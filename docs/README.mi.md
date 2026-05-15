# CAGenerationAndMaintenance

He kāpura reo anga mō te whakahaere i tētahi **Mana Tiaki Tūtohu (CA) kāhore hononga
ki te ipurangi, kua wehewehea** i runga i OpenBSD mā te OpenSSL. Ka whakaputaina te
āhua whakakorehia mā tētahi
[Tūmau OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer) motuhake.
Ka tukuna ngā whakahōunga i waenga i te rorohiko CA kore-ipurangi me te rorohiko
tūmau OCSP mā tētahi kapewhiti USB.

---

## Mahere tuku (whakakīa tēnei i mua i te whakahaere script)

Whakaritea ō uara tuku i mua i te whakahaere i ngā hikoinga kei raro nei:

- Kei hea te CA?  
  default: `/root/ca`  
  tūturu:

- He aha te whakahaere, ā, kei hea?  
  default: `My Organization`  
  tūturu:

- He aha te ingoa kaupapa?  
  default: `MY PROJECT`  
  tūturu:

- Āhea te rā putanga o te kaupapa?  
  default: `01012027`  
  tūturu:

- He aha te TLD?  
  default: `example.com`  
  tūturu:

- He aha te subdomain?  
  default: `app.`  
  tūturu:

- He aha te wāhitau īmēra mō ngā kaiwhakamahi kiritaki?  
  default: `user@example.com`  
  tūturu:

- Kei hea te puku USB mō te whakawhiti?  
  default: `/dev/sd1i`  
  tūturu:

---

## Tirohanga Whakaahua

```
┌─────────────────────────────┐        Kapewhiti USB    ┌──────────────────────────┐
│   Rorohiko CA (kore-ipurangi)│  ───────────────────►  │  Rorohiko Tūmau OCSP    │
│   (OpenBSD, wehewehe)       │  export-to-usb.sh        │  (OpenBSD, ipurangi)     │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  kawe tinana             │  /etc/ocsp/              │
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

## Ngā Āhuatanga Tuatahi

Ka whakamahi rorohiko e rua i **OpenBSD**. Tūtūhia OpenSSL mēnā kāhore:

```sh
pkg_add openssl
```

Me tūtūhia anō e te rorohiko tūmau OCSP te
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer), ka rēhitatia hei
ratonga rc.d ko te ingoa `ocspserver`.

Ka whakamahi ngā kāpura katoa i `#!/bin/sh` (OpenBSD `/bin/sh` i hangaia ki ksh), ngā
tūranga OpenBSD paerewa (`mount_msdos`, `sha256`, `rcctl`, `doas`), me `openssl(1)`.
Whakahaerehia ngā kāpura katoa hei root mā te `doas`.

---

## Hōhonu Kōnae

```
scripts/
  setup-ca.sh               Whakarite ngā kōpaki CA pakiaka, hanga kī/tūtohu pakiaka
  create-intermediate-ca.sh Hangaia he CA waenganui i hainatia e te CA pakiaka
  create-server-cert.sh     Tukuna tētahi tūtohu tūmau TLS (mTLS)
  create-client-cert.sh     Tukuna tētahi tūtohu kiritaki (mTLS)
  revoke-cert.sh            Whakakorehia tētahi tūtohu, hanga anō i te CRL
  export-to-usb.sh          Whakaputaina ngā raraunga CA ki USB mō tuku wehewehe (taha CA)
  import-from-usb.sh        Kawemai i USB ki tūmau OCSP (taha tūmau OCSP)

config/
  openssl-root.cnf.template          Tauira whirihoranga OpenSSL mō CA pakiaka
  openssl-intermediate.cnf.template  Tauira whirihoranga OpenSSL mō CA waenganui
```

---

## Ngā Tautuhinga Hīkoi ki Hīkoi

### 1 — Whakarite i te CA Pakiaka  *(rorohiko CA kore-ipurangi, kotahi wā)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Hangaia `/root/ca/`, hanga kī pakiaka 4096-bit i whakamūkua e AES-256, tūtohu
hainanga-ā-anō e mana ana mō ngā tau 20, me tūtohu haina OCSP mō te CA pakiaka.

