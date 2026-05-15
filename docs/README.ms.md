# CAGenerationAndMaintenance

Skrip shell untuk mengendalikan **Autoriti Sijil (CA) luar talian dan terpencil**
di OpenBSD menggunakan OpenSSL. Status pembatalan diterbitkan melalui
[pelayan OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer) yang berasingan.
Kemas kini dipindahkan antara mesin CA luar talian dan mesin pelayan OCSP melalui
pemacu USB.

---

## Perancangan deployment (isi ini sebelum menjalankan skrip)

Sediakan nilai deployment anda sebelum menjalankan langkah di bawah:

- Di manakah CA akan berada?  
  default: `/root/ca`  
  sebenar:

- Apakah organisasi dan di manakah lokasinya?  
  default: `My Organization`  
  sebenar:

- Apakah nama projek?  
  default: `MY PROJECT`  
  sebenar:

- Bilakah tarikh versi projek?  
  default: `01012027`  
  sebenar:

- Apakah TLD?  
  default: `example.com`  
  sebenar:

- Apakah subdomain?  
  default: `app.`  
  sebenar:

- Apakah alamat e-mel untuk pengguna klien?  
  default: `user@example.com`  
  sebenar:

- Di manakah pemacu USB untuk pemindahan?  
  default: `/dev/sd1i`  
  sebenar:

---

## Gambaran Keseluruhan Seni Bina

```
┌─────────────────────────────┐        Pemacu USB       ┌──────────────────────────┐
│   Mesin CA luar talian      │  ───────────────────►   │  Mesin Pelayan OCSP      │
│   (OpenBSD, terpencil)      │  export-to-usb.sh        │  (OpenBSD, berrangkaian) │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  pengangkutan fizikal    │  /etc/ocsp/              │
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

## Prasyarat

Kedua-dua mesin menjalankan **OpenBSD**. Pasang OpenSSL jika belum ada:

```sh
pkg_add openssl
```

Mesin pelayan OCSP juga memerlukan
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) dipasang dan
didaftarkan sebagai perkhidmatan rc.d bernama `ocspserver`.

Semua skrip menggunakan `#!/bin/sh` (OpenBSD `/bin/sh` berasaskan ksh), utiliti
OpenBSD standard (`mount_msdos`, `sha256`, `rcctl`, `doas`), dan `openssl(1)`.
Jalankan semua skrip sebagai root melalui `doas`.

---

## Susun Atur Fail

```
scripts/
  setup-ca.sh               Memulakan direktori CA akar dan menjana kunci/sijil akar
  create-intermediate-ca.sh Mencipta CA perantara yang ditandatangani oleh CA akar
  create-server-cert.sh     Mengeluarkan sijil pelayan TLS (mTLS)
  create-client-cert.sh     Mengeluarkan sijil klien (mTLS)
  revoke-cert.sh            Membatalkan sijil dan menjana semula CRL
  export-to-usb.sh          Membungkus data CA ke USB untuk pemindahan terpencil (sebelah CA)
  import-from-usb.sh        Mengimport dari USB ke pelayan OCSP (sebelah pelayan OCSP)

config/
  openssl-root.cnf.template          Templat konfigurasi OpenSSL untuk CA akar
  openssl-intermediate.cnf.template  Templat konfigurasi OpenSSL untuk CA perantara
```

---

## Penggunaan Langkah demi Langkah

### 1 — Mulakan CA Akar  *(mesin CA luar talian, sekali)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Mencipta `/root/ca/`, menjana kunci akar 4096-bit yang disulitkan AES-256, sijil
yang ditandatangani sendiri sah selama 20 tahun, dan sijil penandatanganan OCSP
untuk CA akar.

### 2 — Cipta CA Perantara  *(mesin CA luar talian, sekali setiap projek)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Fail dicipta di bawah `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Keluarkan Sijil Pelayan  *(mesin CA luar talian)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Output dalam direktori CA perantara:
- `private/app.example.com.01012027.key.pem` — kunci peribadi yang disulitkan
- `certs/app.example.com.01012027.cert.pem` — sijil yang ditandatangani
- `certs/app.example.com.01012027.server.full.pfx` — bundle PKCS#12

### 4 — Keluarkan Sijil Klien  *(mesin CA luar talian)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Ulangi untuk setiap pengguna. Hantar setiap bundle `.full.pfx` kepada pengguna yang
berkenaan melalui saluran yang selamat.

### 5 — Batalkan Sijil  *(mesin CA luar talian)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Untuk memperbaharui CRL tanpa membatalkan apa-apa (contohnya mengikut jadual):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Pemindahan ke Pelayan OCSP melalui USB  *(aliran kerja terpencil)*

#### Pada Mesin CA Luar Talian

Masukkan pemacu USB berformat FAT32. Sahkan peranti:

```sh
dmesg | tail -20          # cari baris "sd1 at ..."
disklabel sd1             # kenal pasti partition FAT32 (biasanya 'i')
```

Kemudian eksport:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Skrip menulis manifes checksum `SHA256` dan menanggalkan pemacu dengan selamat.
Bawa pemacu USB secara fizikal ke mesin pelayan OCSP.

#### Pada Mesin Pelayan OCSP

```sh
dmesg | tail -20          # sahkan nama peranti USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Skrip mengesahkan checksum, menyalin fail yang dikemas kini ke `/etc/ocsp/`, dan
memuatkan semula daemon `ocspserver` melalui `rcctl`. Jika `EnableIndexTxtWatch`
adalah `true` dalam `appsettings.json`, pelayan OCSP juga akan mengambil perubahan
`index.txt` secara automatik tanpa pemuatan semula.

### 7 — Sahkan Respons OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Konvensyen Penamaan

| Fail | Corak |
|------|-------|
| Kunci CA Perantara | `intermediate-PROJECT-DATE.key.pem` |
| Sijil CA Perantara | `intermediate-PROJECT-DATE.cert.pem` |
| Rantaian Sijil | `ca-chain-PROJECT-DATE.cert.pem` |
| Sijil Pelayan | `SERVER_DOMAIN.DATE.cert.pem` |
| Pelayan PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Sijil Klien | `client-USER_EMAIL.DATE.cert.pem` |
| Klien PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Sijil Penandatanganan OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Nota Keselamatan

- Mesin CA luar talian **tidak boleh disambungkan ke rangkaian sama sekali**.
- Kunci peribadi akar dan perantara disulitkan AES-256. Simpan kata laluan dalam
  token perkakasan atau peti besi fizikal, berasingan dari kunci.
- Sentiasa sahkan checksum pemacu USB sebelum mengimport — `import-from-usb.sh`
  melakukan ini secara automatik menggunakan `sha256 -C` OpenBSD.
- CRL tamat tempoh selepas 30 hari secara lalai. Jadualkan pembaharuan CRL secara
  berkala:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # kemudian export-to-usb + import-from-usb
  ```
- Sijil penandatanganan OCSP tamat tempoh selepas 375 hari. Perbaharui dengan
  menjalankan `create-intermediate-ca.sh` sekali lagi dengan argumen yang sama;
  langkah yang telah selesai dilangkau dan sijil OCSP baru sahaja dicipta apabila perlu.
