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

    // ── P1：壳层 / 顶底面 / 接缝 / 补偿 ─────────────────────
    // 默认值取自 PrintConfig.cpp 的 set_default_value()，不是猜的。
    /// 顶部实心壳层数（引擎默认 4）
    var topShellLayers: Int = 4
    /// 顶部壳厚 mm（和层数取较大者）
    var topShellThickness: Double = 0.6
    /// 底部实心壳层数（引擎默认 3）
    var bottomShellLayers: Int = 3
    /// 底部壳厚 mm（0 表示只按层数算）
    var bottomShellThickness: Double = 0.0
    /// disabled / partial / enabled
    var ensureVerticalShellThickness: String = "enabled"
    /// 顶面图案（InfillPattern）
    var topSurfacePattern: String = "monotonicline"
    /// 底面图案
    var bottomSurfacePattern: String = "monotonicline"
    /// 内部实心填充图案
    var internalSolidInfillPattern: String = "monotonicline"
    /// 首层只打一圈壁
    var onlyOneWallFirstLayer: Bool = false
    /// 接缝位置：nearest / aligned / back / random
    var seamPosition: String = "aligned"
    /// 熨烫：no ironing / top / topmost / solid
    var ironingType: String = "no ironing"
    /// 打壁顺序：inner wall/outer wall | outer wall/inner wall | inner-outer-inner wall
    var wallSequence: String = "inner wall/outer wall"
    /// 象腿补偿 mm（首层内缩，抵消热胀）
    var elefantFootCompensation: Double = 0.0
    /// XY 孔补偿 mm（正=缩小孔）
    var xyHoleCompensation: Double = 0.0
    /// XY 轮廓补偿 mm（正=放大外形）
    var xyContourCompensation: Double = 0.0

    // ── P2：速度（mm/s）──────────────────────────────────────
    // 默认值取自 PrintConfig.cpp 的 set_default_value()。
    var outerWallSpeed: Double = 60
    var innerWallSpeed: Double = 60
    var sparseInfillSpeed: Double = 100
    var internalSolidInfillSpeed: Double = 100
    var topSurfaceSpeed: Double = 100
    var initialLayerSpeed: Double = 30
    var initialLayerInfillSpeed: Double = 60
    var travelSpeed: Double = 120
    var supportSpeed: Double = 80
    var supportInterfaceSpeed: Double = 80
    var bridgeSpeed: Double = 25

    // ── P3：回抽与 Z hop ────────────────────────────────────
    var retractionLength: Double = 0.8
    var retractionSpeed: Double = 30
    /// 空驶距离超过它才回抽
    var retractionMinimumTravel: Double = 2
    var zHop: Double = 0.4
    /// Auto Lift / Normal Lift / Slope Lift / Spiral Lift（引擎默认 Spiral Lift）
    var zHopType: String = "Spiral Lift"
    var wipeEnabled: Bool = false
    var wipeDistance: Double = 2
    var reduceCrossingWall: Bool = false

    // ── P4：冷却风扇 ────────────────────────────────────────
    var fanMaxSpeed: Int = 100
    var fanMinSpeed: Int = 20
    /// 单层耗时低于它会自动降速（秒）
    var fanCoolingLayerTime: Int = 60
    var slowDownForLayerCooling: Bool = true
    /// 降到的最短层时间（秒）
    var slowDownLayerTime: Int = 5
    var overhangFanSpeed: Int = 100
    /// 前 N 层不开风扇
    var closeFanFirstXLayers: Int = 1
    var fullFanSpeedLayer: Int = 0
    var enableOverhangBridgeFan: Bool = true

    /// Z hop 类型对应的引擎枚举索引（顺序来自 PrintConfig.cpp 的 enum_values）
    var zHopTypeIndex: Int {
        switch zHopType {
        case "Auto Lift":   return 0
        case "Normal Lift": return 1
        case "Slope Lift":  return 2
        default:            return 3   // Spiral Lift（引擎默认）
        }
    }

    // ── 模型变换 ────────────────────────────────────────────
    /// 缩放百分比（100 = 原尺寸）。STL 单位搞错时用它拉回来。
    var modelScalePercent: Double = 100
    /// 绕 Z 轴旋转（度）
    var modelRotateZ: Double = 0

    /// 需要暂停的层号（从 1 开始）。空表示不暂停。
    /// 换色 / 埋螺母用：截图里 G-code 会插入 `M400 U1`。
    var pauseLayers: Set<Int> = []

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
        s.modelScale = modelScalePercent / 100.0
        s.modelRotateZ = modelRotateZ

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

        // P1：壳层 / 顶底面 / 接缝 / 补偿
        ov["top_shell_layers"]                 = String(topShellLayers)
        ov["top_shell_thickness"]              = String(format: "%.3f", topShellThickness)
        ov["bottom_shell_layers"]              = String(bottomShellLayers)
        ov["bottom_shell_thickness"]           = String(format: "%.3f", bottomShellThickness)
        ov["ensure_vertical_shell_thickness"]  = ensureVerticalShellThickness
        ov["top_surface_pattern"]              = topSurfacePattern
        ov["bottom_surface_pattern"]           = bottomSurfacePattern
        ov["internal_solid_infill_pattern"]    = internalSolidInfillPattern
        ov["only_one_wall_first_layer"]        = onlyOneWallFirstLayer ? "1" : "0"
        ov["seam_position"]                    = seamPosition
        ov["ironing_type"]                     = ironingType
        ov["wall_sequence"]                    = wallSequence
        ov["elefant_foot_compensation"]        = String(format: "%.3f", elefantFootCompensation)
        ov["xy_hole_compensation"]             = String(format: "%.3f", xyHoleCompensation)
        ov["xy_contour_compensation"]          = String(format: "%.3f", xyContourCompensation)

        // P2：速度（Bambu 里都是 coFloats，单位 mm/s；单值会被解析成单元素数组）
        ov["outer_wall_speed"]             = String(format: "%.1f", outerWallSpeed)
        ov["inner_wall_speed"]             = String(format: "%.1f", innerWallSpeed)
        ov["sparse_infill_speed"]          = String(format: "%.1f", sparseInfillSpeed)
        ov["internal_solid_infill_speed"]  = String(format: "%.1f", internalSolidInfillSpeed)
        ov["top_surface_speed"]            = String(format: "%.1f", topSurfaceSpeed)
        ov["initial_layer_speed"]          = String(format: "%.1f", initialLayerSpeed)
        ov["initial_layer_infill_speed"]   = String(format: "%.1f", initialLayerInfillSpeed)
        ov["travel_speed"]                 = String(format: "%.1f", travelSpeed)
        ov["support_speed"]                = String(format: "%.1f", supportSpeed)
        ov["support_interface_speed"]      = String(format: "%.1f", supportInterfaceSpeed)
        ov["bridge_speed"]                 = String(format: "%.1f", bridgeSpeed)

        // P3：回抽与 Z hop
        ov["retraction_length"]            = String(format: "%.3f", retractionLength)
        ov["retraction_speed"]             = String(format: "%.1f", retractionSpeed)
        ov["retraction_minimum_travel"]    = String(format: "%.2f", retractionMinimumTravel)
        ov["z_hop"]                        = String(format: "%.2f", zHop)
        // z_hop_types 是 nullable 枚举，keys_map 为空，只能按整数索引传。
        // 见 Libslic3rBackend.cpp 里同名键的特殊处理。
        ov["z_hop_types"]                  = String(zHopTypeIndex)
        ov["wipe"]                         = wipeEnabled ? "1" : "0"
        ov["wipe_distance"]                = String(format: "%.2f", wipeDistance)
        ov["reduce_crossing_wall"]         = reduceCrossingWall ? "1" : "0"

        // P4：冷却风扇（这几项是 coInt，必须整数；用小数会被静默拒绝）
        ov["fan_max_speed"]                = String(fanMaxSpeed)
        ov["fan_min_speed"]                = String(fanMinSpeed)
        ov["fan_cooling_layer_time"]       = String(fanCoolingLayerTime)
        ov["slow_down_for_layer_cooling"]  = slowDownForLayerCooling ? "1" : "0"
        ov["slow_down_layer_time"]         = String(slowDownLayerTime)
        ov["overhang_fan_speed"]           = String(overhangFanSpeed)
        ov["close_fan_the_first_x_layers"] = String(closeFanFirstXLayers)
        ov["full_fan_speed_layer"]         = String(fullFanSpeedLayer)
        ov["enable_overhang_bridge_fan"]   = enableOverhangBridgeFan ? "1" : "0"

        // ⚠️ 必须在**所有**键都写完之后再赋值！
        // s.overrides 是 NSDictionary，Swift 字典是值类型，
        // 提前赋值等于复制一份，后续写入根本到不了引擎。
        // （P1 那 15 个参数就这样静默失效过一版。）
        s.overrides = ov

        s.supportFacets = supportFacets.map { NSNumber(value: $0) }
        return s
    }
}
