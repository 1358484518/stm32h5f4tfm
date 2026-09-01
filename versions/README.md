# 镜像版本投放目录（S / NS）

编辑本目录的 `config`（或拆分 txt），然后跑 `./buildtfm.sh`：
编译 SPE/NS 签名与各 `sign_kit` 都会用这里的版本 / security counter。

固定字段：

  MCUBOOT_IMAGE_VERSION_S / MCUBOOT_IMAGE_VERSION_NS
  MCUBOOT_SECURITY_COUNTER_S / MCUBOOT_SECURITY_COUNTER_NS
  MCUBOOT_NS_IMAGE_MIN_VER / MCUBOOT_S_IMAGE_MIN_VER（可选）

也可只放纯文本：

  image_s_version.txt
  image_ns_version.txt
  image_s_security_counter.txt
  image_ns_security_counter.txt

未填写时继续用仓库默认（S 常为 TFM_VERSION/2.3.0，NS 为 0.0.0）。
换版本后需重新编译（或 sign_kit 重签）再烧对应槽位；不必因改版本而换密钥。
