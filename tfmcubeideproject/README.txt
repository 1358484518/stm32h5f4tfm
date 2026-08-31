STM32H5F4 非安全侧 STM32CubeIDE 工程。

在 STM32CubeIDE 里打开 STM32CubeIDE/ 下的 tfmminiproject（工程名不变）。
MCU：STM32H5F4ZJTx，宏 STM32H5F4xx，BL2_TRAILER_SIZE=0x3000。
板子选 genericBoard。若 CubeIDE 器件库还没有 H5F4，GCC 仍可按现有工程编译。

编译生成 Debug/tfm_ns.bin（或 make 的 build/tfm_ns.bin），post-build 会调用 sign_kit 签出 tfm_ns_signed.bin。
Linux 命令行：在 STM32CubeIDE/ 下执行 make，再 ./sign_kit/sign.sh build/tfm_ns.bin。

烧录不要用本工程 spe/api_ns 里的脚本。把签好的 bin 放到 windows-tfm-tools 后双击 tfm_update.bat，或 Linux 用仓库根目录 ./flash_stm32h5f4.sh。

s_veneers.o 必须和板上的 SPE 一起重新导出（trusted-firmware-m/build_s/api_ns/interface/lib）。换过 SPE 后请拷新的 s_veneers.o 和 sign_kit/layout/signing_layout_*.o。

NS 槽 1200 KB @ 0x0C090000；S 槽 352 KB @ 0x0C038000。USART1 PA9/PA10，115200。

工程已带 mbedtls 4.1.1（ns_app/mbedtls-4.1.1）：编 TLS/X.509 辅助模块，不编第二套 PSA crypto core。
密码仍走 SPE 的 PSA（s_veneers.o）。配置见 ns_app/ns_crypto_user.h、ns_mbedtls_user.h。
不要把 net_sockets.c、ssl_*_server.c、builtin aes/ecp 等排除文件加回源文件列表，除非同步改配置。
core/ 只编 psa_util.c（ECDSA raw/DER），不要把 PSA crypto core 的其它 .c 加进来。

NS 侧是 TLS 1.3 客户端：mbedtls_ssl_set_bio() 接到 ns_mbedtls_bio.c（send/recv）。
没有 POSIX mbedtls_net_*；有真实 TCP 时替换这两个回调即可。
动态内存走 mbedtls 自带的 memory_buffer_alloc（MBEDTLS_MEMORY_BUFFER_ALLOC_C），
不经过 newlib malloc/_sbrk。ssl_setup 前调用 mbedtls_memory_buffer_alloc_init()。

串口日志里搜 `TLS 1.3 + bio`。无对端时握手应停在 WANT_READ（ClientHello 已从 bio send 打出）。
