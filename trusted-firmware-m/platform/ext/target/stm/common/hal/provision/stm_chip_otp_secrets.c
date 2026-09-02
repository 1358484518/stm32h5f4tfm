/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Read-only access to STM32H5 on-chip Flash OTP device secrets.
 */
#include "stm_chip_otp_secrets.h"

#include "cmsis.h"

#include <stddef.h>
#include <string.h>

/* ISO-HDLC / zlib CRC-32 */
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
    if (s->version != STM_CHIP_OTP_SECRETS_VERSION) {
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
    return copy_field(chip_otp_map()->huk, STM_CHIP_OTP_HUK_LEN, out, out_len);
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
