import XCTest
@testable import BambuSlice

/// 暂停点（M400 U1）的插入逻辑。
///
/// 这里用构造的 G-code 做纯函数测试：插入位置比"能不能插进去"更要紧——
/// 插在该层抬 Z **之前**，暂停时喷嘴还停在上一层高度，用户一碰就刮花。
final class GCodePostProcessorTests: XCTestCase {

    /// 两层的迷你 G-code，层标记与抬 Z 的顺序和真机一致
    private let sample = """
    ; HEADER
    M73 P0
    ; CHANGE_LAYER
    ; Z_HEIGHT: 0.2
    G1 Z.2 F600
    ; FEATURE: Outer wall
    G1 X10 Y10 E.5
    ; CHANGE_LAYER
    ; Z_HEIGHT: 0.4
    G1 Z.4 F600
    G1 X20 Y20 E1.0
    """

    func testInsertsAfterZMovedToNewLayer() {
        let (out, inserted) = GCodePostProcessor.insertPauses(sample, atLayers: [2])

        XCTAssertEqual(inserted, 1)

        let lines = out.components(separatedBy: "\n")
        guard let pauseIdx = lines.firstIndex(where: { $0.contains("M400 U1") }) else {
            return XCTFail("没插入 M400 U1")
        }
        // 前一行必须是抬到 0.4 的那条移动指令，不是层注释
        XCTAssertTrue(lines[pauseIdx - 1].hasPrefix("G1 Z.4"),
                      "暂停插在了错误位置，前一行是：\(lines[pauseIdx - 1])")
        XCTAssertTrue(lines[pauseIdx].contains("第 2 层"))
    }

    func testNoInsertWhenLayerOutOfRange() {
        let (out, inserted) = GCodePostProcessor.insertPauses(sample, atLayers: [99])
        XCTAssertEqual(inserted, 0)
        XCTAssertFalse(out.contains("M400 U1"))
    }

    func testEmptyRequestLeavesGCodeUntouched() {
        let (out, inserted) = GCodePostProcessor.insertPauses(sample, atLayers: [])
        XCTAssertEqual(inserted, 0)
        XCTAssertEqual(out, sample)
    }

    func testMultipleLayers() {
        let (out, inserted) = GCodePostProcessor.insertPauses(sample, atLayers: [1, 2])
        XCTAssertEqual(inserted, 2)
        XCTAssertEqual(out.components(separatedBy: "M400 U1").count - 1, 2)
    }

    /// 端到端：真的切一次片，确认暂停落到 G-code 里，层号也对。
    func testPauseLandsInRealSlicedGCode() async throws {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "cube10", withExtension: "stl") else {
            return XCTFail("找不到 cube10.stl 夹具")
        }

        var s = SliceSettings()
        s.layerHeight = 0.2
        s.pauseLayers = [3]

        let out = try await BambuCoreEngine().slice(at: url, settings: s) { _, _ in }

        XCTAssertGreaterThan(out.layerCount, 3, "层数太少，测不到第 3 层")
        XCTAssertEqual(out.gcode.components(separatedBy: "M400 U1").count - 1, 1,
                       "暂停没有插入，或者插了不止一次")
        XCTAssertTrue(out.gcode.contains("第 3 层"))
        // 暂停层之外不该有暂停
        XCTAssertFalse(out.gcode.contains("第 1 层"))
    }
}
