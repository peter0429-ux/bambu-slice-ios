//
//  format_stub.cpp —— 只依赖重库的模型加载器，用空实现顶掉
//
//  Format/ 下的加载器里，这几个在 iOS 上不值得移植：
//    - STEP.cpp        需要 OCCT（几十 MB，且文字浮雕也用不到）
//    - AssimpImport.cpp 需要 assimp（FBX/GLTF/DAE 等，App 用不到）
//    - SL1.cpp         需要 SLA 子系统
//    - svg.cpp         SVG 导出，与切片无关
//
//  但 Model::read_from_file() 会无条件引用 assimp 那个入口，
//  所以链接需要符号存在。这里给出「明确失败」的实现：
//  真要用这些格式时，用户会看到清楚的错误提示，而不是崩溃。
//

#include "libslic3r/Format/AssimpImport.hpp"

namespace Slic3r {

bool load_assimp_textured_model(const std::string & /*path*/,
                                TexturedMesh & /*out*/,
                                std::string *error_message) {
    if (error_message)
        *error_message = "iOS 版本未编译 assimp，暂不支持该模型格式（请用 STL / 3MF / OBJ）";
    return false;
}

} // namespace Slic3r
