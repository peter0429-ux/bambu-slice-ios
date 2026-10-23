import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @StateObject private var vm = SlicerViewModel()

    @State private var showImporter = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            ViewportView(scene: vm.scene,
                         showToolpaths: vm.mode == .toolpath && vm.hasToolpaths,
                         maxVisibleLayer: vm.maxVisibleLayer)
                .ignoresSafeArea()

            if !vm.hasModel {
                emptyState
            }

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                if vm.isBusy { progressCard }
                bottomPanel
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: importTypes,
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await vm.importModel(from: url) }
            case .failure(let error):
                vm.errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(settings: $vm.settings)
        }
        .alert("出错了",
               isPresented: Binding(get: { vm.errorMessage != nil },
                                    set: { if !$0 { vm.errorMessage = nil } })) {
            Button("好", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - 顶部信息

    private var topBar: some View {
        HStack(spacing: 8) {
            if vm.hasModel {
                chip(vm.fileName, icon: "cube")
                if let mesh = vm.mesh {
                    let count = mesh.triangleCount
                    chip(count >= 1000 ? "\(count / 1000)K 面" : "\(count) 面", icon: "triangle")
                }
            } else {
                chip("未导入模型", icon: "square.dashed")
            }

            Spacer()

            chip(vm.backendLabel,
                 icon: BambuCoreEngine.isCoreAvailable ? "bolt.fill" : "exclamationmark.triangle",
                 tint: BambuCoreEngine.isCoreAvailable ? .green : .orange)
        }
    }

    private func chip(_ text: String, icon: String, tint: Color = .white) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .foregroundStyle(tint.opacity(0.95))
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 46, weight: .thin))
                .foregroundStyle(.white.opacity(0.55))
            Text("导入一个 STL 或 OBJ")
                .font(.headline)
            Text("支持二进制/ASCII STL、OBJ。也可以从「文件」App\n把模型拖进 BambuSlice 的文件夹。")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(26)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 进度

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(vm.stage.isEmpty ? "处理中" : vm.stage)
                    .font(.caption.weight(.medium))
                Spacer()
                Text("\(Int(vm.progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
            }
            ProgressView(value: min(max(vm.progress, 0), 1))
                .tint(.orange)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.bottom, 8)
    }

    // MARK: - 底部面板

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            Picker("视图", selection: $vm.mode) {
                ForEach(SlicerViewModel.Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!vm.hasToolpaths)

            if vm.mode == .toolpath && vm.hasToolpaths {
                VStack(spacing: 6) {
                    HStack {
                        Text(vm.layerLabel)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        legend
                    }
                    Slider(value: $vm.layerPosition, in: 0...1)
                        .tint(.orange)
                }
            }

            HStack(spacing: 10) {
                stat("打印时间", vm.durationText)
                stat("耗材", vm.filamentText)
                stat("层数", vm.layerCountText)
            }

            if !vm.warnings.isEmpty {
                Label(vm.warnings[0], systemImage: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.orange.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                Button {
                    showImporter = true
                } label: {
                    Label("导入", systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PanelButtonStyle())

                Button {
                    showSettings = true
                } label: {
                    Label("参数", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PanelButtonStyle())

                if let url = vm.gcodeURL {
                    ShareLink(item: url) {
                        Label("导出", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PanelButtonStyle())
                }
            }

            Button {
                if vm.isBusy { vm.cancel() }
                else { Task { await vm.slice() } }
            } label: {
                Text(vm.isBusy ? "取消" : "切片")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isBusy ? .red.opacity(0.85) : .orange)
            .disabled(!vm.canSlice && !vm.isBusy)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var legend: some View {
        HStack(spacing: 8) {
            ForEach([ToolpathFeature.outerWall, .innerWall, .infill, .support], id: \.rawValue) { f in
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color(red: Double(f.rgb.0), green: Double(f.rgb.1), blue: Double(f.rgb.2)))
                        .frame(width: 6, height: 6)
                    Text(f.title)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var importTypes: [UTType] {
        var types: [UTType] = []
        if let stl = UTType(filenameExtension: "stl") { types.append(stl) }
        if let obj = UTType(filenameExtension: "obj") { types.append(obj) }
        return types.isEmpty ? [.data] : types
    }
}

struct PanelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.vertical, 10)
            .background(.white.opacity(configuration.isPressed ? 0.18 : 0.10),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(.white.opacity(0.9))
    }
}
