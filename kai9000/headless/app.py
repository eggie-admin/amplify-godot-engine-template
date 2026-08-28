from __future__ import annotations

import argparse
import json
import os
import sqlite3
import time
import uuid
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any

import httpx
import uvicorn
from fastapi import FastAPI, HTTPException, Query, Request, Response
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field

APP_NAME = "KAI 9000 Headless"
APP_VERSION = "0.1.0"
OLLAMA_BASE = os.environ.get("KAI_OLLAMA_BASE", "http://127.0.0.1:11434").rstrip("/")
DEFAULT_MODEL = os.environ.get("KAI_OLLAMA_MODEL", "qwen3:0.6b")
DATA_DIR = Path(os.environ.get("KAI_DATA_DIR", str(Path.home() / ".local" / "share" / "kai9000")))
DB_PATH = Path(os.environ.get("KAI_DB_PATH", str(DATA_DIR / "kai9000.db")))
REQUEST_TIMEOUT = float(os.environ.get("KAI_OLLAMA_TIMEOUT", "120"))

SCHEMA = """
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL,
    label TEXT
);

CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    model TEXT,
    created_at REAL NOT NULL,
    FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_messages_session_id_id
ON messages(session_id, id);

CREATE TABLE IF NOT EXISTS state (
    key TEXT PRIMARY KEY,
    value_json TEXT NOT NULL,
    updated_at REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS checkpoints (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    created_at REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kind TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    created_at REAL NOT NULL
);
"""


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    model_config = ConfigDict(extra="allow")

    model: str | None = None
    messages: list[ChatMessage] = Field(default_factory=list)
    stream: bool = False


class StateValue(BaseModel):
    value: Any


class CheckpointRequest(BaseModel):
    name: str
    payload: Any


def connect_db() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(DB_PATH, timeout=30, check_same_thread=False)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys=ON")
    return connection


def init_db() -> None:
    with connect_db() as db:
        db.executescript(SCHEMA)
        now = time.time()
        db.execute(
            "INSERT INTO state(key, value_json, updated_at) VALUES(?, ?, ?) "
            "ON CONFLICT(key) DO NOTHING",
            ("human_authority", json.dumps("Professor"), now),
        )
        db.execute(
            "INSERT INTO state(key, value_json, updated_at) VALUES(?, ?, ?) "
            "ON CONFLICT(key) DO NOTHING",
            ("auto_publish", json.dumps(False), now),
        )
        db.execute(
            "INSERT INTO state(key, value_json, updated_at) VALUES(?, ?, ?) "
            "ON CONFLICT(key) DO NOTHING",
            ("ollama_model", json.dumps(DEFAULT_MODEL), now),
        )


def ensure_session(session_id: str) -> None:
    now = time.time()
    with connect_db() as db:
        db.execute(
            "INSERT INTO sessions(id, created_at, updated_at) VALUES(?, ?, ?) "
            "ON CONFLICT(id) DO UPDATE SET updated_at=excluded.updated_at",
            (session_id, now, now),
        )


def store_message(session_id: str, role: str, content: str, model: str | None) -> None:
    now = time.time()
    with connect_db() as db:
        db.execute(
            "INSERT INTO messages(session_id, role, content, model, created_at) VALUES(?, ?, ?, ?, ?)",
            (session_id, role, content, model, now),
        )
        db.execute("UPDATE sessions SET updated_at=? WHERE id=?", (now, session_id))


def log_event(kind: str, payload: Any) -> None:
    with connect_db() as db:
        db.execute(
            "INSERT INTO events(kind, payload_json, created_at) VALUES(?, ?, ?)",
            (kind, json.dumps(payload, ensure_ascii=False), time.time()),
        )


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_db()
    log_event("service_start", {"version": APP_VERSION, "ollama": OLLAMA_BASE})
    yield
    log_event("service_stop", {"version": APP_VERSION})


app = FastAPI(title=APP_NAME, version=APP_VERSION, lifespan=lifespan)


@app.get("/health")
async def health() -> dict[str, Any]:
    ollama_status = "down"
    models: list[str] = []
    error: str | None = None
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"{OLLAMA_BASE}/api/tags")
            response.raise_for_status()
            payload = response.json()
            models = [item.get("name", "") for item in payload.get("models", []) if item.get("name")]
            ollama_status = "green"
    except Exception as exc:  # health endpoint must report, not crash
        error = type(exc).__name__

    return {
        "kai9000": "green",
        "version": APP_VERSION,
        "database": str(DB_PATH),
        "ollama": ollama_status,
        "ollama_base": OLLAMA_BASE,
        "default_model": DEFAULT_MODEL,
        "models": models,
        "error": error,
    }


@app.get("/v1/models")
async def models() -> JSONResponse:
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(f"{OLLAMA_BASE}/v1/models")
            response.raise_for_status()
            return JSONResponse(response.json(), status_code=response.status_code)
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=503, detail=f"Ollama unavailable: {type(exc).__name__}") from exc


