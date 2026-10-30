//
//  SlicerCore.hpp
//  BambuSlice · 切片内核的纯 C++ 接口
//
//  设计原则：
//  1. 这个头文件不 include 任何 libslic3r / Foundation 头文件，可以同时被
//     ObjC++ 桥接层、单元测试、命令行工具复用。
//  2. 所有 libslic3r 类型都藏在 .cpp 里的 pimpl 后面，避免头文件污染。
//  3. 后端可切换：BAMBU_CORE_ENABLED=1 走 libslic3r，=0 走内置的 mini 参考引擎。
//     两者的输入输出完全一致，上层 Swift 代码不需要知道区别。
//

#pragma once

#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <utility>
#include <vector>

namespace bambu {

struct Bounds {
    double min[3] = {0, 0, 0};
    double max[3] = {0, 0, 0};
};

// 三角汤。iOS 端直接用这块内存建 SCNGeometry。
// vertices 是 x,y,z 连续排布（float32），indices 是 uint32 三角形索引。
struct MeshData {
    std::vector<float>    vertices;
    std::vector<uint32_t> indices;
    Bounds                bounds;
    size_t                triangle_count = 0;

    bool empty() const { return indices.empty(); }
};

// 与 BBSliceSettings 一一对应。单位统一为 mm / 摄氏度。
struct Settings {
    double layer_height       = 0.20;
    double first_layer_height = 0.25;
    double nozzle_diameter    = 0.40;
    double filament_diameter  = 1.75;

    int    wall_loops         = 2;
    double infill_density     = 0.15;   // 0.0 ~ 1.0
    std::string infill_pattern = "grid"; // grid / gyroid / cubic / rectilinear

    bool   support_enabled    = false;
    double support_threshold  = 30.0;   // 悬垂角阈值（度），桌面版默认 30
    /// 用户手绘「强制支撑」的面片索引（对应 STL 的三角形序号）。
    /// 空表示不做手动干预，完全由自动检测决定。
    std::vector<int> support_facets;
    bool   brim_enabled       = false;

    double nozzle_temp        = 220.0;
    double bed_temp           = 60.0;

    // 机型预设。开启真内核后，这个名字会用于查找 vendor bundle 里的打印机预设。
    std::string printer_profile = "Bambu Lab A1 mini";
    double bed_width  = 180.0;
    double bed_depth  = 180.0;
    double bed_height = 180.0;

    // 任意 libslic3r 配置项的直通覆盖（key, 序列化后的值）。
    // UI 里没做的参数都从这里进，不用为每个参数加一列。
    std::vector<std::pair<std::string, std::string>> overrides;
};

struct SliceOutput {
    std::string gcode;

    double duration_seconds  = 0.0;
    double filament_mm       = 0.0;
    double filament_grams    = 0.0;
    size_t layer_count       = 0;

    std::string backend;   // "libslic3r" / "mini-ref"
    std::vector<std::string> warnings;
};

using ProgressFn = std::function<void(float fraction, const std::string &stage)>;

class SlicerCore {
public:
    SlicerCore();
    ~SlicerCore();

    SlicerCore(const SlicerCore &) = delete;
    SlicerCore &operator=(const SlicerCore &) = delete;

    // 是否链接了真正的 libslic3r。false 表示当前是 mini 参考引擎。
    static bool core_available();
    static std::string core_version();

    // 读取 STL(binary/ascii) 或 OBJ，转成三角汤给上层渲染。
    bool load(const std::string &path, MeshData &out, std::string &error);

    // 切片。progress 允许为空。返回 false 时 error 里是给人看的中文/英文说明。
    bool slice(const std::string &path,
               const Settings &settings,
               const ProgressFn &progress,
               SliceOutput &out,
               std::string &error);

    // 尽力而为的取消。真内核下要配合 fork 里的 cancel 钩子，见 docs/PORTING.md。
    void request_cancel();

private:
    struct Impl;
    std::unique_ptr<Impl> m_impl;
};

} // namespace bambu
