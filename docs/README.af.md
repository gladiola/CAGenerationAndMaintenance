# CAGenerationAndMaintenance

Shell-skrifte vir die bedryf van 'n **aflyn, luggeïsoleerde Sertifikaat-Owerheid (CA)**
op OpenBSD met OpenSSL. Die herroepingstatus word gepubliseer via 'n afsonderlike
[OpenBSD OCSP-bediener](https://github.com/gladiola/OpenBSDOCSPServer).
Opdaterings word tussen die aflyn CA-masjien en die OCSP-bedienermasjien via 'n
USB-skyf oorgedra.

---

## Argitektuursoorsig

```
┌─────────────────────────────┐        USB-skyf         ┌──────────────────────────┐
│   Aflyn CA-masjien          │  ───────────────────►   │  OCSP-bedienermasjien    │
│   (OpenBSD, luggeïsoleer)   │  export-to-usb.sh        │  (OpenBSD, aanlyn)       │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  fisiese vervoer         │  /etc/ocsp/              │
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

## Vereistes

Albei masjiene gebruik **OpenBSD**. Installeer OpenSSL as dit nog nie teenwoordig is nie:

```sh
pkg_add openssl
```

Die OCSP-bedienermasjien benodig ook
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) geïnstalleer en as
'n rc.d-diens genaamd `ocspserver` geregistreer.

Alle skrifte gebruik `#!/bin/sh` (OpenBSD se ksh-gebaseerde `/bin/sh`), standaard
OpenBSD-nutsgoed (`mount_msdos`, `sha256`, `rcctl`, `doas`), en `openssl(1)`.
Voer alle skrifte as root via `doas` uit.

---

## Lêeruitleg

```
scripts/
  setup-ca.sh               Initialiseer wortel-CA-gidse en genereer wortelsleutel/sertifikaat
  create-intermediate-ca.sh Skep 'n benoemde tussenliggende CA onderteken deur die wortel-CA
  create-server-cert.sh     Reik 'n TLS-bedienersertifikaat uit (mTLS)
  create-client-cert.sh     Reik 'n kliëntsertifikaat uit (mTLS)
  revoke-cert.sh            Herroep 'n sertifikaat en herGenereer die CRL
  export-to-usb.sh          Verpak CA-data op USB vir lugsplete-oordrag (CA-kant)
  import-from-usb.sh        Voer in van USB na die OCSP-bediener (OCSP-bediener-kant)

config/
  openssl-root.cnf.template          Wortel-CA OpenSSL-konfigurasiesjabloon
  openssl-intermediate.cnf.template  Tussenliggende CA OpenSSL-konfigurasiesjabloon
```

---

## Stap-vir-stap Gebruik

### 1 — Initialiseer die Wortel-CA  *(aflyn CA-masjien, een keer)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Skep `/root/ca/`, genereer 'n AES-256-geënkripteerde 4096-bis wortelsleutel, 'n
self-ondertekende sertifikaat geldig vir 20 jaar, en 'n OCSP-ondertekeningsertifikaat
vir die wortel-CA.

### 2 — Skep 'n Tussenliggende CA  *(aflyn CA-masjien, een keer per projek)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Lêers word geskep onder `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Reik 'n Bedienersertifikaat Uit  *(aflyn CA-masjien)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Uitsette in die tussenliggende CA-gids:
- `private/app.example.com.01012027.key.pem` — geënkripteerde privaatsleutel
- `certs/app.example.com.01012027.cert.pem` — ondertekende sertifikaat
- `certs/app.example.com.01012027.server.full.pfx` — PKCS#12-bundel

### 4 — Reik Kliëntsertifikate Uit  *(aflyn CA-masjien)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Herhaal vir elke gebruiker. Dra elke `.full.pfx`-bundel oor na die betrokke gebruiker
via 'n veilige kanaal.

### 5 — Herroep 'n Sertifikaat  *(aflyn CA-masjien)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Om die CRL te vernuwe sonder om iets te herroep (bv. op 'n skedule):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Oordrag na OCSP-bediener via USB  *(lugsplete-werkvloei)*

#### Op die Aflyn CA-masjien

Voeg 'n FAT32-geformatteerde USB-skyf in. Bevestig die toestel:

```sh
dmesg | tail -20          # soek na "sd1 at ..."-reëls
disklabel sd1             # identifiseer die FAT32-partisie (gewoonlik 'i')
```

Dan uitvoer:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Die skrif skryf 'n `SHA256`-kontrolesomdokument en ontkoppel die skyf veilig.
Dra die USB-skyf fisies oor na die OCSP-bedienermasjien.

#### Op die OCSP-bedienermasjien

```sh
dmesg | tail -20          # bevestig USB-toestellnaam
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Die skrif kontroleer kontrolesomme, kopieer opdateerde lêers na `/etc/ocsp/`, en
herlaai die `ocspserver`-daemon via `rcctl`. As `EnableIndexTxtWatch` `true` is in
`appsettings.json`, sal die OCSP-bediener ook `index.txt`-veranderinge outomaties
optel sonder 'n herlaai.

### 7 — Verifieer OCSP-antwoorde

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Naamgewingkonvensies

| Lêer | Patroon |
|------|---------|
| Tussenliggende CA-sleutel | `intermediate-PROJECT-DATE.key.pem` |
| Tussenliggende CA-sertifikaat | `intermediate-PROJECT-DATE.cert.pem` |
| Sertifikaatketting | `ca-chain-PROJECT-DATE.cert.pem` |
| Bedienersertifikaat | `SERVER_DOMAIN.DATE.cert.pem` |
| Bediener PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Kliëntsertifikaat | `client-USER_EMAIL.DATE.cert.pem` |
| Kliënt PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| OCSP-ondertekeningsertifikaat | `INTER_NAME-ocsp.cert.pem` |

---

## Sekuriteitsnotas

- Die aflyn CA-masjien moet **nooit aan 'n netwerk gekoppel word nie**.
- Wortel- en tussenliggende privaatsleutels is AES-256-geënkripteer. Stoor wagfrases in
  'n hardeware-token of fisiese kluis, apart van die sleutels.
- Verifieer altyd USB-skyf-kontrolesomme voor invoer — `import-from-usb.sh` doen dit
  outomaties met OpenBSD se `sha256 -C`.
- CRL's verval na 30 dae by verstek. Skedule gereelde CRL-vernuwing:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # dan export-to-usb + import-from-usb
  ```
- OCSP-ondertekeningsertifikate verval na 375 dae. Vernuwe hulle deur `create-intermediate-ca.sh`
  weer met dieselfde argumente uit te voer; reeds voltooide stappe word oorgeslaan en
  slegs 'n nuwe OCSP-sertifikaat word gegenereer wanneer nodig.
