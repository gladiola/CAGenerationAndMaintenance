# CAGenerationAndMaintenance

Skript shell pou opere yon **Otorite Sètifika (CA) ki pa konekte epi izole nan lè**
sou OpenBSD avèk OpenSSL. Estati revokasyon an pibliye atravè yon sèvè
[OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer) separe.
Mizajou yo transfere ant machin CA pa konekte a ak machin sèvè OCSP la pa mwayen
yon disque USB.

---

## Planifikasyon deplwaman (ranpli sa anvan ou kouri scripts yo)

Prepare valè deplwaman ou yo anvan ou kouri etap ki anba yo:

- Ki kote CA a pral ye?  
  default: `/root/ca`  
  aktyèl:

- Ki òganizasyon an ye e ki kote li ye?  
  default: `My Organization`  
  aktyèl:

- Ki non pwojè a?  
  default: `MY PROJECT`  
  aktyèl:

- Ki dat vèsyon pwojè a?  
  default: `01012027`  
  aktyèl:

- Ki TLD la?  
  default: `example.com`  
  aktyèl:

- Ki sou-domèn nan?  
  default: `app.`  
  aktyèl:

- Ki adrès imel pou itilizatè kliyan an/yo?  
  default: `user@example.com`  
  aktyèl:

- Ki kote kle USB pou transfè a ye?  
  default: `/dev/sd1i`  
  aktyèl:

---

## Rezime Achitekti

```
┌─────────────────────────────┐        Disque USB       ┌──────────────────────────┐
│   Machin CA (pa konekte)    │  ───────────────────►   │  Machin Sèvè OCSP        │
│   (OpenBSD, izole nan lè)   │  export-to-usb.sh        │  (OpenBSD, nan rezo)     │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  pote fizikman          │  /etc/ocsp/              │
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

## Kondisyon Preliminè

De machin yo itilize **OpenBSD**. Enstale OpenSSL si li pa la deja:

```sh
pkg_add openssl
```

Machin sèvè OCSP la bezwen tou
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) enstale epi
anrejistre kòm sèvis rc.d ki rele `ocspserver`.

Tout skript yo itilize `#!/bin/sh` (OpenBSD `/bin/sh` ki baze sou ksh), itilitè
OpenBSD estanda (`mount_msdos`, `sha256`, `rcctl`, `doas`), ak `openssl(1)`.
Kouri tout skript yo kòm root via `doas`.

---

## Dispozisyon Fichye

```
scripts/
  setup-ca.sh               Inisyalize rekatab CA rasin yo epi jenere kle/sètifika rasin
  create-intermediate-ca.sh Kreye yon CA entèmedyè siyen pa CA rasin
  create-server-cert.sh     Pibliye yon sètifika sèvè TLS (mTLS)
  create-client-cert.sh     Pibliye yon sètifika kliyan (mTLS)
  revoke-cert.sh            Revoke yon sètifika epi rejennere CRL la
  export-to-usb.sh          Pakèt done CA sou USB pou transfè izole nan lè (bò CA)
  import-from-usb.sh        Enpòte soti USB nan sèvè OCSP la (bò sèvè OCSP)

config/
  openssl-root.cnf.template          Modèl konfigirasyon OpenSSL pou CA rasin
  openssl-intermediate.cnf.template  Modèl konfigirasyon OpenSSL pou CA entèmedyè
```

---

## Itilizasyon Etap pa Etap

### 1 — Inisyalize CA Rasin  *(machin CA pa konekte, yon fwa)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Kreye `/root/ca/`, jenere yon kle rasin 4096-bit chifre AES-256, yon sètifika
otosine valab 20 an, ak yon sètifika siyen OCSP pou CA rasin la.

### 2 — Kreye yon CA Entèmedyè  *(machin CA pa konekte, yon fwa pou chak pwojè)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Fichye yo kreye anba `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Pibliye yon Sètifika Sèvè  *(machin CA pa konekte)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Rezilta nan rekatab CA entèmedyè a:
- `private/app.example.com.01012027.key.pem` — kle prive chifre
- `certs/app.example.com.01012027.cert.pem` — sètifika siyen
- `certs/app.example.com.01012027.server.full.pfx` — pakèt PKCS#12

### 4 — Pibliye Sètifika Kliyan  *(machin CA pa konekte)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Repete pou chak itilizatè. Transfere chak pakèt `.full.pfx` bay itilizatè ki
responsab la atravè yon kanal sekirize.

### 5 — Revoke yon Sètifika  *(machin CA pa konekte)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Pou renouvle CRL la san revoke anyen (pa egzanp, chak semèn):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Transfè nan Sèvè OCSP via USB  *(pwosesis izolasyon lè)*

#### Sou Machin CA Pa Konekte

Mete yon disque USB ki fòmate FAT32. Konfime aparèy la:

```sh
dmesg | tail -20          # chèche liy "sd1 at ..."
disklabel sd1             # idantifye pati FAT32 (anjeneral 'i')
```

Apre sa ekspòte:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Skript la ekri yon manifès chèksom `SHA256` epi dekonekte disque a an sekirite.
Pote disque USB la fizikman nan machin sèvè OCSP la.

#### Sou Machin Sèvè OCSP

```sh
dmesg | tail -20          # konfime non aparèy USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Skript la verifye chèksom yo, kopye fichye mizajou yo nan `/etc/ocsp/`, epi
rechaje demon `ocspserver` la via `rcctl`. Si `EnableIndexTxtWatch` se `true`
nan `appsettings.json`, sèvè OCSP la pral ranmase chanjman `index.txt` otomatikman
san rechajman.

### 7 — Verifye Repons OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Konvansyon Non

| Fichye | Modèl |
|--------|-------|
| Kle CA entèmedyè | `intermediate-PROJECT-DATE.key.pem` |
| Sètifika CA entèmedyè | `intermediate-PROJECT-DATE.cert.pem` |
| Chenn sètifika | `ca-chain-PROJECT-DATE.cert.pem` |
| Sètifika sèvè | `SERVER_DOMAIN.DATE.cert.pem` |
| PKCS#12 sèvè | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Sètifika kliyan | `client-USER_EMAIL.DATE.cert.pem` |
| PKCS#12 kliyan | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Sètifika siyen OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Nòt Sekirite

- Machin CA pa konekte a **pa dwe janm konekte nan yon rezo**.
- Kle prive rasin ak entèmedyè yo chifre AES-256. Estoke frazmot yo nan yon
  jeton materyèl oswa yon kofrefò fizik, apa de kle yo.
- Toujou verifye chèksom disque USB anvan enpòtasyon — `import-from-usb.sh`
  fè sa otomatikman ak `sha256 -C` OpenBSD.
- CRL yo ekspire apre 30 jou pa defò. Pwograme renouvèlman CRL regilye:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # apre sa export-to-usb + import-from-usb
  ```
- Sètifika siyen OCSP yo ekspire apre 375 jou. Renouvle yo lè ou relanse
  `create-intermediate-ca.sh` avèk menm agiman yo; etap ki deja fini yo pral
  sote epi yon nouvo sètifika OCSP jenere sèlman lè nesesè.
