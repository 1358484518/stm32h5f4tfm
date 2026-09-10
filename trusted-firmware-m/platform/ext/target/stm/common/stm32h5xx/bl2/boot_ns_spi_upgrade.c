/*
 * SPDX-FileCopyrightText: Copyright The TrustedFirmware-M Contributors
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * NS writes signed images to W25Q32. BL2 reads NOR and, after a successful
 * overwrite (or when secondary already matches primary), erases that
 * download slot so the next boot does not hash a leftover image.
 */

#include <string.h>
#include "bootutil/boot_hooks.h"
#include "bootutil/bootutil_public.h"
#include "bootutil/image.h"
#include "bootutil/bootutil_log.h"
#include "flash_map/flash_map.h"
#include "sysflash/sysflash.h"
#include "low_level_spi_flash.h"

#define SLOT_SHA256_LEN  32U

static int read_slot_sha256(const struct flash_area *fap, uint8_t *sha)
{
    struct image_header hdr;
    struct image_tlv_iter it;
    uint32_t off;
    uint16_t len;
    uint16_t type;
    int rc;

    if ((fap == NULL) || (sha == NULL)) {
        return -1;
    }
    if (flash_area_read(fap, 0, &hdr, sizeof(hdr)) != 0) {
        return -1;
    }
    if (hdr.ih_magic != IMAGE_MAGIC) {
        return -1;
    }

    rc = bootutil_tlv_iter_begin(&it, &hdr, fap, IMAGE_TLV_SHA256, false);
    if (rc != 0) {
        return -1;
    }

    rc = bootutil_tlv_iter_next(&it, &off, &len, &type);
    if ((rc != 0) || (len != SLOT_SHA256_LEN)) {
        return -1;
    }

    return flash_area_read(fap, off, sha, SLOT_SHA256_LEN);
}

static void erase_spi_secondary(int img_index)
{
    const struct flash_area *secondary = NULL;
    int32_t rc;

    if (flash_area_open(FLASH_AREA_IMAGE_SECONDARY(img_index),
                        &secondary) != 0) {
        BOOT_LOG_ERR("Image %d: SPI download open for erase failed", img_index);
        return;
    }

    BOOT_LOG_INF("Image %d: erasing SPI download 0x%x+0x%x",
                 img_index,
                 (unsigned)secondary->fa_off,
                 (unsigned)secondary->fa_size);
    rc = w25q32_erase_range(secondary->fa_off, secondary->fa_size);
    flash_area_close(secondary);
    if (rc != ARM_DRIVER_OK) {
        BOOT_LOG_ERR("Image %d: SPI download erase failed (%d)",
                     img_index, (int)rc);
        return;
    }
    BOOT_LOG_INF("Image %d: SPI download erased", img_index);
}

int boot_read_image_header_hook(int img_index, int slot,
                                struct image_header *img_head)
{
    (void)img_index;
    (void)slot;
    (void)img_head;
    return BOOT_HOOK_REGULAR;
}

fih_ret boot_image_check_hook(int img_index, int slot)
{
    (void)img_index;
    (void)slot;
    FIH_RET(FIH_BOOT_HOOK_REGULAR);
}

int boot_read_swap_state_primary_slot_hook(int image_index,
                                           struct boot_swap_state *state)
{
    (void)image_index;
    (void)state;
    return BOOT_HOOK_REGULAR;
}

int boot_copy_region_post_hook(int img_index, const struct flash_area *area,
                               size_t size)
{
    (void)area;
    (void)size;
    /* Primary already holds the new image. Drop the SPI copy so later boots
     * do not re-validate a leftover secondary.
     */
    erase_spi_secondary(img_index);
    return 0;
}

int boot_perform_update_hook(int img_index, struct image_header *img_head,
                             const struct flash_area *area)
{
    const struct flash_area *primary = NULL;
    uint8_t sha_sec[SLOT_SHA256_LEN];
    uint8_t sha_pri[SLOT_SHA256_LEN];
    int rc;

    (void)img_head;

    rc = flash_area_open(FLASH_AREA_IMAGE_PRIMARY(img_index), &primary);
    if (rc != 0) {
        BOOT_LOG_INF("Image %d: primary open failed, follow default update",
                     img_index);
        return BOOT_HOOK_REGULAR;
    }

    if ((read_slot_sha256(area, sha_sec) != 0) ||
        (read_slot_sha256(primary, sha_pri) != 0)) {
        flash_area_close(primary);
        BOOT_LOG_INF("Image %d: hash compare skipped, follow default update",
                     img_index);
        return BOOT_HOOK_REGULAR;
    }
    flash_area_close(primary);

    if (memcmp(sha_sec, sha_pri, SLOT_SHA256_LEN) == 0) {
        BOOT_LOG_INF("Image %d: secondary matches primary, skip overwrite",
                     img_index);
        erase_spi_secondary(img_index);
        return 0;
    }

    BOOT_LOG_INF("Image %d: secondary differs, overwrite primary", img_index);
    return BOOT_HOOK_REGULAR;
}
