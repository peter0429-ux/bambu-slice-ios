import XCTest
import SceneKit
import Metal
import simd
import UIKit
@testable import BambuSlice

/// 视口的**视觉**回归测试：离屏渲染一张图，然后数像素。
///
/// 为什么要有这一层：前几轮的「画面全黑」「模型太小 / 偏离中心」
/// 用几何断言只能覆盖一部分（朝向、NDC 包围盒），
/// 真正确认「屏幕上到底画出了什么」还得看渲染结果。
///
/// 这个测试能抓到：
///   - 全黑 / 什么都没画（覆盖率 0）
///   - 模型被裁掉或铺满整屏（覆盖率异常大）
///   - 取景中心算错（像素质心偏离画面中心）
final class ViewportRenderTests: XCTestCase {

    private func cubeMesh(size: Float) -> Mesh {
        let s = size
        let v: [SIMD3<Float>] = [
            SIMD3(0, 0, 0), SIMD3(s, 0, 0), SIMD3(s, s, 0), SIMD3(0, s, 0),
            SIMD3(0, 0, s), SIMD3(s, 0, s), SIMD3(s, s, s), SIMD3(0, s, s),
        ]
        let idx: [UInt32] = [
            0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7,
            0, 1, 5, 0, 5, 4, 1, 2, 6, 1, 6, 5,
            2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7,
        ]
        return Mesh(positions: v, indices: idx,
                    boundsMin: .zero, boundsMax: SIMD3(s, s, s))
    }

    /// 离屏渲染，返回 (非背景像素占比, 质心x, 质心y)，坐标已归一化到 0...1
    private func renderStats(size: Float,
                             viewSize: CGSize = CGSize(width: 390, height: 844))
        -> (coverage: Double, cx: Double, cy: Double)? {

        let scene = SceneBuilder.buildScene(mesh: cubeMesh(size: size),
                                            layers: [], settings: SliceSettings())
        // 只留模型：床和网格会占掉大半屏幕，那样覆盖率就没意义了
        scene.rootNode.childNode(withName: "bed", recursively: true)?.isHidden = true
        scene.rootNode.childNode(withName: SceneBuilder.toolpathName, recursively: true)?.isHidden = true

        let view = SCNView(frame: CGRect(origin: .zero, size: viewSize))
        view.scene = scene
        SceneBuilder.focusCamera(on: view)

        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = view.pointOfView
        let image = renderer.snapshot(atTime: 0, with: viewSize, antialiasingMode: .none)

        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &pixels, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        var count = 0
        var sumX = 0.0, sumY = 0.0
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                let r = Double(pixels[i]), g = Double(pixels[i + 1]), b = Double(pixels[i + 2])
                let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
                // 背景色 (0.055,0.062,0.078) → 亮度约 16；模型被灯照亮，明显更亮
                if lum > 40 {
                    count += 1
                    sumX += Double(x)
                    sumY += Double(y)
                }
            }
        }
        guard count > 0 else { return (0, 0.5, 0.5) }
        let total = Double(w * h)
        return (Double(count) / total, sumX / Double(count) / Double(w), sumY / Double(count) / Double(h))
    }

    func testRenderedModelIsVisibleAndFramed() throws {
        guard let s = renderStats(size: 16) else {
            XCTFail("离屏渲染失败：模拟器没有 Metal 设备，或 snapshot 返回空。这条测试必须真跑")
            return
        }

        // 1. 必须真的画出了东西（全黑时覆盖率是 0）
        XCTAssertGreaterThan(s.coverage, 0.03,
                             "画面上几乎没有模型（覆盖率 \(s.coverage)），可能全黑或相机没对准")

        // 2. 不能铺满整屏（说明相机切进模型内部）
        XCTAssertLessThan(s.coverage, 0.65,
                          "模型铺满画面（覆盖率 \(s.coverage)），相机太近")

        // 3. 像素质心要落在画面中间
        XCTAssertEqual(s.cx, 0.5, accuracy: 0.08,
                       "模型横向偏离画面中心（质心 x=\(s.cx)）")
        XCTAssertEqual(s.cy, 0.5, accuracy: 0.08,
                       "模型纵向偏离画面中心（质心 y=\(s.cy)）")
    }

    /// 大模型小模型都要画得出来，不能只对某个尺寸成立。
    func testRenderedCoverageStableAcrossSizes() throws {
        for size in [6.0, 16.0, 60.0] as [Float] {
            guard let s = renderStats(size: size) else {
                XCTFail("离屏渲染失败（\(size)mm）：模拟器没有 Metal 设备，或 snapshot 返回空")
                return
            }
            XCTAssertGreaterThan(s.coverage, 0.03, "\(size)mm 模型不可见（覆盖率 \(s.coverage)）")
            XCTAssertLessThan(s.coverage, 0.65, "\(size)mm 模型铺满画面（覆盖率 \(s.coverage)）")
            XCTAssertEqual(s.cx, 0.5, accuracy: 0.10, "\(size)mm 模型横向偏移 (x=\(s.cx))")
        }
    }
}
