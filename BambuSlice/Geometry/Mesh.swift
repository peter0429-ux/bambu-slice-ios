import Foundation
import simd

/// CPU 侧三角网格。与 SCNGeometry 解耦，方便单测。
struct Mesh {
    let positions: [SIMD3<Float>]
    let indices: [UInt32]
    let boundsMin: SIMD3<Float>
    let boundsMax: SIMD3<Float>

    var triangleCount: Int { indices.count / 3 }
    var size: SIMD3<Float> { boundsMax - boundsMin }
    var center: SIMD3<Float> { (boundsMin + boundsMax) * 0.5 }
    var diagonal: Float { simd_length(size) }

    init(positions: [SIMD3<Float>],
         indices: [UInt32],
         boundsMin: SIMD3<Float> = .zero,
         boundsMax: SIMD3<Float> = .zero) {
        self.positions = positions
        self.indices = indices
        self.boundsMin = boundsMin
        self.boundsMax = boundsMax
    }

    /// 缩放 + 绕 Z 轴旋转后的副本。
    ///
    /// 预览必须和引擎用**同一套**变换，否则会出现
    /// 「预览里 20mm，切出来 10mm」这种错位。
    /// 引擎侧对应 Libslic3rBackend.cpp 的 apply_model_transform()。
    func applying(scale: Double, rotateZDeg: Double) -> Mesh {
        let needScale = abs(scale - 1.0) > 1e-9
        let needRot   = abs(rotateZDeg) > 1e-9
        guard needScale || needRot else { return self }

        let s = Float(scale)
        let rad = Float(rotateZDeg * Double.pi / 180.0)
        let c = cos(rad), sn = sin(rad)

        var out = [SIMD3<Float>]()
        out.reserveCapacity(positions.count)
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var hi = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)

        for p in positions {
            let x = p.x * s, y = p.y * s, z = p.z * s
            let r = SIMD3<Float>(x * c - y * sn, x * sn + y * c, z)
            out.append(r)
            lo = simd_min(lo, r)
            hi = simd_max(hi, r)
        }
        if out.isEmpty { lo = .zero; hi = .zero }
        return Mesh(positions: out, indices: indices, boundsMin: lo, boundsMax: hi)
    }

    /// 从 ObjC++ 桥接层搬数据。整体 copy，不做逐元素装箱。
    init(bridge: BBMesh) {
        let vertexCount = bridge.vertexData.count / MemoryLayout<Float>.size
        var floats = [Float](repeating: 0, count: vertexCount)
        _ = floats.withUnsafeMutableBytes { dst in
            bridge.vertexData.copyBytes(to: dst)
        }

        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(vertexCount / 3)
        var i = 0
        while i + 2 < vertexCount {
            positions.append(SIMD3(floats[i], floats[i + 1], floats[i + 2]))
            i += 3
        }

        let indexCount = bridge.indexData.count / MemoryLayout<UInt32>.size
        var indices = [UInt32](repeating: 0, count: indexCount)
        _ = indices.withUnsafeMutableBytes { dst in
            bridge.indexData.copyBytes(to: dst)
        }

        let bb = bridge.boundingBox
        self.init(positions: positions,
                  indices: indices,
                  boundsMin: SIMD3(Float(bb.minX), Float(bb.minY), Float(bb.minZ)),
                  boundsMax: SIMD3(Float(bb.maxX), Float(bb.maxY), Float(bb.maxZ)))
    }
}
