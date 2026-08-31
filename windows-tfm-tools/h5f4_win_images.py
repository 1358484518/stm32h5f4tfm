#!/usr/bin/env python3
"""Locate and verify STM32H5F4 TF-M images for the Windows flash bats.

BL2 must contain H5F4BL2 and H5F4SWP2. Old H573 hex in this folder does not.
Intel HEX 0x0Cxxxxxx records are remapped to 0x08xxxxxx across the full 4 MB.
"""
from __future__ import annotations

import argparse
import os
import sys
import tempfile

BL2_MARKERS = (b"H5F4BL2", b"H5F4SWP2")
S_SEC_MARKER = b"Starting bootloader S-sec="
FLASH_NS_BASE = 0x08000000
FLASH_S_BASE = 0x0C000000
FLASH_BYTES = 4 * 1024 * 1024
FLASH_S_END = FLASH_S_BASE + FLASH_BYTES
REQUIRED_SLOTS = {
    "boot": "0xc00e000",
    "slot0": "0xc038000",
    "slot1": "0xc090000",
    "slot2": "0xc200000",
    "slot3": "0xc258000",
}


def repo_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def hex_records(path):
    ela = 0
    with open(path, "r", encoding="ascii", errors="ignore") as f:
        for raw in f:
            t = raw.strip()
            if not t.startswith(":") or len(t) < 11:
                continue
            length = int(t[1:3], 16)
            offset = int(t[3:7], 16)
            typ = int(t[7:9], 16)
            if typ == 4:
                ela = int(t[9:13], 16)
                continue
            if typ != 0:
                continue
            addr = (ela << 16) + offset
            data = bytes(int(t[9 + 2 * i : 11 + 2 * i], 16) for i in range(length))
            yield addr, data


def remap_secure_alias(addr):
    if FLASH_S_BASE <= addr < FLASH_S_END:
        return addr - (FLASH_S_BASE - FLASH_NS_BASE)
    return addr


def decode_image_bytes(path):
    lower = path.lower()
    if lower.endswith(".hex"):
        recs = list(hex_records(path))
        if not recs:
            return b""
        min_a = min(a for a, _ in recs)
        max_a = max(a + len(d) - 1 for a, d in recs)
        size = max_a - min_a + 1
        if size <= 0 or size > FLASH_BYTES:
            recs.sort(key=lambda x: x[0])
            return b"".join(d for _, d in recs)
        blob = bytearray(size)
        for addr, data in recs:
            off = addr - min_a
            blob[off : off + len(data)] = data
        return bytes(blob)
    with open(path, "rb") as f:
        return f.read()


def bl2_marker_error(path):
    try:
        blob = decode_image_bytes(path)
    except OSError as exc:
        return "cannot read %s: %s" % (path, exc)
    missing = [m.decode("ascii") for m in BL2_MARKERS if m not in blob]
    if missing:
        return "%s missing %s (old H573 image or wrong file)" % (
            path,
            ", ".join(missing),
        )
    if S_SEC_MARKER not in blob:
        return "%s missing %s" % (path, S_SEC_MARKER.decode("ascii"))
    return None


