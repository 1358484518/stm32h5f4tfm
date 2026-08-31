#!/usr/bin/env bash
# STM32H5F4  TF-M 一键编译（硬件浮点）
#
# 用法:
#   ./buildtfm.sh              # 交互选择 测试版 / 正式版
#   ./buildtfm.sh test         # 测试版：TEST_S/NS 全开，INFO 日志
#   ./buildtfm.sh prod         # 正式版：SPE 不带 S 测试分区，NS 测试程序可烧可跑，ERROR 日志
#   ./buildtfm.sh -h
#
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail

usage() {
    cat <<'EOF'
STM32H5F4 TF-M 编译脚本（已启用硬件浮点 FPv5-SP-D16）

用法:
  ./buildtfm.sh              交互选择构建类型
  ./buildtfm.sh test         测试版（TEST_S + TEST_NS，INFO 日志）
  ./buildtfm.sh prod         正式版（TEST_S 关，TEST_NS 开，NS 测试可烧可跑，ERROR 日志）

别名: test|debug|回归    prod|release|formal|正式
EOF
}

BUILD_TYPE=""
case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    test|debug|回归) BUILD_TYPE="test"; shift || true ;;
    prod|release|formal|正式) BUILD_TYPE="prod"; shift || true ;;
    "") ;;
    *)
        echo "未知参数: $1"
        usage
        exit 2
        ;;
esac

if [[ -z "${BUILD_TYPE}" ]]; then
    echo "请选择构建类型:"
    echo "  1) 测试版  — TEST_S / TEST_NS 全开，INFO 日志"
    echo "  2) 正式版  — 安全侧不带测试分区，NS 测试程序仍可烧可跑，ERROR 日志"
    echo -n "输入 1 或 2: "
    read -r choice
    case "${choice}" in
        1) BUILD_TYPE="test" ;;
        2) BUILD_TYPE="prod" ;;
        *) echo "无效选择"; exit 2 ;;
    esac
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 支持两种目录布局:
#   A) 脚本在仓库外:  WORK/buildtfm.sh  WORK/trusted-firmware-m  WORK/tf-m-tests
#   B) 脚本在仓库内:  TF-M/buildtfm.sh  上一级或旁路有 tf-m-tests
if [[ -f "${SCRIPT_DIR}/trusted-firmware-m/CMakeLists.txt" ]]; then
    WORK_ROOT="${SCRIPT_DIR}"
    TFM_ROOT="${WORK_ROOT}/trusted-firmware-m"
    TFM_TESTS="${WORK_ROOT}/tf-m-tests"
elif [[ -f "${SCRIPT_DIR}/CMakeLists.txt" && -d "${SCRIPT_DIR}/secure_fw" ]]; then
    TFM_ROOT="${SCRIPT_DIR}"
    WORK_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
    if [[ -f "${WORK_ROOT}/tf-m-tests/tests_reg/spe/CMakeLists.txt" ]]; then
        TFM_TESTS="${WORK_ROOT}/tf-m-tests"
    elif [[ -f "${TFM_ROOT}/../tf-m-tests/tests_reg/spe/CMakeLists.txt" ]]; then
        TFM_TESTS="$(cd "${TFM_ROOT}/../tf-m-tests" && pwd)"
    else
        TFM_TESTS="${WORK_ROOT}/tf-m-tests"
    fi
else
    echo "错误: 找不到 TF-M 源码（请把脚本放在仓库根目录或与仓库同级）"
    exit 1
fi

[[ -f "${TFM_ROOT}/CMakeLists.txt" ]] || { echo "错误: 缺少 ${TFM_ROOT}"; exit 1; }
[[ -f "${TFM_TESTS}/tests_reg/spe/CMakeLists.txt" ]] || { echo "错误: 缺少 ${TFM_TESTS}"; exit 1; }

cd "${TFM_ROOT}"

if [[ "${BUILD_TYPE}" == "test" ]]; then
    BUILD_LABEL="测试版"
    TEST_FLAGS=(-DTEST_S=ON -DTEST_NS=ON)
    LOG_FLAGS=(
        -DTFM_BL2_LOG_LEVEL=LOG_LEVEL_INFO
        -DTFM_SPM_LOG_LEVEL=LOG_LEVEL_INFO
        -DTFM_PARTITION_LOG_LEVEL=LOG_LEVEL_INFO
    )
