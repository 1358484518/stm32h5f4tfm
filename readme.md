# Trusted Firmware-M 项目

基于 STM32H573 的 TF-M（Trusted Firmware-M）移植与开发项目。

平台名：`stm/stm32h573i_dk`。

| 分支 | 签名算法 | 说明 |
|------|----------|------|
| `master` | **RSA-3072** | 默认主线 |
| `stm32h573p256` | **EC-P256** | 仅改 MCUboot 镜像签名算法与配套密钥 |

本文档所在分支为 **`stm32h573p256` 衍生支线（ITS 加密 + 可编辑 OTP）**。

相对 `stm32h573p256` 额外默认：

- `TFM_DUMMY_PROVISIONING=OFF`（不用 TF-M 内置 dummy HUK/IAK）
- `ITS_ENCRYPTION=ON`（ITS 落盘用 HUK 派生 AEAD 加密；STM32H5 使用 `stm32h5xx/secure/tfm_hal_its_encryption.c`，nonce 走 `psa_generate_random`）
- 设备密钥来自 `keys/otp_device_secrets.json`，编进 Flash 仿真 OTP `@ 0x0C028000`，一键烧录会写 OTP

### HUK 与 IAK 分别干什么

| 密钥 | 用途 | 说明 |
|------|------|------|
| **HUK**（Hardware Unique Key） | **加密存储** | 派生 PS（及本支线 ITS）落盘用的 AEAD 密钥。管“数据怎么加密存放”。 |
| **IAK**（Initial Attestation Key） | **设备认证 / 证明** | 只用于 Initial Attestation：用私钥签 attestation token，对端用公钥验签。管“我是谁、证明给别人看”。 |

补充：

- 换 **HUK**：旧的 PS / ITS 密文会解不开，需按新密钥重新写入。
- 换 **IAK**：只影响**之后**新签的 attestation（要用新公钥才能验过）；一般**不影响**已用 HUK 加密存好的数据。
- 二者都写在 `keys/otp_device_secrets.json`，编进 Flash 仿真 OTP `@ 0x0C028000`。

### 设备 OTP 密钥（HUK / IAK）一键流程

本支线关闭了 dummy 预置，编译前把示例拷成可编辑文件并改成自己的值：

```bash
cp keys/otp_device_secrets.example.json keys/otp_device_secrets.json
# 编辑 huk / iak / boot_seed / implementation_id（各 32 字节 = 64 hex）
./buildtfm.sh test          # 注入 .inc、编 BL2/S/NS，并导出 keys/otp_flash_emulated.hex
./flash_stm32h573.sh        # 回归 + 烧 BL2/S/NS + OTP @ 0x0C028000
```

说明：

- `otp_device_secrets.json` 已 gitignore，勿提交真密钥；仓库只带 `.example.json`。
- 换 HUK 会使旧 ITS 密文失效（与 PS 类似）。
- IAK 勿再使用 TF-M dummy 前缀（脚本会拒绝）。
- ROTPK 仍由 `./buildtfm.sh` 按签名私钥自动同步到同一 OTP 区。

### 相对 `master` 改了什么

本支线相对 `master` **只围绕签名换成 EC-P256**，Flash 布局 / 槽位等不变。主要包括：

1. **TF-M BL2**：`stm32h573i_dk/config.cmake` 设 `MCUBOOT_SIGNATURE_TYPE=EC-P256`（公钥编进 BL2）
2. **TF-M SPE 签名**：默认密钥改为 `root-EC-P256.pem` / `root-EC-P256_1.pem`；`buildtfm.sh` 带 `SIG=` stamp 并 `-UMCUBOOT_KEY_S/NS`
3. **tf-m-tests**：NS 测试镜像随 SPE 导出的 `api_ns` 密钥签名（无需单独改测试仓密钥）
4. **makefile 工程**：`tfmmakeproject/api_ns/image_signing/keys/`（及 `sign_kit/keys/`）
5. **CubeIDE 工程**：`sign_kit/keys/` 与 `spe/api_ns/image_signing/keys/`（含 `mbedtls-411` 平行树）
6. **独立签名工具 / 压缩包**：根目录 `sign_kit.zip`、`ns_make_project.zip`、`tfmcubeideproject.7z` 内密钥与样例签名镜像
7. **Linux 一键烧录**：根目录 `./flash_stm32h573.sh`（回归 + 烧 BL2/S/NS；Windows 仍用 `windows-tfm-tools\tfm_update.bat`）

