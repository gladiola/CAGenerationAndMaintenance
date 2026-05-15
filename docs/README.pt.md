# CAGenerationAndMaintenance

Scripts de shell para operar uma **Autoridade de Certificação (CA) offline e
com air-gap** no OpenBSD usando OpenSSL. O estado de revogação é publicado através
de um [servidor OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer) separado.
As atualizações são transferidas entre a máquina CA offline e a máquina do servidor
OCSP via pen drive USB.

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

## Visão geral da arquitetura

```
┌─────────────────────────────┐        Pen Drive USB    ┌──────────────────────────┐
│   Máquina CA offline        │  ───────────────────►   │  Máquina servidor OCSP   │
│   (OpenBSD, air-gapped)     │  export-to-usb.sh        │  (OpenBSD, em rede)      │
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  transporte físico       │  /etc/ocsp/              │
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

## Pré-requisitos

Ambas as máquinas executam **OpenBSD**. Instale o OpenSSL se ainda não estiver presente:

```sh
pkg_add openssl
```

A máquina do servidor OCSP também precisa do
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) instalado e
registrado como serviço rc.d chamado `ocspserver`.

Todos os scripts usam `#!/bin/sh` (o `/bin/sh` baseado em ksh do OpenBSD), utilitários
padrão do OpenBSD (`mount_msdos`, `sha256`, `rcctl`, `doas`) e `openssl(1)`.
Execute todos os scripts como root via `doas`.

---

## Estrutura de arquivos

```
scripts/
  setup-ca.sh               Inicializa os diretórios da CA raiz e gera a chave/certificado raiz
  create-intermediate-ca.sh Cria uma CA intermediária assinada pela CA raiz
  create-server-cert.sh     Emite um certificado de servidor TLS (mTLS)
  create-client-cert.sh     Emite um certificado de cliente (mTLS)
  revoke-cert.sh            Revoga um certificado e regenera a CRL
  export-to-usb.sh          Empacota dados da CA em USB para transferência air-gap (lado CA)
  import-from-usb.sh        Importa do USB para o servidor OCSP (lado servidor OCSP)

config/
  openssl-root.cnf.template          Modelo de configuração OpenSSL para CA raiz
  openssl-intermediate.cnf.template  Modelo de configuração OpenSSL para CA intermediária
```

---

## Planejamento de implantação (preencha isto antes de executar os scripts)

Prepare seus valores de implantação antes de executar as etapas abaixo:

- Onde a CA ficará?  
  default: `/root/ca`  
  real:

- Qual é a organização e onde ela fica?  
  default: `My Organization`  
  real:

- Qual é o nome do projeto?  
  default: `MY PROJECT`  
  real:

- Qual é a data de versionamento do projeto?  
  default: `01012027`  
  real:

- Qual é o TLD?  
  default: `example.com`  
  real:

- Qual é o subdomínio?  
  default: `app.`  
  real:

- Qual é o e-mail do(s) usuário(s) cliente?  
  default: `user@example.com`  
  real:

- Onde está o pendrive USB para transferência?  
  default: `/dev/sd1i`  
  real:

---

## Uso passo a passo

### 1 — Inicializar a CA raiz  *(máquina CA offline, uma vez)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Cria `/root/ca/`, gera uma chave raiz de 4096 bits criptografada com AES-256, um
certificado autoassinado válido por 20 anos e um certificado de assinatura OCSP para
a CA raiz.

### 2 — Criar uma CA intermediária  *(máquina CA offline, uma vez por projeto)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Os arquivos são criados em `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Emitir um certificado de servidor  *(máquina CA offline)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Saídas no diretório da CA intermediária:
- `private/app.example.com.01012027.key.pem` — chave privada criptografada
- `certs/app.example.com.01012027.cert.pem` — certificado assinado
- `certs/app.example.com.01012027.server.full.pfx` — pacote PKCS#12

### 4 — Emitir certificados de cliente  *(máquina CA offline)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Repita para cada usuário. Transfira cada pacote `.full.pfx` ao respectivo usuário
por meio de um canal seguro.

### 5 — Revogar um certificado  *(máquina CA offline)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Para renovar a CRL sem revogar nada (ex.: periodicamente):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Transferência para o servidor OCSP via USB  *(fluxo de trabalho air-gap)*

#### Na máquina CA offline

Insira um pen drive USB formatado em FAT32. Confirme o dispositivo:

```sh
dmesg | tail -20          # procure por linhas "sd1 at ..."
disklabel sd1             # identifique a partição FAT32 (normalmente 'i')
```

Em seguida, exporte:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

O script escreve um manifesto de soma de verificação `SHA256` e desmonta o drive com
segurança. Leve fisicamente o pen drive USB à máquina do servidor OCSP.

#### Na máquina do servidor OCSP

```sh
dmesg | tail -20          # confirme o nome do dispositivo USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

O script verifica as somas de verificação, copia os arquivos atualizados para
`/etc/ocsp/` e recarrega o daemon `ocspserver` via `rcctl`. Se `EnableIndexTxtWatch`
estiver `true` em `appsettings.json`, o servidor OCSP também detectará alterações no
`index.txt` automaticamente sem necessidade de recarga.

### 7 — Verificar respostas OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Convenções de nomenclatura

| Arquivo | Padrão |
|---------|--------|
| Chave CA intermediária | `intermediate-PROJECT-DATE.key.pem` |
| Certificado CA intermediária | `intermediate-PROJECT-DATE.cert.pem` |
| Cadeia de certificados | `ca-chain-PROJECT-DATE.cert.pem` |
| Certificado de servidor | `SERVER_DOMAIN.DATE.cert.pem` |
| PKCS#12 de servidor | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Certificado de cliente | `client-USER_EMAIL.DATE.cert.pem` |
| PKCS#12 de cliente | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Certificado de assinatura OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Notas de segurança

- A máquina CA offline **nunca deve ser conectada a uma rede**.
- As chaves privadas raiz e intermediárias são criptografadas com AES-256. Armazene as
  senhas em um token de hardware ou cofre físico, separados das chaves.
- Sempre verifique as somas de verificação do pen drive USB antes de importar —
  `import-from-usb.sh` faz isso automaticamente usando `sha256 -C` do OpenBSD.
- As CRLs expiram após 30 dias por padrão. Agende a renovação regular:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # em seguida export-to-usb + import-from-usb
  ```
- Os certificados de assinatura OCSP expiram após 375 dias. Renove-os executando
  novamente `create-intermediate-ca.sh` com os mesmos argumentos; as etapas já
  concluídas são ignoradas e apenas um novo certificado OCSP é gerado.