@app.post("/v1/chat/completions")
async def chat(body: ChatRequest, request: Request, response: Response) -> JSONResponse:
    if body.stream:
        raise HTTPException(status_code=400, detail="Streaming is not enabled in KAI 9000 headless v0.1")
    if not body.messages:
        raise HTTPException(status_code=400, detail="messages cannot be empty")

    session_id = request.headers.get("X-KAI-Session") or str(uuid.uuid4())
    model = body.model or DEFAULT_MODEL
    ensure_session(session_id)

    last_user = next((item for item in reversed(body.messages) if item.role == "user"), None)
    if last_user is not None:
        store_message(session_id, "user", last_user.content, model)

    payload = body.model_dump(exclude_none=True)
    payload["model"] = model
    payload["stream"] = False

    try:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            upstream = await client.post(f"{OLLAMA_BASE}/v1/chat/completions", json=payload)
    except httpx.HTTPError as exc:
        log_event("ollama_error", {"session_id": session_id, "error": type(exc).__name__})
        raise HTTPException(status_code=503, detail=f"Ollama unavailable: {type(exc).__name__}") from exc

    try:
        upstream_json = upstream.json()
    except ValueError as exc:
        raise HTTPException(status_code=502, detail="Ollama returned invalid JSON") from exc

    if upstream.is_error:
        return JSONResponse(upstream_json, status_code=upstream.status_code, headers={"X-KAI-Session": session_id})

    choices = upstream_json.get("choices", [])
    if choices:
        assistant = choices[0].get("message", {}).get("content")
        if assistant:
            store_message(session_id, "assistant", str(assistant), model)

    log_event("chat_completion", {"session_id": session_id, "model": model})
    return JSONResponse(upstream_json, status_code=upstream.status_code, headers={"X-KAI-Session": session_id})


@app.get("/v1/history/{session_id}")
def history(session_id: str, limit: int = Query(default=100, ge=1, le=1000)) -> dict[str, Any]:
    with connect_db() as db:
        rows = db.execute(
            "SELECT id, role, content, model, created_at FROM messages "
            "WHERE session_id=? ORDER BY id DESC LIMIT ?",
            (session_id, limit),
        ).fetchall()
    items = [dict(row) for row in reversed(rows)]
    return {"session_id": session_id, "messages": items}


@app.get("/v1/state")
def get_state() -> dict[str, Any]:
    with connect_db() as db:
        rows = db.execute("SELECT key, value_json, updated_at FROM state ORDER BY key").fetchall()
    return {
        "state": {
            row["key"]: {"value": json.loads(row["value_json"]), "updated_at": row["updated_at"]}
            for row in rows
        }
    }


@app.put("/v1/state/{key}")
def put_state(key: str, body: StateValue) -> dict[str, Any]:
    if key in {"embedded_api_key", "api_key", "secret", "password"}:
        raise HTTPException(status_code=400, detail="KAI 9000 does not persist secrets in SQLite")
    now = time.time()
    value_json = json.dumps(body.value, ensure_ascii=False)
    with connect_db() as db:
        db.execute(
            "INSERT INTO state(key, value_json, updated_at) VALUES(?, ?, ?) "
            "ON CONFLICT(key) DO UPDATE SET value_json=excluded.value_json, updated_at=excluded.updated_at",
            (key, value_json, now),
        )
    log_event("state_update", {"key": key})
    return {"key": key, "value": body.value, "updated_at": now}


@app.post("/v1/checkpoints")
def create_checkpoint(body: CheckpointRequest) -> dict[str, Any]:
    now = time.time()
    with connect_db() as db:
        cursor = db.execute(
            "INSERT INTO checkpoints(name, payload_json, created_at) VALUES(?, ?, ?)",
            (body.name, json.dumps(body.payload, ensure_ascii=False), now),
        )
        checkpoint_id = int(cursor.lastrowid)
    log_event("checkpoint", {"id": checkpoint_id, "name": body.name})
    return {"id": checkpoint_id, "name": body.name, "created_at": now}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="KAI 9000 Python 3 headless runtime")
    parser.add_argument("--host", default=os.environ.get("KAI_HOST", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=int(os.environ.get("KAI_PORT", "8798")))
    parser.add_argument("--certfile", default=os.environ.get("KAI_TLS_CERT"))
    parser.add_argument("--keyfile", default=os.environ.get("KAI_TLS_KEY"))
    parser.add_argument("--allow-http", action="store_true", help="Development only: run without TLS")
    parser.add_argument("--allow-remote", action="store_true", help="Explicitly permit a non-loopback bind")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.host not in {"127.0.0.1", "::1", "localhost"} and not args.allow_remote:
        raise SystemExit("Refusing non-loopback bind. Pass --allow-remote only after adding authentication.")

    tls_kwargs: dict[str, str] = {}
    if args.certfile and args.keyfile:
        certfile = str(Path(args.certfile).expanduser())
        keyfile = str(Path(args.keyfile).expanduser())
        if not Path(certfile).is_file() or not Path(keyfile).is_file():
            raise SystemExit("TLS cert/key path does not exist")
        tls_kwargs = {"ssl_certfile": certfile, "ssl_keyfile": keyfile}
    elif not args.allow_http:
        raise SystemExit("TLS is required. Set KAI_TLS_CERT and KAI_TLS_KEY, or use --allow-http for loopback development only.")

    uvicorn.run(app, host=args.host, port=args.port, log_level="info", **tls_kwargs)


if __name__ == "__main__":
    main()
