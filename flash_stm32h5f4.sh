#!/usr/bin/env bash
# STM32H5F4 一键回归 + 烧录（Linux）
#
#   ./flash_stm32h5f4.sh                 # 一键：解锁/必要时整片擦除 + 烧 BL2/S/NS
#   ./flash_stm32h5f4.sh all             # 同上
#   ./flash_stm32h5f4.sh erase           # 强制 regression 整片擦除后再烧
#   ./flash_stm32h5f4.sh regression      # 同 erase
#   ./flash_stm32h5f4.sh download        # 只烧镜像（不擦片 / 不改 option bytes）
#   ./flash_stm32h5f4.sh unlock-only     # 绝不整片擦除；HDP 仍覆盖 BL2 则直接失败（仍会烧）
#   ./flash_stm32h5f4.sh regression-only # 只跑回归（全片擦除），不烧镜像
#
# STM32H5 hide-protect (HDP) can be enlarged but not shrunk by option bytes.
# Old BL2 sets HDP1=[0, 0x13] (0x0C000000-0x0C026000), which covers all of BL2.
# CubeProgrammer then reports "HDP programmed" while -ob displ still shows
# HDP1_END=0x13, and BL2 verify fails at 0x0C010000 (first byte that differs).
# WRPSG11=0xFFFFFFFF is not enough. Mass-erase the old BL2, then program.
#
# Windows 对应：windows-tfm-tools\tfm_update.bat
# SPDX-License-Identifier: BSD-3-Clause
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_NS="${ROOT}/trusted-firmware-m/build_s/api_ns"
REGRESSION_SRC="${ROOT}/trusted-firmware-m/platform/ext/target/stm/stm32h5f4/regression.sh"
BL2_BIN="${API_NS}/bin/bl2.bin"
BOOT_ADDR=0xc00e000
# First mismatch in the user's log: start of sector 8 / SECBOOTADD.
BL2_VEC_ADDR=0x0C010000
DUMP="${API_NS}/bl2_onchip.bin"

die() { echo "错误: $*" >&2; exit 1; }

usage() {
    cat <<'EOF'
用法:
  ./flash_stm32h5f4.sh                    # 一键：解锁/必要时整片擦除 + 烧录
  ./flash_stm32h5f4.sh all                # 同上
  ./flash_stm32h5f4.sh erase|regression   # 强制回归整片擦除后再烧
  ./flash_stm32h5f4.sh download           # 只烧 BL2 + S + NS
  ./flash_stm32h5f4.sh unlock-only        # 不整片擦除；HDP 盖住 BL2 则失败
  ./flash_stm32h5f4.sh regression-only    # 只回归，不烧
  ./flash_stm32h5f4.sh --help

先编译: ./buildtfm.sh test
产物: trusted-firmware-m/build_s/api_ns/bin/{bl2,tfm_s_signed}.bin
      trusted-firmware-m/build_ns/bin/tfm_ns_signed.bin（由 TFM_UPDATE.sh 使用）
EOF
}

MODE="all"
case "${1:-}" in
    ""|all|unlock)
        MODE="all"
        ;;
    erase|regression|regress)
        MODE="erase"
        ;;
    download|flash|update)
        MODE="download"
        ;;
    unlock-only)
        MODE="unlock-only"
        ;;
    regression-only|erase-only)
        MODE="regression-only"
        ;;
    --self-test)
        MODE="--self-test"
        ;;
    -h|--help|help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        die "未知参数: $*"
        ;;
esac

ob_hex_field() {
    local dump="$1"
    local name="$2"
    printf '%s\n' "${dump}" | sed -n "s/.*${name}[[:space:]]*:[[:space:]]*\(0x[0-9A-Fa-f]\+\).*/\1/p" | head -n 1
}

# HDP is disabled when start > end (ST encoding: STRT=1 END=0).
hdp1_disabled() {
    local dump="$1"
    local strt end
    strt="$(ob_hex_field "${dump}" "HDP1_STRT")"
    end="$(ob_hex_field "${dump}" "HDP1_END")"
    [[ -n "${strt}" && -n "${end}" ]] || return 1
    [[ $((strt)) -gt $((end)) ]]
}

