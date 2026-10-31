import XCTest
import simd
@testable import BambuSlice

/// 模型变换（缩放 / 绕 Z 旋转）。
///
/// 这一组的重点是**预览和引擎必须用同一套参数**：
/// 之前出现过「预览里模型 16mm，切出来只有几层」的错位，
/// 根源就是两边对模型的变换不一致。
final class ModelTransformTests: XCTestCase {

    private func cube(_ s: Float) -> Mesh {
        let v: [SIMD3<Float>] = [
            SIMD3(0, 0, 0), SIMD3(s, 0, 0), SIMD3(s, s, 0), SIMD3(0, s, 0),
            SIMD3(0, 0, s), SIMD3(s, 0, s), SIMD3(s, s, s), SIMD3(0, s, s),
        ]
        let idx: [UInt32] = [
            0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7,
            0, 1, 5, 0, 5, 4, 1, 2, 6, 1, 6, 5,
            2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7,
        ]
        return Mesh(positions: v, indices: idx, boundsMin: .zero, boundsMax: SIMD3(s, s, s))
    }

    func testScaleDoublesBounds() {
        let m = cube(10).applying(scale: 2.0, rotateZDeg: 0)
        XCTAssertEqual(m.boundsMax.x, 20, accuracy: 1e-4)
        XCTAssertEqual(m.boundsMax.y, 20, accuracy: 1e-4)
        XCTAssertEqual(m.boundsMax.z, 20, accuracy: 1e-4)
        XCTAssertEqual(m.positions.count, 8)
    }

    func testIdentityLeavesMeshUntouched() {
        let base = cube(10)
        let m = base.applying(scale: 1.0, rotateZDeg: 0)
        XCTAssertEqual(m.positions, base.positions)
    }

    func testRotate90SwapsXY() {
        // 10x10 的立方体旋转 90° 后包围盒不变，但顶点 (10,0) 应变成 (0,10)
        let m = cube(10).applying(scale: 1.0, rotateZDeg: 90)
        XCTAssertEqual(m.boundsMax.x, 10, accuracy: 1e-3)
        XCTAssertEqual(m.boundsMax.y, 10, accuracy: 1e-3)
        XCTAssertEqual(m.boundsMin.x, 0, accuracy: 1e-3)
        XCTAssertEqual(m.boundsMin.y, 0, accuracy: 1e-3)

        // 找到原来 (10,0,0) 的点，旋转后应在 (0,10,0) 附近
        let rotated = m.positions.contains { p in
            abs(p.x) < 1e-3 && abs(p.y - 10) < 1e-3 && abs(p.z) < 1e-3
        }
        XCTAssertTrue(rotated, "90° 旋转后没有 (0,10,0) 这个点，旋转方向或公式有问题")
    }

    /// 端到端：缩放必须真的作用到引擎上。
    /// 10mm 立方体 0.2 层高约 50 层，放大到 200% 应该接近 100 层。
    func testScaleReachesEngineLayerCount() async throws {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "cube10", withExtension: "stl") else {
            return XCTFail("找不到 cube10.stl 夹具")
        }
        let engine = BambuCoreEngine()

        var normal = SliceSettings()
        normal.layerHeight = 0.2
        let normalOut = try await engine.slice(at: url, settings: normal) { _, _ in }

        var big = normal
        big.modelScalePercent = 200
        let bigOut = try await engine.slice(at: url, settings: big) { _, _ in }

        let expected = Double(normalOut.layerCount) * 2
        XCTAssertGreaterThan(bigOut.layerCount, Int(expected * 0.85),
                             "放大 200% 后层数没翻倍（\(normalOut.layerCount) → \(bigOut.layerCount)）"
                             + "，缩放没传到引擎")
        XCTAssertLessThan(bigOut.layerCount, Int(expected * 1.15))
    }

    /// 旋转不应该改变层数（只转水平方向），但会改变路径坐标
    func testRotationKeepsLayerCountButChangesPath() async throws {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "cube10", withExtension: "stl") else {
            return XCTFail("找不到 cube10.stl 夹具")
        }
        let engine = BambuCoreEngine()

        var normal = SliceSettings()
        normal.layerHeight = 0.2
        let a = try await engine.slice(at: url, settings: normal) { _, _ in }

        var rot = normal
        rot.modelRotateZ = 45
        let b = try await engine.slice(at: url, settings: rot) { _, _ in }

        XCTAssertEqual(a.layerCount, b.layerCount, "绕 Z 旋转不该改变层数")
        XCTAssertNotEqual(a.gcode, b.gcode, "旋转 45° 后 G-code 完全一样，说明旋转没生效")
    }
}
