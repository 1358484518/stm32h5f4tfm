# 量产级 HUK / IAK（STM32H573 / H5F4，本生产分支）

本分支在 P256 正式支线之上，把 **设备密钥** 从 Flash 模拟 OTP 挪到 **片上 Flash OTP（0x08FFF000）**，并由工厂按片预置。

现有 6 条长期分支（master / stm32h5f4 / *p256 / *p256-debug）**不包含**本方案。

## 分工

| 资产 | 存放 | 谁生成 |
|------|------|--------|
| S/NS 签名密钥 + ROTPK | `keys/` → 编进 BL2 模拟 OTP | 组织共用，`./buildtfm.sh` 同步 |
| **HUK** | **片上 OTP** | **每台设备唯一**，工厂脚本 |
| **IAK** | **片上 OTP** | **每台设备唯一**，工厂脚本 |
| boot_seed / implementation_id | 片上 OTP | 每台设备 |

运行时：`stm_otp_flash_prod.c` 读 HUK/IAK 走片上 OTP；ROTPK 仍走原来的模拟 OTP。

## 工厂步骤

```bash
# 1. 为这一台板生成密钥（输出勿提交 git）
./scripts/provision_stm_chip_otp.sh factory/sn-001 SN001

# 2. 用 STM32CubeProgrammer 把 chip_otp_secrets.hex 写到 0x08FFF000
#    然后锁定对应 OTP block（一次性，不可恢复）

# 3. 编译并擦片烧录本分支 BL2 + S + NS
./buildtfm.sh prod
# flash BL2 / tfm_s_signed / tfm_ns_signed
```

成功时 BL2 日志应出现：`Chip OTP device secrets OK (HUK/IAK)`。  
若未预置片上 OTP，BL2 **直接 Error_Handler**（失败封闭），不会静默用 dummy。

## 配置开关（本分支已打开）

- `STM_PROD_CHIP_OTP_SECRETS=ON`
- `TFM_DUMMY_PROVISIONING=OFF`
- `PLATFORM_DEFAULT_OTP=OFF`（改用 `stm_otp_flash_prod.c`）

## 与硬件 DHUK 的关系

STM32H5 SAES 的 **DHUK 不可软件导出**，不能直接塞进 TF-M 的 `tfm_plat_get_huk()` 字节接口。  
本阶段：唯一 HUK 放在 **真 OTP**；后续可再加 SAES wrap（用 DHUK 包裹导出型 HUK）作为加固。

## 注意

- 片上 OTP **只能写一次**，先用废板验证
- `factory/` 产物含私钥，必须进 HSM/保险柜，已建议 gitignore
- 换组织签名密钥仍只动 `keys/` + 重编 BL2；与 IAK/HUK 无关
- Debug 开发请继续用 `*p256-debug` / `*p256`，不要在调试板上盲目锁 OTP
