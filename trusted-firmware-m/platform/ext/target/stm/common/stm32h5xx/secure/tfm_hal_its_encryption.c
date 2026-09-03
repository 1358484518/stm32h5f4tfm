/*
 * Copyright (c) 2023 Nordic Semiconductor ASA.
 * Copyright (c) 2024-2025, Arm Limited. All rights reserved.
 * Copyright (c) 2026 STMicroelectronics / project adaptations.
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * STM32H5 ITS encryption HAL — must NOT call the PSA Crypto *partition*.
 * Crypto depends on ITS for persistent keys; ITS→Crypto→ITS causes an SPM
 * panic and the board resets in a loop (seen at TFM_S_ITS_TEST_1001 Set).
 *
 * Nordic documents the same constraint and uses a HW driver directly. Here we:
 *  - read HUK via tfm_plat_otp_read()
 *  - AEAD with mbedtls_gcm_* from the already-built TF-PSA-Crypto library
 *  - nonce seed from RNG_GetBytes() (Native_Driver), not psa_generate_random()
 */

#include <stdint.h>
#include <string.h>

#include "config_tfm.h"
#include "platform/include/tfm_hal_its_encryption.h"
#include "platform/include/tfm_hal_its.h"
#include "tfm_plat_otp.h"
#include "low_level_rng.h"

#define MBEDTLS_DECLARE_PRIVATE_IDENTIFIERS
#include "mbedtls/private/gcm.h"
#include "mbedtls/private/cipher.h"

#if TFM_ITS_ENC_NONCE_LENGTH != 12
#error "This implementation only supports a ITS nonce of size 12"
#endif

#if TFM_ITS_KEY_LENGTH != 16 && TFM_ITS_KEY_LENGTH != 24 && TFM_ITS_KEY_LENGTH != 32
#error "Unsupported TFM_ITS_KEY_LENGTH"
#endif

static uint32_t g_enc_counter;
static uint8_t g_enc_nonce_seed[TFM_ITS_ENC_NONCE_LENGTH - sizeof(g_enc_counter)];

static enum tfm_hal_status_t its_load_aes_key(uint8_t *key, size_t key_len)
{
    enum tfm_plat_err_t perr;
    uint8_t huk[32];
    size_t huk_size = 0;

    if (key == NULL || key_len == 0 || key_len > sizeof(huk)) {
        return TFM_HAL_ERROR_INVALID_INPUT;
    }

    perr = tfm_plat_otp_get_size(PLAT_OTP_ID_HUK, &huk_size);
    if (perr != TFM_PLAT_ERR_SUCCESS || huk_size < key_len) {
        return TFM_HAL_ERROR_GENERIC;
    }

    memset(huk, 0, sizeof(huk));
    perr = tfm_plat_otp_read(PLAT_OTP_ID_HUK, key_len, huk);
    if (perr != TFM_PLAT_ERR_SUCCESS) {
        return TFM_HAL_ERROR_GENERIC;
    }

    /*
     * Use the leading TFM_ITS_KEY_LENGTH bytes of HUK as the AES key.
     * File identity is already bound in AEAD AAD (fid/flags/size). Avoiding
     * PSA HKDF keeps us out of the Crypto partition.
     */
    memcpy(key, huk, key_len);
    memset(huk, 0, sizeof(huk));
    return TFM_HAL_SUCCESS;
}

enum tfm_hal_status_t tfm_hal_its_aead_generate_nonce(uint8_t *nonce,
                                                      const size_t nonce_size)
{
    size_t out_len = 0;

    if (nonce == NULL ||
        nonce_size < sizeof(g_enc_nonce_seed) + sizeof(g_enc_counter)) {
        return TFM_HAL_ERROR_INVALID_INPUT;
    }

    if (g_enc_counter == UINT32_MAX) {
        return TFM_HAL_ERROR_GENERIC;
    }

    if (g_enc_counter == 0) {
        RNG_GetBytes(g_enc_nonce_seed, sizeof(g_enc_nonce_seed), &out_len);
        if (out_len != sizeof(g_enc_nonce_seed)) {
            return TFM_HAL_ERROR_GENERIC;
        }
    }

    memcpy(nonce, g_enc_nonce_seed, sizeof(g_enc_nonce_seed));
    memcpy(nonce + sizeof(g_enc_nonce_seed), &g_enc_counter, sizeof(g_enc_counter));
    g_enc_counter++;

    return TFM_HAL_SUCCESS;
}

