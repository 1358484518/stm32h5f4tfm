# Trusted Firmware-M 项目

基于 STM32H5F4 的 TF-M（Trusted Firmware-M）移植与开发项目（由 STM32H573 平台最小改动移植）。

当前开发分支：`stm32h5f4`。平台名：`stm/stm32h5f4`。



### versions/（S / NS 镜像版本）

编辑仓库根目录 `versions/config`（或拆分 txt），`./buildtfm.sh` 会在签名时写入对应版本与 security counter，并同步到各 `sign_kit/config`。说明见 `versions/README.md`。

### keys/ 与清编译（不重新下载依赖）

- 把两对固定文件名公私钥放入仓库根目录 `keys/`，`./buildtfm.sh` 会自动覆盖各工程同名密钥并同步 OTP ROTPK。见 `keys/README.md`。
- 不要手动 `rm -rf trusted-firmware-m/build_s`。脚本默认先跑 `scripts/clean_tfm_build.sh`：只清编译产物，依赖缓存在 `trusted-firmware-m/.deps-cache/`。增量可用 `./buildtfm.sh test --no-clean`。


## 编译与烧录

SPE / BL2 / 官方 NS 测试固件只使用仓库根目录的 `./buildtfm.sh` 编译。烧录用 Linux 的 `./flash_stm32h5f4.sh`，或 Windows 的 `windows-tfm-tools\tfm_update.bat`。  
`tfmcubeideproject/` 是 STM32H5F4 非安全侧 CubeIDE 工程。`tfmmakeproject/` 是同一套 SPE 上的 makefile NS 工程（`make` 生成 `out/tfm_ns_signed.bin`）。签完的镜像用上述脚本烧。这两个 NS 工程里已去掉 ST 的 `TFM_UPDATE.sh` / `regression.sh`。

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
- 槽位：BL2 `0xc00e000`，S `0xc038000`，NS `0xc090000`，S 升级 `0xc200000`，NS 升级 `0xc258000`

产物目录：`trusted-firmware-m/build_s/api_ns`（BL2 / S）和 `trusted-firmware-m/build_ns/bin`（NS 测试镜像）。
Linux 烧录 `./flash_stm32h5f4.sh` 会用 SPE 编出来的那份脚本；NS 工程（`tfmmakeproject` / CubeIDE）里不再带 `TFM_UPDATE.sh` / `regression.sh`。

### 签名（自己编的未加密 .bin）

`./buildtfm.sh` 编出来的 `tfm_s_signed.bin` / `tfm_ns_signed.bin` 已经签过。  
makefile / CubeIDE 自己编的未签名 `.bin` 必须先签再烧。工具按 H5F4 槽位（NS 1200 KB、S 352 KB）。仓库根目录旧的 `sign_kit.zip`（H573：NS `0x0C088000` / 576 KB）已删除。

| 工程 | 工具目录 | 签完写到哪 |
|------|----------|------------|
| makefile | `tfmmakeproject/sign_kit/` | 输入文件旁边（`make` → `out/tfm_ns_signed.bin`） |
| CubeIDE | `tfmcubeideproject/STM32CubeIDE/sign_kit/` | `sign_kit/` 目录（post-build 也是这里） |

Linux：

```bash
cd tfmmakeproject/sign_kit
./sign.sh ../out/tfm_ns.bin     # → ../out/tfm_ns_signed.bin
./sign.sh s ../sapp.bin         # 安全侧
```

Windows：

```bat
cd tfmmakeproject\sign_kit
sign.bat tfm_ns.bin
sign.bat sapp.bin
```

文件名带 `ns` 按非安全签；带 `sapp` / `tfm_s` 按安全签。看不出来时：`./sign.sh ns app.bin`。  
签完大小：NS **1200 KB** 烧 `0x0C090000`（升级槽 `0x0C258000`）；S **352 KB** 烧 `0x0C038000`（升级槽 `0x0C200000`）。  
第一次会建 `sign_kit/.venv`，或复用 `tfmmakeproject/.sign-venv`。不要用仓库根目录 TF-M 的 `.venv`（cryptography 对不上会报 `Loaded python version: 50.0.0, shared object version: b'50.0.1'`）。

