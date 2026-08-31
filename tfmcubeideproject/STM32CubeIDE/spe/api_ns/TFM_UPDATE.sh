#!/usr/bin/env bash
echo "ERROR: 不要用 CubeIDE 工程里的 TFM_UPDATE.sh 烧 STM32H5F4。" >&2
echo "NS 编出来后把 tfm_ns_signed.bin 放到 windows-tfm-tools，再跑 tfm_update.bat。" >&2
echo "Linux: ./flash_stm32h5f4.sh" >&2
exit 1
