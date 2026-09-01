# STM32H5F4 独立签名工具包

把未签名的 Secure / Non-Secure `.bin` 放进本目录，执行脚本并给出文件名即可。
必须和当前板上的 H5F4 BL2 / SPE 配套（`H5F4BL2` / `H5F4SWP2`）。

## 用法

Linux / macOS：

```bash
cd sign_kit
./sign.sh tfm_ns.bin     # 非安全
./sign.sh sapp.bin       # 安全
```

Windows（命令提示符或 PowerShell）：

```bat
cd sign_kit
sign.bat tfm_ns.bin
sign.bat sapp.bin
```

也可以把 `.bin` 拖到 `sign.bat` 上。

第一次运行会在本目录创建 `.venv`（不要用仓库根目录 TF-M 的 `.venv`）。

输出在本目录：`tfm_ns_signed.bin` / `sapp_signed.bin`。

文件名里带 `ns` 按非安全签；带 `sapp`、`tfm_s`、`_s.bin` 按安全签。看不出来时：

```bash
./sign.sh ns  app.bin
./sign.sh s   app.bin
```

## 烧录地址（STM32H5F4）

| 镜像 | 地址 | 签完大小 |
|---|---|---|
| `*_s_signed.bin` | `0x0C038000` | 352 KB |
| `*_ns_signed.bin` | `0x0C090000` | 1200 KB |

签完把 `tfm_ns_signed.bin` 放到 `windows-tfm-tools`，双击 `tfm_update.bat` 下载（会自动烧）。不要用本工程 `spe/api_ns` 里的旧脚本烧片。

本目录的密钥是 TF-M 开发用 dummy RSA-3072，和当前 SPE/BL2 配套。量产请替换 `keys/` 并同步更新板上 ROTPK。
