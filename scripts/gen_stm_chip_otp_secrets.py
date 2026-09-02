#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
"""
Generate per-device STM32H5 secrets for production feature branches.

On-chip Flash OTP @ 0x08FFF000:
  - HUK, boot_seed, implementation_id (IAK field zeroed when using Flash IAK)

Secure Flash IAK (DHUK-sealed on-device):
  - iak_raw.bin / iak_*.pem for factory seal via
    stm_iak_flash_dhuk_seal_and_store() into FLASH_IAK_DHUK_AREA (0x0C030000)

Also exports huk.bin for HSM archive.
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
IAK_FLASH_BASE = 0x0C030000  # FLASH_BASE + FLASH_IAK_DHUK_AREA_OFFSET


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
    ela = (base >> 16) & 0xFFFF
    lines.append(ihex_line(0, bytes([(ela >> 8) & 0xFF, ela & 0xFF]), rectype=4))
    offset = base & 0xFFFF
    for i in range(0, len(blob), 16):
        chunk = blob[i : i + 16]
        lines.append(ihex_line(offset + i, chunk, rectype=0))
    lines.append(":00000001FF")
    path.write_text("\n".join(lines) + "\n")


def build_otp_blob(huk: bytes, boot_seed: bytes, impl_id: bytes) -> bytes:
    """OTP image with IAK field zeroed (IAK lives in Secure Flash + DHUK)."""
    assert len(huk) == 32 and len(boot_seed) == 32 and len(impl_id) == 32
    iak_placeholder = bytes(32)
    head = struct.pack("<IIII", MAGIC, VERSION, 0, 0)
    body = head + huk + iak_placeholder + boot_seed + impl_id
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
    if int.from_bytes(iak[:8], "little") == 0xA4906F6DB254B4A9:
        print("极端巧合撞上 dummy IAK 前缀，请重跑", file=sys.stderr)
        return 1

    blob = build_otp_blob(huk, boot_seed, impl_id)

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
        f"""STM32H5 production secrets
=====================================
Chip OTP @ 0x{OTP_BASE:08X} : HUK + boot_seed + impl_id (IAK field = 0)
IAK Secure Flash @ 0x{IAK_FLASH_BASE:08X} : DHUK-sealed on-device
Blob size (OTP)  : {len(blob)} bytes
Magic/version    : 0x{MAGIC:08X} / {VERSION}  (host v1 = plaintext HUK)

IAK (Secure Flash + DHUK)
-------------------------
Do NOT program iak_raw.bin as plaintext into flash.
On the target MCU call:
  stm_iak_flash_dhuk_seal_and_store(iak_raw)
This encrypts with SAES DHUK and erases/programs the 8 KB Secure Flash sector
at FLASH_IAK_DHUK_AREA_OFFSET (0x30000 → 0x0C030000). Re-run to rotate IAK
during bring-up. After debug lock, only SPE can read/decrypt.

HUK (on-chip OTP + optional DHUK)
---------------------------------
This host OTP image stores HUK in plaintext (v1). For STM_PROD_DHUK_WRAP_HUK,
seal ON the MCU with stm_chip_otp_secrets_build_dhuk_image(...) then program
the returned v2 image into Flash OTP. PC has no DHUK.

Files
-----
chip_otp_secrets.bin / .hex  — program into on-chip Flash OTP (or seal HUK first)
huk.bin                      — keep in HSM / offline vault (never commit)
iak_private.pem / iak_raw.bin— feed to on-device IAK seal API
iak_public.pem               — enroll with your attestation verifier
boot_seed.bin / implementation_id.bin

After secrets are provisioned, flash BL2+S+NS from the feature branch.
ROTPK still comes from keys/ via ./buildtfm.sh.
"""
    )

    print(f">>> wrote {out}")
    print(f"    chip OTP image: {out / 'chip_otp_secrets.hex'} @ 0x{OTP_BASE:08X}")
    print(f"    IAK seal input : {out / 'iak_raw.bin'} → on-device @ 0x{IAK_FLASH_BASE:08X}")
    print(f"    enroll pubkey : {out / 'iak_public.pem'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
