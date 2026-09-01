#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-3-Clause
#
# 从仓库根目录 versions/ 读取 S/NS 镜像版本（及 security counter），
# 写入各 sign_kit/config，并打印可供 buildtfm.sh 使用的 cmake -D 参数。
#
# 固定文件（任选其一格式）：
#   1) versions/config   KEY=VALUE 文本（推荐）
#   2) 或拆分文件：
#        versions/image_s_version.txt
#        versions/image_ns_version.txt
#        versions/image_s_security_counter.txt   （可选，默认 1）
#        versions/image_ns_security_counter.txt  （可选，默认 1）
#
# 源文件缺失：只告警，返回 0，使用仓库默认版本，不中断编译。
#
set -u

WORK_ROOT="${1:-.}"
VER_DIR="${WORK_ROOT}/versions"
OUT_ENV="${2:-}"   # 若给出路径，把 VERSION_CMAKE_ARGS 等写进该文件

VERSION_S=""
VERSION_NS=""
SEC_S=""
SEC_NS=""
MIN_NS=""
MIN_S=""

read_kv_file() {
    local f="$1"
    local line key val
    [[ -f "${f}" ]] || return 0
    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="${line%%#*}"
        line="$(echo "${line}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [[ -z "${line}" ]] && continue
        key="${line%%=*}"
        val="${line#*=}"
        key="$(echo "${key}" | sed 's/[[:space:]]*$//')"
        val="$(echo "${val}" | sed 's/^[[:space:]]*//')"
        case "${key}" in
            MCUBOOT_IMAGE_VERSION_S) VERSION_S="${val}" ;;
            MCUBOOT_IMAGE_VERSION_NS) VERSION_NS="${val}" ;;
            MCUBOOT_SECURITY_COUNTER_S) SEC_S="${val}" ;;
            MCUBOOT_SECURITY_COUNTER_NS) SEC_NS="${val}" ;;
            MCUBOOT_NS_IMAGE_MIN_VER) MIN_NS="${val}" ;;
            MCUBOOT_S_IMAGE_MIN_VER) MIN_S="${val}" ;;
        esac
    done < "${f}"
}

read_plain() {
    local f="$1"
    if [[ -f "${f}" ]]; then
        # 取首个非空非注释行
        sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "${f}" \
            | sed '/^$/d' | head -1
    fi
}

if [[ ! -d "${VER_DIR}" ]]; then
    echo ">>> versions/: 目录不存在，跳过用户版本同步（使用仓库默认版本）"
    exit 0
fi

echo ">>> 用户版本同步  versions/ → sign_kit + SPE cmake"
echo "    源目录: ${VER_DIR}"

read_kv_file "${VER_DIR}/config"
# 拆分文本可覆盖 config 同名字段
v="$(read_plain "${VER_DIR}/image_s_version.txt")"; [[ -n "${v}" ]] && VERSION_S="${v}"
v="$(read_plain "${VER_DIR}/image_ns_version.txt")"; [[ -n "${v}" ]] && VERSION_NS="${v}"
v="$(read_plain "${VER_DIR}/image_s_security_counter.txt")"; [[ -n "${v}" ]] && SEC_S="${v}"
v="$(read_plain "${VER_DIR}/image_ns_security_counter.txt")"; [[ -n "${v}" ]] && SEC_NS="${v}"

if [[ -z "${VERSION_S}" && -z "${VERSION_NS}" && -z "${SEC_S}" && -z "${SEC_NS}" ]]; then
    echo "    versions/ 中尚未填写版本，使用仓库默认"
    exit 0
fi

# 缺省补齐（只在用户至少写了一项时）
VERSION_S="${VERSION_S:-2.3.0}"
VERSION_NS="${VERSION_NS:-0.0.0}"
SEC_S="${SEC_S:-1}"
SEC_NS="${SEC_NS:-1}"
MIN_NS="${MIN_NS:-0.0.0+0}"
MIN_S="${MIN_S:-0.0.0+0}"

echo "    S  version=${VERSION_S}  security_counter=${SEC_S}"
echo "    NS version=${VERSION_NS}  security_counter=${SEC_NS}"

set_kv_in_config() {
    local cfg="$1"
    local key="$2"
    local val="$3"
    if [[ ! -f "${cfg}" ]]; then
        echo "    警告: 目标不存在，跳过 ${cfg}"
        return 0
    fi
    if grep -q "^[[:space:]]*${key}=" "${cfg}"; then
        sed -i "s|^[[:space:]]*${key}=.*|${key}=${val}|" "${cfg}"
    else
        echo "${key}=${val}" >> "${cfg}"
    fi
    echo "    更新 ${cfg#"${WORK_ROOT}"/}: ${key}=${val}"
}

# 覆盖仓库内所有 sign_kit/config（排除 build 树 / venv）
while IFS= read -r cfg; do
    [[ -z "${cfg}" ]] && continue
    set_kv_in_config "${cfg}" MCUBOOT_IMAGE_VERSION_S "${VERSION_S}"
    set_kv_in_config "${cfg}" MCUBOOT_SECURITY_COUNTER_S "${SEC_S}"
    set_kv_in_config "${cfg}" MCUBOOT_IMAGE_VERSION_NS "${VERSION_NS}"
    set_kv_in_config "${cfg}" MCUBOOT_SECURITY_COUNTER_NS "${SEC_NS}"
    set_kv_in_config "${cfg}" MCUBOOT_NS_IMAGE_MIN_VER "${MIN_NS}"
    set_kv_in_config "${cfg}" MCUBOOT_S_IMAGE_MIN_VER "${MIN_S}"
done < <(find "${WORK_ROOT}" \
    \( -path '*/.git/*' -o -path '*/.venv/*' -o -path '*/venv/*' \
       -o -path '*/build_s/*' -o -path '*/build_ns/*' \
       -o -path '*/build-spe/*' -o -path '*/__pycache__/*' \
       -o -path '*/all-branch-build/*' \) -prune -o \
    -type f -path '*/sign_kit/config' -print 2>/dev/null)

# 供 buildtfm 引用的 cmake 参数（空格分隔，由调用方读入数组）
CMAKE_ARGS=(
    "-DMCUBOOT_IMAGE_VERSION_S=${VERSION_S}"
    "-DMCUBOOT_IMAGE_VERSION_NS=${VERSION_NS}"
    "-DMCUBOOT_SECURITY_COUNTER_S=${SEC_S}"
    "-DMCUBOOT_SECURITY_COUNTER_NS=${SEC_NS}"
)

if [[ -n "${OUT_ENV}" ]]; then
    {
        echo "VERSION_S='${VERSION_S}'"
        echo "VERSION_NS='${VERSION_NS}'"
        echo "SEC_S='${SEC_S}'"
        echo "SEC_NS='${SEC_NS}'"
        printf "VERSION_CMAKE_ARGS=("
        for a in "${CMAKE_ARGS[@]}"; do
            printf " %q" "${a}"
        done
        echo " )"
    } > "${OUT_ENV}"
fi

# 也写一份给当前 shell 通过 stdout 标记（buildtfm 主要用 OUT_ENV）
echo ">>> 用户版本同步完成"
exit 0