else
    BUILD_LABEL="正式版"
    # 正式 SPE 不编安全侧测试分区；NS 仍是可烧、可跑的回归测试程序
    TEST_FLAGS=(-DTEST_S=OFF -DTEST_NS=ON)
    LOG_FLAGS=(
        -DTFM_BL2_LOG_LEVEL=LOG_LEVEL_ERROR
        -DTFM_SPM_LOG_LEVEL=LOG_LEVEL_ERROR
        -DTFM_PARTITION_LOG_LEVEL=LOG_LEVEL_ERROR
    )
fi

# Cortex-M33 单精度硬件 FPU；BL2 仍为 soft（TF-M 默认）
# NS cmake 只吃命令行/ spe_config，STM cpuarch 不设 FP，必须把配套开关一起传
FP_FLAGS=(
    -DCONFIG_TFM_ENABLE_FP=ON
    -DCONFIG_TFM_FP_ARCH=fpv5-sp-d16
    -DCONFIG_TFM_ENABLE_CP10CP11=ON
    -DCONFIG_TFM_FLOAT_ABI=hard
    -DCONFIG_TFM_LAZY_STACKING=ON
)

echo ">>> WORK_ROOT: ${WORK_ROOT}"
echo ">>> TFM_ROOT:  ${TFM_ROOT}"
echo ">>> TFM_TESTS: ${TFM_TESTS}"
echo ">>> 构建类型:  ${BUILD_LABEL}  (硬件浮点 ON, fpv5-sp-d16)"

LIB_EXT_S="${TFM_ROOT}/build_s/build-spe/lib/ext"
LIB_EXT_NS="${TFM_ROOT}/build_ns/lib/ext"

# 测试版 <-> 正式版或 TEST_* 变化时清掉 SPE 缓存（须在离线检查之前）
STAMP="${TFM_ROOT}/build_s/.buildtfm_type"
STAMP_VAL="${BUILD_TYPE} ${TEST_FLAGS[*]} ${LOG_FLAGS[*]}"
if [[ -f "${STAMP}" ]] && [[ "$(cat "${STAMP}")" != "${STAMP_VAL}" ]]; then
    echo ">>> 构建配置已切换，清理 build_s"
    rm -rf "${TFM_ROOT}/build_s"
fi

# Python：用 python -m pip，避免拷贝来的 venv shebang 失效
VENV_DIR="${WORK_ROOT}/.venv"
if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
    echo ">>> 创建 Python venv: ${VENV_DIR}"
    if ! python3 -m venv "${VENV_DIR}"; then
        echo "错误: 创建 venv 失败。Debian/Ubuntu 请先执行:"
        echo "  apt install -y python3-venv python3-pip"
        exit 1
    fi
fi
# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"
export PATH="${VENV_DIR}/bin:${PATH}"
PYTHON="${VENV_DIR}/bin/python"
"${PYTHON}" -m pip install -q --upgrade pip setuptools wheel || true
if ! command -v hex_generation >/dev/null 2>&1; then
    "${PYTHON}" -m pip install -q -e "${TFM_ROOT}"
fi
command -v hex_generation >/dev/null || { echo "错误: hex_generation 未安装"; exit 1; }