# BL2 download erases sectors [7 23] (0x0C00E000, 128 KB).
hdp1_overlaps_bl2() {
    local dump="$1"
    local strt end
    strt="$(ob_hex_field "${dump}" "HDP1_STRT")"
    end="$(ob_hex_field "${dump}" "HDP1_END")"
    [[ -n "${strt}" && -n "${end}" ]] || return 0
    local s=$((strt)) e=$((end))
    [[ "${s}" -le "${e}" ]] || return 1
    local bl2_s=7 bl2_e=23
    [[ "${s}" -le "${bl2_e}" && "${e}" -ge "${bl2_s}" ]]
}

if [[ "${MODE}" == "--self-test" ]]; then
    sample='     PRODUCT_STATE: 0xED (Open)
     WRPSG11      : 0xFFFFFFFF  (0x8000000)
     HDP1_STRT    : 0x0  (0x0)
     HDP1_END     : 0x13  (0x26000)
     HDP2_STRT    : 0x1  (0x2000)
     HDP2_END     : 0x0  (0x0)'
    hdp1_overlaps_bl2 "${sample}" || die "self-test: HDP [0, 0x13] must overlap BL2"
    hdp1_disabled "${sample}" && die "self-test: HDP [0, 0x13] must not look disabled"
    sample_off='     HDP1_STRT    : 0x1  (0x2000)
     HDP1_END     : 0x0  (0x0)'
    hdp1_disabled "${sample_off}" || die "self-test: HDP STRT>END must be disabled"
    hdp1_overlaps_bl2 "${sample_off}" && die "self-test: disabled HDP must not overlap BL2"
    echo "flash_stm32h5f4.sh self-test OK"
    exit 0
fi

need_images=1
[[ "${MODE}" == "regression-only" ]] && need_images=0

if [[ "${need_images}" -eq 1 ]]; then
    if [[ ! -f "${BL2_BIN}" ]] || [[ ! -x "${API_NS}/TFM_UPDATE.sh" ]]; then
        die "还没有编译产物。先在仓库根目录执行: ./buildtfm.sh"
    fi
    # 不要用 strings | grep -q：pipefail 下 strings 会 SIGPIPE，误报没有标记
    # S-sec 是 BOOT_LOG_INF，正式版 ERROR 日志不会编进 bl2.bin；认 H5F4BL2 即可。
    grep -a -F -q "H5F4BL2" "${BL2_BIN}" \
        || die "${BL2_BIN} 没有 H5F4BL2 标记。这是旧产物，请先: git pull && ./buildtfm.sh"
    grep -a -F -q "H5F4SWP2" "${BL2_BIN}" \
        || die "${BL2_BIN} 没有 MCUBoot 0002 标记 H5F4SWP2（image 0 会 BusFault）。请: git pull && ./buildtfm.sh"
    grep -q '^slot2=0xc200000$' "${API_NS}/TFM_UPDATE.sh" \
        || die "${API_NS}/TFM_UPDATE.sh 的 slot2 不是 0xc200000"
    grep -q '^slot1=0xc090000$' "${API_NS}/TFM_UPDATE.sh" \
        || die "${API_NS}/TFM_UPDATE.sh 的 slot1 不是 0xc090000（S 槽应为 352 KB）"

    echo "将要烧录的目录: ${API_NS}"
    grep -E '^boot=|^slot0=|^slot1=|^slot2=|^slot3=' "${API_NS}/TFM_UPDATE.sh"
    echo
fi

command -v STM32_Programmer_CLI >/dev/null 2>&1 \
    || die "找不到 STM32_Programmer_CLI"

CONNECT_UR="-c port=SWD ap=1 mode=UR"
CONNECT_HP="-c port=SWD ap=1 mode=HotPlug"

read_ob_dump() {
    STM32_Programmer_CLI ${CONNECT_UR} -ob displ
}

