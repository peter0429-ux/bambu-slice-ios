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

#include <cstdio>
#include <string>

#include "libslic3r/Format/AssimpImport.hpp"

namespace Slic3r {

bool load_assimp_textured_model(const std::string & /*path*/,
                                TexturedMesh & /*out*/,
                                std::string *error_message) {
    if (error_message)
        *error_message = "iOS 版本未编译 assimp，暂不支持该模型格式（请用 STL / 3MF / OBJ）";
    return false;
}

// assimp 导入流程里还会用到这两个工具函数（Model::read_from_file 无条件引用）：
//   make_temp_stl_with_modelio  把模型转成临时 STL 供 assimp 读
//   delete_temp_file            删掉那个临时文件
// 我们不走 assimp 分支，第一个返回空串表示「没能生成」，调用方会据此报错。
std::string make_temp_stl_with_modelio(const std::string & /*path*/) {
    return std::string();
}

void delete_temp_file(const std::string &path) {
    if (!path.empty())
        std::remove(path.c_str());
}

} // namespace Slic3r
