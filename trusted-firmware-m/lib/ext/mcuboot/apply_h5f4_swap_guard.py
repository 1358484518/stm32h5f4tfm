#!/usr/bin/env python3
"""Patch MCUBoot v2.4.0 swap_misc.c / swap_scratch.c in an already-fetched tree.

git apply / GNU patch on a format-patch mailbox can exit 0 without editing
files. This script inserts the H5F4 swap-status guard by unique snippets.
"""
from __future__ import annotations

import sys
from pathlib import Path

MARKER = "H5F4SWP2"

GUARD_DECL = """
/* Linked into BL2 so buildtfm.sh can prove this swap-status guard is present. */
#if defined(MCUBOOT_SWAP_USING_SCRATCH)
__attribute__((used)) static const char mcuboot_h5f4_swap_guard[] = "H5F4SWP2";
#endif
"""

# (void)array[0] is a compile-time no-op. GCC -fdata-sections + ld --gc-sections
# then drops the unreferenced .rodata, so bl2.bin has no H5F4SWP2.
WEAK_KEEP = """#if defined(MCUBOOT_SWAP_USING_SCRATCH)
    /* Keep H5F4SWP2 in the BL2 image despite --gc-sections. */
    (void)mcuboot_h5f4_swap_guard[0];
#endif
"""

STRONG_KEEP = """#if defined(MCUBOOT_SWAP_USING_SCRATCH)
    /* Address operand creates a relocation. (void)array[0] is a no-op and
     * --gc-sections then drops H5F4SWP2 from bl2.bin.
     */
    __asm__ volatile ("" :: "r"(mcuboot_h5f4_swap_guard));
#endif
"""

GUARD_USE = "\n" + STRONG_KEEP + "\n"

DROP_STATUS = """
        /*
         * magic=good and copy_done=unset makes MCUBoot treat the primary as
         * an in-progress swap. A factory image, or a small slot whose payload
         * overlaps the status area sized for MCUBOOT_MAX_IMG_SECTORS, then
         * feeds find_last_sector_idx a swap_size of 0xffffffff (erased
         * trailer) and walks the sector table off the end of SRAM.
         */
        if (!boot_status_is_reset(bs)) {
            uint32_t swap_size = 0;
            uint32_t slot_sz = flash_area_get_size(fap);

            rc = boot_read_swap_size(fap, &swap_size);
            BOOT_LOG_INF("swap status idx=%u state=%u size=0x%x slot=0x%x",
                         (unsigned)bs->idx, (unsigned)bs->state,
                         (unsigned)swap_size, (unsigned)slot_sz);
            if (rc != 0 || swap_size == 0 || swap_size == 0xffffffffu ||
                swap_size > slot_sz) {
                BOOT_LOG_ERR("H5F4SWP2 Dropping invalid swap status size=0x%x",
                             (unsigned)swap_size);
                bs->idx = BOOT_STATUS_IDX_0;
                bs->state = BOOT_STATUS_STATE_0;
#if defined(MCUBOOT_SWAP_USING_OFFSET)
                bs->op = BOOT_STATUS_OP_SWAP;
#else
                bs->op = BOOT_STATUS_OP_MOVE;
#endif
                bs->use_scratch = 0;
                bs->swap_size = 0;
                bs->source = BOOT_STATUS_SOURCE_NONE;
                bs->swap_type = BOOT_SWAP_TYPE_NONE;
                rc = 0;
            }
        }
"""

FIND_LAST_OLD = """    int last_sector_idx_primary;
    int last_sector_idx_secondary;
    uint32_t primary_slot_size;
    uint32_t secondary_slot_size;

    primary_slot_size = 0;
    secondary_slot_size = 0;
    last_sector_idx_primary = 0;
    last_sector_idx_secondary = 0;
"""

