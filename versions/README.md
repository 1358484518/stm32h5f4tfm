# 镜像版本投放目录（S / NS）

编辑本目录后执行 `./buildtfm.sh`：SPE / NS 测试签名与各 `sign_kit` 都会使用这里的版本与 security counter。

## 推荐：编辑 `versions/config`

```text
MCUBOOT_IMAGE_VERSION_S=2.3.0
MCUBOOT_SECURITY_COUNTER_S=1
MCUBOOT_NS_IMAGE_MIN_VER=0.0.0+0

MCUBOOT_IMAGE_VERSION_NS=0.0.0
MCUBOOT_SECURITY_COUNTER_NS=1
MCUBOOT_S_IMAGE_MIN_VER=0.0.0+0
```

版本格式：`major.minor.revision[+build]`，例如 `2.3.0`、`1.0.0+3`。

## 或拆分纯文本（可覆盖 config 同名字段）

| 文件 | 含义 |
|------|------|
| `image_s_version.txt` | Secure 镜像版本 |
| `image_ns_version.txt` | Non-Secure 镜像版本 |
| `image_s_security_counter.txt` | Secure security counter（可选，默认 1） |
| `image_ns_security_counter.txt` | Non-Secure security counter（可选，默认 1） |

## 编译与检查

```bash
# 例如把 S 改成 2.4.0，NS 改成 1.0.0 后：
./buildtfm.sh test

imgtool verify trusted-firmware-m/build_s/bin/tfm_s_signed.bin
# 应看到 Image version: 2.4.0+0
imgtool verify trusted-firmware-m/build_ns/bin/tfm_ns_signed.bin
# 应看到 Image version: 1.0.0+0
```

## 说明

- 未填写时继续用仓库默认（S 常为 `TFM_VERSION` / `2.3.0`，NS 为 `0.0.0`）。
- 编译时会同步写入各工程 `sign_kit/config`，CubeIDE / makefile 的 `sign.sh` 也会用同一套版本。
- 换版本后重新编译（或 `sign_kit` 重签）再烧对应槽位；**不必**因改版本而换密钥或重烧 BL2。
- 版本回退在默认 MCUboot 策略下通常会被拒绝。
