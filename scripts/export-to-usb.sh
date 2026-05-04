#!/bin/sh
# export-to-usb.sh — Package CA data onto a USB drive for air-gap transfer to the OCSP server.
#
# Run this script on the OFFLINE CA machine (OpenBSD) after issuing or revoking
# certificates.  The USB drive is then physically carried to the OCSP server machine
# and imported with scripts/import-from-usb.sh.
#
# Usage:
#   export-to-usb.sh PROJECT_NAME DATE_SUFFIX [CA_DIR] [USB_DEV]
#
# Arguments:
#   PROJECT_NAME  Intermediate CA project name (e.g. MY-PROJECT).
#   DATE_SUFFIX   Date stamp used when the intermediate CA was created (e.g. 01JAN2025).
#   CA_DIR        Root CA directory (default: /root/ca).
#   USB_DEV       OpenBSD raw disk device for the USB FAT32 partition
#                 (default: /dev/sd1i).  Use 'disklabel sd1' to confirm the
#                 correct partition letter before running.
#
# What this script copies to the USB drive (under ocsp-export/PROJECT-DATE/):
#   index.txt                         — OpenSSL CA database (OCSP server reads this)
#   crl/intermediate.crl.pem          — Current CRL (PEM)
#   crl/intermediate.crl.der          — Current CRL (DER)
#   certs/ca-chain-PROJECT-DATE.cert.pem — Full certificate chain
#   ocsp/INTER-NAME-ocsp.cert.pem     — OCSP signing certificate for this intermediate CA
#   SHA256                            — Checksums of all exported files
#
# The root CA's OCSP responder cert (certs/root-ocsp.cert.pem) is also copied the
# first time (when it is absent on the USB drive's ocsp-export/root/ directory).
#
# Prerequisites:
#   - USB drive must be FAT32 formatted.
#   - Run as root (doas sh export-to-usb.sh ...).
#   - openssl(1), sha256(1), mount_msdos(8) must be available.
#
# Example:
#   disklabel sd1          # confirm USB partition label
#   doas sh scripts/export-to-usb.sh MY-PROJECT 01JAN2025 /root/ca /dev/sd1i

set -eu

# ── Helpers ────────────────────────────────────────────────────────────────────
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

