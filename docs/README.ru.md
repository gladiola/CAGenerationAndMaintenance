# CAGenerationAndMaintenance

Скрипты командной оболочки для управления **офлайн, изолированным Центром
Сертификации (CA)** на OpenBSD с использованием OpenSSL. Статус отзыва публикуется
через отдельный [сервер OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer).
Обновления передаются между офлайн-машиной CA и машиной сервера OCSP через USB-накопитель.

---

## Обзор архитектуры

```
┌─────────────────────────────┐        USB-накопитель   ┌──────────────────────────┐
│   Офлайн-машина CA          │  ───────────────────►   │  Машина сервера OCSP     │
│   (OpenBSD, изолированная)  │  export-to-usb.sh        │  (OpenBSD, в сети)       │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  физическая передача     │  /etc/ocsp/              │
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

## Предварительные требования

Обе машины работают под управлением **OpenBSD**. Установите OpenSSL, если он ещё не
установлен:

```sh
pkg_add openssl
```

На машине сервера OCSP также должен быть установлен и зарегистрирован как служба rc.d
с именем `ocspserver`
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer).

Все скрипты используют `#!/bin/sh` (ksh-основанный `/bin/sh` OpenBSD), стандартные
утилиты OpenBSD (`mount_msdos`, `sha256`, `rcctl`, `doas`) и `openssl(1)`.
Запускайте все скрипты от имени root через `doas`.

---

## Структура файлов

```
scripts/
  setup-ca.sh               Инициализирует каталоги корневого CA и генерирует корневой ключ/сертификат
  create-intermediate-ca.sh Создаёт промежуточный CA, подписанный корневым CA
  create-server-cert.sh     Выпускает серверный сертификат TLS (mTLS)
  create-client-cert.sh     Выпускает клиентский сертификат (mTLS)
  revoke-cert.sh            Отзывает сертификат и перегенерирует CRL
  export-to-usb.sh          Упаковывает данные CA на USB для передачи через воздушный зазор (сторона CA)
  import-from-usb.sh        Импортирует с USB на сервер OCSP (сторона сервера OCSP)

config/
  openssl-root.cnf.template          Шаблон конфигурации OpenSSL для корневого CA
  openssl-intermediate.cnf.template  Шаблон конфигурации OpenSSL для промежуточного CA
```

---

## Пошаговое использование

### 1 — Инициализация корневого CA  *(офлайн-машина CA, один раз)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Создаёт `/root/ca/`, генерирует зашифрованный AES-256 корневой ключ 4096 бит,
самоподписанный сертификат сроком 20 лет и сертификат подписи OCSP для корневого CA.

### 2 — Создание промежуточного CA  *(офлайн-машина CA, один раз на проект)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Файлы создаются в `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Выпуск серверного сертификата  *(офлайн-машина CA)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Вывод в каталог промежуточного CA:
- `private/app.example.com.01012027.key.pem` — зашифрованный закрытый ключ
- `certs/app.example.com.01012027.cert.pem` — подписанный сертификат
- `certs/app.example.com.01012027.server.full.pfx` — пакет PKCS#12

### 4 — Выпуск клиентских сертификатов  *(офлайн-машина CA)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Повторите для каждого пользователя. Передайте каждый пакет `.full.pfx` соответствующему
пользователю по защищённому каналу.

### 5 — Отзыв сертификата  *(офлайн-машина CA)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Обновление CRL без отзыва (например, по расписанию):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Передача на сервер OCSP через USB  *(рабочий процесс с воздушным зазором)*

#### На офлайн-машине CA

Вставьте USB-накопитель в формате FAT32. Подтвердите устройство:

```sh
dmesg | tail -20          # ищите строки "sd1 at ..."
disklabel sd1             # определите раздел FAT32 (обычно 'i')
```

Затем выполните экспорт:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Скрипт записывает манифест контрольных сумм `SHA256` и безопасно отмонтирует накопитель.
Физически перенесите USB-накопитель на машину сервера OCSP.

#### На машине сервера OCSP

```sh
dmesg | tail -20          # подтвердите имя USB-устройства
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Скрипт проверяет контрольные суммы, копирует обновлённые файлы в `/etc/ocsp/` и
перезагружает демон `ocspserver` через `rcctl`. Если `EnableIndexTxtWatch` в
`appsettings.json` равно `true`, сервер OCSP также автоматически подхватит изменения
`index.txt` без перезагрузки.

### 7 — Проверка ответов OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Соглашения об именовании

| Файл | Шаблон |
|------|--------|
| Ключ промежуточного CA | `intermediate-PROJECT-DATE.key.pem` |
| Сертификат промежуточного CA | `intermediate-PROJECT-DATE.cert.pem` |
| Цепочка сертификатов | `ca-chain-PROJECT-DATE.cert.pem` |
| Серверный сертификат | `SERVER_DOMAIN.DATE.cert.pem` |
| PKCS#12 сервера | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Клиентский сертификат | `client-USER_EMAIL.DATE.cert.pem` |
| PKCS#12 клиента | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Сертификат подписи OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Примечания по безопасности

- Офлайн-машина CA **никогда не должна подключаться к сети**.
- Закрытые ключи корневого и промежуточного CA зашифрованы AES-256. Храните
  парольные фразы в аппаратном токене или физическом сейфе, отдельно от ключей.
- Всегда проверяйте контрольные суммы USB-накопителя перед импортом —
  `import-from-usb.sh` делает это автоматически с помощью `sha256 -C` OpenBSD.
- CRL истекают через 30 дней по умолчанию. Запланируйте регулярное обновление CRL:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # затем export-to-usb + import-from-usb
  ```
- Сертификаты подписи OCSP истекают через 375 дней. Обновляйте их, повторно запуская
  `create-intermediate-ca.sh` с теми же аргументами; уже выполненные шаги пропускаются
  и генерируется только новый сертификат OCSP при необходимости.
