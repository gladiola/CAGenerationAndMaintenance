# CAGenerationAndMaintenance

สคริปต์เชลล์สำหรับดำเนินการ**ศูนย์ออกใบรับรอง (CA) แบบออฟไลน์และแยกทางกายภาพ**
บน OpenBSD โดยใช้ OpenSSL สถานะการเพิกถอนถูกเผยแพร่ผ่าน
[เซิร์ฟเวอร์ OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer) แยกต่างหาก
การอัปเดตถูกถ่ายโอนระหว่างเครื่อง CA ออฟไลน์และเครื่องเซิร์ฟเวอร์ OCSP ผ่านแฟลชไดรฟ์ USB

---

## การวางแผนการปรับใช้ (กรอกส่วนนี้ก่อนรันสคริปต์)

เตรียมค่าการปรับใช้ของคุณก่อนดำเนินขั้นตอนด้านล่าง:

- CA จะอยู่ที่ไหน?  
  default: `/root/ca`  
  ค่าจริง:

- องค์กรคืออะไรและอยู่ที่ไหน?  
  default: `My Organization`  
  ค่าจริง:

- ชื่อโครงการคืออะไร?  
  default: `MY PROJECT`  
  ค่าจริง:

- วันที่เวอร์ชันของโครงการคือเมื่อใด?  
  default: `01012027`  
  ค่าจริง:

- TLD คืออะไร?  
  default: `example.com`  
  ค่าจริง:

- ซับโดเมนคืออะไร?  
  default: `app.`  
  ค่าจริง:

- อีเมลของผู้ใช้ลูกค้าคืออะไร?  
  default: `user@example.com`  
  ค่าจริง:

- แฟลชไดรฟ์ USB สำหรับถ่ายโอนอยู่ที่ไหน?  
  default: `/dev/sd1i`  
  ค่าจริง:

---

## ภาพรวมสถาปัตยกรรม

```
┌─────────────────────────────┐       แฟลชไดรฟ์ USB    ┌──────────────────────────┐
│   เครื่อง CA ออฟไลน์       │  ───────────────────►   │  เครื่องเซิร์ฟเวอร์ OCSP │
│   (OpenBSD, แยกกาย)        │  export-to-usb.sh        │  (OpenBSD, บนเครือข่าย)  │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  ขนส่งทางกายภาพ         │  /etc/ocsp/              │
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

## ข้อกำหนดเบื้องต้น

เครื่องทั้งสองใช้ **OpenBSD** ติดตั้ง OpenSSL หากยังไม่มี:

```sh
pkg_add openssl
```

เครื่องเซิร์ฟเวอร์ OCSP ยังต้องการ
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) ที่ติดตั้งและ
ลงทะเบียนเป็นบริการ rc.d ชื่อ `ocspserver`

สคริปต์ทั้งหมดใช้ `#!/bin/sh` (`/bin/sh` ที่ใช้ ksh ของ OpenBSD), ยูทิลิตี้มาตรฐาน
OpenBSD (`mount_msdos`, `sha256`, `rcctl`, `doas`) และ `openssl(1)`
รันสคริปต์ทั้งหมดในฐานะ root ผ่าน `doas`

---

## โครงสร้างไฟล์

```
scripts/
  setup-ca.sh               เริ่มต้นไดเรกทอรี CA รากและสร้างคีย์/ใบรับรองราก
  create-intermediate-ca.sh สร้าง CA กลางที่มีชื่อและลงนามโดย CA ราก
  create-server-cert.sh     ออกใบรับรองเซิร์ฟเวอร์ TLS (mTLS)
  create-client-cert.sh     ออกใบรับรองไคลเอนต์ (mTLS)
  revoke-cert.sh            เพิกถอนใบรับรองและสร้าง CRL ใหม่
  export-to-usb.sh          บรรจุข้อมูล CA ลง USB สำหรับการถ่ายโอนแบบแยกกาย (ฝั่ง CA)
  import-from-usb.sh        นำเข้าจาก USB ไปยังเซิร์ฟเวอร์ OCSP (ฝั่งเซิร์ฟเวอร์ OCSP)

config/
  openssl-root.cnf.template          เทมเพลตการกำหนดค่า OpenSSL สำหรับ CA ราก
  openssl-intermediate.cnf.template  เทมเพลตการกำหนดค่า OpenSSL สำหรับ CA กลาง
```

---

## วิธีใช้งานทีละขั้นตอน

### 1 — เริ่มต้น CA ราก  *(เครื่อง CA ออฟไลน์ ครั้งเดียว)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

สร้าง `/root/ca/` สร้างคีย์รากขนาด 4096 บิตที่เข้ารหัส AES-256 ใบรับรองที่ลงนาม
ตัวเองมีอายุ 20 ปี และใบรับรองการลงนาม OCSP สำหรับ CA ราก

### 2 — สร้าง CA กลาง  *(เครื่อง CA ออฟไลน์ ครั้งเดียวต่อโครงการ)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

