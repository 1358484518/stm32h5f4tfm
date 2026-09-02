/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * IAK sealed with SAES DHUK and stored in Secure Flash (not on-chip OTP).
 * Re-programmable during bring-up; after debug lock only SPE can read/decrypt.
 */
#ifndef STM_IAK_FLASH_DHUK_H
#define STM_IAK_FLASH_DHUK_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "tfm_plat_otp.h"

#ifdef __cplusplus
extern "C" {
#endif

#define STM_IAK_FLASH_MAGIC     0x49414B31u /* 'IAK1' */
#define STM_IAK_FLASH_VERSION   1u
#define STM_IAK_FLASH_IAK_LEN   32u
#define STM_IAK_FLASH_FLAG_DHUK (1u << 0)

struct stm_iak_flash_blob {
    uint32_t magic;
    uint32_t version;
    uint32_t flags;
    uint32_t reserved;
    uint8_t  iak_cipher[STM_IAK_FLASH_IAK_LEN];
    uint32_t crc32;
};

bool stm_iak_flash_dhuk_is_provisioned(void);

enum tfm_plat_err_t stm_iak_flash_dhuk_read(uint8_t *out, size_t out_len);

/*
 * Factory / bring-up: encrypt plaintext IAK with DHUK and program the
 * Secure Flash sector at FLASH_IAK_DHUK_AREA_OFFSET. Erases the whole sector.
 */
enum tfm_plat_err_t stm_iak_flash_dhuk_seal_and_store(
    const uint8_t iak_plain[STM_IAK_FLASH_IAK_LEN])
    __attribute__((used));

#ifdef __cplusplus
}
#endif

#endif /* STM_IAK_FLASH_DHUK_H */
