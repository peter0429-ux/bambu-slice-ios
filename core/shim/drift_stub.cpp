//
//  drift_stub.cpp —— 补齐「上游新增、而 iOS 端没有移植」的符号
//
//  背景：core/sources.txt 是一份**固定的**源文件快照（185 个文件），
//  而 CI 每次都拉 BambuStudio master。上游一加新功能，就会在已编译的
//  .o 里留下对新文件的引用，链接时表现为 Undefined symbols。
//
//  实测缺的 7 组符号里，只有 STEP / MeshBoolean / nanosvg 属于「功能不可用」，
//  其余要么是 GUI/网络侧（Http、日志加密），要么是 macOS 专有（MacUtils）。
//  这里按「不崩、可预期」的原则补：
//    · 能返回空值的返回空值
//    · 不能返回的抛异常（而不是让链接器报错，或更糟——跳空指针）
//
//  ⚠️ 所有 stub 必须 include 真实头文件，绝不手写签名。
//     之前 apply_fuzzy_skin 就是因为手写签名（返回 void 而实际返回 Polygon）
//     链接通过但运行时堆损坏，排查了很久。
//

#include <stdexcept>
#include <string>
#include <vector>

#include "libslic3r/Model.hpp"
#include "libslic3r/MeshBoolean.hpp"
#include "libslic3r/MacUtils.hpp"

// STEP 头依赖 OCCT 类型；core/shim 下已有 fake OCCT 头，能编过。
#include "libslic3r/Format/STEP.hpp"

namespace Slic3r {

// ── STEP 导入（依赖 OCCT，未移植）──────────────────────────────
// 调用方只有 Model::read_from_step，即用户打开 .step/.stp 时才会走到。
// 直接抛异常，比返回空模型更清楚。
Step::Step(std::string, ImportStepProgressFn, StepIsUtf8Fn) {
    throw std::runtime_error("STEP 导入未支持（iOS 版未移植 OCCT）");
}

Step::~Step() {}

Step::Step_Status Step::load() {
    throw std::runtime_error("STEP 导入未支持（iOS 版未移植 OCCT）");
}

Step::Step_Status Step::mesh(Model *, bool &, bool, double, double) {
    throw std::runtime_error("STEP 导入未支持（iOS 版未移植 OCCT）");
}

// ── 网格布尔（依赖 CGAL + mcut，未移植）────────────────────────
// ModelObject 的分割/合并会用到；切片主路径不用。
namespace MeshBoolean {
namespace cgal {
std::vector<TriangleMesh> segment(const TriangleMesh &, double, int) { return {}; }
} // namespace cgal

namespace mcut {
void make_boolean(const TriangleMesh &, const TriangleMesh &,
                  std::vector<TriangleMesh> &, const std::string &,
                  const BooleanCancelCB &, const BooleanProgressCB &,
                  const BooleanFailedCB &) {
    throw std::runtime_error("网格布尔运算未支持（iOS 版未移植 mcut）");
}
} // namespace mcut
} // namespace MeshBoolean

// ── macOS 专有：文件名日志开关 ────────────────────────────────
bool is_macos_support_boost_add_file_log() { return false; }

// ── 日志加密（Bambu 私有上传协议，用不到）──────────────────────
namespace BBL_Encrypt {

bool AES256CBC_Encrypt(unsigned char *, unsigned int, unsigned char *,
                       unsigned int &out_len, const std::string &,
                       const std::string &) {
    out_len = 0;
    return false;
}

bool AES256CBC_Decrypt(unsigned char *, unsigned int, unsigned char *,
                       unsigned int &out_len, const std::string &,
                       const std::string &) {
    out_len = 0;
    return false;
}

} // namespace BBL_Encrypt

// ── 自交线求交（Emboss 的文字浮雕修复用，未移植）────────────────
std::vector<Line> get_intersections(const std::vector<ExPolygon> &) {
    return {};
}

} // namespace Slic3r
