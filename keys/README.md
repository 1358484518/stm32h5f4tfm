# MCUboot 签名密钥投放目录（两对：S / NS）

**本支线签名算法：RSA-3072。** 请生成 RSA-3072 密钥，不要放 EC-P256。

## 固定文件名

| 文件 | 含义 |
|------|------|
| `image_s_signing_private_key.pem` | Secure 私钥 |
| `image_s_signing_public_key.pem` | Secure 公钥 |
| `image_ns_signing_private_key.pem` | Non-Secure 私钥 |
| `image_ns_signing_public_key.pem` | Non-Secure 公钥 |

## 生成并投放

```bash
imgtool keygen -k keys/image_s_signing_private_key.pem  -t rsa-3072
imgtool keygen -k keys/image_ns_signing_private_key.pem -t rsa-3072
imgtool getpub -k keys/image_s_signing_private_key.pem  > keys/image_s_signing_public_key.pem
imgtool getpub -k keys/image_ns_signing_private_key.pem > keys/image_ns_signing_public_key.pem
```

然后：

```bash
rm -rf trusted-firmware-m/build_s trusted-firmware-m/build_ns   # 或直接 ./buildtfm.sh（默认会清编译产物）
./buildtfm.sh test    # 或 prod
```

## 编译时会做什么

1. 用本目录四个 pem 覆盖仓库内所有同名 `image_*_signing_*.pem`
2. 把两把私钥同步到 BL2：
   - `trusted-firmware-m/bl2/ext/mcuboot/root-RSA-3072.pem`
   - `trusted-firmware-m/bl2/ext/mcuboot/root-RSA-3072_1.pem`
3. 按新公钥自动更新 OTP ROTPK（`otp_rotpk_hashes.inc`）
4. 某目标目录不存在只告警，不中断编译；本目录为空则用仓库默认 dummy 密钥

## 烧录

换密钥后须 **回归擦片并重烧 BL2 + S + NS**。只换 `sign_kit`、不重编不重烧 BL2，板上会出现 `magic=good` 后 `Image in the primary slot is not valid`。

`keys/*.pem` 已 gitignore，勿把量产私钥提交进仓库。
切到 EC-P256 支线前请换成本支线算法的密钥，或清空本目录。
