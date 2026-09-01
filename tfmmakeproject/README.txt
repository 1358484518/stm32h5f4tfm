STM32H5F4 非安全侧 makefile 工程。

在本目录执行 make，生成 out/tfm_ns_signed.bin。
签名走 sign_kit/（与 CubeIDE 工程的 sign_kit 同类，槽位按 H5F4）。
第一次会建 sign_kit/.venv 或复用本目录 .sign-venv，不要用仓库根目录 TF-M 的 .venv。
若根目录 .venv 里 cryptography 版本对不上，imgtool 会报
“Loaded python version: 50.0.0, shared object version: b'50.0.1'”。
只签已有的未签名 bin：
  ./sign_kit/sign.sh out/tfm_ns.bin
  sign_kit\sign.bat out\tfm_ns.bin
MCU：STM32H5F4xx，BL2_TRAILER_SIZE=0x3000。
NS 槽 1200 KB @ 0x0C090000；S 槽 352 KB @ 0x0C038000。
USART1 PA9/PA10，115200。

s_veneers.o 必须和板上的 SPE 一起重新导出（trusted-firmware-m/build_s/api_ns/interface/lib）。
换过 SPE 后请拷新的 s_veneers.o、api_ns/image_signing/layout_files/signing_layout_*.o，
以及 sign_kit/layout/signing_layout_*.o。

烧录不要用本工程 api_ns 里的 TFM_UPDATE.sh / regression.sh。
把签好的 bin 放到 windows-tfm-tools 后双击 tfm_update.bat，或 Linux 用仓库根目录 ./flash_stm32h5f4.sh。
