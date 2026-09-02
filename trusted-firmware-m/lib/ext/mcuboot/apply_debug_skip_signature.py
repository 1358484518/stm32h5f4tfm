#!/usr/bin/env python3
"""Patch MCUBoot image_validate.c to skip signature/hash checks (debug branches).

Only for stm32* p256-debug lines: BL2 still reads the MCUBoot header and jumps,
but does not verify ECDSA/RSA, image hash, or (with rollback off) security counter.

Marker string DBG-NOSIG is left in the source so buildtfm.sh can prove the patch.
"""
from __future__ import annotations

import sys
from pathlib import Path

MARKER = "DBG-NOSIG"

SKIP_BLOCK = """
    /*
     * DBG-NOSIG: debug-branch BL2 — accept primary/secondary images without
     * signature or hash verification so CubeIDE can flash an unsigned NS
     * (header + payload) for download/debug. SPE / PSA partitions are unchanged.
     */
    BOOT_LOG_ERR("DBG-NOSIG: skip image signature validation");
    FIH_RET(FIH_SUCCESS);
"""

ANCHOR = '    BOOT_LOG_DBG("bootutil_img_validate: flash area %p", fap);'


def die(msg: str) -> None:
    print(f"错误: {msg}", file=sys.stderr)
    sys.exit(1)


def patch_file(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    if MARKER in text and "FIH_RET(FIH_SUCCESS)" in text:
        print(f"OK already patched: {path}")
        return
    if ANCHOR not in text:
        die(f"{path} missing validate log anchor")
    if text.count(ANCHOR) != 1:
        die(f"{path} anchor not unique")
    text = text.replace(ANCHOR, ANCHOR + "\n" + SKIP_BLOCK, 1)
    path.write_text(text, encoding="utf-8")
    print(f"patched {path}")


def main() -> None:
    if len(sys.argv) != 2:
        die("用法: apply_debug_skip_signature.py <mcuboot-src>")
    root = Path(sys.argv[1])
    target = root / "boot/bootutil/src/image_validate.c"
    if not target.is_file():
        die(f"找不到 {target}")
    patch_file(target)
    if MARKER not in target.read_text(encoding="utf-8"):
        die(f"{target} 仍没有 {MARKER}")


if __name__ == "__main__":
    main()
