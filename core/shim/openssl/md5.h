//
//  openssl/md5.h —— 兼容层
//
//  libslic3r 的 Utils.hpp 直接 include <openssl/md5.h>，但整个 libslic3r
//  只用到 MD5/SHA 这类哈希函数，为此在 iOS 上完整编一套 OpenSSL 不值当
//  （要额外十几分钟、十几 MB 体积，还要处理 engine/provider 配置）。
//
//  这里把 OpenSSL 的 MD5 API 原样映射到苹果系统自带的 CommonCrypto，
//  函数签名保持二进制兼容，调用方一行都不用改。
//
//  注意：这个文件只对 Apple 平台有效，与 iOS 目标一致。
//

#ifndef BBS_OPENSSL_MD5_SHIM_H
#define BBS_OPENSSL_MD5_SHIM_H

#include <stddef.h>
#include <CommonCrypto/CommonDigest.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    CC_MD5_CTX ctx;
} MD5_CTX;

static inline int MD5_Init(MD5_CTX *c) {
    return CC_MD5_Init(&c->ctx);
}

static inline int MD5_Update(MD5_CTX *c, const void *data, size_t len) {
    return CC_MD5_Update(&c->ctx, data, (CC_LONG)len);
}

static inline int MD5_Final(unsigned char *md, MD5_CTX *c) {
    return CC_MD5_Final(md, &c->ctx);
}

static inline unsigned char *MD5(const unsigned char *d, size_t n, unsigned char *md) {
    return CC_MD5(d, (CC_LONG)n, md);
}

#ifdef __cplusplus
}
#endif

#endif // BBS_OPENSSL_MD5_SHIM_H
