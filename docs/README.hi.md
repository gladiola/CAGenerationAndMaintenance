# CAGenerationAndMaintenance

OpenSSL का उपयोग करके OpenBSD पर **ऑफ़लाइन, एयर-गैप्ड सर्टिफिकेट अथॉरिटी (CA)** चलाने
के लिए शेल स्क्रिप्ट। रद्दीकरण स्थिति एक अलग
[OpenBSD OCSP सर्वर](https://github.com/gladiola/OpenBSDOCSPServer) के माध्यम से
प्रकाशित की जाती है। अपडेट USB ड्राइव के माध्यम से ऑफ़लाइन CA मशीन और OCSP सर्वर
मशीन के बीच स्थानांतरित किए जाते हैं।

---

## आर्किटेक्चर अवलोकन

```
┌─────────────────────────────┐        USB ड्राइव      ┌──────────────────────────┐
│   ऑफ़लाइन CA मशीन          │  ───────────────────►   │  OCSP सर्वर मशीन        │
│   (OpenBSD, एयर-गैप्ड)     │  export-to-usb.sh        │  (OpenBSD, नेटवर्क्ड)   │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  भौतिक परिवहन           │  /etc/ocsp/              │
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

## पूर्वापेक्षाएँ

दोनों मशीनें **OpenBSD** चलाती हैं। यदि OpenSSL पहले से मौजूद नहीं है तो इसे
इंस्टॉल करें:

```sh
pkg_add openssl
```

OCSP सर्वर मशीन को `ocspserver` नामक rc.d सेवा के रूप में इंस्टॉल और पंजीकृत
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) की भी आवश्यकता है।

सभी स्क्रिप्ट `#!/bin/sh` (OpenBSD का ksh-आधारित `/bin/sh`), मानक OpenBSD
यूटिलिटीज़ (`mount_msdos`, `sha256`, `rcctl`, `doas`) और `openssl(1)` का उपयोग
करती हैं। सभी स्क्रिप्ट `doas` के माध्यम से root के रूप में चलाएं।

---

## फ़ाइल लेआउट

```
scripts/
  setup-ca.sh               रूट CA डायरेक्टरी प्रारंभ करें और रूट की/सर्टिफिकेट जेनरेट करें
  create-intermediate-ca.sh रूट CA द्वारा हस्ताक्षरित एक नामित इंटरमीडिएट CA बनाएं
  create-server-cert.sh     TLS सर्वर सर्टिफिकेट जारी करें (mTLS)
  create-client-cert.sh     क्लाइंट सर्टिफिकेट जारी करें (mTLS)
  revoke-cert.sh            सर्टिफिकेट रद्द करें और CRL पुनर्जनित करें
  export-to-usb.sh          एयर-गैप ट्रांसफर के लिए CA डेटा USB पर पैकेज करें (CA पक्ष)
  import-from-usb.sh        USB से OCSP सर्वर में आयात करें (OCSP सर्वर पक्ष)

config/
  openssl-root.cnf.template          रूट CA OpenSSL कॉन्फिग टेम्पलेट
  openssl-intermediate.cnf.template  इंटरमीडिएट CA OpenSSL कॉन्फिग टेम्पलेट
```

---

## चरण-दर-चरण उपयोग

### 1 — रूट CA प्रारंभ करें  *(ऑफ़लाइन CA मशीन, एक बार)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

`/root/ca/` बनाता है, AES-256-एन्क्रिप्टेड 4096-बिट रूट की, 20 वर्षों के लिए
वैध स्व-हस्ताक्षरित सर्टिफिकेट, और रूट CA के लिए OCSP साइनिंग सर्टिफिकेट जनरेट
करता है।

### 2 — इंटरमीडिएट CA बनाएं  *(ऑफ़लाइन CA मशीन, प्रत्येक प्रोजेक्ट के लिए एक बार)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

फ़ाइलें `/root/ca/intermediate-MY-PROJECT-01012027/` के अंतर्गत बनाई जाती हैं।

### 3 — सर्वर सर्टिफिकेट जारी करें  *(ऑफ़लाइन CA मशीन)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

इंटरमीडिएट CA डायरेक्टरी में आउटपुट:
- `private/app.example.com.01012027.key.pem` — एन्क्रिप्टेड प्राइवेट की
- `certs/app.example.com.01012027.cert.pem` — हस्ताक्षरित सर्टिफिकेट
- `certs/app.example.com.01012027.server.full.pfx` — PKCS#12 बंडल

### 4 — क्लाइंट सर्टिफिकेट जारी करें  *(ऑफ़लाइन CA मशीन)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

प्रत्येक उपयोगकर्ता के लिए दोहराएं। प्रत्येक `.full.pfx` बंडल को संबंधित उपयोगकर्ता
को सुरक्षित चैनल के माध्यम से स्थानांतरित करें।

### 5 — सर्टिफिकेट रद्द करें  *(ऑफ़लाइन CA मशीन)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

कुछ भी रद्द किए बिना CRL नवीनीकृत करें (जैसे नियमित आधार पर):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — USB के माध्यम से OCSP सर्वर पर स्थानांतरण  *(एयर-गैप वर्कफ़्लो)*

#### ऑफ़लाइन CA मशीन पर

FAT32-फॉर्मेटेड USB ड्राइव डालें। डिवाइस की पुष्टि करें:

```sh
dmesg | tail -20          # "sd1 at ..." लाइनें देखें
disklabel sd1             # FAT32 पार्टीशन पहचानें (आमतौर पर 'i')
```

फिर एक्सपोर्ट करें:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

स्क्रिप्ट `SHA256` चेकसम मेनिफेस्ट लिखती है और ड्राइव को सुरक्षित रूप से
अनमाउंट करती है। USB ड्राइव को OCSP सर्वर मशीन पर भौतिक रूप से ले जाएं।

#### OCSP सर्वर मशीन पर

```sh
dmesg | tail -20          # USB डिवाइस नाम की पुष्टि करें
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

स्क्रिप्ट चेकसम सत्यापित करती है, अपडेट की गई फ़ाइलें `/etc/ocsp/` में कॉपी करती
है, और `rcctl` के माध्यम से `ocspserver` डेमॉन पुनः लोड करती है। यदि
`appsettings.json` में `EnableIndexTxtWatch` `true` है, तो OCSP सर्वर बिना पुनः
लोड किए `index.txt` परिवर्तन भी स्वचालित रूप से उठाएगा।

### 7 — OCSP प्रतिक्रियाएं सत्यापित करें

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## नामकरण परंपराएं

| फ़ाइल | पैटर्न |
|-------|--------|
| इंटरमीडिएट CA की | `intermediate-PROJECT-DATE.key.pem` |
| इंटरमीडिएट CA सर्टिफिकेट | `intermediate-PROJECT-DATE.cert.pem` |
| सर्टिफिकेट चेन | `ca-chain-PROJECT-DATE.cert.pem` |
| सर्वर सर्टिफिकेट | `SERVER_DOMAIN.DATE.cert.pem` |
| सर्वर PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| क्लाइंट सर्टिफिकेट | `client-USER_EMAIL.DATE.cert.pem` |
| क्लाइंट PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| OCSP साइनिंग सर्टिफिकेट | `INTER_NAME-ocsp.cert.pem` |

---

## सुरक्षा नोट्स

- ऑफ़लाइन CA मशीन को **कभी भी नेटवर्क से कनेक्ट नहीं किया जाना चाहिए**।
- रूट और इंटरमीडिएट प्राइवेट की AES-256 एन्क्रिप्टेड हैं। पासफ़्रेज़ को हार्डवेयर
  टोकन या भौतिक तिजोरी में की से अलग स्टोर करें।
- आयात से पहले हमेशा USB ड्राइव चेकसम सत्यापित करें — `import-from-usb.sh` OpenBSD
  के `sha256 -C` का उपयोग करके स्वचालित रूप से यह करती है।
- CRL डिफ़ॉल्ट रूप से 30 दिनों के बाद समाप्त होती हैं। नियमित CRL नवीनीकरण
  शेड्यूल करें:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # फिर export-to-usb + import-from-usb
  ```
- OCSP साइनिंग सर्टिफिकेट 375 दिनों के बाद समाप्त होते हैं। समान तर्कों के साथ
  `create-intermediate-ca.sh` पुनः चलाकर इन्हें नवीनीकृत करें; पहले से पूर्ण
  चरण छोड़ दिए जाते हैं और केवल आवश्यक होने पर नया OCSP सर्टिफिकेट जनरेट किया
  जाता है।
