/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * STM32H5 SAES + DHUK helpers.
 *
 * DHUK itself is never software-readable. We use it as an AES-256 key
 * (CRYP_KEYSEL_HW + KEYMODE_NORMAL) to protect device secrets stored in
 * on-chip Flash OTP. This is distinct from KEYMODE_WRAPPED / UnwrapKey,
 * which loads keys into write-only SAES registers and cannot feed
 * tfm_plat_get_huk()'s byte API.
 */
#ifndef STM_SAES_DHUK_H
#define STM_SAES_DHUK_H

#include <stddef.h>
#include <stdint.h>

#include "tfm_plat_otp.h"

#ifdef __cplusplus
extern "C" {
#endif

enum tfm_plat_err_t stm_saes_dhuk_encrypt(const uint8_t *in, uint8_t *out, size_t len);
enum tfm_plat_err_t stm_saes_dhuk_decrypt(const uint8_t *in, uint8_t *out, size_t len);

#ifdef __cplusplus
}
#endif

#endif /* STM_SAES_DHUK_H */
