/*
 * SPDX-License-Identifier: BSD-3-Clause
 */
#include "stm_iak_flash_dhuk.h"

#include "Driver_Flash.h"
#include "flash_layout.h"
#include "stm_saes_dhuk.h"

#include <stddef.h>
#include <string.h>

#ifndef STM_PROD_IAK_FLASH_DHUK
#error "stm_iak_flash_dhuk.c requires STM_PROD_IAK_FLASH_DHUK"
#endif

extern ARM_DRIVER_FLASH FLASH_DEV_NAME;

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

static const struct stm_iak_flash_blob *blob_map(void)
{
    return (const struct stm_iak_flash_blob *)
           (FLASH_BASE_ADDRESS + FLASH_IAK_DHUK_AREA_OFFSET);
}

static bool blob_valid(const struct stm_iak_flash_blob *b)
{
    uint32_t expect;

    if (b == NULL) {
        return false;
    }
    if (b->magic != STM_IAK_FLASH_MAGIC) {
        return false;
    }
    if (b->version != STM_IAK_FLASH_VERSION) {
        return false;
    }
    if ((b->flags & STM_IAK_FLASH_FLAG_DHUK) == 0u) {
        return false;
    }
    expect = crc32_update(0u, (const uint8_t *)b,
                          offsetof(struct stm_iak_flash_blob, crc32));
    return expect == b->crc32;
}

bool stm_iak_flash_dhuk_is_provisioned(void)
{
    return blob_valid(blob_map());
}

enum tfm_plat_err_t stm_iak_flash_dhuk_read(uint8_t *out, size_t out_len)
{
    const struct stm_iak_flash_blob *b = blob_map();

    if (out == NULL || out_len < STM_IAK_FLASH_IAK_LEN) {
        return TFM_PLAT_ERR_INVALID_INPUT;
    }
    if (!blob_valid(b)) {
        return TFM_PLAT_ERR_SYSTEM_ERR;
    }
    return stm_saes_dhuk_decrypt(b->iak_cipher, out, STM_IAK_FLASH_IAK_LEN);
}

enum tfm_plat_err_t __attribute__((used)) stm_iak_flash_dhuk_seal_and_store(
    const uint8_t iak_plain[STM_IAK_FLASH_IAK_LEN])
{
    struct stm_iak_flash_blob blob;
    enum tfm_plat_err_t err;
    int32_t drv;
    ARM_FLASH_CAPABILITIES caps;
    uint32_t data_width;
    uint8_t prog[64];
    size_t prog_len;
    size_t off;
    uint32_t num_items;

    if (iak_plain == NULL) {
        return TFM_PLAT_ERR_INVALID_INPUT;
    }
    if (sizeof(blob) > sizeof(prog)) {
        return TFM_PLAT_ERR_SYSTEM_ERR;
    }

    memset(&blob, 0, sizeof(blob));
    blob.magic = STM_IAK_FLASH_MAGIC;
    blob.version = STM_IAK_FLASH_VERSION;
    blob.flags = STM_IAK_FLASH_FLAG_DHUK;

    err = stm_saes_dhuk_encrypt(iak_plain, blob.iak_cipher, STM_IAK_FLASH_IAK_LEN);
    if (err != TFM_PLAT_ERR_SUCCESS) {
        memset(&blob, 0, sizeof(blob));
        return err;
    }
    blob.crc32 = crc32_update(0u, (const uint8_t *)&blob,
                              offsetof(struct stm_iak_flash_blob, crc32));

    memset(prog, 0xFF, sizeof(prog));
    memcpy(prog, &blob, sizeof(blob));
    prog_len = sizeof(blob);
    if ((prog_len % TFM_HAL_FLASH_PROGRAM_UNIT) != 0u) {
        prog_len += TFM_HAL_FLASH_PROGRAM_UNIT -
                    (prog_len % TFM_HAL_FLASH_PROGRAM_UNIT);
    }

    drv = FLASH_DEV_NAME.Initialize(NULL);
    if (drv != ARM_DRIVER_OK) {
        memset(&blob, 0, sizeof(blob));
        memset(prog, 0, sizeof(prog));
        return TFM_PLAT_ERR_SYSTEM_ERR;
    }

    drv = FLASH_DEV_NAME.EraseSector(FLASH_IAK_DHUK_AREA_OFFSET);
    if (drv != ARM_DRIVER_OK) {
        (void)FLASH_DEV_NAME.Uninitialize();
        memset(&blob, 0, sizeof(blob));
        memset(prog, 0, sizeof(prog));
        return TFM_PLAT_ERR_SYSTEM_ERR;
    }

    caps = FLASH_DEV_NAME.GetCapabilities();
    data_width = (caps.data_width == 0u) ? 1u :
                 (caps.data_width == 1u) ? 2u : 4u;

    for (off = 0; off < prog_len; off += TFM_HAL_FLASH_PROGRAM_UNIT) {
        num_items = TFM_HAL_FLASH_PROGRAM_UNIT / data_width;
        drv = FLASH_DEV_NAME.ProgramData(FLASH_IAK_DHUK_AREA_OFFSET + off,
                                         &prog[off], num_items);
        if (drv < 0) {
            (void)FLASH_DEV_NAME.Uninitialize();
            memset(&blob, 0, sizeof(blob));
            memset(prog, 0, sizeof(prog));
            return TFM_PLAT_ERR_SYSTEM_ERR;
        }
    }

    (void)FLASH_DEV_NAME.Uninitialize();
    memset(&blob, 0, sizeof(blob));
    memset(prog, 0, sizeof(prog));

    if (!stm_iak_flash_dhuk_is_provisioned()) {
        return TFM_PLAT_ERR_SYSTEM_ERR;
    }
    return TFM_PLAT_ERR_SUCCESS;
}
