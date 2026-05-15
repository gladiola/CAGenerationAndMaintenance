# CAGenerationAndMaintenance

用於在 OpenBSD 上使用 OpenSSL 操作**離線、氣隔離憑證授權機構 (CA)** 的 Shell 腳本，
撤銷狀態通過單獨的 [OpenBSD OCSP 伺服器](https://github.com/gladiola/OpenBSDOCSPServer)
發布。更新通過 USB 隨身碟在離線 CA 機器和 OCSP 伺服器機器之間傳輸。

---

## 部署規劃（執行腳本前請先填寫）

在執行以下步驟前，請先準備好你的部署參數：

- CA 會部署在哪裡？  
  default: `/root/ca`  
  實際值：

- 機構名稱是甚麼，位於哪裡？  
  default: `My Organization`  
  實際值：

- 專案名稱是甚麼？  
  default: `MY PROJECT`  
  實際值：

- 專案版本日期是甚麼時候？  
  default: `01012027`  
  實際值：

- TLD 是甚麼？  
  default: `example.com`  
  實際值：

- 子網域是甚麼？  
  default: `app.`  
  實際值：

- 客戶端使用者的電郵地址是甚麼？  
  default: `user@example.com`  
  實際值：

- 用於傳輸的 USB 手指在哪裡？  
  default: `/dev/sd1i`  
  實際值：

---

## 架構概覽

```
┌─────────────────────────────┐        USB 隨身碟       ┌──────────────────────────┐
│   離線 CA 機器              │  ───────────────────►   │  OCSP 伺服器機器         │
│   (OpenBSD，氣隔離)         │  export-to-usb.sh        │  (OpenBSD，聯網)         │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  實體攜帶                │  /etc/ocsp/              │
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

## 先決條件

兩台機器均運行 **OpenBSD**。如果尚未安裝 OpenSSL，請先安裝：

```sh
pkg_add openssl
```

OCSP 伺服器機器還需要安裝
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) 並將其
註冊為名為 `ocspserver` 的 rc.d 服務。

所有腳本使用 `#!/bin/sh`（OpenBSD 基於 ksh 的 `/bin/sh`）、標準 OpenBSD
工具（`mount_msdos`、`sha256`、`rcctl`、`doas`）及 `openssl(1)`。
所有腳本請以 root 身份通過 `doas` 運行。

---

## 文件結構

```
scripts/
  setup-ca.sh               初始化根 CA 目錄並生成根金鑰/憑證
  create-intermediate-ca.sh 創建由根 CA 簽名的命名中間 CA
  create-server-cert.sh     頒發 TLS 伺服器憑證（mTLS）
  create-client-cert.sh     頒發客戶端憑證（mTLS）
  revoke-cert.sh            撤銷憑證並重新生成 CRL
  export-to-usb.sh          將 CA 資料打包到 USB（CA 端，用於氣隔離傳輸）
  import-from-usb.sh        從 USB 匯入 OCSP 伺服器（OCSP 伺服器端）

config/
  openssl-root.cnf.template          根 CA OpenSSL 配置範本
  openssl-intermediate.cnf.template  中間 CA OpenSSL 配置範本
```

---

## 逐步使用說明

### 1 — 初始化根 CA  *（離線 CA 機器，執行一次）*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

創建 `/root/ca/`，生成 AES-256 加密的 4096 位根金鑰、有效期 20 年的自簽名憑證，
以及根 CA 的 OCSP 簽名憑證。

### 2 — 創建中間 CA  *（離線 CA 機器，每個項目執行一次）*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

文件在 `/root/ca/intermediate-MY-PROJECT-01012027/` 下創建。

### 3 — 頒發伺服器憑證  *（離線 CA 機器）*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

輸出至中間 CA 目錄：
- `private/app.example.com.01012027.key.pem` — 加密私鑰
- `certs/app.example.com.01012027.cert.pem` — 已簽名憑證
- `certs/app.example.com.01012027.server.full.pfx` — PKCS#12 套件

### 4 — 頒發客戶端憑證  *（離線 CA 機器）*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

為每位用戶重複操作。通過安全渠道將每個 `.full.pfx` 套件傳輸給相應用戶。

### 5 — 撤銷憑證  *（離線 CA 機器）*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

無需撤銷而更新 CRL（例如定期更新）：

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — 通過 USB 傳輸至 OCSP 伺服器  *（氣隔離工作流程）*

#### 在離線 CA 機器上

插入 FAT32 格式的 USB 隨身碟，確認設備：

```sh
dmesg | tail -20          # 查看 "sd1 at ..." 行
disklabel sd1             # 識別 FAT32 分區（通常為 'i'）
```

然後導出：

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

腳本寫入 `SHA256` 校驗和清單並安全卸載磁碟機。
將 USB 隨身碟實體攜帶至 OCSP 伺服器機器。

#### 在 OCSP 伺服器機器上

```sh
dmesg | tail -20          # 確認 USB 設備名稱
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

腳本驗證校驗和，將更新的文件複製到 `/etc/ocsp/`，並通過 `rcctl` 重新載入
`ocspserver` 守護進程。若 `appsettings.json` 中 `EnableIndexTxtWatch` 為 `true`，
OCSP 伺服器也會自動偵測 `index.txt` 的更改，無需重新載入。

### 7 — 驗證 OCSP 回應

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## 命名規範

| 文件 | 模式 |
|------|------|
| 中間 CA 金鑰 | `intermediate-PROJECT-DATE.key.pem` |
| 中間 CA 憑證 | `intermediate-PROJECT-DATE.cert.pem` |
| 憑證鏈 | `ca-chain-PROJECT-DATE.cert.pem` |
| 伺服器憑證 | `SERVER_DOMAIN.DATE.cert.pem` |
| 伺服器 PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| 客戶端憑證 | `client-USER_EMAIL.DATE.cert.pem` |
| 客戶端 PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| OCSP 簽名憑證 | `INTER_NAME-ocsp.cert.pem` |

---

## 安全注意事項

- 離線 CA 機器**絕對不能連接到網絡**。
- 根和中間私鑰使用 AES-256 加密。將密碼短語存儲在硬件令牌或實體保險箱中，
  與金鑰分開存放。
- 導入前始終驗證 USB 隨身碟的校驗和——`import-from-usb.sh` 使用 OpenBSD 的
  `sha256 -C` 自動執行此操作。
- CRL 默認在 30 天後過期。安排定期 CRL 更新：
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # 然後 export-to-usb + import-from-usb
  ```
- OCSP 簽名憑證在 375 天後過期。通過使用相同參數重新運行
  `create-intermediate-ca.sh` 來更新它們；已完成的步驟將被跳過，
  僅在需要時生成新的 OCSP 憑證。
