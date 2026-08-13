#!/usr/bin/env bash
# STM32H573I-DK  TF-M tests_reg 一键编译（纯离线，不下载依赖）
#
# 目录布局:
#   work/
#   ├── buildtfm.sh
#   ├── trusted-firmware-m/
#   └── tf-m-tests/
#
# 前提: 依赖已提交在 trusted-firmware-m/build_s/build-spe/lib/ext/*-src
# 用法: ./buildtfm.sh
#       ./buildtfm.sh --clean

set -euo pipefail

FORCE_CLEAN=0
[[ "${1:-}" == "--clean" ]] && FORCE_CLEAN=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/trusted-firmware-m/CMakeLists.txt" ]]; then
  WORK_ROOT="${SCRIPT_DIR}"
  TFM_ROOT="${WORK_ROOT}/trusted-firmware-m"
elif [[ -f "${SCRIPT_DIR}/CMakeLists.txt" ]]; then
  TFM_ROOT="${SCRIPT_DIR}"
  WORK_ROOT="$(cd "${TFM_ROOT}/.." && pwd)"
else
  echo "错误: 找不到 trusted-firmware-m"
  exit 1
fi

find_tfm_tests() {
  local c
  for c in \
    "${WORK_ROOT}/tf-m-tests" \
    "${TFM_ROOT}/tf-m-tests" \
    "${TFM_ROOT}/../tf-m-tests" \
    "${TFM_TESTS:-}"; do
    [[ -z "${c}" ]] && continue
    [[ -f "${c}/tests_reg/spe/CMakeLists.txt" ]] || continue
    echo "$(cd "${c}" && pwd)"
    return 0
  done
  return 1
}

if ! TFM_TESTS="$(find_tfm_tests)"; then
  echo "错误: 找不到 tf-m-tests"
  exit 1
fi

if [[ ! -f "${TFM_ROOT}/pyproject.toml" ]]; then
  echo "错误: ${TFM_ROOT} 缺少 pyproject.toml"
  exit 1
fi

cd "${TFM_ROOT}"
echo ">>> WORK_ROOT: ${WORK_ROOT}"
echo ">>> TFM_ROOT:  ${TFM_ROOT}"
echo ">>> TFM_TESTS: ${TFM_TESTS}"

LIB_EXT_S="${TFM_ROOT}/build_s/build-spe/lib/ext"
LIB_EXT_NS="${TFM_ROOT}/build_ns/lib/ext"

spe_deps_complete() {
  local ext="${1}"
  local lib f
  for lib in qcbor mcuboot cmsis t_cose tf-psa-crypto tf-m-extras; do
    [[ -d "${ext}/${lib}-src" ]] || return 1
  done
  for f in \
    "${ext}/qcbor-src/src/qcbor_encode.c" \
    "${ext}/mcuboot-src/boot/bootutil/src/bootutil_misc.c" \
    "${ext}/tf-psa-crypto-src/CMakeLists.txt"; do
    [[ -f "${f}" ]] || return 1
  done
  return 0
}

check_offline_deps() {
  if ! spe_deps_complete "${LIB_EXT_S}"; then
    echo ""
    echo "错误: build_s/build-spe/lib/ext 依赖不完整，无法离线编译。"
    echo "请在源机器先 ./buildtfm.sh，再 ./push_to_gitee.sh 推送。"
    exit 1
  fi
}

check_offline_deps

source .venv/bin/activate 2>/dev/null || {
  python3 -m venv .venv
  source .venv/bin/activate
  pip install --upgrade pip setuptools wheel
  pip install -e .
}

clean_cmake_cache() {
  echo ">>> 清理 CMake/Ninja 缓存（保留 lib/ext）"
  local ext_backup="" ns_ext_backup=""
  if [[ -d "${LIB_EXT_S}" ]]; then
    ext_backup="$(mktemp -d)"
    cp -a "${LIB_EXT_S}" "${ext_backup}/"
  fi
  if [[ -d "${LIB_EXT_NS}" ]]; then
    ns_ext_backup="$(mktemp -d)"
    cp -a "${LIB_EXT_NS}" "${ns_ext_backup}/"
  fi
  rm -rf build_s build_ns
  if [[ -n "${ext_backup}" ]]; then
    mkdir -p build_s/build-spe/lib
    cp -a "${ext_backup}/ext" "${LIB_EXT_S}"
    rm -rf "${ext_backup}"
  fi
  if [[ -n "${ns_ext_backup}" ]]; then
    mkdir -p build_ns/lib
    cp -a "${ns_ext_backup}/ext" "${LIB_EXT_NS}"
    rm -rf "${ns_ext_backup}"
  fi
}

