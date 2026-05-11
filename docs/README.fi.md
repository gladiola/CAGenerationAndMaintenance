# CAGenerationAndMaintenance

Shell-skriptejä **offline-tilassa, ilmavälin takana toimivan varmentajan (CA)**
käyttämiseen OpenBSD:llä OpenSSL:n avulla. Peruutustila julkaistaan erillisen
[OpenBSD OCSP -palvelimen](https://github.com/gladiola/OpenBSDOCSPServer) kautta.
Päivitykset siirretään offline-CA-koneen ja OCSP-palvelinkoneen välillä USB-asemalla.

---

## Arkkitehtuurin yleiskatsaus

```
┌─────────────────────────────┐        USB-asema        ┌──────────────────────────┐
│   Offline-CA-kone           │  ───────────────────►   │  OCSP-palvelinkone       │
│   (OpenBSD, ilmaväli)       │  export-to-usb.sh        │  (OpenBSD, verkossa)     │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  fyysinen kuljetus       │  /etc/ocsp/              │
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

## Edellytykset

Molemmat koneet käyttävät **OpenBSD**:tä. Asenna OpenSSL, jos sitä ei vielä ole:

```sh
pkg_add openssl
```

OCSP-palvelinkoneen täytyy myös olla asennettuna
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) rekisteröitynä
rc.d-palveluna nimeltä `ocspserver`.

Kaikki skriptit käyttävät `#!/bin/sh` (OpenBSD:n ksh-pohjainen `/bin/sh`), OpenBSD:n
vakioapuohjelmia (`mount_msdos`, `sha256`, `rcctl`, `doas`) ja `openssl(1)`.
Suorita kaikki skriptit rootina `doas`:n kautta.

---

## Tiedostorakenne

```
scripts/
  setup-ca.sh               Alustaa juuri-CA:n hakemistot ja luo juuriavaimen/-varmenteen
  create-intermediate-ca.sh Luo nimetyn välittäjä-CA:n, jonka juuri-CA allekirjoittaa
  create-server-cert.sh     Myöntää TLS-palvelinvarmenteen (mTLS)
  create-client-cert.sh     Myöntää asiakasvarmenteen (mTLS)
  revoke-cert.sh            Peruuttaa varmenteen ja luo CRL:n uudelleen
  export-to-usb.sh          Pakkaa CA-tiedot USB:lle ilmavälin siirtoa varten (CA-puoli)
  import-from-usb.sh        Tuo USB:ltä OCSP-palvelimelle (OCSP-palvelinpuoli)

config/
  openssl-root.cnf.template          Juuri-CA:n OpenSSL-konfiguraatiomalli
  openssl-intermediate.cnf.template  Välittäjä-CA:n OpenSSL-konfiguraatiomalli
```

---

## Vaiheittainen käyttö

### 1 — Alusta juuri-CA  *(offline-CA-kone, kerran)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Luo `/root/ca/`, tuottaa AES-256-salatun 4096-bittisen juuriavaimen, 20 vuodeksi
voimassa olevan itseallekirjoitetun varmenteen ja juuri-CA:n OCSP-allekirjoitusvarmenteen.

### 2 — Luo välittäjä-CA  *(offline-CA-kone, kerran per projekti)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Tiedostot luodaan `/root/ca/intermediate-MY-PROJECT-01012027/`-hakemistoon.

### 3 — Myönnä palvelinvarmenne  *(offline-CA-kone)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Tuloste välittäjä-CA:n hakemistoon:
- `private/app.example.com.01012027.key.pem` — salattu yksityisavain
- `certs/app.example.com.01012027.cert.pem` — allekirjoitettu varmenne
- `certs/app.example.com.01012027.server.full.pfx` — PKCS#12-paketti

### 4 — Myönnä asiakasvarmenteita  *(offline-CA-kone)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Toista jokaisen käyttäjän kohdalla. Toimita jokainen `.full.pfx`-paketti vastaavalle
käyttäjälle turvallisen kanavan kautta.

### 5 — Peruuta varmenne  *(offline-CA-kone)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

CRL:n uusiminen ilman peruutuksia (esim. aikataulun mukaan):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Siirto OCSP-palvelimelle USB:n kautta  *(ilmaväli-työnkulku)*

#### Offline-CA-koneella

Aseta FAT32-alustettu USB-asema. Vahvista laite:

```sh
dmesg | tail -20          # etsi "sd1 at ..."-rivejä
disklabel sd1             # tunnista FAT32-osio (yleensä 'i')
```

Sitten vie:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Skripti kirjoittaa `SHA256`-tarkistussumman manifestin ja irrottaa aseman turvallisesti.
Kuljeta USB-asema fyysisesti OCSP-palvelinkoneelle.

#### OCSP-palvelinkoneella

```sh
dmesg | tail -20          # vahvista USB-laitteen nimi
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Skripti tarkistaa tarkistussummat, kopioi päivitetyt tiedostot `/etc/ocsp/`-hakemistoon
ja lataa `ocspserver`-demonin uudelleen `rcctl`:n kautta. Jos `appsettings.json`-tiedostossa
`EnableIndexTxtWatch` on `true`, OCSP-palvelin poimii myös `index.txt`-muutokset
automaattisesti ilman uudelleenlatausta.

### 7 — Tarkista OCSP-vastaukset

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Nimeämiskäytännöt

| Tiedosto | Malli |
|---------|-------|
| Välittäjä-CA:n avain | `intermediate-PROJECT-DATE.key.pem` |
| Välittäjä-CA:n varmenne | `intermediate-PROJECT-DATE.cert.pem` |
| Varmenneketju | `ca-chain-PROJECT-DATE.cert.pem` |
| Palvelinvarmenne | `SERVER_DOMAIN.DATE.cert.pem` |
| Palvelimen PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Asiakasvarmenne | `client-USER_EMAIL.DATE.cert.pem` |
| Asiakkaan PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| OCSP-allekirjoitusvarmenne | `INTER_NAME-ocsp.cert.pem` |

---

## Turvallisuushuomiot

- Offline-CA-konetta **ei saa koskaan yhdistää verkkoon**.
- Juuri- ja välittäjä-yksityisavaimet on salattu AES-256:lla. Säilytä salasanat
  laitteistotunnisteessa tai fyysisessä kassakaapissa, erillään avaimista.
- Tarkista aina USB-aseman tarkistussummat ennen tuontia — `import-from-usb.sh`
  tekee tämän automaattisesti OpenBSD:n `sha256 -C`:llä.
- CRL:t vanhenevat oletuksena 30 päivän kuluttua. Aikatauluta säännöllinen CRL:n uusiminen:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # sitten export-to-usb + import-from-usb
  ```
- OCSP-allekirjoitusvarmenteet vanhenevat 375 päivän jälkeen. Uusi ne ajamalla
  `create-intermediate-ca.sh` uudelleen samoilla argumenteilla; jo suoritetut vaiheet
  ohitetaan ja uusi OCSP-varmenne luodaan vain tarvittaessa.
