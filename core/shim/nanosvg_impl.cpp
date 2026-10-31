//
//  nanosvg_impl.cpp —— nanosvg 的实现 TU
//
//  nanosvg 是 header-only 库：头里用 NANOSVG_IMPLEMENTATION / NANOSVGRAST_IMPLEMENTATION
//  这两个宏控制「是否在这一 TU 里生成函数体」。
//
//  NSVGUtils.cpp（SVG 导入）只 include 了头，没有定义这两个宏，
//  于是发生「有声明、无定义」——链接报 _nsvgParse / _nsvgParseFromFile / _nsvgDelete。
//  上游是把 nanosvg 当独立 .c 编译的（见其 CMake 里 add_library(nanosvg ...)），
//  我们照同样思路补一个 TU。
//

#define NANOSVG_IMPLEMENTATION
#include "nanosvg.h"

#define NANOSVGRAST_IMPLEMENTATION
#include "nanosvgrast.h"
