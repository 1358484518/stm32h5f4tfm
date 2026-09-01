# Trusted Firmware-M 项目

基于 STM32H573 的 TF-M（Trusted Firmware-M）移植与开发项目。



### versions/（S / NS 镜像版本）

编辑仓库根目录 `versions/config`（或拆分 txt），`./buildtfm.sh` 会在签名时写入对应版本与 security counter，并同步到各 `sign_kit/config`。说明见 `versions/README.md`。

### keys/ 与清编译（不重新下载依赖）

- 把两对固定文件名公私钥放入仓库根目录 `keys/`，`./buildtfm.sh` 会自动覆盖各工程同名密钥并同步 OTP ROTPK。见 `keys/README.md`。
- 不要手动 `rm -rf trusted-firmware-m/build_s`。脚本默认先跑 `scripts/clean_tfm_build.sh`：只清编译产物，依赖缓存在 `trusted-firmware-m/.deps-cache/`。增量可用 `./buildtfm.sh test --no-clean`。


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

- 增加 tfmcubeideproject.7z 非安全侧工程可以使用stm32cubeide开发，包含.o链接，因为git会忽略链接文件，所以压缩上传。

- 增加 windows-tfm-tools 该工具是windows系统的使用的回归脚本和烧录工具。

## 文件统计

3956 directories, 12622 files