FIND_LAST_NEW = """    int last_sector_idx_primary;
    int last_sector_idx_secondary;
    uint32_t primary_slot_size;
    uint32_t secondary_slot_size;
    size_t max_pri;
    size_t max_sec;

    primary_slot_size = 0;
    secondary_slot_size = 0;
    last_sector_idx_primary = 0;
    last_sector_idx_secondary = 0;
    max_pri = boot_img_num_sectors(state, BOOT_SLOT_PRIMARY);
    max_sec = boot_img_num_sectors(state, BOOT_SLOT_SECONDARY);

    if (copy_size == 0 || copy_size == 0xffffffffu ||
        max_pri == 0 || max_sec == 0) {
        BOOT_LOG_ERR("find_last_sector_idx bad copy_size=0x%x pri=%u sec=%u",
                     (unsigned)copy_size, (unsigned)max_pri, (unsigned)max_sec);
        return -1;
    }
"""

PRI_BOUND_OLD = """        if ((primary_slot_size < copy_size) ||
            (primary_slot_size < secondary_slot_size)) {
           primary_slot_size += boot_img_sector_size(state,
                                                     BOOT_SLOT_PRIMARY,
                                                     last_sector_idx_primary);
"""

PRI_BOUND_NEW = """        if ((primary_slot_size < copy_size) ||
            (primary_slot_size < secondary_slot_size)) {
            if ((size_t)last_sector_idx_primary >= max_pri) {
                BOOT_LOG_ERR("find_last_sector_idx overflow copy_size=0x%x pri=%u",
                             (unsigned)copy_size, (unsigned)max_pri);
                return -1;
            }
           primary_slot_size += boot_img_sector_size(state,
                                                     BOOT_SLOT_PRIMARY,
                                                     last_sector_idx_primary);
"""

SEC_BOUND_OLD = """        if ((secondary_slot_size < copy_size) ||
            (secondary_slot_size < primary_slot_size)) {
           secondary_slot_size += boot_img_sector_size(state,
                                                       BOOT_SLOT_SECONDARY,
                                                       last_sector_idx_secondary);
"""

SEC_BOUND_NEW = """        if ((secondary_slot_size < copy_size) ||
            (secondary_slot_size < primary_slot_size)) {
            if ((size_t)last_sector_idx_secondary >= max_sec) {
                BOOT_LOG_ERR("find_last_sector_idx overflow copy_size=0x%x sec=%u",
                             (unsigned)copy_size, (unsigned)max_sec);
                return -1;
            }
           secondary_slot_size += boot_img_sector_size(state,
                                                       BOOT_SLOT_SECONDARY,
                                                       last_sector_idx_secondary);
"""

SWAP_COUNT_OLD = """    last_sector_idx = find_last_sector_idx(state, copy_size);

    swap_count = 0;
"""

SWAP_COUNT_NEW = """    last_sector_idx = find_last_sector_idx(state, copy_size);
    if (last_sector_idx < 0) {
        return 0;
    }

    swap_count = 0;
"""

SWAP_RUN_OLD = """    last_sector_idx = find_last_sector_idx(state, copy_size);

    swap_idx = 0;
"""

SWAP_RUN_NEW = """    last_sector_idx = find_last_sector_idx(state, copy_size);
    if (last_sector_idx < 0) {
        BOOT_LOG_ERR("swap_run aborted copy_size=0x%x", (unsigned)copy_size);
        return;
    }

    swap_idx = 0;
"""

HEADER_OLD = """        swap_count = find_swap_count(state, swap_size);

        if (bs->idx - BOOT_STATUS_IDX_0 >= swap_count) {
"""

HEADER_NEW = """        BOOT_LOG_INF("swap resume size=0x%x idx=%u pri/sec sectors=%u/%u",
                     (unsigned)swap_size, (unsigned)bs->idx,
                     (unsigned)boot_img_num_sectors(state, BOOT_SLOT_PRIMARY),
                     (unsigned)boot_img_num_sectors(state, BOOT_SLOT_SECONDARY));

        swap_count = find_swap_count(state, swap_size);
        if (swap_count == 0) {
            /* Erased/junk swap_size (0xffffffff) or a slot too small for the
             * recorded copy. Read headers from their natural slots instead of
             * walking the sector table off the end of SRAM.
             */
            BOOT_LOG_ERR("H5F4SWP2 Dropping invalid swap status size=0x%x",
                         (unsigned)swap_size);
        } else if (bs->idx - BOOT_STATUS_IDX_0 >= swap_count) {
"""


