import SwiftUI
import SceneKit

@MainActor
final class SlicerViewModel: ObservableObject {

    enum Mode: String, CaseIterable, Identifiable {
        case model = "模型"
        case toolpath = "路径"
        var id: String { rawValue }
    }

    enum Phase: Equatable {
        case empty            // 还没导入模型
        case ready            // 可以切片
        case busy(String)     // 处理中
        case finished
        case failed(String)
    }

    // 输出
    @Published private(set) var scene: SCNScene?
    @Published private(set) var mesh: Mesh?
    @Published private(set) var layers: [ToolpathLayer] = []
    @Published private(set) var output: SliceOutput?
    @Published private(set) var gcodeURL: URL?
    @Published private(set) var warnings: [String] = []
    @Published private(set) var phase: Phase = .empty
    @Published private(set) var progress: Double = 0
    @Published private(set) var stage: String = ""
    @Published private(set) var fileName: String = ""

    // 输入
    @Published var mode: Mode = .model
    @Published var layerPosition: Double = 1.0
    @Published var settings = SliceSettings() {
        didSet {
            if oldValue.printer != settings.printer { rebuildScene() }
        }
    }
    @Published var errorMessage: String?

    private let engine = BambuCoreEngine()
    private var modelURL: URL?

    /// 所有存储属性都有内联默认值，所以 init 可以标记 nonisolated。
    /// 否则 @StateObject 在 View 的属性初始化器里创建它时会被主 actor 隔离检查拦住。
    nonisolated init() {}

    // MARK: - 派生状态

    var isBusy: Bool {
        if case .busy = phase { return true }
        return false
    }

    var hasModel: Bool { mesh != nil }
    var hasToolpaths: Bool { !layers.isEmpty }

    var canSlice: Bool { hasModel && !isBusy }

    var maxVisibleLayer: Int {
        guard mode == .toolpath, !layers.isEmpty else { return Int.max }
        let n = layers.count
        if layerPosition >= 0.999 { return n - 1 }
        return max(0, min(n - 1, Int((layerPosition * Double(n - 1)).rounded())))
    }

    var layerLabel: String {
        guard hasToolpaths else { return "—" }
        if maxVisibleLayer == Int.max { return "共 \(layers.count) 层" }
        return "第 \(maxVisibleLayer + 1) / \(layers.count) 层"
    }

    var backendLabel: String {
        BambuCoreEngine.isCoreAvailable ? "libslic3r" : "参考引擎"
    }

    var durationText: String {
        guard let output else { return "—" }
        let total = Int(output.durationSeconds.rounded())
        let h = total / 3600, m = (total % 3600) / 60
        if h > 0 { return "\(h) 小时 \(m) 分" }
        return "\(max(m, 1)) 分钟"
    }

    var filamentText: String {
        guard let output else { return "—" }
        return String(format: "%.1f g", output.filamentGrams)
    }

    var layerCountText: String {
        guard let output else { return "—" }
        return "\(output.layerCount)"
    }

    // MARK: - 导入

    func importModel(from url: URL) async {
        guard !isBusy else { return }
        phase = .busy("读取模型")
        errorMessage = nil

        do {
            let local = try Self.stash(url)
            let loaded = try await engine.loadModel(at: local)

            modelURL = local
            fileName = local.lastPathComponent
            mesh = loaded
            layers = []
            output = nil
            gcodeURL = nil
            warnings = []
            layerPosition = 1.0
            mode = .model
            phase = .ready
            rebuildScene()
        } catch {
            phase = .empty
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 切片

    func slice() async {
        guard let url = modelURL, hasModel, !isBusy else { return }

        let snapshot = settings
        let base = (fileName as NSString).deletingPathExtension

        phase = .busy("切片中")
        progress = 0
        stage = "准备"
        output = nil
        warnings = []
        gcodeURL = nil
        layerPosition = 1.0

        do {
            let result = try await engine.slice(at: url, settings: snapshot) { fraction, stage in
                // 内核在后台线程回调，这里跳回主 actor 更新 UI
                Task { @MainActor [weak self] in
                    self?.progress = fraction
                    self?.stage = stage
                }
            }

            // G-code 解析和落盘都很重，别放主线程。
            // 只把 String 传进 detached task，避免把整个 SliceOutput 跨隔离域搬。
            let gcode = result.gcode

            let parsed = await Task.detached(priority: .userInitiated) {
                GCodePreviewParser.parse(gcode)
            }.value

            let fileURL = try await Task.detached(priority: .userInitiated) {
                try Self.writeGCode(gcode, baseName: base)
            }.value

            output = result
            layers = parsed
            gcodeURL = fileURL
            warnings = result.warnings
            mode = .toolpath
            phase = .finished
            rebuildScene()

        } catch SlicerError.cancelled {
            phase = hasModel ? Phase.ready : Phase.empty
            stage = ""
        } catch {
            phase = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func cancel() {
        engine.cancel()
    }

    // MARK: - 私有

    /// 扫 App 自己的 Documents 目录，找最新的一个模型文件。
    /// 「文件」App 里把 STL 拖进 BambuSlice 文件夹，就是落在这里。
    static func newestModelInDocuments() -> URL? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        guard let walker = fm.enumerator(at: docs,
                                         includingPropertiesForKeys: [.contentModificationDateKey],
                                         options: [.skipsHiddenFiles]) else { return nil }

        var best: (URL, Date)?
        for case let url as URL in walker {
            let ext = url.pathExtension.lowercased()
            guard ext == "stl" || ext == "obj" else { continue }
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            if best == nil || date > best!.1 { best = (url, date) }
        }
        return best?.0
    }

    /// 启动或回到前台时，如果还没有模型，自动加载文件夹里最新的那个。
    /// 这样「用文件 App 把 STL 拖进来」才真的能用。
    func autoLoadFromDocuments() async {
        guard mesh == nil, !isBusy else { return }
        guard let url = Self.newestModelInDocuments() else { return }
        await importModel(from: url)
    }

    private func rebuildScene() {
        scene = SceneBuilder.buildScene(mesh: mesh, layers: layers, settings: settings)
    }

    /// 文档选择器给的 URL 是安全作用域的，生命周期不可控。
    /// 立刻拷到沙盒里，后续内核随便读。
    private static func stash(_ url: URL) throws -> URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].resolvingSymlinksInPath()
        let src = url.resolvingSymlinksInPath()

        // 已经在自己的沙盒里（自动加载路径），再拷一次会把源文件删掉
        if src.path.hasPrefix(docs.path) {
            return src
        }

        let dir = docs.appendingPathComponent("Imports", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let dest = dir.appendingPathComponent(url.lastPathComponent)
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        try fm.copyItem(at: url, to: dest)
        return dest
    }

    nonisolated private static func writeGCode(_ text: String, baseName: String) throws -> URL {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(baseName + ".gcode")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
