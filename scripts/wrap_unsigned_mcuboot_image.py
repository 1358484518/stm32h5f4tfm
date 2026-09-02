#!/usr/bin/env python3
"""Wrap a raw NS/S .bin with an unsigned MCUBoot header (BL2_HEADER_SIZE).

Debug BL2 (DBG-NOSIG) accepts the header without verifying a signature TLV.
CubeIDE / makefile can flash the output to the primary slot base.

Example (H5F4 NS primary @ 0x0C090000 / 0x08090000):
  python3 scripts/wrap_unsigned_mcuboot_image.py tfm_ns.bin -o tfm_ns_slot.bin
  STM32_Programmer_CLI ... -d tfm_ns_slot.bin 0x0C090000 -v
"""
from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

IMAGE_MAGIC = 0x96F3B83D


def wrap(payload: bytes, header_size: int, major: int, minor: int, revision: int, build: int) -> bytes:
    if header_size < 32 or header_size % 16:
        raise SystemExit("header_size must be >= 32 and 16-aligned (use 0x400)")
    # struct image_header (mcuboot) — 32 bytes before optional pad to header_size
    hdr = struct.pack(
        "<IIHHIIBBHII",
        IMAGE_MAGIC,
        0,  # ih_load_addr
        header_size,  # ih_hdr_size
        0,  # ih_protect_tlv_size
        len(payload),  # ih_img_size
        0,  # ih_flags
        major & 0xFF,
        minor & 0xFF,
        revision & 0xFFFF,
        build & 0xFFFFFFFF,
        0,  # _pad1
    )
    if len(hdr) != 32:
        raise SystemExit(f"header packed size {len(hdr)} != 32")
    pad = b"\xff" * (header_size - len(hdr))
    return hdr + pad + payload


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("input", type=Path, help="unsigned app .bin (vector table at offset 0)")
    ap.add_argument("-o", "--output", type=Path, required=True)
    ap.add_argument("--header-size", type=lambda s: int(s, 0), default=0x400)
    ap.add_argument("--major", type=int, default=0)
    ap.add_argument("--minor", type=int, default=0)
    ap.add_argument("--revision", type=int, default=0)
    ap.add_argument("--build", type=int, default=0)
    args = ap.parse_args()
    data = args.input.read_bytes()
    out = wrap(data, args.header_size, args.major, args.minor, args.revision, args.build)
    args.output.write_bytes(out)
    print(
        f"wrote {args.output} ({len(out)} bytes): "
        f"header=0x{args.header_size:x} payload={len(data)} "
        f"ver={args.major}.{args.minor}.{args.revision}+{args.build}"
    )


if __name__ == "__main__":
    main()
