import Foundation

struct PrinterPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let bedWidth: Double
    let bedDepth: Double
    let bedHeight: Double

    static let all: [PrinterPreset] = [
        .init(id: "a1mini", name: "A1 mini",  bedWidth: 180, bedDepth: 180, bedHeight: 180),
        .init(id: "a1",     name: "A1",       bedWidth: 256, bedDepth: 256, bedHeight: 256),
        .init(id: "p1s",    name: "P1S / P1P", bedWidth: 256, bedDepth: 256, bedHeight: 256),
        .init(id: "x1c",    name: "X1 Carbon", bedWidth: 256, bedDepth: 256, bedHeight: 256),
    ]
}

/// 一键参数预设。类似于桌面版左侧那一列 0.08/0.12/0.20 的打印配置。
struct SlicePreset: Identifiable, Hashable {
    let id: String
    let name: String
    let layerHeight: Double
    let walls: Int
    let infill: Double

    var detail: String {
        String(format: "%.2fmm · %d 壁 · %d%%", layerHeight, walls, Int((infill * 100).rounded()))
    }

    static let all: [SlicePreset] = [
        .init(id: "fine",   name: "精细", layerHeight: 0.08, walls: 4, infill: 0.25),
        .init(id: "normal", name: "标准", layerHeight: 0.12, walls: 3, infill: 0.20),
        .init(id: "fast",   name: "快速", layerHeight: 0.20, walls: 2, infill: 0.15),
        .init(id: "draft",  name: "草稿", layerHeight: 0.28, walls: 2, infill: 0.10),
    ]
}

struct SliceSettings {
    var layerHeight: Double = 0.20
    var firstLayerHeight: Double = 0.25
    var nozzleDiameter: Double = 0.4
    var wallLoops: Int = 2
    var infillDensity: Double = 0.15
    var infillPattern: String = "grid"
    var supportEnabled: Bool = false
    var brimEnabled: Bool = false
    var nozzleTemp: Double = 220
    var bedTemp: Double = 60
    var printer: PrinterPreset = PrinterPreset.all[0]

    var bedWidth: Double { printer.bedWidth }
    var bedDepth: Double { printer.bedDepth }
    var bedHeight: Double { printer.bedHeight }

    /// 当前参数对得上哪个预设（对不上就是自定义）
    var matchedPreset: SlicePreset? {
        SlicePreset.all.first {
            abs($0.layerHeight - layerHeight) < 0.001
                && $0.walls == wallLoops
                && abs($0.infill - infillDensity) < 0.001
        }
    }

    mutating func apply(_ preset: SlicePreset) {
        layerHeight = preset.layerHeight
        firstLayerHeight = min(0.35, max(0.18, preset.layerHeight * 1.25))
        wallLoops = preset.walls
        infillDensity = preset.infill
    }

    func toBridge() -> BBSliceSettings {
        // ObjC 的 +defaultSettings 被 Swift 导入器按「省略类型名」规则改名成了 default()
        let s = BBSliceSettings.default()
        s.layerHeight = layerHeight
        s.firstLayerHeight = firstLayerHeight
        s.nozzleDiameter = nozzleDiameter
        s.wallLoops = wallLoops
        s.infillDensity = infillDensity
        s.infillPattern = infillPattern
        s.supportEnabled = supportEnabled
        s.brimEnabled = brimEnabled
        s.nozzleTemp = nozzleTemp
        s.bedTemp = bedTemp
        s.printerProfile = printer.name
        s.bedWidth = printer.bedWidth
        s.bedDepth = printer.bedDepth
        s.bedHeight = printer.bedHeight
        return s
    }
}
