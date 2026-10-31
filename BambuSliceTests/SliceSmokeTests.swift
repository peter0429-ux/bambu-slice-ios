import XCTest
@testable import BambuSlice

/// 切片冒烟测试。
///
/// 这个测试的核心价值是**能崩**：今天踩过的坑（缺 Print::process()、
/// support_threshold_angle 用 get_at(-1) 越界、export_gcode 传 null 被上游
/// 未判空写入、log_memory_info 在 iOS 无实现）都会让这里直接失败甚至让
/// 测试进程崩溃 —— 也就是说，以后再犯同类错误，CI 会先发现，不用等用户装包。
final class SliceSmokeTests: XCTestCase {

    /// 夹具：10mm 立方体。层高 0.2 → 预期约 50 层，几何简单、断言稳定。
    private func fixtureURL() throws -> URL {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "cube10", withExtension: "stl") else {
            XCTFail("找不到 cube10.stl 夹具（检查 BambuSliceTests/Fixtures 是否被当作资源打包）")
            throw XCTSkip("夹具缺失")
        }
        return url
    }

    /// 跑一次完整切片，断言 G-code 真的产出了内容。
    func testSliceCubeProducesValidGCode() async throws {
        let url = try fixtureURL()

        let engine = BambuCoreEngine()
        var settings = SliceSettings()
        settings.layerHeight = 0.2
        settings.wallLoops = 2
        settings.infillDensity = 0.2
        settings.supportEnabled = false
        settings.brimEnabled = false

        let out = try await engine.slice(at: url, settings: settings) { _, _ in }

        XCTAssertEqual(out.backend, "libslic3r", "应该走真内核，不是参考引擎")
        XCTAssertGreaterThan(out.gcode.count, 1024,
                             "G-code 小于 1KB，切片可能没真正执行")
        XCTAssertGreaterThan(out.layerCount, 0,
                             "层数为 0：要么统计读取失败，要么切片没产出层")
        XCTAssertGreaterThan(out.durationSeconds, 0,
                             "打印时间为 0，GCodeProcessorResult 的统计没被正确读取")
        XCTAssertGreaterThan(out.filamentGrams, 0,
                             "耗材 0 克：filament_density 可能没设")

        // G-code 里应该能见到基本的运动指令
        XCTAssertTrue(out.gcode.contains("G1 "), "G-code 里没有 G1 运动指令")
    }

    /// 开支撑再跑一次：覆盖 support_* 参数链路。
    /// 之前 support_material（PrusaSlicer 旧名）在 Bambu 分支不存在，
    /// 支撑会静默失效，这个用例能守住这一点。
    func testSliceCubeWithSupport() async throws {
        let url = try fixtureURL()

        let engine = BambuCoreEngine()
        var settings = SliceSettings()
        settings.layerHeight = 0.2
        settings.supportEnabled = true
        settings.supportThreshold = 30

        let out = try await engine.slice(at: url, settings: settings) { _, _ in }

        XCTAssertGreaterThan(out.layerCount, 0)
        // 参数不该被静默丢弃
        let rejected = out.warnings.filter { $0.contains("配置项值无效") }
        XCTAssertTrue(rejected.isEmpty,
                      "有参数值被引擎拒绝，说明枚举字符串或类型写错了: \(rejected)")
    }

    /// 层高变化应该反映到层数上（0.25 层高的层数应明显少于 0.1）。
    func testLayerHeightAffectsLayerCount() async throws {
        let url = try fixtureURL()
        let engine = BambuCoreEngine()

        var thin = SliceSettings()
        thin.layerHeight = 0.1
        let thinOut = try await engine.slice(at: url, settings: thin) { _, _ in }

        // 注意：不能用 0.4。引擎的校验是「层高 ≤ 0.75 × 线宽」，
        // 默认线宽 0.4 → 上限 0.3，写 0.4 会直接报 Too small line width。
        var thick = SliceSettings()
        thick.layerHeight = 0.25
        let thickOut = try await engine.slice(at: url, settings: thick) { _, _ in }

        XCTAssertGreaterThan(thinOut.layerCount, thickOut.layerCount,
                             "0.1mm 层高的层数应该多于 0.25mm（实际 \(thinOut.layerCount) vs \(thickOut.layerCount)）")
        // 10mm 立方体：0.1mm 约 100 层，0.25mm 约 40 层，给足宽容度
        XCTAssertGreaterThan(thinOut.layerCount, 50,
                             "10mm 模型 0.1 层高应有约 100 层，实际 \(thinOut.layerCount)")
    }
}

// MARK: - 参数直通（P1/P2/P3/P4）回归

extension SliceSmokeTests {

