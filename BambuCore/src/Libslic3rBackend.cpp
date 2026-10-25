//
//  Libslic3rBackend.cpp
//  真正的切片后端：把 bambu::Settings 翻成 libslic3r 的 DynamicPrintConfig，
//  跑 Print::apply → validate → 导出 G-code。
//
//  ┌──────────────────────────────────────────────────────────────────┐
//  │ 这个文件里与 libslic3r 直接耦合的只有 5 个地方，用 [CP-1]…[CP-5] │
//  │ 标出。升级 Bambu Studio 版本后只需要对齐这 5 处，其余代码不动。  │
//  │ 每个耦合点在 docs/PORTING.md 里有对应 tag 的差异表。              │
//  └──────────────────────────────────────────────────────────────────┘
//
//  编译条件：BAMBU_CORE_ENABLED=1，且 Frameworks/ 下已放好 libslic3r 及其依赖。
//  关闭时本文件是空 TU，不影响工程构建。
//

#include "Libslic3rBackend.hpp"

#if BAMBU_CORE_ENABLED

#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <memory>
#include <mutex>
#include <sstream>
#include <string>
#include <vector>

// ── [CP-1] 头文件路径 ────────────────────────────────────────
// Bambu Studio / PrusaSlicer 都把 libslic3r 放在 src/libslic3r 下，
// 且以 "libslic3r/xxx.hpp" 形式互相引用，所以 include path 指到 src/ 即可。
#include "libslic3r/Model.hpp"
#include <boost/log/core.hpp>

#include "libslic3r/Print.hpp"
#include "libslic3r/PrintConfig.hpp"
#include "libslic3r/libslic3r.h"

// Bambu 分支把 G-code 生成拆成了 GCode::Generator（PrusaSlicer 没有）。
// 有就用，没有就退回 Print::export_gcode()。
#if __has_include("libslic3r/GCode/GCodeGenerator.hpp")
#  include "libslic3r/GCode/GCodeGenerator.hpp"
#  define BBS_HAVE_GCODE_GENERATOR 1
#endif

