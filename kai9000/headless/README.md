# KAI 9000 Python Headless Mutation

KAI 9000 now separates the Android/Godot cockpit from the local AI runtime:

```text
Godot 4 Android cockpit
        |
        | HTTPS 127.0.0.1:8798
        v
Python 3 / FastAPI headless service
        |
        +-- SQLite WAL state + chat history + checkpoints
        |
        +-- Ollama proxy -> http://127.0.0.1:11434
```

Ollama remains the local inference boss. Python becomes the headless control plane and persistence layer.

## Android / Termux bootstrap

```bash
pkg install python openssl
cd kai9000/headless
python3 -m pip install -r requirements.txt
bash bootstrap_tls.sh
bash run.sh
```

The service binds to `127.0.0.1:8798` by default and refuses a non-loopback bind unless `--allow-remote` is explicitly supplied. Do not expose it remotely until authentication and authorization are added.

## Database

Default SQLite database:

```text
~/.local/share/kai9000/kai9000.db
```

Tables:

- `sessions`
- `messages`
- `state`
- `checkpoints`
- `events`

SQLite runs in WAL mode. KAI refuses obvious secret-key names in the state API. API keys and private credentials do not belong in this database or the APK.

## API

- `GET /health` - KAI + Ollama health/model status
- `GET /v1/models` - Ollama OpenAI-compatible model list
- `POST /v1/chat/completions` - OpenAI-compatible chat proxy with SQL history
- `GET /v1/history/{session_id}` - local conversation history
- `GET /v1/state` - persistent state
- `PUT /v1/state/{key}` - persistent non-secret state
- `POST /v1/checkpoints` - durable checkpoint payloads

The Android cockpit sends a stable `X-KAI-Session` header so chat turns are grouped in SQLite.

## TLS v0.1

`bootstrap_tls.sh` generates a local self-signed certificate and private key under the KAI data directory. The Python service requires TLS unless `--allow-http` is explicitly supplied.

The current Godot mutation uses `TLSOptions.client_unsafe()` only for the loopback `127.0.0.1` service so a device-generated self-signed certificate works immediately. This encrypts the local hop but does not authenticate the certificate. The next security hardening step is per-device certificate pinning or a locally trusted CA.

## Configuration

Environment variables:

```text
KAI_DATA_DIR
KAI_DB_PATH
KAI_HOST
KAI_PORT
KAI_TLS_CERT
KAI_TLS_KEY
KAI_OLLAMA_BASE
KAI_OLLAMA_MODEL
KAI_OLLAMA_TIMEOUT
```

Defaults keep both KAI and Ollama on local loopback.
