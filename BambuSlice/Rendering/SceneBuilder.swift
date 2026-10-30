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

        // 底色比背景亮一档：原来 (0.16,0.17,0.19) 跟背景 (0.055,0.062,0.078)
        // 太接近，在手机上几乎看不出来，像是没渲染。
        let box = SCNBox(width: w, height: d, length: 1.0, chamferRadius: 0.8)
        box.firstMaterial?.diffuse.contents = UIColor(red: 0.20, green: 0.22, blue: 0.26, alpha: 1)
        box.firstMaterial?.roughness.contents = 0.95
        box.firstMaterial?.lightingModel = .blinn

        let plate = SCNNode(geometry: box)
        plate.position = SCNVector3(0, 0, -0.5)   // 顶面正好落在 z = 0（热床面）
        plate.name = "bed"

        // 网格：每 10mm 一条，没有参照物时用户判断不了模型多大
        plate.addChildNode(gridNode(width: Float(w), depth: Float(d), step: 10, z: 0.5))
        return plate
    }

    /// 床面网格线。挂在 bed 节点下，所以 z 用 0.5（bed 顶面在父坐标系 z=0，
    /// 而 bed 自身中心在 z=-0.5）。
    private static func gridNode(width: Float, depth: Float, step: Float, z: Float) -> SCNNode {
        var verts: [Float] = []
        var idx: [UInt32] = []
        let hw = width * 0.5, hd = depth * 0.5

        func addLine(_ x0: Float, _ y0: Float, _ x1: Float, _ y1: Float) {
            let b = UInt32(verts.count / 3)
            verts.append(contentsOf: [x0, y0, z, x1, y1, z])
            idx.append(contentsOf: [b, b + 1])
        }

        var x = -hw
        while x <= hw + 0.01 { addLine(x, -hd, x, hd); x += step }
        var y = -hd
        while y <= hd + 0.01 { addLine(-hw, y, hw, y); y += step }

        let vData = verts.withUnsafeBufferPointer { Data(buffer: $0) }
        let vSource = SCNGeometrySource(data: vData,
                                        semantic: .vertex,
                                        vectorCount: verts.count / 3,
                                        usesFloatComponents: true,
                                        componentsPerVector: 3,
                                        bytesPerComponent: MemoryLayout<Float>.size,
                                        dataOffset: 0,
                                        dataStride: MemoryLayout<Float>.size * 3)
        let iData = idx.withUnsafeBufferPointer { Data(buffer: $0) }
        let element = SCNGeometryElement(data: iData,
                                         primitiveType: .line,
                                         primitiveCount: idx.count / 2,
                                         bytesPerIndex: MemoryLayout<UInt32>.size)
        let geo = SCNGeometry(sources: [vSource], elements: [element])
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = UIColor(red: 0.34, green: 0.37, blue: 0.42, alpha: 1)
        geo.materials = [mat]
        return SCNNode(geometry: geo)
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

    /// 45° 俯视 + 45° 方位角。关键点：
    ///
    /// 这里**不能**用 SCNLookAtConstraint。约束会在每帧强行改写相机的
    /// transform，而 SCNView.allowsCameraControl 的控制器也在改同一个
    /// transform，两者互相覆盖 —— 表现就是拖不动、或者视角乱跳、
    /// 严重时相机朝向被算成异常值，整个 3D 视图一片空白。
    ///
    /// 正确做法：用 look(at:) 一次性把朝向写好，之后完全交给控制器。
    private static func addCamera(to parent: SCNNode, center: SIMD3<Float>, radius: Float) {
        let camera = SCNCamera()
        // 模型可能只有十几毫米，zNear=1 会把它切掉，必须放小
        camera.zNear = 0.1
        camera.zFar = Double(radius) * 60
        camera.fieldOfView = 40

        let node = SCNNode()
        node.name = cameraName
        node.camera = camera

        let dist = radius * 2.6
        let elev: Float = .pi / 5          // 36° 俯角
        let azim: Float = .pi / 4          // 45° 方位
        let pos = SCNVector3(center.x + dist * cos(elev) * sin(azim),
                             center.y - dist * cos(elev) * cos(azim),
                             center.z + dist * sin(elev))
        node.position = pos
        parent.addChildNode(node)

        let worldTarget = parent.convertPosition(SCNVector3(center.x, center.y, center.z), to: nil)
        node.look(at: worldTarget, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))

    }

    /// 一键回到模型特写。
    ///
    /// 取景框现场从模型包围盒算，而不是记在节点上：
    ///   - SCNNode 没有 userData 属性（那是 SpriteKit 的），存不了
    ///   - 每次切片后模型会换，实时算反而总是对的
    /// 模型的父节点就是 container，所以它的局部坐标就是容器坐标。
    static func focusCamera(on view: SCNView) {
        guard let scene = view.scene,
              let cam = scene.rootNode.childNode(withName: cameraName, recursively: true),
              let container = cam.parent else { return }

        var center = SCNVector3(0, 0, 0)
        var radius: Float = 30
        if let model = scene.rootNode.childNode(withName: modelName, recursively: true) {
            let (lo, hi) = model.boundingBox
            center = SCNVector3((lo.x + hi.x) * 0.5,
                                (lo.y + hi.y) * 0.5,
                                (lo.z + hi.z) * 0.5)
            let diag = SIMD3<Float>(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
            radius = max(simd_length(diag) * 0.5, 30)
        }

        let dist = radius * 2.6
        let elev: Float = .pi / 5        // 36° 俯角
        let azim: Float = .pi / 4        // 45° 方位
        cam.position = SCNVector3(center.x + dist * cos(elev) * sin(azim),
                                  center.y - dist * cos(elev) * cos(azim),
                                  center.z + dist * sin(elev))

        let worldTarget = container.convertPosition(center, to: nil)
        cam.look(at: worldTarget, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))

        view.pointOfView = cam
        view.defaultCameraController.target = worldTarget
        view.setNeedsDisplay()
    }

}