namespace bambu::libslic3r_backend {
namespace {

std::atomic<bool> g_cancel{false};

// 关掉 boost.log。
//
// 这不是为了"清爽"，是必须的：App 里没有注册任何 sink，但 boost.log 的
// core 默认 logging_enabled() == true，于是每一条
//     BOOST_LOG_TRIVIAL(info) << "..." << log_memory_info();
// 的流式参数**照样会被求值**。而 log_memory_info() 在 iOS 上没有正确实现
// （桌面版读 /proc/self/status 或 Windows API），一求值就踩空指针。
//
// GCode::do_export() 开头就有这么一行，所以切到 75% 之后、导出 G-code 时崩。
// 关掉 enabled 后 record 变无效，for 循环体不执行，参数不会被求值。
void silence_boost_log() {
    static std::once_flag once;
    std::call_once(once, [] {
        boost::log::core::get()->set_logging_enabled(false);
    });
}

// ── 配置拼装 ─────────────────────────────────────────────────

// Bambu 分支和各 fork 的键名不完全一样（比如 PrusaSlicer 的 perimeters 在这里
// 叫 wall_loops，perimeter_generator 叫 wall_generator）。所以这里统一做两件事：
//   1. 键不存在就直接跳过，不当成错误
//   2. 值非法（枚举值拼错等）也跳过，不让它抛到外面把整个切片打断
bool set_str(Slic3r::DynamicPrintConfig &cfg, const char *key, const std::string &value) {
    if (!cfg.has(key)) return false;
    try {
        Slic3r::ConfigSubstitutionContext ctxt{ Slic3r::ForwardCompatibilitySubstitutionRule::Disable };
        cfg.set_deserialize(key, value, ctxt);
        return true;
    } catch (...) {
        return false;
    }
}

void set_double(Slic3r::DynamicPrintConfig &cfg, const char *key, double v) {
    if (!cfg.has(key)) return;
    char buf[64];
    std::snprintf(buf, sizeof(buf), "%.6g", v);
    set_str(cfg, key, buf);
}

void set_int(Slic3r::DynamicPrintConfig &cfg, const char *key, int v) {
    set_str(cfg, key, std::to_string(v));
}

void set_bool(Slic3r::DynamicPrintConfig &cfg, const char *key, bool v) {
    set_str(cfg, key, v ? "1" : "0");
}

void set_bed_shape(Slic3r::DynamicPrintConfig &cfg, double w, double d) {
    const std::string shape =
        "0x0," + std::to_string(w) + "x0," + std::to_string(w) + "x" + std::to_string(d) +
        ",0x" + std::to_string(d);
    // [CP-2] PrusaSlicer 2.6 起 bed_shape 改名为 printable_area；
    //        Bambu 分支两者都可能存在，set_deserialize 对未知 key 会抛异常，
    //        所以用 has() 先探测。老版本用 bed_shape。
    if (cfg.has("printable_area")) set_str(cfg, "printable_area", shape);
    else if (cfg.has("bed_shape")) set_str(cfg, "bed_shape", shape);
}

Slic3r::DynamicPrintConfig make_config(const Settings &s, std::vector<std::string> &warnings) {
    // full_print_config() 会把 PrintConfigDef 里所有键填上默认值。
    // 如果某个 fork 没有这个静态方法，等价写法：
    //     DynamicPrintConfig cfg;
    //     for (const auto &k : Slic3r::PrintConfigDef::instance().keys())
    //         cfg.set_key_value(k, Slic3r::PrintConfigDef::instance().opt(k)->clone());
    Slic3r::DynamicPrintConfig cfg = Slic3r::DynamicPrintConfig::full_print_config();

    // 机器相关。真机上应当从 vendor bundle 的打印机预设 ini 读，这里给最小集合。
    set_str(cfg, "printer_model", s.printer_profile);
    set_double(cfg, "nozzle_diameter", s.nozzle_diameter);
    set_double(cfg, "filament_diameter", s.filament_diameter);
    set_bed_shape(cfg, s.bed_width, s.bed_depth);
    set_double(cfg, "max_print_height", s.bed_height);
    set_str(cfg, "gcode_flavor", "marlin2");   // Bambu 机器用 "marlin2"，老机器 "marlin"
    set_bool(cfg, "use_relative_e_distances", false);
    set_bool(cfg, "silent_mode", true);
    set_int(cfg, "threads", 2);             // 手机上别让 TBB 起满核，热和内存都吃不消

    // 质量
    set_double(cfg, "layer_height", s.layer_height);
    set_double(cfg, "first_layer_height", s.first_layer_height);
    set_int(cfg, "perimeters", s.wall_loops);
    set_double(cfg, "fill_density", s.infill_density * 100.0);   // libslic3r 用百分比
    set_str(cfg, "fill_pattern", s.infill_pattern);
    set_double(cfg, "perimeter_speed", 120);
    set_double(cfg, "infill_speed", 200);
    set_double(cfg, "travel_speed", 400);

    // 温度
    set_double(cfg, "temperature", s.nozzle_temp);
    set_double(cfg, "first_layer_temperature", s.nozzle_temp);
    set_double(cfg, "bed_temperature", s.bed_temp);
    set_double(cfg, "first_layer_bed_temperature", s.bed_temp);

    // ── Bambu 分支特有：耗材/挤出机索引 ────────────────────
    // libslic3r 里大量用 print_config->nozzle_diameter.get_at(wall_filament - 1)
    // 取喷嘴直径。这个值若不是 1，就是 get_at(-1) 越界读，会拿到垃圾宽度，
    // Flow 变成 NaN/0，后续 Arachne 生成零宽挤出线时踩空指针（0x6）。
    set_int(cfg, "wall_filament", 1);
    set_int(cfg, "solid_infill_filament", 1);
    set_int(cfg, "sparse_infill_filament", 1);
    set_int(cfg, "wipe_tower_filament", 1);

    // ── 周界生成器：先用经典算法 ──────────────────────────
    // Arachne（变宽挤出）对参数完整性要求很高，缺项就崩；经典算法稳得多。
    // 主体流程跑通、参数补齐后再考虑切回 "arachne"。
    if (!set_str(cfg, "wall_generator", "classic") &&
        !set_str(cfg, "wall_generator", "Classic"))
        warnings.push_back("无法指定 wall_generator，周界算法可能仍是 Arachne");

    // ── 线宽：显式给值 ────────────────────────────────────
    // 不给时引擎会用 layer_height 推算，推不好会得到 0 宽度，之后做除就出 NaN。
    // 直接给喷嘴直径最稳。
    set_double(cfg, "line_width", s.nozzle_diameter);
    set_double(cfg, "initial_layer_line_width", s.nozzle_diameter);
    set_double(cfg, "outer_wall_line_width", s.nozzle_diameter);
    set_double(cfg, "inner_wall_line_width", s.nozzle_diameter);
    set_double(cfg, "sparse_infill_line_width", s.nozzle_diameter);
    set_double(cfg, "internal_solid_infill_line_width", s.nozzle_diameter);
    set_double(cfg, "top_surface_line_width", s.nozzle_diameter);
    set_double(cfg, "support_line_width", s.nozzle_diameter);

    // ── 耗材类型 / 热床 ───────────────────────────────────
    set_str(cfg, "filament_type", "PLA");
    set_str(cfg, "curr_bed_type", "Textured PEI Plate");

    // ── Bambu 新键名（旧名 perimeters/fill_density 走 legacy 映射，
    //    这里显式用新名，避免映射过程中的语义偏差）
    set_int(cfg, "wall_loops", s.wall_loops);
    set_double(cfg, "sparse_infill_density", s.infill_density * 100.0);
    set_str(cfg, "sparse_infill_pattern", s.infill_pattern);

    // 支撑
    set_bool(cfg, "support_material", s.support_enabled);
    set_double(cfg, "support_material_threshold", s.support_threshold);
    set_double(cfg, "brim_width", s.brim_enabled ? 5.0 : 0.0);

    // 用户直通覆盖放在最后，优先级最高
    for (const auto &kv : s.overrides) {
        if (!cfg.has(kv.first)) {
            warnings.push_back("未知配置项，已忽略: " + kv.first);
            continue;
        }
        set_str(cfg, kv.first.c_str(), kv.second);
    }
    return cfg;
}

// Bambu 上游有个坑：ConfigOptionEnumsGeneric 的构造函数有 3 个重载忘了传
// keys_map（默认给 nullptr）。用到这些构造的配置项，在 GCode::append_full_config
// 里序列化（往 G-code 头部写 "; key = value" 注释）时会 deref 空指针。
//
// 切到 75% 后崩在 ConfigOptionEnumsGenericTempl<false>::serialize_single_value
// 就是这个原因。这些项只影响 G-code 头部的配置回显，不影响打印路径，直接剔掉。
// 注意：不能把坏项 erase 掉！Print::apply() 里会按 key 取配置项
// （option<ConfigOptionX>("xxx")->value），删掉就变成 nullptr 解引用，
// 崩在 Print::apply 里（比原来更早）。
//
// 正确做法是给它补一个空映射表：serialize_single_value 里是
//     for (const auto& kvp : *keys_map) if (kvp.second == v) ss << kvp.first;
// 空 map 只是循环 0 次、输出空值，不会崩，也不影响任何刀路计算
// （这些项只在 G-code 头部回显配置）。
static void patch_broken_enum_options(Slic3r::DynamicPrintConfig &cfg,
                                      std::vector<std::string> &warnings) {
    static const Slic3r::t_config_enum_values kEmptyEnumValues;
    std::vector<std::string> patched;
    for (const std::string &key : cfg.keys()) {
        Slic3r::ConfigOption *opt = cfg.option(key);
        if (opt == nullptr || opt->type() != Slic3r::coEnums)
            continue;
        if (auto *g = dynamic_cast<Slic3r::ConfigOptionEnumsGeneric *>(opt)) {
            if (g->keys_map == nullptr) { g->keys_map = &kEmptyEnumValues; patched.push_back(key); }
        } else if (auto *gn = dynamic_cast<Slic3r::ConfigOptionEnumsGenericNullable *>(opt)) {
            if (gn->keys_map == nullptr) { gn->keys_map = &kEmptyEnumValues; patched.push_back(key); }
        }
    }
    if (!patched.empty()) {
        std::string msg = "已为 " + std::to_string(patched.size())
                        + " 个枚举项补空映射表（否则导出 G-code 时空指针崩溃）:";
        for (size_t i = 0; i < patched.size() && i < 6; ++i) msg += " " + patched[i];
        warnings.push_back(msg);
    }
}

// ── 进度回调 ─────────────────────────────────────────────────
void on_status(const Slic3r::PrintBase::SlicingStatus &status, const ProgressFn &progress) {
    if (!progress) return;
    if (g_cancel.load()) {
        progress(static_cast<float>(status.percent) / 100.0f, "正在取消…");
        return;
    }
    progress(static_cast<float>(status.percent) / 100.0f, status.text);
}

// 把模型摆到热床中心并落到 z=0
void place_on_bed(Slic3r::Model &model, const Settings &s) {
    const Slic3r::Vec2d center(s.bed_width * 0.5, s.bed_depth * 0.5);
    try {
        model.center_instances_around_point(center);
    } catch (...) {
        // 老版本没有这个接口时退化为「什么都不动」，Print::apply 之后
        // 由 validate 报「超出打印范围」
    }
    for (auto *obj : model.objects) {
        if (obj) obj->ensure_on_bed();
    }
}

} // namespace

void request_cancel() { g_cancel.store(true); }

bool load(const std::string &path, MeshData &out, std::string &error) {
    // 预渲染用 MiniSlicer 的解析器即可；3MF / STEP 在这里改成：
    //     Slic3r::Model model = Slic3r::Model::read_from_file(path);
    // 然后遍历 model.objects / volumes / its mesh，转成 MeshData。
    (void)path; (void)out;
    error = "libslic3r 后端未实现 load()，请使用 SlicerCore::load()";
    return false;
}

bool slice(const std::string &path,
           const Settings &s,
           const ProgressFn &progress,
           SliceOutput &out,
           std::string &error) {
    g_cancel.store(false);
    silence_boost_log();

    auto report = [&](float f, const std::string &stage) {
        if (progress) progress(f, stage);
    };

    try {
        report(0.02f, "加载模型");

        // ── [CP-4] 模型读取 ─────────────────────────────────
        Slic3r::Model model;
        try {
            model = Slic3r::Model::read_from_file(path);
        } catch (const std::exception &e) {
            error = std::string("模型读取失败: ") + e.what();
            return false;
        }
        if (model.objects.empty()) {
            error = "模型里没有任何可打印对象";
            return false;
        }

        report(0.10f, "准备配置");
        std::vector<std::string> warnings;
        Slic3r::DynamicPrintConfig cfg = make_config(s, warnings);

        // 剔掉 keys_map 未初始化的枚举项，否则 export_gcode 写配置回显时空指针崩溃
        patch_broken_enum_options(cfg, warnings);

        place_on_bed(model, s);

        report(0.15f, "构建打印任务");
        Slic3r::Print print;
        // 按值捕获 progress（std::function 拷贝）：process() 内部由 TBB
        // 工作线程回调，按引用捕获会在 slice() 返回后悬空。
        print.set_status_callback([progress](const Slic3r::PrintBase::SlicingStatus &st) {
            on_status(st, progress);
        });

        print.apply(model, cfg);

        report(0.20f, "校验");
        // [CP-6] PrusaSlicer / Bambu 的 Print::validate() 返回 std::string
        //        （空串=通过，非空=错误描述）。少数 fork 返回 bool，按你的 tag 改这一行。
        const Slic3r::StringObjectException valid_err = print.validate();
        if (!valid_err.string.empty()) {
            error = "切片参数校验失败: " + valid_err.string;
            return false;
        }

        if (g_cancel.load()) { error = "已取消"; return false; }

        // ★ 核心：真正执行切片。
        //   Print::apply() 只是把配置和模型"挂"到打印任务上，process() 才是
        //   分层、生成 perimeter/infill/支撑的真正计算。少了这一步，后面的
        //   export_gcode() 访问的全是未初始化的层数据，在 libslic3r 里会直接
        //   踩空指针 → SIGSEGV → App 立即闪退且没有任何 UI 提示。
        report(0.25f, "切片计算");
        try {
            print.process();
        } catch (const Slic3r::CanceledException &) {
            error = "已取消";
            return false;
        }

        if (g_cancel.load()) { error = "已取消"; return false; }
        report(0.90f, "生成 G-code");
        {
            // 统一走 Print::export_gcode()：签名稳定（返回实际写入的路径）。
            // GCode::Generator 的内部 API 在不同 tag 间变过，先不用它。
            //
            // 临时文件必须落在沙盒的 TMPDIR 里：模型文件可能在只读目录
            // （比如通过"文件"App 从 iCloud 拷进来的），往 path 旁边写会失败。
            const char *tmpdir_env = std::getenv("TMPDIR");
            const std::string tmpdir = (tmpdir_env && *tmpdir_env) ? tmpdir_env : "/tmp";
            const std::string tmp = tmpdir + "/bambu_slice_tmp.gcode";

            std::string written = print.export_gcode(tmp, nullptr, nullptr);
            if (written.empty()) written = tmp;

            std::ifstream in(written, std::ios::binary);
            if (!in) {
                error = "G-code 导出失败：无法读取 " + written;
                return false;
            }
            std::ostringstream ss;
            ss << in.rdbuf();
            out.gcode = ss.str();
            std::remove(written.c_str());
        }

        if (out.gcode.empty()) {
            error = "G-code 为空，切片未产生任何路径";
            return false;
        }

        // 统计：优先用引擎自己算的，缺失时从 G-code 尾部兜底解析
        out.layer_count = 0;
        {
            size_t pos = 0;
            while ((pos = out.gcode.find(";LAYER_CHANGE", pos)) != std::string::npos) {
                ++out.layer_count;
                pos += 13;
            }
        }
        out.duration_seconds = 0.0;
        out.filament_mm = 0.0;
        out.filament_grams = 0.0;
        out.backend = "libslic3r";
        out.warnings = std::move(warnings);

        report(1.0f, "完成");
        return true;

    } catch (const std::exception &e) {
        error = std::string("切片异常: ") + e.what();
        return false;
    } catch (...) {
        error = "切片异常：未知错误";
        return false;
    }
}

} // namespace bambu::libslic3r_backend

#endif // BAMBU_CORE_ENABLED
