# Trusted Firmware-M 项目

基于 STM32H573 的 TF-M（Trusted Firmware-M）移植与开发项目。





## keys/、versions/ 与清编译

### keys/（更换签名密钥）

**本支线为 RSA-3072。** 把两对固定文件名放到仓库根目录 `keys/`，再 `./buildtfm.sh`：

```bash
imgtool keygen -k keys/image_s_signing_private_key.pem  -t rsa-3072
imgtool keygen -k keys/image_ns_signing_private_key.pem -t rsa-3072
imgtool getpub -k keys/image_s_signing_private_key.pem  > keys/image_s_signing_public_key.pem
imgtool getpub -k keys/image_ns_signing_private_key.pem > keys/image_ns_signing_public_key.pem
./buildtfm.sh test
```

编译会覆盖各工程同名 pem、BL2 的 `root-RSA-3072*.pem`，并同步 OTP ROTPK。换密钥后须回归擦片并重烧 **BL2 + S + NS**。详见 `keys/README.md`。

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

仓库根目录 `./flash_stm32h573.sh`：先写 option bytes（含全片擦除），再烧 **BL2 + S + NS**。需已安装 `STM32_Programmer_CLI`，板子用 ST-Link。

```bash
git checkout master
./buildtfm.sh test          # 或 prod
./flash_stm32h573.sh        # 一键：回归 + 烧录
# ./flash_stm32h573.sh download     # 只烧，不擦片
# ./flash_stm32h573.sh regression   # 只回归
# ./flash_stm32h573.sh all <ST-LINK SN>
```

| 镜像 | 地址 | 默认文件 |
|------|------|----------|
| BL2（含 OTP 区） | `0x0C00E000`（`bl2.hex` 另含 `0x0C028000` OTP） | `…/api_ns/bin/bl2.hex`（优先）或 `bl2.bin` |
| S | `0x0C038000` | `…/api_ns/bin/tfm_s_signed.bin` |
| NS | `0x0C088000` | `trusted-firmware-m/build_ns/bin/tfm_ns_signed.bin` |

可用环境变量 `TFM_NS_BIN=` 指定其它已签名 NS。`BOOT_UBE=0xB4`（OEM-iRoT）。串口 **115200**。

Windows 一键：`windows-tfm-tools\tfm_update.bat`（会调 `regression.bat`）。


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

- 增加 tfmcubeideproject.7z 非安全侧工程可以使用stm32cubeide开发，包含.o链接，因为git会忽略链接文件，所以压缩上传。

- 增加 windows-tfm-tools 该工具是windows系统的使用的回归脚本和烧录工具。

## 文件统计

3956 directories, 12622 files

