# CAGenerationAndMaintenance

Shell-Skripte für den Betrieb einer **offline, luftgespaltenen Zertifizierungsstelle**
auf OpenBSD mit OpenSSL. Der Sperrstatus wird über einen separaten
[OpenBSD OCSP-Server](https://github.com/gladiola/OpenBSDOCSPServer) veröffentlicht.
Aktualisierungen werden zwischen der Offline-CA-Maschine und der OCSP-Server-Maschine
über einen USB-Stick übertragen.

---

## Bereitstellungsplanung (vor dem Ausführen der Skripte ausfüllen)

Bereiten Sie Ihre Bereitstellungswerte vor, bevor Sie die folgenden Schritte ausführen:

- Wo wird die CA liegen?  
  default: `/root/ca`  
  tatsächlich:

- Wie heißt die Organisation und wo befindet sie sich?  
  default: `My Organization`  
  tatsächlich:

- Wie lautet der Projektname?  
  default: `MY PROJECT`  
  tatsächlich:

- Wann wird das Projekt versioniert?  
  default: `01012027`  
  tatsächlich:

- Was ist die TLD?  
  default: `example.com`  
  tatsächlich:

- Was ist die Subdomain?  
  default: `app.`  
  tatsächlich:

- Wie lautet die E-Mail-Adresse der Client-Benutzer?  
  default: `user@example.com`  
  tatsächlich:

- Wo ist der USB-Stick für die Übertragung?  
  default: `/dev/sd1i`  
  tatsächlich:

---

## Architekturübersicht

```
┌─────────────────────────────┐        USB-Stick        ┌──────────────────────────┐
│   Offline-CA-Maschine       │  ───────────────────►   │  OCSP-Server-Maschine    │
│   (OpenBSD, luftgespalt.)   │  export-to-usb.sh        │  (OpenBSD, vernetzt)     │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  physischer Transport    │  /etc/ocsp/              │
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

## Voraussetzungen

Beide Maschinen laufen unter **OpenBSD**. Installieren Sie OpenSSL, falls es noch nicht
vorhanden ist:

```sh
pkg_add openssl
```

Die OCSP-Server-Maschine benötigt außerdem den
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer), der als rc.d-Dienst
namens `ocspserver` installiert und registriert sein muss.

Alle Skripte verwenden `#!/bin/sh` (OpenBSDs ksh-basiertes `/bin/sh`), Standard-OpenBSD-
Hilfsprogramme (`mount_msdos`, `sha256`, `rcctl`, `doas`) und `openssl(1)`.
Führen Sie alle Skripte als Root über `doas` aus.

---

## Dateistruktur

```
scripts/
  setup-ca.sh               Initialisiert Root-CA-Verzeichnisse und erzeugt Root-Schlüssel/-Zertifikat
  create-intermediate-ca.sh Erstellt eine benannte Zwischen-CA, signiert von der Root-CA
  create-server-cert.sh     Stellt ein TLS-Server-Zertifikat aus (mTLS)
  create-client-cert.sh     Stellt ein Client-Zertifikat aus (mTLS)
  revoke-cert.sh            Widerruft ein Zertifikat und regeneriert die CRL
  export-to-usb.sh          Verpackt CA-Daten auf USB für Luftspalt-Übertragung (CA-Seite)
  import-from-usb.sh        Importiert vom USB in den OCSP-Server (OCSP-Server-Seite)

config/
  openssl-root.cnf.template          Root-CA OpenSSL-Konfigurationsvorlage
  openssl-intermediate.cnf.template  Zwischen-CA OpenSSL-Konfigurationsvorlage
```

---

## Schritt-für-Schritt-Nutzung

### 1 — Root-CA initialisieren  *(Offline-CA-Maschine, einmalig)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Erstellt `/root/ca/`, erzeugt einen AES-256-verschlüsselten 4096-Bit-Root-Schlüssel,
ein selbstsigniertes Zertifikat mit 20 Jahren Gültigkeit und ein OCSP-Signaturzertifikat
für die Root-CA.

### 2 — Zwischen-CA erstellen  *(Offline-CA-Maschine, einmal pro Projekt)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Dateien werden unter `/root/ca/intermediate-MY-PROJECT-01012027/` erstellt.

### 3 — Server-Zertifikat ausstellen  *(Offline-CA-Maschine)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Ausgaben im Zwischen-CA-Verzeichnis:
- `private/app.example.com.01012027.key.pem` — verschlüsselter privater Schlüssel
- `certs/app.example.com.01012027.cert.pem` — signiertes Zertifikat
- `certs/app.example.com.01012027.server.full.pfx` — PKCS#12-Bundle

### 4 — Client-Zertifikate ausstellen  *(Offline-CA-Maschine)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Für jeden Benutzer wiederholen. Übertragen Sie jedes `.full.pfx`-Bundle über einen
sicheren Kanal an den jeweiligen Benutzer.

### 5 — Zertifikat widerrufen  *(Offline-CA-Maschine)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

CRL ohne Widerruf erneuern (z. B. planmäßig):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Übertragung zum OCSP-Server via USB  *(Luftspalt-Workflow)*

#### Auf der Offline-CA-Maschine

FAT32-formatierten USB-Stick einstecken. Gerät bestätigen:

```sh
dmesg | tail -20          # nach "sd1 at ..."-Zeilen suchen
disklabel sd1             # FAT32-Partition identifizieren (meist 'i')
```

Dann exportieren:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Das Skript schreibt ein `SHA256`-Prüfsummen-Manifest und hängt das Laufwerk sicher aus.
Tragen Sie den USB-Stick physisch zur OCSP-Server-Maschine.

#### Auf der OCSP-Server-Maschine

```sh
dmesg | tail -20          # USB-Gerätename bestätigen
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Das Skript überprüft Prüfsummen, kopiert aktualisierte Dateien nach `/etc/ocsp/` und
lädt den `ocspserver`-Daemon über `rcctl` neu. Wenn `EnableIndexTxtWatch` in
`appsettings.json` auf `true` gesetzt ist, übernimmt der OCSP-Server `index.txt`-
Änderungen auch ohne Neustart automatisch.

### 7 — OCSP-Antworten prüfen

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Namenskonventionen

| Datei | Muster |
|-------|--------|
| Zwischen-CA-Schlüssel | `intermediate-PROJECT-DATE.key.pem` |
| Zwischen-CA-Zertifikat | `intermediate-PROJECT-DATE.cert.pem` |
| Zertifikatskette | `ca-chain-PROJECT-DATE.cert.pem` |
| Server-Zertifikat | `SERVER_DOMAIN.DATE.cert.pem` |
| Server-PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Client-Zertifikat | `client-USER_EMAIL.DATE.cert.pem` |
| Client-PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| OCSP-Signaturzertifikat | `INTER_NAME-ocsp.cert.pem` |

---

## Sicherheitshinweise

- Die Offline-CA-Maschine darf **niemals mit einem Netzwerk verbunden werden**.
- Root- und Zwischen-CA-Schlüssel sind AES-256-verschlüsselt. Passphrasen in einem
  Hardware-Token oder physischen Tresor aufbewahren, getrennt von den Schlüsseln.
- USB-Stick-Prüfsummen immer vor dem Import prüfen — `import-from-usb.sh` erledigt
  dies automatisch mit OpenBSDs `sha256 -C`.
- CRLs laufen standardmäßig nach 30 Tagen ab. Regelmäßige CRL-Erneuerung einplanen:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # dann export-to-usb + import-from-usb
  ```
- OCSP-Signaturzertifikate laufen nach 375 Tagen ab. Erneuern Sie diese durch erneutes
  Ausführen von `create-intermediate-ca.sh` mit denselben Argumenten; bereits erledigte
  Schritte werden übersprungen und nur ein neues OCSP-Zertifikat wird erzeugt.
