# Environment Setup Guide

This guide walks you through setting up the complete Akonado environment from scratch, including the Python pipeline, LLM API, ComfyUI image generation, TTS voice synthesis, and Godot runtime.

## Overview

Akonado consists of the following components. You need all of them to run the full pipeline:

| Component | Purpose | Required |
|-----------|---------|----------|
| Python 3.10+ | Run the Akonado pipeline | Yes |
| LLM API | Script, character, and scene generation | Yes |
| ComfyUI | Character sprites, backgrounds, BGM, SFX | Yes |
| TTS engine | Character voice synthesis | Yes (MiMo or Qwen, pick one) |
| Godot 4.7+ | Run the generated visual novel | Runtime only |

### Hardware Requirements

| Spec | Minimum | Recommended |
|------|---------|-------------|
| CPU | Any 64-bit processor | 8+ cores |
| RAM | 8GB | 16GB+ |
| GPU | None (ComfyUI CPU mode is very slow) | NVIDIA GPU with 8GB+ VRAM |
| Disk | 20GB free space | 50GB+ (model files are large) |
| Network | Required for model downloads and cloud APIs | Stable broadband |

> If you don't have an NVIDIA GPU, ComfyUI can run in CPU mode (very slow), and you can use MiMo TTS cloud API (no GPU needed).

---

## Step 1: Set Up Python Environment

### 1.1 Install Python

Akonado requires Python 3.10 or higher (supports 3.10 ~ 3.13).

**Windows:**

