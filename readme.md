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

| TF-M / BL2 | `sign_kit` / `api_ns` | 用途 |
|------------|----------------------|------|
| `bl2/ext/mcuboot/root-EC-P256.pem` | `image_s_signing_private_key.pem` | Secure（S） |
| `bl2/ext/mcuboot/root-EC-P256_1.pem` | `image_ns_signing_private_key.pem` | Non-Secure（NS） |

切换算法或更换密钥后必须 **整片重烧 BL2 + S + NS**。

### 更换密钥（量产 / 自用）

算法须仍为 **EC-P256**。只换 `sign_kit/keys`、不重编不重烧 BL2，板上验签会失败。

```bash
imgtool keygen -k root-EC-P256-s.pem  -t ecdsa-p256
imgtool keygen -k root-EC-P256-ns.pem -t ecdsa-p256
# 覆盖 bl2/ext/mcuboot/root-EC-P256.pem 与 root-EC-P256_1.pem
# 同步拷到各 image_*_signing_private_key.pem
rm -rf trusted-firmware-m/build_s
./buildtfm.sh test
# 整片重烧
```

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

