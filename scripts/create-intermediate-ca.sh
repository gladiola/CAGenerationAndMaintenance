#!/bin/sh
# create-intermediate-ca.sh — Create a named intermediate CA signed by the root CA.
#
# Usage:
#   create-intermediate-ca.sh PROJECT_NAME DATE_SUFFIX [CA_DIR] [SUBJECT]
#
# Arguments:
#   PROJECT_NAME   Short identifier for the project (e.g. MY-PROJECT).
#   DATE_SUFFIX    Date stamp appended to file names (e.g. 01JAN2025).
#   CA_DIR         Root CA directory (default: /root/ca).
#   SUBJECT        Intermediate CA distinguished-name subject.
#                  Defaults to the root CA subject with CN replaced.
#
# The resulting intermediate CA is stored under:
#   CA_DIR/intermediate-PROJECT_NAME-DATE_SUFFIX/
#
# What this script does:
#   1. Creates the intermediate CA directory layout.
#   2. Installs an openssl.cnf derived from config/openssl-intermediate.cnf.template.
#   3. Generates an AES-256-encrypted intermediate private key (4096-bit RSA).
#   4. Creates a CSR and has the root CA sign it (valid 10 years, pathlen:0).
#   5. Builds the certificate chain file (intermediate + root).
#   6. Generates an OCSP responder key and certificate for the intermediate CA.
#
# Example:
#   doas sh create-intermediate-ca.sh MY-PROJECT 01JAN2025 /root/ca \
#     "/C=US/ST=Massachusetts/L=Cambridge/O=My Org/CN=My Org Intermediate CA MY-PROJECT 01JAN2025"

set -eu

# ── Helpers ────────────────────────────────────────────────────────────────────
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*"; }

# ── Resolve script directory ───────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE="${REPO_ROOT}/config/openssl-intermediate.cnf.template"

[ -f "${TEMPLATE}" ] || die "Template not found: ${TEMPLATE}"

