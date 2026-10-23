import SwiftUI
import SceneKit

/// SceneKit 视口。只负责显示和图层显隐，不持有任何业务状态。
struct ViewportView: UIViewRepresentable {

    let scene: SCNScene?
    /// true 时隐藏实体模型，只显示路径
    let showToolpaths: Bool
    /// 只显示 0...maxVisibleLayer 的层；Int.max 表示全部
    let maxVisibleLayer: Int

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.055, green: 0.062, blue: 0.078, alpha: 1)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = false
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        if view.scene !== scene {
            view.scene = scene
            if let camera = scene?.rootNode.childNode(withName: SceneBuilder.cameraName,
                                                      recursively: true) {
                view.pointOfView = camera
            }
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
