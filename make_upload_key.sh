#!/usr/bin/env bash
# Creates the app's upload signing key (PKCS12, alias "upload") with OpenSSL, so no Java/Android tools are needed.
# Run it yourself: it asks for a password that only you should know.
#
#   ./make_upload_key.sh
#
# Afterwards, add two GitHub repository secrets (Settings → Secrets and variables → Actions):
#   KEYSTORE_BASE64    paste from clipboard (this script copies it)
#   KEYSTORE_PASSWORD  the password you typed
#
# BACK UP the .p12 file and password (e.g. in a password manager). Every future update must be signed with this key.
set -euo pipefail

# Default: <project>/keys/, which is git-ignored.
OUT="${KEY_OUT:-$(cd "$(dirname "$0")" && pwd)/keys/focus-timer-upload.p12}"
if [[ -e "$OUT" ]]; then
  echo "$OUT already exists, refusing to overwrite your key." >&2
  exit 1
fi

read -r -s -p "Choose a keystore password (min 8 chars): " KS_PASS; echo
read -r -s -p "Repeat password: " KS_PASS2; echo
if [[ "$KS_PASS" != "$KS_PASS2" ]]; then echo "Passwords don't match." >&2; exit 1; fi
if (( ${#KS_PASS} < 8 )); then echo "Password too short." >&2; exit 1; fi
export KS_PASS

mkdir -p "$(dirname "$OUT")"
chmod 700 "$(dirname "$OUT")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 2048-bit RSA key, self-signed certificate valid for ~27 years.
openssl req -x509 -newkey rsa:2048 -sha256 -days 10000 -nodes \
  -subj "/CN=Focus Timer/O=shiv8080" \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null

openssl pkcs12 -export -name upload \
  -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -out "$OUT" -passout env:KS_PASS

chmod 600 "$OUT"

# Sanity check: the file opens with the password.
openssl pkcs12 -in "$OUT" -passin env:KS_PASS -nokeys -noout

if command -v pbcopy >/dev/null; then
  base64 -i "$OUT" | tr -d '\n' | pbcopy
  echo "Key created: $OUT"
  echo "Its base64 is now on your clipboard. Paste it as the KEYSTORE_BASE64 secret."
else
  echo "Key created: $OUT"
  echo "Run: base64 -i \"$OUT\" | tr -d '\\n'  and paste the output as KEYSTORE_BASE64."
fi
echo "Then add KEYSTORE_PASSWORD with the password you just typed."
echo "Back up $OUT and the password now."
