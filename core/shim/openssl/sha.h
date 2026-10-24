//
//  openssl/sha.h —— 兼容层（同 md5.h 的理由）
//
//  把 OpenSSL 的 SHA1 / SHA256 / SHA512 API 映射到 CommonCrypto。
//

#ifndef BBS_OPENSSL_SHA_SHIM_H
#define BBS_OPENSSL_SHA_SHIM_H

#include <stddef.h>
#include <CommonCrypto/CommonDigest.h>

#ifdef __cplusplus
extern "C" {
#endif

// ── SHA1 ────────────────────────────────────────────────
typedef struct { CC_SHA1_CTX ctx; } SHA_CTX;

static inline int SHA1_Init(SHA_CTX *c) {
    return CC_SHA1_Init(&c->ctx);
}

static inline int SHA1_Update(SHA_CTX *c, const void *data, size_t len) {
    return CC_SHA1_Update(&c->ctx, data, (CC_LONG)len);
}

static inline int SHA1_Final(unsigned char *md, SHA_CTX *c) {
    return CC_SHA1_Final(md, &c->ctx);
}

static inline unsigned char *SHA1(const unsigned char *d, size_t n, unsigned char *md) {
    return CC_SHA1(d, (CC_LONG)n, md);
}

// ── SHA256 ──────────────────────────────────────────────
typedef struct { CC_SHA256_CTX ctx; } SHA256_CTX;

static inline int SHA256_Init(SHA256_CTX *c) {
    return CC_SHA256_Init(&c->ctx);
}

static inline int SHA256_Update(SHA256_CTX *c, const void *data, size_t len) {
    return CC_SHA256_Update(&c->ctx, data, (CC_LONG)len);
}

static inline int SHA256_Final(unsigned char *md, SHA256_CTX *c) {
    return CC_SHA256_Final(md, &c->ctx);
}

static inline unsigned char *SHA256(const unsigned char *d, size_t n, unsigned char *md) {
    return CC_SHA256(d, (CC_LONG)n, md);
}

// ── SHA512 ──────────────────────────────────────────────
typedef struct { CC_SHA512_CTX ctx; } SHA512_CTX;

static inline int SHA512_Init(SHA512_CTX *c) {
    return CC_SHA512_Init(&c->ctx);
}

static inline int SHA512_Update(SHA512_CTX *c, const void *data, size_t len) {
    return CC_SHA512_Update(&c->ctx, data, (CC_LONG)len);
}

static inline int SHA512_Final(unsigned char *md, SHA512_CTX *c) {
    return CC_SHA512_Final(md, &c->ctx);
}

static inline unsigned char *SHA512(const unsigned char *d, size_t n, unsigned char *md) {
    return CC_SHA512(d, (CC_LONG)n, md);
}

#ifdef __cplusplus
}
#endif

#endif // BBS_OPENSSL_SHA_SHIM_H
