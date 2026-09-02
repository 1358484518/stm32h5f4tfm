/*
 * SPDX-License-Identifier: BSD-3-Clause
 */
#include "stm_saes_dhuk.h"

#include "stm32h5xx_hal.h"

#include <string.h>

#ifndef STM_SAES_DHUK_TIMEOUT_MS
#define STM_SAES_DHUK_TIMEOUT_MS 1000u
#endif

/* Fixed IV for CBC; secrets are device-unique so reuse is acceptable here. */
static const uint32_t stm_saes_dhuk_iv[4] = {
    0xA5A5A5A5u, 0x5A5A5A5Au, 0x01234567u, 0x89ABCDEFu
};

static enum tfm_plat_err_t saes_crypt(const uint8_t *in, uint8_t *out, size_t len,
                                      uint32_t encrypt)
{
    CRYP_HandleTypeDef hcryp;
    HAL_StatusTypeDef st;
    uint32_t in_w[8];
    uint32_t out_w[8];

    if ((in == NULL) || (out == NULL) || (len == 0u) || ((len % 16u) != 0u) ||
        (len > sizeof(in_w))) {
        return TFM_PLAT_ERR_INVALID_INPUT;
    }

    memcpy(in_w, in, len);
    memset(out_w, 0, sizeof(out_w));
    memset(&hcryp, 0, sizeof(hcryp));

    __HAL_RCC_SAES_CLK_ENABLE();

    hcryp.Instance = SAES;
    hcryp.Init.DataType = CRYP_NO_SWAP;
    hcryp.Init.KeySize = CRYP_KEYSIZE_256B;
    hcryp.Init.Algorithm = CRYP_AES_CBC;
    hcryp.Init.pInitVect = (uint32_t *)stm_saes_dhuk_iv;
    hcryp.Init.KeyIVConfigSkip = CRYP_KEYIVCONFIG_ALWAYS;
    hcryp.Init.KeySelect = CRYP_KEYSEL_HW;     /* DHUK */
    hcryp.Init.KeyMode = CRYP_KEYMODE_NORMAL;  /* encrypt/decrypt data to SW buffer */
    hcryp.Init.KeyProtection = CRYP_KEYPROT_DISABLE;

    st = HAL_CRYP_Init(&hcryp);
    if (st != HAL_OK) {
        return TFM_PLAT_ERR_SYSTEM_ERR;
    }

    if (encrypt != 0u) {
        st = HAL_CRYP_Encrypt(&hcryp, in_w, (uint16_t)(len / 4u), out_w,
                              STM_SAES_DHUK_TIMEOUT_MS);
    } else {
        st = HAL_CRYP_Decrypt(&hcryp, in_w, (uint16_t)(len / 4u), out_w,
                              STM_SAES_DHUK_TIMEOUT_MS);
    }

    (void)HAL_CRYP_DeInit(&hcryp);

    if (st != HAL_OK) {
        memset(out_w, 0, sizeof(out_w));
        return TFM_PLAT_ERR_SYSTEM_ERR;
    }

    memcpy(out, out_w, len);
    memset(out_w, 0, sizeof(out_w));
    memset(in_w, 0, sizeof(in_w));
    return TFM_PLAT_ERR_SUCCESS;
}

enum tfm_plat_err_t stm_saes_dhuk_encrypt(const uint8_t *in, uint8_t *out, size_t len)
{
    return saes_crypt(in, out, len, 1u);
}

enum tfm_plat_err_t stm_saes_dhuk_decrypt(const uint8_t *in, uint8_t *out, size_t len)
{
    return saes_crypt(in, out, len, 0u);
}
