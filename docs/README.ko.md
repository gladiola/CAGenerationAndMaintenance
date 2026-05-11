# CAGenerationAndMaintenance

OpenSSL을 사용하여 OpenBSD에서 **오프라인, 에어갭 인증 기관(CA)** 을 운영하기 위한
셸 스크립트입니다. 폐지 상태는 별도의
[OpenBSD OCSP 서버](https://github.com/gladiola/OpenBSDOCSPServer)를 통해 게시됩니다.
업데이트는 USB 드라이브를 통해 오프라인 CA 기기와 OCSP 서버 기기 간에 전송됩니다.

---

## 아키텍처 개요

```
┌─────────────────────────────┐        USB 드라이브     ┌──────────────────────────┐
│   오프라인 CA 기기          │  ───────────────────►   │  OCSP 서버 기기          │
│   (OpenBSD, 에어갭)         │  export-to-usb.sh        │  (OpenBSD, 네트워크 연결)│
│                             │  ◄───────────────────   │                          │
│  /root/ca/                  │  물리적 이동             │  /etc/ocsp/              │
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

## 사전 요구사항

두 기기 모두 **OpenBSD**를 실행합니다. OpenSSL이 없는 경우 설치하세요:

```sh
pkg_add openssl
```

OCSP 서버 기기에는 `ocspserver`라는 rc.d 서비스로 설치 및 등록된
[OpenBSDOCSPServer](https://github.com/gladiola/OpenBSDOCSPServer)도 필요합니다.

모든 스크립트는 `#!/bin/sh`(OpenBSD의 ksh 기반 `/bin/sh`), 표준 OpenBSD
유틸리티(`mount_msdos`, `sha256`, `rcctl`, `doas`) 및 `openssl(1)`을 사용합니다.
모든 스크립트를 `doas`를 통해 root로 실행하세요.

---

## 파일 레이아웃

```
scripts/
  setup-ca.sh               루트 CA 디렉터리를 초기화하고 루트 키/인증서 생성
  create-intermediate-ca.sh 루트 CA가 서명한 중간 CA 생성
  create-server-cert.sh     TLS 서버 인증서 발급 (mTLS)
  create-client-cert.sh     클라이언트 인증서 발급 (mTLS)
  revoke-cert.sh            인증서 폐지 및 CRL 재생성
  export-to-usb.sh          에어갭 전송용 CA 데이터를 USB에 패키징 (CA 측)
  import-from-usb.sh        USB에서 OCSP 서버로 가져오기 (OCSP 서버 측)

config/
  openssl-root.cnf.template          루트 CA OpenSSL 설정 템플릿
  openssl-intermediate.cnf.template  중간 CA OpenSSL 설정 템플릿
```

---

## 단계별 사용법

### 1 — 루트 CA 초기화  *(오프라인 CA 기기, 한 번)*

```sh
doas sh scripts/setup-ca.sh /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Root CA"
```

`/root/ca/`를 생성하고, AES-256으로 암호화된 4096비트 루트 키, 20년 유효
자체 서명 인증서, 루트 CA용 OCSP 서명 인증서를 생성합니다.

### 2 — 중간 CA 생성  *(오프라인 CA 기기, 프로젝트당 한 번)*

```sh
doas sh scripts/create-intermediate-ca.sh MY-PROJECT 01012027 /root/ca \
  "/C=US/ST=MyState/L=MyCity/O=My Organization/CN=My Organization Intermediate CA MY-PROJECT 01012027"
```

파일은 `/root/ca/intermediate-MY-PROJECT-01012027/` 아래에 생성됩니다.

### 3 — 서버 인증서 발급  *(오프라인 CA 기기)*

```sh
doas sh scripts/create-server-cert.sh MY-PROJECT 01012027 \
  app.example.com \
  "DNS:app.example.com,DNS:www.example.com" \
  /root/ca
```

중간 CA 디렉터리에 출력:
- `private/app.example.com.01012027.key.pem` — 암호화된 개인 키
- `certs/app.example.com.01012027.cert.pem` — 서명된 인증서
- `certs/app.example.com.01012027.server.full.pfx` — PKCS#12 번들

### 4 — 클라이언트 인증서 발급  *(오프라인 CA 기기)*

```sh
doas sh scripts/create-client-cert.sh MY-PROJECT 01012027 \
  user@example.com /root/ca
```

각 사용자에 대해 반복합니다. 각 `.full.pfx` 번들을 안전한 채널을 통해
해당 사용자에게 전송하세요.

### 5 — 인증서 폐지  *(오프라인 CA 기기)*

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 \
  certs/client-user@example.com.01012027.cert.pem \
  keyCompromise /root/ca
```

폐지 없이 CRL만 갱신 (예: 정기적):

```sh
doas sh scripts/revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca
```

### 6 — USB를 통해 OCSP 서버로 전송  *(에어갭 워크플로)*

#### 오프라인 CA 기기에서

FAT32 포맷된 USB 드라이브를 삽입하고 장치를 확인하세요:

```sh
dmesg | tail -20          # "sd1 at ..." 줄 확인
disklabel sd1             # FAT32 파티션 식별 (보통 'i')
```

그런 다음 내보내기:

```sh
doas sh scripts/export-to-usb.sh MY-PROJECT 01012027 /root/ca /dev/sd1i
```

스크립트는 `SHA256` 체크섬 매니페스트를 작성하고 드라이브를 안전하게 언마운트합니다.
USB 드라이브를 OCSP 서버 기기로 물리적으로 이동하세요.

#### OCSP 서버 기기에서

```sh
dmesg | tail -20          # USB 장치 이름 확인
disklabel sd1
doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver
```

스크립트는 체크섬을 확인하고, 업데이트된 파일을 `/etc/ocsp/`에 복사하며,
`rcctl`을 통해 `ocspserver` 데몬을 다시 로드합니다. `appsettings.json`에서
`EnableIndexTxtWatch`가 `true`이면 OCSP 서버가 재로드 없이 `index.txt` 변경도
자동으로 감지합니다.

### 7 — OCSP 응답 확인

```sh
openssl ocsp \
  -issuer /etc/ocsp/intermediate-MY-PROJECT-01012027/ca-chain.cert.pem \
  -cert /path/to/cert.pem \
  -url http://localhost:2560 \
  -resp_text
```

---

## 명명 규칙

| 파일 | 패턴 |
|------|------|
| 중간 CA 키 | `intermediate-PROJECT-DATE.key.pem` |
| 중간 CA 인증서 | `intermediate-PROJECT-DATE.cert.pem` |
| 인증서 체인 | `ca-chain-PROJECT-DATE.cert.pem` |
| 서버 인증서 | `SERVER_DOMAIN.DATE.cert.pem` |
| 서버 PKCS#12 | `SERVER_DOMAIN.DATE.server.full.pfx` |
| 클라이언트 인증서 | `client-USER_EMAIL.DATE.cert.pem` |
| 클라이언트 PKCS#12 | `client-USER_EMAIL.DATE.full.pfx` |
| CRL | `intermediate.crl.pem` / `intermediate.crl.der` |
| OCSP 서명 인증서 | `INTER_NAME-ocsp.cert.pem` |

---

## 보안 참고사항

- 오프라인 CA 기기는 **절대로 네트워크에 연결해서는 안 됩니다**.
- 루트 및 중간 개인 키는 AES-256으로 암호화됩니다. 암호 구문은 하드웨어 토큰
  또는 실물 금고에 키와 별도로 보관하세요.
- 가져오기 전에 항상 USB 드라이브 체크섬을 확인하세요 — `import-from-usb.sh`가
  OpenBSD의 `sha256 -C`를 사용하여 자동으로 수행합니다.
- CRL은 기본적으로 30일 후 만료됩니다. 정기적인 CRL 갱신을 예약하세요:
  ```sh
  doas sh scripts/revoke-cert.sh MY-PROJECT DATE --crl-only
  # 그런 다음 export-to-usb + import-from-usb
  ```
- OCSP 서명 인증서는 375일 후 만료됩니다. 같은 인수로 `create-intermediate-ca.sh`를
  다시 실행하여 갱신하세요; 이미 완료된 단계는 건너뛰고 필요한 경우에만 새 OCSP
  인증서를 생성합니다.
