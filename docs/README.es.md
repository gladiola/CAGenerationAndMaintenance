# CAGenerationAndMaintenance

Scripts de shell para operar una **Autoridad de Certificación (CA) fuera de línea y
con espacio de aire** en OpenBSD usando OpenSSL. El estado de revocación se publica a
través de un servidor
[OpenBSD OCSP](https://github.com/gladiola/OpenBSDOCSPServer) separado.
Las actualizaciones se transfieren entre la máquina CA fuera de línea y la máquina del
servidor OCSP mediante una unidad USB.

---

## Descripción general de la arquitectura

```
┌─────────────────────────────┐        Unidad USB       ┌──────────────────────────┐
│   Máquina CA fuera de línea │  ───────────────────►   │  Máquina servidor OCSP   │
│   (OpenBSD, con air-gap)    │  export-to-usb.sh        │  (OpenBSD, en red)       │
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

## Requisitos previos

Ambas máquinas ejecutan **OpenBSD**. Instale OpenSSL si aún no está presente:

```sh
pkg_add openssl
```

La máquina del servidor OCSP también necesita el
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer) instalado y
registrado como servicio rc.d llamado `ocspserver`.

Todos los scripts usan `#!/bin/sh` (el `/bin/sh` basado en ksh de OpenBSD), utilidades
estándar de OpenBSD (`mount_msdos`, `sha256`, `rcctl`, `doas`) y `openssl(1)`.
Ejecute todos los scripts como root usando `doas`.

---

## Estructura de archivos

```
scripts/
  setup-ca.sh               Inicializa los directorios de la CA raíz y genera la clave/certificado raíz
  create-intermediate-ca.sh Crea una CA intermedia firmada por la CA raíz
  create-server-cert.sh     Emite un certificado de servidor TLS (mTLS)
  create-client-cert.sh     Emite un certificado de cliente (mTLS)
  revoke-cert.sh            Revoca un certificado y regenera la CRL
  export-to-usb.sh          Empaqueta datos de CA en USB para transferencia air-gap (lado CA)
  import-from-usb.sh        Importa desde USB al servidor OCSP (lado servidor OCSP)

config/
  openssl-root.cnf.template          Plantilla de configuración OpenSSL para CA raíz
  openssl-intermediate.cnf.template  Plantilla de configuración OpenSSL para CA intermedia
```

---

## Planificación de despliegue (complete esto antes de ejecutar scripts)

Prepare sus valores de despliegue antes de ejecutar los pasos siguientes:

- ¿Dónde va a estar la CA?  
  default: `/root/ca`  
  real:

- ¿Cuál es la organización y dónde está?  
  default: `My Organization`  
  real:

- ¿Cuál es el nombre del proyecto?  
  default: `MY PROJECT`  
  real:

- ¿Cuál es la fecha de versionado del proyecto?  
  default: `01012027`  
  real:

- ¿Cuál es el TLD?  
  default: `example.com`  
  real:

- ¿Cuál es el subdominio?  
  default: `app.`  
  real:

- ¿Cuál es la dirección de correo para el/los usuario(s) cliente?  
  default: `user@example.com`  
  real:

- ¿Dónde está la memoria USB para la transferencia?  
  default: `/dev/sd1i`  
  real:

---

## Uso paso a paso

### 1 — Inicializar la CA raíz  *(máquina CA fuera de línea, una vez)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

Crea `/root/ca/`, genera una clave raíz de 4096 bits cifrada con AES-256, un
certificado autofirmado válido por 20 años y un certificado de firma OCSP para
la CA raíz.

### 2 — Crear una CA intermedia  *(máquina CA fuera de línea, una vez por proyecto)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

Los archivos se crean en `/root/ca/intermediate-MY-PROJECT-01012027/`.

### 3 — Emitir un certificado de servidor  *(máquina CA fuera de línea)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

Salidas en el directorio de la CA intermedia:
- `private/app.example.com.01012027.key.pem` — clave privada cifrada
- `certs/app.example.com.01012027.cert.pem` — certificado firmado
- `certs/app.example.com.01012027.server.full.pfx` — paquete PKCS#12

### 4 — Emitir certificados de cliente  *(máquina CA fuera de línea)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

Repita para cada usuario. Transfiera cada paquete `.full.pfx` al usuario
correspondiente a través de un canal seguro.

### 5 — Revocar un certificado  *(máquina CA fuera de línea)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

Para renovar la CRL sin revocar nada (p. ej., de forma programada):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — Transferencia al servidor OCSP vía USB  *(flujo de trabajo air-gap)*

#### En la máquina CA fuera de línea

Inserte una unidad USB formateada en FAT32. Confirme el dispositivo:

```sh
dmesg | tail -20          # busque líneas "sd1 at ..."
disklabel sd1             # identifique la partición FAT32 (normalmente 'i')
```

Luego exporte:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

El script escribe un manifiesto de suma de comprobación `SHA256` y desmonta la
unidad de forma segura. Lleve físicamente la unidad USB a la máquina del servidor OCSP.

#### En la máquina del servidor OCSP

```sh
dmesg | tail -20          # confirme el nombre del dispositivo USB
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

El script verifica las sumas de comprobación, copia los archivos actualizados a
`/etc/ocsp/` y recarga el daemon `ocspserver` vía `rcctl`. Si `EnableIndexTxtWatch`
está en `true` en `appsettings.json`, el servidor OCSP también detectará los cambios
de `index.txt` automáticamente sin necesidad de recarga.

### 7 — Verificar respuestas OCSP

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## Convenciones de nomenclatura

| Archivo | Patrón |
|---------|--------|
| Clave CA intermedia | `intermediate-PROJECT-DATE.key.pem` |
| Certificado CA intermedia | `intermediate-PROJECT-DATE.cert.pem` |
| Cadena de certificados | `ca-chain-PROJECT-DATE.cert.pem` |
| Certificado de servidor | `SERVER_DOMAIN.DATE.cert.pem` |
| PKCS#12 de servidor | `SERVER_DOMAIN.DATE.server.full.pfx` |
| Certificado de cliente | `client-USER_EMAIL.DATE.cert.pem` |
| PKCS#12 de cliente | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| Certificado de firma OCSP | `INTER_NAME-ocsp.cert.pem` |

---

## Notas de seguridad

- La máquina CA fuera de línea **nunca debe conectarse a una red**.
- Las claves privadas de la CA raíz e intermedia están cifradas con AES-256. Guarde
  las frases de contraseña en un token de hardware o bóveda física, separados de las
  claves.
- Siempre verifique las sumas de comprobación de la unidad USB antes de importar —
  `import-from-usb.sh` lo hace automáticamente usando `sha256 -C` de OpenBSD.
- Las CRL caducan después de 30 días por defecto. Programe la renovación periódica:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # luego export-to-usb + import-from-usb
  ```
- Los certificados de firma OCSP caducan después de 375 días. Renuévelos ejecutando
  nuevamente `create-intermediate-ca.sh` con los mismos argumentos; omite los pasos
  ya completados y solo genera un nuevo certificado OCSP cuando es necesario.