# cmake FetchContent 增量配置可能把已拉取的 MCUBoot 重置回 tag，冲掉 0002。
# 必须在 cmake 之后、ninja 之前打补丁，并 touch 源文件逼 ninja 重编 bootutil。
apply_mcuboot_0002() {
    local patch="${TFM_ROOT}/lib/ext/mcuboot/0002-bootutil-Bound-scratch-swap-sector-walk.patch"
    local src misc
    local found=0
    [[ -f "${patch}" ]] || { echo "错误: 缺少 ${patch}"; exit 1; }
    while IFS= read -r src; do
        misc="${src}/boot/bootutil/src/swap_misc.c"
        [[ -f "${misc}" ]] || continue
        found=1
        if grep -q 'H5F4SWP2' "${misc}"; then
            echo ">>> MCUBoot 0002 已在 ${src}"
            continue
        fi
        echo ">>> 给 ${src} 打 MCUBoot 0002"
        if grep -q "Dropping invalid swap status" "${misc}"; then
            # 旧 0002 已打上，只补不依赖日志、且能抗 --gc-sections 的标记
            python3 - "${misc}" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
t = p.read_text()
if "H5F4SWP2" in t:
    raise SystemExit(0)
needle = "BOOT_LOG_MODULE_DECLARE(mcuboot);"
insert = needle + """
#if defined(MCUBOOT_SWAP_USING_SCRATCH)
__attribute__((used)) static const char mcuboot_h5f4_swap_guard[] = "H5F4SWP2";
#endif
"""
if needle not in t:
    raise SystemExit("insert point missing")
t = t.replace(needle, insert, 1)
use = "    bs->source = swap_status_source(state);"
use_ins = """#if defined(MCUBOOT_SWAP_USING_SCRATCH)
    (void)mcuboot_h5f4_swap_guard[0];
#endif
""" + use
if use in t:
    t = t.replace(use, use_ins, 1)
p.write_text(t)
PY
        elif git -C "${src}" apply "${patch}"; then
            :
        elif (cd "${src}" && patch -p1 < "${patch}"); then
            :
        else
            echo "错误: MCUBoot 0002 补丁失败。请: rm -rf ${TFM_ROOT}/build_s && $0 ${BUILD_TYPE}"
            exit 1
        fi
        grep -q 'H5F4SWP2' "${misc}" || { echo "错误: 打补丁后仍没有 H5F4SWP2"; exit 1; }
        touch "${misc}" "${src}/boot/bootutil/src/swap_scratch.c"
        find "${TFM_ROOT}/build_s" \( -name 'swap_misc.c.o' -o -name 'swap_scratch.c.o' \) -delete 2>/dev/null || true
    done < <(find "${TFM_ROOT}/build_s" -type d -name 'mcuboot-src' 2>/dev/null)
    if [[ "${found}" -eq 0 ]]; then
        echo "错误: 找不到 mcuboot-src，无法打 0002"
        exit 1
    fi
}

# 有 lib/ext 就离线，没有就自动在线下载
OFFLINE=1
for lib in qcbor mcuboot cmsis t_cose tf-psa-crypto tf-m-extras; do
    [[ -d "${LIB_EXT_S}/${lib}-src" ]] || OFFLINE=0
done
[[ -f "${LIB_EXT_S}/qcbor-src/src/qcbor_encode.c" ]] || OFFLINE=0

if [[ "${OFFLINE}" -eq 1 ]]; then
    echo ">>> 离线模式"
    FETCH_OFF=(-DFETCHCONTENT_FULLY_DISCONNECTED=ON)
else
    echo ">>> 在线模式（首次会下载依赖，较慢）"
    FETCH_OFF=()
fi

# 关掉 tf-m-tests 版本检查（只打一次补丁）
CV="${TFM_TESTS}/cmake/check_version.cmake"
if [[ -f "${CV}" ]] && ! grep -q 'buildtfm: skip version check' "${CV}"; then
    sed -i '8i\return() # buildtfm: skip version check' "${CV}"
fi

echo ">>> build_s (${BUILD_LABEL})"
cmake -S "${TFM_TESTS}/tests_reg/spe" -B build_s -GNinja \
    -DCONFIG_TFM_SOURCE_PATH="${TFM_ROOT}" \
    -DTFM_PLATFORM=stm/stm32h5f4 \
    -DTFM_TOOLCHAIN_FILE="${TFM_ROOT}/toolchain_GNUARM.cmake" \
    -DTFM_PSA_API=ON \
    -DTFM_ISOLATION_LEVEL=1 \
    "${TEST_FLAGS[@]}" \
    "${FP_FLAGS[@]}" \
    "${LOG_FLAGS[@]}" \
    "${FETCH_OFF[@]}"

apply_mcuboot_0002

ninja -C build_s install -j"$(nproc)"
mkdir -p "$(dirname "${STAMP}")"
echo "${STAMP_VAL}" > "${STAMP}"

SPE_CONFIG="${TFM_ROOT}/build_s/api_ns/cmake/spe_config.cmake"
[[ -f "${SPE_CONFIG}" ]] && \
    sed -i 's/^set(CHECK_TFM_TESTS_VERSION.*$/set(CHECK_TFM_TESTS_VERSION OFF)/' "${SPE_CONFIG}"

