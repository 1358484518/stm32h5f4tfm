/*
 * SPDX-FileCopyrightText: Copyright The TrustedFirmware-M Contributors
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * SPE links bootutil_public.c with MCUBOOT_IMAGE_ACCESS_HOOKS. Only this
 * hook is called from that translation unit.
 */

#include "bootutil/boot_hooks.h"
#include "bootutil/bootutil_public.h"

int boot_read_swap_state_primary_slot_hook(int image_index,
                                           struct boot_swap_state *state)
{
    (void)image_index;
    (void)state;
    return BOOT_HOOK_REGULAR;
}
