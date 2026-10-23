//
//  MiniSlicer.hpp
//  不依赖任何第三方库的参考实现。
//
//  它存在的唯一目的：让整个 App 在 libslic3r 还没编出来的阶段就能跑通
//  「导入模型 → 切片 → 预览路径 → 导出 G-code」全链路，用来验证桥接层、
//  渲染层和文件流程。
//
//  ⚠️ 它不是生产切片器：
//     - 只做单面壁 + 直线填充，不做支撑 / 桥接 / 可变层高 / 接缝优化
//     - 不做过孔修复、不做流形检查
//     - 输出的 G-code 是 RepRap/Marlin 风味，不能直接丢给 Bambu 机器打印
//

#pragma once

#include "SlicerCore.hpp"

namespace bambu::mini {

bool load(const std::string &path, MeshData &out, std::string &error);

bool slice(const std::string &path,
           const Settings &settings,
           const ProgressFn &progress,
           SliceOutput &out,
           std::string &error);

void request_cancel();

} // namespace bambu::mini
