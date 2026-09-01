# Trusted Firmware-M 项目

基于 STM32H5F4 的 TF-M（Trusted Firmware-M）移植与开发项目（由 STM32H573 平台最小改动移植）。

平台名：`stm/stm32h5f4`。

| 分支 | 签名算法 | 说明 |
|------|----------|------|
| `stm32h5f4` | **RSA-3072** | 默认开发支线 |
| `stm32h5f4p256`（及 `stm32h5f4-p256`） | **EC-P256** | 仅改 MCUboot 镜像签名算法与配套密钥 |

本文档所在分支为 **`stm32h5f4p256`**。

### 相对 `stm32h5f4` 改了什么

本支线相对 `stm32h5f4` **只围绕签名换成 EC-P256**，Flash 布局 / 槽位地址 / NS 工程逻辑不变。主要包括：

1. `trusted-firmware-m/platform/ext/target/stm/stm32h5f4/config.cmake`：`MCUBOOT_SIGNATURE_TYPE=EC-P256`
2. makefile / CubeIDE / `sign_kit` 下的 S、NS 公私钥：换成 TF-M 自带 dummy **EC-P256**（不再用 RSA-3072）
3. `buildtfm.sh`：算法写入 stamp（RSA↔EC 会强制清 `build_s`）；正确解析 `SIG_TYPE`；内层 cmake `-UMCUBOOT_KEY_S/NS`
4. 按 EC-P256 重编后刷新跟踪的 `build_s/bin/bl2.hex`（及 veneers）
5. 文档与说明文字改为 EC-P256；并修复损坏的 MCUBoot `0002` mailbox patch（否则 SPE 编不过）

从 `stm32h5f4` 切到本支线后，必须 **整片重烧 BL2 + S + NS**，并只用本支线的 `sign_kit/keys`。不要把 RSA 密钥 / BL2 与 P256 混用。

### 更换密钥（量产 / 自用）

算法必须仍是 **EC-P256**。

**推荐：只往仓库根目录 `keys/` 放四份固定文件名，编译时自动覆盖全库。**

| 固定文件名 | 含义 |
|------------|------|
| `keys/image_s_signing_private_key.pem` | Secure 私钥 |
| `keys/image_s_signing_public_key.pem` | Secure 公钥 |
| `keys/image_ns_signing_private_key.pem` | Non-Secure 私钥 |
| `keys/image_ns_signing_public_key.pem` | Non-Secure 公钥 |

```bash
imgtool keygen -k keys/image_s_signing_private_key.pem  -t ecdsa-p256
imgtool keygen -k keys/image_ns_signing_private_key.pem -t ecdsa-p256
imgtool getpub -k keys/image_s_signing_private_key.pem  > keys/image_s_signing_public_key.pem
imgtool getpub -k keys/image_ns_signing_private_key.pem > keys/image_ns_signing_public_key.pem

rm -rf trusted-firmware-m/build_s trusted-firmware-m/build_ns
./buildtfm.sh test
```

`./buildtfm.sh` 会：

1. 用 `keys/` 覆盖各工程里所有同名 `image_*_signing_*.pem`，以及 BL2 的 `root-EC-P256.pem` / `root-EC-P256_1.pem`
2. 按新私钥自动同步 OTP ROTPK（`otp_rotpk_hashes.inc` 等）
3. 某目标**目录不存在**只告警，**不中断编译**；`keys/` 为空则继续用仓库默认 dummy 密钥

`keys/*.pem` 已 gitignore，勿把量产私钥提交进仓库。说明见 `keys/README.md`。

换密钥后仍须 **回归擦片并重烧 BL2 + S + NS**（BL2/`bl2.hex` 带 OTP 公钥哈希）。只换 `sign_kit`、不重编不重烧 BL2，板上会出现 `magic=good` 后 `Image in the primary slot is not valid`。

**可选：不用 `keys/` 时**，仍可手动覆盖 `trusted-firmware-m/bl2/ext/mcuboot/root-EC-P256*.pem` 与各 `sign_kit` / `image_signing/keys` 下同名文件，或传 `MCUBOOT_KEY_S` / `MCUBOOT_KEY_NS`。

默认 dummy 下，`root-EC-P256.pem` 与 `image_s_signing_private_key.pem`（以及 NS 那一对）内容相同，只是路径不同；换密钥时必须整对一起换。


### versions/（S / NS 镜像版本）

编辑仓库根目录 `versions/config`（或 `image_s_version.txt` / `image_ns_version.txt`），`./buildtfm.sh` 会在签名时写入对应版本与 security counter，并同步到各 `sign_kit/config`。说明见 `versions/README.md`。


## 编译与烧录

