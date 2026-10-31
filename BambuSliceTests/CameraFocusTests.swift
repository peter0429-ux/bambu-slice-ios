import XCTest
import SceneKit
import simd
@testable import BambuSlice

/// 相机取景的回归测试。
///
/// 守的是「点了聚焦按钮画面全黑」这类问题 —— 它的本质是**相机朝向算错**
/// （或离模型太远/太近），完全可以离线断言，不需要真机看屏幕。
///
/// 之前这里用 `look(at:)` + 给 `SCNCameraController` 塞 pointOfView，
/// 相机挂在旋转 -90° 的 container 下时算出了反向朝向，屏幕上什么都没有。
final class CameraFocusTests: XCTestCase {

    // MARK: - 夹具

    private func cubeMesh(size: Float, at origin: SIMD3<Float> = .zero) -> Mesh {
        let s = size
        let v: [SIMD3<Float>] = [
            origin + SIMD3(0, 0, 0), origin + SIMD3(s, 0, 0),
            origin + SIMD3(s, s, 0), origin + SIMD3(0, s, 0),
            origin + SIMD3(0, 0, s), origin + SIMD3(s, 0, s),
            origin + SIMD3(s, s, s), origin + SIMD3(0, s, s),
        ]
        let idx: [UInt32] = [
            0, 2, 1, 0, 3, 2,      // 底
            4, 5, 6, 4, 6, 7,      // 顶
            0, 1, 5, 0, 5, 4,
            1, 2, 6, 1, 6, 5,
            2, 3, 7, 2, 7, 6,
            3, 0, 4, 3, 4, 7,
        ]
        return Mesh(positions: v, indices: idx,
                    boundsMin: origin, boundsMax: origin + SIMD3(s, s, s))
    }

    /// 造一个和 App 里一样的场景并执行一次聚焦，返回 (view, 相机, 模型, 目标世界坐标)
    private func makeFocusedScene(mesh: Mesh)
        -> (SCNView, SCNNode, SCNNode, SIMD3<Float>) {

        let scene = SceneBuilder.buildScene(mesh: mesh, layers: [], settings: SliceSettings())
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.scene = scene

        SceneBuilder.focusCamera(on: view)

        let cam = view.pointOfView ?? SCNNode()
        let model = scene.rootNode.childNode(withName: SceneBuilder.modelName, recursively: true)!
        let (lo, hi) = model.boundingBox
        let localCenter = SCNVector3((lo.x + hi.x) * 0.5,
                                     (lo.y + hi.y) * 0.5,
                                     (lo.z + hi.z) * 0.5)
        let target = model.convertPosition(localCenter, to: nil)
        return (view, cam, model, SIMD3<Float>(target.x, target.y, target.z))
    }

    // MARK: - 用例

    /// 相机必须**看着模型**。dot ≈ 1 才算对准；朝向反了就是全黑。
    func testFocusCameraAimsAtModel() {
        let (view, cam, _, target) = makeFocusedScene(mesh: cubeMesh(size: 10))

        XCTAssertNotNil(view.pointOfView, "聚焦后没有 pointOfView，画面会是空的")
        XCTAssertNotNil(cam.camera, "相机节点上没有 SCNCamera")

        let eye = cam.simdWorldPosition
        let toTarget = simd_normalize(target - eye)

        // 相机朝自身 -Z，世界朝向取世界变换第三列取反
        let zAxis = SIMD3<Float>(cam.simdWorldTransform.columns.2.x,
                                 cam.simdWorldTransform.columns.2.y,
                                 cam.simdWorldTransform.columns.2.z)
        let forward = -simd_normalize(zAxis)

        let dot = simd_dot(toTarget, forward)
        XCTAssertGreaterThan(dot, 0.99,
                             "相机没对准模型（dot=\(dot)）：屏幕上会是空的")
    }

    /// 距离要合理：不能贴脸（看到内部/黑屏），也不能远到模型只剩一个点。
    func testFocusCameraDistanceIsSane() {
        let (_, cam, _, target) = makeFocusedScene(mesh: cubeMesh(size: 10))
        let dist = simd_distance(cam.simdWorldPosition, target)

        XCTAssertGreaterThan(dist, 10, "相机离模型太近（\(dist)mm），会切进模型内部")
        XCTAssertLessThan(dist, 200, "相机离模型太远（\(dist)mm），模型会小得看不见")
    }

