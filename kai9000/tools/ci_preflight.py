#!/usr/bin/env python3
"""KAI 9000 / Lum Android build preflight for GitHub Actions.

Python is the build conductor: it validates the Godot project and Android
preset before the Godot exporter creates the APK.  It also emits a
base64-encoded JSON session manifest (forge-output/manifest.b64) that the
in-app cockpit decodes at runtime to pre-load the OpenAI Lum agent with
accurate structural context.
"""
from __future__ import annotations

import base64
import json
import platform
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "project.godot"
PRESETS = ROOT / "export_presets.cfg"
MAIN_SCENE = ROOT / "main.tscn"
SCRIPT_MAIN = ROOT / "scripts" / "main.gd"
SCRIPT_COCKPIT = ROOT / "scripts" / "cockpit.gd"
OUT_DIR = ROOT.parent / "forge-output"
OUT_PREFLIGHT = OUT_DIR / "preflight.json"
OUT_MANIFEST = OUT_DIR / "manifest.b64"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"PRECHECK FAILED: {message}")


def _extract(text: str, pattern: str, default: str = "") -> str:
    """Return first capture group from pattern, or default."""
    m = re.search(pattern, text)
    return m.group(1) if m else default


def main() -> int:
    # ── File existence ──────────────────────────────────────────────────────
    require(PROJECT.is_file(), f"missing {PROJECT}")
    require(PRESETS.is_file(), f"missing {PRESETS}")
    require(MAIN_SCENE.is_file(), f"missing {MAIN_SCENE}")
    require(SCRIPT_MAIN.is_file(), f"missing {SCRIPT_MAIN}")
    require(SCRIPT_COCKPIT.is_file(), f"missing {SCRIPT_COCKPIT}")

    project = PROJECT.read_text(encoding="utf-8")
    presets = PRESETS.read_text(encoding="utf-8")
    scene = MAIN_SCENE.read_text(encoding="utf-8")

    # ── project.godot checks ─────────────────────────────────────────────────
    require('run/main_scene="res://main.tscn"' in project, "main scene is not wired")
    require('window/size/viewport_width=1080' in project, "viewport width must be 1080")
    require('window/size/viewport_height=1920' in project, "viewport height must be 1920")
    require('renderer/rendering_method="gl_compatibility"' in project, "renderer must be gl_compatibility")

    # ── main.tscn script references ──────────────────────────────────────────
    require('path="res://scripts/main.gd"' in scene, "main.tscn does not reference scripts/main.gd")
    require('path="res://scripts/cockpit.gd"' in scene, "main.tscn does not reference scripts/cockpit.gd")

    # ── export_presets.cfg checks ────────────────────────────────────────────
    require('name="Android"' in presets, "Android export preset missing")
    require('platform="Android"' in presets, "Android platform missing")
    require('architectures/arm64-v8a=true' in presets, "ARM64 export is disabled")
    require('architectures/armeabi-v7a=false' in presets, "armeabi-v7a must be disabled")
    require('permissions/internet=true' in presets, "internet permission is disabled")
    require('package/unique_name="com.eggie.kai9000sanctuary"' in presets, "unexpected package id")
    require('package/signed=true' in presets, "APK signing is disabled")

    # ── Extract metadata for manifest ────────────────────────────────────────
    orientation_raw = _extract(project, r'window/handheld/orientation=(\d+)', "0")
    orientation = "landscape" if orientation_raw == "0" else "portrait"
    version_name = _extract(presets, r'version/name="([^"]+)"', "unknown")
    version_code = _extract(presets, r'version/code=(\d+)', "0")
    renderer = _extract(project, r'renderer/rendering_method="([^"]+)"', "gl_compatibility")

    # ── Session manifest ─────────────────────────────────────────────────────
    manifest = {
        "project": "KAI 9000 Sanctuary / Lum",
        "package": "com.eggie.kai9000sanctuary",
        "arch": "arm64-v8a",
        "version_name": version_name,
        "version_code": version_code,
        "orientation": orientation,
        "renderer": renderer,
        "openai_model": "gpt-5.6",
        "ollama_model": "qwen3:0.6b",
        "ollama_endpoint": "http://127.0.0.1:11434",
        "authority": "human-final",
        "auto_publish": False,
    }
    manifest_json = json.dumps(manifest, separators=(",", ":"))
    manifest_b64 = base64.b64encode(manifest_json.encode()).decode()

    # ── Preflight payload ────────────────────────────────────────────────────
    payload = {
        "status": "green",
        "python": sys.version.split()[0],
        "runner": platform.platform(),
        **manifest,
    }

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_PREFLIGHT.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    OUT_MANIFEST.write_text(manifest_b64 + "\n", encoding="utf-8")

    print(json.dumps(payload, indent=2))
    print(f"\nmanifest.b64 → {manifest_b64}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
