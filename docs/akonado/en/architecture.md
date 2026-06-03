# Architecture

## Pipeline Flow

Akonado uses a ten-step pipeline to generate complete visual novel assets from a one-sentence premise:

```
One-sentence premise
    |
    v
+-----------------------------------------------------+
|  Step 1: LLM -> script.json                         |
|    generate_script skill                            |
|    Output: chapters, scenes, characters,            |
|            backgrounds, CGs, BGM, SE definitions    |
+-----------------------------------------------------+
    |
    v
+-----------------------------------------------------+
|  Step 2-7: LLM -> Manifests                         |
|    characters.json / backgrounds.json               |
|    cgs.json / bgm.json + se.json                    |
|    voice_config.json / ui.json                      |
+-----------------------------------------------------+
    |
    v
+-----------------------------------------------------+
|  Step 8: Providers -> Visual/Audio assets            |
|    ComfyUI -> character sprites, backgrounds,       |
|               CG illustrations, BGM, SFX, UI        |
|    Output to assets/ directory                      |
+-----------------------------------------------------+
    |
    v
+-----------------------------------------------------+
|  Step 9a: LLM -> .ks scripts                        |
|    generate_scene_script skill                      |
|    Output to story/ directory                       |
+-----------------------------------------------------+
|  Step 9b: TTS -> Voice files                        |
|    Extract lines from .ks -> synthesize ->          |
|    inject voice labels                              |
|    Output to assets/audio/voice/                    |
+-----------------------------------------------------+
    |
    v
+-----------------------------------------------------+
|  Godot + Konado -> Run visual novel                 |
+-----------------------------------------------------+
```

### Execution Order

Voice generation (Step 9b) MUST run after .ks script generation (Step 9a), because the voice pipeline extracts dialogue lines from the .ks scripts.

## Core Modules

### config.py -- Global Configuration

All configuration is loaded from `.env` via python-dotenv. Defines:
- Path constants (assets, manifests, skills, comfyui directories)
- Provider credentials (LLM, ComfyUI, TTS)
- Web GUI settings

### providers/ -- Backend Abstraction Layer

All providers implement abstract interfaces from `base.py`:

| Abstract Base Class | Responsibility | Implementation |
|--------------------|----------------|----------------|
| `LLMProvider` | Text generation | `OpenAICompatibleLLM` |
| `ImageProvider` | Image/audio generation + background removal | `ComfyUIClient` |
| `TTSProvider` | Voice synthesis | `MiMoTTS`, `QwenTTS` |

### generators/ -- Asset Generators

Each generator reads a manifest JSON and calls providers to produce output files:

| Generator | Input Manifest | Output |
|-----------|---------------|--------|
| `characters.py` | characters.json | `assets/characters/<id>/<expr>.png` (transparent background) |
| `backgrounds.py` | backgrounds.json | `assets/backgrounds/<id>.png` |
| `cg.py` | cgs.json | `assets/cgs/<id>.png` (CG illustration, 1920x1080) |
| `bgm.py` | bgm.json | `assets/audio/bgm/<id>.mp3` |
| `se.py` | se.json | `assets/audio/se/<id>.mp3` |
| `voice.py` | .ks scripts + voice_config.json | `assets/audio/voice/<hash>.wav` |
| `ui.py` | ui.json | `ui/<filename>.png` |
| `dialogue.py` | .ks scripts | `manifests/dialogue.json` |

### skills/ -- LLM Skill System

JSON prompt templates with `system_prompt` + `user_prompt_template` (supports `{placeholder}` variables). Run via `skill run` command or Web GUI.

### comfyui/ -- Workflow Templates

ComfyUI workflow JSON files, auto-classified by filename prefix:
- `image_*.json` -> Image generation
- `audio_*.json` -> Audio generation
- `*_remove_background.json` -> Background removal

### web/ -- Flask Web GUI

Browser-based visual management: view/edit manifests, run skills, trigger generation, view statistics.

## Directory Structure

```
akonado/                        # Project root (Godot project)
+-- addons/konado/              # Konado plugin (upstream visual novel framework)
+-- assets/                     # Game assets (AI-generated)
|   +-- characters/             #   Character sprites (PNG, transparent background)
|   |   +-- <character_id>/     #     One subdirectory per character
|   |       +-- normal.png
|   |       +-- happy.png
|   |       +-- ...
|   +-- backgrounds/            #   Background images (PNG, 1920x1080)
|   +-- cgs/                    #   CG illustrations (PNG, 1920x1080, characters+background combined)
|   +-- audio/
|       +-- bgm/                #   Background music (MP3)
|       +-- se/                 #   Sound effects (MP3)
|       +-- voice/              #   Voice files (WAV, content-hash named)
+-- story/                      # Konado .ks scripts
|   +-- chapter01/
|       +-- chapter01_01.ks
+-- ui/                         # UI assets
+-- docs/
|   +-- konado/                 #   Konado framework docs (upstream)
|   +-- akonado/                #   Akonado AI pipeline docs
|       +-- en/                 #     English documentation
+-- akonado/                    # AI asset generation pipeline (Python package)
|   +-- config.py               #     Global configuration
|   +-- cli.py                  #     CLI entry point
|   +-- providers/              #     Backend abstraction layer
|   |   +-- base.py             #       Abstract base classes
|   |   +-- llm.py              #       OpenAI-compatible LLM
|   |   +-- comfyui.py          #       ComfyUI image/audio
|   |   +-- tts_mimo.py         #       MiMo TTS (cloud)
|   |   +-- tts_qwen.py         #       Qwen3 TTS (local)
|   +-- generators/             #     Asset generators
|   |   +-- characters.py       #       Character sprites
|   |   +-- backgrounds.py      #       Background images
|   |   +-- cg.py               #       CG illustrations
|   |   +-- bgm.py              #       Background music
|   |   +-- se.py               #       Sound effects
|   |   +-- voice.py            #       Voice synthesis
|   |   +-- ui.py               #       UI assets
|   |   +-- dialogue.py         #       Dialogue extraction
|   |   +-- godot_resources.py  #       .tres resource files
|   +-- skills/                 #     LLM prompt templates (JSON)
|   +-- manifests/              #     Asset manifest definitions (JSON)
|   +-- comfyui/                #     ComfyUI workflow templates
|   +-- web/                    #     Flask Web GUI
+-- scripts/                    # Platform convenience scripts
|   +-- Windows/                #   .cmd scripts
|   +-- Linux/                  #   .sh scripts
|   +-- macOS/                  #   .sh scripts
+-- tests/                      # Unit tests
```

## Design Principles

1. **Backend Abstraction** -- Provider interfaces are unified; switching backends requires no generator code changes
2. **JSON-Driven** -- All data flows through JSON manifests, easy to edit and version control
3. **Skill-Driven** -- LLM prompts are template-based, reusable and composable
4. **Incremental Generation** -- Skips existing files by default; use `--force` to regenerate
5. **Decoupling** -- Python pipeline and Godot project are independent, connected only through `assets/` and `story/`
