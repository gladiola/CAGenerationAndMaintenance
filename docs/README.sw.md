# CAGenerationAndMaintenance

Hati za shell kwa ajili ya kuendesha **Mamlaka ya Cheti (CA) isiyo mtandaoni na
iliyotengwa na hewa** kwenye OpenBSD kwa kutumia OpenSSL. Hali ya kufutwa inachapishwa
kupitia [seva ya OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer) tofauti.
Masasisho yanahamishwa kati ya mashine ya CA isiyo mtandaoni na mashine ya seva ya
OCSP kwa kutumia gari la USB.

---

## Mipango ya uwekaji (jaza hii kabla ya kuendesha skripti)

Andaa thamani zako za uwekaji kabla ya kuendesha hatua zilizo hapa chini:

- CA itakuwa wapi?  
  default: `/root/ca`  
  halisi:

- Shirika ni lipi na liko wapi?  
  default: `My Organization`  
  halisi:

- Jina la mradi ni nini?  
  default: `MY PROJECT`  
  halisi:

- Tarehe ya toleo la mradi ni ipi?  
  default: `01012027`  
  halisi:

- TLD ni nini?  
  default: `example.com`  
  halisi:

- Subdomain ni ipi?  
  default: `app.`  
  halisi:

- Barua pepe ya mtumiaji wa mteja ni ipi?  
  default: `user@example.com`  
  halisi:

- Kifaa cha USB cha kuhamisha kiko wapi?  
  default: `/dev/sd1i`  
  halisi:

---

## Muhtasari wa Usanifu

```
┌─────────────────────────────┐        Gari la USB      ┌──────────────────────────┐
│   Mashine ya CA (offline)   │  ───────────────────►   │  Mashine ya Seva ya OCSP │
│   (OpenBSD, imetengwa)      │  export-to-usb.sh        │  (OpenBSD, mtandaoni)    │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  kubeba kimwili          │  /etc/ocsp/              │
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

## Mahitaji ya Awali

Mashine zote mbili zinaendesha **OpenBSD**. Sakinisha OpenSSL ikiwa haipo:

```sh
pkg_add openssl
```

Mashine ya seva ya OCSP pia inahitaji
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) iliyosakinishwa na
kusajiliwa kama huduma ya rc.d inayoitwa `ocspserver`.

Hati zote zinatumia `#!/bin/sh` (OpenBSD ya `/bin/sh` inayotegemea ksh), zana za
kawaida za OpenBSD (`mount_msdos`, `sha256`, `rcctl`, `doas`), na `openssl(1)`.
Endesha hati zote kama root kupitia `doas`.

---

## Mpangilio wa Faili

```
scripts/
  setup-ca.sh               Anzisha saraka za CA kuu na tengeneza ufunguo/cheti cha msingi
  create-intermediate-ca.sh Unda CA ya kati iliyosainiwa na CA kuu
  create-server-cert.sh     Toa cheti cha seva ya TLS (mTLS)
  create-client-cert.sh     Toa cheti cha mteja (mTLS)
  revoke-cert.sh            Futa cheti na utengeneze upya CRL
  export-to-usb.sh          Pakiti data ya CA kwenye USB kwa uhamisho wa hewa (upande wa CA)
  import-from-usb.sh        Ingiza kutoka USB hadi seva ya OCSP (upande wa seva ya OCSP)

config/
  openssl-root.cnf.template          Kiolezo cha usanidi wa OpenSSL cha CA kuu
  openssl-intermediate.cnf.template  Kiolezo cha usanidi wa OpenSSL cha CA ya kati
```

---

## Matumizi Hatua kwa Hatua

### 1 — Anzisha CA Kuu  *(mashine ya CA offline, mara moja)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Inaunda `/root/ca/`, inatengeneza ufunguo wa msingi wa biti 4096 uliofichwa kwa
AES-256, cheti kilichosainiwa na chenyewe chenye uhalali wa miaka 20, na cheti cha
kutiwa saini cha OCSP kwa CA kuu.

