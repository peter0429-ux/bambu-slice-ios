import Foundation
import simd

/// 路径特征。颜色顺序对应 UI 里的图例，改这里就够了。
enum ToolpathFeature: Int, CaseIterable {
    case outerWall
    case innerWall
    case solidInfill
    case infill
    case support
    case skirt
    case other

    var title: String {
        switch self {
        case .outerWall:   return "外壁"
        case .innerWall:   return "内壁"
        case .solidInfill: return "实心填充"
        case .infill:      return "填充"
        case .support:     return "支撑"
        case .skirt:       return "Brim/Skirt"
        case .other:       return "其他"
        }
    }

    /// RGB 0-1。暗色背景下的可读配色，别用纯饱和色，线条会糊成一团。
    var rgb: (Float, Float, Float) {
        switch self {
        case .outerWall:   return (0.98, 0.45, 0.20)
        case .innerWall:   return (0.99, 0.72, 0.28)
        case .solidInfill: return (0.36, 0.78, 0.98)
        case .infill:      return (0.45, 0.55, 0.95)
        case .support:     return (0.55, 0.85, 0.62)
        case .skirt:       return (0.65, 0.65, 0.70)
        case .other:       return (0.75, 0.75, 0.80)
        }
    }
}

struct ToolpathSegment {
    var a: SIMD3<Float>
    var b: SIMD3<Float>
    var feature: ToolpathFeature
}

struct ToolpathLayer {
    var z: Float
    var segments: [ToolpathSegment]
}

/// 把 G-code 解成可渲染的分层线段。
///
/// 不追求解析完整性（不处理圆弧 G2/G3、不处理多挤出机），目标是
/// 「让用户看到路径大致长什么样」，所以只认 G0/G1 的直线段。
enum GCodePreviewParser {

    static func parse(_ gcode: String) -> [ToolpathLayer] {
        var layers: [ToolpathLayer] = []
        layers.reserveCapacity(256)

        var current = ToolpathLayer(z: 0, segments: [])
        current.segments.reserveCapacity(4096)

        var pos = SIMD3<Float>.zero
        var lastE = 0.0
        var relativeE = false
        var feature: ToolpathFeature = .other

        gcode.enumerateLines { line, _ in
            guard !line.isEmpty else { return }

            // ── 注释即元数据 ──
            if line.hasPrefix(";") {
                if line.hasPrefix(";LAYER:") || line.hasPrefix(";LAYER_CHANGE") {
                    flush(&layers, &current)
                    return
                }
                if line.hasPrefix(";Z:") {
                    if let v = Double(line.dropFirst(3)) { current.z = Float(v) }
                    return
                }
                let marker = line.uppercased()
                if marker.hasPrefix(";TYPE:") || marker.hasPrefix("; FEATURE:") || marker.hasPrefix(";FEATURE:") {
                    let raw = line.split(separator: ":", maxSplits: 1)
                        .last.map(String.init) ?? ""
                    feature = classify(raw)
                }
                return
            }

            // ── 状态指令 ──
            if line.hasPrefix("G90") { relativeE = false; return }
            if line.hasPrefix("G91") { relativeE = true; return }
            if line.hasPrefix("M82") { relativeE = false; return }
            if line.hasPrefix("M83") { relativeE = true; return }
            if line.hasPrefix("G92") {
                if let e = value(in: line, letter: "E") { lastE = e }
                return
            }

            guard line.hasPrefix("G1") || line.hasPrefix("G0") else { return }

            let nx = value(in: line, letter: "X")
            let ny = value(in: line, letter: "Y")
            let nz = value(in: line, letter: "Z")
            let ne = value(in: line, letter: "E")

            var next = pos
            if let nx { next.x = Float(nx) }
            if let ny { next.y = Float(ny) }
            if let nz { next.z = Float(nz); current.z = Float(nz) }

            var extruding = false
            if let ne {
                if relativeE {
                    extruding = ne > 1e-9
                    lastE += ne
                } else {
                    extruding = ne > lastE + 1e-9
                    lastE = ne
                }
            }

            if extruding && (next.x != pos.x || next.y != pos.y) {
                current.segments.append(ToolpathSegment(a: pos, b: next, feature: feature))
            }
            pos = next
        }

        flush(&layers, &current)
        return layers
    }

    /// 把当前层收进数组并清空。写成静态函数而不是嵌套闭包，
    /// 避免 enumerateLines 的闭包与局部函数互相捕获造成的独占访问问题。
    private static func flush(_ layers: inout [ToolpathLayer], _ current: inout ToolpathLayer) {
        if !current.segments.isEmpty {
            layers.append(current)
        }
        current.segments.removeAll(keepingCapacity: true)
    }

    // MARK: - 私有

    private static func classify(_ raw: String) -> ToolpathFeature {
        let s = raw.lowercased()
        if s.contains("external") || s.contains("outer") { return .outerWall }
        if s.contains("perimeter") || s.contains("inner") || s.contains("wall") { return .innerWall }
        if s.contains("solid") || s.contains("surface") { return .solidInfill }
        if s.contains("support") { return .support }
        if s.contains("skirt") || s.contains("brim") || s.contains("raft") { return .skirt }
        if s.contains("infill") || s.contains("fill") { return .infill }
        return .other
    }

    /// 从 "G1 X12.3 Y4 E0.5 F1800" 里取某个字母后面的数字。
    private static func value(in line: String, letter: Character) -> Double? {
        var idx = line.startIndex
        while idx < line.endIndex {
            if line[idx] == letter {
                let start = line.index(after: idx)
                var end = start
                while end < line.endIndex,
                      line[end].isNumber || line[end] == "." || line[end] == "-" || line[end] == "+" {
                    end = line.index(after: end)
                }
                if end > start { return Double(line[start..<end]) }
                return nil
            }
            idx = line.index(after: idx)
        }
        return nil
    }
}
