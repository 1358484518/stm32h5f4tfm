#!/usr/bin/env bash
# 只烧当前源码编出来的 STM32H5F4 镜像。拒绝仓库里的旧 H573 快照。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_NS="${ROOT}/trusted-firmware-m/build_s/api_ns"
BL2_BIN="${API_NS}/bin/bl2.bin"

if [[ ! -f "${BL2_BIN}" ]] || [[ ! -x "${API_NS}/TFM_UPDATE.sh" ]]; then
    echo "错误: 还没有编译产物。先在仓库根目录执行: ./buildtfm.sh test"
    exit 1
fi

if ! strings "${BL2_BIN}" | grep -q "Starting bootloader S-sec="; then
    echo "错误: ${BL2_BIN} 没有 S-sec 标记，不是这次移植的 BL2"
    exit 1
fi

if ! grep -q '^slot2=0xc200000$' "${API_NS}/TFM_UPDATE.sh"; then
    echo "错误: ${API_NS}/TFM_UPDATE.sh 的 slot2 不是 0xc200000"
    grep -E '^slot[0-3]=' "${API_NS}/TFM_UPDATE.sh" || true
    exit 1
fi

echo "将要烧录的目录: ${API_NS}"
grep -E '^boot=|^slot0=|^slot1=|^slot2=|^slot3=' "${API_NS}/TFM_UPDATE.sh"
echo
echo "bl2.bin 标记:"
strings "${BL2_BIN}" | grep -E "Starting bootloader S-sec=|Checking image|BL2 flash map S-secondary=" || true
echo

if ! command -v STM32_Programmer_CLI >/dev/null 2>&1; then
    echo "本机没有 STM32_Programmer_CLI，请手动执行:"
    echo "  cd ${API_NS}"
    echo "  ./regression.sh"
    echo "  STM32_Programmer_CLI -c port=SWD mode=HotPlug -ob BOOT_UBE=0xB4"
    echo "  ./TFM_UPDATE.sh"
    echo
    echo "烧完串口必须出现: Starting bootloader S-sec=0x200000"
    exit 0
fi

cd "${API_NS}"
./regression.sh
STM32_Programmer_CLI -c port=SWD mode=HotPlug -ob BOOT_UBE=0xB4
./TFM_UPDATE.sh
echo
echo "烧录结束。复位后串口必须出现: Starting bootloader S-sec=0x200000"
echo "如果仍是 Starting bootloader（没有 S-sec），BL2 没写进去。"
