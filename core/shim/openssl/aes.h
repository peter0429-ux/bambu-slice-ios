//
//  openssl/aes.h —— 兼容层
//
//  LogSink.cpp 直接用 OpenSSL 的 AES API（云端日志加密）。我们不需要云功能，
//  但编译要过。这里把 OpenSSL 的 AES API 用 CommonCrypto 实现一遍，
//  语义（尤其 CBC 会就地更新 ivec）与 OpenSSL 保持一致。
//

#ifndef BBS_OPENSSL_AES_SHIM_H
#define BBS_OPENSSL_AES_SHIM_H

#include <stddef.h>
#include <string.h>
#include <CommonCrypto/CommonCryptor.h>

#ifdef __cplusplus
extern "C" {
#endif

#define AES_ENCRYPT 1
#define AES_DECRYPT 0
#define AES_BLOCK_SIZE 16
#define AES_MAXNR 14

typedef struct {
    unsigned char raw[32];
    int bits;   // 128 / 192 / 256
} AES_KEY;

static inline int bbs_aes_set_key(const unsigned char *userKey, int bits, AES_KEY *k) {
    if (!userKey || !k) return -1;
    if (bits != 128 && bits != 192 && bits != 256) return -2;
    k->bits = bits;
    memset(k->raw, 0, sizeof(k->raw));
    memcpy(k->raw, userKey, (size_t)bits / 8);
    return 0;
}

static inline int AES_set_encrypt_key(const unsigned char *userKey, const int bits, AES_KEY *key) {
    return bbs_aes_set_key(userKey, bits, key);
}

static inline int AES_set_decrypt_key(const unsigned char *userKey, const int bits, AES_KEY *key) {
    return bbs_aes_set_key(userKey, bits, key);
}

static inline void bbs_aes_block(const unsigned char *in, unsigned char *out,
                                 const AES_KEY *key, int enc) {
    size_t moved = 0;
    CCCryptorStatus st = CCCrypt(enc ? kCCEncrypt : kCCDecrypt,
                                 kCCAlgorithmAES,
                                 kCCOptionECBMode,
                                 key->raw, (size_t)key->bits / 8, NULL,
                                 in, AES_BLOCK_SIZE,
                                 out, AES_BLOCK_SIZE, &moved);
    if (st != kCCSuccess) memset(out, 0, AES_BLOCK_SIZE);
}

static inline void AES_encrypt(const unsigned char *in, unsigned char *out, const AES_KEY *key) {
    bbs_aes_block(in, out, key, 1);
}

static inline void AES_decrypt(const unsigned char *in, unsigned char *out, const AES_KEY *key) {
    bbs_aes_block(in, out, key, 0);
}

static inline void AES_ecb_encrypt(const unsigned char *in, unsigned char *out,
                                   const AES_KEY *key, const int enc) {
    bbs_aes_block(in, out, key, enc == AES_ENCRYPT);
}

// OpenSSL 的 CBC 接口会就地更新 ivec，这里逐块模拟该行为。
static inline void AES_cbc_encrypt(const unsigned char *in, unsigned char *out, size_t len,
                                   const AES_KEY *key, unsigned char *ivec, const int enc) {
    unsigned char buf[AES_BLOCK_SIZE];
    unsigned char iv[AES_BLOCK_SIZE];
    memcpy(iv, ivec, AES_BLOCK_SIZE);

    for (size_t off = 0; off + AES_BLOCK_SIZE <= len; off += AES_BLOCK_SIZE) {
        if (enc == AES_ENCRYPT) {
            for (int i = 0; i < AES_BLOCK_SIZE; ++i) buf[i] = (unsigned char)(in[off + i] ^ iv[i]);
            bbs_aes_block(buf, out + off, key, 1);
            memcpy(iv, out + off, AES_BLOCK_SIZE);
        } else {
            bbs_aes_block(in + off, buf, key, 0);
            for (int i = 0; i < AES_BLOCK_SIZE; ++i) out[off + i] = (unsigned char)(buf[i] ^ iv[i]);
            memcpy(iv, in + off, AES_BLOCK_SIZE);
        }
    }
    memcpy(ivec, iv, AES_BLOCK_SIZE);
}

#ifdef __cplusplus
}
#endif

#endif // BBS_OPENSSL_AES_SHIM_H
