//
//  fuzzyskin_stub.cpp —— 模糊皮肤（Fuzzy Skin）的降级实现
//
//  FuzzySkin.cpp 依赖 libnoise（Perlin 噪声库，Bambu 走外部依赖拉取，我们没移植）。
//  模糊皮肤只是可选的表面纹理效果，这里退化成「原样返回」。
//
//  ⚠️ 关键坑（曾经害得 App 崩过一次）：
//     apply_fuzzy_skin 的返回类型是 Polygon / Arachne::ExtrusionLine，**不是 void**。
//     C++ 的符号修饰不含返回类型，所以写成 void 也能链接通过，
//     但调用方会按 Polygon 去读返回值 —— 拿到的是栈上垃圾，
//     用它构造 std::vector<Point> 后析构时 free 非法指针，运行期报
//     ___BUG_IN_CLIENT_OF_LIBMALLOC_POINTER_BEING_FREED_WAS_NOT_ALLOCATED。
//
//     而且 PerimeterGenerator::traverse_loops 里是**无条件调用**：
//         const Polygon polygon = apply_fuzzy_skin(loop.polygon, ...);
//     配置也关不掉。
//
//  所以：include 真实的 FuzzySkin.hpp，让签名自动跟头文件一致，
//  不要再手写签名。
//

#include "libslic3r/PerimeterGenerator.hpp"
#include "libslic3r/FuzzySkin.hpp"
#include "libslic3r/Arachne/utils/ExtrusionLine.hpp"

namespace Slic3r {

Polygon apply_fuzzy_skin(const Polygon &polygon,
                         const PrintRegionConfig & /*base_config*/,
                         const PerimeterRegions & /*perimeter_regions*/,
                         size_t /*layer_idx*/,
                         size_t /*perimeter_idx*/,
                         bool /*is_contour*/,
                         coordf_t /*slice_z*/) {
    return polygon;
}

Arachne::ExtrusionLine apply_fuzzy_skin(const Arachne::ExtrusionLine &extrusion,
                                        const PrintRegionConfig & /*base_config*/,
                                        const PerimeterRegions & /*perimeter_regions*/,
                                        size_t /*layer_idx*/,
                                        size_t /*perimeter_idx*/,
                                        bool /*is_contour*/,
                                        coordf_t /*slice_z*/) {
    return extrusion;
}

} // namespace Slic3r
