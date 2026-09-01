# Trusted Firmware-M 项目

基于 STM32H5F4 的 TF-M（Trusted Firmware-M）移植与开发项目（由 STM32H573 平台最小改动移植）。

当前开发分支：`stm32h5f4`。平台名：`stm/stm32h5f4`。

## 编译与烧录

SPE / BL2 / 官方 NS 测试固件只使用仓库根目录的 `./buildtfm.sh` 编译。烧录用 Linux 的 `./flash_stm32h5f4.sh`，或 Windows 的 `windows-tfm-tools\tfm_update.bat`。  
`tfmcubeideproject/` 是 STM32H5F4 非安全侧 CubeIDE 工程（签完的 `tfm_ns_signed.bin` 可用上述脚本烧）。**不要**用 `tfmmakeproject/` 里的旧 H573 hex，也不要用 CubeIDE 工程里的 `TFM_UPDATE.sh` / `regression.sh` 烧片。

### 依赖

- Ubuntu：`cmake`、`ninja-build`、`python3-venv`、`python3-pip`
- ARM GNU 工具链（`arm-none-eabi-gcc`）在 `PATH` 里
- 烧录：`STM32_Programmer_CLI`（STM32CubeProgrammer）
- Windows 烧录：把镜像放到 `windows-tfm-tools` 后双击 `tfm_update.bat`。只有 hex、没有 bin 时才需要 Python 3（hex→bin）。已经是 bin 可以不装 Python。
- 串口：USART1 PA9/PA10，**115200**

脚本会在仓库根目录自动创建 `.venv`。如果签名步骤报 `mcuboot_imagesign_wrapper: not found`，删掉 `.venv` 再编一次。

### 编译

在仓库根目录：

```bash
git checkout stm32h5f4
git pull origin stm32h5f4

# 测试版：TEST_S + TEST_NS，INFO 日志（硬件回归用这个）
./buildtfm.sh test

# 正式版：SPE 不带 S 测试分区，NS 测试程序仍可烧可跑，ERROR 日志
# ./buildtfm.sh prod
```

成功结尾应有 `=== 编译完成（测试版，硬件浮点 ON）===`，并且检查：

- `bl2.bin` 含 `H5F4BL2`、`H5F4SWP2`
- `TFM_UPDATE.sh`：`boot=0xc00e000` `slot0=0xc038000` `slot1=0xc090000` `slot2=0xc200000` `slot3=0xc258000`

产物目录：`trusted-firmware-m/build_s/api_ns`（BL2 / S / 更新脚本）和 `trusted-firmware-m/build_ns/bin`（NS 测试镜像）。

### 烧录

板子接好 ST-Link 后，仍在仓库根目录：

```bash
./flash_stm32h5f4.sh
```

片上若还有旧 BL2 的 HDP（盖住 `0x0C00E000`），脚本会整片擦除再烧。需要强制擦除：

```bash
./flash_stm32h5f4.sh erase
```

烧完复位，串口第一行必须有 **`H5F4BL2`**（测试版常见 `[INF] H5F4BL2`）。  
如果仍是 `Starting bootloader` 且没有 `H5F4BL2`，说明 BL2 没写进去，不要继续用旧工程脚本补烧。

开发镜像用 dummy RSA-3072 密钥，启动日志里的 `NOT SECURE` 是预期现象。

### Windows 烧录

`windows-tfm-tools` 只保留 ST-Link 脚本。详细步骤见 `windows-tfm-tools/本目录工具使用说明.txt`。

1. `git checkout stm32h5f4` 后 `git pull origin stm32h5f4`。双击后窗口 rev 应为 `h5f4-20260901e`（或更新）。
2. Ubuntu/WSL 编好：`./buildtfm.sh prod` 或 `./buildtfm.sh test`。
3. 安装 STM32CubeProgrammer。只有 hex 没有 bin 时才需要 Python 3。
4. 把镜像放到 `windows-tfm-tools`（二选一）：
   - **优先**：三个文件直接放在该目录  
     `bl2.bin`、`tfm_s_signed.bin`、`tfm_ns_signed.bin`（也可用同名 `.hex`）
   - **其次**：把整份 `trusted-firmware-m/build_s` 和 `build_ns` 拷成  
     `windows-tfm-tools\build_s`、`windows-tfm-tools\build_ns`
5. 双击 `tfm_update.bat`：擦除 → 烧 option bytes → 找镜像 → 下载到  
   BL2 `0x0C00E000`、S `0x0C038000`、NS `0x0C090000`。  
   只重烧镜像：`tfm_update.bat images-only`。只擦：`erase_flash.bat`。

当前目录里的 bin/hex 永远压过 `build_s` / `build_ns` 里的同名文件。J-Link 脚本已删除。

### SRAM（当前 `stm32h5f4`）

| 块 | 谁用 | 地址 | 大小 |
|----|------|------|------|
| SRAM1 | NS | `0x20000000` | 256 KB |
| SRAM2 | S / BL2 | `0x30040000` | 127 KB + 1 KB 共享 |
| SRAM3+4+5 | NS（链接脚本 `RAM2`） | `0x20060000` | 1152 KB |

NS 大缓冲可放到 `.ram2` / `.bss.ram2`，或使用 `__ns_ram2_start__` / `__ns_ram2_end__`。

## 文档

- [TF-M 编译笔记](./tfmwork/tfm编译笔记.txt) — 环境搭建与踩坑记录（烧录请以上面脚本为准）
- 编译不通过时可以删除 `.venv` 后重新执行 `./buildtfm.sh`

## 硬件平台

- 主控：STM32H5F4（Cortex-M33 + TrustZone，4 MB Flash / 1536 KB SRAM）
- 调试器：ST-Link
- 平台名：`stm/stm32h5f4`（`./buildtfm.sh` 已指向该平台）
- 控制台：USART1 PA9/PA10，115200

## 代码提交 

- 执行命令: ./push_to_gitee.sh [提交说明]

- 增加非安全测试代码 nsdev.tar.xz ，在 ubuntu22.04 解压后执行make即可运行，这个工程不含硬件浮点计算。

- 增加 sign_kit.tar.xz 签名工具，只是用来对未加密固件进行签名使用。

- 增加 tfm-h573-flash签名固件下载固件快捷脚本.zip 签名回归烧录工具，里面有使用说明文档，用来签名未签名的固件和下载程序到flash。

- 增加 makefile 编译的非安全侧工程 tfmmakeproject ，可以使用make编译生成代码，正式版本关闭非安全侧测试，开启硬件浮点，使用内部晶振 PLL 240 MHZ

- 增加 tfmcubeideproject 非安全侧 CubeIDE 工程（已改为 STM32H5F4）。打开 `tfmcubeideproject/STM32CubeIDE` 下的 `tfmminiproject`。已带 mbedtls 4.1.1（TLS/X.509 辅助，PSA crypto 仍走 SPE）。`s_veneers.o` 与 `signing_layout_*.o` 已纳入仓库。签完的 NS 镜像用 `windows-tfm-tools` 或 `./flash_stm32h5f4.sh` 烧，不要跑工程里的 `TFM_UPDATE.sh`。

- 增加 windows-tfm-tools：Windows 上给 STM32H5F4 用的 ST-Link 烧录脚本（`tfm_update.bat`）。把 bin/hex 或 `build_s`/`build_ns` 放到该目录。不要用旧 H573 hex。

## 文件统计

3956 directories, 12622 files

