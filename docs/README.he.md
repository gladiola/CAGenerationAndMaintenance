# CAGenerationAndMaintenance

סקריפטים של מעטפת להפעלת **רשות אישורים (CA) לא מקוונת ומבודדת**
ב-OpenBSD באמצעות OpenSSL. מצב הביטול מתפרסם דרך
[שרת OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer) נפרד.
עדכונים מועברים בין מכשיר ה-CA הלא מקוון לבין מכשיר שרת ה-OCSP באמצעות כונן USB.

---

## 🌐 Language / Sprache / Langue / Idioma / Língua / Lingua / 語言 / 언어 / भाषा / Язык / لغة / Lugha / 言語 / Lang / Wika / ʻŌlelo / Gagana / Reo / Taal / Harshe / ቋንቋ / Èdè / ভাষা / 语言 / Keel / Kieli / Språk / Мова / ภาษา / Bahasa / Wika / Bahasa / Basa / Γλώσσα / Lingua / שפה / Teanga

| | | | | |
|---|---|---|---|---|
| 🇺🇸 [English](../README.md) | 🇩🇪 [Deutsch](README.de.md) | 🇪🇸 [Español](README.es.md) | 🇫🇷 [Français](README.fr.md) | 🇵🇹 [Português](README.pt.md) |
| 🇮🇹 [Italiano](README.it.md) | 🇭🇰 [繁體中文](README.zh-HK.md) | 🇰🇷 [한국어](README.ko.md) | 🇮🇳 [हिन्दी](README.hi.md) | 🇷🇺 [Русский](README.ru.md) |
| 🇸🇦 [العربية](README.ar.md) | 🌍 [Kiswahili](README.sw.md) | 🇯🇵 [日本語](README.ja.md) | 🇭🇹 [Kreyòl ayisyen](README.ht.md) | 🌺 [ʻŌlelo Hawaiʻi](README.haw.md) |
| 🌊 [Gagana Sāmoa](README.sm.md) | 🌿 [Te Reo Māori](README.mi.md) | 🇿🇦 [Afrikaans](README.af.md) | 🇳🇱 [Nederlands](README.nl.md) | 🌍 [Hausa](README.ha.md) |
| 🇪🇹 [አማርኛ](README.am.md) | 🌍 [Yorùbá](README.yo.md) | 🇧🇩 [বাংলা](README.bn.md) | 🇨🇳 [简体中文](README.zh-CN.md) | 🇪🇪 [Eesti](README.et.md) |
| 🇫🇮 [Suomi](README.fi.md) | 🇸🇪 [Svenska](README.sv.md) | 🇳🇴 [Norsk](README.no.md) | 🇺🇦 [Українська](README.uk.md) | 🇹🇭 [ภาษาไทย](README.th.md) |
| 🇮🇩 [Bahasa Indonesia](README.id.md) | 🇵🇭 [Filipino](README.tl.md) | 🇲🇾 [Bahasa Melayu](README.ms.md) | 🌏 [Basa Jawa](README.jv.md) | 🇬🇷 [Ελληνικά](README.el.md) |
| 📜 [Latina](README.la.md) | 🇮🇱 [עברית](README.he.md) | 🇮🇪 [Gaeilge](README.ga.md) | | |

---

## סקירת ארכיטקטורה

```
┌─────────────────────────────┐        כונן USB         ┌──────────────────────────┐
│   מכשיר CA לא מקוון        │  ───────────────────►   │  מכשיר שרת OCSP         │
│   (OpenBSD, מבודד)          │  export-to-usb.sh        │  (OpenBSD, מחובר לרשת)  │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  העברה פיזית             │  /etc/ocsp/              │
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

## דרישות מוקדמות

שני המכשירים פועלים עם **OpenBSD**. התקן OpenSSL אם אינו קיים:

```sh
pkg_add openssl
```

מכשיר שרת OCSP צריך גם את
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) מותקן ורשום
כשירות rc.d בשם `ocspserver`.

כל הסקריפטים משתמשים ב-`#!/bin/sh` (OpenBSD `/bin/sh` מבוסס ksh), בכלים סטנדרטיים
של OpenBSD (`mount_msdos`, `sha256`, `rcctl`, `doas`) וב-`openssl(1)`.
הפעל את כל הסקריפטים כ-root דרך `doas`.

---

## מבנה הקבצים

```
scripts/
  setup-ca.sh               מאתחל את ספריות CA הבסיסי ויוצר מפתח/אישור בסיס
  create-intermediate-ca.sh יוצר CA ביניים בשם החתום על ידי CA הבסיסי
  create-server-cert.sh     מנפיק אישור שרת TLS (mTLS)
  create-client-cert.sh     מנפיק אישור לקוח (mTLS)
  revoke-cert.sh            מבטל אישור ויוצר מחדש CRL
  export-to-usb.sh          אורז נתוני CA ב-USB להעברה מבודדת (צד CA)
  import-from-usb.sh        מייבא מ-USB לשרת OCSP (צד שרת OCSP)

config/
  openssl-root.cnf.template          תבנית הגדרת OpenSSL ל-CA בסיסי
  openssl-intermediate.cnf.template  תבנית הגדרת OpenSSL ל-CA ביניים
```