static bool ctx_is_valid(struct tfm_hal_its_auth_crypt_ctx *ctx)
{
    bool ret;

    if (ctx == NULL) {
        return false;
    }

    ret = (ctx->deriv_label == NULL && ctx->deriv_label_size != 0) ||
          (ctx->aad == NULL && ctx->aad_size != 0) ||
          (ctx->nonce == NULL && ctx->nonce_size != 0);

    return !ret;
}

static enum tfm_hal_status_t its_gcm_crypt(
                                        struct tfm_hal_its_auth_crypt_ctx *ctx,
                                        int mode,
                                        const uint8_t *input,
                                        size_t input_size,
                                        uint8_t *output,
                                        uint8_t *tag,
                                        size_t tag_size)
{
    mbedtls_gcm_context gcm;
    uint8_t key[TFM_ITS_KEY_LENGTH];
    enum tfm_hal_status_t herr;
    int rc;

    if (!ctx_is_valid(ctx) || tag == NULL || tag_size < TFM_ITS_AUTH_TAG_LENGTH) {
        return TFM_HAL_ERROR_INVALID_INPUT;
    }

    herr = its_load_aes_key(key, sizeof(key));
    if (herr != TFM_HAL_SUCCESS) {
        return herr;
    }

    mbedtls_gcm_init(&gcm);
    rc = mbedtls_gcm_setkey(&gcm, MBEDTLS_CIPHER_ID_AES, key,
                            (unsigned int)(sizeof(key) * 8));
    memset(key, 0, sizeof(key));
    if (rc != 0) {
        mbedtls_gcm_free(&gcm);
        return TFM_HAL_ERROR_GENERIC;
    }

    if (mode == MBEDTLS_GCM_ENCRYPT) {
        rc = mbedtls_gcm_crypt_and_tag(&gcm, MBEDTLS_GCM_ENCRYPT, input_size,
                                       ctx->nonce, ctx->nonce_size,
                                       ctx->aad, ctx->aad_size,
                                       input, output,
                                       TFM_ITS_AUTH_TAG_LENGTH, tag);
    } else {
        rc = mbedtls_gcm_auth_decrypt(&gcm, input_size,
                                      ctx->nonce, ctx->nonce_size,
                                      ctx->aad, ctx->aad_size,
                                      tag, TFM_ITS_AUTH_TAG_LENGTH,
                                      input, output);
    }

    mbedtls_gcm_free(&gcm);
    return (rc == 0) ? TFM_HAL_SUCCESS : TFM_HAL_ERROR_GENERIC;
}

enum tfm_hal_status_t tfm_hal_its_aead_encrypt(
                                        struct tfm_hal_its_auth_crypt_ctx *ctx,
                                        const uint8_t *plaintext,
                                        const size_t plaintext_size,
                                        uint8_t *ciphertext,
                                        const size_t ciphertext_size,
                                        uint8_t *tag,
                                        const size_t tag_size)
{
    if (plaintext_size > ciphertext_size) {
        return TFM_HAL_ERROR_INVALID_INPUT;
    }

    (void)ctx; /* used inside its_gcm_crypt */
    return its_gcm_crypt(ctx, MBEDTLS_GCM_ENCRYPT, plaintext, plaintext_size,
                         ciphertext, tag, tag_size);
}

enum tfm_hal_status_t tfm_hal_its_aead_decrypt(
                                        struct tfm_hal_its_auth_crypt_ctx *ctx,
                                        const uint8_t *ciphertext,
                                        const size_t ciphertext_size,
                                        uint8_t *tag,
                                        const size_t tag_size,
                                        uint8_t *plaintext,
                                        const size_t plaintext_size)
{
    if (plaintext_size < ciphertext_size) {
        return TFM_HAL_ERROR_INVALID_INPUT;
    }

    return its_gcm_crypt(ctx, MBEDTLS_GCM_DECRYPT, ciphertext, ciphertext_size,
                         plaintext, tag, tag_size);
}
