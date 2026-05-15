# CAGenerationAndMaintenance

Nā palapala shell no ka hoʻohana ʻana i kahi **Hale Hōʻoia Palapala (CA) i kaʻawale
loa mai ka pūnaewele** ma OpenBSD me OpenSSL. Hōʻike ʻia ke kūlana hoʻopau ʻia ma
o kahi [OpenBSD OCSP Server](https://github.com/gladiola/OpenBSDOCSPServer) kaʻawale.
Hoʻoneʻe ʻia nā hoʻonui ʻana ma waena o ka mīkini CA kaʻawale a me ka mīkini kikowaena
OCSP ma o kahi lawe ʻikepili USB.

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

## Nānā Ākea i ke Kūkulu

```
┌─────────────────────────────┐        Lawe ʻikepili USB ┌──────────────────────────┐
│   Mīkini CA (kaʻawale)      │  ───────────────────►   │  Mīkini Kikowaena OCSP   │
│   (OpenBSD, kaʻawale loa)   │  export-to-usb.sh        │  (OpenBSD, pūnaewele)    │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  lawe kino               │  /etc/ocsp/              │
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

## Nā Koi Mua

Hoʻohana nā mīkini ʻelua i **OpenBSD**. E hoʻokomo i OpenSSL ke ʻole ia:

```sh
pkg_add openssl
```

Pono hoʻi ka mīkini kikowaena OCSP i ke
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) i hoʻokomo ʻia a
hoʻopaʻa ʻia ma ke ʻano he lawelawe rc.d i kapa ʻia `ocspserver`.

Hoʻohana nā palapala a pau i `#!/bin/sh` (ka `/bin/sh` kumu ksh o OpenBSD), nā
mea lawelawe maʻamau o OpenBSD (`mount_msdos`, `sha256`, `rcctl`, `doas`), a me
`openssl(1)`. E hoʻohana i nā palapala a pau ma ke ʻano he root ma o `doas`.

---

## Ka Hoʻolālā o nā Faila

```
scripts/
  setup-ca.sh               Hoʻomaka nā papa kuhikuhi CA kumu a hana i ke kī/palapala kumu
  create-intermediate-ca.sh Hana i kahi CA waena i pēpē ʻia e ka CA kumu
  create-server-cert.sh     Hoʻopuka i kahi palapala kikowaena TLS (mTLS)
  create-client-cert.sh     Hoʻopuka i kahi palapala mea kōkua (mTLS)
  revoke-cert.sh            Hoʻopau i kahi palapala a hana hou i ka CRL
  export-to-usb.sh          Hoʻopaʻa i nā ʻikepili CA ma USB no ke kaʻawale (ʻaoʻao CA)
  import-from-usb.sh        Lawe mai USB i ke kikowaena OCSP (ʻaoʻao kikowaena OCSP)

config/
  openssl-root.cnf.template          Kīʻaha hoʻonohonoho OpenSSL no ka CA kumu
  openssl-intermediate.cnf.template  Kīʻaha hoʻonohonoho OpenSSL no ka CA waena
```

---

## Hoʻolālā hoʻokuʻu (hoʻopiha i kēia ma mua o ka holo ʻana o nā script)

E hoʻomākaukau i nā waiwai hoʻokuʻu ma mua o ka holo ʻana i nā ʻanuʻu ma lalo nei:

- Aia i hea ka CA?  
  default: `/root/ca`  
  maoli:

- He aha ka hui a aia i hea?  
  default: `My Organization`  
  maoli:

- He aha ka inoa papahana?  
  default: `MY PROJECT`  
  maoli:

- I ka lā hea ka mana (version) o ka papahana?  
  default: `01012027`  
  maoli:

- He aha ka TLD?  
  default: `example.com`  
  maoli:

- He aha ka subdomain?  
  default: `app.`  
  maoli:

- He aha ka leka uila no ka mea hoʻohana mea kūʻai?  
  default: `user@example.com`  
  maoli:

- Aia i hea ka USB no ka hoʻoili?  
  default: `/dev/sd1i`  
  maoli:

---

## Nā ʻAlahele Hoʻohana

### 1 — Hoʻomaka i ka CA Kumu  *(mīkini CA kaʻawale, hoʻokahi manawa)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Hana ʻia `/root/ca/`, hana ʻia kahi kī kumu 4096-bit i hoʻopaʻa ʻia me AES-256,
kahi palapala i pēpē ʻia iā ia iho i kūpono no 20 makahiki, a me kahi palapala
pēpē OCSP no ka CA kumu.

### 2 — Hana i CA Waena  *(mīkini CA kaʻawale, hoʻokahi manawa no kēlā me kēia papahana)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Hana ʻia nā faila ma lalo o `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Hoʻopuka i Kahi Palapala Kikowaena  *(mīkini CA kaʻawale)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Nā mea i puka ʻia i loko o ka papa kuhikuhi CA waena:
- `private/app.example.com.01012027.key.pem` — kī pilikino i hoʻopaʻa ʻia
- `certs/app.example.com.01012027.cert.pem` — palapala i pēpē ʻia
- `certs/app.example.com.01012027.server.full.pfx` — pūʻolo PKCS#12

### 4 — Hoʻopuka i Nā Palapala Mea Kōkua  *(mīkini CA kaʻawale)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

E hoʻohana hou no kēlā me kēia mea hoʻohana. E lawe i kēlā me kēia pūʻolo `.full.pfx`
i ka mea hoʻohana kūpono ma o kahi ala palekana.

### 5 — Hoʻopau i Kahi Palapala  *(mīkini CA kaʻawale)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

E hōʻhou i ka CRL me ka hoʻopau ʻole ʻana (no ka laʻana, ma ka manawa koʻikoʻi):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Hoʻoneʻe i ke Kikowaena OCSP ma o USB  *(ka hana kaʻawale loa)*

#### Ma ka Mīkini CA Kaʻawale

E hoʻokomo i kahi lawe ʻikepili USB i hoʻonohonoho ʻia ma FAT32. E hōʻoia i ka hāmeʻa:

```sh
dmesg | tail -20          # e ʻimi i nā laina "sd1 at ..."
disklabel sd1             # e hoʻoiho i ka māhele FAT32 (maʻamau ʻo 'i')
```

A laila e lawe aku:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Kākau ka palapala i kahi papa inoa SHA256 a wehe palekana i ka lawe ʻikepili.
E lawe kino i ka lawe ʻikepili USB i ka mīkini kikowaena OCSP.

#### Ma ka Mīkini Kikowaena OCSP

```sh
dmesg | tail -20          # e hōʻoia i ka inoa hāmeʻa USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

E nānā ka palapala i nā helu SHA256, kope i nā faila i hoʻonui ʻia i `/etc/ocsp/`,
a hoʻohou i ka daemon `ocspserver` ma o `rcctl`. Inā ʻo `EnableIndexTxtWatch` he
`true` ma `appsettings.json`, e lawe hou hoʻi ke kikowaena OCSP i nā hoʻololi
`index.txt` ma ka ʻano aunoa me ka hoʻohou hou ʻole.

### 7 — E Hōʻoia i Nā Pane OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Nā ʻŌlelo Kūhelu Inoa

| Faila | Kīʻaha |
|-------|--------|
| Kī CA Waena | `intermediate-PROJECT-DATE.key.pem` |
| Palapala CA Waena | `intermediate-PROJECT-DATE.cert.pem` |
| Kaʻa Palapala | `ca-chain-PROJECT-DATE.cert.pem` |
| Palapala Kikowaena | `SERVER_DOMAIN.DATE.cert.pem` |
| PKCS#12 Kikowaena | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Palapala Mea Kōkua | `client-USER_EMAIL.DATE.cert.pem` |
| PKCS#12 Mea Kōkua | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Palapala Pēpē OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Nā ʻŌlelo Aʻo Palekana

- **ʻAʻole pono** e hoʻohui ka mīkini CA kaʻawale i kahi pūnaewele.
- Hoʻopaʻa ʻia nā kī pilikino kumu a waena me AES-256. E mālama i nā huaʻōlelo kahua
  ma kahi hāmeʻa pākahi a i ʻole kahi pahu palekana kino, kaʻawale mai nā kī.
- E hōʻoia mau i nā helu SHA256 o ka lawe ʻikepili USB ma mua o ka lawe ʻana mai —
  hana ʻia kēia ma ka ʻano aunoa e `import-from-usb.sh` me `sha256 -C` o OpenBSD.
- Pau ka CRL ma hope o 30 lā ma ka mea paʻamau. E hoʻonohonoho i ka hōʻhou ʻana
  mau i ka CRL:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # a laila export-to-usb + import-from-usb
  ```
- Pau nā palapala pēpē OCSP ma hope o 375 lā. E hōʻhou iā lākou ma ka hoʻohana hou
  ʻana i `create-intermediate-ca.sh` me nā helu like; e lele ʻia nā ʻalahele i
  hoʻokō mua ʻia a hana ʻia kahi palapala OCSP hou wale nō ke pono.
