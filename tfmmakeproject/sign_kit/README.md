# STM32H573 makefile 签名密钥（stm32h573p256）

本目录 `keys/` 为 TF-M dummy **EC-P256** 私钥，与 `api_ns/image_signing/keys/` 及 BL2 的
`root-EC-P256.pem` / `root-EC-P256_1.pem` 配套。

| 文件 | 对应 TF-M |
|------|-----------|
| `keys/image_s_signing_private_key.pem` | `bl2/ext/mcuboot/root-EC-P256.pem` |
| `keys/image_ns_signing_private_key.pem` | `bl2/ext/mcuboot/root-EC-P256_1.pem` |

`make` 实际签名使用 `api_ns/image_signing/keys/`。独立签包见仓库根目录 `sign_kit.zip`。
