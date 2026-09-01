#!/usr/bin/env bash
# STM32H573I-DK  TF-M 一键编译（硬件浮点）
#
# 用法:
#   ./buildtfm.sh              # 交互选择 测试版 / 正式版
#   ./buildtfm.sh test         # 测试版：TEST_S/NS 全开，INFO 日志
#   ./buildtfm.sh prod         # 正式版：SPE 不带 S 测试分区，NS 测试程序可烧可跑，ERROR 日志
#   ./buildtfm.sh test --no-clean   # 增量（不清 build，仍用本地依赖缓存）
#   ./buildtfm.sh -h
#
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail

usage() {
    cat <<'EOF'
STM32H573I-DK TF-M 编译脚本（已启用硬件浮点 FPv5-SP-D16）

用法:
  ./buildtfm.sh              交互选择构建类型
  ./buildtfm.sh test         测试版（TEST_S + TEST_NS，INFO 日志）
  ./buildtfm.sh prod         正式版（TEST_S 关，TEST_NS 开，NS 测试可烧可跑，ERROR 日志）
  ./buildtfm.sh test --no-clean   不清 build 目录（增量，仍用本地依赖缓存）

默认每次编译会先调用 scripts/clean_tfm_build.sh：只清编译结果，
把已下载的 mcuboot/cmsis/… 留在 trusted-firmware-m/.deps-cache，不重新联网。

仓库根目录 keys/ 若放了固定文件名公私钥，会先覆盖各工程同名文件再编。

别名: test|debug|回归    prod|release|formal|正式
EOF
}

BUILD_TYPE=""
# 默认每次编译先清 build 产物并还原本地依赖缓存（避免 rm -rf 后重新下载）。
# 增量编译：./buildtfm.sh test --no-clean  或  BUILDTFM_NO_CLEAN=1 ./buildtfm.sh test
DO_CLEAN=1
[[ "${BUILDTFM_NO_CLEAN:-0}" == "1" ]] && DO_CLEAN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        test|debug|回归) BUILD_TYPE="test" ;;
        prod|release|formal|正式) BUILD_TYPE="prod" ;;
        clean|--clean) DO_CLEAN=1 ;;
        --no-clean|noclean) DO_CLEAN=0 ;;
        "")
            ;;
        *)
            echo "未知参数: $1"
            usage
            exit 2
            ;;
    esac
    shift || true
done

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
CLEAN_SH="${WORK_ROOT}/scripts/clean_tfm_build.sh"

# 测试版 <-> 正式版或 TEST_* / 签名算法变化时清掉 SPE 缓存（须在离线检查之前）
STAMP="${TFM_ROOT}/build_s/.buildtfm_type"
SIG_TYPE="$(sed -n 's/^[[:space:]]*set(MCUBOOT_SIGNATURE_TYPE[[:space:]]*"\([^"]*\)".*/\1/p' \
    "${TFM_ROOT}/platform/ext/target/stm/stm32h573i_dk/config.cmake" 2>/dev/null \
    | head -1)"
SIG_TYPE="${SIG_TYPE:-RSA-3072}"
STAMP_VAL="${BUILD_TYPE} ${TEST_FLAGS[*]} ${LOG_FLAGS[*]} SIG=${SIG_TYPE}"
if [[ -f "${STAMP}" ]] && [[ "$(cat "${STAMP}")" != "${STAMP_VAL}" ]]; then
    echo ">>> 构建配置已切换，将清除编译产物（保留依赖缓存）"
    DO_CLEAN=1
fi
echo ">>> MCUBOOT_SIGNATURE_TYPE: ${SIG_TYPE}"

# 若仓库根目录 keys/ 放了固定文件名的公私钥，则覆盖各工程同名文件 + BL2 root-*.pem。
# 缺失源文件或目标目录不存在只告警，不中断编译。
sync_user_signing_keys() {
    local sync_sh="${WORK_ROOT}/scripts/sync_user_signing_keys.sh"
    if [[ ! -f "${sync_sh}" ]]; then
        echo "警告: 缺少 ${sync_sh}，跳过 keys/ 用户密钥同步"
        return 0
    fi
    bash "${sync_sh}" "${WORK_ROOT}" "${SIG_TYPE}" || true
}

# 根据当前签名私钥同步 STM OTP 表里的 bl2_rotpk_*（及 provisioning.c dummy 哈希）。
sync_stm_otp_rotpk() {
    local sync_py="${WORK_ROOT}/scripts/sync_stm_otp_rotpk.py"
    local key_s key_ns
    if [[ ! -f "${sync_py}" ]]; then
        echo "警告: 缺少 ${sync_py}，跳过 OTP ROTPK 同步"
        return 0
    fi
    case "${SIG_TYPE}" in
        EC-P256)
            key_s="${TFM_ROOT}/bl2/ext/mcuboot/root-EC-P256.pem"
            key_ns="${TFM_ROOT}/bl2/ext/mcuboot/root-EC-P256_1.pem"
            ;;
        EC-P384)
            key_s="${TFM_ROOT}/bl2/ext/mcuboot/root-EC-P384.pem"
            key_ns="${TFM_ROOT}/bl2/ext/mcuboot/root-EC-P384_1.pem"
            ;;
        RSA-2048)
            key_s="${TFM_ROOT}/bl2/ext/mcuboot/root-RSA-2048.pem"
            key_ns="${TFM_ROOT}/bl2/ext/mcuboot/root-RSA-2048_1.pem"
            ;;
        RSA-3072)
            key_s="${TFM_ROOT}/bl2/ext/mcuboot/root-RSA-3072.pem"
            key_ns="${TFM_ROOT}/bl2/ext/mcuboot/root-RSA-3072_1.pem"
            ;;
        *)
            echo "警告: 未知 SIG=${SIG_TYPE}，跳过 OTP ROTPK 同步"
            return 0
            ;;
    esac
    [[ -n "${MCUBOOT_KEY_S:-}" ]] && key_s="${MCUBOOT_KEY_S}"
    [[ -n "${MCUBOOT_KEY_NS:-}" ]] && key_ns="${MCUBOOT_KEY_NS}"
    "${PYTHON}" "${sync_py}" \
        --tfm-root "${TFM_ROOT}" \
        --sig-type "${SIG_TYPE}" \
        --key-s "${key_s}" \
        --key-ns "${key_ns}"
}

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
# Always install TF-M Python deps into *this* venv. Do not use `command -v hex_generation`
# (may hit another venv on PATH and skip jinja2/pyyaml/…).
"${PYTHON}" -m pip install -q -e "${TFM_ROOT}"
"${PYTHON}" -c "import cryptography, jinja2, yaml" 2>/dev/null || {
    echo "错误: TF-M Python 依赖未装好（需要 cryptography/jinja2/pyyaml 等）"
    exit 1
}
"${PYTHON}" -c "import shutil,sys; sys.exit(0 if shutil.which('hex_generation') else 1)" \
    || { echo "错误: hex_generation 未安装"; exit 1; }

