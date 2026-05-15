# CAGenerationAndMaintenance

Scripta testudinaria ad administrandum **Auctoritatem Certificatorum (CA) extra
retis communicationem et ab aliis computatris separatam** in systemate OpenBSD per
OpenSSL. Status revocationis per separatum
[Servientem OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer) publici
iuris fit. Renovationes inter computatrum CA extra retis et computatrum servientis
OCSP per instrumentum USB transferuntur.

---

## Conspectus Architecturae

```
┌─────────────────────────────┐        Instrumentum USB  ┌──────────────────────────┐
│   Computatrum CA (extra rete)│  ──────────────────►   │  Computatrum Serv. OCSP  │
│   (OpenBSD, separatum)       │  export-to-usb.sh        │  (OpenBSD, in rete)      │
│                              │  ◄─────────────────────  │                          │
│  /root/ca/                   │  vectura corporalis       │  /etc/ocsp/              │
│    openssl.cnf               │                           │    index.txt             │
│    certs/ca.cert.pem         │                           │    *.crl.pem             │
│    intermediate-*/           │                           │    *-responder.crt       │
│      index.txt               │                           │  OcspServer (ASP.NET)    │
│      crl/                    │                           │  rcctl enable ocspserver │
│      certs/                  │                           │                          │
│      ocsp/                   │                           │                          │
└─────────────────────────────┘                            └──────────────────────────┘
```

---

## Praerequisita

Utrumque computatrum systemate **OpenBSD** utitur. OpenSSL installa si iam non adest:

```sh
pkg_add openssl
```

Computatrum servientis OCSP etiam
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) installatum et
tamquam servitium rc.d nomine `ocspserver` registratum requirit.

Omnia scripta `#!/bin/sh` (OpenBSD `/bin/sh` e ksh derivatum), utensilia OpenBSD
usualia (`mount_msdos`, `sha256`, `rcctl`, `doas`) et `openssl(1)` adhibent.
Omnia scripta ut radix per `doas` executa.

---

## Dispositio Fasciculorum

```
scripts/
  setup-ca.sh               Indices CA radicis instruit clavemque/certificatum radicis gignit
  create-intermediate-ca.sh CA mediam, a CA radice signatam, creat
  create-server-cert.sh     Certificatum servientis TLS (mTLS) emittit
  create-client-cert.sh     Certificatum clientis (mTLS) emittit
  revoke-cert.sh            Certificatum revocat et CRL regenerat
  export-to-usb.sh          Data CA in USB condit ad transferendum per separationem (a latere CA)
  import-from-usb.sh        Ex USB in servientem OCSP importat (a latere servientis OCSP)

config/
  openssl-root.cnf.template          Formula configurationis OpenSSL pro CA radice
  openssl-intermediate.cnf.template  Formula configurationis OpenSSL pro CA media
```

---

## Consilium dispositionis (hoc exple antequam scripta curras)

Para valores dispositionis antequam gradus infra positos exsequaris:

- Ubi erit CA?  
  default: `/root/ca`  
  revera:

- Quae est institutio et ubi sita est?  
  default: `My Organization`  
  revera:

- Quod est nomen propositi?  
  default: `MY PROJECT`  
  revera:

- Quae est dies versionis propositi?  
  default: `01012027`  
  revera:

- Quid est TLD?  
  default: `example.com`  
  revera:

- Quid est subdominium?  
  default: `app.`  
  revera:

- Quae est inscriptio electronica usoris/clientium?  
  default: `user@example.com`  
  revera:

- Ubi est clavicula USB ad translationem?  
  default: `/dev/sd1i`  
  revera:

---

## Usus Gradatim

### 1 — CA Radicem Instrui  *(computatrum CA extra rete, semel)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

`/root/ca/` creat, clavem radicem 4096-bit AES-256 cryptatam, certificatum
auto-signatum viginti annos validum et certificatum signaturae OCSP pro CA radice gignit.

### 2 — CA Mediam Creare  *(computatrum CA extra rete, semel pro quoque opere)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Fasciculi sub `/root/ca/intermediate-MY-PROJECT-01012027/` creantur.

### 3 — Certificatum Servientis Emittere  *(computatrum CA extra rete)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Exitus in indice CA mediae:
- `private/app.example.com.01012027.key.pem` — clavis privata cryptata
- `certs/app.example.com.01012027.cert.pem` — certificatum signatum
- `certs/app.example.com.01012027.server.full.pfx` — fasciculus PKCS#12

### 4 — Certificata Clientium Emittere  *(computatrum CA extra rete)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Pro unoquoque utente repete. Quemque fasciculum `.full.pfx` ad clientem idoneum
per viam tutam transfer.

### 5 — Certificatum Revocare  *(computatrum CA extra rete)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

CRL renovare sine revocatione (e.g. ex ordine temporario):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Ad Servientem OCSP per USB Transferre  *(operatio per separationem)*

#### In Computatro CA Extra Rete

Instrumentum USB formato FAT32 insere. Machinam confirma:

```sh
dmesg | tail -20          # lineas "sd1 at ..." quaere
disklabel sd1             # partitionem FAT32 nota (plerumque 'i')
```

Deinde exporta:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Scriptum indicem SHA256 scribit et instrumentum tuto demittit.
Instrumentum USB corporaliter ad computatrum servientis OCSP porta.

#### In Computatro Servientis OCSP

```sh
dmesg | tail -20          # nomen instrumenti USB confirma
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Scriptum summas controllantes verificat, fasciculos renovatos in `/etc/ocsp/` copiat
et daemonem `ocspserver` per `rcctl` relocat. Si `EnableIndexTxtWatch` in
`appsettings.json` `true` est, serviens OCSP mutationes `index.txt` quoque
automatice sine reloatione capiet.

### 7 — Responsiones OCSP Verificare

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Conventiones Nominum

| Fasciculus | Exemplar |
|------------|----------|
| Clavis CA Mediae | `intermediate-PROJECT-DATE.key.pem` |
| Certificatum CA Mediae | `intermediate-PROJECT-DATE.cert.pem` |
| Catena Certificatorum | `ca-chain-PROJECT-DATE.cert.pem` |
| Certificatum Servientis | `SERVER_DOMAIN.DATE.cert.pem` |
| Serviens PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Certificatum Clientis | `client-USER_EMAIL.DATE.cert.pem` |
| Clientis PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Certificatum Signaturae OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Notae de Securitate

- Computatrum CA extra rete **numquam ad rete conecti debet**.
- Claves privatae CA radicis et mediae AES-256 cryptatae sunt. Verba tesserarum in
  tessera ferramentaria aut scrinio corporali, separatim a clavibus, serva.
- Summas controllantes instrumenti USB semper ante importationem verifica —
  `import-from-usb.sh` hoc automatice per `sha256 -C` OpenBSD facit.
- CRL post triginta dies exspirare solent. Renovationem periodicam orna:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # deinde export-to-usb + import-from-usb
  ```
- Certificata signaturae OCSP post CCCLXXV dies exspirant. Ea renova iterum
  `create-intermediate-ca.sh` cum eisdem argumentis exsequendo; gradus iam peracti
  praeteruntur et novum certificatum OCSP solum quando necesse est gignitur.
