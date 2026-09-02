/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * STM32H5 on-chip Flash OTP layout for per-device secrets (production).
 *
 * Physical OTP window: FLASH_OTP_BASE (0x08FFF000), size 0x800.
 *
 * Version 2: when STM_CHIP_OTP_FLAG_HUK_DHUK is set, huk[] is AES-CBC
 * ciphertext protected by SAES DHUK (not plaintext).
 *
 * With STM_PROD_IAK_FLASH_DHUK, IAK lives in Secure Flash (DHUK-sealed)
 * instead of this OTP blob; iak[] here should be left zero / unused.
 */
#ifndef STM_CHIP_OTP_SECRETS_H
#define STM_CHIP_OTP_SECRETS_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "tfm_plat_otp.h"

#ifdef __cplusplus
extern "C" {
#endif

#define STM_CHIP_OTP_SECRETS_MAGIC   0x53544D31u /* 'STM1' */
#define STM_CHIP_OTP_SECRETS_VERSION 2u
#define STM_CHIP_OTP_HUK_LEN         32u
#define STM_CHIP_OTP_IAK_LEN         32u
#define STM_CHIP_OTP_BOOT_SEED_LEN   32u
#define STM_CHIP_OTP_IMPL_ID_LEN     32u

/* flags */
#define STM_CHIP_OTP_FLAG_HUK_DHUK   (1u << 0) /* huk[] is DHUK-encrypted */

struct stm_chip_otp_secrets {
    uint32_t magic;
    uint32_t version;
    uint32_t flags;
    uint32_t reserved;
    uint8_t  huk[STM_CHIP_OTP_HUK_LEN];
    uint8_t  iak[STM_CHIP_OTP_IAK_LEN];
    uint8_t  boot_seed[STM_CHIP_OTP_BOOT_SEED_LEN];
    uint8_t  implementation_id[STM_CHIP_OTP_IMPL_ID_LEN];
    uint32_t crc32;
};

bool stm_chip_otp_secrets_is_provisioned(void);

enum tfm_plat_err_t stm_chip_otp_secrets_read_huk(uint8_t *out, size_t out_len);
enum tfm_plat_err_t stm_chip_otp_secrets_read_iak(uint8_t *out, size_t out_len);
enum tfm_plat_err_t stm_chip_otp_secrets_read_boot_seed(uint8_t *out, size_t out_len);
enum tfm_plat_err_t stm_chip_otp_secrets_read_impl_id(uint8_t *out, size_t out_len);

/*
 * Factory helper (runs on the device): encrypt plaintext HUK with DHUK and
 * fill an OTP image ready to program. Does not write Flash OTP itself.
 */
enum tfm_plat_err_t stm_chip_otp_secrets_build_dhuk_image(
    const uint8_t huk_plain[STM_CHIP_OTP_HUK_LEN],
    const uint8_t iak[STM_CHIP_OTP_IAK_LEN],
    const uint8_t boot_seed[STM_CHIP_OTP_BOOT_SEED_LEN],
    const uint8_t implementation_id[STM_CHIP_OTP_IMPL_ID_LEN],
    struct stm_chip_otp_secrets *out_image);

#ifdef __cplusplus
}
#endif

#endif /* STM_CHIP_OTP_SECRETS_H */
