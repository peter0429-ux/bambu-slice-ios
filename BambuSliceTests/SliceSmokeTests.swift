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

    /// 层高变化应该反映到层数上（0.4 层高的层数应明显少于 0.2）。
    func testLayerHeightAffectsLayerCount() async throws {
        let url = try fixtureURL()
        let engine = BambuCoreEngine()

        var thin = SliceSettings()
        thin.layerHeight = 0.1
        let thinOut = try await engine.slice(at: url, settings: thin) { _, _ in }

        var thick = SliceSettings()
        thick.layerHeight = 0.4
        let thickOut = try await engine.slice(at: url, settings: thick) { _, _ in }

        XCTAssertGreaterThan(thinOut.layerCount, thickOut.layerCount,
                             "0.1mm 层高的层数应该多于 0.4mm（实际 \(thinOut.layerCount) vs \(thickOut.layerCount)）")
    }
}
