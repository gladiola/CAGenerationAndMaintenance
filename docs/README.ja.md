# CAGenerationAndMaintenance

OpenSSL を使用して OpenBSD 上で**オフライン・エアギャップ型認証局 (CA)** を運用するための
シェルスクリプトです。失効状態は別の
[OpenBSD OCSP サーバー](https://github.com/gladiola/OpenBSDOCSPServer)を通じて公開されます。
更新は USB ドライブを介してオフライン CA マシンと OCSP サーバーマシン間で転送されます。

---

## 🌐 Language / Sprache / Langue / Idioma / Língua / Lingua / 語言 / 언어 / भाषा / Язык / لغة / Lugha / 言語 / Lang / Wika / ʻŌlelo / Gagana / Reo / Taal / Harshe / ቋንቋ / Èdè / ভাষা / 语言 / Keel / Kieli / Språk / Мова / ภาษา / Bahasa / Wika / Bahasa / Basa / Γλώσσα / Lingua / שפה / Teanga

| | | | | |
|---|---|---|---|---|
| 🇺🇸 [English](../README.md) | 🇩🇪 [Deutsch](README.de.md) | 🇪🇸 [Español](README.es.md) | 🇫🇷 [Français](README.fr.md) | 🇵🇹 [Português](README.pt.md) |
| 🇮🇹 [Italiano](README.it.md) | 🇭🇰 [繁體中文](README.zh-HK.md) | 🇰🇷 [한국어](README.ko.md) | 🇮🇳 [हिन्दी](README.hi.md) | 🇷🇺 [Русский](README.ru.md) |
| 🇸🇦 [العربية](README.ar.md) | 🌍 [Kiswahili](README.sw.md) | 🇯🇵 [日本語](README.ja.md) | 🇭🇹 [Kreyòl ayisyen](README.ht.md) | 🌺 [ʻŌlelo Hawaiʻi](README.haw.md) |
| 🌊 [Gagana Sāmoa](README.sm.md) | 🌿 [Te Reo Māori](README.mi.md) | 🇿🇦 [Afrikaans](README.af.md) | 🇳🇱 [Nederlands](README.nl.md) | 🌍 [Hausa](README.ha.md) |
| 🇪🇹 [አማርኛ](README.am.md) | 🌍 [Yorùbá](README.yo.md) | 🇧🇩 [বাংলা](README.bn.md) | 🇨🇳 [简体中文](README.zh-CN.md) | 🇪🇪 [Eesti](README.et.md) |
| 🇫🇮 [Suomi](README.fi.md) | 🇸🇪 [Svenska](README.sv.md) | 🇳🇴 [Norsk](README.no.md) | 🇺🇦 [Українська](README.uk.md) | 🇹🇭 [ภาษาไทย](README.th.md) |
| 🇮🇩 [Bahasa Indonesia](README.id.md) | 🇵🇭 [Filipino](README.tl.md) | 🇲🇾 [Bahasa Melayu](README.ms.md) | 🌏 [Basa Jawa](README.jv.md) | 🇬🇷 [Ελληνικά](README.el.md) |
| 📜 [Latina](README.la.md) | 🇮🇱 [עברית](README.he.md) | 🇮🇪 [Gaeilge](README.ga.md) | | |

---

## アーキテクチャの概要

```
┌─────────────────────────────┐        USB ドライブ     ┌──────────────────────────┐
│   オフライン CA マシン      │  ───────────────────►   │  OCSP サーバーマシン     │
│   (OpenBSD、エアギャップ)   │  export-to-usb.sh        │  (OpenBSD、ネットワーク) │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  物理的な移動            │  /etc/ocsp/              │
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

## 前提条件

両方のマシンで **OpenBSD** が動作している必要があります。OpenSSL がまだインストールされていない
場合はインストールしてください:

```sh
pkg_add openssl
```

OCSP サーバーマシンには、`ocspserver` という名前の rc.d サービスとしてインストール・登録された
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) も必要です。

すべてのスクリプトは `#!/bin/sh`（OpenBSD の ksh ベースの `/bin/sh`）、標準 OpenBSD
ユーティリティ（`mount_msdos`、`sha256`、`rcctl`、`doas`）、および `openssl(1)` を使用します。
すべてのスクリプトを `doas` 経由で root として実行してください。

---

## ファイルレイアウト

```
scripts/
  setup-ca.sh               ルート CA ディレクトリを初期化してルートキー/証明書を生成する
  create-intermediate-ca.sh ルート CA によって署名された中間 CA を作成する
  create-server-cert.sh     TLS サーバー証明書を発行する (mTLS)
  create-client-cert.sh     クライアント証明書を発行する (mTLS)
  revoke-cert.sh            証明書を失効させ CRL を再生成する
  export-to-usb.sh          エアギャップ転送のために CA データを USB にパッケージする (CA 側)
  import-from-usb.sh        USB から OCSP サーバーにインポートする (OCSP サーバー側)

config/
  openssl-root.cnf.template          ルート CA OpenSSL 設定テンプレート
  openssl-intermediate.cnf.template  中間 CA OpenSSL 設定テンプレート
```

---

## デプロイ計画（スクリプト実行前にここを記入）

以下の手順を実行する前に、デプロイ値を準備してください。

- CA はどこに配置しますか？  
  default: `/root/ca`  
  実際:

- 組織名と所在地はどこですか？  
  default: `My Organization`  
  実際:

- プロジェクト名は何ですか？  
  default: `MY PROJECT`  
  実際:

- プロジェクトのバージョン日付はいつですか？  
  default: `01012027`  
  実際:

- TLD は何ですか？  
  default: `example.com`  
  実際:

- サブドメインは何ですか？  
  default: `app.`  
  実際:

- クライアントユーザーのメールアドレスは何ですか？  
  default: `user@example.com`  
  実際:

- 転送用 USB メモリはどこにありますか？  
  default: `/dev/sd1i`  
  実際:

---

## ステップバイステップの使用方法

### 1 — ルート CA を初期化する  *(オフライン CA マシン、一回のみ)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

`/root/ca/` を作成し、AES-256 暗号化された 4096 ビットのルートキー、有効期限 20 年の
自己署名証明書、およびルート CA 用の OCSP 署名証明書を生成します。

### 2 — 中間 CA を作成する  *(オフライン CA マシン、プロジェクトごとに一回)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

ファイルは `/root/ca/intermediate-MY-PROJECT-01012027/` 以下に作成されます。

### 3 — サーバー証明書を発行する  *(オフライン CA マシン)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

中間 CA ディレクトリへの出力:
- `private/app.example.com.01012027.key.pem` — 暗号化された秘密鍵
- `certs/app.example.com.01012027.cert.pem` — 署名済み証明書
- `certs/app.example.com.01012027.server.full.pfx` — PKCS#12 バンドル

### 4 — クライアント証明書を発行する  *(オフライン CA マシン)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

各ユーザーに対して繰り返します。各 `.full.pfx` バンドルを安全なチャンネルで
該当ユーザーに転送してください。

### 5 — 証明書を失効させる  *(オフライン CA マシン)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

何も失効させずに CRL を更新する（例：定期的に）:

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — USB を介して OCSP サーバーに転送する  *(エアギャップワークフロー)*

#### オフライン CA マシン上で

FAT32 フォーマットの USB ドライブを挿入し、デバイスを確認します:

```sh
dmesg | tail -20          # "sd1 at ..." 行を探す
disklabel sd1             # FAT32 パーティションを特定する（通常は 'i'）
```

次にエクスポートします:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

スクリプトは `SHA256` チェックサムマニフェストを書き込み、ドライブを安全に
アンマウントします。USB ドライブを物理的に OCSP サーバーマシンに持ち運びます。

#### OCSP サーバーマシン上で

```sh
dmesg | tail -20          # USB デバイス名を確認する
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

スクリプトはチェックサムを検証し、更新されたファイルを `/etc/ocsp/` にコピーし、
`rcctl` 経由で `ocspserver` デーモンをリロードします。`appsettings.json` で
`EnableIndexTxtWatch` が `true` の場合、OCSP サーバーはリロードなしに `index.txt`
の変更も自動的に検出します。

### 7 — OCSP レスポンスを確認する

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## 命名規則

| ファイル | パターン |
|---------|---------|
| 中間 CA キー | `intermediate-PROJECT-DATE.key.pem` |
| 中間 CA 証明書 | `intermediate-PROJECT-DATE.cert.pem` |
| 証明書チェーン | `ca-chain-PROJECT-DATE.cert.pem` |
| サーバー証明書 | `SERVER_DOMAIN.DATE.cert.pem` |
| サーバー PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| クライアント証明書 | `client-USER_EMAIL.DATE.cert.pem` |
| クライアント PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| OCSP 署名証明書 | `INTER_NAME-ocsp.cert.pem` |

---

## セキュリティに関する注意事項

- オフライン CA マシンは**決してネットワークに接続してはいけません**。
- ルートおよび中間の秘密鍵は AES-256 で暗号化されています。パスフレーズはハードウェア
  トークンまたは物理的な金庫に、鍵とは別に保管してください。
- インポート前に必ず USB ドライブのチェックサムを確認してください — `import-from-usb.sh`
  は OpenBSD の `sha256 -C` を使用して自動的にこれを行います。
- CRL はデフォルトで 30 日後に期限切れになります。定期的な CRL 更新をスケジュールしてください:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # 次に export-to-usb + import-from-usb
  ```
- OCSP 署名証明書は 375 日後に期限切れになります。同じ引数で `create-intermediate-ca.sh`
  を再実行して更新してください；すでに完了したステップはスキップされ、必要な場合にのみ
  新しい OCSP 証明書が生成されます。
