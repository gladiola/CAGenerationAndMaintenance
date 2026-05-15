# CAGenerationAndMaintenance

Shell-scripts voor het beheren van een **offline, air-gapped Certificeringsinstantie
(CA)** op OpenBSD met OpenSSL. De intrekkingsstatus wordt gepubliceerd via een
afzonderlijke [OpenBSD OCSP-server](https://github.com/gladiola/OpenBSDOCSPServer).
Updates worden overgedragen tussen de offline CA-machine en de OCSP-servermachine via
een USB-station.

---

## Architectuuroverzicht

```
┌─────────────────────────────┐        USB-station      ┌──────────────────────────┐
│   Offline CA-machine        │  ───────────────────►   │  OCSP-servermachine      │
│   (OpenBSD, air-gapped)     │  export-to-usb.sh        │  (OpenBSD, in netwerk)   │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  fysiek transport        │  /etc/ocsp/              │
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

## Vereisten

Beide machines draaien **OpenBSD**. Installeer OpenSSL als dat nog niet aanwezig is:

```sh
pkg_add openssl
```

De OCSP-servermachine heeft ook
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) nodig, geïnstalleerd
en geregistreerd als rc.d-dienst genaamd `ocspserver`.

Alle scripts gebruiken `#!/bin/sh` (OpenBSD's ksh-gebaseerde `/bin/sh`), standaard
OpenBSD-hulpprogramma's (`mount_msdos`, `sha256`, `rcctl`, `doas`) en `openssl(1)`.
Voer alle scripts als root uit via `doas`.

---

## Bestandsindeling

```
scripts/
  setup-ca.sh               Initialiseer root-CA-mappen en genereer rootsleutel/-certificaat
  create-intermediate-ca.sh Maak een benoemde tussenliggende CA ondertekend door de root-CA
  create-server-cert.sh     Geef een TLS-servercertificaat uit (mTLS)
  create-client-cert.sh     Geef een clientcertificaat uit (mTLS)
  revoke-cert.sh            Trek een certificaat in en regenereer de CRL
  export-to-usb.sh          Verpak CA-gegevens op USB voor air-gap-overdracht (CA-kant)
  import-from-usb.sh        Importeer van USB naar de OCSP-server (OCSP-server-kant)

config/
  openssl-root.cnf.template          Root-CA OpenSSL-configuratiesjabloon
  openssl-intermediate.cnf.template  Tussenliggende CA OpenSSL-configuratiesjabloon
```

---

## Uitrolplanning (vul dit in voordat je scripts uitvoert)

Bereid je uitrolwaarden voor voordat je de onderstaande stappen uitvoert:

- Waar komt de CA te staan?  
  default: `/root/ca`  
  daadwerkelijk:

- Wat is de organisatie en waar bevindt die zich?  
  default: `My Organization`  
  daadwerkelijk:

- Wat is de projectnaam?  
  default: `MY PROJECT`  
  daadwerkelijk:

- Wat is de versiedatum van het project?  
  default: `01012027`  
  daadwerkelijk:

- Wat is de TLD?  
  default: `example.com`  
  daadwerkelijk:

- Wat is het subdomein?  
  default: `app.`  
  daadwerkelijk:

- Wat is het e-mailadres van de clientgebruiker(s)?  
  default: `user@example.com`  
  daadwerkelijk:

- Waar is de USB-stick voor overdracht?  
  default: `/dev/sd1i`  
  daadwerkelijk:

---

## Stap-voor-stap Gebruik

### 1 — Initialiseer de Root-CA  *(offline CA-machine, eenmalig)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Maakt `/root/ca/` aan, genereert een AES-256-versleutelde 4096-bits rootsleutel, een
zelfondertekend certificaat geldig voor 20 jaar en een OCSP-ondertekeningscertificaat
voor de root-CA.

### 2 — Maak een Tussenliggende CA  *(offline CA-machine, eenmalig per project)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Bestanden worden aangemaakt in `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Geef een Servercertificaat Uit  *(offline CA-machine)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Uitvoer in de tussenliggende CA-map:
- `private/app.example.com.01012027.key.pem` — versleutelde privésleutel
- `certs/app.example.com.01012027.cert.pem` — ondertekend certificaat
- `certs/app.example.com.01012027.server.full.pfx` — PKCS#12-bundel

### 4 — Geef Clientcertificaten Uit  *(offline CA-machine)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Herhaal voor elke gebruiker. Stuur elke `.full.pfx`-bundel over een beveiligd kanaal
naar de betreffende gebruiker.

### 5 — Trek een Certificaat In  *(offline CA-machine)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

CRL vernieuwen zonder intrekking (bijv. op een schema):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Overdracht naar OCSP-server via USB  *(air-gap-workflow)*

#### Op de Offline CA-machine

Steek een FAT32-geformatteerd USB-station in. Bevestig het apparaat:

```sh
dmesg | tail -20          # zoek naar "sd1 at ..."-regels
disklabel sd1             # identificeer de FAT32-partitie (gewoonlijk 'i')
```

Daarna exporteren:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Het script schrijft een `SHA256`-controlesommanifest en ontkoppelt het station veilig.
Transporteer het USB-station fysiek naar de OCSP-servermachine.

#### Op de OCSP-servermachine

```sh
dmesg | tail -20          # bevestig USB-apparaatnaam
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Het script verifieert controlesommen, kopieert bijgewerkte bestanden naar `/etc/ocsp/`
en herlaadt de `ocspserver`-daemon via `rcctl`. Als `EnableIndexTxtWatch` `true` is
in `appsettings.json`, zal de OCSP-server ook `index.txt`-wijzigingen automatisch
oppikken zonder herlaad.

### 7 — Verifieer OCSP-antwoorden

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Naamgevingsconventies

| Bestand | Patroon |
|---------|---------|
| Tussenliggende CA-sleutel | `intermediate-PROJECT-DATE.key.pem` |
| Tussenliggend CA-certificaat | `intermediate-PROJECT-DATE.cert.pem` |
| Certificaatketen | `ca-chain-PROJECT-DATE.cert.pem` |
| Servercertificaat | `SERVER_DOMAIN.DATE.cert.pem` |
| Server PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Clientcertificaat | `client-USER_EMAIL.DATE.cert.pem` |
| Client PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| OCSP-ondertekeningscertificaat | `INTER_NAME-ocsp.cert.pem` |

---

## Beveiligingsnotities

- De offline CA-machine mag **nooit worden verbonden met een netwerk**.
- Root- en tussenliggende privésleutels zijn AES-256-versleuteld. Bewaar
  wachtwoordzinnen in een hardwaretoken of fysieke kluis, apart van de sleutels.
- Verifieer altijd USB-station-controlesommen vóór importeren — `import-from-usb.sh`
  doet dit automatisch met OpenBSD's `sha256 -C`.
- CRL's verlopen standaard na 30 dagen. Plan regelmatige CRL-vernieuwing:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # dan export-to-usb + import-from-usb
  ```
- OCSP-ondertekeningscertificaten verlopen na 375 dagen. Vernieuw ze door
  `create-intermediate-ca.sh` opnieuw uit te voeren met dezelfde argumenten; reeds
  voltooide stappen worden overgeslagen en alleen een nieuw OCSP-certificaat wordt
  gegenereerd wanneer nodig.
