#include "MiniSlicer.hpp"

#include <algorithm>
#include <atomic>
#include <cctype>
#include <cmath>
#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <map>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

namespace bambu::mini {
namespace {

constexpr double kPi = 3.14159265358979323846;

// ─────────────────────────────────────────────────────────────
// 基础类型
// ─────────────────────────────────────────────────────────────

struct V2 { double x = 0, y = 0; };
struct V3 { double x = 0, y = 0, z = 0; };

inline V2 operator+(V2 a, V2 b) { return {a.x + b.x, a.y + b.y}; }
inline V2 operator-(V2 a, V2 b) { return {a.x - b.x, a.y - b.y}; }
inline V2 operator*(V2 a, double s) { return {a.x * s, a.y * s}; }
inline double dot(V2 a, V2 b) { return a.x * b.x + a.y * b.y; }
inline double cross(V2 a, V2 b) { return a.x * b.y - a.y * b.x; }
inline double len(V2 a) { return std::sqrt(dot(a, a)); }
inline V2 normalize(V2 a) {
    const double l = len(a);
    return l > 1e-12 ? V2{a.x / l, a.y / l} : V2{0, 0};
}

struct Tri {
    V3 a, b, c;
    double minz = 0, maxz = 0;
};

struct Seg { V2 a, b; };
struct Path { std::vector<V2> pts; bool closed = false; };

std::atomic<bool> g_cancel{false};

// ─────────────────────────────────────────────────────────────
// 文件读取
// ─────────────────────────────────────────────────────────────

bool read_all(const std::string &path, std::string &out) {
    std::ifstream f(path, std::ios::binary);
    if (!f) return false;
    f.seekg(0, std::ios::end);
    const auto size = static_cast<size_t>(f.tellg());
    f.seekg(0, std::ios::beg);
    if (size == 0) return false;
    out.resize(size);
    f.read(out.data(), static_cast<std::streamsize>(size));
    return f.good() || f.eof();
}

std::string lower_ext(const std::string &path) {
    const auto pos = path.find_last_of('.');
    if (pos == std::string::npos) return "";
    std::string ext = path.substr(pos + 1);
    for (auto &c : ext) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    return ext;
}

void append_tri(std::vector<Tri> &tris, V3 a, V3 b, V3 c) {
    // 丢弃退化三角形，否则后面线段拼接会炸
    const V3 ab{b.x - a.x, b.y - a.y, b.z - a.z};
    const V3 ac{c.x - a.x, c.y - a.y, c.z - a.z};
    const V3 n{ab.y * ac.z - ab.z * ac.y,
               ab.z * ac.x - ab.x * ac.z,
               ab.x * ac.y - ab.y * ac.x};
    if (std::fabs(n.x) + std::fabs(n.y) + std::fabs(n.z) < 1e-12) return;

    Tri t;
    t.a = a; t.b = b; t.c = c;
    t.minz = std::min({a.z, b.z, c.z});
    t.maxz = std::max({a.z, b.z, c.z});
    tris.push_back(t);
}

// ── STL (binary) ─────────────────────────────────────────────
bool parse_stl_binary(const std::string &buf, std::vector<Tri> &tris) {
    if (buf.size() < 84) return false;
    uint32_t count = 0;
    std::memcpy(&count, buf.data() + 80, 4);
    const size_t need = 84ull + 50ull * static_cast<size_t>(count);
    if (count == 0 || buf.size() < need) return false;

    tris.reserve(count);
    const char *p = buf.data() + 84;
    for (uint32_t i = 0; i < count; ++i, p += 50) {
        float v[9];
        std::memcpy(v, p + 12, 36);   // 跳过 12 字节法线
        append_tri(tris, {v[0], v[1], v[2]}, {v[3], v[4], v[5]}, {v[6], v[7], v[8]});
    }
    return !tris.empty();
}

// ── STL (ascii) ──────────────────────────────────────────────
bool parse_stl_ascii(const std::string &buf, std::vector<Tri> &tris) {
    std::istringstream in(buf);
    std::string tok;
    std::vector<V3> pending;
    pending.reserve(3);
    while (in >> tok) {
        if (tok == "vertex") {
            V3 v;
            in >> v.x >> v.y >> v.z;
            pending.push_back(v);
            if (pending.size() == 3) {
                append_tri(tris, pending[0], pending[1], pending[2]);
                pending.clear();
            }
        }
    }
    return !tris.empty();
}

// ── OBJ ──────────────────────────────────────────────────────
bool parse_obj(const std::string &buf, std::vector<Tri> &tris) {
    std::istringstream in(buf);
    std::string line;
    std::vector<V3> verts;
    verts.reserve(4096);

    auto resolve = [&verts](const std::string &token) -> int {
        // 支持 "12", "12/3", "12//4", "12/3/4" 及负数索引
        const auto slash = token.find('/');
        const std::string head = slash == std::string::npos ? token : token.substr(0, slash);
        if (head.empty()) return -1;
        int idx = std::atoi(head.c_str());
        if (idx > 0) return idx - 1;
        if (idx < 0) return static_cast<int>(verts.size()) + idx;
        return -1;
    };

    while (std::getline(in, line)) {
        if (line.size() < 2) continue;
        if (line[0] == 'v' && (line[1] == ' ' || line[1] == '\t')) {
            std::istringstream ls(line.substr(1));
            V3 v;
            if (ls >> v.x >> v.y >> v.z) verts.push_back(v);
        } else if (line[0] == 'f' && (line[1] == ' ' || line[1] == '\t')) {
            std::istringstream ls(line.substr(1));
            std::vector<int> face;
            std::string token;
            while (ls >> token) {
                const int idx = resolve(token);
                if (idx >= 0 && idx < static_cast<int>(verts.size())) face.push_back(idx);
            }
            // 扇形三角化，够用（OBJ 基本都是凸多边形面）
            for (size_t i = 2; i < face.size(); ++i)
                append_tri(tris, verts[face[0]], verts[face[i - 1]], verts[face[i]]);
        }
    }
    return !tris.empty();
}

bool parse_mesh(const std::string &path, std::vector<Tri> &tris, std::string &error) {
    std::string buf;
    if (!read_all(path, buf)) {
        error = "无法读取文件（路径错误或没有权限）: " + path;
        return false;
    }

    const std::string ext = lower_ext(path);
    bool ok = false;

    if (ext == "obj") {
        ok = parse_obj(buf, tris);
    } else {
        // stl 或未知扩展名：按内容嗅探，binary 优先（ASCII 的 "solid" 开头也可能是 bin）
        ok = parse_stl_binary(buf, tris);
        if (!ok) ok = parse_stl_ascii(buf, tris);
        if (!ok) ok = parse_obj(buf, tris);
    }

    if (!ok) {
        error = "解析失败：不支持或损坏的模型格式（当前支持 STL / OBJ）";
        return false;
    }

    if (tris.size() > 4000000) {
        error = "模型三角形数量过大（>400 万），移动端无法处理";
        return false;
    }
    return true;
}

void tris_to_mesh(const std::vector<Tri> &tris, MeshData &out) {
    out.vertices.clear();
    out.indices.clear();
    out.vertices.reserve(tris.size() * 9);
    out.indices.reserve(tris.size() * 3);

    Bounds b;
    b.min[0] = b.min[1] = b.min[2] = 1e30;
    b.max[0] = b.max[1] = b.max[2] = -1e30;

    uint32_t i = 0;
    for (const auto &t : tris) {
        for (const V3 *v : {&t.a, &t.b, &t.c}) {
            out.vertices.push_back(static_cast<float>(v->x));
            out.vertices.push_back(static_cast<float>(v->y));
            out.vertices.push_back(static_cast<float>(v->z));
            b.min[0] = std::min(b.min[0], v->x); b.max[0] = std::max(b.max[0], v->x);
            b.min[1] = std::min(b.min[1], v->y); b.max[1] = std::max(b.max[1], v->y);
            b.min[2] = std::min(b.min[2], v->z); b.max[2] = std::max(b.max[2], v->z);
            out.indices.push_back(i++);
        }
    }
    if (b.min[0] > b.max[0]) { b.min[0] = b.min[1] = b.min[2] = 0; b.max[0] = b.max[1] = b.max[2] = 0; }
    out.bounds = b;
    out.triangle_count = tris.size();
}

// ─────────────────────────────────────────────────────────────
// 平面求交 → 线段 → 闭合轮廓
// ─────────────────────────────────────────────────────────────

void slice_plane(const std::vector<Tri> &tris, double z, std::vector<Seg> &segs) {
    segs.clear();
    segs.reserve(512);

    for (const auto &t : tris) {
        if (t.maxz < z || t.minz > z) continue;

        const V3 *p[3] = {&t.a, &t.b, &t.c};
        V2 pts[3];
        int n = 0;

        for (int i = 0; i < 3; ++i) {
            const V3 &A = *p[i];
            const V3 &B = *p[(i + 1) % 3];
            const bool a_below = A.z < z, b_below = B.z < z;
            if (a_below == b_below) continue;              // 同侧，无交点；共面边也在此被跳过

            const double dz = B.z - A.z;
            if (std::fabs(dz) < 1e-12) continue;
            const double tt = (z - A.z) / dz;
            if (tt < 0.0 || tt > 1.0) continue;

            V2 q{A.x + (B.x - A.x) * tt, A.y + (B.y - A.y) * tt};
            bool dup = false;
            for (int k = 0; k < n; ++k)
                if (len(q - pts[k]) < 1e-7) { dup = true; break; }
            if (!dup && n < 3) pts[n++] = q;
        }
        if (n == 2) segs.push_back({pts[0], pts[1]});
    }
}

using Key = std::pair<long long, long long>;

inline Key key_of(V2 p) {
    constexpr double Q = 1e-3;   // 1 微米量化
    return {static_cast<long long>(std::llround(p.x / Q)),
            static_cast<long long>(std::llround(p.y / Q))};
}

std::vector<Path> stitch(std::vector<Seg> &segs) {
    std::map<Key, std::vector<int>> at;
    for (int i = 0; i < static_cast<int>(segs.size()); ++i) {
        at[key_of(segs[i].a)].push_back(i);
        at[key_of(segs[i].b)].push_back(i);
    }

    std::vector<char> used(segs.size(), 0);
    std::vector<Path> paths;

    for (int i = 0; i < static_cast<int>(segs.size()); ++i) {
        if (used[i]) continue;
        used[i] = 1;

        std::vector<V2> pts{segs[i].a, segs[i].b};

        // 向后延伸
        for (;;) {
            auto it = at.find(key_of(pts.back()));
            if (it == at.end()) break;
            int next = -1;
            for (int j : it->second) if (!used[j]) { next = j; break; }
            if (next < 0) break;
            used[next] = 1;
            const V2 &A = segs[next].a, &B = segs[next].b;
            pts.push_back(len(pts.back() - A) < len(pts.back() - B) ? B : A);
        }

        // 向前延伸。先收进临时数组再整体前插，
        // 否则每接一段都 insert 到头部，轮廓点数一多就是 O(n²)。
        // 注意游标要跟着新端点走（front），不能一直用 pts.front()。
        std::vector<V2> head;
        V2 front = pts.front();
        for (;;) {
            auto it = at.find(key_of(front));
            if (it == at.end()) break;
            int next = -1;
            for (int j : it->second) if (!used[j]) { next = j; break; }
            if (next < 0) break;
            used[next] = 1;
            const V2 &A = segs[next].a, &B = segs[next].b;
            const V2 p = (len(front - A) < len(front - B)) ? B : A;
            head.push_back(p);
            front = p;
        }
        if (!head.empty()) {
            pts.insert(pts.begin(), head.rbegin(), head.rend());
        }

        bool closed = pts.size() > 3 && len(pts.front() - pts.back()) < 1e-5;
        if (closed) pts.pop_back();
        if (pts.size() >= 3) paths.push_back({std::move(pts), closed});
    }
    return paths;
}

double signed_area(const std::vector<V2> &p) {
    double a = 0;
    for (size_t i = 0; i < p.size(); ++i)
        a += cross(p[i], p[(i + 1) % p.size()]);
    return a * 0.5;
}

void ensure_ccw(std::vector<V2> &p) {
    if (signed_area(p) < 0) std::reverse(p.begin(), p.end());
}

// 顶点法线内缩（近似偏移）。对光滑轮廓足够好；尖角用 miter 上限兜住，
// 不处理自交 —— 生产环境请交给 libslic3r 的 ClipperUtils。
//
// 注意：STL 在棱边处会给出重复顶点（相邻面各自产生一次），
// 不去掉的话斜接角算出来是 90°，偏移量会过冲 41%。
std::vector<V2> dedupe(const std::vector<V2> &p, double eps = 1e-6) {
    std::vector<V2> q;
    q.reserve(p.size());
    for (const auto &v : p) {
        if (q.empty() || len(v - q.back()) > eps) q.push_back(v);
    }
    while (q.size() > 1 && len(q.front() - q.back()) <= eps) q.pop_back();
    return q;
}

std::vector<V2> offset_inward(const std::vector<V2> &raw, double d) {
    const std::vector<V2> p = dedupe(raw);
    const int n = static_cast<int>(p.size());
    if (n < 3) return p;

    std::vector<V2> q(static_cast<size_t>(n));
    for (int i = 0; i < n; ++i) {
        const V2 prev = p[(i + n - 1) % n], cur = p[i], next = p[(i + 1) % n];
        const V2 d1 = normalize(cur - prev), d2 = normalize(next - cur);
        const V2 n1{-d1.y, d1.x}, n2{-d2.y, d2.x};   // CCW 下的左法线 = 指向内部
        const double cos_t = std::max(-1.0, std::min(1.0, dot(n1, n2)));
        double miter = 1.0 / std::sqrt(std::max(0.06, (1.0 + cos_t) * 0.5));
        miter = std::min(miter, 3.0);
        q[static_cast<size_t>(i)] = cur + normalize(n1 + n2) * (d * miter);
    }
    return q;
}

// ─────────────────────────────────────────────────────────────
// 填充：在旋转 45° 的坐标系里扫线，再转回来
// ─────────────────────────────────────────────────────────────

inline V2 rot(V2 p, double a) {
    const double c = std::cos(a), s = std::sin(a);
    return {p.x * c - p.y * s, p.x * s + p.y * c};
}

void infill_lines(const std::vector<Path> &loops, double spacing,
                  std::vector<std::pair<V2, V2>> &out) {
    out.clear();
    if (spacing <= 0.05) return;

    constexpr double kAngle = kPi / 4.0;

    std::vector<std::vector<V2>> polys;
    polys.reserve(loops.size());
    for (const auto &lp : loops) {
        if (!lp.closed || lp.pts.size() < 3) continue;
        std::vector<V2> r;
        r.reserve(lp.pts.size());
        for (auto p : lp.pts) r.push_back(rot(p, -kAngle));
        polys.push_back(std::move(r));
    }
    if (polys.empty()) return;

    double ymin = 1e30, ymax = -1e30;
    for (const auto &p : polys)
        for (auto v : p) { ymin = std::min(ymin, v.y); ymax = std::max(ymax, v.y); }

    std::vector<double> xs;
    for (double y = ymin + spacing * 0.5; y < ymax; y += spacing) {
        xs.clear();
        for (const auto &poly : polys) {
            const size_t n = poly.size();
            for (size_t i = 0; i < n; ++i) {
                const V2 A = poly[i], B = poly[(i + 1) % n];
                if ((A.y <= y && B.y > y) || (B.y <= y && A.y > y)) {
                    const double tt = (y - A.y) / (B.y - A.y);
                    xs.push_back(A.x + (B.x - A.x) * tt);
                }
            }
        }
        if (xs.size() < 2) continue;
        std::sort(xs.begin(), xs.end());
        for (size_t i = 0; i + 1 < xs.size(); i += 2) {
            if (xs[i + 1] - xs[i] < 1e-4) continue;
            out.emplace_back(rot({xs[i], y}, kAngle), rot({xs[i + 1], y}, kAngle));
        }
    }
}

// ─────────────────────────────────────────────────────────────
// 支撑：把每层轮廓栅格化，然后逐列自上而下扫，找出「上面有料、下面悬空」的区间
// ─────────────────────────────────────────────────────────────
//
// 这是简化实现，不是 libslic3r 那种基于悬垂角的精确算法：
//   - 用 1 层的高度差近似「悬垂」，所以接近水平的悬空面会被识别，
//     45° 左右的斜坡因为每层外扩量小于栅格精度，不会被误判成悬空。
//   - 支撑是垂直柱，不做倾斜、不做与模型的间隙、不做接触面加密。
// 目的只是让预览里能看见支撑，真打印请用真内核。

struct Mask {
    int w = 0, h = 0;
    std::vector<uint8_t> bits;

