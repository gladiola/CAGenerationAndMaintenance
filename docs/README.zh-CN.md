# CAGenerationAndMaintenance

用于在 OpenBSD 上使用 OpenSSL 操作**离线、气隔离证书颁发机构 (CA)** 的 Shell 脚本，
吊销状态通过单独的 [OpenBSD OCSP 服务器](https://github.com/gladiola/OpenBSDOCSPServer)
发布。更新通过 USB 驱动器在离线 CA 机器和 OCSP 服务器机器之间传输。

---

## 架构概述

```
┌─────────────────────────────┐        USB 驱动器       ┌──────────────────────────┐
│   离线 CA 机器              │  ───────────────────►   │  OCSP 服务器机器         │
│   (OpenBSD，气隔离)         │  export-to-usb.sh        │  (OpenBSD，联网)         │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  实体携带                │  /etc/ocsp/              │
│    openssl.cnf              │                          │    index.txt             │
│    certs/ca.cert.pem        │                          │    *.crl.pem             │
│    intermediate-*/          │                          │    *-responder.crt       │
│      index.txt              │                          │  OcspServer (ASP.NET)    │
│      crl/                   │                          │  rcctl enable ocspserver │
│      certs/                 │                          │                          │
│      ocsp/                  │                          │                          │
└─────────────────────────────┘                          └──────────────────────────┘
```

---

## 先决条件

两台机器均运行 **OpenBSD**。如果尚未安装 OpenSSL，请先安装：

```sh
pkg_add openssl
```

OCSP 服务器机器还需要安装
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) 并将其
注册为名为 `ocspserver` 的 rc.d 服务。

所有脚本使用 `#!/bin/sh`（OpenBSD 基于 ksh 的 `/bin/sh`）、标准 OpenBSD
工具（`mount_msdos`、`sha256`、`rcctl`、`doas`）及 `openssl(1)`。
所有脚本请以 root 身份通过 `doas` 运行。

---

## 文件结构

```
scripts/
  setup-ca.sh               初始化根 CA 目录并生成根密钥/证书
  create-intermediate-ca.sh 创建由根 CA 签名的命名中间 CA
  create-server-cert.sh     颁发 TLS 服务器证书（mTLS）
  create-client-cert.sh     颁发客户端证书（mTLS）
  revoke-cert.sh            吊销证书并重新生成 CRL
  export-to-usb.sh          将 CA 数据打包到 USB（CA 端，用于气隔离传输）
  import-from-usb.sh        从 USB 导入 OCSP 服务器（OCSP 服务器端）

config/
  openssl-root.cnf.template          根 CA OpenSSL 配置模板
  openssl-intermediate.cnf.template  中间 CA OpenSSL 配置模板
```

---

## 逐步使用说明

### 1 — 初始化根 CA  *（离线 CA 机器，执行一次）*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

创建 `/root/ca/`，生成 AES-256 加密的 4096 位根密钥、有效期 20 年的自签名证书，
以及根 CA 的 OCSP 签名证书。

### 2 — 创建中间 CA  *（离线 CA 机器，每个项目执行一次）*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

文件在 `/root/ca/intermediate-MY-PROJECT-01012027/` 下创建。

### 3 — 颁发服务器证书  *（离线 CA 机器）*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

输出至中间 CA 目录：
- `private/app.example.com.01012027.key.pem` — 加密私钥
- `certs/app.example.com.01012027.cert.pem` — 已签名证书
- `certs/app.example.com.01012027.server.full.pfx` — PKCS#12 套件

### 4 — 颁发客户端证书  *（离线 CA 机器）*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

为每位用户重复操作。通过安全渠道将每个 `.full.pfx` 套件传输给相应用户。

### 5 — 吊销证书  *（离线 CA 机器）*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

无需吊销而更新 CRL（例如定期更新）：

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — 通过 USB 传输至 OCSP 服务器  *（气隔离工作流程）*

#### 在离线 CA 机器上

插入 FAT32 格式的 USB 驱动器，确认设备：

```sh
dmesg | tail -20          # 查看 "sd1 at ..." 行
disklabel sd1             # 识别 FAT32 分区（通常为 'i'）
```

然后导出：

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

脚本写入 `SHA256` 校验和清单并安全卸载磁盘驱动器。
将 USB 驱动器实体携带至 OCSP 服务器机器。

#### 在 OCSP 服务器机器上

```sh
dmesg | tail -20          # 确认 USB 设备名称
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

脚本验证校验和，将更新的文件复制到 `/etc/ocsp/`，并通过 `rcctl` 重新加载
`ocspserver` 守护进程。若 `appsettings.json` 中 `EnableIndexTxtWatch` 为 `true`，
OCSP 服务器也会自动检测 `index.txt` 的更改，无需重新加载。

### 7 — 验证 OCSP 响应

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## 命名规范

| 文件 | 模式 |
|------|------|
| 中间 CA 密钥 | `intermediate-PROJECT-DATE.key.pem` |
| 中间 CA 证书 | `intermediate-PROJECT-DATE.cert.pem` |
| 证书链 | `ca-chain-PROJECT-DATE.cert.pem` |
| 服务器证书 | `SERVER_DOMAIN.DATE.cert.pem` |
| 服务器 PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| 客户端证书 | `client-USER_EMAIL.DATE.cert.pem` |
| 客户端 PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| OCSP 签名证书 | `INTER_NAME-ocsp.cert.pem` |

---

## 安全注意事项

- 离线 CA 机器**绝对不能连接到网络**。
- 根和中间私钥使用 AES-256 加密。将密码短语存储在硬件令牌或实体保险箱中，
  与密钥分开存放。
- 导入前始终验证 USB 驱动器的校验和——`import-from-usb.sh` 使用 OpenBSD 的
  `sha256 -C` 自动执行此操作。
- CRL 默认在 30 天后过期。安排定期 CRL 更新：
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # 然后 export-to-usb + import-from-usb
  ```
- OCSP 签名证书在 375 天后过期。通过使用相同参数重新运行
  `create-intermediate-ca.sh` 来更新它们；已完成的步骤将被跳过，
  仅在需要时生成新的 OCSP 证书。
