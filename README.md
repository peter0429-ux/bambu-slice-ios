# BambuSlice —— 把 Bambu Studio 的切片内核搬到 iOS

一个 **SwiftUI + SceneKit** 的原生 iOS 外壳，加上 **libslic3r** 的 ObjC++ 桥接层。
不是 WebView 套壳，不是远程调桌面端。

> **当前状态：M0 → M1 之间**
> 界面、桥接层、文件流程、G-code 预览全部写完了；
> libslic3r 的依赖编译脚本是模板，还没在 macOS 上实跑过（我在 Windows 上写的）。
> 开箱即用的是内置**参考引擎**——它能真的把 STL 切成路径并生成 G-code，
> 但只做单壁 + 直线填充，不生成支撑，产出不能上机打印。

---

## 跑起来

```bash
# 1. 装 XcodeGen（只第一次需要）
brew install xcodegen

# 2. 生成工程
cd bambu-slice-ios
xcodegen generate

# 3. 打开
open BambuSlice.xcodeproj
```

选一个模拟器或真机，⌘R。

第一次启动后：
- 点「导入」选一个 STL（或者用「文件」App 往 `BambuSlice/Imports` 里丢）
- 点「切片」→ 几秒后自动切到「路径」视图
- 拖层高滑块可以逐层看
- 点「导出」把 `.gcode` 发出去

> 用真机需要在 Xcode 里配一下 Team（Signing & Capabilities）。

### 没有 Mac，想要 ipa？

Windows 上出不了 ipa（没有 Xcode / iOS SDK / 签名工具链），但可以这样绕：

1. push 到 GitHub → `.github/workflows/build-ipa.yml` 会在 macOS 机器上自动编出**未签名 ipa**
2. 下载 artifact，用 **Sideloadly** 在 Windows 上拿你的 Apple ID 签一次
3. 装进 iPhone

完整步骤、免费 Apple ID 的 7 天限制、开发者模式怎么开，都在
**[docs/BUILD_IPA.md](docs/BUILD_IPA.md)**。

---

## 目录结构

```
bambu-slice-ios/
├── project.yml                  ← XcodeGen 工程描述（.xcodeproj 是产物，不入库）
├── BambuSlice/                  ← SwiftUI App
│   ├── App/                     入口
│   ├── Engine/                  内核封装、参数模型
│   ├── GCode/                   G-code → 分层线段
│   ├── Geometry/                Mesh 数据结构
│   ├── Rendering/               SceneKit 场景构建
│   ├── ViewModels/              状态机
│   └── Views/                   视口 + 面板 + 参数表
├── BambuCore/                   ← C++17 / ObjC++
│   ├── include/
│   │   ├── SlicerCore.hpp       纯 C++ 接口（不含任何 libslic3r 头）
│   │   └── SlicerBridge.h       ObjC 门面（Swift 只认这个）
│   └── src/
│       ├── SlicerCore.cpp       后端分发
│       ├── MiniSlicer.cpp       零依赖参考引擎（STL/OBJ 解析 + 切片 + G-code）
│       ├── Libslic3rBackend.cpp ★ 真内核，6 个耦合点都在这里
│       └── SlicerBridge.mm      ObjC++ 粘合
├── scripts/
│   ├── ios.toolchain.cmake
│   ├── build_deps_ios.sh        boost / tbb / eigen / cgal / zlib / expat
│   ├── build_libslic3r_ios.sh   编 libslic3r.a
│   └── make_ipa.sh              本地打未签名 ipa（需 macOS）
├── .github/workflows/
│   └── build-ipa.yml            没 Mac 时用这个：云端编 ipa
├── Samples/
│   ├── cube_20mm.stl            测试用，20mm 立方体
│   └── cylinder_r15_h30.stl     测试用，圆柱
├── docs/
│   ├── BUILD_IPA.md             ★ 怎么拿到能装的 ipa
│   ├── PORTING.md               ★ 移植指南：依赖矩阵、耦合点、常见报错
│   └── LEGAL.md                 ★ AGPL 与 App Store 的冲突，先看这个
└── Frameworks/                  依赖产物落这里（被 gitignore）
```

---

## 切换到真内核（两处改动）

**第一步**，编依赖和内核：

```bash
bash scripts/build_deps_ios.sh all
bash scripts/build_libslic3r_ios.sh
```

**第二步**，在 `project.yml` 里把 `BAMBU_CORE_ENABLED=0` 改成 `1`，
并取消下面那段 `HEADER_SEARCH_PATHS` / `OTHER_LDFLAGS` 的注释，然后：

```bash
xcodegen generate
```

启动后右上角的徽标会从橙色「参考引擎」变成绿色「libslic3r」。

> 详细步骤、每个依赖的坑、六类典型报错，都在 **docs/PORTING.md**。

---

## 已经处理掉的几件事

这些是 iOS 上容易踩、但在这里已经写好的：

- **安全作用域 URL**：文档选择器给的 URL 生命周期不可控，导入时立刻拷进沙盒（`Imports/`），内核随便读
- **主线程保护**：`Print::apply` 可能跑几十秒，桥接层全在后台队列，进度回调用 `@MainActor` 跳回来
- **大数组不走 NSNumber**：顶点/索引直接用 `NSData` 搬内存，几十万面不会卡在装箱上
- **SIMD3 的 stride 陷阱**：`MemoryLayout<SIMD3<Float>>.stride` 是 16 而不是 12，`SCNGeometrySource` 的 `dataStride` 必须跟着它
- **相机不跳**：模型和路径共用同一个场景，切视图只改显隐，不会重置视角
- **取消**：参考引擎每层检查一次原子标志；真内核要看 fork 有没有 cancel 钩子（PORTING.md CP-3）

---

## 已知限制

| 项 | 状态 |
|---|---|
| STL（binary / ASCII） | ✅ |
| OBJ | ✅ 基础三角化 |
| 3MF / STEP | ❌ 需要 lib3mf / OpenCASCADE，见 PORTING.md |
| 支撑 / 桥接 / 可变层高 | ❌ 参考引擎不支持；真内核支持 |
| 圆弧插补 G2/G3 预览 | ❌ 预览只画 G0/G1 直线段 |
| iPad 分屏 | ⏸ 未适配，视口会拉伸 |
| 上面一行代码没编译过 | ⚠️ 见文首说明 |

---

## 读这三份文档再动代码

1. **docs/BUILD_IPA.md** —— 怎么在 Windows 上拿到能装的 ipa
2. **docs/LEGAL.md** —— 为什么这个 App 上不了 App Store，以及合法的分发方式
3. **docs/PORTING.md** —— 依赖怎么编、API 怎么对、手机会不会炸

`Bambu` 是 Bambu Lab 的商标，`BambuSlice` 这个工程名只是占位，发布前请改名。
