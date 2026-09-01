#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-3-Clause
#
# 清除 TF-M 编译结果，但保留 FetchContent 已下载的依赖源码（*-src）。
# 依赖缓存目录：trusted-firmware-m/.deps-cache/{spe,ns}/
#
# 用法:
#   ./scripts/clean_tfm_build.sh              # 缓存依赖 → 删 build_s/build_ns → 还原 *-src
#   ./scripts/clean_tfm_build.sh --save-only  # 仅把现有 *-src 写入缓存（编译成功后用）
#   ./scripts/clean_tfm_build.sh --restore-only  # 仅从缓存还原到 build 树（不删编译产物）
#   ./scripts/clean_tfm_build.sh /path/to/trusted-firmware-m
#
# 返回 0；缓存为空时只清编译目录并提示，不失败。
#
set -euo pipefail

MODE="clean"
TFM_ROOT=""

for arg in "$@"; do
    case "${arg}" in
        --save-only) MODE="save" ;;
        --restore-only) MODE="restore" ;;
        --clean) MODE="clean" ;;
        -h|--help)
            sed -n '2,16p' "$0"
            exit 0
            ;;
        *)
            if [[ -z "${TFM_ROOT}" && -d "${arg}" ]]; then
                TFM_ROOT="${arg}"
            else
                echo "未知参数: ${arg}" >&2
                exit 2
            fi
            ;;
    esac
done

