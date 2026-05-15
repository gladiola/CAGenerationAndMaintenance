# CAGenerationAndMaintenance

Skrip shell untuk mengoperasikan **Otoritas Sertifikat (CA) yang offline dan
terisolasi secara fisik** di OpenBSD menggunakan OpenSSL. Status pencabutan
dipublikasikan melalui [server OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer)
yang terpisah. Pembaruan ditransfer antara mesin CA offline dan mesin server OCSP
melalui drive USB.

---

## Gambaran Arsitektur

```
┌─────────────────────────────┐        Drive USB        ┌──────────────────────────┐
│   Mesin CA offline          │  ───────────────────►   │  Mesin Server OCSP       │
│   (OpenBSD, terisolasi)     │  export-to-usb.sh        │  (OpenBSD, berjaringan)  │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  transport fisik         │  /etc/ocsp/              │
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

Kedua mesin menjalankan **OpenBSD**. Instal OpenSSL jika belum ada:

```sh
pkg_add openssl
```

Mesin server OCSP juga memerlukan
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) yang diinstal dan
didaftarkan sebagai layanan rc.d bernama `ocspserver`.

Semua skrip menggunakan `#!/bin/sh` (OpenBSD `/bin/sh` berbasis ksh), utilitas
OpenBSD standar (`mount_msdos`, `sha256`, `rcctl`, `doas`), dan `openssl(1)`.
Jalankan semua skrip sebagai root melalui `doas`.

---

## Tata Letak File

```
scripts/
  setup-ca.sh               Menginisialisasi direktori CA root dan menghasilkan kunci/sertifikat root
  create-intermediate-ca.sh Membuat CA perantara yang ditandatangani oleh CA root
  create-server-cert.sh     Menerbitkan sertifikat server TLS (mTLS)
  create-client-cert.sh     Menerbitkan sertifikat klien (mTLS)
  revoke-cert.sh            Mencabut sertifikat dan meregenerasi CRL
  export-to-usb.sh          Mengemas data CA ke USB untuk transfer terisolasi (sisi CA)
  import-from-usb.sh        Mengimpor dari USB ke server OCSP (sisi server OCSP)

config/
  openssl-root.cnf.template          Template konfigurasi OpenSSL untuk CA root
  openssl-intermediate.cnf.template  Template konfigurasi OpenSSL untuk CA perantara
```

---

## Perencanaan deployment (isi ini sebelum menjalankan skrip)

Siapkan nilai deployment Anda sebelum menjalankan langkah-langkah di bawah:

- Di mana CA akan berada?  
  default: `/root/ca`  
  aktual:

- Apa nama organisasi dan di mana lokasinya?  
  default: `My Organization`  
  aktual:

- Apa nama proyek?  
  default: `MY PROJECT`  
  aktual:

- Kapan versi proyek ditetapkan?  
  default: `01012027`  
  aktual:

- Apa TLD-nya?  
  default: `example.com`  
  aktual:

- Apa subdomain-nya?  
  default: `app.`  
  aktual:

- Apa alamat email untuk pengguna klien?  
  default: `user@example.com`  
  aktual:

- Di mana USB thumb drive untuk transfer?  
  default: `/dev/sd1i`  
  aktual:

---

## Penggunaan Langkah demi Langkah

### 1 — Inisialisasi CA Root  *(mesin CA offline, sekali)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Membuat `/root/ca/`, menghasilkan kunci root 4096-bit terenkripsi AES-256, sertifikat
yang ditandatangani sendiri berlaku 20 tahun, dan sertifikat penandatanganan OCSP
untuk CA root.

### 2 — Buat CA Perantara  *(mesin CA offline, sekali per proyek)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

File dibuat di bawah `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Terbitkan Sertifikat Server  *(mesin CA offline)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Keluaran di direktori CA perantara:
- `private/app.example.com.01012027.key.pem` — kunci privat terenkripsi
- `certs/app.example.com.01012027.cert.pem` — sertifikat yang ditandatangani
- `certs/app.example.com.01012027.server.full.pfx` — bundel PKCS#12

### 4 — Terbitkan Sertifikat Klien  *(mesin CA offline)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Ulangi untuk setiap pengguna. Transfer setiap bundel `.full.pfx` ke pengguna yang
bersangkutan melalui saluran yang aman.

### 5 — Cabut Sertifikat  *(mesin CA offline)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Untuk memperbarui CRL tanpa mencabut apa pun (misalnya secara terjadwal):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Transfer ke Server OCSP via USB  *(alur kerja terisolasi)*

#### Pada Mesin CA Offline

Masukkan drive USB berformat FAT32. Konfirmasi perangkat:

```sh
dmesg | tail -20          # cari baris "sd1 at ..."
disklabel sd1             # identifikasi partisi FAT32 (biasanya 'i')
```

Kemudian ekspor:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Skrip menulis manifes checksum `SHA256` dan melepas drive dengan aman.
Bawa drive USB secara fisik ke mesin server OCSP.

#### Pada Mesin Server OCSP

```sh
dmesg | tail -20          # konfirmasi nama perangkat USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Skrip memverifikasi checksum, menyalin file yang diperbarui ke `/etc/ocsp/`, dan
memuat ulang daemon `ocspserver` melalui `rcctl`. Jika `EnableIndexTxtWatch` adalah
`true` di `appsettings.json`, server OCSP juga akan mengambil perubahan `index.txt`
secara otomatis tanpa pemuatan ulang.

### 7 — Verifikasi Respons OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Konvensi Penamaan

| File | Pola |
|------|------|
| Kunci CA Perantara | `intermediate-PROJECT-DATE.key.pem` |
| Sertifikat CA Perantara | `intermediate-PROJECT-DATE.cert.pem` |
| Rantai Sertifikat | `ca-chain-PROJECT-DATE.cert.pem` |
| Sertifikat Server | `SERVER_DOMAIN.DATE.cert.pem` |
| Server PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Sertifikat Klien | `client-USER_EMAIL.DATE.cert.pem` |
| Klien PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Sertifikat Penandatanganan OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Catatan Keamanan

- Mesin CA offline **tidak boleh pernah terhubung ke jaringan**.
- Kunci privat root dan perantara dienkripsi dengan AES-256. Simpan passphrase di
  token perangkat keras atau brankas fisik, terpisah dari kunci.
- Selalu verifikasi checksum drive USB sebelum mengimpor — `import-from-usb.sh`
  melakukan ini secara otomatis menggunakan `sha256 -C` OpenBSD.
- CRL kedaluwarsa setelah 30 hari secara default. Jadwalkan pembaruan CRL secara
  berkala:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # kemudian export-to-usb + import-from-usb
  ```
- Sertifikat penandatanganan OCSP kedaluwarsa setelah 375 hari. Perbarui dengan
  menjalankan `create-intermediate-ca.sh` lagi dengan argumen yang sama; langkah
  yang sudah selesai dilewati dan sertifikat OCSP baru hanya dibuat bila diperlukan.
