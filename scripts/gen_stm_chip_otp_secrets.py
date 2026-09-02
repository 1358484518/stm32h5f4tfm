#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
"""
Generate per-device STM32H5 on-chip Flash OTP secrets (HUK + IAK + boot_seed + impl_id).

Writes a binary/Intel-HEX image mapped at FLASH_OTP_BASE (0x08FFF000) matching
struct stm_chip_otp_secrets in stm_chip_otp_secrets.h.

Also exports:
  - iak_private.pem / iak_public.pem  (ECDSA P-256) for attestation enrollment
  - huk.bin                           (raw 32-byte HUK; keep offline)

Factory flow (irreversible OTP programming — use scrap silicon first):
  1) python3 scripts/gen_stm_chip_otp_secrets.py --out-dir factory/<sn>
  2) Program chip OTP with STM32CubeProgrammer OTP panel / CLI (see README)
  3) Optionally lock OTP blocks 0-9 via Option Bytes
  4) Flash BL2 + S + NS from this production branch
"""
from __future__ import annotations

import argparse
import binascii
import os
import struct
import sys
from pathlib import Path

try:
    from cryptography.hazmat.backends import default_backend
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import ec
except ImportError as exc:  # pragma: no cover
    print("需要 cryptography：pip install cryptography", file=sys.stderr)
    raise SystemExit(2) from exc

MAGIC = 0x53544D31  # 'STM1'
# Host-side generator emits v1 plaintext HUK for bring-up / HSM archive.
# Production DHUK protection (v2 + FLAG_HUK_DHUK) must be sealed ON-DEVICE
# via stm_chip_otp_secrets_build_dhuk_image() — the PC has no DHUK.
VERSION = 1
OTP_BASE = 0x08FFF000
FLAG_HUK_DHUK = 1 << 0


def crc32_iso(data: bytes) -> int:
    return binascii.crc32(data) & 0xFFFFFFFF


def ihex_line(addr: int, data: bytes, rectype: int = 0) -> str:
    assert len(data) <= 16
    al = addr & 0xFFFF
    record = bytes([len(data), (al >> 8) & 0xFF, al & 0xFF, rectype]) + data
    csum = ((-(sum(record))) & 0xFF)
    return ":" + record.hex().upper() + f"{csum:02X}"


def write_ihex(path: Path, base: int, blob: bytes) -> None:
    lines = []
    # Extended linear address
    ela = (base >> 16) & 0xFFFF
    lines.append(ihex_line(0, bytes([(ela >> 8) & 0xFF, ela & 0xFF]), rectype=4))
    offset = base & 0xFFFF
    for i in range(0, len(blob), 16):
        chunk = blob[i : i + 16]
        lines.append(ihex_line(offset + i, chunk, rectype=0))
    lines.append(":00000001FF")
    path.write_text("\n".join(lines) + "\n")


def build_blob(huk: bytes, iak: bytes, boot_seed: bytes, impl_id: bytes) -> bytes:
    assert len(huk) == 32 and len(iak) == 32
    assert len(boot_seed) == 32 and len(impl_id) == 32
    head = struct.pack("<IIII", MAGIC, VERSION, 0, 0)
    body = head + huk + iak + boot_seed + impl_id
    return body + struct.pack("<I", crc32_iso(body))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out-dir", required=True, help="Output directory for this device")
    ap.add_argument(
        "--impl-id-hex",
        default=None,
        help="Optional 64-hex-char implementation_id (default: random)",
    )
    ap.add_argument(
        "--allow-overwrite",
        action="store_true",
        help="Overwrite existing out-dir contents",
    )
    args = ap.parse_args()

    out = Path(args.out_dir)
    if out.exists() and any(out.iterdir()) and not args.allow_overwrite:
        print(f"错误: {out} 非空，加 --allow-overwrite 才会覆盖", file=sys.stderr)
        return 1
    out.mkdir(parents=True, exist_ok=True)

    huk = os.urandom(32)
    boot_seed = os.urandom(32)
    if args.impl_id_hex:
        impl_id = bytes.fromhex(args.impl_id_hex)
        if len(impl_id) != 32:
            print("impl-id-hex 必须是 32 字节（64 hex）", file=sys.stderr)
            return 1
    else:
        impl_id = os.urandom(32)

    priv = ec.generate_private_key(ec.SECP256R1(), default_backend())
    iak = priv.private_numbers().private_value.to_bytes(32, "big")
    # Reject TF-M known dummy IAK leading qword
    if int.from_bytes(iak[:8], "little") == 0xA4906F6DB254B4A9:
        print("极端巧合撞上 dummy IAK 前缀，请重跑", file=sys.stderr)
        return 1

    blob = build_blob(huk, iak, boot_seed, impl_id)

    (out / "chip_otp_secrets.bin").write_bytes(blob)
    write_ihex(out / "chip_otp_secrets.hex", OTP_BASE, blob)
    (out / "huk.bin").write_bytes(huk)
    (out / "iak_raw.bin").write_bytes(iak)
    (out / "boot_seed.bin").write_bytes(boot_seed)
    (out / "implementation_id.bin").write_bytes(impl_id)

    (out / "iak_private.pem").write_bytes(
        priv.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.TraditionalOpenSSL,
            serialization.NoEncryption(),
        )
    )
    (out / "iak_public.pem").write_bytes(
        priv.public_key().public_bytes(
            serialization.Encoding.PEM,
            serialization.PublicFormat.SubjectPublicKeyInfo,
        )
    )

    meta = out / "README.txt"
    meta.write_text(
        f"""STM32H5 chip OTP secrets (production)
=====================================
Target address : 0x{OTP_BASE:08X}
Blob size      : {len(blob)} bytes
Magic/version  : 0x{MAGIC:08X} / {VERSION}  (host v1 = plaintext HUK)

DHUK note
---------
This host image stores HUK in plaintext (v1). For builds with
STM_PROD_DHUK_WRAP_HUK, seal ON the MCU with:
  stm_chip_otp_secrets_build_dhuk_image(...)
then program the returned v2 image (flag HUK_DHUK) into Flash OTP.
The PC cannot apply DHUK — it lives only inside SAES.

Files
-----
chip_otp_secrets.bin / .hex  — program into on-chip Flash OTP (or seal first)
huk.bin                      — keep in HSM / offline vault (never commit)
iak_private.pem / iak_raw.bin— device attestation private key material
iak_public.pem               — enroll with your attestation verifier
boot_seed.bin / implementation_id.bin

Program (example, adjust to your CubeProgrammer version)
--------------------------------------------------------
STM32_Programmer_CLI -c port=SWD mode=UR -w chip_otp_secrets.hex
# Then lock OTP blocks that contain this blob (blocks 0..N) via Option Bytes.
# OTP programming is ONE-WAY. Validate on scrap parts first.

After OTP is programmed, flash BL2+S+NS from the DHUK/production feature branch.
ROTPK (image verify) still comes from keys/ via ./buildtfm.sh — separate from IAK/HUK.
"""
    )

    print(f">>> wrote {out}")
    print(f"    chip OTP image: {out / 'chip_otp_secrets.hex'} @ 0x{OTP_BASE:08X}")
    print(f"    enroll pubkey : {out / 'iak_public.pem'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
