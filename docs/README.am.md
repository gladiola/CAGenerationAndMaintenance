# CAGenerationAndMaintenance

የ shell ስክሪፖች ለ **ከበይነ መረብ ተነጥሎ የሚሠራ የምስክር ወረቀት ባለሥልጣን (CA)** ማስተዳደሪያ
በ OpenBSD ላይ OpenSSL ተጠቅሞ። የሚሰረዝ ምስክር ወረቀቶች ሁኔታ በተለዩ
[OpenBSD OCSP አገልጋይ](https://github.com/gladiola/OpenBSDOCSPServer) ታትሟል።
ዝማኔዎች በ USB ማህደረ ትዝታ አማካኝነት ከ offline CA ማሽን ወደ OCSP አገልጋይ ማሽን
ይተላለፋሉ።

---

## የስነ-ሕንፃ ክለሳ

```
┌─────────────────────────────┐        USB ማህደረ ትዝታ   ┌──────────────────────────┐
│   Offline CA ማሽን           │  ───────────────────►   │  OCSP አገልጋይ ማሽን         │
│   (OpenBSD, ከበይነ-መረብ ተነጥሎ)│  export-to-usb.sh        │  (OpenBSD, ተቀናጅቷል)      │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  አካላዊ ማጓጓዝ             │  /etc/ocsp/              │
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

## ቅድመ-ሁኔታዎች

ሁለቱም ማሽኖች **OpenBSD** ያሄዳሉ። OpenSSL ካልተጫነ ይጫኑ:

```sh
pkg_add openssl
```

የ OCSP አገልጋይ ማሽን እንዲሁ `ocspserver` በሚባለው rc.d አገልግሎት ተጭኖ የተመዘገበ
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) ያስፈልጋል።

ሁሉም ስክሪፖች `#!/bin/sh` (የ OpenBSD ksh-ተኮር `/bin/sh`)፣ መደበኛ OpenBSD
ዩቲሊቲዎች (`mount_msdos`፣ `sha256`፣ `rcctl`፣ `doas`) እና `openssl(1)` ይጠቀማሉ።
ሁሉም ስክሪፖችን root ሆነው `doas` ተጠቅሞ ያስሩ።

---

## የፋይል አቀማመጥ

```
scripts/
  setup-ca.sh               ሥር CA ዳይሬክቶሪዎችን አስጀምር እና ሥር ቁልፍ/ምስክር ወረቀት ፍጠር
  create-intermediate-ca.sh በሥር CA የተፈረመ መካከለኛ CA ፍጠር
  create-server-cert.sh     TLS አገልጋይ ምስክር ወረቀት አውጣ (mTLS)
  create-client-cert.sh     ደንበኛ ምስክር ወረቀት አውጣ (mTLS)
  revoke-cert.sh            ምስክር ወረቀት ሰርዝ እና CRL እንደገና ፍጠር
  export-to-usb.sh          ለ air-gap ማስተላለፊያ CA ዳታ ወደ USB ሸጉጥ (CA ጎን)
  import-from-usb.sh        ከ USB ወደ OCSP አገልጋይ አስገባ (OCSP አገልጋይ ጎን)

config/
  openssl-root.cnf.template          ሥር CA OpenSSL ውቅር አብነት
  openssl-intermediate.cnf.template  መካከለኛ CA OpenSSL ውቅር አብነት
```

---

## የማስፈንጠሪያ ዕቅድ (ስክሪፕቶችን ከማስኬድ በፊት ይህን ይሙሉ)

ከታች ያሉትን ደረጃዎች ከመከተልዎ በፊት የማስፈንጠሪያ እሴቶችዎን ያዘጋጁ፡

- CA የት ይሆናል?  
  default: `/root/ca`  
  ትክክለኛ:

- ድርጅቱ ምንድነው እና የት ነው?  
  default: `My Organization`  
  ትክክለኛ:

- የፕሮጀክቱ ስም ምንድነው?  
  default: `MY PROJECT`  
  ትክክለኛ:

- ፕሮጀክቱ በምን ቀን ይቨርዥናል?  
  default: `01012027`  
  ትክክለኛ:

- TLD ምንድነው?  
  default: `example.com`  
  ትክክለኛ:

- ንዑስ ጎራው ምንድነው?  
  default: `app.`  
  ትክክለኛ:

- ለደንበኛ ተጠቃሚ(ዎች) የኢሜይል አድራሻ ምንድነው?  
  default: `user@example.com`  
  ትክክለኛ:

- ለማስተላለፊያ የUSB ድራይቭ የት ነው?  
  default: `/dev/sd1i`  
  ትክክለኛ:

---

## ደረጃ-በ-ደረጃ አጠቃቀም

### 1 — ሥር CA አስጀምር  *(offline CA ማሽን፣ አንድ ጊዜ)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

`/root/ca/` ይፈጥራል፣ AES-256 የተሻሻለ 4096-bit ሥር ቁልፍ፣ ለ20 ዓመት የሚሠራ
የራሱ-ፈራሚ ምስክር ወረቀት፣ እና ለሥር CA OCSP ፊርማ ምስክር ወረቀት ያመርታል።

### 2 — መካከለኛ CA ፍጠር  *(offline CA ማሽን፣ በፕሮጀክት አንድ ጊዜ)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

ፋይሎች ከ `/root/ca/intermediate-MY-PROJECT-01012027/` ሥር ይፈጠራሉ።

### 3 — አገልጋይ ምስክር ወረቀት አውጣ  *(offline CA ማሽን)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

ወደ መካከለኛ CA ዳይሬክቶሪ ውፅዓት:
- `private/app.example.com.01012027.key.pem` — ምስጠራ ግላዊ ቁልፍ
- `certs/app.example.com.01012027.cert.pem` — የተፈረመ ምስክር ወረቀት
- `certs/app.example.com.01012027.server.full.pfx` — PKCS#12 ጥቅል

### 4 — ደንበኛ ምስክር ወረቀቶች አውጣ  *(offline CA ማሽን)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

ለእያንዳንዱ ተጠቃሚ ይድገሙ። እያንዳንዱን `.full.pfx` ጥቅል ለሚመለከተው ተጠቃሚ
ደህንነቱ በተጠበቀ ቻናል ያስተላልፉ።

### 5 — ምስክር ወረቀት ሰርዝ  *(offline CA ማሽን)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

ምንም ሳይሰርዝ CRL ለማደስ (ለምሳሌ በጊዜ ሰሌዳ):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — ወደ OCSP አገልጋይ USB በኩል ማስተላለፍ  *(air-gap የሥራ ሂደት)*

#### ในの offline CA ማሽን ላይ

FAT32-ቀረፀ USB ያስገቡ። መሣሪያ ያረጋግጡ:

```sh
dmesg | tail -20          # "sd1 at ..." ሰጠሮችን ይፈልጉ
disklabel sd1             # FAT32 ክፋይ ያወቁ (ብዙ ጊዜ 'i')
```

ከዚያ ወደ ውጪ ያምጡ:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

ስክሪፕቱ SHA256 ቼክሰም ዝርዝር ይጽፋል እና ዲስኩን ደህንነቱ በተጠበቀ ሁኔታ ያላቅቃል።
USB ዲስኩን አካላዊ ሆኖ ወደ OCSP አገልጋይ ማሽን ይዘዋ።

#### OCSP አገልጋይ ማሽን ላይ

```sh
dmesg | tail -20          # USB መሣሪያ ስም ያረጋግጡ
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

ስክሪፕቱ ቼክሰሞችን ያረጋግጣል፣ ዝማኔ ፋይሎችን ወደ `/etc/ocsp/` ይቅዳል፣ እና
`rcctl` አማካኝነት `ocspserver` daemon እንደገና ይጭናል። `appsettings.json`
ውስጥ `EnableIndexTxtWatch` `true` ከሆነ፣ OCSP አገልጋዩ `index.txt` ለውጦችን
ሳይጫን በቀጥታ ይወስዳል።

### 7 — OCSP ምላሾችን ያረጋግጡ

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## የስም ስምምነቶች

| ፋይል | ቅርጸ-ቁምፊ |
|------|----------|
| መካከለኛ CA ቁልፍ | `intermediate-PROJECT-DATE.key.pem` |
| መካከለኛ CA ምስክር ወረቀት | `intermediate-PROJECT-DATE.cert.pem` |
| ምስክር ወረቀት ሰንሰለት | `ca-chain-PROJECT-DATE.cert.pem` |
| አገልጋይ ምስክር ወረቀት | `SERVER_DOMAIN.DATE.cert.pem` |
| አገልጋይ PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| ደንበኛ ምስክር ወረቀት | `client-USER_EMAIL.DATE.cert.pem` |
| ደንበኛ PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| OCSP ፊርማ ምስክር ወረቀት | `INTER_NAME-ocsp.cert.pem` |

---

## የደህንነት ማስታወሻዎች

- Offline CA ማሽን **ወደ ምንም ኔትወርክ ፈጽሞ መገናኘት የለበትም**።
- ሥር እና መካከለኛ ግላዊ ቁልፎች AES-256 ምስጥሩ ናቸው። ፓስፍሬዞችን ከቁልፎቹ ተለይቶ
  በሃርድዌር ቶከን ወይም አካላዊ ቮልት ውስጥ ያስቀምጡ።
- ከማስገባቱ ቀደም USB ቼክሰሞችን ሁልጊዜ ያረጋግጡ — `import-from-usb.sh` ይህን
  OpenBSD `sha256 -C` ተጠቅሞ በራሱ ያደርጋል።
- CRL ዎች በነባሪ ሁኔታ ከ30 ቀን በኋላ ያልፋሉ። መደበኛ CRL ዝማኔ ያዘጋጁ:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # ከዚያ export-to-usb + import-from-usb
  ```
- OCSP ፊርማ ምስክር ወረቀቶች ከ375 ቀን በኋላ ያልፋሉ። ተመሳሳይ ክርክሮቹን ተጠቅሞ
  `create-intermediate-ca.sh` እንደገና ማስኬድ ይዘምናቸዋል፤ ቀደም ሲሉ የተጠናቀቁ ደረጃዎች
  ይዘለላሉ እና አዲስ OCSP ምስክር ወረቀት ሲያስፈልግ ብቻ ይፈጠራል።
