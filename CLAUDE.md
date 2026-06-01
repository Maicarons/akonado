# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Akonado is an AI-powered visual novel asset generation pipeline built on Godot 4.6 + Konado. From a one-sentence premise, it generates complete scripts, character sprites, backgrounds, BGM, sound effects, voice acting, and UI assets. The generated output runs directly in Godot using the Konado dialogue framework.

The project has two layers:
- **Python package** (`akonado/`) — CLI + Web GUI for AI asset generation (the main codebase you'll work on)
- **Godot project** (root) — runs the generated visual novel using `addons/konado/` as a dependency

## Python Package (`akonado/`)

### Setup
```bash
cd akonado
pip install -e .          # install in editable mode
cp .env.example .env      # configure API keys
python -m akonado check   # verify providers
```

### CLI Commands
```bash
python -m akonado skill run -n generate_script -i "故事概要"   # generate script from premise
python -m akonado generate all                                 # generate all assets
python -m akonado generate characters                          # generate specific type
python -m akonado generate voice --engine qwen                 # use local Qwen TTS
python -m akonado list [type]                                  # view manifest contents
python -m akonado clean <type>                                 # remove generated files
python -m akonado skill list                                   # list available LLM skills
python -m akonado web                                          # launch Web GUI (Flask)
```

### Convenience Scripts
Platform-specific wrappers in `scripts/Windows/`, `scripts/Linux/`, `scripts/macOS/`:
```bash
scripts/Windows/pipeline.cmd "故事概要"   # full pipeline: premise -> script -> all assets
scripts/Windows/generate.cmd              # generate all assets
scripts/Windows/web.cmd                   # launch web GUI
scripts/Windows/godot.cmd                 # open Godot editor
```

### Architecture

**Config** (`config.py`): All settings from `.env` via python-dotenv. Defines paths for assets, manifests, skills, and provider credentials (LLM, ComfyUI, TTS).

**Providers** (`providers/`): Abstract base classes in `base.py`, concrete implementations:
- `llm.py` — OpenAI-compatible LLM (any provider with OpenAI API format)
- `image.py` — ComfyUI image/audio generation
- `tts_mimo.py` — MiMo TTS (Xiaomi cloud)
- `tts_qwen.py` — Qwen3 TTS (local GPU)

**Generators** (`generators/`): Asset pipelines that read manifests and call providers:
- `characters.py`, `backgrounds.py`, `bgm.py`, `se.py`, `voice.py`, `ui.py` — produce files in `assets/`
- `dialogue.py` — extracts `.ks` script lines into `story/`

**Skills** (`skills/`): JSON prompt templates with `system_prompt` + `user_prompt` (supports `{{input}}` placeholders). Run via `skill run -n <name>`.

**Web** (`web/`): Flask app for visual manifest editing and generation control.

### Linting
```bash
ruff check akonado/        # lint
ruff format akonado/       # format
```

Ruff config is in `pyproject.toml`: line-length 100, target Python 3.10, rules E/F/W/I.

### Dependencies
`requests`, `Pillow`, `python-dotenv`, `openai`, `flask`. Dev: `pytest`, `ruff`.

## Godot Project (root)

Open `project.godot` in Godot 4.6+ to run the visual novel. The `addons/konado/` folder is the upstream Konado framework (not akonado code) — do not modify it directly.

Key Konado concepts:
- `.ks` scripts (in `story/`) use a line-oriented DSL: `"character" "text"` for dialogue, `actor show`, `background switch`, `play bgm` for game commands
- `KND_DialogueManager` is the runtime orchestrator
- `KonadoScriptsInterpreter` parses `.ks` into `KND_Shot` node graphs

### GDScript Style (for any Godot-side changes)
- Tabs for indentation, LF line endings, UTF-8
- File names: `snake_case.gd`, classes: `PascalCase`, functions/vars: `snake_case`
- Constants: `CONSTANT_CASE`, signals: past tense `snake_case`

## Commit Convention

Conventional Commits: `<type>(<scope>): <subject>`

Types: `feat`, `fix`, `docs`, `test`, `ci`. Examples:
- `feat(generators): Add character sprite generation`
- `fix(tts): Handle empty text in voice synthesis`
- `docs(readme): Update quick start guide`
