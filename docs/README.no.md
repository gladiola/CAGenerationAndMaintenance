# CAGenerationAndMaintenance

Shell-skript for å drifte en **frakoblet, luftgapet sertifikatmyndighet (CA)**
på OpenBSD med OpenSSL. Tilbakekallingstatus publiseres via en separat
[OpenBSD OCSP-server](https://github.com/gladiola/OpenBSDOCSPServer).
Oppdateringer overføres mellom den frakoblede CA-maskinen og OCSP-servermaskinen
via en USB-enhet.

---

## Planlegging av utrulling (fyll ut dette før du kjører skriptene)

Forbered utrullingsverdiene før du kjører trinnene nedenfor:

- Hvor skal CA-en være?  
  default: `/root/ca`  
  faktisk:

- Hva er organisasjonen og hvor ligger den?  
  default: `My Organization`  
  faktisk:

- Hva er prosjektnavnet?  
  default: `MY PROJECT`  
  faktisk:

- Hva er prosjektets versjonsdato?  
  default: `01012027`  
  faktisk:

- Hva er TLD?  
  default: `example.com`  
  faktisk:

- Hva er subdomenet?  
  default: `app.`  
  faktisk:

- Hva er e-postadressen til klientbruker(e)?  
  default: `user@example.com`  
  faktisk:

- Hvor er USB-minnepinnen for overføring?  
  default: `/dev/sd1i`  
  faktisk:

---

## Arkitekturoversikt

```
┌─────────────────────────────┐        USB-enhet        ┌──────────────────────────┐
│   Frakoblet CA-maskin       │  ───────────────────►   │  OCSP-servermaskin       │
│   (OpenBSD, luftgapet)      │  export-to-usb.sh        │  (OpenBSD, i nettverk)   │
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

## Forutsetninger

Begge maskiner kjører **OpenBSD**. Installer OpenSSL hvis det ikke allerede er til stede:

```sh
pkg_add openssl
```

OCSP-servermaskinen trenger også
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) installert og
registrert som rc.d-tjeneste med navn `ocspserver`.

Alle skript bruker `#!/bin/sh` (OpenBSD sitt ksh-baserte `/bin/sh`), standard
OpenBSD-verktøy (`mount_msdos`, `sha256`, `rcctl`, `doas`) og `openssl(1)`.
Kjør alle skript som root via `doas`.

---

## Filstruktur

```
scripts/
  setup-ca.sh               Initialiserer root-CA-kataloger og genererer rotnøkkel/-sertifikat
  create-intermediate-ca.sh Oppretter en navngitt mellomliggende CA signert av root-CA
  create-server-cert.sh     Utsteder et TLS-serversertifikat (mTLS)
  create-client-cert.sh     Utsteder et klientsertifikat (mTLS)
  revoke-cert.sh            Tilbakekaller et sertifikat og regenererer CRL
  export-to-usb.sh          Pakker CA-data på USB for luftgap-overføring (CA-side)
  import-from-usb.sh        Importerer fra USB til OCSP-serveren (OCSP-serverside)

config/
  openssl-root.cnf.template          Root-CA OpenSSL-konfigurasjonsmal
  openssl-intermediate.cnf.template  Mellomliggende CA OpenSSL-konfigurasjonsmal
```

---

## Trinn-for-trinn-bruk

### 1 — Initialiser root-CA  *(frakoblet CA-maskin, én gang)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Oppretter `/root/ca/`, genererer en AES-256-kryptert 4096-bits rotnøkkel, et
selvsignert sertifikat gyldig i 20 år og et OCSP-signeringssertifikat for root-CA.

### 2 — Opprett en mellomliggende CA  *(frakoblet CA-maskin, én gang per prosjekt)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Filer opprettes under `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Utsted et serversertifikat  *(frakoblet CA-maskin)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Utdata i den mellomliggende CA-katalogen:
- `private/app.example.com.01012027.key.pem` — kryptert privat nøkkel
- `certs/app.example.com.01012027.cert.pem` — signert sertifikat
- `certs/app.example.com.01012027.server.full.pfx` — PKCS#12-pakke

### 4 — Utsted klientsertifikater  *(frakoblet CA-maskin)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Gjenta for hver bruker. Overfør hver `.full.pfx`-pakke til den aktuelle brukeren
via en sikker kanal.

### 5 — Tilbakekall et sertifikat  *(frakoblet CA-maskin)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

For å fornye CRL uten å tilbakekalle noe (f.eks. på en tidsplan):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Overføring til OCSP-server via USB  *(luftgap-arbeidsflyt)*

#### På den frakoblede CA-maskinen

Sett inn en FAT32-formatert USB-enhet. Bekreft enheten:

```sh
dmesg | tail -20          # se etter "sd1 at ..."-linjer
disklabel sd1             # identifiser FAT32-partisjonen (vanligvis 'i')
```

Deretter eksportere:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Skriptet skriver et `SHA256`-kontrollsummemanifest og demonterer enheten trygt.
Transporter USB-enheten fysisk til OCSP-servermaskinen.

#### På OCSP-servermaskinen

```sh
dmesg | tail -20          # bekreft USB-enhetens navn
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Skriptet verifiserer kontrollsummer, kopierer oppdaterte filer til `/etc/ocsp/` og
laster inn `ocspserver`-demonen på nytt via `rcctl`. Hvis `EnableIndexTxtWatch` er
`true` i `appsettings.json`, vil OCSP-serveren også hente `index.txt`-endringer
automatisk uten en ny innlasting.

### 7 — Verifiser OCSP-svar

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Navnkonvensjoner

| Fil | Mønster |
|-----|---------|
| Mellomliggende CA-nøkkel | `intermediate-PROJECT-DATE.key.pem` |
| Mellomliggende CA-sertifikat | `intermediate-PROJECT-DATE.cert.pem` |
| Sertifikatkjede | `ca-chain-PROJECT-DATE.cert.pem` |
| Serversertifikat | `SERVER_DOMAIN.DATE.cert.pem` |
| Server-PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Klientsertifikat | `client-USER_EMAIL.DATE.cert.pem` |
| Klient-PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| OCSP-signeringssertifikat | `INTER_NAME-ocsp.cert.pem` |

---

## Sikkerhetsmerknader

- Den frakoblede CA-maskinen må **aldri kobles til et nettverk**.
- Root- og mellomliggende private nøkler er AES-256-kryptert. Lagre passordfrasene
  i en maskinvaretokens eller fysisk safe, atskilt fra nøklene.
- Verifiser alltid USB-enhetens kontrollsummer før import — `import-from-usb.sh`
  gjør dette automatisk med OpenBSD sin `sha256 -C`.
- CRL-er utløper etter 30 dager som standard. Planlegg regelmessig CRL-fornyelse:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # deretter export-to-usb + import-from-usb
  ```
- OCSP-signeringssertifikater utløper etter 375 dager. Forny dem ved å kjøre
  `create-intermediate-ca.sh` igjen med de samme argumentene; allerede fullførte
  trinn hoppes over og et nytt OCSP-sertifikat genereres bare når nødvendig.