# ── Arguments ─────────────────────────────────────────────────────────────────
[ $# -ge 2 ] || die "Usage: $0 PROJECT_NAME DATE_SUFFIX [CA_DIR] [SUBJECT]"

PROJECT_NAME="$1"
DATE_SUFFIX="$2"
CA_DIR="${3:-/root/ca}"
INTER_NAME="intermediate-${PROJECT_NAME}-${DATE_SUFFIX}"
INTER_DIR="${CA_DIR}/${INTER_NAME}"
SUBJECT="${4:-/C=US/ST=Massachusetts/L=Cambridge/O=My Organization/CN=Intermediate CA ${PROJECT_NAME} ${DATE_SUFFIX}}"

ROOT_CNF="${CA_DIR}/openssl.cnf"
[ -f "${ROOT_CNF}" ] || die "Root CA openssl.cnf not found at ${ROOT_CNF}. Run setup-ca.sh first."

info "Intermediate CA name : ${INTER_NAME}"
info "Intermediate CA dir  : ${INTER_DIR}"
info "Subject              : ${SUBJECT}"

# ── Create directory layout ────────────────────────────────────────────────────
info "Creating intermediate CA directory structure..."
mkdir -p \
    "${INTER_DIR}/certs" \
    "${INTER_DIR}/crl" \
    "${INTER_DIR}/csr" \
    "${INTER_DIR}/newcerts" \
    "${INTER_DIR}/private" \
    "${INTER_DIR}/ocsp"

chmod 700 "${INTER_DIR}/private"

[ -f "${INTER_DIR}/index.txt" ]  || touch "${INTER_DIR}/index.txt"
[ -f "${INTER_DIR}/serial" ]     || printf '1000\n' > "${INTER_DIR}/serial"
[ -f "${INTER_DIR}/crlnumber" ]  || printf '1000\n' > "${INTER_DIR}/crlnumber"

# ── Install openssl.cnf ────────────────────────────────────────────────────────
INTER_CNF="${INTER_DIR}/openssl.cnf"
INTER_KEY="${INTER_DIR}/private/${INTER_NAME}.key.pem"
INTER_CERT="${INTER_DIR}/certs/${INTER_NAME}.cert.pem"

if [ -f "${INTER_CNF}" ]; then
    info "openssl.cnf already exists — skipping."
else
    info "Installing ${INTER_CNF}..."
    sed \
        -e "s|@@INTER_DIR@@|${INTER_DIR}|g" \
        -e "s|@@INTER_KEY@@|${INTER_KEY}|g" \
        -e "s|@@INTER_CERT@@|${INTER_CERT}|g" \
        "${TEMPLATE}" > "${INTER_CNF}"
fi

# ── Generate intermediate private key ─────────────────────────────────────────
if [ -f "${INTER_KEY}" ]; then
    info "Intermediate key already exists — skipping."
else
    info "Generating intermediate private key (4096-bit RSA, AES-256 encrypted)..."
    info "You will be prompted to set a passphrase."
    openssl genrsa -aes256 -out "${INTER_KEY}" 4096
    chmod 400 "${INTER_KEY}"
fi

# ── Create intermediate CSR ────────────────────────────────────────────────────
INTER_CSR="${INTER_DIR}/csr/${INTER_NAME}.csr.pem"
if [ -f "${INTER_CSR}" ]; then
    info "Intermediate CSR already exists — skipping."
else
    info "Creating intermediate CA CSR..."
    info "You will be prompted for the intermediate key passphrase."
    openssl req \
        -config "${INTER_CNF}" \
        -new -sha256 \
        -key "${INTER_KEY}" \
        -subj "${SUBJECT}" \
        -out "${INTER_CSR}"
fi

# ── Sign with root CA ──────────────────────────────────────────────────────────
if [ -f "${INTER_CERT}" ]; then
    info "Intermediate certificate already exists — skipping."
else
    info "Signing intermediate CA certificate with root CA (valid 3650 days / 10 years)..."
    info "You will be prompted for the ROOT CA key passphrase."
    openssl ca \
        -config "${ROOT_CNF}" \
        -extensions v3_intermediate_ca \
        -days 3650 \
        -notext \
        -md sha256 \
        -in "${INTER_CSR}" \
        -out "${INTER_CERT}"
    chmod 444 "${INTER_CERT}"
fi

info "Verifying intermediate certificate..."
openssl verify -CAfile "${CA_DIR}/certs/ca.cert.pem" "${INTER_CERT}"

# ── Build certificate chain file ──────────────────────────────────────────────
CHAIN_CERT="${INTER_DIR}/certs/ca-chain-${PROJECT_NAME}-${DATE_SUFFIX}.cert.pem"
if [ -f "${CHAIN_CERT}" ]; then
    info "Certificate chain file already exists — skipping."
else
    info "Building certificate chain file..."
    cat "${INTER_CERT}" "${CA_DIR}/certs/ca.cert.pem" > "${CHAIN_CERT}"
    chmod 444 "${CHAIN_CERT}"
fi

# ── Generate OCSP responder key and certificate for the intermediate CA ────────
OCSP_KEY="${INTER_DIR}/ocsp/${INTER_NAME}-ocsp.key.pem"
OCSP_CERT="${INTER_DIR}/ocsp/${INTER_NAME}-ocsp.cert.pem"
OCSP_CSR="${INTER_DIR}/ocsp/${INTER_NAME}-ocsp.csr.pem"

if [ -f "${OCSP_CERT}" ]; then
    info "Intermediate OCSP responder certificate already exists — skipping."
else
    info "Generating intermediate OCSP responder key (unencrypted for automated signing)..."
    openssl genrsa -out "${OCSP_KEY}" 4096
    chmod 400 "${OCSP_KEY}"

    info "Creating intermediate OCSP responder CSR..."
    openssl req \
        -config "${INTER_CNF}" \
        -new -sha256 \
        -key "${OCSP_KEY}" \
        -subj "$(printf '%s/CN=OCSP Responder %s %s' \
            "$(printf '%s' "${SUBJECT}" | sed 's|/CN=[^/]*||')" \
            "${PROJECT_NAME}" "${DATE_SUFFIX}")" \
        -out "${OCSP_CSR}"

    info "Signing OCSP responder certificate with intermediate CA (valid 375 days)..."
    info "You will be prompted for the INTERMEDIATE CA key passphrase."
    openssl ca \
        -config "${INTER_CNF}" \
        -extensions ocsp \
        -days 375 \
        -notext \
        -md sha256 \
        -in "${OCSP_CSR}" \
        -out "${OCSP_CERT}"
    chmod 444 "${OCSP_CERT}"
fi

# ── Generate initial empty CRL ─────────────────────────────────────────────────
CRL_FILE="${INTER_DIR}/crl/intermediate.crl.pem"
if [ ! -f "${CRL_FILE}" ]; then
    info "Generating initial CRL..."
    info "You will be prompted for the intermediate CA key passphrase."
    openssl ca \
        -config "${INTER_CNF}" \
        -gencrl \
        -out "${CRL_FILE}"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
cat <<EOF

===  Intermediate CA '${INTER_NAME}' created  ===

  Directory      : ${INTER_DIR}
  Config         : ${INTER_CNF}
  Private key    : ${INTER_KEY}   (AES-256 encrypted)
  Certificate    : ${INTER_CERT}
  Chain file     : ${CHAIN_CERT}
  CRL            : ${CRL_FILE}
  OCSP key       : ${OCSP_KEY}
  OCSP cert      : ${OCSP_CERT}

Next steps:
  - Issue a server certificate:
      sh scripts/create-server-cert.sh ${PROJECT_NAME} ${DATE_SUFFIX} DOMAIN.TLD "DNS:DOMAIN.TLD" [CA_DIR]
  - Issue a client certificate:
      sh scripts/create-client-cert.sh ${PROJECT_NAME} ${DATE_SUFFIX} user@example.com [CA_DIR]
  - Publish OCSP data:
      sh scripts/export-to-ocsp.sh ${PROJECT_NAME} ${DATE_SUFFIX} [OCSP_SERVER_DIR] [CA_DIR]
EOF
