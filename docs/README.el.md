# CAGenerationAndMaintenance

Σενάρια shell για τη λειτουργία μιας **αυτόνομης, απομονωμένης Αρχής Πιστοποίησης (CA)**
σε OpenBSD με OpenSSL. Η κατάσταση ανάκλησης δημοσιεύεται μέσω ξεχωριστού
[διακομιστή OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer).
Οι ενημερώσεις μεταφέρονται μεταξύ της αυτόνομης μηχανής CA και της μηχανής
διακομιστή OCSP μέσω μονάδας USB.

---

## Επισκόπηση Αρχιτεκτονικής

```
┌─────────────────────────────┐        Μονάδα USB       ┌──────────────────────────┐
│   Αυτόνομη Μηχανή CA       │  ───────────────────►   │  Μηχανή Διακομιστή OCSP │
│   (OpenBSD, απομονωμένη)    │  export-to-usb.sh        │  (OpenBSD, σε δίκτυο)   │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  φυσική μεταφορά         │  /etc/ocsp/              │
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

## Προαπαιτούμενα

Και οι δύο μηχανές εκτελούν **OpenBSD**. Εγκαταστήστε το OpenSSL αν δεν υπάρχει ήδη:

```sh
pkg_add openssl
```

Η μηχανή διακομιστή OCSP χρειάζεται επίσης τον
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) εγκατεστημένο και
καταχωρημένο ως υπηρεσία rc.d με το όνομα `ocspserver`.

Όλα τα σενάρια χρησιμοποιούν `#!/bin/sh` (OpenBSD ksh-based `/bin/sh`), τυπικά
εργαλεία OpenBSD (`mount_msdos`, `sha256`, `rcctl`, `doas`) και `openssl(1)`.
Εκτελέστε όλα τα σενάρια ως root μέσω `doas`.

---

## Διάταξη Αρχείων

```
scripts/
  setup-ca.sh               Αρχικοποιεί τους καταλόγους της ριζικής CA και δημιουργεί ριζικό κλειδί/πιστοποιητικό
  create-intermediate-ca.sh Δημιουργεί ενδιάμεση CA υπογεγραμμένη από τη ριζική CA
  create-server-cert.sh     Εκδίδει πιστοποιητικό διακομιστή TLS (mTLS)
  create-client-cert.sh     Εκδίδει πιστοποιητικό πελάτη (mTLS)
  revoke-cert.sh            Ανακαλεί πιστοποιητικό και αναγεννά το CRL
  export-to-usb.sh          Συσκευάζει δεδομένα CA σε USB για μεταφορά απομόνωσης (πλευρά CA)
  import-from-usb.sh        Εισάγει από USB στον διακομιστή OCSP (πλευρά διακομιστή OCSP)

config/
  openssl-root.cnf.template          Πρότυπο ρύθμισης OpenSSL για ριζική CA
  openssl-intermediate.cnf.template  Πρότυπο ρύθμισης OpenSSL για ενδιάμεση CA
```

---

## Σχεδιασμός ανάπτυξης (συμπληρώστε το πριν εκτελέσετε τα σενάρια)

Προετοιμάστε τις τιμές ανάπτυξης πριν εκτελέσετε τα παρακάτω βήματα:

- Πού θα βρίσκεται η CA;  
  default: `/root/ca`  
  πραγματικό:

- Ποιος είναι ο οργανισμός και πού βρίσκεται;  
  default: `My Organization`  
  πραγματικό:

- Ποιο είναι το όνομα του έργου;  
  default: `MY PROJECT`  
  πραγματικό:

- Ποια είναι η ημερομηνία έκδοσης του έργου;  
  default: `01012027`  
  πραγματικό:

- Ποιο είναι το TLD;  
  default: `example.com`  
  πραγματικό:

- Ποιο είναι το υποτομέας;  
  default: `app.`  
  πραγματικό:

- Ποια είναι η διεύθυνση email για τον/τους χρήστη/ες πελάτη;  
  default: `user@example.com`  
  πραγματικό:

- Πού βρίσκεται το USB stick για μεταφορά;  
  default: `/dev/sd1i`  
  πραγματικό:

---

## Χρήση Βήμα Βήμα

### 1 — Αρχικοποίηση Ριζικής CA  *(αυτόνομη μηχανή CA, μια φορά)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Δημιουργεί `/root/ca/`, παράγει ριζικό κλειδί 4096-bit κρυπτογραφημένο με AES-256,
αυτο-υπογεγραμμένο πιστοποιητικό με ισχύ 20 χρόνια και πιστοποιητικό υπογραφής
OCSP για τη ριζική CA.

