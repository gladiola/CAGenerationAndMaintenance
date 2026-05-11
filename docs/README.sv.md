# CAGenerationAndMaintenance

Skalskript för att driva en **offline, luftgappad certifikatutfärdare (CA)**
på OpenBSD med OpenSSL. Återkallelsestatus publiceras via en separat
[OpenBSD OCSP-server](https://github.com/gladiola/OpenBSDOCSPServer).
Uppdateringar överförs mellan den offline-CA-maskinen och OCSP-servermaskinen
via en USB-enhet.

---

## Arkitekturöversikt

```
┌─────────────────────────────┐        USB-enhet        ┌──────────────────────────┐
│   Offline-CA-maskin         │  ───────────────────►   │  OCSP-servermaskin       │
│   (OpenBSD, luftgappad)     │  export-to-usb.sh        │  (OpenBSD, nätverkad)    │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  fysisk transport        │  /etc/ocsp/              │
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

## Förutsättningar

Båda maskinerna kör **OpenBSD**. Installera OpenSSL om det inte redan finns:

```sh
pkg_add openssl
```

OCSP-servermaskinen behöver också
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) installerad och
registrerad som rc.d-tjänst med namnet `ocspserver`.

Alla skript använder `#!/bin/sh` (OpenBSD:s ksh-baserade `/bin/sh`), standard
OpenBSD-verktyg (`mount_msdos`, `sha256`, `rcctl`, `doas`) och `openssl(1)`.
Kör alla skript som root via `doas`.

---

## Fillayout

```
scripts/
  setup-ca.sh               Initierar root-CA-kataloger och genererar root-nyckel/-certifikat
  create-intermediate-ca.sh Skapar en namngiven mellanliggande CA signerad av root-CA
  create-server-cert.sh     Utfärdar ett TLS-servercertifikat (mTLS)
  create-client-cert.sh     Utfärdar ett klientcertifikat (mTLS)
  revoke-cert.sh            Återkallar ett certifikat och återskapar CRL
  export-to-usb.sh          Paketerar CA-data på USB för luftgapps-överföring (CA-sida)
  import-from-usb.sh        Importerar från USB till OCSP-servern (OCSP-serversida)

config/
  openssl-root.cnf.template          Root-CA OpenSSL-konfigurationsmall
  openssl-intermediate.cnf.template  Mellanliggande CA OpenSSL-konfigurationsmall
```

---

## Steg-för-steg-användning

### 1 — Initiera root-CA  *(offline-CA-maskin, en gång)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Skapar `/root/ca/`, genererar en AES-256-krypterad 4096-bitars root-nyckel, ett
självundertecknat certifikat giltigt i 20 år och ett OCSP-signeringscertifikat för
root-CA.

### 2 — Skapa en mellanliggande CA  *(offline-CA-maskin, en gång per projekt)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Filer skapas under `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Utfärda ett servercertifikat  *(offline-CA-maskin)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Utdata i den mellanliggande CA-katalogen:
- `private/app.example.com.01012027.key.pem` — krypterad privat nyckel
- `certs/app.example.com.01012027.cert.pem` — signerat certifikat
- `certs/app.example.com.01012027.server.full.pfx` — PKCS#12-paket

### 4 — Utfärda klientcertifikat  *(offline-CA-maskin)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Upprepa för varje användare. Överför varje `.full.pfx`-paket till respektive användare
via en säker kanal.

### 5 — Återkalla ett certifikat  *(offline-CA-maskin)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Förnya CRL utan att återkalla något (t.ex. på ett schema):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Överföring till OCSP-server via USB  *(luftgapps-arbetsflöde)*

#### På offline-CA-maskinen

Sätt i en FAT32-formaterad USB-enhet. Bekräfta enheten:

```sh
dmesg | tail -20          # leta efter "sd1 at ..."-rader
disklabel sd1             # identifiera FAT32-partition (vanligtvis 'i')
```

Exportera sedan:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Skriptet skriver ett `SHA256`-kontrollsummemanifest och demonterar enheten säkert.
Bär fysiskt USB-enheten till OCSP-servermaskinen.

#### På OCSP-servermaskinen

```sh
dmesg | tail -20          # bekräfta USB-enhetens namn
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Skriptet verifierar kontrollsummor, kopierar uppdaterade filer till `/etc/ocsp/` och
laddar om `ocspserver`-demonen via `rcctl`. Om `EnableIndexTxtWatch` är `true` i
`appsettings.json` hämtar OCSP-servern också `index.txt`-ändringar automatiskt utan
omladdning.

### 7 — Verifiera OCSP-svar

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Namnkonventioner

| Fil | Mönster |
|-----|---------|
| Mellanliggande CA-nyckel | `intermediate-PROJECT-DATE.key.pem` |
| Mellanliggande CA-certifikat | `intermediate-PROJECT-DATE.cert.pem` |
| Certifikatkedja | `ca-chain-PROJECT-DATE.cert.pem` |
| Servercertifikat | `SERVER_DOMAIN.DATE.cert.pem` |
| Server-PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Klientcertifikat | `client-USER_EMAIL.DATE.cert.pem` |
| Klient-PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| OCSP-signeringscertifikat | `INTER_NAME-ocsp.cert.pem` |

---

## Säkerhetsanteckningar

- Offline-CA-maskinen får **aldrig anslutas till ett nätverk**.
- Root- och mellanliggande privata nycklar är AES-256-krypterade. Förvara lösenfraser
  i en hårdvarutoken eller ett fysiskt kassaskåp, separat från nycklarna.
- Verifiera alltid USB-enhetens kontrollsummor innan import — `import-from-usb.sh`
  gör detta automatiskt med OpenBSD:s `sha256 -C`.
- CRL:er löper ut efter 30 dagar som standard. Schemalägg regelbunden CRL-förnyelse:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # sedan export-to-usb + import-from-usb
  ```
- OCSP-signeringscertifikat löper ut efter 375 dagar. Förnya dem genom att köra
  `create-intermediate-ca.sh` igen med samma argument; redan slutförda steg hoppas
  över och ett nytt OCSP-certifikat genereras bara när det behövs.
