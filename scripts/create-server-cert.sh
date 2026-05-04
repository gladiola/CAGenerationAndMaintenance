#!/bin/sh
# create-server-cert.sh — Issue a TLS server certificate signed by an intermediate CA.
#
# Usage:
#   create-server-cert.sh PROJECT_NAME DATE_SUFFIX SERVER_DOMAIN SAN_LIST [CA_DIR]
#
# Arguments:
#   PROJECT_NAME   Intermediate CA project name (e.g. MY-PROJECT).
#   DATE_SUFFIX    Date stamp used when the intermediate CA was created (e.g. 01JAN2027).
#   SERVER_DOMAIN  Primary domain / CN for the certificate (e.g. example.com).
#   SAN_LIST       Comma-separated Subject Alternative Names in openssl format,
#                  e.g. "DNS:example.com,DNS:www.example.com,IP:10.0.0.1"
#   CA_DIR         Root CA directory (default: /root/ca).
#
# Output files (under CA_DIR/intermediate-PROJECT_NAME-DATE_SUFFIX/):
#   private/SERVER_DOMAIN.DATE_SUFFIX.key.pem       — AES-256 encrypted private key (3072-bit)
#   csr/SERVER_DOMAIN.DATE_SUFFIX.csr.pem           — Certificate signing request
#   certs/SERVER_DOMAIN.DATE_SUFFIX.cert.pem        — Signed server certificate
#   certs/SERVER_DOMAIN.DATE_SUFFIX.server.full.pfx — PKCS#12 bundle (cert + key + chain)
#
# Example:
#   doas sh create-server-cert.sh MY-PROJECT 01JAN2027 \
#     app.example.com \
#     "DNS:app.example.com,DNS:www.example.com" \
#     /root/ca

set -eu

# ── Helpers ────────────────────────────────────────────────────────────────────
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*"; }

# ── Arguments ─────────────────────────────────────────────────────────────────
[ $# -ge 4 ] || die "Usage: $0 PROJECT_NAME DATE_SUFFIX SERVER_DOMAIN SAN_LIST [CA_DIR]"

PROJECT_NAME="$1"
DATE_SUFFIX="$2"
SERVER_DOMAIN="$3"
SAN_LIST="$4"
CA_DIR="${5:-/root/ca}"

INTER_NAME="intermediate-${PROJECT_NAME}-${DATE_SUFFIX}"
INTER_DIR="${CA_DIR}/${INTER_NAME}"
INTER_CNF="${INTER_DIR}/openssl.cnf"

[ -f "${INTER_CNF}" ] || die "Intermediate CA not found at ${INTER_DIR}. Run create-intermediate-ca.sh first."

CERT_BASENAME="${SERVER_DOMAIN}.${DATE_SUFFIX}"
PRIVATE_KEY="${INTER_DIR}/private/${CERT_BASENAME}.key.pem"
CSR_FILE="${INTER_DIR}/csr/${CERT_BASENAME}.csr.pem"
CERT_FILE="${INTER_DIR}/certs/${CERT_BASENAME}.cert.pem"
PFX_FILE="${INTER_DIR}/certs/${CERT_BASENAME}.server.full.pfx"
CHAIN_FILE="${INTER_DIR}/certs/ca-chain-${PROJECT_NAME}-${DATE_SUFFIX}.cert.pem"
INTER_CERT="${INTER_DIR}/certs/${INTER_NAME}.cert.pem"
ROOT_CERT="${CA_DIR}/certs/ca.cert.pem"

info "Project / intermediate CA : ${INTER_NAME}"
info "Server domain             : ${SERVER_DOMAIN}"
info "SAN list                  : ${SAN_LIST}"

# ── Generate server private key ────────────────────────────────────────────────
if [ -f "${PRIVATE_KEY}" ]; then
    info "Server private key already exists — skipping."
else
    info "Generating server private key (3072-bit RSA, AES-256 encrypted)..."
    info "You will be prompted to set a passphrase for the server key."
    openssl genrsa -aes256 -out "${PRIVATE_KEY}" 3072
    chmod 400 "${PRIVATE_KEY}"
fi

# ── Create server CSR with SAN extension ──────────────────────────────────────
if [ -f "${CSR_FILE}" ]; then
    info "Server CSR already exists — skipping."
else
    info "Creating server certificate CSR..."
    info "You will be prompted for the server key passphrase."
    openssl req \
        -config "${INTER_CNF}" \
        -new -sha256 \
        -key "${PRIVATE_KEY}" \
        -subj "/CN=${SERVER_DOMAIN}" \
        -addext "subjectAltName = ${SAN_LIST}" \
        -out "${CSR_FILE}"
fi

# ── Sign the server certificate ────────────────────────────────────────────────
if [ -f "${CERT_FILE}" ]; then
    info "Server certificate already exists — skipping."
else
    info "Signing server certificate with intermediate CA (valid 375 days)..."
    info "You will be prompted for the INTERMEDIATE CA key passphrase."
    openssl ca \
        -config "${INTER_CNF}" \
        -extensions server_cert \
        -days 375 \
        -notext \
        -md sha256 \
        -in "${CSR_FILE}" \
        -out "${CERT_FILE}"
    chmod 444 "${CERT_FILE}"
fi

info "Verifying server certificate..."
openssl verify -CAfile "${CHAIN_FILE}" "${CERT_FILE}"

# ── Create PKCS#12 bundle ─────────────────────────────────────────────────────
if [ -f "${PFX_FILE}" ]; then
    info "PKCS#12 bundle already exists — skipping."
else
    info "Creating PKCS#12 bundle (${PFX_FILE})..."
    info "You will be prompted for the server key passphrase, then a new export password."
    openssl pkcs12 \
        -export \
        -out "${PFX_FILE}" \
        -inkey "${PRIVATE_KEY}" \
        -in "${CERT_FILE}" \
        -certfile "${INTER_CERT}" \
        -certfile "${ROOT_CERT}"
    chmod 400 "${PFX_FILE}"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
cat <<EOF

===  Server certificate issued  ===

  Private key    : ${PRIVATE_KEY}
  CSR            : ${CSR_FILE}
  Certificate    : ${CERT_FILE}
  PKCS#12 bundle : ${PFX_FILE}

After issuing this certificate, regenerate the CRL:
  sh scripts/revoke-cert.sh ${PROJECT_NAME} ${DATE_SUFFIX} --crl-only [CA_DIR]

Then publish OCSP data:
  sh scripts/export-to-ocsp.sh ${PROJECT_NAME} ${DATE_SUFFIX} [OCSP_SERVER_DIR] [CA_DIR]
EOF
