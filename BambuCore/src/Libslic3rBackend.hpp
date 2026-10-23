//
//  Libslic3rBackend.hpp
//  真内核后端的声明。故意不含任何 libslic3r 头文件，这样关闭内核时
//  这个头依然能被其它 TU 包含。
//

#pragma once

#include "SlicerCore.hpp"

namespace bambu::libslic3r_backend {

bool load(const std::string &path, MeshData &out, std::string &error);

bool slice(const std::string &path,
           const Settings &settings,
           const ProgressFn &progress,
           SliceOutput &out,
           std::string &error);

void request_cancel();

} // namespace bambu::libslic3r_backend
