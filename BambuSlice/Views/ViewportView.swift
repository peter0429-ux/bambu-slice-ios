import SwiftUI
import SceneKit

/// SceneKit 视口。只负责显示和图层显隐，不持有任何业务状态。
struct ViewportView: UIViewRepresentable {

    let scene: SCNScene?
    /// 手绘支撑高亮要用到原始网格
    var mesh: Mesh? = nil
    /// true 时隐藏实体模型，只显示路径
    let showToolpaths: Bool
    /// 只显示 0...maxVisibleLayer 的层；Int.max 表示全部
    let maxVisibleLayer: Int
    /// 每次数值变化就触发一次「聚焦到模型」。用计数器而不是 Bool，
    /// 这样连点也能每次都生效。
    var focusToken: Int = 0
    /// true 时进入「手绘支撑」模式：锁住相机，点模型拾取面片
    var paintingSupport: Bool = false
    /// 已经标记的面片，用于画红色覆盖层
    var supportFacets: Set<Int> = []
    /// 点中面片时回调
    var onPaint: ((Int) -> Void)? = nil

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.055, green: 0.062, blue: 0.078, alpha: 1)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = false

        let cc = view.defaultCameraController
        cc.interactionMode = .orbitTurntable
        cc.inertiaEnabled = true
        cc.inertiaFriction = 0.12          // 阻尼：别让惯性滑太久
        // 限制俯仰，避免转到床底下看到一个空洞
        cc.maximumVerticalAngle = 88
        cc.minimumVerticalAngle = -88
        // 关键：不要拿场景包围盒当轨道中心。
        // 热床 220mm 而模型只有十几毫米，围着床转会一直把模型甩到画面边缘。
        cc.automaticTarget = false

        // 手绘支撑：单击拾取面片
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.view = view
        return view
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastFocusToken = -1
        var lastFacetCount = -1
        var parent: ViewportView?
        weak var view: SCNView?

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard let p = parent, p.paintingSupport, let v = g.view as? SCNView else { return }
            let pt = g.location(in: v)
            // SCNHitTestResult.faceIndex 就是我们建 SCNGeometry 时三角形的序号，
            // 与 mesh.indices 的顺序一致（每 3 个索引一个面）。
            let hits = v.hitTest(pt, options: [
                .searchMode: SCNHitTestSearchMode.all.rawValue,
                .ignoreHiddenNodes: true
            ])
            for h in hits where h.node.name == SceneBuilder.modelName {
                if h.faceIndex >= 0 { p.onPaint?(h.faceIndex) }
                break
            }
        }
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.parent = self
        // 绘制模式下必须锁住相机，否则单击会被识别成旋转/缩放
        view.allowsCameraControl = !paintingSupport

        if let sc = view.scene, let m = mesh,
           context.coordinator.lastFacetCount != supportFacets.count {
            context.coordinator.lastFacetCount = supportFacets.count
            SceneBuilder.updateSupportHighlight(scene: sc, mesh: m, facets: supportFacets)
        }

        if view.scene !== scene {
            view.scene = scene
            if scene?.rootNode.childNode(withName: SceneBuilder.cameraName,
                                         recursively: true) != nil {
                // 顺带把相机复位并把轨道中心对准模型
                SceneBuilder.focusCamera(on: view)
            }
        }
        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            SceneBuilder.focusCamera(on: view)
        }
        applyVisibility(to: view)
    }

    private func applyVisibility(to view: SCNView) {
        guard let root = view.scene?.rootNode else { return }

        if let model = root.childNode(withName: SceneBuilder.modelName, recursively: true) {
            model.isHidden = showToolpaths
        }

        guard let toolpaths = root.childNode(withName: SceneBuilder.toolpathName,
                                             recursively: true) else { return }
        toolpaths.isHidden = !showToolpaths

        guard showToolpaths else { return }
        toolpaths.enumerateChildNodes { node, _ in
            guard let name = node.name,
                  name.hasPrefix("layer_"),
                  let index = Int(name.dropFirst("layer_".count)) else { return }
            node.isHidden = index > maxVisibleLayer
        }
    }
}
