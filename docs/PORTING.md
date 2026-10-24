# 移植指南：libslic3r → iOS

这份文档只讲**怎么把 Bambu Studio 的切片内核搬到 iPhone 上**，不讲界面。
界面部分（SwiftUI + SceneKit）已经在工程里了，你不需要动。

---

## 0. 先确认范围

Bambu Studio 是个桌面程序，它的价值拆开看是这样：

| 部分 | 目录 | iOS 上要不要 |
|---|---|---|
| 切片内核 | `src/libslic3r/` | ✅ 要，整个移植的核心 |
| 桌面 GUI | `src/slic3r/GUI/`、`wxWidgets` | ❌ 完全不要，用 SwiftUI 重写 |
| 网络 / 云 / MakerWorld | `src/slic3r/GUI/...`、`libcurl`、`openssl` | ❌ 第一期全砍 |
| 插件系统 | `plugins/` | ❌ 砍 |
| OpenGL 预览 | `src/slic3r/GUI/GLCanvas*` | ❌ 砍，用 SceneKit/Metal |
| 3MF / STEP 读取 | `lib3mf`、`OpenCASCADE` | ⏸ 第二期再说（体积 + 编译成本极高） |

**结论：只需要 `libslic3r` 这一个静态库，加上 boost / tbb / eigen / cgal / zlib / expat。**

---

## 1. 数据流

```
┌──────────── SwiftUI ────────────┐
│ RootView / SlicerViewModel      │
│                                 │
│  SceneKit 预览 ◄─── Mesh        │
│         ▲                       │
└─────────┼───────────────────────┘
          │ BBMesh / BBSliceResult      ← ObjC 类型，Swift 可见
┌─────────┴───────────────────────┐
│ SlicerBridge.mm  (ObjC++)       │  ← 唯一接触 ObjC 的一层
├─────────────────────────────────┤
│ SlicerCore (纯 C++, pimpl)      │  ← 后端分发点
│   ├─ MiniSlicer.cpp   (无依赖)  │  ← BAMBU_CORE_ENABLED=0
│   └─ Libslic3rBackend.cpp       │  ← BAMBU_CORE_ENABLED=1
├─────────────────────────────────┤
│ libslic3r.a + boost + tbb ...   │
└─────────────────────────────────┘
```

关键点：**`SlicerCore.hpp` 不 include 任何 libslic3r 头文件**。
所以关掉真内核时，整个工程照样能编译、能跑，只是切片结果是参考实现。
这条边界是刻意设计的，别打破它——否则每次调内核都要等 Xcode 重编整个 C++ 世界。

---

## 2. 依赖矩阵

> 下面这张表是**实测过**的（GitHub Actions / macos-latest / Xcode 26.6 / CMake 4）。
> 六个依赖全部编成 iOS arm64 静态库通过，见 `.github/workflows/deps.yml`。

| 依赖 | 状态 | 编译方式 | 踩过的坑 |
|---|---|---|---|
| Eigen | ✅ 已验证 | header-only，拷 `Eigen/` 目录 | 无 |
| Boost | ✅ 已验证 | `b2 target-os=iphone toolset=clang-ios` | **不能写 `abi=iphone`**，`<abi>` 只接受 aapcs/eabi/ms/n32/o32/sysv。写了直接报错退出 |
| TBB | ✅ 已验证 | CMake + 我们的 toolchain | oneTBB 的 `cmake_minimum_required(VERSION 3.1)` 被 CMake 4 拒绝，要加 `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` |
| CGAL | ✅ 已验证 | header-only，拷 `CGAL/` | 精确谓词要 GMP/MPFR，本次未编（见下方风险） |
| zlib | ✅ 已验证 | CMake + make | **不能用 `-G Xcode`**：会给 example/minigzip 生成 App target 然后卡签名；且 `zconf.h` 是 CMake 生成到 build 目录的，源码树里没有 |
| expat | ✅ 已验证 | CMake | 无 |
| GMP / MPFR | ⏸ 未做 | 需单独交叉编译 | libslic3r 的 `MeshBoolean` 走 OpenMeshCraft 时要它们；缺了就退到 MCUT（需 `SLIC3R_ALLOW_MCUT_BOOLEAN=ON`） |
| Qhull / cereal / libnest2d / libigl / clipper2 / miniz / admesh | 📦 源码自带 | 随 BambuStudio 的 `src/` 一起编 | 不需要单独交叉编译 |
| OpenCV / OpenEXR / OpenSSL / CURL / lib3mf | ❌ 不要 | — | 只服务 GUI、云、贴图，全部砍掉 |