def die(msg: str) -> None:
    print(f"错误: {msg}", file=sys.stderr)
    raise SystemExit(1)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        die(f"找不到片段 {label}")
    return text.replace(old, new, 1)


def ensure_keepalive(text: str) -> str:
    """Upgrade a previously applied weak keep, or leave a strong keep alone."""
    if "__asm__ volatile (\"\" :: \"r\"(mcuboot_h5f4_swap_guard));" in text:
        return text
    if WEAK_KEEP in text:
        return text.replace(WEAK_KEEP, STRONG_KEEP, 1)
    if "(void)mcuboot_h5f4_swap_guard[0];" in text:
        return text.replace(
            "(void)mcuboot_h5f4_swap_guard[0];",
            '__asm__ volatile ("" :: "r"(mcuboot_h5f4_swap_guard));',
            1,
        )
    return text


def ensure_log_marker(text: str) -> str:
    """Put H5F4SWP2 in the ERR format string so strings(1) can see it."""
    old = 'BOOT_LOG_ERR("Dropping invalid swap status size=0x%x"'
    new = 'BOOT_LOG_ERR("H5F4SWP2 Dropping invalid swap status size=0x%x"'
    return text.replace(old, new)


def patch_swap_misc(path: Path) -> None:
    text = path.read_text()
    if MARKER not in text:
        text = replace_once(
            text,
            "BOOT_LOG_MODULE_DECLARE(mcuboot);\n",
            "BOOT_LOG_MODULE_DECLARE(mcuboot);\n" + GUARD_DECL,
            "BOOT_LOG_MODULE_DECLARE in swap_misc.c",
        )
        text = replace_once(
            text,
            "    int rc;\n\n    bs->source = swap_status_source(state);",
            "    int rc;\n" + GUARD_USE + "\n    bs->source = swap_status_source(state);",
            "swap_read_status rc in swap_misc.c",
        )
        if "boot_status_is_reset(bs)" not in text or "swap_size == 0xffffffffu" not in text:
            text = replace_once(
                text,
                "        bs->swap_type = BOOT_GET_SWAP_TYPE(swap_info);\n    }",
                "        bs->swap_type = BOOT_GET_SWAP_TYPE(swap_info);"
                + DROP_STATUS
                + "    }",
                "BOOT_GET_SWAP_TYPE in swap_misc.c",
            )
    text = ensure_keepalive(text)
    text = ensure_log_marker(text)
    path.write_text(text)


def patch_swap_scratch(path: Path) -> None:
    text = path.read_text()
    if "find_last_sector_idx overflow" not in text:
        text = replace_once(text, FIND_LAST_OLD, FIND_LAST_NEW, "find_last_sector_idx locals")
        text = replace_once(text, PRI_BOUND_OLD, PRI_BOUND_NEW, "primary sector bound")
        text = replace_once(text, SEC_BOUND_OLD, SEC_BOUND_NEW, "secondary sector bound")
        text = replace_once(text, SWAP_COUNT_OLD, SWAP_COUNT_NEW, "find_swap_count")
        text = replace_once(text, SWAP_RUN_OLD, SWAP_RUN_NEW, "swap_run")
        text = replace_once(text, HEADER_OLD, HEADER_NEW, "boot_read_image_header")
    text = ensure_log_marker(text)
    path.write_text(text)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        die("用法: apply_h5f4_swap_guard.py <mcuboot-src>")
    src = Path(argv[1])
    misc = src / "boot/bootutil/src/swap_misc.c"
    scratch = src / "boot/bootutil/src/swap_scratch.c"
    if not misc.is_file() or not scratch.is_file():
        die(f"{src} 里没有 MCUBoot swap 源文件")
    patch_swap_misc(misc)
    patch_swap_scratch(scratch)
    text = misc.read_text()
    if MARKER not in text:
        die(f"写入后 {misc} 仍没有 {MARKER}")
    print(f">>> MCUBoot swap guard 已写入 {src}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
