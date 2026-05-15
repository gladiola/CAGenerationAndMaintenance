# CAGenerationAndMaintenance

Awọn iwe afọwọkọ shell fun ṣiṣakoso **Alaṣẹ Iwe-ẹri (CA) ti ko ni asopọ intanẹẹti
ati ti o ya sọtọ ni afẹfẹ** lori OpenBSD pẹlu OpenSSL. Ipo ifagile ti wa ni atẹjade
nipasẹ [Olupin OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer) lọtọ.
Awọn imudojuiwọn ni a gbe laarin ẹrọ CA ti ko ni intanẹẹti ati ẹrọ olupin OCSP
nipasẹ USB.

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

## Akopọ Ilana Faaji

```
┌─────────────────────────────┐        USB Drive        ┌──────────────────────────┐
│   Ẹrọ CA (laisi intanẹẹti)  │  ───────────────────►   │  Ẹrọ Olupin OCSP        │
│   (OpenBSD, ya sọtọ)        │  export-to-usb.sh        │  (OpenBSD, ninu nẹtiwọọki)│
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  gbigbe ara              │  /etc/ocsp/              │
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

## Awọn Ibeere Alakọbẹrẹ

Awọn ẹrọ mejeeji ṣiṣẹ **OpenBSD**. Fi OpenSSL sori ẹrọ ti ko ba si tẹlẹ:

```sh
pkg_add openssl
```

Ẹrọ olupin OCSP tun nilo
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) ti a fi sori ẹrọ
ati ti o forukọsilẹ gẹgẹ bi iṣẹ rc.d ti a n pè ní `ocspserver`.

Gbogbo awọn iwe afọwọkọ lo `#!/bin/sh` (OpenBSD `/bin/sh` ti o da lori ksh), awọn
ohun elo OpenBSD boṣewa (`mount_msdos`, `sha256`, `rcctl`, `doas`), ati `openssl(1)`.
Ṣe gbogbo awọn iwe afọwọkọ gẹgẹ bi root nipasẹ `doas`.

---

## Eto Faili

```
scripts/
  setup-ca.sh               Pilẹṣẹ awọn iwe ipamọ CA gbongbo ati ṣẹda bọtini/iwe-ẹri gbongbo
  create-intermediate-ca.sh Ṣẹda CA aarin ti CA gbongbo fowo si
  create-server-cert.sh     Ṣe agbejade iwe-ẹri olupin TLS (mTLS)
  create-client-cert.sh     Ṣe agbejade iwe-ẹri onibara (mTLS)
  revoke-cert.sh            fagile iwe-ẹri ati tun ṣẹda CRL
  export-to-usb.sh          Ṣajọpọ data CA sori USB fun gbigbe ya sọtọ (ẹgbẹ CA)
  import-from-usb.sh        Gbe wọle lati USB si olupin OCSP (ẹgbẹ olupin OCSP)

config/
  openssl-root.cnf.template          Awoṣe iṣeto OpenSSL fun CA gbongbo
  openssl-intermediate.cnf.template  Awoṣe iṣeto OpenSSL fun CA aarin
```

---

## Eto imuṣiṣẹ (fọwọsi eyi kí o tó ṣiṣẹ́ scripts)

Mura àwọn iye imuṣiṣẹ rẹ ṣáájú ṣiṣe àwọn ìgbésẹ̀ tó wà ní isalẹ:

- Níbo ni CA yóò wà?  
  default: `/root/ca`  
  gangan:

- Kí ni orúkọ ilé-iṣẹ́, ó sì wà níbo?  
  default: `My Organization`  
  gangan:

- Kí ni orúkọ iṣẹ́-akanṣe?  
  default: `MY PROJECT`  
  gangan:

- Ọjọ́ wo ni a fi ń ṣe ẹya iṣẹ́-akanṣe?  
  default: `01012027`  
  gangan:

- Kí ni TLD?  
  default: `example.com`  
  gangan:

- Kí ni subdomain?  
  default: `app.`  
  gangan:

- Kí ni adirẹsi imeeli fún olumulo oníbàárà?  
  default: `user@example.com`  
  gangan:

- Níbo ni USB fún ìgbékalẹ̀ wà?  
  default: `/dev/sd1i`  
  gangan:

---

## Lilo Igbesẹ-si-Igbesẹ

### 1 — Pilẹṣẹ CA Gbongbo  *(ẹrọ CA laisi intanẹẹti, ẹẹkan)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Ṣẹda `/root/ca/`, ṣe agbejade bọtini gbongbo 4096-bit ti AES-256 fi pamọ, iwe-ẹri
ti ara rẹ fowo si ti o wulo fun ọdun 20, ati iwe-ẹri ibuwọlu OCSP fun CA gbongbo.

