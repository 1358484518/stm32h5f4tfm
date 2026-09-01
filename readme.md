# Trusted Firmware-M 项目

基于 STM32H573 的 TF-M（Trusted Firmware-M）移植与开发项目。

平台名：`stm/stm32h573i_dk`。

| 分支 | 签名算法 | 说明 |
|------|----------|------|
| `master` | **RSA-3072** | 默认主线 |
| `stm32h573p256` | **EC-P256** | 仅改 MCUboot 镜像签名算法与配套密钥 |

本文档所在分支为 **`stm32h573p256`**。

### 相对 `master` 改了什么

本支线相对 `master` **只围绕签名换成 EC-P256**，Flash 布局 / 槽位等不变。主要包括：

1. **TF-M BL2**：`stm32h573i_dk/config.cmake` 设 `MCUBOOT_SIGNATURE_TYPE=EC-P256`（公钥编进 BL2）
2. **TF-M SPE 签名**：默认密钥改为 `root-EC-P256.pem` / `root-EC-P256_1.pem`；`buildtfm.sh` 带 `SIG=` stamp 并 `-UMCUBOOT_KEY_S/NS`
3. **tf-m-tests**：NS 测试镜像随 SPE 导出的 `api_ns` 密钥签名（无需单独改测试仓密钥）
4. **makefile 工程**：`tfmmakeproject/api_ns/image_signing/keys/`（及 `sign_kit/keys/`）
5. **CubeIDE 工程**：`sign_kit/keys/` 与 `spe/api_ns/image_signing/keys/`（含 `mbedtls-411` 平行树）
6. **独立签名工具 / 压缩包**：根目录 `sign_kit.zip`、`tfm-h573-flash…zip`、`ns_make_project.zip`、`tfmcubeideproject.7z` 内密钥与样例签名镜像

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

算法必须仍是 **EC-P256**。只换 `sign_kit/keys`、不重编不重烧 BL2，板上验签会失败（ROTPK 在 BL2 里）。

**1. 生成新密钥对（S / NS 各一把）**

```bash
# 可用 sign_kit 自己的 .venv，或仓库根目录 .venv（需已装 imgtool）
imgtool keygen -k root-EC-P256-s.pem  -t ecdsa-p256
imgtool keygen -k root-EC-P256-ns.pem -t ecdsa-p256
```

**2. 编进 BL2（公钥进芯片）**

覆盖 TF-M 默认路径（或 cmake 传 `-DMCUBOOT_KEY_S=... -DMCUBOOT_KEY_NS=...`）：

- S：`trusted-firmware-m/bl2/ext/mcuboot/root-EC-P256.pem`（内容 = `image_s_signing_private_key.pem`）
- NS：`trusted-firmware-m/bl2/ext/mcuboot/root-EC-P256_1.pem`（内容 = `image_ns_signing_private_key.pem`）

然后清 SPE 再编：

```bash
git checkout stm32h573p256
rm -rf trusted-firmware-m/build_s
./buildtfm.sh test    # 或 prod
```

**3. 同步给各签名工具**

把**与上表同一对**私钥拷到实际在用的目录（文件名用右边这一套）：

| 文件 | 用途 |
|------|------|
| `image_s_signing_private_key.pem` | 签 Secure |
| `image_ns_signing_private_key.pem` | 签 Non-Secure |

常见位置：

- `tfmmakeproject/api_ns/image_signing/keys/`（及若存在的 `tfmmakeproject/sign_kit/keys/`）
- `tfmcubeideproject/STM32CubeIDE/sign_kit/keys/`
- `tfmcubeideproject/STM32CubeIDE/spe/api_ns/image_signing/keys/`
- `trusted-firmware-m-mbedtls-411-ns-tls/tfmcubeideproject/...` 平行树中的同名路径
- 根目录 `sign_kit.zip` / `tfm-h573-flash…zip` / `ns_make_project.zip` / 重建后的 `tfmcubeideproject.7z`

公钥可从 `trusted-firmware-m/build_s/api_ns/image_signing/keys/`（或 `bin/`）再拷一份对齐。

**4. 整片重烧**

用新密钥签过的镜像，重烧 **BL2 + S + NS**。只烧 NS 不够。

仓库默认仍是 TF-M **开发用 dummy** 密钥；量产请用自己的密钥并妥善保管私钥。

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

- 增加 tfm-h573-flash签名固件下载固件快捷脚本.zip 签名回归烧录工具，里面有使用说明文档，用来签名未签名的固件和下载程序到flash。

- 增加 makefile 编译的非安全侧工程 tfmmakeproject ，可以使用make编译生成代码，正式版本关闭非安全侧测试，开启硬件浮点，使用内部晶振 PLL 240 MHZ

- 增加 tfmcubeideproject 非安全侧工程可以使用stm32cubeide开发，这是基于make工程 tfmmakeproject 移植而来。

- 增加 tfmcubeideproject.7z 非安全侧工程可以使用stm32cubeide开发，包含.o链接，因为git会忽略链接文件，所以压缩上传。本分支（`stm32h573p256`）压缩包内 `sign_kit`/`spe` 密钥与样例签名镜像已改为 **EC-P256**（与树内工程一致）；`master` 上仍为 RSA-3072。

- 增加 windows-tfm-tools 该工具是windows系统的使用的回归脚本和烧录工具。

## 文件统计

3956 directories, 12622 files