SPE / BL2 / 官方 NS 测试固件只使用仓库根目录的 `./buildtfm.sh` 编译。烧录用 Linux 的 `./flash_stm32h5f4.sh`，或 Windows 的 `windows-tfm-tools\tfm_update.bat`。  
`tfmcubeideproject/` 是 STM32H5F4 非安全侧 CubeIDE 工程。`tfmmakeproject/` 是同一套 SPE 上的 makefile NS 工程（`make` 生成 `out/tfm_ns_signed.bin`）。签完的镜像用上述脚本烧。这两个 NS 工程里已去掉 ST 的 `TFM_UPDATE.sh` / `regression.sh`。

**清编译 / 不重新下载依赖：** 不要手动 `rm -rf trusted-firmware-m/build_s`（会丢掉 FetchContent 源码，下次又要联网）。`./buildtfm.sh` 默认会先跑 `scripts/clean_tfm_build.sh`：只删编译产物，把 mcuboot/cmsis/qcbor/… 留在 `trusted-firmware-m/.deps-cache/`，再离线重编。也可单独执行：

```bash
./scripts/clean_tfm_build.sh    # 清 build_s/build_ns，保留依赖缓存
./buildtfm.sh test              # 默认先 clean 再编
./buildtfm.sh test --no-clean   # 增量编译（不删 build 目录）
```

首次仍需联网下载依赖；之后有 `.deps-cache` 即可离线。

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
git checkout stm32h5f4p256
git pull origin stm32h5f4p256

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

开发镜像用 TF-M dummy **EC-P256** 密钥（`stm32h5f4` 支线仍为 RSA-3072），启动日志里的 `NOT SECURE` 是预期现象。与 RSA 支线互切后必须整片重烧 BL2 + S + NS，并使用本支线的 `sign_kit/keys`。更换自有密钥见上文「更换密钥」。

`./flash_stm32h5f4.sh` 只写当前运行槽（BL2 / S primary / NS primary）。**升级下载**请写 MCUBoot secondary：S `0x0C200000`（`slot2`）、NS `0x0C258000`（`slot3`）。不要用 H573 的 `0x0C118000` / `0x0C168000`。完整表见下面 Windows 一节。

### Windows 烧录

`windows-tfm-tools` 只保留 ST-Link 脚本。详细步骤见 `windows-tfm-tools/本目录工具使用说明.txt`。

1. `git checkout stm32h5f4p256` 后 `git pull origin stm32h5f4p256`。双击后窗口 rev 应为 `h5f4-20260901h`（或更新）。
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

- 增加 H5F4 `sign_kit` 签名工具：`tfmmakeproject/sign_kit` 与 `tfmcubeideproject/STM32CubeIDE/sign_kit`。只签未加密固件。NS 1200 KB @ `0x0C090000`，S 352 KB @ `0x0C038000`。Linux：`./sign.sh tfm_ns.bin`；Windows：`sign.bat tfm_ns.bin`。根目录旧的 `sign_kit.zip`（H573）已从 `stm32h5f4` 删除。支线 `stm32h5f4p256` 仅把 MCUboot 签名改为 EC-P256（相对 `stm32h5f4` 的差异与换密钥步骤见上文）。

- 根目录旧的 `tfm-h573-flash签名固件下载固件快捷脚本.zip`（H573 地址：NS `0x0C088000` / 576 KB）已从 `stm32h5f4` 删除。Windows 烧录用 `windows-tfm-tools`，签名用上面的 `sign_kit`。

- 增加 makefile 编译的非安全侧工程 tfmmakeproject（已改为 STM32H5F4）。在 `tfmmakeproject/` 下执行 `make`（内部调用 `sign_kit/sign.sh`）。MCU 宏 `STM32H5F4xx`，`BL2_TRAILER_SIZE=0x3000`。签完的 `out/tfm_ns_signed.bin` 用 `windows-tfm-tools` 或 `./flash_stm32h5f4.sh` 烧。工程里已删除 `TFM_UPDATE.sh` / `regression.sh`。

- 增加 tfmcubeideproject 非安全侧 CubeIDE 工程（已改为 STM32H5F4）。打开 `tfmcubeideproject/STM32CubeIDE` 下的 `tfmminiproject`。已带 mbedtls 4.1.1（TLS/X.509 辅助，PSA crypto 仍走 SPE）。`s_veneers.o` 与 `signing_layout_*.o` 已纳入仓库。签完的 NS 镜像用 `windows-tfm-tools` 或 `./flash_stm32h5f4.sh` 烧。工程里已删除 `TFM_UPDATE.sh` / `regression.sh`。

- 增加 windows-tfm-tools：Windows 上给 STM32H5F4 用的 ST-Link 烧录脚本（`tfm_update.bat`）。把 bin/hex 或 `build_s`/`build_ns` 放到该目录。不要用旧 H573 hex。

## 文件统计

3956 directories, 12622 files

