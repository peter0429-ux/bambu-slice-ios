# Frameworks/

放交叉编译出来的 iOS 静态库。整个目录被 `.gitignore` 忽略，只留这个说明。

编好之后的结构应该长这样：

```
Frameworks/
├── boost/
│   ├── include/boost/...
│   └── lib/libboost_filesystem.a  libboost_thread.a  libboost_system.a  libboost_regex.a
├── tbb/
│   ├── include/oneapi/tbb/...
│   └── lib/libtbb.a
├── eigen/
│   └── include/Eigen/...
├── cgal/
│   └── include/CGAL/...
├── zlib/
│   ├── include/zlib.h
│   └── lib/libz.a
├── expat/
│   ├── include/expat.h
│   └── lib/libexpat.a
└── libslic3r/
    ├── include/libslic3r/...     ← 注意：是 src/ 那一层的镜像
    └── lib/libslic3r.a
```

## 验收：确认它们真的是 iOS 版

```bash
# 必须是 arm64
lipo -info Frameworks/tbb/lib/libtbb.a

# 平台必须是 IOS，不是 MACOS
otool -l Frameworks/tbb/lib/libtbb.a | grep -A4 LC_BUILD_VERSION | head -20
```

如果 `platform` 显示 `MACOS`，说明工具链没生效，Xcode 链接时会报
`building for iOS, but linking in object file built for macOS`。
这一步是最常见的失败点，别急着往下走。