    bool inside(int ix, int iy) const {
        if (ix < 0 || iy < 0 || ix >= w || iy >= h) return false;
        return bits[size_t(iy) * size_t(w) + size_t(ix)] != 0;
    }
};

Mask rasterize(const std::vector<Path> &loops, int w, int h, double x0, double y0, double cell) {
    Mask m;
    m.w = w;
    m.h = h;
    m.bits.assign(size_t(w) * size_t(h), 0);

    std::vector<double> xs;
    for (int iy = 0; iy < h; ++iy) {
        const double y = y0 + (iy + 0.5) * cell;
        xs.clear();
        for (const auto &lp : loops) {
            if (!lp.closed || lp.pts.size() < 3) continue;
            const size_t n = lp.pts.size();
            for (size_t i = 0; i < n; ++i) {
                const V2 A = lp.pts[i], B = lp.pts[(i + 1) % n];
                if ((A.y <= y && B.y > y) || (B.y <= y && A.y > y)) {
                    const double t = (y - A.y) / (B.y - A.y);
                    xs.push_back(A.x + (B.x - A.x) * t);
                }
            }
        }
        if (xs.size() < 2) continue;
        std::sort(xs.begin(), xs.end());
        for (size_t k = 0; k + 1 < xs.size(); k += 2) {
            int a = static_cast<int>(std::ceil((xs[k] - x0) / cell - 0.5));
            int b = static_cast<int>(std::floor((xs[k + 1] - x0) / cell - 0.5));
            a = std::max(a, 0);
            b = std::min(b, w - 1);
            for (int ix = a; ix <= b; ++ix) m.bits[size_t(iy) * size_t(w) + size_t(ix)] = 1;
        }
    }
    return m;
}

std::vector<std::vector<std::pair<V2, V2>>>
compute_support(const std::vector<std::vector<Path>> &layer_loops,
                double x0, double y0, int w, int h, double cell) {
    const size_t n = layer_loops.size();
    std::vector<std::vector<std::pair<V2, V2>>> out(n);
    if (n < 2) return out;

    std::vector<Mask> masks;
    masks.reserve(n);
    for (size_t i = 0; i < n; ++i)
        masks.push_back(rasterize(layer_loops[i], w, h, x0, y0, cell));

    const double half = std::max(cell * 0.45, 0.3);

    // 逐列遍历，每列只走一遍层数组，避免 O(层数²)
    for (int iy = 0; iy < h; ++iy) {
        for (int ix = 0; ix < w; ++ix) {
            int last_solid = -1;
            for (size_t j = 0; j < n; ++j) {
                const bool solid = masks[j].inside(ix, iy);
                if (!solid) continue;

                // 中间隔了至少一层空，说明第 j 层这块是悬空的
                if (last_solid >= 0 && static_cast<int>(j) - last_solid > 1) {
                    const double px = x0 + (ix + 0.5) * cell;
                    const double py = y0 + (iy + 0.5) * cell;
                    for (int k = last_solid + 1; k < static_cast<int>(j); ++k) {
                        out[size_t(k)].emplace_back(V2{px - half, py}, V2{px + half, py});
                    }
                }
                last_solid = static_cast<int>(j);
            }
        }
    }
    return out;
}

// ─────────────────────────────────────────────────────────────
// G-code 输出
// ─────────────────────────────────────────────────────────────

std::string fmt(const char *f, ...) {
    char buf[512];
    va_list ap;
    va_start(ap, f);
    std::vsnprintf(buf, sizeof(buf), f, ap);
    va_end(ap);
    return std::string(buf);
}

class Emitter {
public:
    Emitter(const Settings &s)
        : m_s(s),
          m_filament_area(kPi * (s.filament_diameter * 0.5) * (s.filament_diameter * 0.5)) {}