---

## תכנון פריסה (מלאו זאת לפני הרצת הסקריפטים)

הכינו את ערכי הפריסה לפני הרצת השלבים הבאים:

- היכן תמוקם ה-CA?  
  default: `/root/ca`  
  בפועל:

- מה הארגון והיכן הוא נמצא?  
  default: `My Organization`  
  בפועל:

- מה שם הפרויקט?  
  default: `MY PROJECT`  
  בפועל:

- מהו תאריך הגרסה של הפרויקט?  
  default: `01012027`  
  בפועל:

- מהו ה-TLD?  
  default: `example.com`  
  בפועל:

- מהו תת-הדומיין?  
  default: `app.`  
  בפועל:

- מה כתובת האימייל של משתמש/י הלקוח?  
  default: `user@example.com`  
  בפועל:

- היכן נמצא כונן ה-USB להעברה?  
  default: `/dev/sd1i`  
  בפועל:

---

## שימוש שלב אחר שלב

### 1 — אתחול CA הבסיסי  *(מכשיר CA לא מקוון, פעם אחת)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

יוצר `/root/ca/`, מייצר מפתח בסיס 4096-bit מוצפן AES-256, אישור חתום-עצמי
תקף 20 שנה ואישור חתימה OCSP ל-CA הבסיסי.

### 2 — יצירת CA ביניים  *(מכשיר CA לא מקוון, פעם אחת לכל פרויקט)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

קבצים נוצרים תחת `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — הנפקת אישור שרת  *(מכשיר CA לא מקוון)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

פלט בספרייה של CA הביניים:
- `private/app.example.com.01012027.key.pem` — מפתח פרטי מוצפן
- `certs/app.example.com.01012027.cert.pem` — אישור חתום
- `certs/app.example.com.01012027.server.full.pfx` — חבילת PKCS#12

### 4 — הנפקת אישורי לקוח  *(מכשיר CA לא מקוון)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

חזור על כל משתמש. העבר כל חבילת `.full.pfx` למשתמש המתאים דרך ערוץ מאובטח.

### 5 — ביטול אישור  *(מכשיר CA לא מקוון)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

לחידוש CRL ללא ביטול (למשל, לפי לוח זמנים):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — העברה לשרת OCSP דרך USB  *(תהליך עבודה מבודד)*

#### על מכשיר CA הלא מקוון

הכנס כונן USB מפורמט FAT32. אשר את ההתקן:

```sh
dmesg | tail -20          # חפש שורות "sd1 at ..."
disklabel sd1             # זהה את מחיצת FAT32 (בדרך כלל 'i')
```

לאחר מכן יצא:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

הסקריפט כותב מניפסט SHA256 ומנתק את הכונן בבטחה.
הובל פיזית את כונן ה-USB למכשיר שרת OCSP.

#### על מכשיר שרת OCSP

```sh
dmesg | tail -20          # אשר שם התקן USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

הסקריפט מאמת סכומי ביקורת, מעתיק קבצים מעודכנים ל-`/etc/ocsp/` ומטעין מחדש
את ה-daemon של `ocspserver` דרך `rcctl`. אם `EnableIndexTxtWatch` הוא `true`
ב-`appsettings.json`, שרת OCSP יאסוף גם שינויים ב-`index.txt` אוטומטית ללא טעינה מחדש.

### 7 — אימות תגובות OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## מוסכמות שמות

| קובץ | תבנית |
|------|-------|
| מפתח CA ביניים | `intermediate-PROJECT-DATE.key.pem` |
| אישור CA ביניים | `intermediate-PROJECT-DATE.cert.pem` |
| שרשרת אישורים | `ca-chain-PROJECT-DATE.cert.pem` |
| אישור שרת | `SERVER_DOMAIN.DATE.cert.pem` |
| שרת PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| אישור לקוח | `client-USER_EMAIL.DATE.cert.pem` |
| לקוח PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| אישור חתימה OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## הערות אבטחה

- מכשיר CA הלא מקוון **אסור לעולם להתחבר לרשת**.
- מפתחות פרטיים בסיסיים וביניים מוצפנים AES-256. שמור סיסמאות בטוקן חומרה
  או כספת פיזית, בנפרד מהמפתחות.
- אמת תמיד סכומי ביקורת של USB לפני ייבוא — `import-from-usb.sh` עושה זאת
  אוטומטית באמצעות `sha256 -C` של OpenBSD.
- CRL-ים פגים תוקף לאחר 30 יום כברירת מחדל. תזמן חידוש CRL קבוע:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # ואחר כך export-to-usb + import-from-usb
  ```
- אישורי חתימה OCSP פגים תוקף לאחר 375 יום. חדש אותם על ידי הפעלה מחדש של
  `create-intermediate-ca.sh` עם אותן ארגומנטים; שלבים שהושלמו כבר מדולגים ורק
  אישור OCSP חדש נוצר כשצריך.
