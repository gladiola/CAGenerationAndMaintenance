#!/bin/sh
# revoke-cert.sh — Revoke a certificate and regenerate the intermediate CA CRL.
#
# Usage:
#   revoke-cert.sh PROJECT_NAME DATE_SUFFIX CERT_FILE [REASON] [CA_DIR]
#   revoke-cert.sh PROJECT_NAME DATE_SUFFIX --crl-only [CA_DIR]
#
# Arguments:
#   PROJECT_NAME  Intermediate CA project name (e.g. MY-PROJECT).
#   DATE_SUFFIX   Date stamp used when the intermediate CA was created (e.g. 01012027).
#   CERT_FILE     Path to the certificate PEM file to revoke, relative to the
#                 intermediate CA directory OR absolute.
#                 Pass --crl-only to skip revocation and only regenerate the CRL.
#   REASON        Optional revocation reason (default: unspecified).
#                 Allowed values: unspecified, keyCompromise, CACompromise,
#                 affiliationChanged, superseded, cessationOfOperation,
#                 certificateHold, removeFromCRL
#   CA_DIR        Root CA directory (default: /root/ca).
#
# What this script does:
#   1. Marks the certificate as revoked in the intermediate CA's index.txt.
#   2. Re-generates the intermediate CA CRL (DER and PEM formats).
#   3. Prints a reminder to run export-to-usb.sh so the OCSP server is updated.
#
# Example — revoke a client certificate:
#   doas sh revoke-cert.sh MY-PROJECT 01012027 \
#     certs/client-user@example.com.01012027.cert.pem \
#     keyCompromise /root/ca
#
# Example — regenerate CRL only (e.g. on scheduled renewal):
#   doas sh revoke-cert.sh MY-PROJECT 01012027 --crl-only /root/ca

set -eu

# ── Helpers ────────────────────────────────────────────────────────────────────
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*"; }

# ── Arguments ─────────────────────────────────────────────────────────────────
[ $# -ge 3 ] || die "Usage: $0 PROJECT_NAME DATE_SUFFIX CERT_FILE|--crl-only [REASON] [CA_DIR]"

PROJECT_NAME="$1"
DATE_SUFFIX="$2"
CERT_OR_FLAG="$3"
CA_DIR="/root/ca"
REASON="unspecified"
CRL_ONLY=0

if [ "${CERT_OR_FLAG}" = "--crl-only" ]; then
    CRL_ONLY=1
    # remaining positional: [CA_DIR]
    if [ $# -ge 4 ]; then CA_DIR="$4"; fi
else
    CERT_FILE="${CERT_OR_FLAG}"
    # remaining positional: [REASON] [CA_DIR]
    if [ $# -ge 4 ]; then
        # Determine whether arg 4 looks like a reason keyword or a path
        case "$4" in
            unspecified|keyCompromise|CACompromise|affiliationChanged| \
            superseded|cessationOfOperation|certificateHold|removeFromCRL)
                REASON="$4"
                if [ $# -ge 5 ]; then CA_DIR="$5"; fi
                ;;
            *)
                CA_DIR="$4"
                ;;
        esac
    fi
fi

INTER_NAME="intermediate-${PROJECT_NAME}-${DATE_SUFFIX}"
INTER_DIR="${CA_DIR}/${INTER_NAME}"
INTER_CNF="${INTER_DIR}/openssl.cnf"

[ -f "${INTER_CNF}" ] || die "Intermediate CA not found: ${INTER_DIR}. Run create-intermediate-ca.sh first."

CRL_PEM="${INTER_DIR}/crl/intermediate.crl.pem"
CRL_DER="${INTER_DIR}/crl/intermediate.crl.der"

# ── Revoke ─────────────────────────────────────────────────────────────────────
if [ "${CRL_ONLY}" -eq 0 ]; then
    # Resolve certificate path relative to the intermediate CA dir if not absolute
    case "${CERT_FILE}" in
        /*) ABS_CERT="${CERT_FILE}" ;;
        *)  ABS_CERT="${INTER_DIR}/${CERT_FILE}" ;;
    esac

    [ -f "${ABS_CERT}" ] || die "Certificate file not found: ${ABS_CERT}"

    info "Certificate to revoke : ${ABS_CERT}"
    info "Revocation reason     : ${REASON}"

    # Show the cert subject and serial for confirmation
    CERT_SUBJECT="$(openssl x509 -noout -subject -in "${ABS_CERT}" | sed 's/subject=//')"
    CERT_SERIAL="$(openssl x509 -noout -serial -in "${ABS_CERT}" | sed 's/serial=//')"
    info "  Subject : ${CERT_SUBJECT}"
    info "  Serial  : ${CERT_SERIAL}"

    printf '\nRevoke this certificate? [y/N] '
    read -r CONFIRM
    case "${CONFIRM}" in
        [Yy]|[Yy][Ee][Ss]) ;;
        *) info "Aborted."; exit 0 ;;
    esac

    info "Revoking certificate (you will be prompted for the intermediate CA key passphrase)..."
    openssl ca \
        -config "${INTER_CNF}" \
        -revoke "${ABS_CERT}" \
        -crl_reason "${REASON}"

    info "Certificate revoked."
fi

# ── Regenerate CRL ─────────────────────────────────────────────────────────────
info "Regenerating CRL (you will be prompted for the intermediate CA key passphrase)..."
openssl ca \
    -config "${INTER_CNF}" \
    -gencrl \
    -out "${CRL_PEM}"

# Also produce a DER-encoded copy (required by some clients)
openssl crl \
    -in "${CRL_PEM}" \
    -outform DER \
    -out "${CRL_DER}"

info "CRL written to:"
info "  PEM : ${CRL_PEM}"
info "  DER : ${CRL_DER}"

# Verify and show the updated CRL
openssl crl -in "${CRL_PEM}" -noout -text | grep -E 'Last Update|Next Update|Revoked'

# ── Reminder ──────────────────────────────────────────────────────────────────
cat <<EOF

===  CRL regenerated  ===

The index.txt and CRL have been updated on this offline CA machine.
You must now transfer the updated data to the OCSP server via USB:

  doas sh scripts/export-to-usb.sh ${PROJECT_NAME} ${DATE_SUFFIX} [CA_DIR]

Then on the OCSP server machine:

  doas sh scripts/import-from-usb.sh
EOF