详细用法：`tfmmakeproject/sign_kit/README.md`、`tfmcubeideproject/STM32CubeIDE/sign_kit/README.md`。

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

`./flash_stm32h5f4.sh` 只写当前运行槽（BL2 / S primary / NS primary）。**升级下载**请写 MCUBoot secondary：S `0x0C200000`（`slot2`）、NS `0x0C258000`（`slot3`）。不要用 H573 的 `0x0C118000` / `0x0C168000`。完整表见下面 Windows 一节。

### Windows 烧录

`windows-tfm-tools` 只保留 ST-Link 脚本。详细步骤见 `windows-tfm-tools/本目录工具使用说明.txt`。

1. `git checkout stm32h5f4` 后 `git pull origin stm32h5f4`。双击后窗口 rev 应为 `h5f4-20260901h`（或更新）。
2. Ubuntu/WSL 编好：`./buildtfm.sh prod` 或 `./buildtfm.sh test`。
3. 安装 STM32CubeProgrammer。只有 hex 没有 bin 时才需要 Python 3。
4. 把镜像放到 `windows-tfm-tools`（二选一）：
   - **优先**：三个文件直接放在该目录  
     `bl2.bin`、`tfm_s_signed.bin`、`tfm_ns_signed.bin`（也可用同名 `.hex`）
   - **其次**：把整份 `trusted-firmware-m/build_s` 和 `build_ns` 拷成  
     `windows-tfm-tools\build_s`、`windows-tfm-tools\build_ns`
5. 双击 `tfm_update.bat`：擦除 → 烧 option bytes → 找镜像 → 下载到 **当前运行槽**  
   BL2 `0x0C00E000`、S `0x0C038000`、NS `0x0C090000`。  
   只重烧镜像：`tfm_update.bat images-only`。只擦：`erase_flash.bat`。

**升级下载地址**（MCUBoot secondary，不要写到 primary）：

| 槽 | 槽名 | 安全别名 `0x0C` | 非安全 `0x08` | 大小 |
|----|-----------------|-----------------|---------------|------|
| BL2 | `boot=0xc00e000` | `0x0C00E000` | `0x0800E000` | 96 KB |
| S 当前运行 | `slot0=0xc038000` | `0x0C038000` | `0x08038000` | 352 KB |
| NS 当前运行 | `slot1=0xc090000` | `0x0C090000` | `0x08090000` | 1200 KB |
| **S 升级下载** | `slot2=0xc200000` | **`0x0C200000`** | `0x08200000` | 352 KB |
| **NS 升级下载** | `slot3=0xc258000` | **`0x0C258000`** | `0x08258000` | 1200 KB |

CubeProgrammer 示例：

```bat
STM32_Programmer_CLI -c port=SWD ap=1 mode=UR -d tfm_s_signed.bin  0x0C200000 -v
STM32_Programmer_CLI -c port=SWD ap=1 mode=UR -d tfm_ns_signed.bin 0x0C258000 -v
```

S 升级槽必须从 bank 2 开头（`0x0C200000`）。H573 的 `0x0C118000` / `0x0C168000` 禁止再用。

当前目录里的 bin/hex 永远压过 `build_s` / `build_ns` 里的同名文件。J-Link 脚本已删除。

### SRAM（当前 `stm32h5f4`）

| 块 | 谁用 | 地址 | 大小 |
|----|------|------|------|
| SRAM1 | NS | `0x20000000` | 256 KB |
| SRAM2 | S / BL2 | `0x30040000` | 127 KB + 1 KB 共享 |
| SRAM3+4+5 | NS（链接脚本 `RAM2`） | `0x20060000` | 1152 KB |

