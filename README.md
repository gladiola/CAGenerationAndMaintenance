# CAGenerationAndMaintenance

## Architecture overview

```
┌─────────────────────────────┐        USB drive        ┌──────────────────────────┐
│   Offline CA machine        │  ───────────────────►   │  OCSP server machine     │
│   (OpenBSD, air-gapped)     │  export-to-usb.sh        │  (OpenBSD, networked)    │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  physical carry          │  /etc/ocsp/              │
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

## Prerequisites

Both machines run **OpenBSD**. Install OpenSSL if it is not already present:

```sh
pkg_add openssl
```

The OCSP server machine also needs the
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) installed and
registered as an rc.d service named `ocspserver`.

All scripts use `#!/bin/sh` (OpenBSD's ksh-based `/bin/sh`), standard OpenBSD
utilities (`mount_msdos`, `sha256`, `rcctl`, `doas`), and `openssl(1)`.
Run all scripts as root via `doas`.

---

## File layout

```
scripts/
  setup-ca.sh               Initialize root CA directories and generate root key/cert
  create-intermediate-ca.sh Create a named intermediate CA signed by the root CA
  create-server-cert.sh     Issue a TLS server certificate (mTLS)
  create-client-cert.sh     Issue a client certificate (mTLS)
  revoke-cert.sh            Revoke a certificate and regenerate the CRL
  export-to-usb.sh          Package CA data onto USB for air-gap transfer (CA side)
  import-from-usb.sh        Import from USB into the OCSP server (OCSP server side)

config/
  openssl-root.cnf.template          Root CA OpenSSL config template
  openssl-intermediate.cnf.template  Intermediate CA OpenSSL config template
```

---

## 🌐 Language / Sprache / Langue / Idioma / Língua / Lingua / 語言 / 언어 / भाषा / Язык / لغة / Lugha / 言語 / Lang / Wika / ʻŌlelo / Gagana / Reo / Taal / Harshe / ቋንቋ / Èdè / ভাষা / 语言 / Keel / Kieli / Språk / Мова / ภาษา / Bahasa / Wika / Bahasa / Basa / Γλώσσα / Lingua / שפה / Teanga

| | | | | |
|---|---|---|---|---|
| 🇺🇸 [English](README.md) | 🇩🇪 [Deutsch](docs/README.de.md) | 🇪🇸 [Español](docs/README.es.md) | 🇫🇷 [Français](docs/README.fr.md) | 🇵🇹 [Português](docs/README.pt.md) |
| 🇮🇹 [Italiano](docs/README.it.md) | 🇭🇰 [繁體中文](docs/README.zh-HK.md) | 🇰🇷 [한국어](docs/README.ko.md) | 🇮🇳 [हिन्दी](docs/README.hi.md) | 🇷🇺 [Русский](docs/README.ru.md) |
| 🇸🇦 [العربية](docs/README.ar.md) | 🌍 [Kiswahili](docs/README.sw.md) | 🇯🇵 [日本語](docs/README.ja.md) | 🇭🇹 [Kreyòl ayisyen](docs/README.ht.md) | 🌺 [ʻŌlelo Hawaiʻi](docs/README.haw.md) |
| 🌊 [Gagana Sāmoa](docs/README.sm.md) | 🌿 [Te Reo Māori](docs/README.mi.md) | 🇿🇦 [Afrikaans](docs/README.af.md) | 🇳🇱 [Nederlands](docs/README.nl.md) | 🌍 [Hausa](docs/README.ha.md) |
| 🇪🇹 [አማርኛ](docs/README.am.md) | 🌍 [Yorùbá](docs/README.yo.md) | 🇧🇩 [বাংলা](docs/README.bn.md) | 🇨🇳 [简体中文](docs/README.zh-CN.md) | 🇪🇪 [Eesti](docs/README.et.md) |
| 🇫🇮 [Suomi](docs/README.fi.md) | 🇸🇪 [Svenska](docs/README.sv.md) | 🇳🇴 [Norsk](docs/README.no.md) | 🇺🇦 [Українська](docs/README.uk.md) | 🇹🇭 [ภาษาไทย](docs/README.th.md) |
| 🇮🇩 [Bahasa Indonesia](docs/README.id.md) | 🇵🇭 [Filipino](docs/README.tl.md) | 🇲🇾 [Bahasa Melayu](docs/README.ms.md) | 🌏 [Basa Jawa](docs/README.jv.md) | 🇬🇷 [Ελληνικά](docs/README.el.md) |
| 📜 [Latina](docs/README.la.md) | 🇮🇱 [עברית](docs/README.he.md) | 🇮🇪 [Gaeilge](docs/README.ga.md) | | |