    void header(const std::string &model_name) {
        m_out << fmt("; BambuSlice mini-ref engine 0.1\n");
        m_out << fmt("; model: %s\n", model_name.c_str());
        m_out << fmt("; layer_height: %.2f  walls: %d  infill: %.0f%%\n",
                     m_s.layer_height, m_s.wall_loops, m_s.infill_density * 100.0);
        m_out << ";\n";
        m_out << fmt("M140 S%.0f\n", m_s.bed_temp);
        m_out << fmt("M104 S%.0f\n", m_s.nozzle_temp);
        m_out << "G28 ; home\n";
        m_out << fmt("M109 S%.0f ; wait nozzle\n", m_s.nozzle_temp);
        m_out << "G90 ; absolute positioning\n";
        m_out << "M82 ; absolute extrusion\n";
        m_out << "G92 E0\n";
        m_out << "G1 Z3 F600\n";
    }

    void begin_layer(size_t index, double z) {
        m_out << fmt(";LAYER:%zu\n", index);
        m_out << fmt(";Z:%.2f\n", z);
        m_out << fmt("G1 Z%.3f F1200\n", z);
    }

    void feature(const char *name) {
        if (m_feature == name) return;
        m_feature = name;
        m_out << fmt(";TYPE:%s\n", name);
    }

