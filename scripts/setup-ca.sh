#!/bin/sh
# setup-ca.sh — Initialize an offline root Certificate Authority using OpenSSL.
#
# Usage:
#   setup-ca.sh [CA_DIR] [SUBJECT]
#
# Arguments:
#   CA_DIR    Directory to create the CA in (default: /root/ca)
#   SUBJECT   OpenSSL distinguished-name subject for the root cert
#             (default: "/C=US/ST=Massachusetts/L=Cambridge/O=My Organization/CN=Root CA")
#
# What this script does:
#   1. Creates the standard OpenSSL CA directory layout under CA_DIR.
#   2. Installs an openssl.cnf derived from config/openssl-root.cnf.template.
#   3. Generates an AES-256-encrypted root private key (4096-bit RSA).
#   4. Creates the self-signed root CA certificate (valid 20 years).
#   5. Generates an OCSP responder key and certificate for the root CA,
#      placed in CA_DIR/ocsp/ ready to be copied to the OCSP server.
#
# Prerequisites:
#   - openssl(1) must be installed and on PATH.
#   - Run as a user with write access to CA_DIR (typically root on an air-gapped machine).
#   - The config/openssl-root.cnf.template file must exist relative to this script.
#
# Example:
#   doas sh setup-ca.sh /root/ca \
#     "/C=US/ST=Massachusetts/L=Cambridge/O=ACME Corp/CN=ACME Root CA"

set -eu

# ── Helpers ────────────────────────────────────────────────────────────────────
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*"; }

# ── Resolve script directory so we can find config templates ──────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE="${REPO_ROOT}/config/openssl-root.cnf.template"

[ -f "${TEMPLATE}" ] || die "Template not found: ${TEMPLATE}"

# ── Arguments ─────────────────────────────────────────────────────────────────
CA_DIR="${1:-/root/ca}"
SUBJECT="${2:-/C=US/ST=Massachusetts/L=Cambridge/O=My Organization/CN=Root CA}"

info "CA root directory : ${CA_DIR}"
info "Subject           : ${SUBJECT}"

# ── Create directory layout ───────────────────────────────────────────────────
info "Creating CA directory structure..."
mkdir -p \
    "${CA_DIR}/certs" \
    "${CA_DIR}/crl" \
    "${CA_DIR}/newcerts" \
    "${CA_DIR}/private" \
    "${CA_DIR}/ocsp"

chmod 700 "${CA_DIR}/private"

# Initialise the serial and index files only if they don't exist yet
[ -f "${CA_DIR}/index.txt" ]  || touch "${CA_DIR}/index.txt"
[ -f "${CA_DIR}/serial" ]     || printf '1000\n' > "${CA_DIR}/serial"
[ -f "${CA_DIR}/crlnumber" ]  || printf '1000\n' > "${CA_DIR}/crlnumber"

# ── Install openssl.cnf ───────────────────────────────────────────────────────
OPENSSL_CNF="${CA_DIR}/openssl.cnf"
if [ -f "${OPENSSL_CNF}" ]; then
    info "openssl.cnf already exists — skipping (remove it manually to regenerate)."
else
    info "Installing ${OPENSSL_CNF}..."
    sed "s|@@CA_DIR@@|${CA_DIR}|g" "${TEMPLATE}" > "${OPENSSL_CNF}"
fi

# ── Generate root private key ─────────────────────────────────────────────────
ROOT_KEY="${CA_DIR}/private/ca.key.pem"
if [ -f "${ROOT_KEY}" ]; then
    info "Root key already exists — skipping key generation."
else
    info "Generating root private key (4096-bit RSA, AES-256 encrypted)..."
    info "You will be prompted to set a passphrase — keep it safe and offline."
    openssl genrsa -aes256 -out "${ROOT_KEY}" 4096
    chmod 400 "${ROOT_KEY}"
fi

# ── Create root certificate ───────────────────────────────────────────────────
ROOT_CERT="${CA_DIR}/certs/ca.cert.pem"
if [ -f "${ROOT_CERT}" ]; then
    info "Root certificate already exists — skipping."
else
    info "Creating self-signed root certificate (valid 7300 days / ~20 years)..."
    info "You will be prompted for the root key passphrase."
    openssl req \
        -config "${OPENSSL_CNF}" \
        -key "${ROOT_KEY}" \
        -new -x509 \
        -days 7300 \
        -sha256 \
        -extensions v3_ca \
        -subj "${SUBJECT}" \
        -out "${ROOT_CERT}"
    chmod 444 "${ROOT_CERT}"
fi

info "Verifying root certificate..."
openssl x509 -noout -text -in "${ROOT_CERT}" | grep -E 'Subject:|Issuer:|Not '

# ── Generate OCSP responder key and certificate for the root CA ───────────────
OCSP_KEY="${CA_DIR}/ocsp/root-ocsp.key.pem"
OCSP_CERT="${CA_DIR}/ocsp/root-ocsp.cert.pem"
OCSP_CSR="${CA_DIR}/ocsp/root-ocsp.csr.pem"

if [ -f "${OCSP_CERT}" ]; then
    info "Root OCSP responder certificate already exists — skipping."
else
    info "Generating OCSP responder key (4096-bit RSA, unencrypted for automated signing)..."
    openssl genrsa -out "${OCSP_KEY}" 4096
    chmod 400 "${OCSP_KEY}"

    info "Creating OCSP responder CSR..."
    openssl req \
        -config "${OPENSSL_CNF}" \
        -new -sha256 \
        -key "${OCSP_KEY}" \
        -subj "$(printf '%s/CN=Root OCSP Responder' "$(printf '%s' "${SUBJECT}" | sed 's|/CN=[^/]*||')")" \
        -out "${OCSP_CSR}"

    info "Signing OCSP responder certificate (valid 375 days)..."
    info "You will be prompted for the root CA key passphrase."
    openssl ca \
        -config "${OPENSSL_CNF}" \
        -extensions ocsp \
        -days 375 \
        -notext \
        -md sha256 \
        -in "${OCSP_CSR}" \
        -out "${OCSP_CERT}"
    chmod 444 "${OCSP_CERT}"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
cat <<EOF

===  Root CA initialisation complete  ===

  CA directory   : ${CA_DIR}
  Root key       : ${ROOT_KEY}   (AES-256 encrypted — keep offline)
  Root cert      : ${ROOT_CERT}
  OCSP key       : ${OCSP_KEY}
  OCSP cert      : ${OCSP_CERT}

Next steps:
  1. Create an intermediate CA:
       sh scripts/create-intermediate-ca.sh PROJECT-NAME DATE_SUFFIX [CA_DIR]
  2. Distribute the root cert (${ROOT_CERT}) to all clients that need to trust this CA.
  3. Copy the OCSP key/cert to the OCSP server:
       sh scripts/export-to-ocsp.sh --root [CA_DIR] [OCSP_SERVER_DIR]
EOF
