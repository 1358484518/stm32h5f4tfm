#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-3-Clause
#
# Helper: generate secrets then attempt STM32_Programmer_CLI write.
# OTP programming is irreversible — confirm SN / scrap silicon first.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-}"
SN_HINT="${2:-}"

if [[ -z "${OUT_DIR}" ]]; then
  echo "用法: $0 <out-dir> [serial-hint]"
  echo "例:   $0 factory/sn-001 SN001"
  exit 1
fi

PYTHON="${ROOT}/.venv/bin/python"
if [[ ! -x "${PYTHON}" ]]; then
  PYTHON="python3"
fi

"${PYTHON}" -m pip -q install cryptography >/dev/null 2>&1 || true
"${PYTHON}" "${ROOT}/scripts/gen_stm_chip_otp_secrets.py" --out-dir "${OUT_DIR}" --allow-overwrite

HEX="${OUT_DIR}/chip_otp_secrets.hex"
echo
echo "已生成: ${HEX}"
echo "下一步（工厂）:"
echo "  1) 确认目标板序列号 ${SN_HINT:-<unknown>}"
echo "  2) STM32_Programmer_CLI -c port=SWD mode=UR -w ${HEX}"
echo "  3) 在 Option Bytes 中锁定已写入的 OTP block"
echo "  4) 烧录本生产分支的 BL2 + S + NS"
echo
if command -v STM32_Programmer_CLI >/dev/null 2>&1; then
  read -r -p "检测到 STM32_Programmer_CLI，是否立即写入 OTP？输入 YES 继续: " ans
  if [[ "${ans}" == "YES" ]]; then
    STM32_Programmer_CLI -c port=SWD mode=UR -w "${HEX}"
  else
    echo "已跳过实际烧录。"
  fi
else
  echo "未找到 STM32_Programmer_CLI，请手工用 CubeProgrammer 写入。"
fi
