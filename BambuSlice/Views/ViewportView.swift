import SwiftUI
import SceneKit

/// SceneKit 视口。只负责显示和图层显隐，不持有任何业务状态。
struct ViewportView: UIViewRepresentable {

    let scene: SCNScene?
    /// true 时隐藏实体模型，只显示路径
    let showToolpaths: Bool
    /// 只显示 0...maxVisibleLayer 的层；Int.max 表示全部
    let maxVisibleLayer: Int
    /// 每次数值变化就触发一次「聚焦到模型」。用计数器而不是 Bool，
    /// 这样连点也能每次都生效。
    var focusToken: Int = 0

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
        return view
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastFocusToken = -1
    }

    func updateUIView(_ view: SCNView, context: Context) {
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