echo ">>> build_ns (回归测试程序，可烧录可跑)"
rm -rf build_ns
mkdir -p "${LIB_EXT_NS}"
for lib in qcbor t_cose; do
    [[ -d "${LIB_EXT_S}/${lib}-src" ]] && cp -a "${LIB_EXT_S}/${lib}-src" "${LIB_EXT_NS}/"
done

cmake -S "${TFM_TESTS}/tests_reg" -B build_ns -GNinja \
    -DCONFIG_SPE_PATH="${TFM_ROOT}/build_s/api_ns" \
    -DTFM_TOOLCHAIN_FILE="${TFM_ROOT}/build_s/api_ns/cmake/toolchain_ns_GNUARM.cmake" \
    "${FP_FLAGS[@]}" \
    "${FETCH_OFF[@]}"

ninja -C build_ns -j"$(nproc)"

echo ">>> postbuild"
cd build_s/api_ns
chmod +x postbuild.sh regression.sh TFM_UPDATE.sh preprocess.sh 2>/dev/null || true
./postbuild.sh "$(command -v arm-none-eabi-gcc)"

BL2_BIN="${TFM_ROOT}/build_s/api_ns/bin/bl2.bin"
[[ -f "${BL2_BIN}" ]] || { echo "错误: 找不到 ${BL2_BIN}"; exit 1; }
# grep -q + pipefail 会因 strings 收到 SIGPIPE 而误报失败
if ! grep -a -F -q "Starting bootloader S-sec=" "${BL2_BIN}"; then
    echo "错误: ${BL2_BIN} 没有 S-sec 标记，这不是当前源码编出来的 BL2，禁止烧录"
    strings "${BL2_BIN}" | grep -E "Starting bootloader|H5F4BL2" || true
    exit 1
fi
if ! grep -a -F -q "H5F4BL2" "${BL2_BIN}"; then
    echo "错误: ${BL2_BIN} 没有 H5F4BL2 标记（编译产物不是当前源码）"
    strings "${BL2_BIN}" | grep -E "Starting bootloader|H5F4BL2" || true
    exit 1
fi
if ! grep -a -F -q "H5F4SWP2" "${BL2_BIN}"; then
    echo "错误: ${BL2_BIN} 没有 MCUBoot 0002 标记 H5F4SWP2（image 0 会在 0x30180000 BusFault）"
    echo "cmake 可能冲掉了补丁。请再跑一次 ./buildtfm.sh ${BUILD_TYPE}；仍失败则: rm -rf ${TFM_ROOT}/build_s && ./buildtfm.sh ${BUILD_TYPE}"
    exit 1
fi
if ! grep -q '^slot2=0xc200000$' TFM_UPDATE.sh; then
    echo "错误: TFM_UPDATE.sh 的 slot2 必须是 0xc200000（S secondary 在 bank 2）"
    grep -E '^slot[0-3]=' TFM_UPDATE.sh || true
    exit 1
fi

echo ""
grep -E '^boot=|^slot0=|^slot1=|^slot2=|^slot3=' TFM_UPDATE.sh || true
echo ""
echo "=== 编译完成（${BUILD_LABEL}，硬件浮点 ON）==="
echo "************************************************************"
echo "* 只能烧下面这个目录，不要用 tfmcubeideproject /"
echo "* tfmmakeproject / windows-tfm-tools 里的旧脚本和 hex"
echo "* ${TFM_ROOT}/build_s/api_ns"
echo "*"
echo "* cd ${TFM_ROOT}/build_s/api_ns"
echo "* ./regression.sh"
echo "* STM32_Programmer_CLI -c port=SWD mode=HotPlug -ob BOOT_UBE=0xB4"
echo "* ./TFM_UPDATE.sh"
echo "*"
echo "* 烧完串口第一行必须有: [INF] H5F4BL2"
echo "* 如果仍是 Starting bootloader（没有 H5F4BL2 / S-sec），BL2 没写进去"
echo "************************************************************"
echo "NS 测试程序: ${TFM_ROOT}/build_ns/bin/tfm_ns_signed.bin  地址 0x0C088000"
echo "NS 用户 Flash 数据区: 0x0C37C000  大小 528 KB（到 4 MB 末尾）"