### 2 — Δημιουργία Ενδιάμεσης CA  *(αυτόνομη μηχανή CA, μια φορά ανά έργο)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Τα αρχεία δημιουργούνται στο `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Έκδοση Πιστοποιητικού Διακομιστή  *(αυτόνομη μηχανή CA)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Αποτελέσματα στον κατάλογο ενδιάμεσης CA:
- `private/app.example.com.01012027.key.pem` — κρυπτογραφημένο ιδιωτικό κλειδί
- `certs/app.example.com.01012027.cert.pem` — υπογεγραμμένο πιστοποιητικό
- `certs/app.example.com.01012027.server.full.pfx` — πακέτο PKCS#12

### 4 — Έκδοση Πιστοποιητικών Πελάτη  *(αυτόνομη μηχανή CA)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Επαναλάβετε για κάθε χρήστη. Μεταφέρετε κάθε πακέτο `.full.pfx` στον αντίστοιχο
χρήστη μέσω ασφαλούς καναλιού.

### 5 — Ανάκληση Πιστοποιητικού  *(αυτόνομη μηχανή CA)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Ανανέωση CRL χωρίς ανάκληση (π.χ. προγραμματισμένα):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Μεταφορά στον Διακομιστή OCSP μέσω USB  *(ροή εργασίας απομόνωσης)*

#### Στην Αυτόνομη Μηχανή CA

Εισάγετε μονάδα USB με μορφοποίηση FAT32. Επιβεβαιώστε τη συσκευή:

```sh
dmesg | tail -20          # αναζητήστε γραμμές "sd1 at ..."
disklabel sd1             # προσδιορίστε τον κατάτμηση FAT32 (συνήθως 'i')
```

Στη συνέχεια εξάγετε:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Το σενάριο γράφει ένα μανιφέστο αθροίσματος SHA256 και αποσυνδέει τη μονάδα με
ασφάλεια. Μεταφέρετε φυσικά τη μονάδα USB στη μηχανή διακομιστή OCSP.

#### Στη Μηχανή Διακομιστή OCSP

```sh
dmesg | tail -20          # επιβεβαιώστε το όνομα συσκευής USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Το σενάριο επαληθεύει αθροίσματα ελέγχου, αντιγράφει ενημερωμένα αρχεία στο
`/etc/ocsp/` και επαναφορτώνει τον daemon `ocspserver` μέσω `rcctl`. Εάν το
`EnableIndexTxtWatch` είναι `true` στο `appsettings.json`, ο διακομιστής OCSP
θα λαμβάνει αλλαγές `index.txt` αυτόματα χωρίς επαναφόρτωση.

### 7 — Επαλήθευση Απαντήσεων OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Συμβάσεις Ονοματοδοσίας

| Αρχείο | Μοτίβο |
|--------|--------|
| Κλειδί Ενδιάμεσης CA | `intermediate-PROJECT-DATE.key.pem` |
| Πιστοποιητικό Ενδιάμεσης CA | `intermediate-PROJECT-DATE.cert.pem` |
| Αλυσίδα Πιστοποιητικών | `ca-chain-PROJECT-DATE.cert.pem` |
| Πιστοποιητικό Διακομιστή | `SERVER_DOMAIN.DATE.cert.pem` |
| Διακομιστής PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Πιστοποιητικό Πελάτη | `client-USER_EMAIL.DATE.cert.pem` |
| Πελάτης PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Πιστοποιητικό Υπογραφής OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Σημειώσεις Ασφαλείας

- Η αυτόνομη μηχανή CA **δεν πρέπει ποτέ να συνδεθεί σε δίκτυο**.
- Τα ιδιωτικά κλειδιά ριζικής και ενδιάμεσης CA είναι κρυπτογραφημένα με AES-256.
  Αποθηκεύστε τις φράσεις πρόσβασης σε διακριτικό υλικού ή φυσική θυρίδα ασφαλείας,
  ξεχωριστά από τα κλειδιά.
- Πάντα επαληθεύετε αθροίσματα ελέγχου USB πριν την εισαγωγή — το `import-from-usb.sh`
  το κάνει αυτόματα χρησιμοποιώντας `sha256 -C` του OpenBSD.
- Τα CRL λήγουν μετά από 30 ημέρες εξ ορισμού. Προγραμματίστε τακτική ανανέωση CRL:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # στη συνέχεια export-to-usb + import-from-usb
  ```
- Τα πιστοποιητικά υπογραφής OCSP λήγουν μετά από 375 ημέρες. Ανανεώστε τα
  εκτελώντας ξανά `create-intermediate-ca.sh` με τα ίδια ορίσματα· τα ήδη
  ολοκληρωμένα βήματα παραλείπονται και νέο πιστοποιητικό OCSP δημιουργείται μόνο
  όταν χρειάζεται.
