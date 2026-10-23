import SceneKit
import UIKit
import simd

/// 场景构建。约定：
/// - 3D 数据是 Z 轴朝上（打印机坐标系），SceneKit 是 Y 朝上，
///   所以所有内容都挂在旋转 -90° 的 container 下，相机也挂在里面。
/// - 节点命名固定："camera" / "model" / "toolpaths" / userData["layer"]。
enum SceneBuilder {

    static let cameraName = "camera"
    static let modelName = "model"
    static let toolpathName = "toolpaths"

    // MARK: - 入口

    static func buildScene(mesh: Mesh?, layers: [ToolpathLayer], settings: SliceSettings) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.055, green: 0.062, blue: 0.078, alpha: 1)

        let container = SCNNode()
        container.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        container.name = "container"
        scene.rootNode.addChildNode(container)

        let boundsMin = mesh?.boundsMin ?? SIMD3(0, 0, 0)
        let boundsMax = mesh?.boundsMax ?? SIMD3(Float(settings.bedWidth),
                                                 Float(settings.bedDepth), 0)
        let center = (boundsMin + boundsMax) * 0.5

        container.addChildNode(bedNode(settings: settings))
        addLights(to: container)
        addCamera(to: container, center: center, radius: radius(boundsMin, boundsMax))

        if let mesh {
            let node = meshNode(mesh: mesh)
            node.name = modelName
            container.addChildNode(node)
        }

        if !layers.isEmpty {
            let root = SCNNode()
            root.name = toolpathName
            for (i, layer) in layers.enumerated() {
                guard let n = toolpathNode(layer: layer, index: i) else { continue }
                root.addChildNode(n)
            }
            container.addChildNode(root)
        }

        return scene
    }

    // MARK: - 零件

    private static func radius(_ lo: SIMD3<Float>, _ hi: SIMD3<Float>) -> Float {
        max(simd_length(hi - lo) * 0.5, 30)
    }

    private static func meshNode(mesh: Mesh) -> SCNNode {
        // 顶点数据直接走 buffer，不经过 SCNVector3 数组（几十万顶点会卡）。
        // 注意 SIMD3<Float> 的 stride 是 16 字节（不是 12），dataStride 必须跟着它走。
        let vertexData = mesh.positions.withUnsafeBufferPointer { Data(buffer: $0) }
        let vertexSource = SCNGeometrySource(data: vertexData,
                                            semantic: .vertex,
                                            vectorCount: mesh.positions.count,
                                            usesFloatComponents: true,
                                            componentsPerVector: 3,
                                            bytesPerComponent: MemoryLayout<Float>.size,
                                            dataOffset: 0,
                                            dataStride: MemoryLayout<SIMD3<Float>>.stride)

        let indexData = mesh.indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let element = SCNGeometryElement(data: indexData,
                                         primitiveType: .triangles,
                                         primitiveCount: mesh.indices.count / 3,
                                         bytesPerIndex: MemoryLayout<UInt32>.size)

        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])

        let material = SCNMaterial()
        material.lightingModel = .blinn
        material.diffuse.contents = UIColor(red: 0.60, green: 0.76, blue: 0.90, alpha: 1)
        material.specular.contents = UIColor(white: 0.35, alpha: 1)
        material.shininess = 0.35
        material.isDoubleSided = true
        geometry.materials = [material]

        return SCNNode(geometry: geometry)
    }

    private static func toolpathNode(layer: ToolpathLayer, index: Int) -> SCNNode? {
        guard !layer.segments.isEmpty else { return nil }

        var vertices = [Float]()
        var colors = [Float]()
        var indices = [UInt32]()
        vertices.reserveCapacity(layer.segments.count * 6)
        colors.reserveCapacity(layer.segments.count * 8)
        indices.reserveCapacity(layer.segments.count * 2)

        for seg in layer.segments {
            let (r, g, b) = seg.feature.rgb
            for p in [seg.a, seg.b] {
                indices.append(UInt32(vertices.count / 3))
                vertices.append(p.x); vertices.append(p.y); vertices.append(p.z)
                colors.append(r); colors.append(g); colors.append(b); colors.append(1)
            }
        }

        let vData = vertices.withUnsafeBufferPointer { Data(buffer: $0) }
        let vSource = SCNGeometrySource(data: vData,
                                        semantic: .vertex,
                                        vectorCount: vertices.count / 3,
                                        usesFloatComponents: true,
                                        componentsPerVector: 3,
                                        bytesPerComponent: MemoryLayout<Float>.size,
                                        dataOffset: 0,
                                        dataStride: MemoryLayout<Float>.size * 3)

        let cData = colors.withUnsafeBufferPointer { Data(buffer: $0) }
        let cSource = SCNGeometrySource(data: cData,
                                        semantic: .color,
                                        vectorCount: colors.count / 4,
                                        usesFloatComponents: true,
                                        componentsPerVector: 4,
                                        bytesPerComponent: MemoryLayout<Float>.size,
                                        dataOffset: 0,
                                        dataStride: MemoryLayout<Float>.size * 4)

        let iData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let element = SCNGeometryElement(data: iData,
                                         primitiveType: .line,
                                         primitiveCount: layer.segments.count,
                                         bytesPerIndex: MemoryLayout<UInt32>.size)

        let geometry = SCNGeometry(sources: [vSource, cSource], elements: [element])
        let material = SCNMaterial()
        material.lightingModel = .constant          // 顶点色直接出，不受光照影响
        material.diffuse.contents = UIColor.white
        material.isDoubleSided = true
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        // 用节点名承载层号，避免 userData 的桥接开销，也方便遍历时解析
        node.name = "layer_\(index)"
        return node
    }

    private static func bedNode(settings: SliceSettings) -> SCNNode {
        let w = CGFloat(settings.bedWidth)
        let d = CGFloat(settings.bedDepth)
        let box = SCNBox(width: w, height: d, length: 1.0, chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = UIColor(red: 0.16, green: 0.17, blue: 0.19, alpha: 1)
        box.firstMaterial?.roughness.contents = 0.9
        box.firstMaterial?.lightingModel = .blinn

        let node = SCNNode(geometry: box)
        node.position = SCNVector3(0, 0, -0.5)   // 顶面正好落在 z = 0（热床面）
        node.name = "bed"
        return node
    }

    private static func addLights(to parent: SCNNode) {
        let key = SCNLight()
        key.type = .directional
        key.intensity = 900
        key.castsShadow = false
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-Float.pi / 3.2, 0, -Float.pi / 5)
        parent.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .ambient
        fill.intensity = 420
        fill.color = UIColor(red: 0.72, green: 0.76, blue: 0.85, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fill
        parent.addChildNode(fillNode)
    }

    private static func addCamera(to parent: SCNNode, center: SIMD3<Float>, radius: Float) {
        let camera = SCNCamera()
        camera.zNear = 1
        camera.zFar = radius * 40
        camera.fieldOfView = 42

        let node = SCNNode()
        node.name = cameraName
        node.camera = camera
        node.position = SCNVector3(center.x, center.y - radius * 2.0, center.z + radius * 1.5)
        parent.addChildNode(node)

        let target = SCNNode()
        target.position = SCNVector3(center.x, center.y, center.z)
        parent.addChildNode(target)

        let lookAt = SCNLookAtConstraint(target: target)
        lookAt.isGimbalLockEnabled = true
        node.constraints = [lookAt]
    }
}
