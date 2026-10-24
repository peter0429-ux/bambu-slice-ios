//
//  glu-libtess 兼容头
//
//  BambuStudio 自带的 glu-libtess 源码（src/glu-libtess/src/*.c）在 iOS SDK 下
//  缺 <limits.h>，导致 priorityq-heap.c 里 LONG_MAX 未声明。
//  这里给所有 .c 文件强制前置包含 <limits.h> 和 <stdint.h>。
//

#include <limits.h>
#include <stdint.h>