unlock_wrp_hdp() {
    echo ">>> 关掉 HDP，并清 H5F4 的 WRPSG11（不是 H573 的 WRPSGn1）"
    # 分两次：H5 option-byte 名写错时整条 -ob 都会被丢掉
    STM32_Programmer_CLI ${CONNECT_UR} -ob HDP1_STRT=1 HDP1_END=0 HDP2_STRT=1 HDP2_END=0 || true
    STM32_Programmer_CLI ${CONNECT_UR} -ob WRPSG11=0xffffffff WRPSG12=0xffffffff WRPSG21=0xffffffff WRPSG22=0xffffffff
}

mass_erase_old_bl2() {
    echo ">>> 整片擦除旧 BL2（HDP 覆盖 BL2 时，只改 option bytes 缩不了 HDP）"
    echo "    WRP 已是 0xFFFFFFFF 也没用：HDP1_END=0x13 盖住 0x0C000000-0x0C026000。"
    echo "    CubeProgrammer 会显示 Option Bytes successfully programmed，但 HDP1 仍是 [0, 0x13]。"
    echo "    这会清空用户 Flash；PRODUCT_STATE 保持 Open (0xED)。"
    if [[ -x "${REGRESSION_SRC}" ]]; then
        echo ">>> 用仓库里的 regression.sh（不依赖可能过期的 build_s 拷贝）"
        mkdir -p "${API_NS}"
        (cd "${API_NS}" && bash "${REGRESSION_SRC}")
    elif [[ -x "${API_NS}/regression.sh" ]]; then
        (cd "${API_NS}" && ./regression.sh)
    else
        STM32_Programmer_CLI ${CONNECT_UR} \
            -ob WRPSG11=0xffffffff WRPSG12=0xffffffff WRPSG21=0xffffffff WRPSG22=0xffffffff \
            -e all \
            || die "整片擦除失败"
    fi
    echo ">>> 擦除后再关 HDP（此时旧 BL2 已不在，不会把 HDP 锁回去）"
    STM32_Programmer_CLI ${CONNECT_UR} -ob HDP1_STRT=1 HDP1_END=0 HDP2_STRT=1 HDP2_END=0 || true
    STM32_Programmer_CLI ${CONNECT_UR} -ob WRPSG11=0xffffffff WRPSG12=0xffffffff WRPSG21=0xffffffff WRPSG22=0xffffffff || true
}

assert_bl2_region_erased() {
    local head="${API_NS}/bl2_vec_after_erase.bin"
    local got
    rm -f "${head}"
    STM32_Programmer_CLI ${CONNECT_UR} -r ${BL2_VEC_ADDR} 16 "${head}" \
        || die "擦除后读 0x0C010000 失败"
    got="$(od -An -tx1 "${head}" | tr -d ' \n')"
    if [[ "${got}" != ffffffffffffffffffffffffffffffff ]]; then
        echo "erase check bytes: ${got}"
        die "擦除后 0x0C010000 不是 0xFF，HDP 连 mass erase 都挡住了。请用 CubeProgrammer GUI: Option Bytes → Reset MCU to Factory Settings"
    fi
    echo ">>> 0x0C010000 已是 0xFF，旧 BL2 已被擦掉"
}

run_prepare_unlock() {
    local force_fail_on_hdp="$1"
    echo ">>> 先读 option bytes，确认是不是 HDP 而不是 WRP"
    OB_DUMP="$(read_ob_dump)"
    printf '%s\n' "${OB_DUMP}" | grep -E "WRP|HDP|PRODUCT|SECWM" || true
    if hdp1_overlaps_bl2 "${OB_DUMP}"; then
        echo
        echo ">>> HDP1 仍覆盖 BL2。S/NS 能校验通过是因为它们在 0x0C038000 之外；"
        echo "    BL2 在 0x0C00E000，落在 HDP1 [STRT, END] 里面。"
        echo "    只跑 -ob HDP1_STRT=1 HDP1_END=0 不能缩小已设置的 HDP。"
        if [[ "${force_fail_on_hdp}" == "1" ]]; then
            die "HDP 仍覆盖 BL2。请改跑: ./flash_stm32h5f4.sh erase"
        fi
        mass_erase_old_bl2
    else
        echo ">>> 不解整片，只解锁 WRP/HDP"
        unlock_wrp_hdp
    fi
    echo ">>> BOOT_UBE=0xB4"
    STM32_Programmer_CLI ${CONNECT_HP} -ob BOOT_UBE=0xB4 || true
}