NS 大缓冲可放到 `.ram2` / `.bss.ram2`，或使用 `__ns_ram2_start__` / `__ns_ram2_end__`。

## 文档

- [TF-M 学习笔记（HTML）](./TF-M学习笔记/index.html) — 由 `TF-M学习笔记.docx` 导出，图片在同目录 `media/`。文末有 STM32H573 → STM32H5F4 移植过程与差异。浏览器打开即可，请整夹拷贝。
- [TF-M 编译笔记](./tfm编译笔记.txt) — 环境搭建与踩坑记录（烧录 / 签名请以本文和 `sign_kit` 为准）
- makefile 签名：[`tfmmakeproject/sign_kit/README.md`](./tfmmakeproject/sign_kit/README.md)
- CubeIDE 签名：[`tfmcubeideproject/STM32CubeIDE/sign_kit/README.md`](./tfmcubeideproject/STM32CubeIDE/sign_kit/README.md)
- Windows 烧录：[`windows-tfm-tools/本目录工具使用说明.txt`](./windows-tfm-tools/本目录工具使用说明.txt)
- 编译不通过时可以删除仓库根目录 `.venv` 后重新执行 `./buildtfm.sh`（NS 签名不要用这个 `.venv`）

## 硬件平台

- 主控：STM32H5F4（Cortex-M33 + TrustZone，4 MB Flash / 1536 KB SRAM）
- 调试器：ST-Link
- 平台名：`stm/stm32h5f4`（`./buildtfm.sh` 已指向该平台）
- 控制台：USART1 PA9/PA10，115200

## 代码提交 

- 执行命令: ./push_to_gitee.sh [提交说明]

- 增加非安全测试代码 nsdev.tar.xz ，在 ubuntu22.04 解压后执行make即可运行，这个工程不含硬件浮点计算。

- 增加 H5F4 `sign_kit` 签名工具：`tfmmakeproject/sign_kit` 与 `tfmcubeideproject/STM32CubeIDE/sign_kit`。只签未加密固件。NS 1200 KB @ `0x0C090000`，S 352 KB @ `0x0C038000`。Linux：`./sign.sh tfm_ns.bin`；Windows：`sign.bat tfm_ns.bin`。根目录旧的 `sign_kit.zip`（H573）已从 `stm32h5f4` 删除。

- 根目录旧的 `tfm-h573-flash签名固件下载固件快捷脚本.zip`（H573 地址：NS `0x0C088000` / 576 KB）已从 `stm32h5f4` 删除。Windows 烧录用 `windows-tfm-tools`，签名用上面的 `sign_kit`。

- 增加 makefile 编译的非安全侧工程 tfmmakeproject（已改为 STM32H5F4）。在 `tfmmakeproject/` 下执行 `make`（内部调用 `sign_kit/sign.sh`）。MCU 宏 `STM32H5F4xx`，`BL2_TRAILER_SIZE=0x3000`。签完的 `out/tfm_ns_signed.bin` 用 `windows-tfm-tools` 或 `./flash_stm32h5f4.sh` 烧。工程里已删除 `TFM_UPDATE.sh` / `regression.sh`。

- 增加 tfmcubeideproject 非安全侧 CubeIDE 工程（已改为 STM32H5F4）。打开 `tfmcubeideproject/STM32CubeIDE` 下的 `tfmminiproject`。已带 mbedtls 4.1.1（TLS/X.509 辅助，PSA crypto 仍走 SPE）。`s_veneers.o` 与 `signing_layout_*.o` 已纳入仓库。签完的 NS 镜像用 `windows-tfm-tools` 或 `./flash_stm32h5f4.sh` 烧。工程里已删除 `TFM_UPDATE.sh` / `regression.sh`。

- 增加 windows-tfm-tools：Windows 上给 STM32H5F4 用的 ST-Link 烧录脚本（`tfm_update.bat`）。把 bin/hex 或 `build_s`/`build_ns` 放到该目录。不要用旧 H573 hex。

## 文件统计

3956 directories, 12622 files

