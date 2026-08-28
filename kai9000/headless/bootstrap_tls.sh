#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

DATA_DIR="${KAI_DATA_DIR:-$HOME/.local/share/kai9000}"
TLS_DIR="$DATA_DIR/tls"
mkdir -p "$TLS_DIR"
chmod 700 "$DATA_DIR" "$TLS_DIR"

KEY="$TLS_DIR/server.key"
CERT="$TLS_DIR/server.crt"

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required. In Termux: pkg install openssl" >&2
  exit 1
fi

if [[ -e "$KEY" || -e "$CERT" ]]; then
  echo "TLS material already exists in $TLS_DIR"
  echo "Delete it manually only if you intentionally want to rotate the local certificate."
  exit 0
fi

openssl req \
  -x509 \
  -newkey rsa:3072 \
  -sha256 \
  -days 825 \
  -nodes \
  -keyout "$KEY" \
  -out "$CERT" \
  -subj "/CN=localhost/O=KAI 9000 Local" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:::1" \
  -addext "basicConstraints=critical,CA:FALSE" \
  -addext "keyUsage=critical,digitalSignature,keyEncipherment" \
  -addext "extendedKeyUsage=serverAuth"

chmod 600 "$KEY"
chmod 644 "$CERT"

cat <<EOF
KAI 9000 local TLS created:
  cert: $CERT
  key:  $KEY

Export before launch:
  export KAI_TLS_CERT="$CERT"
  export KAI_TLS_KEY="$KEY"
EOF