### 密钥文件名对应（同内容、不同路径）

本支线默认 dummy 密钥下，下面两对文件 **内容相同**，只是名字和用途不同；换密钥时必须整对一起换，不能只改一边。

| TF-M / BL2 路径（编 SPE / 编进 BL2） | `sign_kit` / `api_ns` 路径（签镜像） | 用途 |
|--------------------------------------|--------------------------------------|------|
| `bl2/ext/mcuboot/root-EC-P256.pem` | `image_s_signing_private_key.pem` | Secure（S）私钥 |
| `bl2/ext/mcuboot/root-EC-P256_1.pem` | `image_ns_signing_private_key.pem` | Non-Secure（NS）私钥 |

编 SPE 时 TF-M 会把 `root-EC-P256*.pem` 拷成 `build_s/api_ns/image_signing/keys/image_*_signing_private_key.pem`；各工程 `sign_kit/keys/` 里同名文件应与之一致。

切换算法或更换密钥后必须 **整片重烧 BL2 + S + NS**。

### S / NS 签名版本修改说明

MCUboot 镜像头里的 **version**（以及可选的 **security counter**）在签名时写入。升级时 BL2 会按版本 / 计数器决定是否接受新镜像；改版本后需重新签名再烧录对应槽位。

| 镜像 | 默认版本（本仓库常见配置） | 默认 security counter |
|------|---------------------------|------------------------|
| Secure（S） | `2.3.0`（随 `TFM_VERSION` / `MCUBOOT_IMAGE_VERSION_S`） | `1` |
| Non-Secure（NS） | `0.0.0` | `1` |

版本字符串格式：`major.minor.revision[+build]`，例如 `1.2.0`、`1.2.0+3`。

#### 1. SPE / `./buildtfm.sh` 编出来的已签名镜像

TF-M 默认在 `bl2/ext/mcuboot/mcuboot_default_config.cmake`：

- `MCUBOOT_IMAGE_VERSION_S` ← 默认 `${TFM_VERSION}`
- `MCUBOOT_IMAGE_VERSION_NS` ← 默认 `0.0.0`
- `MCUBOOT_SECURITY_COUNTER_S` / `_NS` ← 默认 `1`（也可设为 `auto`）

改法（任选其一）：

```bash
# 方式 A：cmake 缓存（清 build 后重编）
rm -rf trusted-firmware-m/build_s trusted-firmware-m/build_ns
# 在 buildtfm / 平台 cmake 中增加，或首次配置时传入：
#   -DMCUBOOT_IMAGE_VERSION_S=2.4.0
#   -DMCUBOOT_IMAGE_VERSION_NS=1.0.0
#   -DMCUBOOT_SECURITY_COUNTER_S=2
#   -DMCUBOOT_SECURITY_COUNTER_NS=2
./buildtfm.sh test
```

也可在平台 `config.cmake`（`stm32h573i_dk`）里 `set(MCUBOOT_IMAGE_VERSION_S ... CACHE STRING "" FORCE)` 固化。改完必须重编 SPE（及需要的 NS 测试），再烧 **S / NS**（若只改 NS 版本则重签重烧 NS 即可；S 同理）。

#### 2. 独立 `sign_kit`（CubeIDE post-build / 手动 `sign.sh`）

编辑对应工程下的 `sign_kit/config`（CubeIDE：`tfmcubeideproject/STM32CubeIDE/sign_kit/config`；根目录解压的 `sign_kit.zip` 同理）：

