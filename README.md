# CAGenerationAndMaintenance

Shell scripts for operating an **offline, air-gapped Certificate Authority** on
OpenBSD using OpenSSL, with revocation status published via a separate
[OpenBSD OCSP Server](https://github.com/gladiola/OpenBSDOCSPServer).
Updates are transferred between the offline CA machine and the OCSP server
machine by USB drive.

---

## Architecture overview

```
┌─────────────────────────────┐        USB drive        ┌──────────────────────────┐
│   Offline CA machine        │  ───────────────────►   │  OCSP server machine     │
│   (OpenBSD, air-gapped)     │  export-to-usb.sh        │  (OpenBSD, networked)    │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  physical carry          │  /etc/ocsp/              │
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

## Prerequisites

Both machines run **OpenBSD**. Install OpenSSL if it is not already present:

```sh
pkg_add openssl
```

The OCSP server machine also needs the
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) installed and
registered as an rc.d service named `ocspserver`.

All scripts use `#!/bin/sh` (OpenBSD's ksh-based `/bin/sh`), standard OpenBSD
utilities (`mount_msdos`, `sha256`, `rcctl`, `doas`), and `openssl(1)`.
Run all scripts as root via `doas`.

---

## File layout

```
scripts/
  setup-ca.sh               Initialize root CA directories and generate root key/cert
  create-intermediate-ca.sh Create a named intermediate CA signed by the root CA
  create-server-cert.sh     Issue a TLS server certificate (mTLS)
  create-client-cert.sh     Issue a client certificate (mTLS)
  revoke-cert.sh            Revoke a certificate and regenerate the CRL
  export-to-usb.sh          Package CA data onto USB for air-gap transfer (CA side)
  import-from-usb.sh        Import from USB into the OCSP server (OCSP server side)

config/
  openssl-root.cnf.template          Root CA OpenSSL config template
  openssl-intermediate.cnf.template  Intermediate CA OpenSSL config template
```

---

## Step-by-step usage

### 1 — Initialize the root CA  *(offline CA machine, once)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

This creates `/root/ca/`, generates an AES-256-encrypted 4096-bit root key, a
self-signed certificate valid for 20 years, and an OCSP signing certificate for
the root CA.

### 2 — Create an intermediate CA  *(offline CA machine, once per project)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01JAN2027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01JAN2027"
```

Files are created under `/root/ca/intermediate-MY-PROJECT-01JAN2027/`.

### 3 — Issue a server certificate  *(offline CA machine)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01JAN2027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Outputs under the intermediate CA directory:
- `private/app.example.com.01JAN2027.key.pem` — encrypted private key
- `certs/app.example.com.01JAN2027.cert.pem` — signed certificate
- `certs/app.example.com.01JAN2027.server.full.pfx` — PKCS#12 bundle

### 4 — Issue client certificates  *(offline CA machine)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01JAN2027 \
  user@example.com /root/ca
```

Repeat for each user. Transfer each `.full.pfx` bundle to the respective user
over a secure channel.

### 5 — Revoke a certificate  *(offline CA machine)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01JAN2027 \
  certs/client-user@example.com.01JAN2027.cert.pem \
  keyCompromise /root/ca
```

To renew the CRL without revoking anything (e.g. on a scheduled basis):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01JAN2027 --crl-only /root/ca
```

### 6 — Transfer to OCSP server via USB  *(air-gap workflow)*

#### On the offline CA machine

Insert a FAT32-formatted USB drive. Confirm the device:

```sh
dmesg | tail -20          # look for "sd1 at ..." lines
disklabel sd1             # identify the FAT32 partition (usually 'i')
```

Then export:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01JAN2027 /root/ca /dev/sd1i
```

The script writes a `SHA256` checksum manifest and unmounts the drive safely.
Physically carry the USB drive to the OCSP server machine.

#### On the OCSP server machine

```sh
dmesg | tail -20          # confirm USB device name
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

The script verifies checksums, copies updated files to `/etc/ocsp/`, and
reloads the `ocspserver` daemon via `rcctl`. If `EnableIndexTxtWatch` is `true`
in `appsettings.json`, the OCSP server will also pick up `index.txt` changes
automatically without a reload.

### 7 — Verify OCSP responses

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01JAN2027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Naming conventions

| File | Pattern |
|------|---------|
| Intermediate CA key | `intermediate-PROJECT-DATE.key.pem` |
| Intermediate CA cert | `intermediate-PROJECT-DATE.cert.pem` |
| Certificate chain | `ca-chain-PROJECT-DATE.cert.pem` |
| Server cert | `SERVER_DOMAIN.DATE.cert.pem` |
| Server PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Client cert | `client-USER_EMAIL.DATE.cert.pem` |
| Client PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| OCSP signing cert | `INTER_NAME-ocsp.cert.pem` |

---

## Security notes

- The offline CA machine must **never be connected to a network**.
- Root and intermediate private keys are AES-256 encrypted. Store passphrases
  in a hardware token or physical vault, separate from the keys themselves.
- Always verify USB drive checksums before importing — `import-from-usb.sh`
  does this automatically using OpenBSD's `sha256 -C`.
- CRLs expire after 30 days by default. Schedule regular CRL renewal:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # then export-to-usb + import-from-usb
  ```
- OCSP signing certificates expire after 375 days. Renew them by rerunning
  `create-intermediate-ca.sh` with the same arguments; it skips steps that are
  already complete and only generates a new OCSP cert when needed.
