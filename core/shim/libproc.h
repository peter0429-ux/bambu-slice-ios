//
//  libproc.h —— 兼容层
//
//  libslic3r 的 utils.cpp 用 proc_pidpath() 取可执行文件路径，
//  这个接口在 macOS 上有（/usr/lib/libproc），**iOS 上不存在**。
//  utils.cpp 是核心文件，不能排除，所以这里提供桩实现：
//  返回 -1 表示失败，调用方本来就有降级路径（取不到就留空）。
//

#ifndef BBS_LIBPROC_SHIM_H
#define BBS_LIBPROC_SHIM_H

#include <sys/types.h>
#include <unistd.h>

#ifdef __cplusplus
extern "C" {
#endif

#define PROC_PIDPATHINFO_MAXSIZE 4096

static inline int proc_pidpath(int pid, void *buffer, unsigned int buffersize) {
    (void)pid;
    (void)buffer;
    (void)buffersize;
    return -1;   // iOS 无此能力
}

static inline int proc_pidinfo(int pid, int flavor, unsigned long long arg,
                               void *buffer, int buffersize) {
    (void)pid; (void)flavor; (void)arg; (void)buffer; (void)buffersize;
    return 0;
}

#ifdef __cplusplus
}
#endif

#endif // BBS_LIBPROC_SHIM_H
