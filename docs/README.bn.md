# CAGenerationAndMaintenance

OpenSSL ব্যবহার করে OpenBSD-তে **অফলাইন, এয়ার-গ্যাপড সার্টিফিকেট অথরিটি (CA)**
পরিচালনার জন্য শেল স্ক্রিপ্ট। প্রত্যাহার স্থিতি একটি পৃথক
[OpenBSD OCSP সার্ভার](https://github.com/gladiola/OpenBSDOCSPServer) এর মাধ্যমে
প্রকাশিত হয়। আপডেটগুলো USB ড্রাইভের মাধ্যমে অফলাইন CA মেশিন এবং OCSP সার্ভার
মেশিনের মধ্যে স্থানান্তরিত হয়।

---

## আর্কিটেকচারের সারসংক্ষেপ

```
┌─────────────────────────────┐        USB ড্রাইভ      ┌──────────────────────────┐
│   অফলাইন CA মেশিন          │  ───────────────────►   │  OCSP সার্ভার মেশিন     │
│   (OpenBSD, এয়ার-গ্যাপড)   │  export-to-usb.sh        │  (OpenBSD, নেটওয়ার্কড)  │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  শারীরিক পরিবহন         │  /etc/ocsp/              │
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

## পূর্বশর্ত

উভয় মেশিন **OpenBSD** চালায়। OpenSSL না থাকলে ইনস্টল করুন:

```sh
pkg_add openssl
```

OCSP সার্ভার মেশিনের জন্য আরও প্রয়োজন
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) ইনস্টল এবং
`ocspserver` নামে rc.d সার্ভিস হিসেবে নিবন্ধিত।

সকল স্ক্রিপ্ট `#!/bin/sh` (OpenBSD-র ksh-ভিত্তিক `/bin/sh`), মানক OpenBSD
ইউটিলিটি (`mount_msdos`, `sha256`, `rcctl`, `doas`) এবং `openssl(1)` ব্যবহার করে।
সব স্ক্রিপ্ট `doas` এর মাধ্যমে root হিসেবে চালান।

---

## ফাইল বিন্যাস

```
scripts/
  setup-ca.sh               রুট CA ডিরেক্টরি আরম্ভ করুন এবং রুট কী/সার্টিফিকেট তৈরি করুন
  create-intermediate-ca.sh রুট CA দ্বারা স্বাক্ষরিত ইন্টারমিডিয়েট CA তৈরি করুন
  create-server-cert.sh     TLS সার্ভার সার্টিফিকেট ইস্যু করুন (mTLS)
  create-client-cert.sh     ক্লায়েন্ট সার্টিফিকেট ইস্যু করুন (mTLS)
  revoke-cert.sh            সার্টিফিকেট বাতিল করুন এবং CRL পুনরায় তৈরি করুন
  export-to-usb.sh          এয়ার-গ্যাপ ট্রান্সফারের জন্য CA ডেটা USB-এ প্যাকেজ করুন (CA পক্ষ)
  import-from-usb.sh        USB থেকে OCSP সার্ভারে আমদানি করুন (OCSP সার্ভার পক্ষ)

config/
  openssl-root.cnf.template          রুট CA OpenSSL কনফিগ টেমপ্লেট
  openssl-intermediate.cnf.template  ইন্টারমিডিয়েট CA OpenSSL কনফিগ টেমপ্লেট
```

---

## ডিপ্লয়মেন্ট পরিকল্পনা (স্ক্রিপ্ট চালানোর আগে এটি পূরণ করুন)

নিচের ধাপগুলো চালানোর আগে আপনার ডিপ্লয়মেন্ট মানগুলো প্রস্তুত করুন:

- CA কোথায় থাকবে?  
  default: `/root/ca`  
  প্রকৃত:

- সংগঠনের নাম কী এবং এটি কোথায়?  
  default: `My Organization`  
  প্রকৃত:

- প্রকল্পের নাম কী?  
  default: `MY PROJECT`  
  প্রকৃত:

- প্রকল্পের ভার্সন তারিখ কী?  
  default: `01012027`  
  প্রকৃত:

- TLD কী?  
  default: `example.com`  
  প্রকৃত:

- সাবডোমেইন কী?  
  default: `app.`  
  প্রকৃত:

- ক্লায়েন্ট ব্যবহারকারী(দের) ইমেল ঠিকানা কী?  
  default: `user@example.com`  
  প্রকৃত:

- ট্রান্সফারের জন্য USB থাম্ব ড্রাইভ কোথায়?  
  default: `/dev/sd1i`  
  প্রকৃত:

---

## ধাপে ধাপে ব্যবহার

### ১ — রুট CA আরম্ভ করুন  *(অফলাইন CA মেশিন, একবার)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

`/root/ca/` তৈরি করে, AES-256-এনক্রিপ্টেড 4096-বিট রুট কী, ২০ বছর বৈধ স্ব-স্বাক্ষরিত
সার্টিফিকেট, এবং রুট CA-র জন্য OCSP সাইনিং সার্টিফিকেট তৈরি করে।

### ২ — ইন্টারমিডিয়েট CA তৈরি করুন  *(অফলাইন CA মেশিন, প্রতি প্রজেক্টে একবার)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

ফাইলগুলো `/root/ca/intermediate-MY-PROJECT-01012027/` এর অধীনে তৈরি হয়।

### ৩ — সার্ভার সার্টিফিকেট ইস্যু করুন  *(অফলাইন CA মেশিন)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

ইন্টারমিডিয়েট CA ডিরেক্টরিতে আউটপুট:
- `private/app.example.com.01012027.key.pem` — এনক্রিপ্টেড প্রাইভেট কী
- `certs/app.example.com.01012027.cert.pem` — স্বাক্ষরিত সার্টিফিকেট
- `certs/app.example.com.01012027.server.full.pfx` — PKCS#12 বান্ডেল

### ৪ — ক্লায়েন্ট সার্টিফিকেট ইস্যু করুন  *(অফলাইন CA মেশিন)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

প্রতিটি ব্যবহারকারীর জন্য পুনরাবৃত্তি করুন। প্রতিটি `.full.pfx` বান্ডেল সুরক্ষিত
চ্যানেলের মাধ্যমে সংশ্লিষ্ট ব্যবহারকারীকে স্থানান্তর করুন।

### ৫ — সার্টিফিকেট বাতিল করুন  *(অফলাইন CA মেশিন)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

কিছু বাতিল না করে CRL নবায়ন করতে (যেমন নির্ধারিত সময়ে):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### ৬ — USB এর মাধ্যমে OCSP সার্ভারে স্থানান্তর  *(এয়ার-গ্যাপ ওয়ার্কফ্লো)*

#### অফলাইন CA মেশিনে

FAT32-ফরম্যাটেড USB ড্রাইভ ঢোকান। ডিভাইস নিশ্চিত করুন:

```sh
dmesg | tail -20          # "sd1 at ..." লাইন খুঁজুন
disklabel sd1             # FAT32 পার্টিশন চিহ্নিত করুন (সাধারণত 'i')
```

তারপর এক্সপোর্ট করুন:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

স্ক্রিপ্ট একটি SHA256 চেকসাম ম্যানিফেস্ট লেখে এবং ড্রাইভ নিরাপদে আনমাউন্ট করে।
USB ড্রাইভ শারীরিকভাবে OCSP সার্ভার মেশিনে নিয়ে যান।

#### OCSP সার্ভার মেশিনে

```sh
dmesg | tail -20          # USB ডিভাইসের নাম নিশ্চিত করুন
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

স্ক্রিপ্ট চেকসাম যাচাই করে, আপডেট করা ফাইলগুলো `/etc/ocsp/`-এ কপি করে, এবং
`rcctl` এর মাধ্যমে `ocspserver` ডেমন পুনরায় লোড করে। `appsettings.json`-এ
`EnableIndexTxtWatch` `true` হলে OCSP সার্ভার পুনরায় লোড ছাড়াই `index.txt`
পরিবর্তন স্বয়ংক্রিয়ভাবে গ্রহণ করবে।

### ৭ — OCSP প্রতিক্রিয়া যাচাই করুন

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## নামকরণ নিয়মাবলী

| ফাইল | প্যাটার্ন |
|------|----------|
| ইন্টারমিডিয়েট CA কী | `intermediate-PROJECT-DATE.key.pem` |
| ইন্টারমিডিয়েট CA সার্টিফিকেট | `intermediate-PROJECT-DATE.cert.pem` |
| সার্টিফিকেট চেইন | `ca-chain-PROJECT-DATE.cert.pem` |
| সার্ভার সার্টিফিকেট | `SERVER_DOMAIN.DATE.cert.pem` |
| সার্ভার PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| ক্লায়েন্ট সার্টিফিকেট | `client-USER_EMAIL.DATE.cert.pem` |
| ক্লায়েন্ট PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| OCSP সাইনিং সার্টিফিকেট | `INTER_NAME-ocsp.cert.pem` |

---

## নিরাপত্তা নোট

- অফলাইন CA মেশিন **কখনো কোনো নেটওয়ার্কে সংযুক্ত হওয়া উচিত নয়**।
- রুট এবং ইন্টারমিডিয়েট প্রাইভেট কী AES-256 এনক্রিপ্টেড। পাসফ্রেজ হার্ডওয়্যার
  টোকেন বা শারীরিক ভল্টে, কী থেকে আলাদা রাখুন।
- আমদানির আগে সর্বদা USB চেকসাম যাচাই করুন — `import-from-usb.sh` OpenBSD-র
  `sha256 -C` ব্যবহার করে স্বয়ংক্রিয়ভাবে করে।
- CRL ডিফল্টভাবে ৩০ দিন পরে মেয়াদোত্তীর্ণ হয়। নিয়মিত CRL নবায়ন শিডিউল করুন:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # তারপর export-to-usb + import-from-usb
  ```
- OCSP সাইনিং সার্টিফিকেট ৩৭৫ দিন পরে মেয়াদোত্তীর্ণ হয়। একই আর্গুমেন্ট দিয়ে
  `create-intermediate-ca.sh` পুনরায় চালিয়ে নবায়ন করুন; ইতোমধ্যে সম্পন্ন ধাপগুলো
  বাদ দেওয়া হয় এবং শুধুমাত্র প্রয়োজনে নতুন OCSP সার্টিফিকেট তৈরি হয়।