```text
MCUBOOT_IMAGE_VERSION_S=2.3.0
MCUBOOT_SECURITY_COUNTER_S=1
MCUBOOT_NS_IMAGE_MIN_VER=0.0.0+0

MCUBOOT_IMAGE_VERSION_NS=0.0.0
MCUBOOT_SECURITY_COUNTER_NS=1
MCUBOOT_S_IMAGE_MIN_VER=0.0.0+0
```

- 签 S 时用 `MCUBOOT_IMAGE_VERSION_S` + `MCUBOOT_SECURITY_COUNTER_S`
- 签 NS 时用 `MCUBOOT_IMAGE_VERSION_NS` + `MCUBOOT_SECURITY_COUNTER_NS`
- `*_IMAGE_MIN_VER` 是镜像依赖的对端最低版本（写入 dependency TLV），一般保持与板上已有镜像兼容，不要随意抬高

改完后重新执行 `./sign.sh` / `sign.bat`（或 CubeIDE 再编一次触发 post-build）。

#### 3. makefile 工程 `tfmmakeproject`

`Makefile` 里签名参数目前写死为 NS `--version 0.0.0`、`-s 1`（security counter）。改 NS 版本时改这两处后 `make` 重新生成 `out/tfm_ns_signed.bin`：

```makefile
--version 0.0.0 \
...
-s 1 \
-d "(0, 0.0.0+0)" \
```

`-d "(0, <S最低版本>)"` 表示 NS 镜像依赖的 S 镜像最低版本，须与板上 S 实际版本匹配。

#### 注意

- 仅抬高 version / security counter 做升级时：用**同一套**签名密钥签新镜像，烧到升级槽或按现有升级流程即可；**不必**因改版本而换密钥或重烧 BL2。
- 版本回退（比板上更低）在默认 MCUboot 策略下通常会被拒绝；需要回退请走你们自己的降级 / 确认流程，不要假设直接烧低版本一定能过。
- `sign_kit/config` 与 SPE cmake 里的版本应尽量一致，避免测试镜像和自签镜像版本语义混乱。

### 更换密钥（量产 / 自用）

> 推荐流程见上文「keys/、versions/ 与清编译」；本节保留细节说明。

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


## keys/、versions/ 与清编译

### keys/（更换签名密钥）

**本支线为 EC-P256。** 把两对固定文件名放到仓库根目录 `keys/`，再 `./buildtfm.sh`：

```bash
imgtool keygen -k keys/image_s_signing_private_key.pem  -t ecdsa-p256
imgtool keygen -k keys/image_ns_signing_private_key.pem -t ecdsa-p256
imgtool getpub -k keys/image_s_signing_private_key.pem  > keys/image_s_signing_public_key.pem
imgtool getpub -k keys/image_ns_signing_private_key.pem > keys/image_ns_signing_public_key.pem
./buildtfm.sh test
```

编译会覆盖各工程同名 pem、BL2 的 `root-EC-P256*.pem`，并同步 OTP ROTPK。换密钥后须回归擦片并重烧 **BL2 + S + NS**。详见 `keys/README.md`。

### versions/（S / NS 镜像版本）

编辑 `versions/config`（或 `image_s_version.txt` / `image_ns_version.txt`），`./buildtfm.sh` 会把版本与 security counter 写进签名镜像，并同步各 `sign_kit/config`。

```bash
# 改 versions/config 后
./buildtfm.sh test
imgtool verify trusted-firmware-m/build_s/bin/tfm_s_signed.bin   # 看 Image version
imgtool verify trusted-firmware-m/build_ns/bin/tfm_ns_signed.bin
```

详见 `versions/README.md`。改版本只需重编重烧对应槽位，不必换密钥。

### 清编译（不重新下载依赖）

不要手动 `rm -rf trusted-firmware-m/build_s`。`./buildtfm.sh` 默认先跑 `scripts/clean_tfm_build.sh`：只清编译产物，依赖缓存在 `trusted-firmware-m/.deps-cache/`。增量：`./buildtfm.sh test --no-clean`。


### 一键回归烧录（Linux）

