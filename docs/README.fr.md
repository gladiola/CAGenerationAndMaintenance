# CAGenerationAndMaintenance

Scripts shell pour exploiter une **Autorité de Certification (CA) hors ligne à
isolation physique** sur OpenBSD avec OpenSSL. L'état de révocation est publié via
un [serveur OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer) séparé.
Les mises à jour sont transférées entre la machine CA hors ligne et la machine serveur
OCSP par clé USB.

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

## Vue d'ensemble de l'architecture

```
┌─────────────────────────────┐        Clé USB          ┌──────────────────────────┐
│   Machine CA hors ligne     │  ───────────────────►   │  Machine serveur OCSP    │
│   (OpenBSD, air-gappée)     │  export-to-usb.sh        │  (OpenBSD, en réseau)    │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  transport physique      │  /etc/ocsp/              │
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

## Prérequis

Les deux machines exécutent **OpenBSD**. Installez OpenSSL s'il n'est pas déjà présent :

```sh
pkg_add openssl
```

La machine serveur OCSP nécessite également
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) installé et enregistré
comme service rc.d nommé `ocspserver`.

Tous les scripts utilisent `#!/bin/sh` (le `/bin/sh` basé sur ksh d'OpenBSD), les
utilitaires standard d'OpenBSD (`mount_msdos`, `sha256`, `rcctl`, `doas`) et
`openssl(1)`. Exécutez tous les scripts en tant que root via `doas`.

---

## Structure des fichiers

```
scripts/
  setup-ca.sh               Initialise les répertoires de la CA racine et génère la clé/le certificat racine
  create-intermediate-ca.sh Crée une CA intermédiaire nommée signée par la CA racine
  create-server-cert.sh     Émet un certificat de serveur TLS (mTLS)
  create-client-cert.sh     Émet un certificat client (mTLS)
  revoke-cert.sh            Révoque un certificat et régénère la CRL
  export-to-usb.sh          Prépare les données CA sur USB pour le transfert air-gap (côté CA)
  import-from-usb.sh        Importe depuis USB vers le serveur OCSP (côté serveur OCSP)

config/
  openssl-root.cnf.template          Modèle de configuration OpenSSL pour la CA racine
  openssl-intermediate.cnf.template  Modèle de configuration OpenSSL pour la CA intermédiaire
```

---

## Planification du déploiement (à remplir avant d’exécuter les scripts)

Préparez vos valeurs de déploiement avant d’exécuter les étapes ci-dessous :

- Où la CA va-t-elle se trouver ?  
  default: `/root/ca`  
  valeur réelle :

- Quelle est l’organisation et où se trouve-t-elle ?  
  default: `My Organization`  
  valeur réelle :

- Quel est le nom du projet ?  
  default: `MY PROJECT`  
  valeur réelle :

- Quelle est la date de version du projet ?  
  default: `01012027`  
  valeur réelle :

- Quel est le TLD ?  
  default: `example.com`  
  valeur réelle :

- Quel est le sous-domaine ?  
  default: `app.`  
  valeur réelle :

- Quelle est l’adresse e-mail du/des utilisateur(s) client ?  
  default: `user@example.com`  
  valeur réelle :

- Où se trouve la clé USB pour le transfert ?  
  default: `/dev/sd1i`  
  valeur réelle :

---

## Utilisation étape par étape

### 1 — Initialiser la CA racine  *(machine CA hors ligne, une fois)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Crée `/root/ca/`, génère une clé racine de 4096 bits chiffrée AES-256, un certificat
auto-signé valable 20 ans et un certificat de signature OCSP pour la CA racine.

### 2 — Créer une CA intermédiaire  *(machine CA hors ligne, une fois par projet)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Les fichiers sont créés sous `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Émettre un certificat serveur  *(machine CA hors ligne)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Sorties dans le répertoire de la CA intermédiaire :
- `private/app.example.com.01012027.key.pem` — clé privée chiffrée
- `certs/app.example.com.01012027.cert.pem` — certificat signé
- `certs/app.example.com.01012027.server.full.pfx` — bundle PKCS#12

### 4 — Émettre des certificats clients  *(machine CA hors ligne)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Répétez pour chaque utilisateur. Transmettez chaque bundle `.full.pfx` à l'utilisateur
concerné via un canal sécurisé.

### 5 — Révoquer un certificat  *(machine CA hors ligne)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Pour renouveler la CRL sans révoquer (ex. planification régulière) :

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Transfert vers le serveur OCSP via USB  *(flux de travail air-gap)*

#### Sur la machine CA hors ligne

Insérez une clé USB formatée FAT32. Confirmez le périphérique :

```sh
dmesg | tail -20          # recherchez les lignes "sd1 at ..."
disklabel sd1             # identifiez la partition FAT32 (généralement 'i')
```

Puis exportez :

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

Le script écrit un manifeste de somme de contrôle `SHA256` et démonte le lecteur en
toute sécurité. Transportez physiquement la clé USB vers la machine serveur OCSP.

#### Sur la machine serveur OCSP

```sh
dmesg | tail -20          # confirmez le nom du périphérique USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

Le script vérifie les sommes de contrôle, copie les fichiers mis à jour dans `/etc/ocsp/`
et recharge le daemon `ocspserver` via `rcctl`. Si `EnableIndexTxtWatch` est `true`
dans `appsettings.json`, le serveur OCSP détectera également les changements d'`index.txt`
automatiquement sans rechargement.

### 7 — Vérifier les réponses OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Conventions de nommage

| Fichier | Modèle |
|---------|--------|
| Clé CA intermédiaire | `intermediate-PROJECT-DATE.key.pem` |
| Certificat CA intermédiaire | `intermediate-PROJECT-DATE.cert.pem` |
| Chaîne de certificats | `ca-chain-PROJECT-DATE.cert.pem` |
| Certificat serveur | `SERVER_DOMAIN.DATE.cert.pem` |
| PKCS#12 serveur | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Certificat client | `client-USER_EMAIL.DATE.cert.pem` |
| PKCS#12 client | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Certificat de signature OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Notes de sécurité

- La machine CA hors ligne ne doit **jamais être connectée à un réseau**.
- Les clés privées racine et intermédiaire sont chiffrées AES-256. Conservez les phrases
  de passe dans un token matériel ou un coffre physique, séparément des clés.
- Vérifiez toujours les sommes de contrôle de la clé USB avant d'importer —
  `import-from-usb.sh` le fait automatiquement avec `sha256 -C` d'OpenBSD.
- Les CRL expirent après 30 jours par défaut. Planifiez un renouvellement régulier :
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # puis export-to-usb + import-from-usb
  ```
- Les certificats de signature OCSP expirent après 375 jours. Renouvelez-les en
  réexécutant `create-intermediate-ca.sh` avec les mêmes arguments ; les étapes déjà
  effectuées sont ignorées et seul un nouveau certificat OCSP est généré.
