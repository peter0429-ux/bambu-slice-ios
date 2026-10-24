//
//  fuzzyskin_stub.cpp —— 模糊皮肤（Fuzzy Skin）的空实现
//
//  FuzzySkin.cpp 依赖 libnoise（Perlin 噪声库，Bambu 走外部依赖拉取）。
//  模糊皮肤是可选的表面处理效果，不影响切片正确性，所以这里顶掉。
//
//  为什么不 include FuzzySkin.hpp：那个头可能又拉进 libnoise 的东西，
//  所以这里只按链接符号里出现的签名手写前置声明，保证 ABI 对得上。
//

#include <cstddef>
#include <vector>

namespace Slic3r {

class PrintRegionConfig;
struct Polygon;
struct PerimeterRegion;
namespace Arachne { class ExtrusionLine; }

// 对应 PerimeterGenerator 里两处调用：
//   对 Arachne 生成的挤出线做模糊化
//   对经典 PerimeterGenerator 的 Polygon 做模糊化
void apply_fuzzy_skin(const Arachne::ExtrusionLine &,
                      const PrintRegionConfig &,
                      const std::vector<PerimeterRegion> &,
                      unsigned long,
                      unsigned long,
                      bool,
                      double) {}

void apply_fuzzy_skin(const Polygon &,
                      const PrintRegionConfig &,
                      const std::vector<PerimeterRegion> &,
                      unsigned long,
                      unsigned long,
                      bool,
                      double) {}

} // namespace Slic3r
