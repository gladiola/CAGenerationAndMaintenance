# CAGenerationAndMaintenance

Scripteanna blaoisce chun **Údarás Deimhnithe (CA) as líne agus aeridhealaithe**
a oibriú ar OpenBSD ag úsáid OpenSSL. Foilsítear stádas cúlghairme trí
[freastalaí OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer) ar leith.
Aistríodh nuashonruithe idir an meaisín CA as líne agus meaisín an fhreastalaí OCSP
trí thiomántán USB.

---

## Pleanáil imlonnaithe (líon é seo sula rithtear scripteanna)

Ullmhaigh do luachanna imlonnaithe sula ritheann tú na céimeanna thíos:

- Cá mbeidh an CA?  
  default: `/root/ca`  
  iarbhír:

- Cad é an eagraíocht agus cá bhfuil sí?  
  default: `My Organization`  
  iarbhír:

- Cad is ainm don tionscadal?  
  default: `MY PROJECT`  
  iarbhír:

- Cathain a dhéantar leaganú an tionscadail?  
  default: `01012027`  
  iarbhír:

- Cad é an TLD?  
  default: `example.com`  
  iarbhír:

- Cad é an fofhearann?  
  default: `app.`  
  iarbhír:

- Cad é seoladh ríomhphoist úsáideora/úsáideoirí an chliaint?  
  default: `user@example.com`  
  iarbhír:

- Cá bhfuil an tiomántán USB le haghaidh aistrithe?  
  default: `/dev/sd1i`  
  iarbhír:

---

## Forbhreathnú Ailtireachta

```
┌─────────────────────────────┐        Tiomántán USB    ┌──────────────────────────┐
│   Meaisín CA as líne        │  ───────────────────►   │  Meaisín Freastalaí OCSP │
│   (OpenBSD, aeridhealaithe) │  export-to-usb.sh        │  (OpenBSD, i líonra)     │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  iompar fisiciúil        │  /etc/ocsp/              │
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

## Réamhriachtanais

Ritheann an dá mheaisín **OpenBSD**. Suiteáil OpenSSL mura bhfuil sé ann cheana:

```sh
pkg_add openssl
```

Teastaíonn
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) ón meaisín
freastalaí OCSP freisin, suiteáilte agus cláraithe mar sheirbhís rc.d darb ainm
`ocspserver`.

Úsáideann gach scripte `#!/bin/sh` (OpenBSD `/bin/sh` bunaithe ar ksh), fóntais
caighdeánacha OpenBSD (`mount_msdos`, `sha256`, `rcctl`, `doas`), agus `openssl(1)`.
Rith gach scripte mar root trí `doas`.

---

## Leagan Amach Comhaid

```
scripts/
  setup-ca.sh               Túsaíonn comhadlanna CA fréimhe agus gineann eochair/deimhniú fréimhe
  create-intermediate-ca.sh Cruthaíonn CA idirmheánach sínithe ag CA fréimhe
  create-server-cert.sh     Eisíonn deimhniú freastalaí TLS (mTLS)
  create-client-cert.sh     Eisíonn deimhniú cliaint (mTLS)
  revoke-cert.sh            Cúlghairrm deimhniú agus athghineann CRL
  export-to-usb.sh          Pacáistí sonraí CA ar USB le haghaidh aistrithe aeridhealaithe (taobh CA)
  import-from-usb.sh        Iompórtáilann ó USB go freastalaí OCSP (taobh an fhreastalaí OCSP)

config/
  openssl-root.cnf.template          Teimpléad cumraíochta OpenSSL do CA fréimhe
  openssl-intermediate.cnf.template  Teimpléad cumraíochta OpenSSL do CA idirmheánach
```

---

## Úsáid Céim ar Chéim

### 1 — CA Fréimhe a Thúsú  *(meaisín CA as líne, uair amháin)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Cruthaíonn `/root/ca/`, gineann eochair fréimhe 4096-giotán criptithe AES-256,
deimhniú féin-sínithe bailí ar feadh 20 bliana, agus deimhniú sínithe OCSP do CA fréimhe.

