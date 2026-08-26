#!/usr/bin/env python3
"""KAI 9000 / Lum Android build preflight for GitHub Actions.

Python is the build conductor: it validates the Godot project and Android
preset before the Godot exporter creates the APK.
"""
from __future__ import annotations

import json
import platform
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "project.godot"
PRESETS = ROOT / "export_presets.cfg"
MAIN_SCENE = ROOT / "main.tscn"
OUT = ROOT.parent / "forge-output" / "preflight.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"PRECHECK FAILED: {message}")


def main() -> int:
    require(PROJECT.is_file(), f"missing {PROJECT}")
    require(PRESETS.is_file(), f"missing {PRESETS}")
    require(MAIN_SCENE.is_file(), f"missing {MAIN_SCENE}")

    project = PROJECT.read_text(encoding="utf-8")
    presets = PRESETS.read_text(encoding="utf-8")

    require('run/main_scene="res://main.tscn"' in project, "main scene is not wired")
    require('name="Android"' in presets, "Android export preset missing")
    require('platform="Android"' in presets, "Android platform missing")
    require('architectures/arm64-v8a=true' in presets, "ARM64 export is disabled")
    require('permissions/internet=true' in presets, "internet permission is disabled")
    require('package/unique_name="com.eggie.kai9000sanctuary"' in presets, "unexpected package id")

    payload = {
        "status": "green",
        "python": sys.version.split()[0],
        "runner": platform.platform(),
        "project": "KAI 9000 Sanctuary / Lum",
        "package": "com.eggie.kai9000sanctuary",
        "arch": "arm64-v8a",
        "ollama_endpoint": "http://127.0.0.1:11434",
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(payload, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