def parse_update_slots(path):
    slots = {}
    with open(path, "r", encoding="ascii", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if "=" not in line:
                continue
            key, val = line.split("=", 1)
            if key in REQUIRED_SLOTS:
                slots[key] = val.strip()
    return slots


def update_sh_error(path):
    slots = parse_update_slots(path)
    bad = []
    for key, want in REQUIRED_SLOTS.items():
        got = slots.get(key)
        if got != want:
            bad.append("%s=%s (want %s)" % (key, got or "<missing>", want))
    if bad:
        return "%s flash map is not H5F4: %s" % (path, "; ".join(bad))
    return None


def search_dirs(extra_cwd=None):
    root = repo_root()
    script = os.path.dirname(os.path.abspath(__file__))
    cwd = os.path.abspath(extra_cwd or os.getcwd())
    dirs = [
        os.path.join(root, "trusted-firmware-m", "build_s", "api_ns", "bin"),
        os.path.join(root, "trusted-firmware-m", "build_ns", "bin"),
        os.path.join(root, "trusted-firmware-m", "build_s", "api_ns", "image_signing", "scripts"),
        cwd,
        script,
    ]
    seen = set()
    out = []
    for d in dirs:
        ap = os.path.abspath(d)
        if ap in seen:
            continue
        seen.add(ap)
        out.append(ap)
    return out


def first_existing(dirs, names):
    for d in dirs:
        for name in names:
            p = os.path.join(d, name)
            if os.path.isfile(p):
                yield p


def locate(extra_cwd=None):
    dirs = search_dirs(extra_cwd)
    info = {
        "STATUS": "OK",
        "ERROR": "",
        "BL2": "",
        "S_SIGNED": "",
        "S_NS_SIGNED": "",
        "NS_SIGNED": "",
        "UPDATE_SH": "",
        "REPO": repo_root(),
    }

    root = repo_root()
    update_sh = os.path.join(root, "trusted-firmware-m", "build_s", "api_ns", "TFM_UPDATE.sh")
    if os.path.isfile(update_sh):
        err = update_sh_error(update_sh)
        if err:
            info["STATUS"] = "FAIL"
            info["ERROR"] = err
            return info
        info["UPDATE_SH"] = update_sh

    bl2 = None
    skipped = []
    for cand in first_existing(dirs, ("bl2.bin", "bl2.hex")):
        err = bl2_marker_error(cand)
        if err:
            skipped.append(err)
            continue
        bl2 = cand
        break
    if not bl2:
        info["STATUS"] = "FAIL"
        if skipped:
            info["ERROR"] = (
                "no H5F4 BL2 (need H5F4BL2 + H5F4SWP2). "
                "Build with ./buildtfm.sh test, then flash from "
                "trusted-firmware-m\\build_s\\api_ns\\bin. "
                + " | ".join(skipped[:3])
            )
        else:
            info["ERROR"] = (
                "bl2.bin / bl2.hex not found. Run ./buildtfm.sh test first "
                "(or copy build_s\\api_ns\\bin\\bl2.bin here)."
            )
        return info
    info["BL2"] = bl2

    for cand in first_existing(dirs, ("tfm_s_signed.bin", "tfm_s_signed.hex")):
        info["S_SIGNED"] = cand
        break
    for cand in first_existing(dirs, ("tfm_s_ns_signed.bin", "tfm_s_ns_signed.hex")):
        info["S_NS_SIGNED"] = cand
        break
    for cand in first_existing(dirs, ("tfm_ns_signed.bin", "tfm_ns_signed.hex")):
        info["NS_SIGNED"] = cand
        break

    have_s = bool(info["S_SIGNED"] or info["S_NS_SIGNED"])
    have_ns = bool(info["NS_SIGNED"] or info["S_NS_SIGNED"])
    if not have_s:
        info["STATUS"] = "FAIL"
        info["ERROR"] = (
            "no S image (tfm_s_signed.bin or tfm_s_ns_signed.bin/.hex). "
            "Run ./buildtfm.sh test first."
        )
        return info
    if not have_ns:
        info["STATUS"] = "FAIL"
        info["ERROR"] = (
            "no NS image (tfm_ns_signed.bin) and no concatenated S+NS image. "
            "Run ./buildtfm.sh test first."
        )
        return info
    return info


def print_locate(info):
    for key in (
        "STATUS",
        "ERROR",
        "REPO",
        "BL2",
        "S_SIGNED",
        "S_NS_SIGNED",
        "NS_SIGNED",
        "UPDATE_SH",
    ):
        print("%s=%s" % (key, info.get(key, "")))


def hex_to_ns_bin(infile, outfile):
    recs = [(remap_secure_alias(a), d) for a, d in hex_records(infile)]
    if not recs:
        sys.exit("No data records in %s" % infile)
    min_a = min(a for a, d in recs)
    max_a = max(a + len(d) - 1 for a, d in recs)
    size = max_a - min_a + 1
    if size <= 0 or size > FLASH_BYTES:
        sys.exit("HEX span 0x%08X-0x%08X size=%d too large" % (min_a, max_a, size))
    if FLASH_S_BASE <= min_a < FLASH_S_END:
        sys.exit("converted address still 0x0C: 0x%08X" % min_a)
    blob = bytearray([0xFF]) * size
    for addr, data in recs:
        off = addr - min_a
        blob[off : off + len(data)] = data
    with open(outfile, "wb") as out:
        out.write(blob)
    with open(outfile + ".addr", "w", encoding="ascii") as out:
        out.write("0x%08X\n" % min_a)
    print("LOAD=0x%08X SIZE=%d" % (min_a, size))


def cmd_self_test():
    # Bank 2 NS secondary 0x0C258000 must remap (old script stopped at 0x0C200000).
    recs = [
        (0x0C00E000, b"\x11"),
        (0x0C258000, b"\x22"),
        (0x0C3FFFF0, b"\x33"),
        (0x08038000, b"\x44"),
    ]
    mapped = [remap_secure_alias(a) for a, _ in recs]
    assert mapped == [0x0800E000, 0x08258000, 0x083FFFF0, 0x08038000], mapped
    assert remap_secure_alias(0x0C400000) == 0x0C400000

    with tempfile.TemporaryDirectory() as td:
        good = os.path.join(td, "bl2.bin")
        with open(good, "wb") as f:
            f.write(b"pad H5F4BL2 pad H5F4SWP2 pad Starting bootloader S-sec=0x200000")
        assert bl2_marker_error(good) is None

        bad = os.path.join(td, "old.bin")
        with open(bad, "wb") as f:
            f.write(b"Starting bootloader")
        err = bl2_marker_error(bad)
        assert err and "H5F4BL2" in err, err

        hex_path = os.path.join(td, "bank2.hex")
        # type 04 ELA 0x0C25, offset 0x8000 -> 0x0C258000, one data byte 0xA5
        rec = bytearray.fromhex("0108000000A5")
        ela = bytearray.fromhex("020000040C25")
        def csum(payload):
            s = (-sum(payload)) & 0xFF
            return payload + bytes([s])
        # :02 0000 04 0C25 checksum
        ela_pl = bytes([0x02, 0x00, 0x00, 0x04, 0x0C, 0x25])
        data_pl = bytes([0x01, 0x80, 0x00, 0x00, 0xA5])
        with open(hex_path, "w", encoding="ascii") as f:
            f.write(":" + csum(ela_pl).hex().upper() + "\n")
            f.write(":" + csum(data_pl).hex().upper() + "\n")
            f.write(":00000001FF\n")
        out_bin = os.path.join(td, "out.bin")
        hex_to_ns_bin(hex_path, out_bin)
        with open(out_bin + ".addr", encoding="ascii") as f:
            addr = f.read().strip()
        assert addr.lower() == "0x08258000", addr
        with open(out_bin, "rb") as f:
            assert f.read() == b"\xa5"

        upd = os.path.join(td, "TFM_UPDATE.sh")
        with open(upd, "w", encoding="ascii") as f:
            f.write("slot0=0xc038000\nslot1=0xc088000\nslot2=0xc200000\n")
            f.write("slot3=0xc258000\nboot=0xc00e000\n")
        err = update_sh_error(upd)
        assert err and "slot1" in err, err

    real_bl2 = os.path.join(
        repo_root(), "trusted-firmware-m", "build_s", "api_ns", "bin", "bl2.bin"
    )
    if os.path.isfile(real_bl2):
        err = bl2_marker_error(real_bl2)
        assert err is None, err
        loc = locate()
        assert loc["STATUS"] == "OK", loc
        assert loc["BL2"].endswith("bl2.bin"), loc
        print("locate BL2=%s" % loc["BL2"])
        print("locate S_SIGNED=%s" % loc["S_SIGNED"])
        print("locate NS_SIGNED=%s" % loc["NS_SIGNED"])
    script_dir = os.path.dirname(os.path.abspath(__file__))
    env = open(os.path.join(script_dir, "h5f4_env.bat"), encoding="utf-8").read()
    assert 'set "H5F4_ADDR_NS_S=0x0C090000"' in env
    assert 'set "H5F4_ADDR_NS_NS=0x08090000"' in env
    assert "WRPSG11=0xffffffff" in env
    assert 'set "H5F4_SECWM_FULL=SECWM1_STRT=0 SECWM1_END=255' in env
    assert "WRPSGn1=" not in env
    for name in (
        "regression.bat",
        "tfm_update.bat",
        "jlink_regression.bat",
        "jlink_tfm_update.bat",
        "erase_flash.bat",
        "jlink_erase_flash.bat",
    ):
        text = open(os.path.join(script_dir, name), encoding="utf-8", errors="ignore").read()
        assert "WRPSG11" in text, name
        assert "WRPSGn1=" not in text, name
        assert "0x08088000" not in text, name
        assert "STM32H573I-DK" not in text, name
    erase = open(os.path.join(script_dir, "erase_flash.bat"), encoding="utf-8").read()
    assert " -e all" in erase
    assert "SECWM1_STRT=255" in erase
    assert "H5F4_SECWM_FULL" not in erase
    print("h5f4_win_images.py self-test OK")


def main(argv=None):
    p = argparse.ArgumentParser(description="STM32H5F4 Windows image helper")
    p.add_argument("-InFile", dest="infile")
    p.add_argument("-OutFile", dest="outfile")
    p.add_argument("--self-test", action="store_true")
    p.add_argument("command", nargs="?", help="locate | check | remap | self-test")
    p.add_argument("path", nargs="?", help="file for check")
    args = p.parse_args(argv)

    if args.infile and args.outfile:
        hex_to_ns_bin(args.infile, args.outfile)
        return 0

    cmd = (args.command or "").lower()
    if args.self_test or cmd in ("self-test", "--self-test"):
        cmd_self_test()
        return 0
    if cmd == "locate":
        info = locate()
        print_locate(info)
        return 0 if info["STATUS"] == "OK" else 1
    if cmd == "check":
        if not args.path:
            sys.exit("check requires a file path")
        err = bl2_marker_error(args.path)
        if err:
            print(err, file=sys.stderr)
            return 1
        print("OK %s" % args.path)
        return 0
    if cmd == "remap":
        if not args.path:
            sys.exit("remap requires -InFile and -OutFile")
        sys.exit("use -InFile / -OutFile")
    p.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
