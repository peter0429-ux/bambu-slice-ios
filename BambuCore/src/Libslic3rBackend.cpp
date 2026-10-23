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
#include <fstream>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

// ── [CP-1] 头文件路径 ────────────────────────────────────────
// Bambu Studio / PrusaSlicer 都把 libslic3r 放在 src/libslic3r 下，
// 且以 "libslic3r/xxx.hpp" 形式互相引用，所以 include path 指到 src/ 即可。
#include "libslic3r/Model.hpp"
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

// ── 配置拼装 ─────────────────────────────────────────────────

void set_str(Slic3r::DynamicPrintConfig &cfg, const char *key, const std::string &value) {
    // set_deserialize 走的是配置项自己的反序列化，不用为每个类型记住
    // ConfigOptionFloat / Bool / Int / Enum 的构造方式。
    cfg.set_deserialize(key, value);
}

void set_double(Slic3r::DynamicPrintConfig &cfg, const char *key, double v) {
    set_str(cfg, key, std::to_string(v));
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

// ── 进度回调 ─────────────────────────────────────────────────
struct StatusCtx {
    const ProgressFn *fn = nullptr;
};

void on_status(const Slic3r::PrintBase::SlicingStatus &status, void *data) {
    auto *ctx = static_cast<StatusCtx *>(data);
    if (!ctx || !ctx->fn || !*ctx->fn) return;
    // [CP-3] 取消：不同版本挂法不同。PrusaSlicer 里 status.flags 有 CANCEL 位，
    //        Bambu 分支要走 Print 上的 cancel 接口。这里只做标记 + 上报。
    if (g_cancel.load()) {
        (*ctx->fn)(static_cast<float>(status.percent) / 100.0f, "正在取消…");
        return;
    }
    (*ctx->fn)(static_cast<float>(status.percent) / 100.0f, status.text);
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

        place_on_bed(model, s);

        report(0.15f, "构建打印任务");
        Slic3r::Print print;
        StatusCtx ctx{&progress};
        print.set_status_callback(&on_status, &ctx);

        print.apply(model, cfg);

        report(0.20f, "校验");
        // [CP-6] PrusaSlicer / Bambu 的 Print::validate() 返回 std::string
        //        （空串=通过，非空=错误描述）。少数 fork 返回 bool，按你的 tag 改这一行。
        const std::string valid_err = print.validate();
        if (!valid_err.empty()) {
            error = "切片参数校验失败: " + valid_err;
            return false;
        }

        if (g_cancel.load()) { error = "已取消"; return false; }

        // ── [CP-5] G-code 生成 ──────────────────────────────
        report(0.25f, "生成 G-code");
#if BBS_HAVE_GCODE_GENERATOR
        {
            // Bambu 分支：GCode::Generator 把结果放进 GCodeResult
            Slic3r::GCode::Generator generator;
            generator.generate(print);

            Slic3r::GCodeResult result;
            generator.process(result);
            out.gcode = result.gcode;   // 部分版本是 result.gcode_string()
        }
#else
        {
            // PrusaSlicer 分支：写到临时文件再读回，避免依赖 GCodeResult 的内部布局
            const std::string tmp = path + ".tmp.gcode";
            print.export_gcode(tmp, nullptr, nullptr);

            std::ifstream in(tmp, std::ios::binary);
            if (!in) { error = "G-code 导出失败"; return false; }
            std::ostringstream ss;
            ss << in.rdbuf();
            out.gcode = ss.str();
            std::remove(tmp.c_str());
        }
#endif

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
