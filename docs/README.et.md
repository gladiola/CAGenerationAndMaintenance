# CAGenerationAndMaintenance

Shellisskriptid **võrguühenduseta, õhuvahega sertifitseerimiskeskuse (CA)** käitamiseks
OpenBSD-s OpenSSL-iga. Tühistamisstaatus avaldatakse eraldi
[OpenBSD OCSP-serveri](https://github.com/gladiola/OpenBSDOCSPServer) kaudu.
Uuendused edastatakse võrguühenduseta CA masina ja OCSP-serveri masina vahel USB-mälupulga kaudu.

---

## Arhitektuuri ülevaade

```
┌─────────────────────────────┐        USB-mälupulk     ┌──────────────────────────┐
│   Võrguühenduseta CA masin  │  ───────────────────►   │  OCSP-serveri masin      │
│   (OpenBSD, õhuvahega)      │  export-to-usb.sh        │  (OpenBSD, võrgus)       │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  füüsiline transport     │  /etc/ocsp/              │
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

## Eeldused

Mõlemad masinad töötavad **OpenBSD** all. Paigaldage OpenSSL, kui see puudub:

```sh
pkg_add openssl
```

OCSP-serveri masinas on vaja ka
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer), mis on paigaldatud
ja registreeritud rc.d-teenusena nimega `ocspserver`.

Kõik skriptid kasutavad `#!/bin/sh` (OpenBSD ksh-põhine `/bin/sh`), standardseid
OpenBSD-utiliite (`mount_msdos`, `sha256`, `rcctl`, `doas`) ja `openssl(1)`.
Käivitage kõik skriptid root-ina `doas` kaudu.

---

## Failide paigutus

```
scripts/
  setup-ca.sh               Initsialiseerib juur-CA kataloogid ja loob juure võtme/sertifikaadi
  create-intermediate-ca.sh Loob juure CA poolt allkirjastatud vahepealseid CA
  create-server-cert.sh     Väljastab TLS-serveri sertifikaadi (mTLS)
  create-client-cert.sh     Väljastab kliendi sertifikaadi (mTLS)
  revoke-cert.sh            Tühistab sertifikaadi ja taastoodab CRL-i
  export-to-usb.sh          Pakib CA andmed USB-le õhuvahega edastamiseks (CA pool)
  import-from-usb.sh        Impordib USB-lt OCSP-serverisse (OCSP-serveri pool)

config/
  openssl-root.cnf.template          Juur-CA OpenSSL-i konfiguratsiooni mall
  openssl-intermediate.cnf.template  Vahepealsea CA OpenSSL-i konfiguratsiooni mall
```

---

## Samm-sammult kasutamine

### 1 — Initsialiseerige juur-CA  *(võrguühenduseta CA masin, üks kord)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Loob `/root/ca/`, genereerib AES-256-krüpteeritud 4096-bitise juurvõtme, 20 aasta
kehtivusega ise-allkirjastatud sertifikaadi ja juur-CA OCSP allkirjastamise sertifikaadi.

### 2 — Looge vahepealse CA  *(võrguühenduseta CA masin, üks kord projekti kohta)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Failid luuakse `/root/ca/intermediate-MY-PROJECT-01012027/` alla.

### 3 — Väljastage serveri sertifikaat  *(võrguühenduseta CA masin)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Väljund vahepealse CA kataloogis:
- `private/app.example.com.01012027.key.pem` — krüpteeritud privaatvõti
- `certs/app.example.com.01012027.cert.pem` — allkirjastatud sertifikaat
- `certs/app.example.com.01012027.server.full.pfx` — PKCS#12 pakett

### 4 — Väljastage kliendi sertifikaadid  *(võrguühenduseta CA masin)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Korrake iga kasutaja jaoks. Edastage iga `.full.pfx` pakett vastavale kasutajale
turvalise kanali kaudu.

### 5 — Tühistage sertifikaat  *(võrguühenduseta CA masin)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

CRL-i uuendamine ilma midagi tühistamata (nt ajakava alusel):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Edastamine OCSP-serverisse USB kaudu  *(õhuvahega tööprotsess)*

#### Võrguühenduseta CA masinas

Sisestage FAT32-ga vormindatud USB-mälupulk. Kinnitage seade:

```sh
dmesg | tail -20          # otsige "sd1 at ..." ridu
disklabel sd1             # tuvastage FAT32 partitsioon (tavaliselt 'i')
```

Seejärel eksportida:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Skript kirjutab `SHA256` kontrollsumma manifesti ja eemaldab draivi turvaliselt.
Transportige USB-mälupulk füüsiliselt OCSP-serveri masinasse.

#### OCSP-serveri masinas

```sh
dmesg | tail -20          # kinnitage USB-seadme nimi
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Skript kontrollib kontrollsummasid, kopeerib uuendatud failid `/etc/ocsp/`-i ja
laadib `ocspserver` deemoni uuesti `rcctl` kaudu. Kui `appsettings.json`-is on
`EnableIndexTxtWatch` väärtus `true`, võtab OCSP-server `index.txt` muudatused
automaatselt vastu ilma uuesti laadimata.

### 7 — Kontrollige OCSP vastuseid

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Nimekonventsioonid

| Fail | Muster |
|------|--------|
| Vahepealse CA võti | `intermediate-PROJECT-DATE.key.pem` |
| Vahepealse CA sertifikaat | `intermediate-PROJECT-DATE.cert.pem` |
| Sertifikaadi ahel | `ca-chain-PROJECT-DATE.cert.pem` |
| Serveri sertifikaat | `SERVER_DOMAIN.DATE.cert.pem` |
| Serveri PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Kliendi sertifikaat | `client-USER_EMAIL.DATE.cert.pem` |
| Kliendi PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| OCSP allkirjastamise sertifikaat | `INTER_NAME-ocsp.cert.pem` |

---

## Turvamärkused

- Võrguühenduseta CA masinat **ei tohi kunagi võrguga ühendada**.
- Juure ja vahepealse CA privaatvõtmed on AES-256-krüpteeritud. Hoidke paroollaused
  riistvara-tokenil või füüsilises seifis, võtmetest eraldi.
- Kontrollige USB-mälupulga kontrollsummasid alati enne importimist — `import-from-usb.sh`
  teeb seda automaatselt OpenBSD `sha256 -C` abil.
- CRL-id aeguvad vaikimisi 30 päeva pärast. Planeerige regulaarne CRL-i uuendamine:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # seejärel export-to-usb + import-from-usb
  ```
- OCSP allkirjastamise sertifikaadid aeguvad 375 päeva pärast. Uuendage neid, käivitades
  `create-intermediate-ca.sh` uuesti samade argumentidega; juba lõpetatud sammud
  jäetakse vahele ja luuakse ainult uus OCSP sertifikaat vajadusel.