if [[ -z "${TFM_ROOT}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TFM_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)/trusted-firmware-m"
fi

LIB_EXT_S="${TFM_ROOT}/build_s/build-spe/lib/ext"
LIB_EXT_NS="${TFM_ROOT}/build_ns/lib/ext"
CACHE_ROOT="${TFM_ROOT}/.deps-cache"
CACHE_S="${CACHE_ROOT}/spe"
CACHE_NS="${CACHE_ROOT}/ns"

SPE_LIBS=(qcbor mcuboot cmsis t_cose tf-psa-crypto tf-m-extras)
NS_LIBS=(qcbor t_cose cmsis)

# 不拷贝巨大的 .git，加快缓存；源码本身足够离线编译
RSYNC_OPTS=(-a --delete --exclude '.git/')

have_rsync=0
command -v rsync >/dev/null 2>&1 && have_rsync=1

copy_tree() {
    local src="$1"
    local dst="$2"
    mkdir -p "$(dirname "${dst}")"
    if [[ "${have_rsync}" -eq 1 ]]; then
        rsync "${RSYNC_OPTS[@]}" "${src%/}/" "${dst%/}/"
    else
        rm -rf "${dst}"
        mkdir -p "${dst}"
        cp -a "${src%/}/." "${dst%/}/"
    fi
}

save_libs() {
    local from_dir="$1"
    local to_dir="$2"
    shift 2
    local libs=("$@")
    local name src
    local n=0
    mkdir -p "${to_dir}"
    for name in "${libs[@]}"; do
        src="${from_dir}/${name}-src"
        if [[ -d "${src}" ]]; then
            echo "    缓存 ${name}-src  ← ${src#"${TFM_ROOT}"/}"
            copy_tree "${src}" "${to_dir}/${name}-src"
            n=$((n + 1))
        fi
    done
    echo "    已缓存 ${n} 个依赖目录 → ${to_dir#"${TFM_ROOT}"/}"
}

restore_libs() {
    local from_dir="$1"
    local to_dir="$2"
    shift 2
    local libs=("$@")
    local name src dst
    local n=0
    mkdir -p "${to_dir}"
    for name in "${libs[@]}"; do
        src="${from_dir}/${name}-src"
        dst="${to_dir}/${name}-src"
        if [[ -d "${src}" ]]; then
            echo "    还原 ${name}-src  → ${dst#"${TFM_ROOT}"/}"
            copy_tree "${src}" "${dst}"
            n=$((n + 1))
        fi
    done
    if [[ "${n}" -eq 0 ]]; then
        echo "    警告: ${from_dir#"${TFM_ROOT}"/} 中无可用 *-src 缓存（首次需联网下载）"
    else
        echo "    已还原 ${n} 个依赖目录"
    fi
}

save_all() {
    echo ">>> 保存 FetchContent 依赖到 .deps-cache（不清编译产物）"
    if [[ -d "${LIB_EXT_S}" ]]; then
        save_libs "${LIB_EXT_S}" "${CACHE_S}" "${SPE_LIBS[@]}"
    else
        echo "    SPE lib/ext 尚不存在，跳过"
    fi
    if [[ -d "${LIB_EXT_NS}" ]]; then
        save_libs "${LIB_EXT_NS}" "${CACHE_NS}" "${NS_LIBS[@]}"
    else
        # NS 可与 SPE 共用 qcbor/t_cose
        if [[ -d "${CACHE_S}" ]]; then
            mkdir -p "${CACHE_NS}"
            for name in qcbor t_cose; do
                if [[ -d "${CACHE_S}/${name}-src" && ! -d "${CACHE_NS}/${name}-src" ]]; then
                    copy_tree "${CACHE_S}/${name}-src" "${CACHE_NS}/${name}-src"
                fi
            done
        fi
        echo "    NS lib/ext 尚不存在（已尽量从 SPE 缓存补齐）"
    fi
}

restore_all() {
    echo ">>> 从 .deps-cache 还原依赖源码（供离线编译）"
    restore_libs "${CACHE_S}" "${LIB_EXT_S}" "${SPE_LIBS[@]}"
    restore_libs "${CACHE_NS}" "${LIB_EXT_NS}" "${NS_LIBS[@]}"
    # NS 缺的从 SPE 缓存补
    mkdir -p "${LIB_EXT_NS}"
    for name in qcbor t_cose; do
        if [[ ! -d "${LIB_EXT_NS}/${name}-src" && -d "${CACHE_S}/${name}-src" ]]; then
            echo "    补齐 NS ${name}-src ← spe 缓存"
            copy_tree "${CACHE_S}/${name}-src" "${LIB_EXT_NS}/${name}-src"
        elif [[ ! -d "${LIB_EXT_NS}/${name}-src" && -d "${LIB_EXT_S}/${name}-src" ]]; then
            echo "    补齐 NS ${name}-src ← SPE lib/ext"
            copy_tree "${LIB_EXT_S}/${name}-src" "${LIB_EXT_NS}/${name}-src"
        fi
    done
}

wipe_builds() {
    echo ">>> 清除编译结果（保留 .deps-cache）"
    if [[ -d "${TFM_ROOT}/build_s" ]]; then
        # 先尽量把现有依赖写入缓存，避免误删未缓存的源码
        if [[ -d "${LIB_EXT_S}" ]]; then
            save_libs "${LIB_EXT_S}" "${CACHE_S}" "${SPE_LIBS[@]}"
        fi
        rm -rf "${TFM_ROOT}/build_s"
        echo "    已删除 build_s"
    else
        echo "    build_s 不存在"
    fi
    if [[ -d "${TFM_ROOT}/build_ns" ]]; then
        if [[ -d "${LIB_EXT_NS}" ]]; then
            save_libs "${LIB_EXT_NS}" "${CACHE_NS}" "${NS_LIBS[@]}"
        fi
        rm -rf "${TFM_ROOT}/build_ns"
        echo "    已删除 build_ns"
    else
        echo "    build_ns 不存在"
    fi
}

case "${MODE}" in
    save)
        save_all
        ;;
    restore)
        restore_all
        ;;
    clean)
        echo ">>> clean_tfm_build: 清编译产物，依赖走本地缓存（不重新下载）"
        echo "    TFM_ROOT=${TFM_ROOT}"
        wipe_builds
        restore_all
        echo ">>> clean_tfm_build 完成"
        ;;
esac

exit 0