    /// 模型必须**完整落在画面内**，而且居中。
    ///
    /// 守的是「角度对了，但模型被裁掉 / 偏在一边 / 显得太远」：
    /// `SCNCamera.fieldOfView` 在 `.automatic` 下竖屏时作用在水平方向，
    /// 竖直 FOV 会被放大，取景距离算错就会横向裁切。
    func testFocusCameraKeepsModelInsideViewport() {
        let size: Float = 16
        let (view, cam, model, _) = makeFocusedScene(mesh: cubeMesh(size: size))

        guard let camera = cam.camera else { return XCTFail("没有 SCNCamera") }
        XCTAssertEqual(camera.projectionDirection, .vertical,
                       "投影方向必须显式设为 vertical，否则竖屏取景会算错")

        // 和实现保持一致：view 是 390x844
        let aspect = Float(view.bounds.width) / max(Float(view.bounds.height), 1)
        let fovY = Float(camera.fieldOfView) * .pi / 180
        let fovX = 2 * atan(tan(fovY * 0.5) * aspect)

        let inv = simd_inverse(cam.simdWorldTransform)
        let (lo, hi) = model.boundingBox

        var maxX: Float = 0
        var maxY: Float = 0
        for xi in [lo.x, hi.x] {
            for yi in [lo.y, hi.y] {
                for zi in [lo.z, hi.z] {
                    let world = model.convertPosition(SCNVector3(xi, yi, zi), to: nil)
                    let pc = inv * SIMD4<Float>(world.x, world.y, world.z, 1)
                    let depth = -pc.z                     // 相机朝 -Z，前方为正
                    XCTAssertGreaterThan(depth, 0, "模型有点在相机后面")
                    let ndcX = (pc.x / depth) / tan(fovX * 0.5)
                    let ndcY = (pc.y / depth) / tan(fovY * 0.5)
                    maxX = max(maxX, abs(ndcX))
                    maxY = max(maxY, abs(ndcY))
                }
            }
        }

        XCTAssertLessThanOrEqual(maxX, 1.02,
                                 "模型横向超出画面（|x|max=\(maxX)），会被裁掉")
        XCTAssertLessThanOrEqual(maxY, 1.02,
                                 "模型纵向超出画面（|y|max=\(maxY)）")
        // 至少有一边要占得比较满，否则就是「太远、模型很小」
        XCTAssertGreaterThan(max(maxX, maxY), 0.55,
                             "模型在画面里太小（最大占比 \(max(maxX, maxY))），取景太远")
    }

    /// 模型中心应该落在画面正中。
    func testFocusCameraCentersModel() {
        let (_, cam, model, _) = makeFocusedScene(mesh: cubeMesh(size: 16))
        guard let camera = cam.camera else { return XCTFail("没有 SCNCamera") }

        let aspect = 390.0 / 844.0
        let fovY = Float(camera.fieldOfView) * .pi / 180
        let fovX = 2 * atan(tan(fovY * 0.5) * Float(aspect))

        let (lo, hi) = model.boundingBox
        let localCenter = SCNVector3((lo.x + hi.x) * 0.5,
                                     (lo.y + hi.y) * 0.5,
                                     (lo.z + hi.z) * 0.5)
        let world = model.convertPosition(localCenter, to: nil)
        let pc = simd_inverse(cam.simdWorldTransform) * SIMD4<Float>(world.x, world.y, world.z, 1)
        let depth = -pc.z
        let ndcX = (pc.x / depth) / tan(fovX * 0.5)
        let ndcY = (pc.y / depth) / tan(fovY * 0.5)

        XCTAssertLessThan(abs(ndcX), 0.05, "模型中心横向偏了（ndcX=\(ndcX)）")
        XCTAssertLessThan(abs(ndcY), 0.05, "模型中心纵向偏了（ndcY=\(ndcY)）")
    }

    /// 取景距离要随模型尺寸变化，不能写死。
    func testFocusCameraScalesWithModelSize() {
        let (_, smallCam, _, smallTarget) = makeFocusedScene(mesh: cubeMesh(size: 5))
        let (_, bigCam, _, bigTarget) = makeFocusedScene(mesh: cubeMesh(size: 80))

        let smallDist = simd_distance(smallCam.simdWorldPosition, smallTarget)
        let bigDist = simd_distance(bigCam.simdWorldPosition, bigTarget)

        XCTAssertGreaterThan(bigDist, smallDist * 3,
                             "80mm 与 5mm 的模型取景距离几乎一样（\(smallDist) vs \(bigDist)），说明没按包围盒算")
    }

    /// 模型不在原点时（STL 原始坐标任意），聚焦仍要对准它被摆到床中心后的位置。
    func testFocusCameraHandlesOffsetModel() {
        let (_, cam, _, target) = makeFocusedScene(
            mesh: cubeMesh(size: 12, at: SIMD3(180, -40, 30)))

        let eye = cam.simdWorldPosition
        let toTarget = simd_normalize(target - eye)
        let zAxis = SIMD3<Float>(cam.simdWorldTransform.columns.2.x,
                                 cam.simdWorldTransform.columns.2.y,
                                 cam.simdWorldTransform.columns.2.z)
        let forward = -simd_normalize(zAxis)

        XCTAssertGreaterThan(simd_dot(toTarget, forward), 0.99,
                             "模型有偏移时没对准，说明取景中心没算上节点平移")
    }
}
