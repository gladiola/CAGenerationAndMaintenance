# CAGenerationAndMaintenance

Mga shell script para sa pagpapatakbo ng isang **offline, air-gapped na Awtoridad sa
Sertipiko (CA)** sa OpenBSD gamit ang OpenSSL. Ang katayuan ng pagkabigo ay inilalathala
sa pamamagitan ng isang hiwalay na
[OpenBSD OCSP server](https://github.com/gladiola/OpenBSDOCSPServer).
Ang mga update ay inililipat sa pagitan ng offline na makina ng CA at ng makina ng OCSP
server sa pamamagitan ng USB drive.

---

## Pangkalahatang-ideya ng Arkitektura

```
┌─────────────────────────────┐        USB Drive        ┌──────────────────────────┐
│   Offline na Makina ng CA   │  ───────────────────►   │  Makina ng OCSP Server   │
│   (OpenBSD, air-gapped)     │  export-to-usb.sh        │  (OpenBSD, nakakonekta)  │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  pisikal na pagdadala    │  /etc/ocsp/              │
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

## Mga Paunang Kinakailangan

Ang parehong makina ay nagpapatakbo ng **OpenBSD**. I-install ang OpenSSL kung wala pa:

```sh
pkg_add openssl
```

Ang makina ng OCSP server ay nangangailangan din ng
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) na naka-install at
nakarehistro bilang serbisyo ng rc.d na pinangalanang `ocspserver`.

Lahat ng script ay gumagamit ng `#!/bin/sh` (OpenBSD na ksh-based na `/bin/sh`), mga
karaniwang kagamitan ng OpenBSD (`mount_msdos`, `sha256`, `rcctl`, `doas`), at
`openssl(1)`. Patakbuhin ang lahat ng script bilang root sa pamamagitan ng `doas`.

---

## Layout ng File

```
scripts/
  setup-ca.sh               Sinisimulan ang mga direktoryo ng root CA at lumilikha ng root key/sertipiko
  create-intermediate-ca.sh Lumilikha ng pinangalanang intermediate CA na nilagdaan ng root CA
  create-server-cert.sh     Naglalabas ng TLS server certificate (mTLS)
  create-client-cert.sh     Naglalabas ng client certificate (mTLS)
  revoke-cert.sh            Binabago ang sertipiko at binubuo muli ang CRL
  export-to-usb.sh          Nagpapahinto ng CA data sa USB para sa paglipat ng air-gap (CA side)
  import-from-usb.sh        Nag-iimport mula sa USB patungo sa OCSP server (OCSP server side)

config/
  openssl-root.cnf.template          Template ng OpenSSL configuration para sa root CA
  openssl-intermediate.cnf.template  Template ng OpenSSL configuration para sa intermediate CA
```

---

## Pagpaplano ng deployment (punan ito bago patakbuhin ang mga script)

Ihanda ang iyong mga deployment value bago patakbuhin ang mga hakbang sa ibaba:

- Saan ilalagay ang CA?  
  default: `/root/ca`  
  aktuwal:

- Ano ang organisasyon at nasaan ito?  
  default: `My Organization`  
  aktuwal:

- Ano ang pangalan ng proyekto?  
  default: `MY PROJECT`  
  aktuwal:

- Ano ang petsa ng bersyon ng proyekto?  
  default: `01012027`  
  aktuwal:

- Ano ang TLD?  
  default: `example.com`  
  aktuwal:

- Ano ang subdomain?  
  default: `app.`  
  aktuwal:

- Ano ang email address ng (mga) client user?  
  default: `user@example.com`  
  aktuwal:

- Nasaan ang USB thumb drive para sa paglilipat?  
  default: `/dev/sd1i`  
  aktuwal:

---

## Hakbang-hakbang na Paggamit

### 1 — Simulan ang Root CA  *(offline na makina ng CA, isang beses)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Lumilikha ng `/root/ca/`, gumagawa ng AES-256-encrypted na 4096-bit na root key,
isang self-signed certificate na may bisa sa loob ng 20 taon, at isang OCSP signing
certificate para sa root CA.

### 2 — Lumikha ng Intermediate CA  *(offline na makina ng CA, isang beses bawat proyekto)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Ang mga file ay nililikha sa ilalim ng `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Maglabas ng Server Certificate  *(offline na makina ng CA)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Mga output sa direktoryo ng intermediate CA:
- `private/app.example.com.01012027.key.pem` — naka-encrypt na private key
- `certs/app.example.com.01012027.cert.pem` — nilagdaang sertipiko
- `certs/app.example.com.01012027.server.full.pfx` — bundle ng PKCS#12

### 4 — Maglabas ng Mga Client Certificate  *(offline na makina ng CA)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Ulitin para sa bawat gumagamit. Ilipat ang bawat `.full.pfx` bundle sa kaukulang
gumagamit sa pamamagitan ng isang secure na channel.

### 5 — Baguhin ang Sertipiko  *(offline na makina ng CA)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Para i-renew ang CRL nang hindi binabago ang anuman (hal. ayon sa iskedyul):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Paglilipat sa OCSP Server sa pamamagitan ng USB  *(air-gap na daloy ng trabaho)*

#### Sa Offline na Makina ng CA

Ipasok ang isang FAT32-formatted na USB drive. Kumpirmahin ang device:

```sh
dmesg | tail -20          # hanapin ang mga linya na "sd1 at ..."
disklabel sd1             # tukuyin ang partisyon ng FAT32 (karaniwang 'i')
```

Pagkatapos i-export:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Sinusulat ng script ang isang `SHA256` checksum manifest at ligtas na dini-dismount ang
drive. Dalhin nang pisikal ang USB drive sa makina ng OCSP server.

#### Sa Makina ng OCSP Server

```sh
dmesg | tail -20          # kumpirmahin ang pangalan ng USB device
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Bine-verify ng script ang mga checksum, kinokopya ang mga na-update na file sa
`/etc/ocsp/`, at muling nino-load ang `ocspserver` daemon sa pamamagitan ng `rcctl`.
Kung ang `EnableIndexTxtWatch` ay `true` sa `appsettings.json`, ang OCSP server ay
awtomatiko ring kukuha ng mga pagbabago sa `index.txt` nang walang reload.

### 7 — I-verify ang Mga Tugon ng OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Mga Kumbensyon sa Pagpapangalan

| File | Pattern |
|------|---------|
| Intermediate CA Key | `intermediate-PROJECT-DATE.key.pem` |
| Intermediate CA Certificate | `intermediate-PROJECT-DATE.cert.pem` |
| Certificate Chain | `ca-chain-PROJECT-DATE.cert.pem` |
| Server Certificate | `SERVER_DOMAIN.DATE.cert.pem` |
| Server PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Client Certificate | `client-USER_EMAIL.DATE.cert.pem` |
| Client PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| OCSP Signing Certificate | `INTER_NAME-ocsp.cert.pem` |

---

## Mga Tala sa Seguridad

- Ang offline na makina ng CA ay **hindi dapat ikonekta sa isang network**.
- Ang mga private key ng root at intermediate ay naka-encrypt ng AES-256. Iimbak ang
  mga passphrase sa isang hardware token o pisikal na vault, hiwalay sa mga key.
- Palaging i-verify ang mga checksum ng USB drive bago mag-import — ginagawa ito ng
  `import-from-usb.sh` awtomatiko gamit ang `sha256 -C` ng OpenBSD.
- Ang mga CRL ay nag-eexpire pagkatapos ng 30 araw bilang default. Mag-iskedyul ng
  regular na pag-renew ng CRL:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # pagkatapos ay export-to-usb + import-from-usb
  ```
- Ang mga OCSP signing certificate ay nag-eexpire pagkatapos ng 375 araw. I-renew ang
  mga ito sa pamamagitan ng muling pagpapatakbo ng `create-intermediate-ca.sh` gamit
  ang parehong mga argumento; ang mga natapos nang hakbang ay nilalaktawan at ang isang
  bagong OCSP certificate lamang ang nalilikha kapag kinakailangan.
