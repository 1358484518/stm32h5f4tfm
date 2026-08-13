#!/usr/bin/env bash
# STM32H573I-DK  TF-M tests_reg 一键编译
# 用法: ./buildtfm.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="${SCRIPT_DIR}"
TFM_ROOT="${WORK_ROOT}/trusted-firmware-m"
TFM_TESTS="${WORK_ROOT}/tf-m-tests"

[[ -f "${TFM_ROOT}/CMakeLists.txt" ]] || { echo "错误: 缺少 ${TFM_ROOT}"; exit 1; }
[[ -f "${TFM_TESTS}/tests_reg/spe/CMakeLists.txt" ]] || { echo "错误: 缺少 ${TFM_TESTS}"; exit 1; }

cd "${TFM_ROOT}"
echo ">>> WORK_ROOT: ${WORK_ROOT}"
echo ">>> TFM_ROOT:  ${TFM_ROOT}"
echo ">>> TFM_TESTS: ${TFM_TESTS}"

LIB_EXT_S="${TFM_ROOT}/build_s/build-spe/lib/ext"
LIB_EXT_NS="${TFM_ROOT}/build_ns/lib/ext"

# Python + hex_generation
VENV_DIR="${WORK_ROOT}/.venv"
if [[ ! -f "${VENV_DIR}/bin/activate" ]]; then
  python3 -m venv "${VENV_DIR}"
fi
source "${VENV_DIR}/bin/activate"
export PATH="${VENV_DIR}/bin:${PATH}"
pip install -q --upgrade pip setuptools wheel 2>/dev/null || true
pip install -q -e "${TFM_ROOT}"
command -v hex_generation >/dev/null || { echo "错误: hex_generation 未安装"; exit 1; }

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

# build_s
echo ">>> build_s"
cmake -S "${TFM_TESTS}/tests_reg/spe" -B build_s -GNinja \
  -DCONFIG_TFM_SOURCE_PATH="${TFM_ROOT}" \
  -DTFM_PLATFORM=stm/stm32h573i_dk \
  -DTFM_TOOLCHAIN_FILE="${TFM_ROOT}/toolchain_GNUARM.cmake" \
  -DTFM_PSA_API=ON \
  -DTFM_ISOLATION_LEVEL=1 \
  -DTEST_S=ON -DTEST_NS=ON \
  -DTFM_BL2_LOG_LEVEL=LOG_LEVEL_INFO \
  -DTFM_SPM_LOG_LEVEL=LOG_LEVEL_INFO \
  -DTFM_PARTITION_LOG_LEVEL=LOG_LEVEL_INFO \
  "${FETCH_OFF[@]}"

ninja -C build_s install -j"$(nproc)"

# install 后 spe_config 会重置版本检查
SPE_CONFIG="${TFM_ROOT}/build_s/api_ns/cmake/spe_config.cmake"
[[ -f "${SPE_CONFIG}" ]] && \
  sed -i 's/^set(CHECK_TFM_TESTS_VERSION.*$/set(CHECK_TFM_TESTS_VERSION OFF)/' "${SPE_CONFIG}"

# build_ns（每次清空重配，避免旧缓存）
echo ">>> build_ns"
rm -rf build_ns
mkdir -p "${LIB_EXT_NS}"
for lib in qcbor t_cose; do
  [[ -d "${LIB_EXT_S}/${lib}-src" ]] && cp -a "${LIB_EXT_S}/${lib}-src" "${LIB_EXT_NS}/"
done

cmake -S "${TFM_TESTS}/tests_reg" -B build_ns -GNinja \
  -DCONFIG_SPE_PATH="${TFM_ROOT}/build_s/api_ns" \
  -DTFM_TOOLCHAIN_FILE="${TFM_ROOT}/build_s/api_ns/cmake/toolchain_ns_GNUARM.cmake" \
  "${FETCH_OFF[@]}"

ninja -C build_ns -j"$(nproc)"

# postbuild
echo ">>> postbuild"
cd build_s/api_ns
chmod +x postbuild.sh regression.sh TFM_UPDATE.sh preprocess.sh 2>/dev/null || true
./postbuild.sh "$(command -v arm-none-eabi-gcc)"

echo ""
grep -E '^boot=|^slot0=|^slot1=' TFM_UPDATE.sh || true
echo ""
echo "=== 编译完成 ==="
echo "烧录: cd ${TFM_ROOT}/build_s/api_ns && ./regression.sh"
echo "      STM32_Programmer_CLI -c port=SWD mode=HotPlug -ob BOOT_UBE=0xB4"
echo "      ./TFM_UPDATE.sh"

