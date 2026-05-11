# CAGenerationAndMaintenance

Script di shell per gestire un'**Autorità di Certificazione (CA) offline e air-gapped**
su OpenBSD tramite OpenSSL. Lo stato di revoca è pubblicato attraverso un
[server OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer) separato.
Gli aggiornamenti vengono trasferiti tra la macchina CA offline e la macchina server
OCSP tramite unità USB.

---

## Panoramica dell'architettura

```
┌─────────────────────────────┐        Unità USB        ┌──────────────────────────┐
│   Macchina CA offline       │  ───────────────────►   │  Macchina server OCSP    │
│   (OpenBSD, air-gapped)     │  export-to-usb.sh        │  (OpenBSD, in rete)      │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  trasporto fisico        │  /etc/ocsp/              │
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

## Prerequisiti

Entrambe le macchine eseguono **OpenBSD**. Installare OpenSSL se non è già presente:

```sh
pkg_add openssl
```

La macchina server OCSP necessita anche di
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) installato e
registrato come servizio rc.d chiamato `ocspserver`.

Tutti gli script usano `#!/bin/sh` (il `/bin/sh` basato su ksh di OpenBSD), le utility
standard di OpenBSD (`mount_msdos`, `sha256`, `rcctl`, `doas`) e `openssl(1)`.
Eseguire tutti gli script come root tramite `doas`.

---

## Struttura dei file

```
scripts/
  setup-ca.sh               Inizializza le directory della CA radice e genera la chiave/certificato radice
  create-intermediate-ca.sh Crea una CA intermedia firmata dalla CA radice
  create-server-cert.sh     Emette un certificato server TLS (mTLS)
  create-client-cert.sh     Emette un certificato client (mTLS)
  revoke-cert.sh            Revoca un certificato e rigenera la CRL
  export-to-usb.sh          Pacchettizza i dati CA su USB per il trasferimento air-gap (lato CA)
  import-from-usb.sh        Importa da USB nel server OCSP (lato server OCSP)

config/
  openssl-root.cnf.template          Template di configurazione OpenSSL per CA radice
  openssl-intermediate.cnf.template  Template di configurazione OpenSSL per CA intermedia
```

---

## Utilizzo passo per passo

### 1 — Inizializzare la CA radice  *(macchina CA offline, una volta)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Crea `/root/ca/`, genera una chiave radice da 4096 bit cifrata AES-256, un certificato
autofirmato valido 20 anni e un certificato di firma OCSP per la CA radice.

### 2 — Creare una CA intermedia  *(macchina CA offline, una volta per progetto)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

I file vengono creati in `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Emettere un certificato server  *(macchina CA offline)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Output nella directory della CA intermedia:
- `private/app.example.com.01012027.key.pem` — chiave privata cifrata
- `certs/app.example.com.01012027.cert.pem` — certificato firmato
- `certs/app.example.com.01012027.server.full.pfx` — bundle PKCS#12

### 4 — Emettere certificati client  *(macchina CA offline)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Ripetere per ogni utente. Trasferire ogni bundle `.full.pfx` al rispettivo utente
tramite un canale sicuro.

### 5 — Revocare un certificato  *(macchina CA offline)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Per rinnovare la CRL senza revocare (es. periodicamente):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Trasferimento al server OCSP via USB  *(flusso di lavoro air-gap)*

#### Sulla macchina CA offline

Inserire un'unità USB formattata FAT32. Confermare il dispositivo:

```sh
dmesg | tail -20          # cercare righe "sd1 at ..."
disklabel sd1             # identificare la partizione FAT32 (di solito 'i')
```

Poi esportare:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Lo script scrive un manifesto di checksum `SHA256` e smonta l'unità in modo sicuro.
Trasportare fisicamente l'unità USB alla macchina server OCSP.

#### Sulla macchina server OCSP

```sh
dmesg | tail -20          # confermare il nome del dispositivo USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Lo script verifica i checksum, copia i file aggiornati in `/etc/ocsp/` e ricarica il
daemon `ocspserver` tramite `rcctl`. Se `EnableIndexTxtWatch` è `true` in
`appsettings.json`, il server OCSP rileverà anche le modifiche a `index.txt`
automaticamente senza un ricaricamento.

### 7 — Verificare le risposte OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Convenzioni di denominazione

| File | Schema |
|------|--------|
| Chiave CA intermedia | `intermediate-PROJECT-DATE.key.pem` |
| Certificato CA intermedia | `intermediate-PROJECT-DATE.cert.pem` |
| Catena di certificati | `ca-chain-PROJECT-DATE.cert.pem` |
| Certificato server | `SERVER_DOMAIN.DATE.cert.pem` |
| PKCS#12 server | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Certificato client | `client-USER_EMAIL.DATE.cert.pem` |
| PKCS#12 client | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Certificato di firma OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Note sulla sicurezza

- La macchina CA offline **non deve mai essere connessa a una rete**.
- Le chiavi private radice e intermedia sono cifrate con AES-256. Conservare le
  passphrase in un token hardware o in una cassaforte fisica, separatamente dalle chiavi.
- Verificare sempre i checksum dell'unità USB prima di importare — `import-from-usb.sh`
  lo fa automaticamente usando `sha256 -C` di OpenBSD.
- Le CRL scadono dopo 30 giorni per impostazione predefinita. Pianificare il rinnovo
  periodico:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # poi export-to-usb + import-from-usb
  ```
- I certificati di firma OCSP scadono dopo 375 giorni. Rinnovarli eseguendo di nuovo
  `create-intermediate-ca.sh` con gli stessi argomenti; i passaggi già completati
  vengono saltati e viene generato solo un nuovo certificato OCSP.