---

## 2.1 关键结论：不能直接用他们的顶层 CMake

这是实测出来的，也是整个移植里最容易走错的一步。

BambuStudio 根目录的 `CMakeLists.txt` 里有这些**无条件**的语句：

```cmake
find_package(OpenSSL REQUIRED)
find_package(CURL REQUIRED)        # APPLE 分支还要 CONFIG 模式
find_package(OpenGL REQUIRED)
find_package(GLEW REQUIRED)
find_package(glfw3 REQUIRED)
find_package(PNG REQUIRED)
```

注意：**它们不在 `if(SLIC3R_GUI)` 里面**。也就是说即使你传 `-DSLIC3R_GUI=OFF`，
configure 阶段照样要求桌面 OpenGL 生态。GLEW / glfw3 在 iOS 上基本是死路
（GLEW 是桌面 GL 扩展加载器，glfw3 的 iOS 支持是残缺的）。

所以正确的做法是：**绕开他们的顶层 CMake，自己写一个只编 `libslic3r` 的工程。**

规模是可控的：

- `src/libslic3r/` 下 **225 个 .cpp**（根目录 127，GCode 18，Fill 17，SLA 14，Format 12，Arachne 系列 15，Geometry 7，Support 5…）
- 第三方库大量内联在 `src/` 里：`eigen`(311 文件) `libigl`(1088) `qhull`(236) `clipper2` `admesh` `miniz` `minilzo` `libnest2d` `nlohmann` `mcut` `glu-libtess`
- 也就是说需要外编的只有：boost / tbb / cgal / zlib / expat 这几个

还有一个结构上的坑：他们内部把 CGAL 相关的代码拆成了**独立的 `libslic3r_cgal` 子目标**，
并且 `MeshBoolean` 依赖 OpenMeshCraft（要 GMP/MPFR）或 MCUT。
自己写 CMake 时要么把 `libslic3r_cgal` 一起编进来，要么把 `MeshBoolean.cpp` 排除并
定义 `SLIC3R_ALLOW_MCUT_BOOLEAN`。

---

## 3. 与 libslic3r API 的 6 个耦合点

`BambuCore/src/Libslic3rBackend.cpp` 里用 `[CP-x]` 标了。升级版本只需要对齐这里。

| # | 位置 | 说明 | 版本差异 |
|---|---|---|---|
| CP-1 | `#include "libslic3r/xxx.hpp"` | include path 指向 `src/` | 两个 fork 一致 |
| CP-2 | `bed_shape` vs `printable_area` | 热床尺寸的配置键 | PrusaSlicer ≥2.6 改名为 `printable_area`；代码里用 `has()` 双探测 |
| CP-3 | 取消 | `SlicingStatus` 的 cancel 位 | PrusaSlicer 用 status flags；Bambu 要调 Print 上的 cancel 接口 |
| CP-4 | `Model::read_from_file()` | 读模型 | 一致，但 Bambu 版本多了 `LoadStrategy` 参数 |
| CP-5 | G-code 生成 | **差异最大** | PrusaSlicer：`print.export_gcode(tmp, nullptr, nullptr)`<br>Bambu：`GCode::Generator::generate(print)` + `process(GCodeResult&)` |
| CP-6 | `Print::validate()` | 返回类型 | 返回 `std::string`（空=通过）；个别 fork 返回 `bool` |

`#if __has_include("libslic3r/GCode/GCodeGenerator.hpp")` 这句会自动判断分支，
所以你 clone 哪个 fork 都能编，只是要走对分支。

**如果 CP-5 对不上**，最快的定位方法是去看他们的 CLI 入口：
`src/BambuStudio.cpp` 或 `src/PrusaSlicer.cpp` 里 `slice()` 那个函数，
它做的就是我们要做的事，照抄顺序即可。

---

## 4. 编译参数

见 `scripts/build_libslic3r_ios.sh`。几个必须的：

```cmake
-DSLIC3R_GUI=OFF        # 不编 wxWidgets 那一坨
-DSLIC3R_PCH=OFF        # 预编译头在交叉编译下经常炸
-DSLIC3R_STATIC=1
-DBUILD_SHARED_LIBS=OFF # iOS 不让随便加载动态库
-DSLIC3R_FHS=OFF
```

C++ 标准 **C++17**，异常和 RTTI **必须开**（libslic3r 大量用 `dynamic_cast`
和 `throw`，设 `-fno-exceptions` 会连锁报错）。

---

## 5. 常见报错与处理