---

Shell scripts for operating an **offline, air-gapped Certificate Authority** on
OpenBSD using OpenSSL, with revocation status published via a separate
[OpenBSD OCSP Server](https://github.com/gladiola/OpenBSDOCSPServer).
Updates are transferred between the offline CA machine and the OCSP server
machine by USB drive.

---

## Deployment planning (fill this out before running scripts)

Prepare your deployment values before running the steps below:

- Where is the CA going to be?  
  default: `/root/ca`  
  actual:

- What is the org and where is it?  
  default: `My Organization`  
  actual:

- What is the project name?  
  default: `MY PROJECT`  
  actual:

- When is the project versioned?  
  default: `01012027`  
  actual:

- What is the TLD?  
  default: `example.com`  
  actual:

- What is the subdomain?  
  default: `app.`  
  actual:

- What is the email address for the client user(s)?  
  default: `user@example.com`  
  actual:

- Where is the USB thumb drive for transfer?  
  default: `/dev/sd1i`  
  actual:

---

## Step-by-step usage

### 1 — Initialize the root CA  *(offline CA machine, once)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

This creates `/root/ca/`, generates an AES-256-encrypted 4096-bit root key, a
self-signed certificate valid for 20 years, and an OCSP signing certificate for
the root CA.

### 2 — Create an intermediate CA  *(offline CA machine, once per project)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Files are created under `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Issue a server certificate  *(offline CA machine)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Outputs under the intermediate CA directory:
- `private/app.example.com.01012027.key.pem` — encrypted private key
- `certs/app.example.com.01012027.cert.pem` — signed certificate
- `certs/app.example.com.01012027.server.full.pfx` — PKCS#12 bundle

### 4 — Issue client certificates  *(offline CA machine)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Repeat for each user. Transfer each `.full.pfx` bundle to the respective user
over a secure channel.

### 5 — Revoke a certificate  *(offline CA machine)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

To renew the CRL without revoking anything (e.g. on a scheduled basis):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Transfer to OCSP server via USB  *(air-gap workflow)*

#### On the offline CA machine

Insert a FAT32-formatted USB drive. Confirm the device:

```sh
dmesg | tail -20          # look for "sd1 at ..." lines
disklabel sd1             # identify the FAT32 partition (usually 'i')
```

Then export:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

The script writes a `SHA256` checksum manifest and unmounts the drive safely.
Physically carry the USB drive to the OCSP server machine.

#### On the OCSP server machine

```sh
dmesg | tail -20          # confirm USB device name
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

The script verifies checksums, copies updated files to `/etc/ocsp/`, and
reloads the `ocspserver` daemon via `rcctl`. If `EnableIndexTxtWatch` is `true`
in `appsettings.json`, the OCSP server will also pick up `index.txt` changes
automatically without a reload.

### 7 — Verify OCSP responses

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Naming conventions

| File | Pattern |
|------|---------|
| Intermediate CA key | `intermediate-PROJECT-DATE.key.pem` |
| Intermediate CA cert | `intermediate-PROJECT-DATE.cert.pem` |
| Certificate chain | `ca-chain-PROJECT-DATE.cert.pem` |
| Server cert | `SERVER_DOMAIN.DATE.cert.pem` |
| Server PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Client cert | `client-USER_EMAIL.DATE.cert.pem` |
| Client PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| OCSP signing cert | `INTER_NAME-ocsp.cert.pem` |

---

## Security notes

- The offline CA machine must **never be connected to a network**.
- Root and intermediate private keys are AES-256 encrypted. Store passphrases
  in a hardware token or physical vault, separate from the keys themselves.
- Always verify USB drive checksums before importing — `import-from-usb.sh`
  does this automatically using OpenBSD's `sha256 -C`.
- CRLs expire after 30 days by default. Schedule regular CRL renewal:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # then export-to-usb + import-from-usb
  ```
- OCSP signing certificates expire after 375 days. Renew them by rerunning
  `create-intermediate-ca.sh` with the same arguments; it skips steps that are
  already complete and only generates a new OCSP cert when needed.
