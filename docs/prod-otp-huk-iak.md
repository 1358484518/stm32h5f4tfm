# 量产级 HUK / IAK + DHUK（STM32H573 / H5F4）

> **不修改** 现有 6 条长期分支（master / stm32h5f4 / *p256 / *p256-debug）。  
> 本方案只在独立生产特性分支上演进。

## 两层

| 层 | 做什么 |
|----|--------|
| 片上 Flash OTP `0x08FFF000` | 存每台设备的 HUK/IAK 等 |
| **SAES DHUK** | 用芯片唯一 DHUK 加密 OTP 里的 HUK；运行时再解密给 TF-M |

DHUK **本身读不出来**。这里用的是：

`CRYP_KEYSEL_HW` + `KEYMODE_NORMAL` + AES-CBC  
→ 把 HUK 当数据加/解密到软件缓冲区（满足 `tfm_plat_get_huk()`）。

这和 `UnwrapKey`（密钥进 SAES 只写寄存器、软件拿不到明文）不是同一条路。

## 分工

| 资产 | 存放 | 保护 |
|------|------|------|
| S/NS 签名 + ROTPK | `keys/` → 模拟 OTP | 组织密钥 |
| **HUK** | 片上 OTP | **DHUK 加密**（flag `HUK_DHUK`） |
| **IAK** | 片上 OTP | 明文标量（证明仍要在软件侧用） |
| boot_seed / impl_id | 片上 OTP | 明文 |

## 工厂流程（DHUK）

DHUK 加密**必须在板子上**做（主机没有 DHUK）。

```bash
# 1) 主机生成明文材料（勿提交 git）
./scripts/provision_stm_chip_otp.sh factory/sn-001 SN001
# 得到 huk.bin / iak_*.pem / chip_otp_secrets*.hex（v1 明文便于调试）

# 2) 在目标芯片上调用 stm_chip_otp_secrets_build_dhuk_image()
#    （工厂夹具固件 / 一次性 seal 程序）把 huk 用 DHUK 加密，
#    得到带 STM_CHIP_OTP_FLAG_HUK_DHUK 的 v2 镜像

# 3) 把 v2 镜像写入片上 OTP @ 0x08FFF000，并锁定 OTP block

# 4) 烧录本 DHUK 特性分支的 BL2 + S + NS
./buildtfm.sh prod
```

运行时读 HUK：若 OTP flag 含 DHUK，则 `stm_saes_dhuk_decrypt()` 后再交给 TF-M。

## 配置

- `STM_PROD_CHIP_OTP_SECRETS=ON`
- `STM_PROD_DHUK_WRAP_HUK=ON`（本 DHUK 迭代分支）
- `TFM_DUMMY_PROVISIONING=OFF`

## 注意

- 片上 OTP 一次性；先用废板
- 未预置 OTP 时 BL2 失败封闭
- 6 条正式/调试长期分支不要拿来锁 OTP / 开 DHUK