    void polyline(const std::vector<V2> &pts, bool closed, double speed,
                  double width, double height) {
        if (pts.size() < 2) return;
        const double feed = speed * 60.0;
        const double e_per_mm = width * height / m_filament_area;

        travel(pts.front(), 150.0);

        auto seg = [&](V2 a, V2 b) {
            const double L = len(b - a);
            if (L < 1e-6) return;
            m_e += L * e_per_mm;
            m_out << fmt("G1 X%.3f Y%.3f E%.4f F%.0f\n", b.x, b.y, m_e, feed);
            m_time += L / speed;
        };

        for (size_t i = 1; i < pts.size(); ++i) seg(pts[i - 1], pts[i]);
        if (closed) seg(pts.back(), pts.front());
    }

    void segment(V2 a, V2 b, double speed, double width, double height) {
        const double feed = speed * 60.0;
        const double e_per_mm = width * height / m_filament_area;
        travel(a, 150.0);
        const double L = len(b - a);
        if (L < 1e-6) return;
        m_e += L * e_per_mm;
        m_out << fmt("G1 X%.3f Y%.3f E%.4f F%.0f\n", b.x, b.y, m_e, feed);
        m_time += L / speed;
    }

    void footer(size_t layers) {
        m_out << "M104 S0\nM140 S0\nG91\nG1 Z10 F600\nG90\nG28 X Y\nM84\n";
        m_out << fmt(";TIME:%d\n", static_cast<int>(m_time));
        m_out << fmt(";Filament used: %.2fmm\n", m_e);
        m_out << fmt(";LAYER_COUNT:%zu\n", layers);
    }

