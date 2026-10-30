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

    // ── 支撑参数（对应 Bambu Studio 支撑面板）──────────────────
    // 注意：Bambu 分支里没有 PrusaSlicer 的 support_material / support_material_threshold，
    // 它的键是 enable_support / support_threshold_angle，用旧名会静默失效。
    /// 悬垂角阈值（°）：坡度低于这个值的悬垂才加支撑。桌面版默认 30，
    /// 调大→支撑变少，调小→支撑变多。
    var supportThreshold: Double = 30
    /// normal(auto) / tree(auto) / normal / tree
    var supportType: String = "normal(auto)"
    /// 支撑顶面与模型的间隙 mm
    var supportTopZDistance: Double = 0.20
    /// 支撑底面与模型的间隙 mm
    var supportBottomZDistance: Double = 0.20
    /// 支撑与模型的水平距离 mm
    var supportObjectXYDistance: Double = 0.35
    /// 支撑底部图案间距 mm（越小越密实）
    var supportBasePatternSpacing: Double = 2.5
    /// 支撑接触面层数
    var supportInterfaceTopLayers: Int = 2
    /// 接触面线距 mm
    var supportInterfaceSpacing: Double = 0.5
    /// 支撑水平外扩 mm（正值让支撑更宽，更容易挂住悬垂）
    var supportExpansion: Double = 0.0
    /// 只在热床上生成支撑（模型内部不放）
    var supportBuildplateOnly: Bool = false
    /// 过滤掉太小的悬垂区域
    var supportRemoveSmallOverhang: Bool = true
    /// 树状支撑分枝角（°）
    var treeSupportBranchAngle: Double = 30
    /// 树状支撑主干直径 mm
    var treeSupportBranchDiameter: Double = 2.0
    /// 树状支撑壁数
    var treeSupportWallCount: Int = 1

    var brimEnabled: Bool = false

    /// 手绘强制支撑的三角形索引（对应 STL 面片序号）。
    /// 用户在 3D 视图里点选的面会被标记为 ENFORCER，切片时引擎强制在该处生成支撑。
    var supportFacets: Set<Int> = []
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
        s.supportThreshold = supportThreshold
        s.brimEnabled = brimEnabled
        s.nozzleTemp = nozzleTemp
        s.bedTemp = bedTemp
        s.printerProfile = printer.name
        s.bedWidth = printer.bedWidth
        s.bedDepth = printer.bedDepth
        s.bedHeight = printer.bedHeight

        // 支撑细节参数全部走 overrides 直通。
        // 这些键在 Bambu 分支里都存在（已对着 PrintConfig.hpp 核对过），
        // 传错键名也不会崩：libslic3r 那边会跳过不认识的键。
        var ov = (s.overrides as? [String: String]) ?? [:]
        ov["support_type"]                  = supportType
        ov["support_top_z_distance"]        = String(format: "%.3f", supportTopZDistance)
        ov["support_bottom_z_distance"]     = String(format: "%.3f", supportBottomZDistance)
        ov["support_object_xy_distance"]    = String(format: "%.3f", supportObjectXYDistance)
        ov["support_base_pattern_spacing"]  = String(format: "%.3f", supportBasePatternSpacing)
        ov["support_interface_top_layers"]  = String(supportInterfaceTopLayers)
        ov["support_interface_spacing"]     = String(format: "%.3f", supportInterfaceSpacing)
        ov["support_expansion"]             = String(format: "%.3f", supportExpansion)
        ov["support_on_build_plate_only"]   = supportBuildplateOnly ? "1" : "0"
        ov["support_remove_small_overhang"] = supportRemoveSmallOverhang ? "1" : "0"
        ov["tree_support_branch_angle"]     = String(format: "%.1f", treeSupportBranchAngle)
        ov["tree_support_branch_diameter"]  = String(format: "%.2f", treeSupportBranchDiameter)
        ov["tree_support_wall_count"]       = String(treeSupportWallCount)
        s.overrides = ov
        s.supportFacets = supportFacets.map { NSNumber(value: $0) }
        return s
    }
}
