#!/usr/bin/env bash
# STM32H573I-DK  TF-M tests_reg 一键编译
#
# 目录布局（buildtfm.sh 与 trusted-firmware-m、tf-m-tests 同级）:
#   work/
#   ├── buildtfm.sh
#   ├── trusted-firmware-m/
#   └── tf-m-tests/
#
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

source .venv/bin/activate 2>/dev/null || {
  python3 -m venv .venv
  source .venv/bin/activate
  pip install --upgrade pip setuptools wheel
  pip install -e .
}

LIB_EXT_S="${TFM_ROOT}/build_s/build-spe/lib/ext"
LIB_EXT_NS="${TFM_ROOT}/build_ns/lib/ext"
LIB_EXT_BACKUP_S=""
LIB_EXT_BACKUP_NS=""

backup_lib_ext() {
  if [[ -d "${LIB_EXT_S}" ]]; then
    LIB_EXT_BACKUP_S="$(mktemp -d)"
    echo ">>> 备份 build_s lib/ext"
    cp -a "${LIB_EXT_S}" "${LIB_EXT_BACKUP_S}/"
  fi
  if [[ -d "${LIB_EXT_NS}" ]]; then
    LIB_EXT_BACKUP_NS="$(mktemp -d)"
    echo ">>> 备份 build_ns lib/ext"
    cp -a "${LIB_EXT_NS}" "${LIB_EXT_BACKUP_NS}/"
  fi
}

restore_lib_ext() {
  if [[ -n "${LIB_EXT_BACKUP_S}" && -d "${LIB_EXT_BACKUP_S}/ext" ]]; then
    mkdir -p "${TFM_ROOT}/build_s/build-spe/lib"
    cp -a "${LIB_EXT_BACKUP_S}/ext" "${LIB_EXT_S}"
    rm -rf "${LIB_EXT_BACKUP_S}"
    LIB_EXT_BACKUP_S=""
  fi
  if [[ -n "${LIB_EXT_BACKUP_NS}" && -d "${LIB_EXT_BACKUP_NS}/ext" ]]; then
    mkdir -p "${TFM_ROOT}/build_ns/lib"
    cp -a "${LIB_EXT_BACKUP_NS}/ext" "${LIB_EXT_NS}"
    rm -rf "${LIB_EXT_BACKUP_NS}"
    LIB_EXT_BACKUP_NS=""
  fi
}

# build_ns 需要 qcbor-src / t_cose-src，从 build_s 拷贝避免重复下载
seed_ns_lib_ext() {
  local spe_ext="${LIB_EXT_S}"
  local ns_ext="${LIB_EXT_NS}"
  mkdir -p "${ns_ext}"
  for lib in qcbor t_cose; do
    if [[ -d "${spe_ext}/${lib}-src" && ! -d "${ns_ext}/${lib}-src" ]]; then
      echo ">>> 从 build_s 拷贝 ${lib}-src -> build_ns"
      cp -a "${spe_ext}/${lib}-src" "${ns_ext}/"
    fi
  done
}

need_reconfigure() {
  [[ "${FORCE_CLEAN}" -eq 1 ]] && return 0
  [[ ! -f build_s/CMakeCache.txt ]] && return 0

  local cached_root cached_spe
  cached_root="$(grep -m1 '^CONFIG_TFM_SOURCE_PATH:UNINITIALIZED=' build_s/CMakeCache.txt 2>/dev/null | cut -d= -f2- || true)"
  cached_spe="$(grep -m1 '^CMAKE_HOME_DIRECTORY:INTERNAL=' build_s/CMakeCache.txt 2>/dev/null | cut -d= -f2- || true)"

  if [[ -n "${cached_root}" && "${cached_root}" != "${TFM_ROOT}" ]]; then
    echo ">>> 检测到路径变更，将重新 configure"
    return 0
  fi
  if [[ -n "${cached_spe}" && "${cached_spe}" != "${TFM_TESTS}/tests_reg/spe" ]]; then
    echo ">>> 检测到 tf-m-tests 路径变更，将重新 configure"
    return 0
  fi
  return 1
}

clean_build_dirs() {
  backup_lib_ext
  echo ">>> 清理 build_s / build_ns（保留 lib/ext 备份）"
  rm -rf build_s build_ns
  restore_lib_ext
}

if need_reconfigure; then
  clean_build_dirs
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

echo ">>> Configure build_s (SPE)"
cmake -S "${TFM_TESTS}/tests_reg/spe" -B build_s -GNinja \
  -DCONFIG_TFM_SOURCE_PATH="${TFM_ROOT}" \
  "${CMAKE_COMMON[@]}"

echo ">>> Build & install build_s"
ninja -C build_s install -j"$(nproc)"

# NS 侧：先 seed qcbor/t_cose，再 configure
seed_ns_lib_ext

NS_CMAKE_EXTRA=()
if [[ -d "${LIB_EXT_NS}/qcbor-src" && -d "${LIB_EXT_NS}/t_cose-src" ]]; then
  NS_CMAKE_EXTRA=(-DFETCHCONTENT_FULLY_DISCONNECTED=ON)
fi

echo ">>> Configure build_ns"
cmake -S "${TFM_TESTS}/tests_reg" -B build_ns -GNinja \
  -DCONFIG_SPE_PATH="${TFM_ROOT}/build_s/api_ns" \
  -DTFM_TOOLCHAIN_FILE="${TFM_ROOT}/build_s/api_ns/cmake/toolchain_ns_GNUARM.cmake" \
  "${NS_CMAKE_EXTRA[@]}"

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
echo "烧录前（首次或换板子）:"
echo "  cd ${TFM_ROOT}/build_s/api_ns"
echo "  ./regression.sh"
echo "  STM32_Programmer_CLI -c port=SWD mode=HotPlug -ob BOOT_UBE=0xB4"
echo "  ./TFM_UPDATE.sh"
echo ""
echo "仅更新固件:"
echo "  cd ${TFM_ROOT}/build_s/api_ns && ./TFM_UPDATE.sh"

