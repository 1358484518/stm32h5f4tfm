/*
 * SPDX-License-Identifier: BSD-3-Clause
 */
#include "stm_chip_otp_secrets.h"

#include "cmsis.h"
#ifdef STM_PROD_DHUK_WRAP_HUK
#include "stm_saes_dhuk.h"
#endif

#include <stddef.h>
#include <string.h>

static uint32_t crc32_update(uint32_t crc, const uint8_t *data, size_t len)
{
    size_t i;
    int bit;

    crc = ~crc;
    for (i = 0; i < len; i++) {
        crc ^= data[i];
        for (bit = 0; bit < 8; bit++) {
            uint32_t mask = -(crc & 1u);
            crc = (crc >> 1) ^ (0xEDB88320u & mask);
        }
    }
    return ~crc;
}

static const struct stm_chip_otp_secrets *chip_otp_map(void)
{
    return (const struct stm_chip_otp_secrets *)FLASH_OTP_BASE;
}

static bool secrets_valid(const struct stm_chip_otp_secrets *s)
{
    uint32_t expect;

    if (s == NULL) {
        return false;
    }
    if (s->magic != STM_CHIP_OTP_SECRETS_MAGIC) {
        return false;
    }
    /* Accept v1 (plaintext HUK) and v2 (+ optional DHUK flag). */
    if ((s->version != 1u) && (s->version != STM_CHIP_OTP_SECRETS_VERSION)) {
        return false;
    }
    expect = crc32_update(0u, (const uint8_t *)s,
                          offsetof(struct stm_chip_otp_secrets, crc32));
    return expect == s->crc32;
}

bool stm_chip_otp_secrets_is_provisioned(void)
{
    return secrets_valid(chip_otp_map());
}

static enum tfm_plat_err_t copy_field(const uint8_t *src, size_t src_len,
                                      uint8_t *out, size_t out_len)
{
    if (out == NULL || out_len < src_len) {
        return TFM_PLAT_ERR_INVALID_INPUT;
    }
    if (!stm_chip_otp_secrets_is_provisioned()) {
        return TFM_PLAT_ERR_SYSTEM_ERR;
    }
    memcpy(out, src, src_len);
    return TFM_PLAT_ERR_SUCCESS;
}

enum tfm_plat_err_t stm_chip_otp_secrets_read_huk(uint8_t *out, size_t out_len)
{
    const struct stm_chip_otp_secrets *s = chip_otp_map();

    if (out == NULL || out_len < STM_CHIP_OTP_HUK_LEN) {
        return TFM_PLAT_ERR_INVALID_INPUT;
    }
    if (!secrets_valid(s)) {
        return TFM_PLAT_ERR_SYSTEM_ERR;
    }

#ifdef STM_PROD_DHUK_WRAP_HUK
    if ((s->flags & STM_CHIP_OTP_FLAG_HUK_DHUK) != 0u) {
        return stm_saes_dhuk_decrypt(s->huk, out, STM_CHIP_OTP_HUK_LEN);
    }
#endif
    /* v1 plaintext or v2 without DHUK flag */
    memcpy(out, s->huk, STM_CHIP_OTP_HUK_LEN);
    return TFM_PLAT_ERR_SUCCESS;
}

enum tfm_plat_err_t stm_chip_otp_secrets_read_iak(uint8_t *out, size_t out_len)
{
    return copy_field(chip_otp_map()->iak, STM_CHIP_OTP_IAK_LEN, out, out_len);
}

enum tfm_plat_err_t stm_chip_otp_secrets_read_boot_seed(uint8_t *out, size_t out_len)
{
    return copy_field(chip_otp_map()->boot_seed, STM_CHIP_OTP_BOOT_SEED_LEN,
                      out, out_len);
}

enum tfm_plat_err_t stm_chip_otp_secrets_read_impl_id(uint8_t *out, size_t out_len)
{
    return copy_field(chip_otp_map()->implementation_id, STM_CHIP_OTP_IMPL_ID_LEN,
                      out, out_len);
}

enum tfm_plat_err_t stm_chip_otp_secrets_build_dhuk_image(
    const uint8_t huk_plain[STM_CHIP_OTP_HUK_LEN],
    const uint8_t iak[STM_CHIP_OTP_IAK_LEN],
    const uint8_t boot_seed[STM_CHIP_OTP_BOOT_SEED_LEN],
    const uint8_t implementation_id[STM_CHIP_OTP_IMPL_ID_LEN],
    struct stm_chip_otp_secrets *out_image)
{
#ifndef STM_PROD_DHUK_WRAP_HUK
    (void)huk_plain;
    (void)iak;
    (void)boot_seed;
    (void)implementation_id;
    (void)out_image;
    return TFM_PLAT_ERR_UNSUPPORTED;
#else
    enum tfm_plat_err_t err;

    if ((huk_plain == NULL) || (iak == NULL) || (boot_seed == NULL) ||
        (implementation_id == NULL) || (out_image == NULL)) {
        return TFM_PLAT_ERR_INVALID_INPUT;
    }

    memset(out_image, 0, sizeof(*out_image));
    out_image->magic = STM_CHIP_OTP_SECRETS_MAGIC;
    out_image->version = STM_CHIP_OTP_SECRETS_VERSION;
    out_image->flags = STM_CHIP_OTP_FLAG_HUK_DHUK;

    err = stm_saes_dhuk_encrypt(huk_plain, out_image->huk, STM_CHIP_OTP_HUK_LEN);
    if (err != TFM_PLAT_ERR_SUCCESS) {
        memset(out_image, 0, sizeof(*out_image));
        return err;
    }

    memcpy(out_image->iak, iak, STM_CHIP_OTP_IAK_LEN);
    memcpy(out_image->boot_seed, boot_seed, STM_CHIP_OTP_BOOT_SEED_LEN);
    memcpy(out_image->implementation_id, implementation_id,
           STM_CHIP_OTP_IMPL_ID_LEN);
    out_image->crc32 = crc32_update(0u, (const uint8_t *)out_image,
                                    offsetof(struct stm_chip_otp_secrets, crc32));
    return TFM_PLAT_ERR_SUCCESS;
#endif
}