    /// 把所有参数改成非默认值，一起下发。
    ///
    /// 断言里那两类 warning 一个都不能出现：
    ///   「未知配置项，已忽略」  → 键名拼错 / 该版本没有这个键
    ///   「配置项值无效，已忽略」→ 类型错（比如该整数传了小数、枚举字符串不对）
    ///
    /// 这条测试的价值：以后加参数时，只要有任何一个键写错，CI 立刻指名道姓。
    func testAllParametersAcceptedByEngine() async throws {
        let url = try fixtureURL()

        var s = SliceSettings()
        s.layerHeight = 0.2
        s.wallLoops = 2
        s.infillDensity = 0.15
        s.supportEnabled = true

        // P1
        s.topShellLayers = 3
        s.topShellThickness = 0.8
        s.bottomShellLayers = 2
        s.bottomShellThickness = 0.4
        s.ensureVerticalShellThickness = "partial"
        s.topSurfacePattern = "monotonic"
        s.bottomSurfacePattern = "line"
        s.internalSolidInfillPattern = "zig-zag"
        s.onlyOneWallFirstLayer = true
        s.seamPosition = "back"
        s.ironingType = "top"
        s.wallSequence = "outer wall/inner wall"
        s.elefantFootCompensation = 0.1
        s.xyHoleCompensation = 0.05
        s.xyContourCompensation = 0.05

        // P2：速度全部改成明显不同的值
        s.outerWallSpeed = 30
        s.innerWallSpeed = 45
        s.sparseInfillSpeed = 70
        s.internalSolidInfillSpeed = 80
        s.topSurfaceSpeed = 55
        s.initialLayerSpeed = 20
        s.initialLayerInfillSpeed = 40
        s.travelSpeed = 200
        s.supportSpeed = 60
        s.supportInterfaceSpeed = 50
        s.bridgeSpeed = 20

        // P3
        s.retractionLength = 1.2
        s.retractionSpeed = 40
        s.retractionMinimumTravel = 3
        s.zHop = 0.6
        s.zHopType = "Normal Lift"
        s.wipeEnabled = true
        s.wipeDistance = 3
        s.reduceCrossingWall = true

        // P4
        s.fanMaxSpeed = 90
        s.fanMinSpeed = 30
        s.fanCoolingLayerTime = 40
        s.slowDownForLayerCooling = true
        s.slowDownLayerTime = 8
        s.overhangFanSpeed = 80
        s.closeFanFirstXLayers = 2
        s.fullFanSpeedLayer = 3
        s.enableOverhangBridgeFan = true

        let engine = BambuCoreEngine()
        let out = try await engine.slice(at: url, settings: s) { _, _ in }

        XCTAssertGreaterThan(out.gcode.count, 1024, "参数全开后切片没产出")

        let rejected = out.warnings.filter {
            $0.contains("未知配置项") || $0.contains("配置项值无效")
        }
        XCTAssertTrue(rejected.isEmpty,
                      "有参数没被引擎接受（键名拼错或类型不对）：\n\(rejected.joined(separator: "\n"))")
    }

    /// 改速度必须真的改变 G-code 里的进给率（F 值）。
    ///
    /// 为什么不用「打印时长」判断：10mm 的小立方体每段移动只有 10mm，
    /// 加速度/拐角速度限制下轴根本到不了 200mm/s，快慢都被运动学主导
    /// （实测 338s vs 420s，只差 24%，看着像参数没生效）。
    /// 直接读 G-code 的 F 值才是参数是否到达引擎的直接证据。
    ///
    /// 这条守的是「参数根本没到引擎」——比如 Swift 字典是值类型，
    /// `s.overrides = ov` 写早了等于复制一份，后续写入全部丢失，
    /// 而这种失效**不会产生任何 warning**，只能靠行为差异发现。
    func testSpeedOverridesReachGCode() async throws {
        let url = try fixtureURL()
        let engine = BambuCoreEngine()

        var fast = SliceSettings()
        fast.layerHeight = 0.2
        fast.outerWallSpeed = 200
        fast.innerWallSpeed = 200
        fast.sparseInfillSpeed = 200
        fast.internalSolidInfillSpeed = 200
        fast.topSurfaceSpeed = 200
        fast.initialLayerSpeed = 100
        fast.initialLayerInfillSpeed = 200
        fast.travelSpeed = 400

        var slow = fast
        slow.outerWallSpeed = 20
        slow.innerWallSpeed = 20
        slow.sparseInfillSpeed = 20
        slow.internalSolidInfillSpeed = 20
        slow.topSurfaceSpeed = 20
        slow.initialLayerSpeed = 10
        slow.initialLayerInfillSpeed = 20
        slow.travelSpeed = 40

        let fastOut = try await engine.slice(at: url, settings: fast) { _, _ in }
        let slowOut = try await engine.slice(at: url, settings: slow) { _, _ in }

        let fastMaxF = maxFeedrate(fastOut.gcode)
        let slowMaxF = maxFeedrate(slowOut.gcode)

        XCTAssertGreaterThan(slowMaxF, 0, "G-code 里没有 F 值，解析有问题")
        XCTAssertGreaterThan(fastMaxF, slowMaxF * 3,
                             "速度调快 10 倍，G-code 最大进给率却几乎没变"
                             + "（fast maxF=\(fastMaxF) mm/min, slow maxF=\(slowMaxF) mm/min）"
                             + " —— 速度参数没进到引擎")
    }

    /// 取 G-code 里出现过的最大进给率（mm/min）
    private func maxFeedrate(_ gcode: String) -> Double {
        var maxF = 0.0
        gcode.enumerateLines { line, _ in
            guard line.hasPrefix("G1") || line.hasPrefix("G0") else { return }
            for token in line.split(separator: " ") where token.hasPrefix("F") {
                if let v = Double(token.dropFirst()), v > maxF { maxF = v }
            }
        }
        return maxF
    }
}