run_prepare_erase() {
    mass_erase_old_bl2
    echo ">>> BOOT_UBE=0xB4"
    STM32_Programmer_CLI ${CONNECT_HP} -ob BOOT_UBE=0xB4 || true
}

verify_hdp_after_prepare() {
    OB_DUMP="$(read_ob_dump)"
    printf '%s\n' "${OB_DUMP}" | grep -E "WRP|HDP|PRODUCT|SECWM" || true
    if hdp1_overlaps_bl2 "${OB_DUMP}"; then
        echo "警告: 擦除/解锁后 HDP1 仍然覆盖 BL2。若 0x0C010000 已是 0xFF，仍可在 HDPL1 下写入。"
        assert_bl2_region_erased
    else
        echo ">>> HDP1 已关闭（STRT > END）"
    fi
}

run_download() {
    cd "${API_NS}"
    echo ">>> TFM_UPDATE.sh（烧 BL2 + S + NS）"
    set +e
    ./TFM_UPDATE.sh
    upd_rc=$?
    set -e
    if [[ "${upd_rc}" -ne 0 ]]; then
        echo "警告: TFM_UPDATE.sh 退出码 ${upd_rc}，继续单独重写并回读 BL2"
    fi

    echo ">>> 单独再写一次 BL2 并校验"
    STM32_Programmer_CLI ${CONNECT_UR} -d "${BL2_BIN}" ${BOOT_ADDR} -v \
        || die "BL2 下载失败。若地址是 0x0C010000：这是 HDP，不是 WRP。请 ./flash_stm32h5f4.sh erase，或 GUI Reset MCU to Factory Settings"

    echo ">>> 从芯片回读 BL2"
    rm -f "${DUMP}"
    STM32_Programmer_CLI ${CONNECT_HP} -r ${BOOT_ADDR} 0x20000 "${DUMP}" \
        || die "回读 BL2 失败"
    echo "片上 BL2 字符串:"
    strings "${DUMP}" | grep -E "H5F4BL2|Starting bootloader|Checking image|BL2 flash map" || true
    grep -a -F -q "H5F4BL2" "${DUMP}" \
        || die "片上 BL2 没有 H5F4BL2。写保护还在，bootloader 没换掉"

    echo
    echo "片上已经是新 BL2。复位后串口必须有:"
    echo "  H5F4BL2                         （BOOT_LOG_ERR，正式版也会打）"
    echo "  BANK 2 secure flash [0, 39]     （不能再是 [255, 0]）"
    echo "  不能出现 set wrp1 / set hdp1"
    echo "  Image 0 boot_go done"
    STM32_Programmer_CLI ${CONNECT_UR} -hardRst || true
}

case "${MODE}" in
    regression-only)
        run_prepare_erase
        verify_hdp_after_prepare
        echo "回归完成（未烧镜像）。接着可: ./flash_stm32h5f4.sh download"
        ;;
    download)
        echo ">>> 只下载（不改 option bytes / 不整片擦除）"
        run_download
        echo "download Done"
        ;;
    erase)
        run_prepare_erase
        verify_hdp_after_prepare
        run_download
        echo "全部完成（强制回归 + 烧录）。"
        ;;
    unlock-only)
        run_prepare_unlock 1
        verify_hdp_after_prepare
        run_download
        echo "全部完成（解锁 + 烧录）。"
        ;;
    all)
        run_prepare_unlock 0
        verify_hdp_after_prepare
        run_download
        echo "全部完成。"
        ;;
esac