Download the installer from [python.org](https://www.python.org/downloads/). Check **"Add Python to PATH"** during installation.

Verify:
```bash
python --version
# Should output Python 3.10.x or higher
```

**Linux / macOS:**
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install python3 python3-pip python3-venv

# macOS (Homebrew)
brew install python@3.12
```

### 1.2 Create a Virtual Environment (Recommended)

```bash
cd akonado
python -m venv .venv

# Windows activate
.venv\Scripts\activate

# Linux / macOS activate
source .venv/bin/activate
```

After activation, your terminal prompt will show `(.venv)`. You need to reactivate the virtual environment each time you open a new terminal.

### 1.3 Install Akonado

```bash
pip install -e .
```

This installs Akonado and all Python dependencies:
- `requests` — HTTP requests
- `Pillow` — Image processing
- `python-dotenv` — Environment variable management
- `openai` — LLM API client
- `flask` — Web GUI

Verify:
```bash
python -m akonado --help
```

Should display the command help.

---

## Step 2: Configure API Keys

### 2.1 Create Configuration File

```bash
cp akonado/.env.example akonado/.env
```

Open `akonado/.env` in a text editor and fill in the configuration below.

### 2.2 LLM API (Required)

Akonado uses LLM to generate scripts, character definitions, scene scripts, and other text content. Supports all OpenAI-compatible APIs.

**Using Xiaomi MiMo (recommended for China):**

1. Register at [Xiaomi MiMo Platform](https://mimo.xiaomi.com/)
2. Create an application and get your API Key
3. Fill in `.env`:

```env
LLM_API_KEY=your-mimo-api-key
LLM_BASE_URL=https://api.xiaomimimo.com/v1
LLM_MODEL=mimo-v2.5-pro
```

**Using OpenAI:**

```env
LLM_API_KEY=sk-your-openai-key
LLM_BASE_URL=https://api.openai.com/v1
LLM_MODEL=gpt-4o
```

**Using other compatible APIs (DeepSeek, SiliconFlow, etc.):**

```env
LLM_API_KEY=your-key
LLM_BASE_URL=https://api.siliconflow.cn/v1
LLM_MODEL=deepseek-ai/DeepSeek-V3
```

Any API compatible with the OpenAI format will work.

---

## Step 3: Set Up ComfyUI (Image/Audio Generation)

ComfyUI is the image and audio generation backend for Akonado, used for character sprites, backgrounds, BGM, and sound effects.

### 3.1 Install ComfyUI

**Option A: Official Portable Package (Recommended)**

1. Visit [ComfyUI Releases](https://github.com/comfyanonymous/ComfyUI/releases)
2. Download the latest `ComfyUI_windows_portable.zip`
3. Extract to any directory (avoid paths with Chinese characters or spaces)
4. Run `run_nvidia_gpu.bat` (NVIDIA GPU) or `run_cpu.bat` (no GPU)

**Option B: Manual Installation**

```bash
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI
pip install -r requirements.txt
python main.py
```

After startup, visit http://127.0.0.1:8188. If you see the ComfyUI interface, installation is successful.

### 3.2 Install Custom Nodes

Akonado's workflows depend on these custom nodes:

```bash
cd ComfyUI/custom_nodes

# ComfyUI-KJNodes (PrimitiveStringMultiline and other nodes)
git clone https://github.com/kijai/ComfyUI-KJNodes.git

# ComfyUI-BiRefNet (background removal)
git clone https://github.com/ltdrdata/ComfyUI-BiRefNet.git

# ComfyUI-StableAudioSuite (audio generation)
git clone https://github.com/b-fission/ComfyUI-StableAudioSuite.git
```

Restart ComfyUI after installation.

### 3.3 Download Models

Download the following models to the corresponding ComfyUI directories:

**Image Generation (Required):**

| Model | Download | Place In |
|-------|----------|----------|
| ernie-image-turbo | [HuggingFace](https://huggingface.co/baidu/ERNIE-Image-Turbo) | `ComfyUI/models/unet/` |
| ministral-3-3b | [HuggingFace](https://huggingface.co/Comfy-Org/ministral-3b-3b-instruct) | `ComfyUI/models/clip/` |
| flux2-vae | [HuggingFace](https://huggingface.co/black-forest-labs/FLUX.2-schnell) | `ComfyUI/models/vae/` |
| ernie-image-prompt-enhancer | [HuggingFace](https://huggingface.co/baidu/ERNIE-Image) | `ComfyUI/models/clip/` |

**Audio Generation (Required):**

| Model | Download | Place In |
|-------|----------|----------|
| stable_audio_3_small_music | [HuggingFace](https://huggingface.co/stabilityai/stable-audio-open-small) | `ComfyUI/models/checkpoints/` |
| qwen3.5_2b_bf16 | [HuggingFace](https://huggingface.co/Qwen/Qwen3.5-2B) | `ComfyUI/models/clip/` |
| t5gemma_b_b_ul2 | [HuggingFace](https://huggingface.co/google/t5gemma-b-b-ul2) | `ComfyUI/models/clip/` |

**Background Removal (Required):**

| Model | Download | Place In |
|-------|----------|----------|
| birefnet | [HuggingFace](https://huggingface.co/ZhengPeng7/BiRefNet) | `ComfyUI/models/birefnet/` |

### 3.4 Configure Akonado to Connect to ComfyUI

Confirm the ComfyUI address in `akonado/.env`:

```env
COMFYUI_URL=http://127.0.0.1:8188
```

If ComfyUI runs on a different machine or port, update this address.

### 3.5 Verify

Ensure ComfyUI is running, then execute:

```bash
python -m akonado check
```

Output should include:
```
ComfyUI (Image/Audio): OK

ComfyUI workflows (5):
  - audio:stable_audio_3
  - image:ernie_image_turbo
  - image:logo_workflow
  - image:title_bg_workflow
  - utility:remove_bg
```

> For detailed ComfyUI configuration, see [ComfyUI Setup Guide](comfyui-setup.md).

---

## Step 4: Set Up TTS Voice Engine

Akonado supports two TTS engines. **Pick one:**

| Engine | Features | Best For |
|--------|----------|----------|
| MiMo TTS (Cloud) | No GPU needed, per-API-call billing | No GPU or prefer cloud |
| Qwen TTS (Local) | GPU required, free and offline | NVIDIA GPU with 8GB+ VRAM |

### Option A: MiMo TTS (Recommended, No GPU)

1. Register at [Xiaomi MiMo Platform](https://mimo.xiaomi.com/) and get an API Key
2. Fill in `akonado/.env`:

```env
MIMO_API_KEY=your-mimo-api-key
MIMO_BASE_URL=https://api.xiaomimimo.com/v1
MIMO_TTS_MODEL=mimo-v2.5-tts
```

> MiMo TTS Chinese must use preset voice names (冰糖/茉莉/苏打/白桦). See [TTS Setup Guide](tts-setup.md).

### Option B: Qwen TTS (Local GPU)

1. Ensure you have an NVIDIA GPU (8GB+ VRAM) with CUDA 11.8+
2. Install qwen_tts:

```bash
pip install qwen-tts
```

3. Download the [Qwen3-TTS CustomVoice model](https://huggingface.co/Qwen/Qwen3-TTS) locally
4. Fill in `akonado/.env`:

```env
QWEN_TTS_MODEL_PATH=/path/to/Qwen3-TTS-CustomVoice
QWEN_TTS_DEVICE=cuda:0
QWEN_TTS_DTYPE=bfloat16
```

5. Install audio dependencies:

```bash
pip install soundfile
```

### Verify TTS

```bash
python -m akonado check
```

Output should include `MiMo TTS: OK` or `Qwen TTS: OK`.

> For detailed voice configuration and troubleshooting, see [TTS Setup Guide](tts-setup.md).

---

## Step 5: Install Godot (Runtime)

Godot is the visual novel runtime engine. Akonado's generated `.ks` scripts and assets run in Godot.

### 5.1 Download Godot

Download **Godot 4.7+** standard version from the [Godot website](https://godotengine.org/download) or [Steam](https://store.steampowered.com/app/404790/Godot_Engine/).

### 5.2 Configure Godot Path (Optional)

Set the Godot engine directory in `akonado/.env` for convenience scripts:

```env
GODOT_DIR=C:\path\to\Godot Engine
```

If not set, you can directly open `project.godot` in the project root with Godot.

### 5.3 Open the Project

1. Launch Godot
2. Click "Import" or "Open Project"
3. Select the `project.godot` file in the Akonado project root
4. Click "Run" (F5) to experience the generated visual novel

> Note: `addons/konado/` is the upstream Konado framework. Do not modify it.

---

## Step 6: Verify All Components

```bash
python -m akonado check
```

Full output example:
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

- **ComfyUI: OK** — Image/audio generation available
- **LLM: OK** — Script generation available
- **MiMo TTS: OK** or **Qwen TTS: OK** — Voice synthesis available (at least one)

If a component shows `NOT AVAILABLE`, check the corresponding API key and network connection.

---

## Step 7: Run Your First Project

### 7.1 One-Click Generation (Recommended)

```bash
python -m akonado pipeline "a story about a tea shop owner facing tradition vs modernity"
```

This automatically executes the full 7-step pipeline:

1. **Generate script** → `akonado/manifests/script.json`
2. **Generate character prompts** → `akonado/manifests/characters.json`
3. **Generate background prompts** → `akonado/manifests/backgrounds.json`
4. **Generate audio prompts** → `akonado/manifests/bgm.json` + `se.json`
5. **Generate voice config** → `akonado/manifests/voice_config.json`
6. **Generate visual/audio assets** → `assets/` directory
7. **Generate .ks scripts + voice** → `story/` + `assets/audio/voice/`

### 7.2 Custom Parameters

```bash
# Specify chapters and scenes per chapter
python -m akonado pipeline "sci-fi adventure" --chapters 5 --scenes-per-chapter 4

# Use Qwen TTS engine (local GPU)
python -m akonado pipeline "story premise" --engine qwen

# Adjust LLM temperature (0.0-1.0, higher = more creative)
python -m akonado pipeline "story premise" --temperature 0.8

# Force regeneration (don't skip existing files)
python -m akonado pipeline "story premise" --force
```

### 7.3 Run in Godot

1. Open `project.godot` with Godot
2. Press F5 to run
3. Experience your generated visual novel!

### 7.4 Step-by-Step Generation

For more fine-grained control:

```bash
# 1. Generate script
python -m akonado skill run -n generate_script -i "story premise" -o akonado/manifests/script.json

# 2. Generate assets
python -m akonado generate characters    # character sprites
python -m akonado generate backgrounds   # background images
python -m akonado generate bgm           # background music
python -m akonado generate se            # sound effects
python -m akonado generate ui            # UI assets

# 3. Generate .ks scripts
python -m akonado generate scenes

# 4. Generate voice
python -m akonado generate voice

# Or generate everything at once
python -m akonado generate all
```

---

## Convenience Scripts

Platform-specific wrappers in the `scripts/` directory:

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

---

## Web GUI

Akonado provides a browser-based visual management interface:

```bash
python -m akonado web
```

Open http://127.0.0.1:5000 in your browser. You can:
- View and edit all manifests
- Run individual skills
- Trigger asset generation
- View generation statistics

See [Web GUI docs](web-gui.md) for details.

---

## Troubleshooting

### pip install errors

If you encounter `setuptools` errors, try upgrading pip:
```bash
pip install --upgrade pip setuptools wheel
```

### ComfyUI connection failed

Ensure ComfyUI is running and the address is correct:
```bash
python -m akonado check
```
See [ComfyUI Setup Guide](comfyui-setup.md).

### LLM API errors

- Check that your API Key is correct
- Verify `LLM_BASE_URL` is accessible
- Try testing API connectivity with `curl`

### Voice generation failed

- MiMo TTS: Check `MIMO_API_KEY` configuration
- Qwen TTS: Check model path and GPU VRAM
- See [TTS Setup Guide](tts-setup.md)

### Godot runtime errors

- Ensure you're using Godot 4.7+
- Ensure `addons/konado/` directory is complete
- See [Known Pitfalls](../../CLAUDE.md#known-pitfalls-踩坑记录)

### UnicodeDecodeError

Ensure your system locale supports UTF-8. Windows users can go to "Settings > Time & Language > Region > Administrative language settings > Change system locale" and check "Beta: Use Unicode UTF-8 for worldwide language support".

### Disk space issues

Generated asset files can be large (character sprites, BGM, voice files, etc.). Recommend 50GB+ free space. Use `python -m akonado clean` to remove unneeded files.

---

## Next Steps

- [Architecture](architecture.md) — Understand how the pipeline works internally
- [Skills](skills.md) — Customize LLM prompt templates
- [Manifests](manifests.md) — Learn about manifest formats
- [TTS Setup Guide](tts-setup.md) — Deep-dive into voice configuration
- [ComfyUI Setup Guide](comfyui-setup.md) — Deep-dive into image/audio generation
