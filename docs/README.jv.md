# CAGenerationAndMaintenance

Skrip shell kanggo ngoperasikaké **Otoritas Sertifikat (CA) sing ora nyambung internet
lan terisolasi sacara fisik** ing OpenBSD nganggo OpenSSL. Status pencabutan diterbitaké
liwat [server OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer) sing kapisah.
Pembaruan dipindhah antarané mesin CA offline lan mesin server OCSP liwat drive USB.

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

## Gambaran Arsitektur

```
┌─────────────────────────────┐        Drive USB         ┌──────────────────────────┐
│   Mesin CA offline          │  ───────────────────►    │  Mesin Server OCSP       │
│   (OpenBSD, terisolasi)     │  export-to-usb.sh         │  (OpenBSD, nyambung)     │
│                             │  ◄────────────────────   │                          │
│  /root/ca/                  │  pangiriman fisik         │  /etc/ocsp/              │
│    openssl.cnf              │                           │    index.txt             │
│    certs/ca.cert.pem        │                           │    *.crl.pem             │
│    intermediate-*/          │                           │    *-responder.crt       │
│      index.txt              │                           │  OcspServer (ASP.NET)    │
│      crl/                   │                           │  rcctl enable ocspserver │
│      certs/                 │                           │                          │
│      ocsp/                  │                           │                          │
└─────────────────────────────┘                           └──────────────────────────┘
```

---

## Syarat-Syarat Awal

Loro-loroné mesin nganggo **OpenBSD**. Pasang OpenSSL yen durung ana:

```sh
pkg_add openssl
```

Mesin server OCSP uga butuh
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) sing dipasang lan
didaftaraké minangka layanan rc.d sing dijenengi `ocspserver`.

Kabeh skrip nganggo `#!/bin/sh` (OpenBSD `/bin/sh` berbasis ksh), utilitas standar
OpenBSD (`mount_msdos`, `sha256`, `rcctl`, `doas`), lan `openssl(1)`. Lakokna kabeh
skrip minangka root liwat `doas`.

---

## Tata Letak File

```
scripts/
  setup-ca.sh               Ngiseni direktori CA root lan nggawe kunci/sertifikat root
  create-intermediate-ca.sh Nggawe CA perantara sing ditandatangani CA root
  create-server-cert.sh     Ngetokne sertifikat server TLS (mTLS)
  create-client-cert.sh     Ngetokne sertifikat klien (mTLS)
  revoke-cert.sh            Mbatalake sertifikat lan mbangun ulang CRL
  export-to-usb.sh          Ngemas data CA menyang USB kanggo transfer terisolasi (sisi CA)
  import-from-usb.sh        Ngimpor saka USB menyang server OCSP (sisi server OCSP)

config/
  openssl-root.cnf.template          Template konfigurasi OpenSSL kanggo CA root
  openssl-intermediate.cnf.template  Template konfigurasi OpenSSL kanggo CA perantara
```

---

## Rencana deployment (isi iki sadurunge mbukak skrip)

Siapna nilai deployment sadurunge mbukak langkah-langkah ing ngisor iki:

- CA arep disimpen ing endi?  
  default: `/root/ca`  
  nyata:

- Apa jeneng organisasi lan dununge ing endi?  
  default: `My Organization`  
  nyata:

- Apa jeneng proyeke?  
  default: `MY PROJECT`  
  nyata:

- Tanggal versi proyek kapan?  
  default: `01012027`  
  nyata:

- Apa TLD-e?  
  default: `example.com`  
  nyata:

- Apa subdomain-e?  
  default: `app.`  
  nyata:

- Apa alamat email kanggo pangguna klien?  
  default: `user@example.com`  
  nyata:

- USB kanggo transfer ana ing endi?  
  default: `/dev/sd1i`  
  nyata:

---

## Cara Nggunakake Setahap demi Setahap

### 1 — Iseni CA Root  *(mesin CA offline, sapisan)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Nggawe `/root/ca/`, nggawe kunci root 4096-bit sing dienkripsi AES-256, sertifikat
sing ditandatangani dhewe sing sah 20 taun, lan sertifikat penandatangan OCSP kanggo
CA root.

### 2 — Gawe CA Perantara  *(mesin CA offline, sapisan saben proyek)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

File digawe ing ngisor `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Ngetokne Sertifikat Server  *(mesin CA offline)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Output ing direktori CA perantara:
- `private/app.example.com.01012027.key.pem` — kunci pribadi sing dienkripsi
- `certs/app.example.com.01012027.cert.pem` — sertifikat sing ditandatangani
- `certs/app.example.com.01012027.server.full.pfx` — paket PKCS#12

### 4 — Ngetokne Sertifikat Klien  *(mesin CA offline)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Baleni kanggo saben pangguna. Transfer saben paket `.full.pfx` menyang pangguna sing
cocog liwat saluran sing aman.

### 5 — Mbatalake Sertifikat  *(mesin CA offline)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Kanggo nganyari CRL tanpa mbatalake apa-apa (contohé miturut jadwal):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Transfer menyang Server OCSP liwat USB  *(alur kerja terisolasi)*

#### Ing Mesin CA Offline

Lebokna drive USB sing diformat FAT32. Konfirmasi piranti:

```sh
dmesg | tail -20          # goleki baris "sd1 at ..."
disklabel sd1             # identifikasi partisi FAT32 (biasané 'i')
```

Banjur ekspor:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Skrip nulis manifes checksum SHA256 lan ngunmount drive kanthi aman.
Gawa drive USB kanthi fisik menyang mesin server OCSP.

#### Ing Mesin Server OCSP

```sh
dmesg | tail -20          # konfirmasi jeneng piranti USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Skrip mverifikasi checksum, nyalin file sing diperbarui menyang `/etc/ocsp/`, lan
muat ulang daemon `ocspserver` liwat `rcctl`. Yen `EnableIndexTxtWatch` iku `true`
ing `appsettings.json`, server OCSP uga bakal njupuk owahan `index.txt` kanthi
otomatis tanpa muat ulang.

### 7 — Verifikasi Respons OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Konvensi Penamaan

| File | Pola |
|------|------|
| Kunci CA Perantara | `intermediate-PROJECT-DATE.key.pem` |
| Sertifikat CA Perantara | `intermediate-PROJECT-DATE.cert.pem` |
| Rantai Sertifikat | `ca-chain-PROJECT-DATE.cert.pem` |
| Sertifikat Server | `SERVER_DOMAIN.DATE.cert.pem` |
| Server PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Sertifikat Klien | `client-USER_EMAIL.DATE.cert.pem` |
| Klien PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Sertifikat Penandatangan OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Cathetan Keamanan

- Mesin CA offline **ora kena nyambung menyang jaringan apa wae**.
- Kunci pribadi root lan perantara dienkripsi AES-256. Simpen kata sandi ing token
  hardware utawa brankas fisik, kapisah saka kunci.
- Tansah verifikasi checksum drive USB sadurunge ngimpor — `import-from-usb.sh`
  nindakake iki kanthi otomatis nganggo `sha256 -C` OpenBSD.
- CRL kadaluarsa sawise 30 dina minangka default. Jadwalake pembaruan CRL kanthi
  rutin:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # banjur export-to-usb + import-from-usb
  ```
- Sertifikat penandatangan OCSP kadaluarsa sawise 375 dina. Nganyarake kanthi
  nglakokne `create-intermediate-ca.sh` maneh nganggo argumen sing padha; langkah
  sing wis rampung dilompati lan sertifikat OCSP anyar mung digawe yen perlu.
