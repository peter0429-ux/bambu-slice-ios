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