    std::string take() { return m_out.str(); }
    double filament_mm() const { return m_e; }
    double duration() const { return m_time; }

private:
    void travel(V2 p, double speed) {
        if (m_has_last && len(p - m_last) < 1e-6) return;
        m_time += m_has_last ? len(p - m_last) / speed : 0.0;
        m_out << fmt("G0 X%.3f Y%.3f F%.0f\n", p.x, p.y, speed * 60.0);
        m_last = p;
        m_has_last = true;
    }

    const Settings &m_s;
    double m_filament_area;
    std::ostringstream m_out;
    double m_e = 0.0;
    double m_time = 0.0;
    V2 m_last;
    bool m_has_last = false;
    std::string m_feature;
};

} // namespace

// ─────────────────────────────────────────────────────────────
// 对外接口
// ─────────────────────────────────────────────────────────────

void request_cancel() { g_cancel.store(true); }

bool load(const std::string &path, MeshData &out, std::string &error) {
    std::vector<Tri> tris;
    if (!parse_mesh(path, tris, error)) return false;
    tris_to_mesh(tris, out);
    return true;
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

    report(0.02f, "解析模型");

    std::vector<Tri> tris;
    if (!parse_mesh(path, tris, error)) return false;

    // 落到热床上：z 归零
    double zmin = 1e30, zmax = -1e30;
    for (const auto &t : tris) { zmin = std::min(zmin, t.minz); zmax = std::max(zmax, t.maxz); }
    if (zmax - zmin < 1e-6) {
        error = "模型高度为 0，无法切片";
        return false;
    }
    for (auto &t : tris) {
        t.a.z -= zmin; t.b.z -= zmin; t.c.z -= zmin;
        t.minz -= zmin; t.maxz -= zmin;
    }
    const double height = zmax - zmin;

    // 层高序列
    if (s.layer_height < 1e-3 || s.first_layer_height < 1e-3) {
        error = "层高必须大于 0";
        return false;
    }
    std::vector<double> zs;
    for (double z = std::min(s.first_layer_height, height); z <= height + 1e-6; z += s.layer_height)
        zs.push_back(z);
    if (zs.empty()) zs.push_back(height * 0.5);
    const size_t layer_count = zs.size();

    Emitter em(s);
    em.header(path.substr(path.find_last_of("/\\") + 1));

    const double flow_width = s.nozzle_diameter * 1.05;
    const double speed_outer = 120.0, speed_inner = 180.0;
    const double speed_infill = 200.0, speed_support = 80.0;

    // ── 第一遍：算出每层轮廓。支撑要看纵向关系，不能边算层边输出。
    std::vector<std::vector<Path>> all_loops(layer_count);
    {
        std::vector<Seg> segs;
        for (size_t li = 0; li < layer_count; ++li) {
            if (g_cancel.load()) { error = "已取消"; return false; }
            slice_plane(tris, zs[li], segs);
            all_loops[li] = stitch(segs);
            report(0.05f + 0.45f * static_cast<float>(li + 1) / static_cast<float>(layer_count),
                   fmt("切片中 %zu/%zu 层", li + 1, layer_count));
        }
    }

    // ── 第二遍：支撑
    std::vector<std::vector<std::pair<V2, V2>>> support(layer_count);
    if (s.support_enabled) {
        report(0.55f, "生成支撑");

        double minx = 1e30, miny = 1e30, maxx = -1e30, maxy = -1e30;
        for (const auto &ls : all_loops)
            for (const auto &lp : ls)
                for (const auto &p : lp.pts) {
                    minx = std::min(minx, p.x); maxx = std::max(maxx, p.x);
                    miny = std::min(miny, p.y); maxy = std::max(maxy, p.y);
                }

        if (maxx > minx && maxy > miny) {
            const double cell = std::max(1.0, std::max(maxx - minx, maxy - miny) / 300.0);
            const int w = static_cast<int>(std::ceil((maxx - minx) / cell)) + 1;
            const int h = static_cast<int>(std::ceil((maxy - miny) / cell)) + 1;
            support = compute_support(all_loops, minx, miny, w, h, cell);
        }
    }

    // ── 第三遍：出 G-code
    std::vector<std::pair<V2, V2>> infill;

    for (size_t li = 0; li < layer_count; ++li) {
        if (g_cancel.load()) { error = "已取消"; return false; }

        const double z = zs[li];
        const double h = (li == 0) ? std::min(s.first_layer_height, height) : s.layer_height;
        const std::vector<Path> &loops = all_loops[li];

        em.begin_layer(li, z);

        // 壁：第 0 圈是外壁，其余向内偏
        for (const auto &lp : loops) {
            if (!lp.closed) continue;
            std::vector<V2> cur = dedupe(lp.pts);   // 去掉棱上的重复顶点
            ensure_ccw(cur);
            for (int w = 0; w < std::max(1, s.wall_loops); ++w) {
                if (cur.size() < 3) break;
                if (w == 0) em.feature("Outer wall");
                else        em.feature("Inner wall");
                em.polyline(cur, true, w == 0 ? speed_outer : speed_inner, flow_width, h);
                cur = offset_inward(cur, flow_width);
            }
        }

        // 填充
        if (s.infill_density > 0.001) {
            const double spacing = flow_width / std::max(0.05, std::min(1.0, s.infill_density));
            infill_lines(loops, spacing, infill);
            if (!infill.empty()) {
                em.feature("Infill");
                for (const auto &sg : infill) em.segment(sg.first, sg.second, speed_infill, flow_width, h);
            }
        }

        // 支撑
        if (!support[li].empty()) {
            em.feature("Support");
            for (const auto &sg : support[li])
                em.segment(sg.first, sg.second, speed_support, flow_width * 0.9, h);
        }

        report(0.60f + 0.40f * static_cast<float>(li + 1) / static_cast<float>(layer_count),
               fmt("生成路径 %zu/%zu 层", li + 1, layer_count));
    }

    em.footer(layer_count);

    out.gcode = em.take();
    out.duration_seconds = em.duration();
    out.filament_mm = em.filament_mm();
    const double vol_mm3 = em.filament_mm() * kPi * std::pow(s.filament_diameter * 0.5, 2);
    out.filament_grams = vol_mm3 * 0.00124;   // PLA 密度 1.24 g/cm³
    out.layer_count = layer_count;
    out.backend = "mini-ref";
    out.warnings.push_back("参考引擎：G-code 仅供预览，请勿直接上机打印");
    if (s.support_enabled)
        out.warnings.push_back("支撑为简化的垂直柱（无倾斜、无间隙），仅用于预览");
    if (s.brim_enabled)
        out.warnings.push_back("已请求 Brim，但参考引擎不生成 Brim");

    report(1.0f, "完成");
    return true;
}

} // namespace bambu::mini
