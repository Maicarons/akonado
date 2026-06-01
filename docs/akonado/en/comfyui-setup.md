# ComfyUI Setup Guide

Akonado uses ComfyUI as the image and audio generation backend. This guide covers installation, configuration, and required models.

## 1. Install ComfyUI

### Option A: Official Portable Package (Recommended)

1. Visit [ComfyUI Releases](https://github.com/comfyanonymous/ComfyUI/releases)
2. Download the latest `ComfyUI_windows_portable.zip`
3. Extract to any directory and run `run_nvidia_gpu.bat` (NVIDIA) or `run_cpu.bat` (no GPU)

### Option B: Manual Installation

```bash
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI
pip install -r requirements.txt
python main.py
```

### Verify

After starting, visit http://127.0.0.1:8188 . If you see the ComfyUI interface, installation is successful.

## 2. Install Custom Nodes

Akonado workflows depend on these custom nodes:

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

## 3. Download Models

### Image Generation (Required)

| Model | Download | Placement Path |
|-------|----------|----------------|
| ernie-image-turbo | [HuggingFace](https://huggingface.co/baidu/ERNIE-Image-Turbo) | `ComfyUI/models/unet/` |
| ministral-3-3b | [HuggingFace](https://huggingface.co/Comfy-Org/ministral-3b-3b-instruct) | `ComfyUI/models/clip/` |
| flux2-vae | [HuggingFace](https://huggingface.co/black-forest-labs/FLUX.2-schnell) | `ComfyUI/models/vae/` |
| ernie-image-prompt-enhancer | [HuggingFace](https://huggingface.co/baidu/ERNIE-Image) | `ComfyUI/models/clip/` |

### Audio Generation (Required)

| Model | Download | Placement Path |
|-------|----------|----------------|
| stable_audio_3_small_music | [HuggingFace](https://huggingface.co/stabilityai/stable-audio-open-small) | `ComfyUI/models/checkpoints/` |
| qwen3.5_2b_bf16 | [HuggingFace](https://huggingface.co/Qwen/Qwen3.5-2B) | `ComfyUI/models/clip/` |
| t5gemma_b_b_ul2 | [HuggingFace](https://huggingface.co/google/t5gemma-b-b-ul2) | `ComfyUI/models/clip/` |

### Background Removal (Required)

| Model | Download | Placement Path |
|-------|----------|----------------|
| birefnet | [HuggingFace](https://huggingface.co/ZhengPeng7/BiRefNet) | `ComfyUI/models/birefnet/` |

### Directory Structure Example

```
ComfyUI/
+-- models/
|   +-- unet/
|   |   +-- ernie-image-turbo.safetensors
|   +-- clip/
|   |   +-- ministral-3-3b.safetensors
|   |   +-- ernie-image-prompt-enhancer.safetensors
|   |   +-- qwen3.5_2b_bf16.safetensors
|   |   +-- t5gemma_b_b_ul2.safetensors
|   +-- vae/
|   |   +-- flux2-vae.safetensors
|   +-- checkpoints/
|   |   +-- stable_audio_3_small_music.safetensors
|   +-- birefnet/
|       +-- birefnet.safetensors
+-- custom_nodes/
    +-- ComfyUI-KJNodes/
    +-- ComfyUI-BiRefNet/
    +-- ComfyUI-StableAudioSuite/
```

## 4. Place Akonado Workflows

Akonado ships with workflow JSON files in the `akonado/comfyui/` directory:

```
akonado/comfyui/
+-- image_ernie_image_turbo.json              # Character/background generation
+-- audio_stable_audio_3.json                 # BGM/SFX generation
+-- utility_birefnet_remove_background.json   # Character background removal
+-- logo_workflow.json                        # Logo generation
+-- title_bg_workflow.json                    # Title background generation
```

These workflows are automatically discovered by the ComfyUI provider -- no manual import needed.

## 5. Configure Akonado

Set the ComfyUI address in `akonado/.env`:

```env
COMFYUI_URL=http://127.0.0.1:8188
```

Change this address if ComfyUI runs on a different machine or port.

## 6. Verify Connection

```bash
python -m akonado check
```

Expected output:

```
ComfyUI (Image/Audio): OK

ComfyUI workflows (5):
  - audio:stable_audio_3
  - image:ernie_image_turbo
  - image:logo_workflow
  - image:title_bg_workflow
  - utility:remove_bg
```

## 7. Custom Workflows

You can add your own workflow JSON files to `akonado/comfyui/`. Akonado auto-classifies them by filename prefix:

- `image_*.json` -> Image generation (characters, backgrounds, UI)
- `audio_*.json` -> Audio generation (BGM, SFX)
- `*_remove_background.json` -> Background removal

### Parameter Injection Convention

Workflow nodes are identified by their title (`_meta.title`) for parameter injection:

| Node Title Keyword | Injected Parameter |
|-------------------|-------------------|
| prompt | User input prompt |
| width / height | Image dimensions |
| seed | Random seed (auto-randomized if not set) |
| duration / audio / length | Audio duration |

If the node title doesn't contain keywords, it falls back to placeholder replacement (`{prompt}`, `USER_INPUT`, etc.).

## Troubleshooting

### ComfyUI reports missing models on startup

Check that model filenames match exactly (case-sensitive, including extension) with the names in the workflow JSON files.

### Image generation is slow

ernie-image-turbo requires significant VRAM (8GB+ recommended). If VRAM is limited:
- Reduce generation resolution (default 1024x1024)
- Avoid unnecessary regeneration with `--force`

### Background removal fails

Ensure `ComfyUI-BiRefNet` custom node is properly installed and `birefnet.safetensors` is in the correct path.

### Audio generation fails

Ensure `ComfyUI-StableAudioSuite` custom node is installed. The stable-audio model requires significant VRAM.