### 2 — Hangaia he CA Waenganui  *(rorohiko CA kore-ipurangi, kotahi wā mō ia kaupeka)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Ka hangaia ngā kōnae i raro o `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Tukuna Tūtohu Tūmau  *(rorohiko CA kore-ipurangi)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Ngā putanga ki roto i te kōpaki CA waenganui:
- `private/app.example.com.01012027.key.pem` — kī tūmataiti whakamūkua
- `certs/app.example.com.01012027.cert.pem` — tūtohu hainanga
- `certs/app.example.com.01012027.server.full.pfx` — pūkete PKCS#12

### 4 — Tukuna Ngā Tūtohu Kiritaki  *(rorohiko CA kore-ipurangi)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Tukurua mō ia kaiwhakamahi. Tukuna ia pūkete `.full.pfx` ki te kaiwhakamahi e tika ana
mā tētahi ararau haumaru.

### 5 — Whakakorehia Tētahi Tūtohu  *(rorohiko CA kore-ipurangi)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Ki te whakahōu i te CRL me te kore whakakorehanga (hei tauira, i runga i tāima):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Tuku ki Tūmau OCSP mā USB  *(tikanga mahi wehewehe)*

#### I te Rorohiko CA Kore-ipurangi

Whakaūhia he kapewhiti USB ā-FAT32. Whakamautia te pūrere:

```sh
dmesg | tail -20          # kimihia ngā rārangi "sd1 at ..."
disklabel sd1             # tautuhia te wāhanga FAT32 (ko 'i' i te nuinga o ngā wā)
```

Nā, kaweake:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Ka tuhia e te kāpura he rārangi SHA256 ā, ka whakamātatia te kapewhiti haumaru.
Kawea tinana te kapewhiti USB ki te rorohiko tūmau OCSP.

#### I te Rorohiko Tūmau OCSP

```sh
dmesg | tail -20          # whakamautia te ingoa pūrere USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Ka tirotiro te kāpura i ngā tapeke SHA256, ka tāruarua ngā kōnae hōu ki `/etc/ocsp/`,
ā, ka uta anō i te kikorangi `ocspserver` mā `rcctl`. Mēnā ko `EnableIndexTxtWatch`
te `true` i `appsettings.json`, ka tango anō te tūmau OCSP i ngā hurihanga `index.txt`
ā-aunoa me te kore uta anō.

### 7 — Manatokohia Ngā Whakautu OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Tikanga Ingoa

| Kōnae | Tauira |
|-------|--------|
| Kī CA Waenganui | `intermediate-PROJECT-DATE.key.pem` |
| Tūtohu CA Waenganui | `intermediate-PROJECT-DATE.cert.pem` |
| Raupapa Tūtohu | `ca-chain-PROJECT-DATE.cert.pem` |
| Tūtohu Tūmau | `SERVER_DOMAIN.DATE.cert.pem` |
| PKCS#12 Tūmau | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Tūtohu Kiritaki | `client-USER_EMAIL.DATE.cert.pem` |
| PKCS#12 Kiritaki | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Tūtohu Haina OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Ngā Tuhipoka Haumaru

- **Kaua** e honoa te rorohiko CA kore-ipurangi ki tētahi whatunga.
- Ka whakamūkua ngā kī tūmataiti pakiaka me waenganui i AES-256. Tiakina ngā kupu
  muna i tētahi tohu pūmārō me tētahi kete haumaru tinana, wehewehe atu i ngā kī.
- Manatokohia ngā tapeke SHA256 o te kapewhiti USB i mua i te kawetanga mai —
  ka mahia tēnei aunoa e `import-from-usb.sh` mā `sha256 -C` o OpenBSD.
- Ka pau te CRL i muri i ngā rā 30 i te taunoa. Whakaritea te whakahōunga CRL auau:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # nā ka export-to-usb + import-from-usb
  ```
- Ka pau ngā tūtohu haina OCSP i muri i ngā rā 375. Whakahōua mā te whakahaere anō
  i `create-intermediate-ca.sh` mē ōna tāupiri anō; ka pahemo ngā hīkoi kua oti,
  ka hanga anō he tūtohu OCSP hou i te wā e hiahiatia ana noa iho.
