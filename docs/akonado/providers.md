# 后端提供者（Providers）

Providers 是实际执行生成工作的后端实现。

## 基类

所有 provider 实现 `providers/base.py` 中的抽象接口：

### LLMProvider
- `available()` -> bool
- `generate(system, user, *, temperature)` -> str

### ImageProvider
- `available()` -> bool
- `generate(prompt, width, height, save_path, *, seed)` -> None
- `remove_background(input_path, output_path)` -> None
- `generate_audio(prompt, duration, save_path, *, category)` -> None

### TTSProvider
- `available()` -> bool
- `synthesize(text, character, save_path)` -> bool

## 内置 Provider

### OpenAICompatibleLLM
兼容所有 OpenAI 格式的 API（OpenAI、MiMo、DeepSeek 等）。

```python
from akonado.providers import OpenAICompatibleLLM

llm = OpenAICompatibleLLM(
    api_key="your-key",
    base_url="https://api.example.com/v1",
    model="model-name"
)
```

### ComfyUIImageProvider
封装 ComfyUI REST API，用于图像和音频生成。

```python
from akonado.providers import ComfyUIImageProvider

image = ComfyUIImageProvider(base_url="http://127.0.0.1:8188")
```

需要在 `comfyui/` 文件夹中放置工作流 JSON 文件，使用 `{{prompt}}`、`{{width}}`、`{{height}}`、`{{seed}}` 占位符。

### MiMoTTS
基于小米 MiMo API 的云端 TTS（OpenAI 兼容格式）。

### QwenTTS
基于 Qwen3-TTS CustomVoice 模型的本地 GPU 推理。

## 添加自定义 Provider

```python
from akonado.providers.base import LLMProvider

class MyProvider(LLMProvider):
    def available(self) -> bool:
        return True

    def generate(self, system: str, user: str, *, temperature: float = 0.7) -> str:
        # 你的实现
        return "result"
```
