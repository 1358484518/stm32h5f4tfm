#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-3-Clause
#
# 从仓库根目录 keys/ 覆盖各工程里的 MCUboot 签名公私钥。
# 固定文件名（两对）：
#   image_s_signing_private_key.pem / image_s_signing_public_key.pem
#   image_ns_signing_private_key.pem / image_ns_signing_public_key.pem
#
# 私钥还会同步到 BL2 默认路径 root-EC-P256.pem / root-EC-P256_1.pem（EC-P256）。
# 源文件缺失、或目标目录不存在：只告警，返回 0，不中断编译。
#
set -u

WORK_ROOT="${1:-.}"
SIG_TYPE="${2:-EC-P256}"
KEYS_DIR="${WORK_ROOT}/keys"

PRIV_S="image_s_signing_private_key.pem"
PUB_S="image_s_signing_public_key.pem"
PRIV_NS="image_ns_signing_private_key.pem"
PUB_NS="image_ns_signing_public_key.pem"

if [[ ! -d "${KEYS_DIR}" ]]; then
    echo ">>> keys/: 目录不存在，跳过用户密钥同步（使用仓库默认密钥）"
    exit 0
fi

# 收集仓库内已有的同名目标（排除 venv / 构建树 / git）
find_named() {
    local name="$1"
    find "${WORK_ROOT}" \
        \( -path '*/.git/*' -o -path '*/.venv/*' -o -path '*/venv/*' \
           -o -path '*/build_s/*' -o -path '*/build_ns/*' \
           -o -path '*/build-spe/*' -o -path '*/mcuboot-src/*' \
           -o -path '*/__pycache__/*' \) -prune -o \
        -type f -name "${name}" -print 2>/dev/null
}

copy_one() {
    local src="$1"
    local dst="$2"
    local parent
    parent="$(dirname "${dst}")"
    if [[ ! -d "${parent}" ]]; then
        echo "    警告: 目标目录不存在，跳过 ${dst}"
        return 0
    fi
    if cp -f "${src}" "${dst}"; then
        echo "    覆盖 ${dst#"${WORK_ROOT}"/}"
    else
        echo "    警告: 无法写入 ${dst}"
    fi
}

sync_file() {
    local fname="$1"
    local src="${KEYS_DIR}/${fname}"
    local dst
    local n=0

    if [[ ! -f "${src}" ]]; then
        echo "    警告: keys/${fname} 未放置，跳过该类密钥同步"
        return 0
    fi

    while IFS= read -r dst; do
        [[ -z "${dst}" ]] && continue
        # 不要把 keys/ 自己盖一遍（无害但吵）
        [[ "${dst}" == "${src}" ]] && continue
        copy_one "${src}" "${dst}"
        n=$((n + 1))
    done < <(find_named "${fname}")

    if [[ "${n}" -eq 0 ]]; then
        echo "    警告: 未找到任何名为 ${fname} 的目标文件可覆盖"
    fi
}

# BL2 默认私钥路径（与 SIG 对应）
sync_bl2_aliases() {
    local src_s="${KEYS_DIR}/${PRIV_S}"
    local src_ns="${KEYS_DIR}/${PRIV_NS}"
    local bl2_dir="${WORK_ROOT}/trusted-firmware-m/bl2/ext/mcuboot"
    local dst_s dst_ns

    case "${SIG_TYPE}" in
        EC-P256)
            dst_s="${bl2_dir}/root-EC-P256.pem"
            dst_ns="${bl2_dir}/root-EC-P256_1.pem"
            ;;
        EC-P384)
            dst_s="${bl2_dir}/root-EC-P384.pem"
            dst_ns="${bl2_dir}/root-EC-P384_1.pem"
            ;;
        RSA-2048)
            dst_s="${bl2_dir}/root-RSA-2048.pem"
            dst_ns="${bl2_dir}/root-RSA-2048_1.pem"
            ;;
        RSA-3072)
            dst_s="${bl2_dir}/root-RSA-3072.pem"
            dst_ns="${bl2_dir}/root-RSA-3072_1.pem"
            ;;
        *)
            echo "    警告: 未知 SIG=${SIG_TYPE}，跳过 BL2 root-*.pem 同步"
            return 0
            ;;
    esac

    if [[ -f "${src_s}" ]]; then
        copy_one "${src_s}" "${dst_s}"
    else
        echo "    警告: keys/${PRIV_S} 未放置，跳过 ${dst_s#"${WORK_ROOT}"/}"
    fi
    if [[ -f "${src_ns}" ]]; then
        copy_one "${src_ns}" "${dst_ns}"
    else
        echo "    警告: keys/${PRIV_NS} 未放置，跳过 ${dst_ns#"${WORK_ROOT}"/}"
    fi
}

echo ">>> 用户密钥同步  keys/ → 各工程（缺失只告警）"
echo "    源目录: ${KEYS_DIR}"

any=0
for f in "${PRIV_S}" "${PUB_S}" "${PRIV_NS}" "${PUB_NS}"; do
    if [[ -f "${KEYS_DIR}/${f}" ]]; then
        any=1
        break
    fi
done
if [[ "${any}" -eq 0 ]]; then
    echo "    keys/ 中尚未放置上述四个 pem，使用仓库默认密钥"
    exit 0
fi

sync_file "${PRIV_S}"
sync_file "${PUB_S}"
sync_file "${PRIV_NS}"
sync_file "${PUB_NS}"
sync_bl2_aliases

echo ">>> 用户密钥同步完成"
exit 0