### 2 — Ṣẹda CA Aarin  *(ẹrọ CA laisi intanẹẹti, ẹẹkan fun iṣẹ-akanṣe kọọkan)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Awọn faili ni a ṣẹda labẹ `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Ṣe Agbejade Iwe-ẹri Olupin  *(ẹrọ CA laisi intanẹẹti)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Awọn abajade ni iwe ipamọ CA aarin:
- `private/app.example.com.01012027.key.pem` — bọtini ikọkọ ti o fi pamọ
- `certs/app.example.com.01012027.cert.pem` — iwe-ẹri ti a fowo si
- `certs/app.example.com.01012027.server.full.pfx` — ẹgbẹ PKCS#12

### 4 — Ṣe Agbejade Awọn Iwe-ẹri Onibara  *(ẹrọ CA laisi intanẹẹti)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Tun ṣe fun olumulo kọọkan. Gbe ẹgbẹ `.full.pfx` kọọkan si olumulo ti o yẹ
nipasẹ ikanni aabo.

### 5 — Fagile Iwe-ẹri  *(ẹrọ CA laisi intanẹẹti)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Lati tun ṣe CRL laisi fagile ohunkohun (fun apẹẹrẹ, lori iṣeto):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Gbigbe si Olupin OCSP nipasẹ USB  *(ṣiṣan iṣẹ ya sọtọ)*

#### Lori Ẹrọ CA Laisi Intanẹẹti

Fi USB ti a ṣeto FAT32 sii. Jẹrisi ẹrọ naa:

```sh
dmesg | tail -20          # wa fun awọn ila "sd1 at ..."
disklabel sd1             # damo ipin FAT32 (nigbagbogbo 'i')
```

Lẹhinna gbigba:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Iwe afọwọkọ kọ atokọ iye SHA256 ati yọ awakọ ni ailewu.
Gbe USB ni ara si ẹrọ olupin OCSP.

#### Lori Ẹrọ Olupin OCSP

```sh
dmesg | tail -20          # jẹrisi orukọ ẹrọ USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Iwe afọwọkọ ṣayẹwo awọn apao SHA256, daakọ awọn faili ti a ṣe imudojuiwọn si
`/etc/ocsp/`, ati tun gbé daemon `ocspserver` nipasẹ `rcctl`. Ti `EnableIndexTxtWatch`
ba jẹ `true` ni `appsettings.json`, olupin OCSP yoo tun gba awọn ayipada `index.txt`
laifọwọyi laisi atunṣe.

### 7 — Ṣayẹwo Awọn Idahun OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Awọn Ọna Lorukọ

| Faili | Awoṣe |
|-------|-------|
| Bọtini CA Aarin | `intermediate-PROJECT-DATE.key.pem` |
| Iwe-ẹri CA Aarin | `intermediate-PROJECT-DATE.cert.pem` |
| Ẹwọn Iwe-ẹri | `ca-chain-PROJECT-DATE.cert.pem` |
| Iwe-ẹri Olupin | `SERVER_DOMAIN.DATE.cert.pem` |
| Olupin PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Iwe-ẹri Onibara | `client-USER_EMAIL.DATE.cert.pem` |
| Onibara PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Iwe-ẹri Ibuwọlu OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Awọn Akọsilẹ Aabo

- Ẹrọ CA laisi intanẹẹti **ko gbọdọ jẹ sopọ si nẹtiwọọki rara**.
- Awọn bọtini ikọkọ gbongbo ati aarin ti wa ni ipamọ AES-256. Tọju awọn ọrọ-igbaniwọle
  ni aami ohun elo tabi ibi-itọju ti ara, ti o ya sọtọ kuro ninu awọn bọtini.
- Ṣayẹwo nigbagbogbo awọn apao USB ṣaaju gbigbe wọle — `import-from-usb.sh` ṣe eyi
  laifọwọyi pẹlu `sha256 -C` ti OpenBSD.
- Awọn CRL pari ni ọjọ 30 ni aiyipada. Ṣeto isọdọtun CRL deede:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # lẹhinna export-to-usb + import-from-usb
  ```
- Awọn iwe-ẹri ibuwọlu OCSP pari lẹhin ọjọ 375. Tun wọn ṣe nipa ṣiṣe
  `create-intermediate-ca.sh` pẹlu awọn ariyanjiyan kanna; awọn igbesẹ ti o ti pari
  ni a fo ati pe iwe-ẹri OCSP tuntun nikan ni a ṣẹda nigbati o nilo.