ไฟล์ถูกสร้างภายใต้ `/root/ca/intermediate-MY-PROJECT-01012027/`

### 3 — ออกใบรับรองเซิร์ฟเวอร์  *(เครื่อง CA ออฟไลน์)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

ผลลัพธ์ในไดเรกทอรี CA กลาง:
- `private/app.example.com.01012027.key.pem` — คีย์ส่วนตัวที่เข้ารหัส
- `certs/app.example.com.01012027.cert.pem` — ใบรับรองที่ลงนาม
- `certs/app.example.com.01012027.server.full.pfx` — แพ็คเกจ PKCS#12

### 4 — ออกใบรับรองไคลเอนต์  *(เครื่อง CA ออฟไลน์)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

ทำซ้ำสำหรับผู้ใช้แต่ละคน ถ่ายโอนแพ็คเกจ `.full.pfx` แต่ละรายการไปยังผู้ใช้ที่
เกี่ยวข้องผ่านช่องทางที่ปลอดภัย

### 5 — เพิกถอนใบรับรอง  *(เครื่อง CA ออฟไลน์)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

เพื่อต่ออายุ CRL โดยไม่เพิกถอนสิ่งใด (เช่น ตามกำหนดการ):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — ถ่ายโอนไปยังเซิร์ฟเวอร์ OCSP ผ่าน USB  *(ขั้นตอนการทำงานแบบแยกกาย)*

#### บนเครื่อง CA ออฟไลน์

เสียบแฟลชไดรฟ์ USB ที่ฟอร์แมต FAT32 ยืนยันอุปกรณ์:

```sh
dmesg | tail -20          # ดูบรรทัด "sd1 at ..."
disklabel sd1             # ระบุพาร์ติชัน FAT32 (โดยทั่วไปคือ 'i')
```

จากนั้นส่งออก:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

สคริปต์เขียนไฟล์แมนิเฟสต์ SHA256 และยกเลิกการเมาท์ไดรฟ์อย่างปลอดภัย
นำแฟลชไดรฟ์ USB ไปที่เครื่องเซิร์ฟเวอร์ OCSP ด้วยตัวเอง

#### บนเครื่องเซิร์ฟเวอร์ OCSP

```sh
dmesg | tail -20          # ยืนยันชื่ออุปกรณ์ USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

สคริปต์ตรวจสอบค่าแฮช คัดลอกไฟล์ที่อัปเดตไปยัง `/etc/ocsp/` และโหลด daemon
`ocspserver` ใหม่ผ่าน `rcctl` หาก `EnableIndexTxtWatch` เป็น `true` ใน
`appsettings.json` เซิร์ฟเวอร์ OCSP จะรับการเปลี่ยนแปลง `index.txt` โดยอัตโนมัติ
โดยไม่ต้องโหลดใหม่

### 7 — ตรวจสอบการตอบสนอง OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## รูปแบบการตั้งชื่อ

| ไฟล์ | รูปแบบ |
|------|--------|
| คีย์ CA กลาง | `intermediate-PROJECT-DATE.key.pem` |
| ใบรับรอง CA กลาง | `intermediate-PROJECT-DATE.cert.pem` |
| ห่วงโซ่ใบรับรอง | `ca-chain-PROJECT-DATE.cert.pem` |
| ใบรับรองเซิร์ฟเวอร์ | `SERVER_DOMAIN.DATE.cert.pem` |
| PKCS#12 เซิร์ฟเวอร์ | `SERVER_DOMAIN.DATE.server.full.pfx` |
| ใบรับรองไคลเอนต์ | `client-USER_EMAIL.DATE.cert.pem` |
| PKCS#12 ไคลเอนต์ | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| ใบรับรองการลงนาม OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## หมายเหตุด้านความปลอดภัย

- เครื่อง CA ออฟไลน์**ต้องไม่เชื่อมต่อกับเครือข่ายใดๆ เลย**
- คีย์ส่วนตัวราก และ CA กลาง เข้ารหัสด้วย AES-256 เก็บรักษารหัสผ่านไว้ใน
  โทเค็นฮาร์ดแวร์หรือตู้เซฟทางกายภาพ แยกจากคีย์
- ตรวจสอบค่าแฮช USB เสมอก่อนนำเข้า — `import-from-usb.sh` ทำสิ่งนี้โดยอัตโนมัติ
  โดยใช้ `sha256 -C` ของ OpenBSD
- CRL หมดอายุหลังจาก 30 วันตามค่าเริ่มต้น กำหนดการต่ออายุ CRL อย่างสม่ำเสมอ:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # จากนั้น export-to-usb + import-from-usb
  ```
- ใบรับรองการลงนาม OCSP หมดอายุหลังจาก 375 วัน ต่ออายุโดยรัน `create-intermediate-ca.sh`
  อีกครั้งด้วยอาร์กิวเมนต์เดิม ขั้นตอนที่เสร็จสิ้นแล้วจะถูกข้ามและสร้างใบรับรอง
  OCSP ใหม่เฉพาะเมื่อจำเป็น
