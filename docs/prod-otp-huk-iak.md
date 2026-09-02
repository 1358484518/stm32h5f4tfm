# 量产级 HUK / IAK + DHUK（STM32H573 / H5F4）

> **不修改** 现有 6 条长期分支（master / stm32h5f4 / *p256 / *p256-debug）。  
> 本方案只在独立生产特性分支上演进。

## 分工

| 资产 | 存放 | 保护 |
|------|------|------|
| S/NS 签名 + ROTPK | `keys/` → 模拟 OTP | 组织密钥 |
| **HUK** | 片上 OTP `@ 0x08FFF000` | **DHUK 加密**（flag `HUK_DHUK`） |
| **IAK** | **Secure Flash** `@ 0x0C030000`（8 KB 扇区） | **DHUK 加密**；可重烧 |
| boot_seed / impl_id | 片上 OTP | 明文 |

Flash 布局：从原 PS 区划出 8 KB 给 IAK，**S primary 仍在 `0x38000`**。

DHUK 用法：`CRYP_KEYSEL_HW` + `KEYMODE_NORMAL` + AES-CBC（当数据加/解密进软件缓冲，满足 TF-M 字节 API）。不是 `UnwrapKey`。

## 工厂流程

```bash
# 1) 主机生成材料（勿提交 git）
./scripts/provision_stm_chip_otp.sh factory/sn-001 SN001
# OTP hex：HUK/boot_seed/impl_id（IAK 字段为 0）
# iak_raw.bin：给板上 seal 用

# 2) HUK：板上 stm_chip_otp_secrets_build_dhuk_image() → 烧片上 OTP → 锁 OTP block

# 3) IAK：板上 stm_iak_flash_dhuk_seal_and_store(iak_raw)
#    擦写 Secure Flash 扇区 0x0C030000（可重复，便于调试换钥）

# 4) 烧录本特性分支 BL2 + S + NS
./buildtfm.sh prod
```

运行时：

- HUK：OTP →（若 flag）`stm_saes_dhuk_decrypt`
- IAK：`stm_iak_flash_dhuk_read` → DHUK 解密 → attestation

关调试口后，NS/调试器读不到 Secure Flash；只有 SPE 能解密使用。

## 配置

- `STM_PROD_CHIP_OTP_SECRETS=ON`
- `STM_PROD_DHUK_WRAP_HUK=ON`
- `STM_PROD_IAK_FLASH_DHUK=ON`
- `TFM_DUMMY_PROVISIONING=OFF`

## 注意

- 片上 OTP 一次性；IAK Flash 扇区可重编程
- 未预置 OTP HUK 时 BL2 失败封闭；缺 IAK blob 时 BL2 告警，证明会失败
- 调试仍打开时，解密后的 IAK 仍可能从安全 RAM 被读出——量产要关调试
- 6 条正式/调试长期分支不要拿来锁 OTP / 开 DHUK
