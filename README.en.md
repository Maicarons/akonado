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

# Generate everything from one sentence (recommended)
python -m akonado pipeline "a story about war and peace"

# Customize chapters and scenes
python -m akonado pipeline "a milk tea shop story" --chapters 5 --scenes-per-chapter 4

# Use Qwen TTS engine
python -m akonado pipeline "sci-fi adventure" --engine qwen

# Specify Godot engine directory
python -m akonado pipeline "story premise" --godot-dir "C:\path\to\Godot"

# Step-by-step generation
python -m akonado skill run -n generate_script -i "a story about a milk tea shop"
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
| `python -m akonado pipeline "<premise>"` | Generate all assets from one sentence (recommended) |
| `python -m akonado check` | Check provider availability |
| `python -m akonado generate <type>` | Generate assets (characters/backgrounds/bgm/se/voice/ui/dialogue/all) |
| `python -m akonado list [type]` | View manifest contents |
| `python -m akonado clean <type>` | Delete generated files (supports all/manifests/scripts/type, `--deep` for full cleanup) |
| `python -m akonado skill list` | List available skills |
| `python -m akonado skill run -n <name> -i <input>` | Run an LLM skill |
| `python -m akonado workflows` | List ComfyUI workflows |
| `python -m akonado web` | Launch Web GUI |

### Pipeline Options

| Option | Description | Default |
|--------|-------------|---------|
| `--chapters` | Number of chapters | 4 |
| `--scenes-per-chapter` | Scenes per chapter | 3 |
| `--engine` | TTS engine (mimo/qwen) | mimo |
| `--godot-dir` | Godot engine directory | `G:\SteamLibrary\steamapps\common\Godot Engine` |
| `--force` | Force regeneration (don't skip existing files) | false |
| `--temperature` | LLM temperature parameter | 0.7 |

## Documentation

- [Getting Started](docs/akonado/en/getting-started.md) -- Installation, configuration, first project
- [ComfyUI Setup Guide](docs/akonado/en/comfyui-setup.md) -- Image/audio generation backend
- [TTS Setup Guide](docs/akonado/en/tts-setup.md) -- MiMo TTS / Qwen TTS configuration
- [Architecture](docs/akonado/en/architecture.md)
- [Providers](docs/akonado/en/providers.md)
- [Skills](docs/akonado/en/skills.md)
- [Manifests](docs/akonado/en/manifests.md)
- [Web GUI](docs/akonado/en/web-gui.md)
- [Chinese Documentation](docs/akonado/)
- [Konado Framework Docs](docs/konado/)

## Dependencies

- [Konado](https://github.com/DSOE1024/Konado) — Godot visual novel dialogue framework (BSD-3-Clause)

## AI Usage Disclaimer

This project uses AI technology to generate visual novel assets (including but not limited to text, images, and audio). Please note:

- **AI-Generated Content**: All scripts, characters, backgrounds, music, and other content generated through this tool are produced by AI models and may contain inaccurate, inappropriate, or unexpected content.
- **Human Review Recommended**: It is recommended to review and edit generated content before use to ensure it meets project requirements and quality standards.
- **Copyright & Licensing**: The copyright of AI-generated content depends on the terms of service of the AI services used. Please review the relevant service terms before use.
- **Model Limitations**: Generation quality is limited by the capabilities of the AI models used; different models may produce different results.
- **Responsibility**: This tool is intended for assistive creation purposes only; users are responsible for the final content.

## License

AGPL-3.0-only
