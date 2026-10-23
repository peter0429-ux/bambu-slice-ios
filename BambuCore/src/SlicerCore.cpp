//
//  SlicerCore.cpp
//  后端分发。这里是整个工程里唯一决定「用真内核还是参考引擎」的地方。
//

#include "SlicerCore.hpp"

#include <atomic>

#include "MiniSlicer.hpp"

#if BAMBU_CORE_ENABLED
#  include "Libslic3rBackend.hpp"
#endif

namespace bambu {

struct SlicerCore::Impl {
    std::atomic<bool> cancel{false};
};

SlicerCore::SlicerCore() : m_impl(new Impl()) {}
SlicerCore::~SlicerCore() = default;

bool SlicerCore::core_available() {
#if BAMBU_CORE_ENABLED
    return true;
#else
    return false;
#endif
}

std::string SlicerCore::core_version() {
#if BAMBU_CORE_ENABLED
    return std::string("libslic3r (Bambu Studio)");
#else
    return std::string("mini-ref 0.1 (未链接 libslic3r)");
#endif
}

bool SlicerCore::load(const std::string &path, MeshData &out, std::string &error) {
#if BAMBU_CORE_ENABLED
    // libslic3r 也带 STL/OBJ 读取，但走它意味着要先构造 Model 对象；
    // 预渲染这块用自带的解析器更快、零分配抖动，也不影响切片结果。
    // 需要 3MF / STEP 时在这里切到 libslic3r_backend::load()。
    return mini::load(path, out, error);
#else
    return mini::load(path, out, error);
#endif
}

bool SlicerCore::slice(const std::string &path,
                       const Settings &settings,
                       const ProgressFn &progress,
                       SliceOutput &out,
                       std::string &error) {
    m_impl->cancel.store(false);

#if BAMBU_CORE_ENABLED
    const bool ok = libslic3r_backend::slice(path, settings, progress, out, error);
    if (!ok && m_impl->cancel.load()) error = "已取消";
    return ok;
#else
    return mini::slice(path, settings, progress, out, error);
#endif
}

void SlicerCore::request_cancel() {
    m_impl->cancel.store(true);
#if BAMBU_CORE_ENABLED
    libslic3r_backend::request_cancel();
#else
    mini::request_cancel();
#endif
}

} // namespace bambu