# ── Arguments ─────────────────────────────────────────────────────────────────
[ $# -ge 2 ] || die "Usage: $0 PROJECT_NAME DATE_SUFFIX [CA_DIR] [USB_DEV]"

PROJECT_NAME="$1"
DATE_SUFFIX="$2"
CA_DIR="${3:-/root/ca}"
USB_DEV="${4:-/dev/sd1i}"

INTER_NAME="intermediate-${PROJECT_NAME}-${DATE_SUFFIX}"
INTER_DIR="${CA_DIR}/${INTER_NAME}"
INTER_CNF="${INTER_DIR}/openssl.cnf"

[ -f "${INTER_CNF}" ] || die "Intermediate CA not found: ${INTER_DIR}. Run create-intermediate-ca.sh first."
[ -b "${USB_DEV}" ]  || die "Block device not found: ${USB_DEV}. Check the device with 'disklabel' and try again."

USB_MOUNT="/mnt/usb"
EXPORT_DIR="${USB_MOUNT}/ocsp-export/${INTER_NAME}"
ROOT_EXPORT_DIR="${USB_MOUNT}/ocsp-export/root"
TIMESTAMP="$(date +%Y%m%dT%H%M%S)"

# ── Mount USB drive ────────────────────────────────────────────────────────────
info "Mounting ${USB_DEV} at ${USB_MOUNT}..."
mkdir -p "${USB_MOUNT}"
mount_msdos "${USB_DEV}" "${USB_MOUNT}" || die "Failed to mount ${USB_DEV}. Is it FAT32? Check 'dmesg' for the correct device."

# Ensure unmount on exit even if the script fails
_unmount() {
    info "Unmounting ${USB_MOUNT}..."
    umount "${USB_MOUNT}" || warn "umount returned non-zero; check manually."
}
trap _unmount EXIT

# ── Create export directory ────────────────────────────────────────────────────
mkdir -p "${EXPORT_DIR}"
mkdir -p "${ROOT_EXPORT_DIR}"

info "Exporting to ${EXPORT_DIR} ..."

# ── Copy intermediate CA files ─────────────────────────────────────────────────
INDEX_TXT="${INTER_DIR}/index.txt"
CRL_PEM="${INTER_DIR}/crl/intermediate.crl.pem"
CRL_DER="${INTER_DIR}/crl/intermediate.crl.der"
CHAIN_CERT="${INTER_DIR}/certs/ca-chain-${PROJECT_NAME}-${DATE_SUFFIX}.cert.pem"
OCSP_CERT="${INTER_DIR}/ocsp/${INTER_NAME}-ocsp.cert.pem"

[ -f "${INDEX_TXT}" ]  || die "index.txt not found: ${INDEX_TXT}"
[ -f "${CRL_PEM}" ]    || die "CRL (PEM) not found: ${CRL_PEM}. Run revoke-cert.sh --crl-only first."
[ -f "${CRL_DER}" ]    || die "CRL (DER) not found: ${CRL_DER}. Run revoke-cert.sh --crl-only first."
[ -f "${CHAIN_CERT}" ] || die "Chain cert not found: ${CHAIN_CERT}."
[ -f "${OCSP_CERT}" ]  || die "OCSP signing cert not found: ${OCSP_CERT}."

cp "${INDEX_TXT}"  "${EXPORT_DIR}/index.txt"
cp "${CRL_PEM}"    "${EXPORT_DIR}/intermediate.crl.pem"
cp "${CRL_DER}"    "${EXPORT_DIR}/intermediate.crl.der"
cp "${CHAIN_CERT}" "${EXPORT_DIR}/ca-chain-${PROJECT_NAME}-${DATE_SUFFIX}.cert.pem"
cp "${OCSP_CERT}"  "${EXPORT_DIR}/${INTER_NAME}-ocsp.cert.pem"

info "  index.txt"
info "  intermediate.crl.pem"
info "  intermediate.crl.der"
info "  ca-chain-${PROJECT_NAME}-${DATE_SUFFIX}.cert.pem"
info "  ${INTER_NAME}-ocsp.cert.pem"

# ── Copy root CA OCSP cert (first-time or forced refresh) ─────────────────────
ROOT_OCSP_CERT="${CA_DIR}/ocsp/root-ocsp.cert.pem"
ROOT_OCSP_DST="${ROOT_EXPORT_DIR}/root-ocsp.cert.pem"
ROOT_CERT="${CA_DIR}/certs/ca.cert.pem"
ROOT_CERT_DST="${ROOT_EXPORT_DIR}/ca.cert.pem"

if [ ! -f "${ROOT_OCSP_DST}" ]; then
    info "Exporting root CA OCSP cert (first time)..."
    [ -f "${ROOT_OCSP_CERT}" ] || die "Root OCSP cert not found: ${ROOT_OCSP_CERT}. Run setup-ca.sh first."
    cp "${ROOT_OCSP_CERT}" "${ROOT_OCSP_DST}"
    cp "${ROOT_CERT}"      "${ROOT_CERT_DST}"
    info "  root-ocsp.cert.pem"
    info "  ca.cert.pem"
else
    info "Root CA OCSP cert already on USB — skipping (delete ${ROOT_OCSP_DST} to force re-export)."
fi

# ── Write timestamp file ───────────────────────────────────────────────────────
printf '%s\n' "${TIMESTAMP}" > "${EXPORT_DIR}/EXPORT_TIMESTAMP"

# ── Generate SHA256 checksums ──────────────────────────────────────────────────
info "Computing SHA256 checksums..."
CHECKSUM_FILE="${EXPORT_DIR}/SHA256"
# sha256(1) on OpenBSD produces: SHA256 (filename) = hash
(
    cd "${EXPORT_DIR}"
    sha256 \
        index.txt \
        intermediate.crl.pem \
        intermediate.crl.der \
        "ca-chain-${PROJECT_NAME}-${DATE_SUFFIX}.cert.pem" \
        "${INTER_NAME}-ocsp.cert.pem" \
        EXPORT_TIMESTAMP \
        > "${CHECKSUM_FILE}"
)

info "Checksums written to ${CHECKSUM_FILE}:"
cat "${CHECKSUM_FILE}"

# ── Sync and unmount (trap will fire, but sync first) ─────────────────────────
info "Syncing data to USB..."
sync

cat <<EOF

===  Export complete  ===

  USB device     : ${USB_DEV}
  Export path    : ${EXPORT_DIR}
  Timestamp      : ${TIMESTAMP}

Safely remove the USB drive once this script exits, then:
  1. Insert the USB drive into the OCSP server machine.
  2. Run (as root on the OCSP server):
       doas sh scripts/import-from-usb.sh
EOF