仓库根目录 `./flash_stm32h573.sh`：先写 option bytes（含全片擦除），再烧 **BL2 + OTP + S + NS**。需已安装 `STM32_Programmer_CLI`，板子用 ST-Link。

```bash
# 首次 / 换密钥：
cp keys/otp_device_secrets.example.json keys/otp_device_secrets.json
# 按需改 huk/iak 后：
./buildtfm.sh test
./flash_stm32h573.sh        # 一键：回归 + 烧录（含 OTP）
# ./flash_stm32h573.sh download     # 只烧（含 OTP），不擦片
# ./flash_stm32h573.sh regression   # 只回归
# ./flash_stm32h573.sh all <ST-LINK SN>
```

| 镜像 | 地址 | 默认文件 |
|------|------|----------|
| Flash 仿真 OTP（HUK/IAK/ROTPK…） | `0x0C028000` | `keys/otp_flash_emulated.hex`（优先）；否则依赖 `bl2.hex` 内嵌 |
| BL2 | `0x0C00E000`（`bl2.hex` 也可带 OTP） | `…/api_ns/bin/bl2.hex`（优先）或 `bl2.bin` |
| S | `0x0C038000` | `…/api_ns/bin/tfm_s_signed.bin` |
| NS | `0x0C088000` | `trusted-firmware-m/build_ns/bin/tfm_ns_signed.bin` |

可用环境变量 `TFM_NS_BIN=` 指定其它已签名 NS。`BOOT_UBE=0xB4`（OEM-iRoT）。串口 **115200**。

本支线默认 `ITS_ENCRYPTION=ON`、`TFM_DUMMY_PROVISIONING=OFF`。改过 `keys/otp_device_secrets.json` 后必须重新 `./buildtfm.sh` 再烧，OTP 才会更新。

若串口已是 `sig_type: EC-P256` 且 primary `magic=good`，仍报 `Image in the primary slot is not valid`：多半是 OTP 里 ROTPK 不对——请重新 `./buildtfm.sh test` 再 `./flash_stm32h573.sh` 做一次回归+烧录。

Windows 一键：`windows-tfm-tools\tfm_update.bat`（会调 `regression.bat`）。OTP 独立 hex 以 Linux 脚本为准；Windows 侧请烧含 OTP 的 `bl2.hex` 或自行下载 `otp_flash_emulated.hex`。



## 文档


- [TF-M 编译笔记](./tfmwork/tfm编译笔记.txt) — 编译环境搭建、编译命令与踩坑记录
- 注意：如果编译不通过可以删除 .venv 重新创建py环境。

## 硬件平台

- 主控：STM32H573（Cortex-M33 + TrustZone）
- 调试器：ST-Link

## 代码提交 

- 执行命令: ./push_to_gitee.sh [提交说明]

- 增加非安全测试代码 nsdev.tar.xz ，在 ubuntu22.04 解压后执行make即可运行，这个工程不含硬件浮点计算。

- 增加 sign_kit.tar.xz 签名工具，只是用来对未加密固件进行签名使用。


- 增加 makefile 编译的非安全侧工程 tfmmakeproject ，可以使用make编译生成代码，正式版本关闭非安全侧测试，开启硬件浮点，使用内部晶振 PLL 240 MHZ

- 增加 tfmcubeideproject 非安全侧工程可以使用stm32cubeide开发，这是基于make工程 tfmmakeproject 移植而来。

- 增加 tfmcubeideproject.7z 非安全侧工程可以使用stm32cubeide开发，包含.o链接，因为git会忽略链接文件，所以压缩上传。本分支（`stm32h573p256`）压缩包内 `sign_kit`/`spe` 密钥与样例签名镜像已改为 **EC-P256**（与树内工程一致）；`master` 上仍为 RSA-3072。

- 增加 windows-tfm-tools 该工具是windows系统的使用的回归脚本和烧录工具。

- 本分支增加 Linux 一键回归烧录脚本 `flash_stm32h573.sh`（对应 Windows 的 `windows-tfm-tools\tfm_update.bat`）。

## 文件统计

3956 directories, 12622 files