sync_user_signing_keys
sync_stm_otp_rotpk

# 清编译产物 / 还原本地依赖（避免每次 rm -rf build_s 后重新下载）
if [[ -f "${CLEAN_SH}" ]]; then
    if [[ "${DO_CLEAN}" -eq 1 ]]; then
        bash "${CLEAN_SH}" "${TFM_ROOT}"
    else
        echo ">>> --no-clean：保留 build 目录，仅确保依赖缓存可用"
        bash "${CLEAN_SH}" --save-only "${TFM_ROOT}" || true
        bash "${CLEAN_SH}" --restore-only "${TFM_ROOT}" || true
    fi
else
    echo "警告: 缺少 ${CLEAN_SH}，退回旧逻辑"
    if [[ "${DO_CLEAN}" -eq 1 ]]; then
        rm -rf "${TFM_ROOT}/build_s" "${TFM_ROOT}/build_ns"
    fi
fi

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
    -DTFM_PLATFORM=stm/stm32h573i_dk \
    -DTFM_TOOLCHAIN_FILE="${TFM_ROOT}/toolchain_GNUARM.cmake" \
    -DTFM_PSA_API=ON \
    -DTFM_ISOLATION_LEVEL=1 \
    -DMCUBOOT_SIGNATURE_TYPE="${SIG_TYPE}" \
    "${TEST_FLAGS[@]}" \
    "${FP_FLAGS[@]}" \
    "${LOG_FLAGS[@]}" \
    "${FETCH_OFF[@]}"

ninja -C build_s install -j"$(nproc)"
mkdir -p "$(dirname "${STAMP}")"
echo "${STAMP_VAL}" > "${STAMP}"
if [[ -f "${CLEAN_SH}" ]]; then
    bash "${CLEAN_SH}" --save-only "${TFM_ROOT}" || true
fi

SPE_CONFIG="${TFM_ROOT}/build_s/api_ns/cmake/spe_config.cmake"
[[ -f "${SPE_CONFIG}" ]] && \
    sed -i 's/^set(CHECK_TFM_TESTS_VERSION.*$/set(CHECK_TFM_TESTS_VERSION OFF)/' "${SPE_CONFIG}"

echo ">>> build_ns (回归测试程序，可烧录可跑)"
if [[ -f "${CLEAN_SH}" ]]; then
    if [[ -d "${TFM_ROOT}/build_ns" ]]; then
        bash "${CLEAN_SH}" --save-only "${TFM_ROOT}" || true
        rm -rf "${TFM_ROOT}/build_ns"
    fi
    bash "${CLEAN_SH}" --restore-only "${TFM_ROOT}" || true
else
    rm -rf build_ns
    mkdir -p "${LIB_EXT_NS}"
    for lib in qcbor t_cose; do
        [[ -d "${LIB_EXT_S}/${lib}-src" ]] && cp -a "${LIB_EXT_S}/${lib}-src" "${LIB_EXT_NS}/"
    done
fi
mkdir -p "${LIB_EXT_NS}"
for lib in qcbor t_cose; do
    if [[ ! -d "${LIB_EXT_NS}/${lib}-src" && -d "${LIB_EXT_S}/${lib}-src" ]]; then
        cp -a "${LIB_EXT_S}/${lib}-src" "${LIB_EXT_NS}/"
    fi
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

echo ""
grep -E '^boot=|^slot0=|^slot1=' TFM_UPDATE.sh || true
echo ""
echo "=== 编译完成（${BUILD_LABEL}，硬件浮点 ON）==="
echo "烧录: cd ${TFM_ROOT}/build_s/api_ns && ./regression.sh"
echo "      STM32_Programmer_CLI -c port=SWD mode=HotPlug -ob BOOT_UBE=0xB4"
echo "      ./TFM_UPDATE.sh"
echo "NS 测试程序: ${TFM_ROOT}/build_ns/bin/tfm_ns_signed.bin  地址 0x0C088000"
echo "烧录后会上电自动跑回归测试（串口 115200 看 PASSED/FAILED）。"
