#!/usr/bin/env bash
# Flash STM32H5F4 TF-M and prove the on-chip BL2 is the one just built.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_NS="${ROOT}/trusted-firmware-m/build_s/api_ns"
BL2_BIN="${API_NS}/bin/bl2.bin"
BOOT_ADDR=0xc00e000
DUMP="${API_NS}/bl2_onchip.bin"

die() { echo "错误: $*" >&2; exit 1; }

if [[ ! -f "${BL2_BIN}" ]] || [[ ! -x "${API_NS}/TFM_UPDATE.sh" ]]; then
    die "还没有编译产物。先在仓库根目录执行: ./buildtfm.sh test"
fi
strings "${BL2_BIN}" | grep -q "Starting bootloader S-sec=" \
    || die "${BL2_BIN} 没有 S-sec 标记"
grep -q '^slot2=0xc200000$' "${API_NS}/TFM_UPDATE.sh" \
    || die "${API_NS}/TFM_UPDATE.sh 的 slot2 不是 0xc200000"

echo "将要烧录的目录: ${API_NS}"
grep -E '^boot=|^slot0=|^slot1=|^slot2=|^slot3=' "${API_NS}/TFM_UPDATE.sh"
echo
command -v STM32_Programmer_CLI >/dev/null 2>&1 \
    || die "找不到 STM32_Programmer_CLI"

CONNECT_UR="-c port=SWD ap=1 mode=UR"
CONNECT_HP="-c port=SWD ap=1 mode=HotPlug"

cd "${API_NS}"

echo ">>> regression (unlock WRP / erase)"
./regression.sh

echo ">>> BOOT_UBE=0xB4"
STM32_Programmer_CLI ${CONNECT_HP} -ob BOOT_UBE=0xB4

echo ">>> 关掉 HDP，并清 H5F4 的 WRPSG11（不是 H573 的 WRPSGn1）"
STM32_Programmer_CLI ${CONNECT_UR} -ob HDP1_STRT=1 HDP1_END=0 HDP2_STRT=1 HDP2_END=0
STM32_Programmer_CLI ${CONNECT_UR} -ob WRPSG11=0xffffffff WRPSG12=0xffffffff WRPSG21=0xffffffff WRPSG22=0xffffffff
STM32_Programmer_CLI ${CONNECT_HP} -ob displ | grep -E "WRP|HDP|PRODUCT" || true

echo ">>> TFM_UPDATE.sh"
set +e
./TFM_UPDATE.sh
upd_rc=$?
set -e
if [[ "${upd_rc}" -ne 0 ]]; then
    echo "警告: TFM_UPDATE.sh 退出码 ${upd_rc}，继续单独重写并回读 BL2"
fi

echo ">>> 单独再写一次 BL2 并校验"
STM32_Programmer_CLI ${CONNECT_UR} -d "${BL2_BIN}" ${BOOT_ADDR} -v \
    || die "BL2 下载失败（多半是 WRP 还在）。看上面 CubeProgrammer 输出"

echo ">>> 从芯片回读 BL2"
rm -f "${DUMP}"
STM32_Programmer_CLI ${CONNECT_HP} -r ${BOOT_ADDR} 0x20000 "${DUMP}" \
    || die "回读 BL2 失败"
echo "片上 BL2 字符串:"
strings "${DUMP}" | grep -E "H5F4BL2|Starting bootloader|Checking image|BL2 flash map" || true
strings "${DUMP}" | grep -q "Starting bootloader S-sec=" \
    || die "片上 BL2 没有 S-sec。写保护还在，bootloader 没换掉"

echo
echo "片上已经是新 BL2。复位后串口第一行必须是: [INF] H5F4BL2"
STM32_Programmer_CLI ${CONNECT_UR} -hardRst || true
