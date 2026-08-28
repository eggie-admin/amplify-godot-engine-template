#!/usr/bin/env python3
"""KAI 9000 private Android build preflight.

Validates the crowned private-dev architecture before Godot exports the APK:
Godot native UI + Mobile/Vulkan preference + direct local Ollama + read-only
Hugging Face metadata catalog + disabled educational demo adapters.
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
MAIN_SCRIPT = ROOT / "scripts" / "main.gd"
AGENT_MANIFEST = ROOT / "integrations" / "agent_manifest.json"
DEMO_MANIFEST = ROOT / "integrations" / "fallout4_demo_adapter.json"
OUT = ROOT.parent / "forge-output" / "preflight.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"PRECHECK FAILED: {message}")


def main() -> int:
    for path in (PROJECT, PRESETS, MAIN_SCENE, MAIN_SCRIPT, AGENT_MANIFEST, DEMO_MANIFEST):
        require(path.is_file(), f"missing {path}")

    project = PROJECT.read_text(encoding="utf-8")
    presets = PRESETS.read_text(encoding="utf-8")
    scene = MAIN_SCENE.read_text(encoding="utf-8")
    main_script = MAIN_SCRIPT.read_text(encoding="utf-8")
    agent = json.loads(AGENT_MANIFEST.read_text(encoding="utf-8"))
    demo = json.loads(DEMO_MANIFEST.read_text(encoding="utf-8"))

    require('run/main_scene="res://main.tscn"' in project, "main scene is not wired")
    require('renderer/rendering_method.mobile="mobile"' in project, "Mobile renderer is not selected")
    require('rendering_device/driver.android="vulkan"' in project, "Android Vulkan preference missing")
    require('rendering_device/fallback_to_opengl3=true' in project, "OpenGL fallback is disabled")
    require('res://scripts/main.gd' in scene, "direct Ollama main.gd is not the scene root")
    require('res://scripts/main_headless.gd' not in scene, "Python headless bridge is still active")
    require('http://127.0.0.1:11434' in main_script, "direct local Ollama endpoint missing")
    require('name="Android"' in presets and 'platform="Android"' in presets, "Android export preset missing")
    require('architectures/arm64-v8a=true' in presets, "ARM64 export is disabled")
    require('permissions/internet=true' in presets, "network permission is disabled")
    require('permissions/record_audio=false' in presets, "microphone permission should stay off in this build")

    require(agent["runtime"]["inference_provider"] == "ollama", "Ollama is not the manifest runtime")
    require(agent["hugging_face"]["inference"] is False, "Hugging Face inference must stay disabled")
    require(agent["hugging_face"]["auto_download"] is False, "Hugging Face auto-download must stay disabled")
    require(demo["enabled"] is False, "Fallout/Nexus demo adapter must ship disabled")
    require(demo["auto_download"] is False, "demo adapter auto-download must stay disabled")
    require(demo["execute_foreign_code"] is False, "demo adapter foreign code execution must stay disabled")

    payload = {
        "status": "green",
        "python": sys.version.split()[0],
        "runner": platform.platform(),
        "project": "KAI 9000 Sanctuary / private F-Droid import build",
        "package": "com.eggie.kai9000sanctuary",
        "arch": "arm64-v8a",
        "renderer_preference": "mobile/vulkan",
        "renderer_fallback": "gl_compatibility",
        "ollama_endpoint": "http://127.0.0.1:11434",
        "hugging_face": "metadata_only",
        "demo_adapter": "disabled_manifest_socket",
        "embedded_secrets": False,
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(payload, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
