import Foundation

/// G-code 后处理：在指定层插入暂停。
///
/// 用途：换色（暂停后手动换料）、埋入螺母/磁铁、检查打印质量。
///
/// Bambu 机器的暂停宏是 `M400 U1`：先等运动队列清空，再挂起等用户确认。
///
/// 插入位置很关键：必须落在**该层抬 Z 之后、开始挤出之前**。
/// 如果插在层注释后面（Z 还没抬），暂停时喷嘴仍停在上一层的高度，
/// 用户一碰就容易刮到已打好的部分。
enum GCodePostProcessor {

    /// 在指定层插入暂停。
    ///
    /// - Parameters:
    ///   - gcode: 引擎输出的 G-code
    ///   - layers: 层号集合，**从 1 开始**（第 1 层 = 第一个 CHANGE_LAYER 之后）
    /// - Returns: 处理后的 G-code，以及实际插入的暂停数量
    ///   （数量少于请求时说明该层号超出模型层数）
    static func insertPauses(_ gcode: String, atLayers layers: Set<Int>) -> (String, Int) {
        guard !layers.isEmpty else { return (gcode, 0) }

        var out: [String] = []
        out.reserveCapacity(4096)

        var layer = 0                    // 当前层号，遇到第一个层标记后变 1
        var pending: Int? = nil          // 等待在抬 Z 之后插入的层号
        var inserted = 0

        for raw in gcode.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            out.append(line)

            // ── 层标记 ──
            // Bambu 写 "; CHANGE_LAYER"；其它分支写 ";LAYER_CHANGE" 或 ";LAYER:3"
            if line.contains("CHANGE_LAYER") || line.hasPrefix(";LAYER") {
                layer += 1
                if layers.contains(layer) { pending = layer }
                continue
            }

            // ── 抬 Z 的移动指令（插入点）──
            if let l = pending,
               line.hasPrefix("G1") || line.hasPrefix("G0") {
                let tokens = line.split(separator: " ")
                if tokens.contains(where: { $0.hasPrefix("Z") }) {
                    out.append("M400 U1 ; 用户暂停：第 \(l) 层")
                    inserted += 1
                    pending = nil
                }
            }
        }

        return (out.joined(separator: "\n"), inserted)
    }
}
