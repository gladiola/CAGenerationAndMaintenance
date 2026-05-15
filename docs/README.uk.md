# CAGenerationAndMaintenance

Скрипти оболонки для керування **офлайн, ізольованим центром сертифікації (CA)**
на OpenBSD з використанням OpenSSL. Статус відкликання публікується через окремий
[сервер OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer).
Оновлення передаються між офлайн-машиною CA та машиною сервера OCSP через USB-накопичувач.

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

## Огляд архітектури

```
┌─────────────────────────────┐        USB-накопичувач  ┌──────────────────────────┐
│   Офлайн-машина CA          │  ───────────────────►   │  Машина сервера OCSP     │
│   (OpenBSD, ізольована)     │  export-to-usb.sh        │  (OpenBSD, у мережі)     │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  фізичне перенесення     │  /etc/ocsp/              │
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

## Передумови

Обидві машини працюють під управлінням **OpenBSD**. Встановіть OpenSSL, якщо його
немає:

```sh
pkg_add openssl
```

На машині сервера OCSP також повинен бути встановлений і зареєстрований як служба
rc.d з ім'ям `ocspserver`
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer).

Усі скрипти використовують `#!/bin/sh` (ksh-заснований `/bin/sh` OpenBSD), стандартні
утиліти OpenBSD (`mount_msdos`, `sha256`, `rcctl`, `doas`) та `openssl(1)`.
Запускайте всі скрипти від імені root через `doas`.

---

## Структура файлів

```
scripts/
  setup-ca.sh               Ініціалізує каталоги кореневого CA та генерує кореневий ключ/сертифікат
  create-intermediate-ca.sh Створює проміжний CA, підписаний кореневим CA
  create-server-cert.sh     Видає серверний сертифікат TLS (mTLS)
  create-client-cert.sh     Видає клієнтський сертифікат (mTLS)
  revoke-cert.sh            Відкликає сертифікат та перегенерує CRL
  export-to-usb.sh          Пакує дані CA на USB для передачі через ізоляцію (сторона CA)
  import-from-usb.sh        Імпортує з USB на сервер OCSP (сторона сервера OCSP)

config/
  openssl-root.cnf.template          Шаблон конфігурації OpenSSL для кореневого CA
  openssl-intermediate.cnf.template  Шаблон конфігурації OpenSSL для проміжного CA
```

---

## Планування розгортання (заповніть це перед запуском скриптів)

Підготуйте значення розгортання перед виконанням кроків нижче:

- Де буде розміщено CA?  
  default: `/root/ca`  
  фактично:

- Яка це організація і де вона знаходиться?  
  default: `My Organization`  
  фактично:

- Яка назва проєкту?  
  default: `MY PROJECT`  
  фактично:

- Яка дата версії проєкту?  
  default: `01012027`  
  фактично:

- Який TLD?  
  default: `example.com`  
  фактично:

- Який піддомен?  
  default: `app.`  
  фактично:

- Яка електронна адреса користувача(ів) клієнта?  
  default: `user@example.com`  
  фактично:

- Де USB-накопичувач для перенесення?  
  default: `/dev/sd1i`  
  фактично:

---

## Покрокове використання

### 1 — Ініціалізація кореневого CA  *(офлайн-машина CA, один раз)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Створює `/root/ca/`, генерує зашифрований AES-256 кореневий ключ 4096 бітів,
самопідписаний сертифікат терміном 20 років та сертифікат підпису OCSP для кореневого CA.

### 2 — Створення проміжного CA  *(офлайн-машина CA, один раз на проєкт)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Файли створюються в `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Видача серверного сертифіката  *(офлайн-машина CA)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Виведення в каталог проміжного CA:
- `private/app.example.com.01012027.key.pem` — зашифрований приватний ключ
- `certs/app.example.com.01012027.cert.pem` — підписаний сертифікат
- `certs/app.example.com.01012027.server.full.pfx` — пакет PKCS#12

### 4 — Видача клієнтських сертифікатів  *(офлайн-машина CA)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Повторіть для кожного користувача. Передайте кожен пакет `.full.pfx` відповідному
користувачу захищеним каналом.

### 5 — Відкликання сертифіката  *(офлайн-машина CA)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Оновлення CRL без відкликання (наприклад, за розкладом):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Передача на сервер OCSP через USB  *(робочий процес з ізоляцією)*

#### На офлайн-машині CA

Вставте USB-накопичувач у форматі FAT32. Підтвердіть пристрій:

```sh
dmesg | tail -20          # шукайте рядки "sd1 at ..."
disklabel sd1             # визначте розділ FAT32 (зазвичай 'i')
```

Потім виконайте експорт:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Скрипт записує маніфест контрольних сум `SHA256` та безпечно від'єднує накопичувач.
Фізично перенесіть USB-накопичувач на машину сервера OCSP.

#### На машині сервера OCSP

```sh
dmesg | tail -20          # підтвердіть ім'я USB-пристрою
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Скрипт перевіряє контрольні суми, копіює оновлені файли до `/etc/ocsp/` та
перезавантажує демон `ocspserver` через `rcctl`. Якщо `EnableIndexTxtWatch` дорівнює
`true` в `appsettings.json`, сервер OCSP також автоматично підхопить зміни `index.txt`
без перезавантаження.

### 7 — Перевірка відповідей OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Угоди про іменування

| Файл | Шаблон |
|------|--------|
| Ключ проміжного CA | `intermediate-PROJECT-DATE.key.pem` |
| Сертифікат проміжного CA | `intermediate-PROJECT-DATE.cert.pem` |
| Ланцюг сертифікатів | `ca-chain-PROJECT-DATE.cert.pem` |
| Серверний сертифікат | `SERVER_DOMAIN.DATE.cert.pem` |
| Сервер PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Клієнтський сертифікат | `client-USER_EMAIL.DATE.cert.pem` |
| Клієнт PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Сертифікат підпису OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Примітки щодо безпеки

- Офлайн-машина CA **ніколи не повинна підключатися до мережі**.
- Приватні ключі кореневого та проміжного CA зашифровані AES-256. Зберігайте
  парольні фрази в апаратному токені або фізичному сейфі, окремо від ключів.
- Завжди перевіряйте контрольні суми USB-накопичувача перед імпортом —
  `import-from-usb.sh` робить це автоматично за допомогою `sha256 -C` OpenBSD.
- CRL закінчуються через 30 днів за замовчуванням. Заплануйте регулярне оновлення CRL:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # потім export-to-usb + import-from-usb
  ```
- Сертифікати підпису OCSP закінчуються через 375 днів. Оновіть їх, повторно
  запустивши `create-intermediate-ca.sh` з тими самими аргументами; вже виконані
  кроки пропускаються і лише новий сертифікат OCSP генерується при необхідності.
