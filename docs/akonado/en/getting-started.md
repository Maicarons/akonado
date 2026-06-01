# Getting Started

## Requirements

| Dependency | Purpose | Required |
|-----------|---------|----------|
| Python 3.10+ | Run the Akonado pipeline | Yes |
| ComfyUI | Image/audio generation | Yes ([setup guide](comfyui-setup.md)) |
| TTS engine | Voice synthesis | Yes (pick one, [setup guide](tts-setup.md)) |
| Godot 4.6+ | Run the visual novel | Runtime only |

## Installation

```bash
cd akonado
pip install -e .
```

## Configuration

```bash
cp .env.example .env
```

Edit `akonado/.env` with your API keys:

```env
# LLM (required for script generation)
LLM_API_KEY=your-api-key
LLM_BASE_URL=https://api.xiaomimimo.com/v1
LLM_MODEL=mimo-v2.5-pro

# MiMo TTS (for voice generation, pick one of MiMo/Qwen)
MIMO_API_KEY=your-api-key
MIMO_BASE_URL=https://api.xiaomimimo.com/v1
MIMO_TTS_MODEL=mimo-v2.5-tts

# ComfyUI (image/audio generation)
COMFYUI_URL=http://127.0.0.1:8188

# Godot engine directory (optional)
GODOT_DIR=G:\SteamLibrary\steamapps\common\Godot Engine
```

## Verify Installation

```bash
python -m akonado check
```

Expected output:
```
ComfyUI (Image/Audio): OK
LLM (OpenAI-compatible): OK
MiMo TTS: OK
Qwen TTS: NOT AVAILABLE

ComfyUI workflows (5):
  - audio:stable_audio_3
  - image:ernie_image_turbo
  - image:logo_workflow
  - image:title_bg_workflow
  - utility:remove_bg
```

## One-Click Generation (Recommended)

Generate complete visual novel assets from a one-sentence premise:

```bash
python -m akonado pipeline "a story about a tea shop owner facing tradition vs modernity"
```

### Pipeline Execution Flow

1. **Generate script** -> `akonado/manifests/script.json` (chapters, scenes, characters, backgrounds, audio definitions)
2. **Generate character prompts** -> `akonado/manifests/characters.json`
3. **Generate background prompts** -> `akonado/manifests/backgrounds.json`
4. **Generate audio prompts** -> `akonado/manifests/bgm.json` + `se.json`
5. **Generate voice config** -> `akonado/manifests/voice_config.json`
6. **Generate visual/audio assets** -> `assets/` directory (character sprites, backgrounds, BGM, SFX, UI)
7. **Generate .ks scripts** -> `story/` directory
8. **Generate voice acting** -> `assets/audio/voice/` directory

### Custom Parameters

```bash
# Specify number of chapters and scenes per chapter
python -m akonado pipeline "sci-fi adventure" --chapters 5 --scenes-per-chapter 4

# Use Qwen TTS engine (local GPU)
python -m akonado pipeline "story premise" --engine qwen

# Specify Godot engine directory
python -m akonado pipeline "story premise" --godot-dir "C:\path\to\Godot"

# Force regeneration (don't skip existing files)
python -m akonado pipeline "story premise" --force

# Adjust LLM temperature (0.0-1.0, higher = more creative)
python -m akonado pipeline "story premise" --temperature 0.8
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--chapters` | Number of chapters | 4 |
| `--scenes-per-chapter` | Scenes per chapter | 3 |
| `--engine` | TTS engine (mimo/qwen) | mimo |
| `--godot-dir` | Godot engine directory | System default |
| `--force` | Force regeneration | false |
| `--temperature` | LLM temperature | 0.7 |

## Step-by-Step Generation

For more fine-grained control, execute steps individually:

```bash
# 1. Generate script
python -m akonado skill run -n generate_script -i "story premise" -o akonado/manifests/script.json

# 2. Generate assets
python -m akonado generate characters    # character sprites
python -m akonado generate backgrounds   # background images
python -m akonado generate bgm           # background music
python -m akonado generate se            # sound effects
python -m akonado generate ui            # UI assets

# 3. Generate .ks scripts (requires script.json)
python -m akonado skill run -n generate_scene_script -i "scene summary" -o story/chapter01/scene01.ks

# 4. Generate voice acting (requires .ks scripts)
python -m akonado generate voice

# 5. Or generate everything at once
python -m akonado generate all
```

## Running in Godot

1. Open `project.godot` in the project root with Godot 4.6+
2. Run the project to experience the generated visual novel

Generated `.ks` scripts are located in the `story/` directory, using the Konado framework DSL format.

## Web GUI

Launch the visual editing interface:

```bash
python -m akonado web
```

Open http://127.0.0.1:5000 in your browser. See [Web GUI docs](web-gui.md) for details.

## Cleaning Generated Files

```bash
# Clean a single type
python -m akonado clean characters

# Clean all generated assets
python -m akonado clean all

# Deep clean: assets + manifests + .ks scripts
python -m akonado clean all --deep
```

## Convenience Scripts

Platform-specific wrappers are in the `scripts/` directory:

```bash
# Windows
scripts\Windows\pipeline.cmd "story premise"   # full pipeline
scripts\Windows\generate.cmd                    # generate all assets
scripts\Windows\web.cmd                         # launch Web GUI
scripts\Windows\godot.cmd                       # open Godot editor

# Linux / macOS
scripts/Linux/pipeline.sh "story premise"
scripts/macOS/pipeline.sh "story premise"
```

## Troubleshooting

### ComfyUI Connection Failed

Ensure ComfyUI is running: `python -m akonado check`. See [ComfyUI setup guide](comfyui-setup.md).

### Voice Generation Failed

Check TTS API key configuration: `python -m akonado check`. See [TTS setup guide](tts-setup.md).

### Image Generation Failed

Check if ComfyUI workflow files are in the `akonado/comfyui/` directory: `python -m akonado workflows`.

### Encoding Error

If you encounter `UnicodeDecodeError`, ensure your system locale supports UTF-8.
