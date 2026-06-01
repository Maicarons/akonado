# Providers

Providers are the backend implementations that perform actual generation work. All providers implement abstract interfaces from `providers/base.py`; generator code doesn't need to know about specific backends.

## Abstract Base Classes

### LLMProvider -- Text Generation

```python
class LLMProvider(ABC):
    def available(self) -> bool: ...
    def generate(self, system: str, user: str, *, temperature: float = 0.7) -> str: ...
```

### ImageProvider -- Image/Audio Generation

```python
class ImageProvider(ABC):
    def available(self) -> bool: ...
    def generate(self, prompt, width, height, save_path, *, seed=None) -> None: ...
    def remove_background(self, input_path, output_path) -> None: ...
    def generate_audio(self, prompt, duration, save_path, *, category="Music") -> None: ...
```

### TTSProvider -- Voice Synthesis

```python
class TTSProvider(ABC):
    def available(self) -> bool: ...
    def synthesize(self, text: str, character: str, save_path: Path) -> bool: ...
```

## Built-in Providers

### OpenAICompatibleLLM

Compatible with all OpenAI-format APIs (OpenAI, MiMo, DeepSeek, etc.).

Environment variables: `LLM_API_KEY`, `LLM_BASE_URL`, `LLM_MODEL`

```python
from akonado.providers import OpenAICompatibleLLM

llm = OpenAICompatibleLLM()
if llm.available():
    result = llm.generate("You are a screenwriter", "Write a story about a cat")
```

### ComfyUIClient (ComfyUIImageProvider)

Wraps the ComfyUI REST API for image and audio generation. Supports workflow auto-discovery and parameter injection.

Environment variable: `COMFYUI_URL`

```python
from akonado.providers import ComfyUIClient

client = ComfyUIClient()
workflows = client.list_workflows()
# ['audio:stable_audio_3', 'image:ernie_image_turbo', 'utility:remove_bg', ...]

# Generate image
client.generate(prompt="a cute cat", width=1024, height=1024, save_path=Path("cat.png"))

# Generate audio
client.generate_audio(prompt="gentle piano", duration=150, save_path=Path("bgm.mp3"))

# Background removal
client.remove_background(Path("raw.png"), Path("transparent.png"))
```

#### Workflow Auto-Discovery

Place workflow JSON files in the `akonado/comfyui/` directory. They are auto-classified by filename prefix:

| Prefix | Category | Purpose |
|--------|----------|---------|
| `image_*.json` | Image generation | Character sprites, backgrounds, UI |
| `audio_*.json` | Audio generation | BGM, sound effects |
| `*_remove_background.json` | Background removal | Character sprite transparency |
| Other | Auto-detected by output node | -- |

View discovered workflows:

```bash
python -m akonado workflows
```

#### Parameter Injection

Workflow nodes are identified by their title (`_meta.title`) for parameter injection:

| Node Title Keyword | Injected Parameter |
|-------------------|-------------------|
| prompt | User input prompt |
| width / height | Image dimensions |
| seed | Random seed |
| duration / audio / length | Audio duration |

Placeholder replacement is also supported (in node values):

| Placeholder | Mapped Parameter |
|-------------|-----------------|
| `{prompt}` / `{{prompt}}` / `USER_INPUT` | prompt |
| `{width}` / `{{width}}` | width |
| `{height}` / `{{height}}` | height |
| `{seed}` / `{{seed}}` | seed |
| `{duration}` / `{{duration}}` / `AUDIO_LENGTH` | duration |

#### Seed Randomization

KSampler node seeds are automatically randomized to ensure different results each time. To fix a seed:

```python
client.generate(prompt="cat", width=1024, height=1024, save_path=Path("cat.png"), seed=42)
```

### MiMoTTS

Cloud TTS based on the Xiaomi MiMo API (OpenAI-compatible format).

Environment variables: `MIMO_API_KEY`, `MIMO_BASE_URL`, `MIMO_TTS_MODEL`

See [TTS Setup Guide](tts-setup.md) for details.

### QwenTTS

Local GPU inference based on the Qwen3-TTS CustomVoice model.

Environment variables: `QWEN_TTS_MODEL_PATH`, `QWEN_TTS_DEVICE`, `QWEN_TTS_DTYPE`

See [TTS Setup Guide](tts-setup.md) for details.

## Adding a Custom Provider

Inherit the corresponding abstract base class:

```python
from akonado.providers.base import LLMProvider

class MyProvider(LLMProvider):
    def available(self) -> bool:
        return True

    def generate(self, system: str, user: str, *, temperature: float = 0.7) -> str:
        return "generated text"
```

Then export it in `providers/__init__.py` so generators can use it.
