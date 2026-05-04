#!/bin/sh
# import-from-usb.sh — Import CA data from USB drive into the OpenBSD OCSP server.
#
# Run this script on the OCSP SERVER machine (OpenBSD) after receiving a USB drive
# from the offline CA machine.  It verifies checksums, installs the updated files,
# and reloads the OCSP server daemon so it picks up the new index.txt and CRL.
#
# Usage:
#   import-from-usb.sh [USB_DEV] [OCSP_DATA_DIR] [OCSP_DAEMON]
#
# Arguments:
#   USB_DEV        OpenBSD raw disk device for the USB FAT32 partition
#                  (default: /dev/sd1i).  Use 'disklabel sd1' to confirm.
#   OCSP_DATA_DIR  Directory where the OCSP server reads its data files.
#                  Must match Ingestion.IndexTxtWatchPath and OcspServer.*Path
#                  values in the OCSP server's appsettings.json
#                  (default: /etc/ocsp).
#   OCSP_DAEMON    Name of the OCSP server rc.d(8) service
#                  (default: ocspserver).
#
# What this script does:
#   1. Mounts the USB drive read-only.
#   2. Detects all intermediate CA export directories on the USB drive.
#   3. Verifies SHA256 checksums of every exported file.
#   4. For each intermediate CA, copies:
#        index.txt            → OCSP_DATA_DIR/<INTER_NAME>/index.txt
#        intermediate.crl.pem → OCSP_DATA_DIR/<INTER_NAME>/intermediate.crl.pem
#        intermediate.crl.der → OCSP_DATA_DIR/<INTER_NAME>/intermediate.crl.der
#        ca-chain-*.cert.pem  → OCSP_DATA_DIR/<INTER_NAME>/ca-chain.cert.pem
#        *-ocsp.cert.pem      → /etc/ocsp/<INTER_NAME>-responder.crt
#   5. Installs root CA OCSP cert if present (first-time setup).
#   6. Reloads (or restarts) the OCSP server via rcctl(8).
#
# Prerequisites:
#   - Run as root (doas sh import-from-usb.sh).
#   - The OCSP server rc.d script must be installed and enabled:
#       rcctl enable ocspserver
#   - mount_msdos(8), sha256(1), rcctl(8), openssl(1) must be available.
#
# Example:
#   disklabel sd1    # confirm USB partition
#   doas sh scripts/import-from-usb.sh /dev/sd1i /etc/ocsp ocspserver

set -eu

# ── Helpers ────────────────────────────────────────────────────────────────────
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

# ── Arguments ─────────────────────────────────────────────────────────────────
USB_DEV="${1:-/dev/sd1i}"
OCSP_DATA_DIR="${2:-/etc/ocsp}"
OCSP_DAEMON="${3:-ocspserver}"

[ -b "${USB_DEV}" ] || die "Block device not found: ${USB_DEV}. Check with 'disklabel' and try again."

USB_MOUNT="/mnt/usb"
USB_EXPORT_BASE="${USB_MOUNT}/ocsp-export"

# ── Mount USB drive read-only ──────────────────────────────────────────────────
info "Mounting ${USB_DEV} read-only at ${USB_MOUNT}..."
mkdir -p "${USB_MOUNT}"
mount_msdos -o ro "${USB_DEV}" "${USB_MOUNT}" \
    || die "Failed to mount ${USB_DEV}. Is it FAT32? Check 'dmesg' for the correct device."

_unmount() {
    info "Unmounting ${USB_MOUNT}..."
    umount "${USB_MOUNT}" || warn "umount returned non-zero; check manually."
}
trap _unmount EXIT

[ -d "${USB_EXPORT_BASE}" ] || die "No ocsp-export directory found on USB. Was the drive exported with export-to-usb.sh?"

# ── Install root CA files (first-time setup) ───────────────────────────────────
ROOT_EXPORT="${USB_EXPORT_BASE}/root"
if [ -d "${ROOT_EXPORT}" ]; then
    ROOT_OCSP_SRC="${ROOT_EXPORT}/root-ocsp.cert.pem"
    ROOT_CERT_SRC="${ROOT_EXPORT}/ca.cert.pem"
    ROOT_OCSP_DST="${OCSP_DATA_DIR}/root-responder.crt"
    ROOT_CERT_DST="${OCSP_DATA_DIR}/ca.cert.pem"

    if [ ! -f "${ROOT_OCSP_DST}" ]; then
        info "Installing root CA OCSP responder certificate (first-time setup)..."
        mkdir -p "${OCSP_DATA_DIR}"
        [ -f "${ROOT_OCSP_SRC}" ] || die "Root OCSP cert missing from USB: ${ROOT_OCSP_SRC}"
        [ -f "${ROOT_CERT_SRC}" ] || die "Root CA cert missing from USB: ${ROOT_CERT_SRC}"
        cp "${ROOT_OCSP_SRC}" "${ROOT_OCSP_DST}"
        cp "${ROOT_CERT_SRC}" "${ROOT_CERT_DST}"
        chmod 444 "${ROOT_OCSP_DST}" "${ROOT_CERT_DST}"
        info "  ${ROOT_OCSP_DST}"
        info "  ${ROOT_CERT_DST}"
    else
        info "Root CA OCSP cert already installed — skipping."
    fi
fi

# ── Process each intermediate CA export ───────────────────────────────────────
UPDATED=0

