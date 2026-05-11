# CAGenerationAndMaintenance

سكريبتات شل لتشغيل **هيئة إصدار شهادات (CA) غير متصلة بالشبكة ومعزولة هوائيًا**
على OpenBSD باستخدام OpenSSL. يُنشر حالة الإلغاء عبر خادم
[OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer) منفصل.
تُنقل التحديثات بين جهاز CA غير المتصل وجهاز خادم OCSP عبر محرك USB.

---

## نظرة عامة على البنية

```
┌─────────────────────────────┐        محرك USB         ┌──────────────────────────┐
│   جهاز CA غير المتصل       │  ───────────────────►   │  جهاز خادم OCSP          │
│   (OpenBSD، معزول هوائيًا) │  export-to-usb.sh        │  (OpenBSD، متصل بشبكة)   │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  نقل مادي                │  /etc/ocsp/              │
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

## المتطلبات الأساسية

يعمل كلا الجهازين بنظام **OpenBSD**. ثبّت OpenSSL إن لم يكن موجودًا:

```sh
pkg_add openssl
```

يحتاج جهاز خادم OCSP أيضًا إلى تثبيت
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer)
وتسجيله كخدمة rc.d باسم `ocspserver`.

تستخدم جميع السكريبتات `#!/bin/sh` (نظام `/bin/sh` المبني على ksh في OpenBSD)،
وأدوات OpenBSD القياسية (`mount_msdos`، `sha256`، `rcctl`، `doas`)،
و`openssl(1)`. شغّل جميع السكريبتات بصلاحيات الجذر عبر `doas`.

---

## تخطيط الملفات

```
scripts/
  setup-ca.sh               تهيئة مجلدات CA الجذر وتوليد المفتاح/الشهادة الجذر
  create-intermediate-ca.sh إنشاء CA وسيطة موقّعة من CA الجذر
  create-server-cert.sh     إصدار شهادة خادم TLS (mTLS)
  create-client-cert.sh     إصدار شهادة عميل (mTLS)
  revoke-cert.sh            إلغاء شهادة وإعادة توليد CRL
  export-to-usb.sh          تعبئة بيانات CA على USB للنقل المعزول هوائيًا (جانب CA)
  import-from-usb.sh        الاستيراد من USB إلى خادم OCSP (جانب خادم OCSP)

config/
  openssl-root.cnf.template          قالب إعدادات OpenSSL لـ CA الجذر
  openssl-intermediate.cnf.template  قالب إعدادات OpenSSL لـ CA الوسيطة
```

---

## الاستخدام خطوة بخطوة

### 1 — تهيئة CA الجذر  *(جهاز CA غير المتصل، مرة واحدة)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

ينشئ `/root/ca/`، ويولّد مفتاح جذر 4096 بت مشفر بـ AES-256، وشهادة موقّعة ذاتيًا
صالحة لمدة 20 عامًا، وشهادة توقيع OCSP لـ CA الجذر.

### 2 — إنشاء CA وسيطة  *(جهاز CA غير المتصل، مرة واحدة لكل مشروع)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

تُنشأ الملفات في `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — إصدار شهادة خادم  *(جهاز CA غير المتصل)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

المخرجات في مجلد CA الوسيطة:
- `private/app.example.com.01012027.key.pem` — مفتاح خاص مشفر
- `certs/app.example.com.01012027.cert.pem` — شهادة موقّعة
- `certs/app.example.com.01012027.server.full.pfx` — حزمة PKCS#12

### 4 — إصدار شهادات العملاء  *(جهاز CA غير المتصل)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

كرّر لكل مستخدم. انقل كل حزمة `.full.pfx` إلى المستخدم المعني عبر قناة آمنة.

### 5 — إلغاء شهادة  *(جهاز CA غير المتصل)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

لتجديد CRL دون إلغاء أي شهادة (مثلًا بشكل دوري):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — النقل إلى خادم OCSP عبر USB  *(سير عمل العزل الهوائي)*

#### على جهاز CA غير المتصل

أدخل محرك USB بصيغة FAT32. تأكد من الجهاز:

```sh
dmesg | tail -20          # ابحث عن أسطر "sd1 at ..."
disklabel sd1             # حدد قسم FAT32 (عادةً 'i')
```

ثم صدّر:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

تكتب السكريبت ملف بيان SHA256 وتفصل المحرك بأمان.
انقل محرك USB ماديًا إلى جهاز خادم OCSP.

#### على جهاز خادم OCSP

```sh
dmesg | tail -20          # تأكد من اسم جهاز USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

تتحقق السكريبت من المجاميع الاختبارية، وتنسخ الملفات المحدّثة إلى `/etc/ocsp/`،
وتعيد تحميل الخدمة `ocspserver` عبر `rcctl`. إذا كان `EnableIndexTxtWatch` يساوي
`true` في `appsettings.json`، سيلتقط خادم OCSP أيضًا تغييرات `index.txt` تلقائيًا
دون الحاجة لإعادة تحميل.

### 7 — التحقق من استجابات OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## اصطلاحات التسمية

| الملف | النمط |
|-------|--------|
| مفتاح CA الوسيطة | `intermediate-PROJECT-DATE.key.pem` |
| شهادة CA الوسيطة | `intermediate-PROJECT-DATE.cert.pem` |
| سلسلة الشهادات | `ca-chain-PROJECT-DATE.cert.pem` |
| شهادة الخادم | `SERVER_DOMAIN.DATE.cert.pem` |
| PKCS#12 الخادم | `SERVER_DOMAIN.DATE.server.full.pfx` |
| شهادة العميل | `client-USER_EMAIL.DATE.cert.pem` |
| PKCS#12 العميل | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| شهادة توقيع OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## ملاحظات الأمان

- يجب **عدم توصيل** جهاز CA غير المتصل بأي شبكة أبدًا.
- مفاتيح الجذر والوسيطة مشفرة بـ AES-256. خزّن عبارات المرور في رمز أجهزة أو خزينة
  مادية، بعيدًا عن المفاتيح.
- تحقق دائمًا من مجاميع USB الاختبارية قبل الاستيراد — تفعل `import-from-usb.sh`
  ذلك تلقائيًا باستخدام `sha256 -C` من OpenBSD.
- تنتهي صلاحية CRL بعد 30 يومًا افتراضيًا. جدوّل تجديدًا دوريًا:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # ثم export-to-usb + import-from-usb
  ```
- تنتهي صلاحية شهادات توقيع OCSP بعد 375 يومًا. جدّدها بإعادة تشغيل
  `create-intermediate-ca.sh` بنفس الوسائط؛ يتخطى الخطوات المكتملة ويولّد شهادة
  OCSP جديدة فقط عند الحاجة.