### 2 — CA Idirmheánach a Chruthú  *(meaisín CA as líne, uair amháin in aghaidh an tionscadail)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Cruthaítear comhaid faoi `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Deimhniú Freastalaí a Eisiúint  *(meaisín CA as líne)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Aschur i gcomhadlann CA idirmheánach:
- `private/app.example.com.01012027.key.pem` — eochair phríobháideach chriptithe
- `certs/app.example.com.01012027.cert.pem` — deimhniú sínithe
- `certs/app.example.com.01012027.server.full.pfx` — beart PKCS#12

### 4 — Deimhnithe Cliaint a Eisiúint  *(meaisín CA as líne)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Déan arís é do gach úsáideoir. Aistrígh gach beart `.full.pfx` chuig an úsáideoir
cuí trí bhealaí slán.

### 5 — Deimhniú a Chúlghairm  *(meaisín CA as líne)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Chun CRL a athnuachan gan aon rud a chúlghairm (m.sh. de réir sceideal):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Aistriú chuig Freastalaí OCSP trí USB  *(sreabhadh oibre aeridhealaithe)*

#### Ar Mheaisín CA as Líne

Cuir isteach tiomántán USB formáidithe FAT32. Deimhnigh an gléas:

```sh
dmesg | tail -20          # cuardaigh línte "sd1 at ..."
disklabel sd1             # aithnigh deighilt FAT32 (de ghnáth 'i')
```

Ansin easpórtáil:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Scríobhann an scripte mionleitir seiceálacha SHA256 agus díshuiteálann an tiomántán
go sábháilte. Iompair an tiomántán USB go fisiciúil chuig meaisín an fhreastalaí OCSP.

#### Ar Mheaisín Freastalaí OCSP

```sh
dmesg | tail -20          # deimhnigh ainm gléas USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Fíoraíonn an scripte seiceálacha, cóipeálann comhaid nuashonraithe go `/etc/ocsp/`,
agus athluchtaíonn sé daemon `ocspserver` trí `rcctl`. Má tá `EnableIndexTxtWatch`
ina `true` in `appsettings.json`, piocfaidh an freastalaí OCSP suas athruithe
`index.txt` go huathoibríoch gan athluchtú.

### 7 — Freagraí OCSP a Fhíorú

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Coinbhinsiúin Ainmniúcháin

| Comhad | Patrún |
|--------|--------|
| Eochair CA Idirmheánach | `intermediate-PROJECT-DATE.key.pem` |
| Deimhniú CA Idirmheánach | `intermediate-PROJECT-DATE.cert.pem` |
| Slabhra Deimhnithe | `ca-chain-PROJECT-DATE.cert.pem` |
| Deimhniú Freastalaí | `SERVER_DOMAIN.DATE.cert.pem` |
| Freastalaí PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Deimhniú Cliaint | `client-USER_EMAIL.DATE.cert.pem` |
| Cliaint PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Deimhniú Sínithe OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Nótaí Slándála

- **Ná ceangail** meaisín CA as líne le líonra riamh.
- Tá eochracha príobháideacha fréimhe agus idirmheánacha criptithe AES-256. Coinnigh
  frásaí focal faire i gcomhartha crua-earraí nó taisclann fisiciúil, ar leithligh ón
  gceol.
- Fíoraigh seiceálacha tiomántáin USB i gcónaí roimh iompórtáil — déanann
  `import-from-usb.sh` seo go huathoibríoch ag baint úsáide as `sha256 -C` OpenBSD.
- Éagann CRL-anna tar éis 30 lá de réir réamhshocrú. Sceideal athnuachana rialta CRL:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # ansin export-to-usb + import-from-usb
  ```
- Éagann deimhnithe sínithe OCSP tar éis 375 lá. Athnuaigh iad trí `create-intermediate-ca.sh`
  a rith arís leis na hargóintí céanna; léimeann céimeanna atá críochnaithe cheana agus
  ní ghintear ach deimhniú OCSP nua nuair is gá.
