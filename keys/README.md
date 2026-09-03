# MCUboot 签名密钥投放目录（两对：S / NS）

**本支线签名算法：EC-P256。** 请生成 ECDSA-P256 密钥，不要放 RSA。

## 固定文件名

| 文件 | 含义 |
|------|------|
| `image_s_signing_private_key.pem` | Secure 私钥 |
| `image_s_signing_public_key.pem` | Secure 公钥 |
| `image_ns_signing_private_key.pem` | Non-Secure 私钥 |
| `image_ns_signing_public_key.pem` | Non-Secure 公钥 |

## 生成并投放

```bash
imgtool keygen -k keys/image_s_signing_private_key.pem  -t ecdsa-p256
imgtool keygen -k keys/image_ns_signing_private_key.pem -t ecdsa-p256
imgtool getpub -k keys/image_s_signing_private_key.pem  > keys/image_s_signing_public_key.pem
imgtool getpub -k keys/image_ns_signing_private_key.pem > keys/image_ns_signing_public_key.pem
```

然后：

```bash
./buildtfm.sh test    # 或 prod（默认会清编译产物并保留依赖缓存）
```

## 编译时会做什么

1. 用本目录四个 pem 覆盖仓库内所有同名 `image_*_signing_*.pem`
2. 把两把私钥同步到 BL2：
   - `trusted-firmware-m/bl2/ext/mcuboot/root-EC-P256.pem`
   - `trusted-firmware-m/bl2/ext/mcuboot/root-EC-P256_1.pem`
3. 按新公钥自动更新 OTP ROTPK（`otp_rotpk_hashes.inc`）
4. 某目标目录不存在只告警，不中断编译；本目录为空则用仓库默认 dummy 密钥

## 烧录

换密钥后须 **回归擦片并重烧 BL2 + S + NS**。只换 `sign_kit`、不重编不重烧 BL2，板上会出现 `magic=good` 后 `Image in the primary slot is not valid`。

`keys/*.pem` 已 gitignore，勿把量产私钥提交进仓库。
切到 RSA 支线前请换成 RSA-3072 密钥，或清空本目录。

## 设备 OTP 密钥（HUK / IAK）

本支线 `TFM_DUMMY_PROVISIONING=OFF`，设备密钥来自本目录的 JSON，编进 Flash 仿真 OTP `@ 0x0C028000`（一键烧录会写进去）。

| 文件 | 用途 |
|------|------|
| `otp_device_secrets.example.json` | 仓库自带的**示例**（可提交）。各字段 32 字节 = 64 hex。 |
| `otp_device_secrets.json` | **你自己的**密钥（已 gitignore）。编译真正读取的是这个。 |
| `otp_flash_emulated.hex` | 编译结束后由 `buildtfm.sh` 从 BL2 的 `.BL2_OTP` 导出，供烧录脚本写 OTP（gitignore）。 |

字段含义：

| 字段 | 用途 |
|------|------|
| `huk` | **加密存储**（PS / 本支线 ITS 派生 AEAD） |
| `iak` | **设备 attestation**（Initial Attestation 签名） |
| `boot_seed` / `implementation_id` | 证明相关设备标识材料 |

### 编译时如何处理 `otp_device_secrets.json`

`./buildtfm.sh` 会调用 `scripts/apply_stm_otp_device_secrets.py`：

1. **若 `otp_device_secrets.json` 不存在**：自动从 `otp_device_secrets.example.json` **复制一份**再继续（所以不手动 `cp` 也能编过，但用的是示例值）。
2. **若文件已存在**：**不会覆盖**，直接用你改过的内容生成 `otp_device_secrets.inc` 等。
3. 改完 JSON 后必须重新 `./buildtfm.sh` 再烧，OTP 才会更新。

推荐流程：

```bash
cp keys/otp_device_secrets.example.json keys/otp_device_secrets.json
# 编辑 huk / iak / …
./buildtfm.sh test
./flash_stm32h5f4.sh
```

勿把真密钥提交进仓库。IAK 勿使用 TF-M 内置 dummy 前缀（脚本会拒绝）。