### 2 — Unda CA ya Kati  *(mashine ya CA offline, mara moja kwa mradi)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Faili zinaundwa chini ya `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Toa Cheti cha Seva  *(mashine ya CA offline)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Matokeo kwenye saraka ya CA ya kati:
- `private/app.example.com.01012027.key.pem` — ufunguo wa siri uliofichwa
- `certs/app.example.com.01012027.cert.pem` — cheti kilichosainiwa
- `certs/app.example.com.01012027.server.full.pfx` — kifurushi cha PKCS#12

### 4 — Toa Vyeti vya Mteja  *(mashine ya CA offline)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Rudia kwa kila mtumiaji. Hamisha kila kifurushi cha `.full.pfx` kwa mtumiaji
husika kupitia njia salama.

### 5 — Futa Cheti  *(mashine ya CA offline)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Kuhuisha CRL bila kufuta chochote (mfano kwa ratiba):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Uhamisho hadi Seva ya OCSP kupitia USB  *(mchakato wa hewa)*

#### Kwenye Mashine ya CA offline

Weka gari la USB lililoundwa kwa FAT32. Thibitisha kifaa:

```sh
dmesg | tail -20          # tafuta mistari ya "sd1 at ..."
disklabel sd1             # tambua kizigeu cha FAT32 (kawaida 'i')
```

Kisha hamisha:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Hati inaandika orodha ya mchoro wa SHA256 na kufuta gari kwa usalama.
Beba gari la USB kimwili hadi mashine ya seva ya OCSP.

#### Kwenye Mashine ya Seva ya OCSP

```sh
dmesg | tail -20          # thibitisha jina la kifaa cha USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Hati inathibitisha mchoro, inakili faili zilizosasishwa hadi `/etc/ocsp/`, na
kupakia upya `ocspserver` daemon kupitia `rcctl`. Ikiwa `EnableIndexTxtWatch` ni
`true` katika `appsettings.json`, seva ya OCSP pia itachukua mabadiliko ya
`index.txt` kiotomatiki bila upakiaji upya.

### 7 — Thibitisha Majibu ya OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Mikataba ya Majina

| Faili | Muundo |
|-------|--------|
| Ufunguo wa CA ya kati | `intermediate-PROJECT-DATE.key.pem` |
| Cheti cha CA ya kati | `intermediate-PROJECT-DATE.cert.pem` |
| Mnyororo wa vyeti | `ca-chain-PROJECT-DATE.cert.pem` |
| Cheti cha seva | `SERVER_DOMAIN.DATE.cert.pem` |
| PKCS#12 ya seva | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Cheti cha mteja | `client-USER_EMAIL.DATE.cert.pem` |
| PKCS#12 ya mteja | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Cheti cha kusaini OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Maelezo ya Usalama

- Mashine ya CA offline **kamwe haipaswi kuunganishwa kwenye mtandao**.
- Vifunguo vya siri vya msingi na vya kati vimefichwa kwa AES-256. Hifadhi misemo
  ya siri katika tokeni ya maunzi au sanduku la usalama la kimwili, tofauti na vifunguo.
- Daima thibitisha mchoro wa USB kabla ya kuingiza — `import-from-usb.sh` hufanya hivi
  kiotomatiki kwa kutumia `sha256 -C` ya OpenBSD.
- CRL zinaisha baada ya siku 30 kwa chaguo-msingi. Panga upya uhusiano wa CRL mara kwa mara:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # kisha export-to-usb + import-from-usb
  ```
- Vyeti vya kusaini OCSP vinaisha baada ya siku 375. Vifanye upya kwa kuendesha tena
  `create-intermediate-ca.sh` kwa hoja sawa; hatua zilizokamilika zinarukwa na cheti
  kipya cha OCSP kinaundwa tu inapohitajika.
