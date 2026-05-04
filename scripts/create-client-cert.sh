#!/bin/sh
# create-client-cert.sh — Issue a client certificate for mTLS, signed by an intermediate CA.
#
# Usage:
#   create-client-cert.sh PROJECT_NAME DATE_SUFFIX USER_EMAIL [CA_DIR]
#
# Arguments:
#   PROJECT_NAME  Intermediate CA project name (e.g. MY-PROJECT).
#   DATE_SUFFIX   Date stamp used when the intermediate CA was created (e.g. 01JAN2027).
#   USER_EMAIL    Email address / identifier for the client (e.g. user@example.com).
#   CA_DIR        Root CA directory (default: /root/ca).
#
# Output files (under CA_DIR/intermediate-PROJECT_NAME-DATE_SUFFIX/):
#   private/client-USER_EMAIL.DATE_SUFFIX.key.pem       — AES-256 encrypted private key (3072-bit)
#   csr/client-USER_EMAIL.DATE_SUFFIX.csr.pem           — Certificate signing request
#   certs/client-USER_EMAIL.DATE_SUFFIX.cert.pem        — Signed client certificate
#   certs/client-USER_EMAIL.DATE_SUFFIX.full.pfx        — PKCS#12 bundle for browser/OS import
#
# Example:
#   doas sh create-client-cert.sh MY-PROJECT 01JAN2027 user@example.com /root/ca

set -eu

# ── Helpers ────────────────────────────────────────────────────────────────────
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*"; }

# ── Arguments ─────────────────────────────────────────────────────────────────
[ $# -ge 3 ] || die "Usage: $0 PROJECT_NAME DATE_SUFFIX USER_EMAIL [CA_DIR]"

PROJECT_NAME="$1"
DATE_SUFFIX="$2"
USER_EMAIL="$3"
CA_DIR="${4:-/root/ca}"

INTER_NAME="intermediate-${PROJECT_NAME}-${DATE_SUFFIX}"
INTER_DIR="${CA_DIR}/${INTER_NAME}"
INTER_CNF="${INTER_DIR}/openssl.cnf"

[ -f "${INTER_CNF}" ] || die "Intermediate CA not found at ${INTER_DIR}. Run create-intermediate-ca.sh first."

CERT_BASENAME="client-${USER_EMAIL}.${DATE_SUFFIX}"
PRIVATE_KEY="${INTER_DIR}/private/${CERT_BASENAME}.key.pem"
CSR_FILE="${INTER_DIR}/csr/${CERT_BASENAME}.csr.pem"
CERT_FILE="${INTER_DIR}/certs/${CERT_BASENAME}.cert.pem"
PFX_FILE="${INTER_DIR}/certs/${CERT_BASENAME}.full.pfx"
INTER_CERT="${INTER_DIR}/certs/${INTER_NAME}.cert.pem"
ROOT_CERT="${CA_DIR}/certs/ca.cert.pem"
CHAIN_FILE="${INTER_DIR}/certs/ca-chain-${PROJECT_NAME}-${DATE_SUFFIX}.cert.pem"

info "Project / intermediate CA : ${INTER_NAME}"
info "Client email              : ${USER_EMAIL}"

# ── Generate client private key ────────────────────────────────────────────────
if [ -f "${PRIVATE_KEY}" ]; then
    info "Client private key already exists — skipping."
else
    info "Generating client private key (3072-bit RSA, AES-256 encrypted)..."
    info "You will be prompted to set a passphrase for the client key."
    openssl genrsa -aes256 -out "${PRIVATE_KEY}" 3072
    chmod 400 "${PRIVATE_KEY}"
fi

# ── Create client CSR ─────────────────────────────────────────────────────────
if [ -f "${CSR_FILE}" ]; then
    info "Client CSR already exists — skipping."
else
    info "Creating client certificate CSR (email SAN added automatically)..."
    info "You will be prompted for the client key passphrase."
    openssl req \
        -config "${INTER_CNF}" \
        -new -sha256 \
        -key "${PRIVATE_KEY}" \
        -subj "/CN=${USER_EMAIL}/emailAddress=${USER_EMAIL}" \
        -addext "subjectAltName = email:${USER_EMAIL}" \
        -out "${CSR_FILE}"
fi

# ── Sign the client certificate ────────────────────────────────────────────────
if [ -f "${CERT_FILE}" ]; then
    info "Client certificate already exists — skipping."
else
    info "Signing client certificate with intermediate CA (valid 375 days)..."
    info "You will be prompted for the INTERMEDIATE CA key passphrase."
    openssl ca \
        -config "${INTER_CNF}" \
        -extensions usr_cert \
        -days 375 \
        -notext \
        -md sha256 \
        -in "${CSR_FILE}" \
        -out "${CERT_FILE}"
    chmod 444 "${CERT_FILE}"
fi

info "Verifying client certificate..."
openssl verify -CAfile "${CHAIN_FILE}" "${CERT_FILE}"

# ── Create PKCS#12 bundle ─────────────────────────────────────────────────────
if [ -f "${PFX_FILE}" ]; then
    info "PKCS#12 bundle already exists — skipping."
else
    info "Creating PKCS#12 bundle (${PFX_FILE})..."
    info "You will be prompted for the client key passphrase, then a new export password."
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

===  Client certificate issued for '${USER_EMAIL}'  ===

  Private key    : ${PRIVATE_KEY}
  CSR            : ${CSR_FILE}
  Certificate    : ${CERT_FILE}
  PKCS#12 bundle : ${PFX_FILE}   (import into browser / OS keychain)

Distribute the PKCS#12 bundle to the user via a secure channel.
After issuing this certificate, publish updated OCSP data:
  sh scripts/export-to-ocsp.sh ${PROJECT_NAME} ${DATE_SUFFIX} [OCSP_SERVER_DIR] [CA_DIR]
EOF