**① `'boost/filesystem.hpp' file not found`**
你的 Boost 是 macOS 版。检查 `lipo -info libboost_filesystem.a` 是否含 arm64，
以及 `otool -l` 的 platform 是不是 `IOS`。

**② `Undefined symbols: _tbb::detail::r1::...`**
TBB 编成了动态库，或者编的是 macOS 架构。重编，确认 `TBB_BUILD_SHARED=OFF`。

**③ `Cannot find GMP`**
CGAL 的精确谓词。两条路：编 GMP/MPFR（痛苦），或改用
`CGAL::Exact_predicates_inexact_constructions_kernel` 并接受微小几何误差。

**④ 链接期出现 `wx*` 符号**
说明 `SLIC3R_GUI=OFF` 没生效，或者某个 `libslic3r` 源文件反向引用了 GUI。
在 CMakeLists 里把 `src/slic3r/GUI` 从 `include_directories` 里摘掉。

**⑤ `'filesystem' is unavailable: introduced in iOS 13`**
部署目标低于 13。我们是 16，正常不会遇到；如果遇到了说明某处用了
`std::filesystem` 的 experimental 版本。

**⑥ 编译过了但一跑就崩在 `Print::apply`**
九成是配置不全。`DynamicPrintConfig` 缺 `printer_model` / `nozzle_diameter` /
`bed_shape` 这类必填项时，libslic3r 内部会越界访问而不是抛异常。
用 `cfg.has("key")` 逐个断言一遍。

**⑦ 切片结束但 G-code 是空的**
`GCodeResult` 的字段名在不同 tag 之间改过（`gcode` / `gcode_string()` / `gcode_data`）。
在 `Libslic3rBackend.cpp` CP-5 那里打印一下类型就知道了。

---

## 6. 手机上的现实约束

这些是设计 App 时必须提前知道的，不是「以后优化」：

| 项 | 现实 |
|---|---|
| 内存 | iOS 给单个 App 的上限大约 2~3 GB（取决于机型）。一个 100 万面的模型，`Print` 对象内部展开后轻松吃掉 1.5 GB。**必须限制模型复杂度**，或做分块切片 |
| 线程 | `Print` 内部用 TBB 并行跑层。手机全核跑满 30 秒就开始降频，用户能摸到烫。代码里 `threads=2` 是刻意的，别改大 |
| 时间 | 桌面 20 秒的活，A17 上大概 40~90 秒。要在 UI 上给足进度反馈，并支持取消 |
| 后台 | App 进后台 30 秒就被挂起。切片必须在前台完成，或者用 `beginBackgroundTask` 争取一点尾巴 |
| 沙盒 | `boost::filesystem::temp_directory_path()` 在 iOS 上返回 `$TMPDIR`，可用；但**不能 fork/exec**，所以任何调用外部进程的代码路径都要排除 |

---

## 7. 建议的推进节奏

| 阶段 | 目标 | 验收标准 |
|---|---|---|
| M0 | 工程能跑 | `xcodegen generate` → 模拟器能导入 STL、看到模型、用参考引擎切出路径 |
| M1 | 依赖编通 | 6 个依赖全部产出 arm64 iOS `.a`，`lipo -info` 确认 |
| M2 | libslic3r 链接成功 | `BAMBU_CORE_ENABLED=1` 后 App 能启动，不崩 |
| M3 | 切出第一份真 G-code | 同一个模型，参考引擎和真内核的层数/路径大致吻合 |
| M4 | 真机打印验证 | 把 G-code 通过 AirDrop 送到桌面 Bambu Studio，对比切片结果；误差应在可接受范围内 |
| M5 | 参数面板打通 | 至少 20 个常用参数能从 UI 直通到 `DynamicPrintConfig` |

参考引擎那一步不是玩具：它让你在 M1/M2 卡住的时候仍然能推进 UI 和文件流程，
也能当作真内核的对照基准（层数、层高序列、总路径长度应该量级一致）。

---

## 8. 什么时候该放弃这条路

说实话，如果你的目标只是「在手机上把 STL 切了然后打印」，方案成本排序是：

1. **Bambu Handy + 云端切片** — 现成的，零成本，但依赖网络和 Bambu 账号
2. **网页版切片器（PWA）** — 如 Kiri:Moto，Safari 打开即用，加到主屏像 App
3. **本工程这条路** — 完全离线、完全可控、能对接自己的机器，但要投入 M1~M4 的工作量

只有当你需要 **离线 + 自定义参数 + 对接非 Bambu 机器 + 数据不出设备** 时，
自己编 libslic3r 才是合理的投入。
