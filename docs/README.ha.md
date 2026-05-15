# CAGenerationAndMaintenance

Rubututtukan shell don gudanar da **Hukumar Takardar Shaidar (CA) mara hanyar sadarwa
kuma keɓantacciya** akan OpenBSD ta amfani da OpenSSL. Ana buga matsayin soke ta
hanyar [OpenBSD OCSP Server](https://github.com/gladiola/OpenBSDOCSPServer) daban.
Ana canja wurin sabuntawa tsakanin injin CA mara sadarwa da injin sabar OCSP ta
hanyar USB.

---

## Tsarin shiryawa na tura aiki (cika wannan kafin gudanar da rubutun)

Shirya ƙimomin turawa kafin ka gudanar da matakan da ke ƙasa:

- Ina za a ajiye CA?  
  default: `/root/ca`  
  ainihi:

- Menene ƙungiya kuma ina take?  
  default: `My Organization`  
  ainihi:

- Menene sunan aikin?  
  default: `MY PROJECT`  
  ainihi:

- Yaushe ake yin sigar aikin?  
  default: `01012027`  
  ainihi:

- Menene TLD?  
  default: `example.com`  
  ainihi:

- Menene subdomain?  
  default: `app.`  
  ainihi:

- Menene adireshin imel na mai amfani da abokin ciniki?  
  default: `user@example.com`  
  ainihi:

- Ina kebul ɗin USB na canja wuri yake?  
  default: `/dev/sd1i`  
  ainihi:

---

## Taƙaitacciyar Tsarin Gine-ginen

```
┌─────────────────────────────┐        USB Drive        ┌──────────────────────────┐
│   Injin CA (mara sadarwa)   │  ───────────────────►   │  Injin Sabar OCSP        │
│   (OpenBSD, keɓantacce)     │  export-to-usb.sh        │  (OpenBSD, a cibiyar)    │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  ɗaukar jiki             │  /etc/ocsp/              │
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

## Sharuɗɗan Farko

Injuna biyu suna gudana akan **OpenBSD**. Saka OpenSSL idan bai nan ba:

```sh
pkg_add openssl
```

Injin sabar OCSP kuma yana buƙatar
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) da aka saka kuma
aka yi rajista a matsayin sabis rc.d mai suna `ocspserver`.

Duk rubututtukan sun yi amfani da `#!/bin/sh` (OpenBSD `/bin/sh` mai tushen ksh),
kayan aikin OpenBSD na al'ada (`mount_msdos`, `sha256`, `rcctl`, `doas`), da
`openssl(1)`. Gudanar da duk rubututtukan a matsayin root ta hanyar `doas`.

---

## Tsarin Fayiloli

```
scripts/
  setup-ca.sh               Fara directories na CA tushe kuma ƙirƙiri maɓalli/takardar shaida ta tushe
  create-intermediate-ca.sh Ƙirƙiri CA ta tsakiya wanda CA tushe ya sanya hannu
  create-server-cert.sh     Fitar da takardar shaida ta sabar TLS (mTLS)
  create-client-cert.sh     Fitar da takardar shaida ta mai amfani (mTLS)
  revoke-cert.sh            Soke takardar shaida kuma sake ƙirƙirar CRL
  export-to-usb.sh          Kulle bayanan CA akan USB don canja wurin keɓance (gefen CA)
  import-from-usb.sh        Shigo da daga USB zuwa sabar OCSP (gefen sabar OCSP)

config/
  openssl-root.cnf.template          Samfuri na tsarin OpenSSL na CA tushe
  openssl-intermediate.cnf.template  Samfuri na tsarin OpenSSL na CA ta tsakiya
```

---

## Amfani Mataki zuwa Mataki

### 1 — Fara CA Tushe  *(injin CA mara sadarwa, sau ɗaya)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Yana ƙirƙirar `/root/ca/`, yana ƙirƙirar maɓalli na tushe na bit 4096 da AES-256 ya
kare, takardar shaida da ta sanya wa kanta hannu mai inganci tsawon shekaru 20, da
takardar shaida ta sa hannu ta OCSP don CA tushe.

### 2 — Ƙirƙiri CA ta Tsakiya  *(injin CA mara sadarwa, sau ɗaya kowace shiri)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Ana ƙirƙirar fayiloli ƙarƙashin `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Fitar da Takardar Shaida ta Sabar  *(injin CA mara sadarwa)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Fitarwa a cikin directory CA ta tsakiya:
- `private/app.example.com.01012027.key.pem` — maɓalli na sirri da aka kare
- `certs/app.example.com.01012027.cert.pem` — takardar shaida da aka sanya hannu
- `certs/app.example.com.01012027.server.full.pfx` — kulle PKCS#12

### 4 — Fitar da Takardun Shaida na Mai Amfani  *(injin CA mara sadarwa)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Maimaita don kowace mai amfani. Canja kulle kowane `.full.pfx` ga mai amfani da ya
dace ta hanyar tashar aminci.

### 5 — Soke Takardar Shaida  *(injin CA mara sadarwa)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Don sabunta CRL ba tare da soke komai ba (misali, akan jadawali):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Canja zuwa Sabar OCSP ta USB  *(aikin keɓance)*

#### Akan Injin CA Mara Sadarwa

Saka USB da aka tsara ta FAT32. Tabbatar da na'urar:

```sh
dmesg | tail -20          # nemi layin "sd1 at ..."
disklabel sd1             # gano bangaren FAT32 (yawanci 'i')
```

Sannan fitar:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Rubutun yana rubuta takarda ta tsarin SHA256 kuma yana cire na'ura da aminci.
Ɗauki USB jiki zuwa injin sabar OCSP.

#### Akan Injin Sabar OCSP

```sh
dmesg | tail -20          # tabbatar da sunan na'urar USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Rubutun yana tabbatar da tsarin SHA256, yana kwafe fayilolin da aka sabunta zuwa
`/etc/ocsp/`, kuma yana sake loda daemon `ocspserver` ta `rcctl`. Idan
`EnableIndexTxtWatch` shine `true` a cikin `appsettings.json`, sabar OCSP kuma za ta
ɗauki canje-canje na `index.txt` ta atomatik ba tare da sake loda ba.

### 7 — Tabbatar da Amsoshin OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Al'adun Suna

| Fayil | Tsari |
|-------|-------|
| Maɓalli CA ta Tsakiya | `intermediate-PROJECT-DATE.key.pem` |
| Takardar Shaida CA ta Tsakiya | `intermediate-PROJECT-DATE.cert.pem` |
| Sarkar Takardun Shaida | `ca-chain-PROJECT-DATE.cert.pem` |
| Takardar Shaida ta Sabar | `SERVER_DOMAIN.DATE.cert.pem` |
| Sabar PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Takardar Shaida ta Mai Amfani | `client-USER_EMAIL.DATE.cert.pem` |
| Mai Amfani PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Takardar Shaida ta Sa Hannu OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Bayanan Tsaro

- Injin CA mara sadarwa **bai kamata a haɗa shi da cibiyar sadarwa ba**.
- Ana kare maɓallan sirri na tushe da tsakiya da AES-256. Adana kalmomin sirri a cikin
  token na hardware ko akwatin ƙarfe na jiki, daban da maɓallan.
- Koyaushe tabbatar da tsarin USB kafin shigo da — `import-from-usb.sh` yana yin haka
  ta atomatik ta amfani da `sha256 -C` na OpenBSD.
- CRL suna ƙarewa bayan kwanaki 30 ta tsoho. Shirya sabuntawar CRL na yau da kullun:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # sannan export-to-usb + import-from-usb
  ```
- Takardun shaida ta sa hannu na OCSP suna ƙarewa bayan kwanaki 375. Sabunta su ta
  sake gudanar da `create-intermediate-ca.sh` da irin waɗancan muhawara; ana tsallake
  matakai da aka riga aka kammala kuma ana ƙirƙirar sabon takardar shaida ta OCSP
  kawai idan ya cancanta.
