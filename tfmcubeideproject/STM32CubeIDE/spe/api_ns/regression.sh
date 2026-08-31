#!/usr/bin/env bash
echo "ERROR: 不要用 CubeIDE 工程里的 regression.sh 烧 STM32H5F4。" >&2
echo "请用仓库根目录: ./flash_stm32h5f4.sh" >&2
echo "或 Windows: windows-tfm-tools\\tfm_update.bat / erase_flash.bat" >&2
exit 1