need_reconfigure() {
  [[ "${FORCE_CLEAN}" -eq 1 ]] && return 0
  [[ ! -f build_s/CMakeCache.txt ]] && return 0
  local cached_root cached_spe
  cached_root="$(grep -m1 '^CONFIG_TFM_SOURCE_PATH:UNINITIALIZED=' build_s/CMakeCache.txt 2>/dev/null | cut -d= -f2- || true)"
  cached_spe="$(grep -m1 '^CMAKE_HOME_DIRECTORY:INTERNAL=' build_s/CMakeCache.txt 2>/dev/null | cut -d= -f2- || true)"
  [[ -n "${cached_root}" && "${cached_root}" != "${TFM_ROOT}" ]] && return 0
  [[ -n "${cached_spe}" && "${cached_spe}" != "${TFM_TESTS}/tests_reg/spe" ]] && return 0
  return 1
}

if need_reconfigure; then
  clean_cmake_cache
fi

CMAKE_COMMON=(
  -DTFM_PLATFORM=stm/stm32h573i_dk
  -DTFM_TOOLCHAIN_FILE="${TFM_ROOT}/toolchain_GNUARM.cmake"
  -DTFM_PSA_API=ON
  -DTFM_ISOLATION_LEVEL=1
  -DTEST_S=ON
  -DTEST_NS=ON
  -DTFM_BL2_LOG_LEVEL=LOG_LEVEL_INFO
  -DTFM_SPM_LOG_LEVEL=LOG_LEVEL_INFO
  -DTFM_PARTITION_LOG_LEVEL=LOG_LEVEL_INFO
  -DFETCHCONTENT_FULLY_DISCONNECTED=ON
)

echo ">>> Configure build_s (SPE) [离线]"
cmake -S "${TFM_TESTS}/tests_reg/spe" -B build_s -GNinja \
  -DCONFIG_TFM_SOURCE_PATH="${TFM_ROOT}" \
  "${CMAKE_COMMON[@]}"

echo ">>> Build & install build_s"
ninja -C build_s install -j"$(nproc)"

mkdir -p "${LIB_EXT_NS}"
for lib in qcbor t_cose; do
  if [[ ! -d "${LIB_EXT_NS}/${lib}-src" ]]; then
    echo ">>> 拷贝 ${lib}-src -> build_ns"
    cp -a "${LIB_EXT_S}/${lib}-src" "${LIB_EXT_NS}/"
  fi
done

echo ">>> Configure build_ns [离线]"
cmake -S "${TFM_TESTS}/tests_reg" -B build_ns -GNinja \
  -DCONFIG_SPE_PATH="${TFM_ROOT}/build_s/api_ns" \
  -DTFM_TOOLCHAIN_FILE="${TFM_ROOT}/build_s/api_ns/cmake/toolchain_ns_GNUARM.cmake" \
  -DFETCHCONTENT_FULLY_DISCONNECTED=ON

echo ">>> Build build_ns"
ninja -C build_ns -j"$(nproc)"

echo ">>> postbuild"
cd build_s/api_ns
chmod +x postbuild.sh regression.sh TFM_UPDATE.sh preprocess.sh 2>/dev/null || true
./postbuild.sh "$(which arm-none-eabi-gcc)"

echo ""
echo "=== TFM_UPDATE.sh 地址 ==="
grep -E '^boot=|^slot0=|^slot1=' TFM_UPDATE.sh || true

echo ""
echo "=== 编译完成 ==="
echo "烧录: cd ${TFM_ROOT}/build_s/api_ns && ./regression.sh"
echo "      STM32_Programmer_CLI -c port=SWD mode=HotPlug -ob BOOT_UBE=0xB4"
echo "      ./TFM_UPDATE.sh"

