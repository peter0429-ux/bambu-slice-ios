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
        // 模型会被平移到底板中心（见下面 meshNode 的 offset），
        // 所以取景中心也必须用平移后的位置，不能用 STL 原始包围盒中心。
        let modelHeight = boundsMax.z - boundsMin.z
        let center = SIMD3<Float>(Float(settings.bedWidth) * 0.5,
                                  Float(settings.bedDepth) * 0.5,
                                  modelHeight * 0.5)

        container.addChildNode(bedNode(settings: settings))
        addLights(to: container)
        addCamera(to: container, center: center, radius: radius(boundsMin, boundsMax))

        if let mesh {
            let node = meshNode(mesh: mesh)
            node.name = modelName

            // ⚠️ 预览里的模型位置必须和 libslic3r 实际切片时的位置一致。
            //    切片那边会做 place_on_bed()：XY 平移到热床中心、Z 让最低点落到 0。
            //    但 Swift 手上的 mesh 是 STL 的原始坐标（可能在任意位置、悬空），
            //    不补这个平移就会出现「预览里模型飘在半空、偏在一边，
            //    而切片结果却在板子正中」的错位。
            let offsetX = Float(settings.bedWidth) * 0.5 - (boundsMin.x + boundsMax.x) * 0.5
            let offsetY = Float(settings.bedDepth) * 0.5 - (boundsMin.y + boundsMax.y) * 0.5
            let offsetZ = -boundsMin.z
            node.position = SCNVector3(offsetX, offsetY, offsetZ)

            container.addChildNode(node)
        }

        if !layers.isEmpty {
            let root = SCNNode()
            root.name = toolpathName
            let lineWidth = Float(settings.nozzleDiameter)
            for (i, layer) in layers.enumerated() {
                guard let n = toolpathNode(layer: layer, index: i, lineWidth: lineWidth) else { continue }
                root.addChildNode(n)
            }
            container.addChildNode(root)
        }

        return scene
    }

    // MARK: - 零件

    private static func radius(_ lo: SIMD3<Float>, _ hi: SIMD3<Float>) -> Float {
        // 下限只用来兜住退化情况（点/空网格）。不要写大值：
        // 曾经写 30mm、后来 8mm，结果小零件被当成 8mm 取景，屏幕上只有一小块。
        // 这个值必须和 focusCamera 里的一致，否则「聚焦」和「初始视角」不一样。
        max(simd_length(hi - lo) * 0.5, 1)
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

    /// 把一层路径画成**有宽度**的带状。
    ///
    /// 之前用 SCNGeometryElement.primitiveType = .line 渲染，线宽恒为 1 像素，
    /// 看上去是「细线」，完全体现不出真实挤出宽度（0.4mm 左右），
    /// 也没法判断填充密度和壁厚是否合理。
    ///
    /// 现在每条线段扩成一个矩形（2 个三角形），宽度 = 喷嘴直径。
    private static func toolpathNode(layer: ToolpathLayer, index: Int,
                                     lineWidth: Float) -> SCNNode? {
        guard !layer.segments.isEmpty else { return nil }

        let halfW = max(lineWidth, 0.05) * 0.5

        var vertices = [Float]()
        var colors = [Float]()
        var indices = [UInt32]()
        // 每条线段 4 顶点 / 6 索引
        vertices.reserveCapacity(layer.segments.count * 12)
        colors.reserveCapacity(layer.segments.count * 16)
        indices.reserveCapacity(layer.segments.count * 6)

        let up = SIMD3<Float>(0, 0, 1)   // 同层路径共面，Z 一定不与走向平行
        for seg in layer.segments {
            let d = seg.b - seg.a
            let len = simd_length(d)
            guard len > 1e-6 else { continue }
            let dir = d / len
            var perp = simd_cross(dir, up)
            let plen = simd_length(perp)
            guard plen > 1e-6 else { continue }
            perp = (perp / plen) * halfW

            let a0 = seg.a - perp, a1 = seg.a + perp
            let b0 = seg.b - perp, b1 = seg.b + perp

            let (r, g, b) = seg.feature.rgb
            let base = UInt32(vertices.count / 3)
            for p in [a0, a1, b1, b0] {
                vertices.append(p.x); vertices.append(p.y); vertices.append(p.z)
                colors.append(r); colors.append(g); colors.append(b); colors.append(1)
            }
            // 两个三角形拼成矩形
            indices.append(contentsOf: [base, base + 1, base + 2,
                                        base, base + 2, base + 3])
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
                                         primitiveType: .triangles,
                                         primitiveCount: indices.count / 3,
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
        // 打印机坐标系里热床是从 (0,0) 到 (w,d)，中心在 (w/2, d/2)。
        // 模型也被摆到这个中心，所以板子必须跟着移过来，否则模型会跑到板外。
        plate.position = SCNVector3(Float(w) * 0.5, Float(d) * 0.5, -0.5)
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
    ///
    /// 两个坑（都踩过）：
    ///
    /// 1. `view.allowsCameraControl = true` 时，`SCNCameraController` 自己维护
    ///    相机状态。用户拖动过之后直接写 position 只管一帧，下一帧会被覆盖，
    ///    表现为「点了没反应」。所以写位姿前后要临时关掉控制。
    ///
    /// 2. **不要用 `look(at:)`，也不要去动 `cc.pointOfView` / `cc.stopInertia()`。**
    ///    相机挂在旋转了 -90° 的 container 下，`look(at:)` 的 up 向量与父节点
    ///    坐标系不一致，算出来的朝向可能是反的（表现：画面全黑）；
    ///    而给控制器塞 pointOfView 会让它用内部距离/角度重算位姿，同样会跑飞。
    ///    这里改成自己用叉乘算基向量，直接写世界变换，结果完全确定。
    static func focusCamera(on view: SCNView) {
        guard let scene = view.scene,
              let cam = scene.rootNode.childNode(withName: cameraName, recursively: true),
              let container = cam.parent else { return }

        // ── 1. 取景中心与尺度（container 的 Z-up 坐标）──
        var center = SCNVector3(Float(220) * 0.5, Float(220) * 0.5, 10)
        var radius: Float = 30
        if let model = scene.rootNode.childNode(withName: modelName, recursively: true) {
            let (lo, hi) = model.boundingBox
            let p = model.position
            let dx = max(hi.x - lo.x, 0)
            let dy = max(hi.y - lo.y, 0)
            let dz = max(hi.z - lo.z, 0)
            if dx + dy + dz > 1e-3 {          // 包围盒非空才用
                center = SCNVector3((lo.x + hi.x) * 0.5 + p.x,
                                    (lo.y + hi.y) * 0.5 + p.y,
                                    (lo.z + hi.z) * 0.5 + p.z)
                // 下限只兜退化情况；取景必须严格跟着模型尺寸走，
                // 否则小零件会被放大成一个"最小尺寸"，显得特别小。
                radius = max(simd_length(SIMD3<Float>(dx, dy, dz)) * 0.5, 1)
            }
        }

        // ── 2. 取景距离：按**实际宽高比**同时保证宽、高都装得下 ──
        //
        // 这里之前踩过一个坑：`SCNCamera.fieldOfView` 在
        // `projectionDirection == .automatic`（默认）下，竖屏时是作用在
        // **水平**方向的。于是竖直 FOV 被放大到 70° 以上，模型看起来又小又偏；
        // 而按「竖直 FOV = 40°」推距离，横向又装不下、被裁掉。
        //
        // 现在显式设成 .vertical，用包围球半径 + sin 求距离，宽高取较大者。
        if cam.camera == nil { cam.camera = SCNCamera() }
        cam.camera?.projectionDirection = .vertical
        cam.camera?.zNear = Double(max(radius * 0.02, 0.05))   // zNear/zFar 是 Double
        cam.camera?.zFar = Double(max(radius * 200, 5000))

        let fovY = Float(cam.camera?.fieldOfView ?? 40) * .pi / 180
        let aspect = Float(view.bounds.width) / max(Float(view.bounds.height), 1)
        // bounds 还没布局时 width/height 可能是 0，给个手机竖屏的保守值
        let safeAspect = (aspect > 0.1 && aspect < 10) ? aspect : 0.46
        let fovX = 2 * atan(tan(fovY * 0.5) * safeAspect)

        let sphereR = radius                     // 包围球半径 = 对角线一半
        let distV = sphereR / max(sin(fovY * 0.5), 0.05)
        let distH = sphereR / max(sin(fovX * 0.5), 0.05)
        let dist = max(distV, distH) * 1.08      // 8% 留白，别贴着边

        let elev: Float = .pi / 5                // 36° 俯角
        let azim: Float = .pi / 4                // 45° 方位
        let dir = SIMD3<Float>(cos(elev) * sin(azim),
                               -cos(elev) * cos(azim),
                               sin(elev))        // container 的 Z-up 方向
        let eye = SCNVector3(center.x + dir.x * dist,
                             center.y + dir.y * dist,
                             center.z + dir.z * dist)
        let worldEye    = container.convertPosition(eye, to: nil)
        let worldTarget = container.convertPosition(center, to: nil)

        // ── 3. 自己算朝向矩阵（相机看向自身 -Z）──
        let eyeV = SIMD3<Float>(worldEye.x, worldEye.y, worldEye.z)
        let tgtV = SIMD3<Float>(worldTarget.x, worldTarget.y, worldTarget.z)
        var forward = tgtV - eyeV
        let flen = simd_length(forward)
        guard flen > 1e-5 else { return }
        forward /= flen

        let worldUp = SIMD3<Float>(0, 1, 0)
        var right = simd_cross(forward, worldUp)
        if simd_length(right) < 1e-4 {        // 视线与 up 平行时退化，换个参考轴
            right = simd_cross(forward, SIMD3<Float>(1, 0, 0))
        }
        right = simd_normalize(right)
        let up = simd_normalize(simd_cross(right, forward))

        var m = matrix_identity_float4x4
        m.columns.0 = SIMD4<Float>(right, 0)
        m.columns.1 = SIMD4<Float>(up, 0)
        m.columns.2 = SIMD4<Float>(-forward, 0)   // 相机朝 -Z
        m.columns.3 = SIMD4<Float>(eyeV, 1)

        // ── 4. 应用：关控制 → 写变换 → 同步轨道中心 → 开控制 ──
        let wasEnabled = view.allowsCameraControl
        view.allowsCameraControl = false

        cam.simdWorldTransform = m

        let cc = view.defaultCameraController
        cc.target = worldTarget               // 只同步轨道中心，不碰 pointOfView
        cc.automaticTarget = false

        view.pointOfView = cam
        view.allowsCameraControl = wasEnabled
        view.setNeedsDisplay()
    }


    static let supportHighlightName = "supportHighlight"

    /// 把用户点选的面片画成半透明红色覆盖层。
    /// 每次点选都会重建这个节点（几百个三角形，开销可以忽略）。
    static func updateSupportHighlight(scene: SCNScene, mesh: Mesh, facets: Set<Int>) {
        guard let container = scene.rootNode.childNode(withName: "container", recursively: false) else { return }
        container.childNode(withName: supportHighlightName, recursively: false)?.removeFromParentNode()
        guard !facets.isEmpty else { return }

        let idxArr = mesh.indices
        var verts: [Float] = []
        verts.reserveCapacity(facets.count * 9)
        for f in facets {
            let base = f * 3
            guard base + 2 < idxArr.count else { continue }
            for k in 0..<3 {
                let vi = Int(idxArr[base + k])
                guard vi < mesh.positions.count else { continue }
                let p = mesh.positions[vi]
                verts.append(p.x); verts.append(p.y); verts.append(p.z)
            }
        }
        guard verts.count >= 9 else { return }

        let vData = verts.withUnsafeBufferPointer { Data(buffer: $0) }
        let vSource = SCNGeometrySource(data: vData,
                                        semantic: .vertex,
                                        vectorCount: verts.count / 3,
                                        usesFloatComponents: true,
                                        componentsPerVector: 3,
                                        bytesPerComponent: MemoryLayout<Float>.size,
                                        dataOffset: 0,
                                        dataStride: MemoryLayout<Float>.size * 3)
        let indices: [UInt32] = (0..<UInt32(verts.count / 3)).map { $0 }
        let iData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let element = SCNGeometryElement(data: iData,
                                         primitiveType: .triangles,
                                         primitiveCount: indices.count / 3,
                                         bytesPerIndex: MemoryLayout<UInt32>.size)
        let geo = SCNGeometry(sources: [vSource], elements: [element])
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = UIColor(red: 1.0, green: 0.25, blue: 0.30, alpha: 0.75)
        mat.isDoubleSided = true
        // 稍微抬起一点，避免和模型面 z-fighting
        mat.writesToDepthBuffer = false
        geo.materials = [mat]

        let node = SCNNode(geometry: geo)
        node.name = supportHighlightName
        node.renderingOrder = 10
        // 跟模型用同一个平移（模型居中到床面）
        if let model = container.childNode(withName: modelName, recursively: true) {
            node.position = model.position
        }
        container.addChildNode(node)
    }
}