for EXPORT_DIR in "${USB_EXPORT_BASE}"/intermediate-*; do
    [ -d "${EXPORT_DIR}" ] || continue
    INTER_NAME="$(basename "${EXPORT_DIR}")"
    info "Processing intermediate CA: ${INTER_NAME}"

    CHECKSUM_FILE="${EXPORT_DIR}/SHA256"
    [ -f "${CHECKSUM_FILE}" ] || { warn "No SHA256 file in ${EXPORT_DIR} — skipping."; continue; }

    # ── Verify checksums ──────────────────────────────────────────────────────
    info "Verifying checksums..."
    # sha256 -C checks against an existing checksum file (OpenBSD sha256(1))
    (cd "${EXPORT_DIR}" && sha256 -C "${CHECKSUM_FILE}") \
        || die "Checksum verification FAILED for ${INTER_NAME}. Do NOT use this data. Check the USB drive."
    info "Checksums verified OK."

    # ── Destination directory ─────────────────────────────────────────────────
    DEST_DIR="${OCSP_DATA_DIR}/${INTER_NAME}"
    mkdir -p "${DEST_DIR}"
    chmod 750 "${DEST_DIR}"

    # ── Validate index.txt with openssl before copying ────────────────────────
    INDEX_SRC="${EXPORT_DIR}/index.txt"
    [ -f "${INDEX_SRC}" ] || { warn "index.txt missing in ${EXPORT_DIR} — skipping."; continue; }
    # A valid OpenSSL index.txt has lines starting with V, R, or E
    if ! grep -qE '^[VRE]' "${INDEX_SRC}"; then
        # Empty (newly initialised) index.txt is valid
        INDEX_LINES="$(wc -l < "${INDEX_SRC}" | tr -d ' ')"
        if [ "${INDEX_LINES}" -gt 0 ]; then
            warn "index.txt in ${EXPORT_DIR} does not look like a valid OpenSSL database — skipping."
            continue
        fi
    fi

    # ── Copy files ────────────────────────────────────────────────────────────
    info "Installing files to ${DEST_DIR}..."

    cp "${INDEX_SRC}" "${DEST_DIR}/index.txt"
    info "  index.txt"

    for CRL_FILE in "${EXPORT_DIR}/intermediate.crl.pem" "${EXPORT_DIR}/intermediate.crl.der"; do
        [ -f "${CRL_FILE}" ] && cp "${CRL_FILE}" "${DEST_DIR}/" && info "  $(basename "${CRL_FILE}")"
    done

    CHAIN_SRC="$(ls "${EXPORT_DIR}"/ca-chain-*.cert.pem 2>/dev/null | head -1)"
    if [ -n "${CHAIN_SRC}" ] && [ -f "${CHAIN_SRC}" ]; then
        cp "${CHAIN_SRC}" "${DEST_DIR}/ca-chain.cert.pem"
        info "  ca-chain.cert.pem"
    fi

    # ── Install intermediate OCSP signing cert ────────────────────────────────
    OCSP_SRC="$(ls "${EXPORT_DIR}"/*-ocsp.cert.pem 2>/dev/null | head -1)"
    if [ -n "${OCSP_SRC}" ] && [ -f "${OCSP_SRC}" ]; then
        OCSP_DST="${OCSP_DATA_DIR}/${INTER_NAME}-responder.crt"
        cp "${OCSP_SRC}" "${OCSP_DST}"
        chmod 444 "${OCSP_DST}"
        info "  $(basename "${OCSP_DST}")"
    fi

    # ── Fix permissions ───────────────────────────────────────────────────────
    chmod 640 "${DEST_DIR}/index.txt" 2>/dev/null || true
    chmod 444 "${DEST_DIR}"/*.pem    2>/dev/null || true
    chmod 444 "${DEST_DIR}"/*.der    2>/dev/null || true

    TIMESTAMP_FILE="${EXPORT_DIR}/EXPORT_TIMESTAMP"
    if [ -f "${TIMESTAMP_FILE}" ]; then
        TIMESTAMP="$(cat "${TIMESTAMP_FILE}")"
        info "  (exported from CA at ${TIMESTAMP})"
    fi

    UPDATED=$((UPDATED + 1))
done

if [ "${UPDATED}" -eq 0 ]; then
    warn "No intermediate CA export directories found on USB drive — nothing imported."
    exit 1
fi

# ── Reload / restart OCSP server ──────────────────────────────────────────────
if rcctl check "${OCSP_DAEMON}" >/dev/null 2>&1; then
    info "Reloading ${OCSP_DAEMON} via rcctl..."
    rcctl reload "${OCSP_DAEMON}" 2>/dev/null \
        || rcctl restart "${OCSP_DAEMON}"
    info "${OCSP_DAEMON} reloaded."
else
    warn "${OCSP_DAEMON} is not running (or not registered with rcctl)."
    warn "If EnableIndexTxtWatch is true in appsettings.json the server will"
    warn "pick up the new index.txt automatically once it is started."
    warn "Start it with:  doas rcctl start ${OCSP_DAEMON}"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
cat <<EOF

===  USB import complete  ===

  Intermediate CAs updated : ${UPDATED}
  OCSP data directory      : ${OCSP_DATA_DIR}

Verify the OCSP server is responding correctly:
  openssl ocsp -issuer ${OCSP_DATA_DIR}/<INTER_NAME>/ca-chain.cert.pem \\
               -cert /path/to/cert.pem \\
               -url http://localhost:2560 -resp_text
EOF
