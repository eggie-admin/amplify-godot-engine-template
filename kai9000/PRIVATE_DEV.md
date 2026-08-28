# KAI 9000 private F-Droid import build

This branch is a private-development APK forge. It is intentionally not an official F-Droid submission.

## APK architecture

- Godot 4.7.2 native Android shell.
- Godot Mobile renderer with Vulkan preferred and OpenGL Compatibility fallback allowed.
- Direct local Ollama inference at `http://127.0.0.1:11434`.
- Hugging Face public model metadata browser only; no tokens, downloads, or HF inference.
- Device benchmark/settings wizard reports the actual rendering method, driver, GPU, FPS, and audio path.
- Educational Fallout 4 / Nexus animation-physics adapter is a disabled manifest socket only.
- No Python control plane, nginx, WebView, bundled Chromium, PyTorch, JAX, Lightning, or foreign mod binaries in the APK.

## GitHub artifact

The workflow uploads `kai9000-private-fdroid-import`, containing:

- `kai9000-private-fdroid-vulkan.apk`
- APK SHA-256 checksum
- `kai9000-agent-manifest.json`
- `preflight.json`

The current build uses an ephemeral debug signing key. It is suitable for private install/import testing, but a later build will not update an installed copy unless a stable signing key is configured. Do not place signing keys or tokens in the repository.

## Demo asset policy

The dummy Fallout/Nexus adapter never downloads from Nexus and does not understand Bethesda native mod packages. It accepts only user-authorized, already-converted GLB/GLTF plus JSON metadata for animation/physics demonstrations. No third-party game assets are redistributed.
