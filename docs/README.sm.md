# CAGenerationAndMaintenance

O tusitusiga shell mo le fa'agaioia o se **Fa'amalosia o Tusi Faamaonia (CA) e
fa'ate'a mai le initaneti ma le ea** i luga o OpenBSD fa'aaoga OpenSSL. O le tulaga
o le fa'ate'aina e lolomiina e ala i se [OpenBSD OCSP Server](https://github.com/gladiola/OpenBSDOCSPServer)
tu'usa'o. O fa'afouina e fe'au'au'a i le va o le masini CA e fa'ate'a ai ma le masini
o le OCSP server e ala i se fu'a USB.

---

## Fuafuaga o le deployment (faatumu lenei mea aʻo leʻi tamoʻe scripts)

Saunia au tau deployment aʻo leʻi tamoʻe laasaga o loo i lalo:

- O fea o le a iai le CA?  
  default: `/root/ca`  
  moni:

- O le ā le faalapotopotoga ma o fea e iai?  
  default: `My Organization`  
  moni:

- O le ā le igoa o le poloketi?  
  default: `MY PROJECT`  
  moni:

- O afea le aso version o le poloketi?  
  default: `01012027`  
  moni:

- O le ā le TLD?  
  default: `example.com`  
  moni:

- O le ā le subdomain?  
  default: `app.`  
  moni:

- O le ā le imeli mo tagata faaaoga a le client?  
  default: `user@example.com`  
  moni:

- O fea le USB mo le fesiitaiga?  
  default: `/dev/sd1i`  
  moni:

---

## Faamatalaga o le Fausaga

```
┌─────────────────────────────┐        Fu'a USB          ┌──────────────────────────┐
│   Masini CA (fa'ate'a)      │  ───────────────────►   │  Masini OCSP Server      │
│   (OpenBSD, fa'ate'a ea)    │  export-to-usb.sh        │  (OpenBSD, feso'ota'i)   │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  ave faaletino           │  /etc/ocsp/              │
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

## Mea Manaomia

E fa'aogaina masini uma **OpenBSD**. Fa'apipi'i OpenSSL afai e le'i i ai:

```sh
pkg_add openssl
```

E manaomia fo'i e le masini OCSP server le
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) na fa'apipi'i ma
fa'amaonia o se tautua rc.d e ta'ua `ocspserver`.

E fa'aogaina tusitusiga uma `#!/bin/sh` (OpenBSD `/bin/sh` e fa'atatau i ksh), mea
galuega masani OpenBSD (`mount_msdos`, `sha256`, `rcctl`, `doas`), ma `openssl(1)`.
Fa'agasolo tusitusiga uma o le a root e ala i `doas`.

---

## Fa'atulagaina o Faila

```
scripts/
  setup-ca.sh               Fa'amalo fa'atonuga CA a'mata ma gaosia le ki/tusi faamaonia a'mata
  create-intermediate-ca.sh Fai se CA vaeluagalemu ua sainia e le CA a'mata
  create-server-cert.sh     Tu'uina atu se tusi faamaonia o le TLS server (mTLS)
  create-client-cert.sh     Tu'uina atu se tusi faamaonia o le tagata fa'aogaina (mTLS)
  revoke-cert.sh            Fa'ate'a se tusi faamaonia ma toe gaosia le CRL
  export-to-usb.sh          Fa'apotopoto fa'amaumauga CA i USB mo fe'au'au'a fa'ate'a ea (itu CA)
  import-from-usb.sh        Fa'aulufale mai USB i le OCSP server (itu OCSP server)

config/
  openssl-root.cnf.template          Fa'ata'ita'i fa'atulagaina OpenSSL mo CA a'mata
  openssl-intermediate.cnf.template  Fa'ata'ita'i fa'atulagaina OpenSSL mo CA vaeluagalemu
```

---

## Fa'aogaina Laasaga i Laasaga

### 1 — Fa'amalo le CA A'mata  *(masini CA fa'ate'a, o le tasi taimi)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Fausia `/root/ca/`, gaosia se ki a'mata e 4096-bit ua fa'aoga AES-256, se tusi
faamaonia sainia e ia lava e aoga mo le 20 tausaga, ma se tusi faamaonia sainia OCSP
mo le CA a'mata.

### 2 — Fai se CA Vaeluagalemu  *(masini CA fa'ate'a, o le tasi taimi mo poloketi ta'itasi)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

O faila e faia i lalo o `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Tu'uina Atu se Tusi Faamaonia Server  *(masini CA fa'ate'a)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Fa'ao'o i le fa'atonuga CA vaeluagalemu:
- `private/app.example.com.01012027.key.pem` — ki tumu ua fa'ailoga fa'aulufale
- `certs/app.example.com.01012027.cert.pem` — tusi faamaonia ua sainia
- `certs/app.example.com.01012027.server.full.pfx` — fa'apotopotoga PKCS#12

### 4 — Tu'uina Atu Tusi Faamaonia Tagata Fa'aogaina  *(masini CA fa'ate'a)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Toe fai mo tagata fa'aogaina ta'itasi. Feaveai fa'apotopotoga `.full.pfx` ta'itasi i
le tagata fa'aogaina e fetaui ai e ala i se auala saogalemu.

### 5 — Fa'ate'a se Tusi Faamaonia  *(masini CA fa'ate'a)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Fa'afou le CRL e aunoa ma le fa'ate'aina (e.g. i luga o se fa'atulaga):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Feaveai i le OCSP Server e ala i USB  *(faiga galuega fa'ate'a ea)*

#### I le Masini CA Fa'ate'a

Fa'aulufale se fu'a USB ua fa'atulatulagaina FAT32. Fa'amaonia le masini:

```sh
dmesg | tail -20          # su'e laina "sd1 at ..."
disklabel sd1             # iloa le vaega FAT32 (masanini 'i')
```

Ona ave ese ai lea:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Tusia e le tusitusiga se lisi SHA256 ma aveese le fu'a saogalemu.
Ave faaletino le fu'a USB i le masini OCSP server.

#### I le Masini OCSP Server

```sh
dmesg | tail -20          # fa'amaonia le igoa o masini USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Siaki e le tusitusiga le fa'amaumauga SHA256, kopi faila fa'afouina i `/etc/ocsp/`,
ma toe fa'aola le daemon `ocspserver` e ala i `rcctl`. Afai o `EnableIndexTxtWatch`
o le `true` i `appsettings.json`, o le a maua fo'i e le OCSP server suiga o
`index.txt` otometi e aunoa ma se toe fa'aola.

### 7 — Fa'amaonia Tali OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Tu'utu'uga o Igoa

| Faila | Fa'ata'ita'i |
|-------|-------------|
| Ki CA Vaeluagalemu | `intermediate-PROJECT-DATE.key.pem` |
| Tusi Faamaonia CA Vaeluagalemu | `intermediate-PROJECT-DATE.cert.pem` |
| Fusi Tusi Faamaonia | `ca-chain-PROJECT-DATE.cert.pem` |
| Tusi Faamaonia Server | `SERVER_DOMAIN.DATE.cert.pem` |
| PKCS#12 Server | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Tusi Faamaonia Tagata Fa'aogaina | `client-USER_EMAIL.DATE.cert.pem` |
| PKCS#12 Tagata Fa'aogaina | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Tusi Faamaonia Sainia OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Fa'aaliga Saogalemu

- E le tatau **lava** ona feso'ota'i le masini CA fa'ate'a i se feso'ota'iga.
- O ki tumu a'mata ma vaeluagalemu ua fa'ailoga fa'aulufale AES-256. Teu fa'aupuga
  i se fa'amaufa'ailoga masini po'o se pusa saogalemu faaletino, tu'usa'o mai ki.
- Siaki pea le fa'amaumauga SHA256 o le fu'a USB a'o le'i fa'aulufale — faia lea
  e `import-from-usb.sh` otometi fa'aaoga `sha256 -C` OpenBSD.
- E muta le CRL pe a uma le 30 aso e fa'aaogaina ai. Fa'atulaga toe fa'afouina o
  le CRL i taimi mea uma:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # ona export-to-usb + import-from-usb
  ```
- E muta tusi faamaonia sainia OCSP pe a uma le 375 aso. Fa'afou i le toe fa'agasolo
  o `create-intermediate-ca.sh` fa'aaoga le auivi tutusa; o laasaga ua mae'a uma
  e solomuli ma gaosia se tusi faamaonia OCSP fou pe a manaomia.
