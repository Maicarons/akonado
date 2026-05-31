# Akonado

[简体中文](README.md)

Full-pipeline AI visual novel asset generator built on Godot + Konado.

<div align="center">
  <img src="https://img.shields.io/badge/Godot-4.6+-blue.svg?style=flat-square&logo=godotengine&logoSize=14" alt="Godot" height="20">
  <img src="https://img.shields.io/badge/Python-3.10+-green.svg?style=flat-square&logo=python&logoSize=14" alt="Python" height="20">
  <img src="https://img.shields.io/badge/License-AGPL_3.0-purple.svg?style=flat-square&logoSize=14" alt="License" height="20">
</div>

<br>

## Overview

Akonado is an AI-powered visual novel asset generation pipeline. Starting from a one-sentence summary, it automatically generates complete scripts, character sprites, backgrounds, BGM, sound effects, voice acting, and UI assets — ready to run in Godot with the Konado plugin.

**Key features:**

- One sentence → full script + characters + scene settings
- Character sprite generation (ComfyUI, auto background removal)
- Background, BGM, SFX, UI asset generation
- Voice synthesis: MiMo TTS (cloud) / Qwen3 TTS (local GPU)
- JSON-driven asset manifests for easy editing and automation
- Web GUI for visual editing and generation control
- CLI for batch operations
- Extensible provider and skill system

## Quick Start

### Run the Visual Novel (Godot)

1. Clone this repository
2. Open the project in Godot 4.6+
3. Generate assets with Akonado, then run

### Generate Assets (Python)

```bash
# Install
cd akonado
pip install -e .

# Configure API keys
cp .env.example .env
# Edit .env with your keys

# Check provider availability
python -m akonado check

# Generate script from one sentence
python -m akonado skill run -n generate_script -i "a story about a milk tea shop"

# Generate all assets
python -m akonado generate all

# Launch Web GUI
python -m akonado web
```

## Project Structure

```
akonado/                  # Project root (Godot project)
  addons/konado/          # Konado plugin (upstream VN framework)
  assets/                 # Game assets (AI-generated)
  story/                  # .ks scripts (AI-generated)
  docs/
    konado/               # Konado framework docs
    akonado/              # Akonado AI pipeline docs
  akonado/                # AI asset generation pipeline (Python package)
    providers/            # Backend abstraction (LLM, Image, TTS)
    generators/           # Asset generators
    skills/               # LLM prompt templates (JSON)
    manifests/            # Asset manifest definitions (JSON)
    web/                  # Flask Web GUI
    comfyui/              # ComfyUI workflow templates
```

## Commands

| Command | Description |
|---------|-------------|
| `python -m akonado check` | Check provider availability |
| `python -m akonado generate <type>` | Generate assets (characters/backgrounds/bgm/se/voice/ui/dialogue/all) |
| `python -m akonado list [type]` | View manifest contents |
| `python -m akonado clean <type>` | Delete generated files |
| `python -m akonado skill list` | List available skills |
| `python -m akonado skill run -n <name> -i <input>` | Run an LLM skill |
| `python -m akonado web` | Launch Web GUI |

## Documentation

- [Getting Started](docs/akonado/getting-started.md)
- [Architecture](docs/akonado/architecture.md)
- [Providers](docs/akonado/providers.md)
- [Skills](docs/akonado/skills.md)
- [Manifests](docs/akonado/manifests.md)
- [Web GUI](docs/akonado/web-gui.md)
- [Konado Framework Docs](docs/konado/)

## Dependencies

- [Konado](https://github.com/DSOE1024/Konado) — Godot visual novel dialogue framework (BSD-3-Clause)

## License

AGPL-3.0-only
