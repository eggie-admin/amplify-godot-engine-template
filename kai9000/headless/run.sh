#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${KAI_DATA_DIR:-$HOME/.local/share/kai9000}"
TLS_DIR="$DATA_DIR/tls"

export KAI_DATA_DIR="$DATA_DIR"
export KAI_TLS_CERT="${KAI_TLS_CERT:-$TLS_DIR/server.crt}"
export KAI_TLS_KEY="${KAI_TLS_KEY:-$TLS_DIR/server.key}"
export KAI_OLLAMA_BASE="${KAI_OLLAMA_BASE:-http://127.0.0.1:11434}"
export KAI_OLLAMA_MODEL="${KAI_OLLAMA_MODEL:-qwen3:0.6b}"

if [[ ! -f "$KAI_TLS_CERT" || ! -f "$KAI_TLS_KEY" ]]; then
  echo "TLS material missing. Run: bash $HERE/bootstrap_tls.sh" >&2
  exit 1
fi

exec python3 "$HERE/app.py" --host 127.0.0.1 --port "${KAI_PORT:-8798}"
