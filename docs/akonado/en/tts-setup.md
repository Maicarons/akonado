# TTS Setup Guide

Akonado supports two TTS engines for voice acting. Choose one based on your environment.

## Comparison

| Feature | MiMo TTS (Cloud) | Qwen TTS (Local) |
|---------|------------------|-------------------|
| GPU Required | No | Yes (8GB+ VRAM recommended) |
| Network | Online only | Offline capable |
| Cost | Per API call | Free |
| Latency | Network-dependent | Slow first load, fast after |
| Quality | Excellent | Excellent |

## Option A: MiMo TTS (Cloud, Recommended)

Xiaomi MiMo V2.5 TTS, called via OpenAI-compatible API. No local GPU needed.

### 1. Get API Key

Register at [Xiaomi MiMo Platform](https://mimo.xiaomi.com/) to get an API Key.

### 2. Configure Environment

In `akonado/.env`:

```env
MIMO_API_KEY=your-api-key-here
MIMO_BASE_URL=https://api.xiaomimimo.com/v1
MIMO_TTS_MODEL=mimo-v2.5-tts
```

### 3. Verify

```bash
python -m akonado check
```

Output should include `MiMo TTS: OK`.

### 4. Usage

```bash
# Pipeline uses MiMo TTS by default
python -m akonado pipeline "story premise"

# Or generate voice separately
python -m akonado generate voice
```

## Option B: Qwen3 TTS (Local GPU)

Local inference based on the Qwen3-TTS CustomVoice model, supporting custom speaker voice timbre.

### 1. Requirements

- NVIDIA GPU, 8GB+ VRAM recommended
- CUDA 11.8+ and cuDNN
- Python 3.10+

### 2. Install qwen_tts Package

```bash
# Option A: Install from PyPI
pip install qwen-tts

# Option B: Install from source
git clone https://github.com/QwenLM/Qwen3-TTS.git
cd Qwen3-TTS
pip install -e .
```

### 3. Download Model

Download the Qwen3-TTS CustomVoice model from [HuggingFace](https://huggingface.co/Qwen/Qwen3-TTS) to a local directory.

### 4. Configure Environment

In `akonado/.env`:

```env
QWEN_TTS_MODEL_PATH=/path/to/Qwen3-TTS-CustomVoice
QWEN_TTS_DEVICE=cuda:0
QWEN_TTS_DTYPE=bfloat16
```

| Parameter | Description |
|-----------|-------------|
| `QWEN_TTS_MODEL_PATH` | Absolute path to the model directory |
| `QWEN_TTS_DEVICE` | Device, e.g. `cuda:0`, `cuda:1`, `cpu` |
| `QWEN_TTS_DTYPE` | Precision: `bfloat16` (recommended), `float16`, `float32` |

### 5. Install Audio Dependencies

```bash
pip install soundfile
```

### 6. Verify

```bash
python -m akonado check
```

Output should include `Qwen TTS: OK`.

### 7. Usage

```bash
# Use Qwen engine in pipeline
python -m akonado pipeline "story premise" --engine qwen

# Or generate separately
python -m akonado generate voice --engine qwen
```

## Voice Configuration (voice_config.json)

Both TTS engines are configured through `akonado/manifests/voice_config.json`. The pipeline auto-generates this file; you can also edit it manually.

### MiMo Preset Voices (Chinese)

MiMo TTS Chinese **must** use these preset voice names. Do **not** use English voices (Dean, Mia, etc.) — they are English-only and produce garbled Chinese speech.

| Voice Name | Gender | Description |
|------------|--------|-------------|
| `冰糖` (Bingtang) | Female | Bright, positive, natural |
| `茉莉` (Moli) | Female | Gentle, intellectual |
| `苏打` (Suda) | Male | Standard Mandarin, warm |
| `白桦` (Baihua) | Male | Deep, calm, magnetic |

### Qwen Common Chinese Voices

| Parameter | Chinese Name | Gender | Description |
|-----------|-------------|--------|-------------|
| `Ethan` | 晨煦 | Male | Warm, standard Mandarin |
| `Cherry` | 芊悦 | Female | Bright, friendly |
| `Serena` | 苏瑶 | Female | Gentle |
| `Eldric Sage` | 沧明子 | Male | Wise elder |
| `Vincent` | 田叔 | Male | Husky voice |
| `Kai` | 凯 | Male | Calm |
| `Moon` | 月白 | Male | Dashing |
| `Maia` | 四月 | Female | Intellectual, gentle |
| `Ryan` | 甜茶 | Male | Dramatic |
| `Chelsie` | 千雪 | Female | Anime-style |
| `Nofish` | 不吃鱼 | Male | Designer accent |

### Configuration Structure

```json
{
  "characters": {
    "chenmo": {
      "profile": "28-year-old male photographer, quiet and introverted,细腻 sensitive.",
      "instruct_mimo": "Character: 28-year-old male photographer, quiet. Slow pace, calm tone with subtle detachment.",
      "instruct_qwen": "Speak in a calm, slightly distant but internally warm tone.",
      "voices": {
        "mimo": "白桦",
        "qwen": "Ethan"
      },
      "gender": "male"
    },
    "linwan": {
      "profile": "27-year-old female architect, outwardly capable, inwardly gentle.",
      "instruct_mimo": "Character: 27-year-old female architect, professional and capable, gentle when expressing emotions.",
      "instruct_qwen": "Speak in a clear, professional tone; soften when expressing emotions.",
      "voices": {
        "mimo": "冰糖",
        "qwen": "Cherry"
      },
      "gender": "female"
    }
  },
  "emotion_rules": [
    {"label": "happy", "keywords": ["haha", "great", "happy"]},
    {"label": "sad", "keywords": ["sorry", "sad", "tears"]}
  ],
  "emotion_directions": {
    "neutral": "Say this line in a natural, calm tone.",
    "happy": "Say this line in a cheerful, light tone.",
    "sad": "Say this line in a low, slightly choked tone."
  }
}
```

### Field Reference

| Field | Description |
|-------|-------------|
| `profile` | Character voice description, used for TTS emotion control |
| `voices.mimo` | MiMo TTS voice name (must be Chinese preset: 冰糖/茉莉/苏打/白桦) |
| `voices.qwen` | Qwen TTS speaker parameter name (e.g. Ethan, Cherry) |
| `instruct_mimo` | MiMo TTS style instruction (natural language describing speaking style, emotion, pace) |
| `instruct_qwen` | Qwen TTS tone guidance |
| `emotion_rules` | Auto-detect line emotion from keywords |
| `emotion_directions` | Tone guidance for each emotion |

## Troubleshooting

### MiMo TTS: "API key not configured"

Check that `MIMO_API_KEY` is correctly set in `akonado/.env`.

### Qwen TTS: "model not found"

Check that `QWEN_TTS_MODEL_PATH` exists and contains model files (`config.json`, `*.safetensors`, etc.).

### Qwen TTS: "CUDA out of memory"

- Try `QWEN_TTS_DTYPE=float16` to reduce VRAM usage
- Or use `QWEN_TTS_DEVICE=cpu` (will be slow)
- Close other programs consuming VRAM

### Qwen TTS: "No module named 'qwen_tts'"

Ensure qwen_tts is properly installed:
```bash
pip install qwen-tts
# Or from source
pip install -e /path/to/Qwen3-TTS
```

### Where are the voice files?

Generated voice files are saved in `assets/audio/voice/`, named with content hashes (`md5(character + text)[:8].wav`) to avoid regenerating identical lines.

### How to preview?

Open the `.wav` files directly with any audio player. If unsatisfied:
1. Modify `profile` or `instruct_qwen` in `voice_config.json` to adjust voice timbre
2. Adjust tone descriptions in `emotion_directions`
3. Delete the corresponding `.wav` files and regenerate: `python -m akonado generate voice --force`
