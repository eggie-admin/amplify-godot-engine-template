# KAI 9000 integration sockets

This directory contains manifests only. It does not contain third-party game assets, Nexus downloads, credentials, native mod executables, or model binaries.

## Runtime rules

- Ollama at `127.0.0.1:11434` is the only AI inference runtime used by the APK.
- Hugging Face support is a public metadata browser only. It does not store tokens, download models, or run inference.
- Demo plugin manifests are disabled by default and cannot execute foreign code.
- The Fallout 4 / Nexus educational adapter accepts only user-authorized, already-converted GLB/GLTF and JSON handoff data.
- Native Bethesda/Nexus mod formats and DLLs are deliberately rejected by the adapter.
- No automatic publishing or external asset redistribution.

Professor remains the final human authority for enabling any future adapter capability.
