/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * STM32H5 on-chip Flash OTP layout for per-device HUK / IAK (production).
 *
 * Physical OTP window: FLASH_OTP_BASE (0x08FFF000), size 0x800.
 * These secrets MUST NOT live only in the flash-emulated OTP region at
 * 0x0C028000 (erasable with mass-erase). Factory tools program this struct
 * once; firmware only reads it.
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
#define STM_CHIP_OTP_SECRETS_VERSION 1u
#define STM_CHIP_OTP_HUK_LEN         32u
#define STM_CHIP_OTP_IAK_LEN         32u
#define STM_CHIP_OTP_BOOT_SEED_LEN   32u
#define STM_CHIP_OTP_IMPL_ID_LEN     32u

/*
 * Packed layout programmed at FLASH_OTP_BASE.
 * Total 148 bytes; fits in OTP block 0..4 (16-byte blocks on H5).
 */
struct stm_chip_otp_secrets {
    uint32_t magic;
    uint32_t version;
    uint32_t flags;      /* reserved, write 0 */
    uint32_t reserved;
    uint8_t  huk[STM_CHIP_OTP_HUK_LEN];
    uint8_t  iak[STM_CHIP_OTP_IAK_LEN];
    uint8_t  boot_seed[STM_CHIP_OTP_BOOT_SEED_LEN];
    uint8_t  implementation_id[STM_CHIP_OTP_IMPL_ID_LEN];
    uint32_t crc32;      /* CRC-32/ISO-HDLC over bytes before crc32 */
};

bool stm_chip_otp_secrets_is_provisioned(void);

enum tfm_plat_err_t stm_chip_otp_secrets_read_huk(uint8_t *out, size_t out_len);
enum tfm_plat_err_t stm_chip_otp_secrets_read_iak(uint8_t *out, size_t out_len);
enum tfm_plat_err_t stm_chip_otp_secrets_read_boot_seed(uint8_t *out, size_t out_len);
enum tfm_plat_err_t stm_chip_otp_secrets_read_impl_id(uint8_t *out, size_t out_len);

#ifdef __cplusplus
}
#endif

#endif /* STM_CHIP_OTP_SECRETS_H */
