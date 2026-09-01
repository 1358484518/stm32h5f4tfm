# MCUboot 签名密钥投放目录（两对：S / NS）

把你的密钥放到本目录，文件名必须固定为：

  image_s_signing_private_key.pem    Secure 私钥
  image_s_signing_public_key.pem     Secure 公钥
  image_ns_signing_private_key.pem   Non-Secure 私钥
  image_ns_signing_public_key.pem    Non-Secure 公钥

运行 ./buildtfm.sh 时会自动用这里的文件覆盖仓库里所有同名
image_*_signing_*.pem，并把两把私钥同步到 BL2 默认路径
（本支线常见为 root-RSA-3072*.pem 或 root-EC-P256*.pem，随 SIG 而定）。

某目标路径的目录不存在时只打印警告，不中断编译。
本目录为空或不放 pem 时，继续使用仓库默认 dummy 密钥。

*.pem 已 gitignore，请勿把量产私钥提交进仓库。
