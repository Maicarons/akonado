# 后端提供者（Providers）

Providers 是实际执行生成工作的后端实现。所有 provider 实现 `providers/base.py` 中的抽象接口，generator 代码无需关心具体后端。

## 抽象基类

### LLMProvider — 文本生成

```python
class LLMProvider(ABC):
    def available(self) -> bool: ...
    def generate(self, system: str, user: str, *, temperature: float = 0.7) -> str: ...
```

### ImageProvider — 图像/音频生成

```python
class ImageProvider(ABC):
    def available(self) -> bool: ...
    def generate(self, prompt, width, height, save_path, *, seed=None) -> None: ...
    def remove_background(self, input_path, output_path) -> None: ...
    def generate_audio(self, prompt, duration, save_path, *, category="Music") -> None: ...
```

### TTSProvider — 语音合成

```python
class TTSProvider(ABC):
    def available(self) -> bool: ...
    def synthesize(self, text: str, character: str, save_path: Path) -> bool: ...
```

## 内置 Provider

### OpenAICompatibleLLM

兼容所有 OpenAI 格式的 API（OpenAI、MiMo、DeepSeek 等）。

配置环境变量：`LLM_API_KEY`、`LLM_BASE_URL`、`LLM_MODEL`

```python
from akonado.providers import OpenAICompatibleLLM

llm = OpenAICompatibleLLM()
if llm.available():
    result = llm.generate("你是一个编剧", "写一个关于猫的故事")
```

### ComfyUIClient (ComfyUIImageProvider)

封装 ComfyUI REST API，用于图像和音频生成。支持工作流自动发现和参数注入。

配置环境变量：`COMFYUI_URL`

```python
from akonado.providers import ComfyUIClient

client = ComfyUIClient()
workflows = client.list_workflows()
# ['audio:stable_audio_3', 'image:ernie_image_turbo', 'utility:remove_bg', ...]

# 生成图像
client.generate(prompt="a cute cat", width=1024, height=1024, save_path=Path("cat.png"))

# 生成音频
client.generate_audio(prompt="gentle piano", duration=150, save_path=Path("bgm.mp3"))

# 背景移除
client.remove_background(Path("raw.png"), Path("transparent.png"))
```

#### 工作流自动发现

在 `akonado/comfyui/` 目录中放置工作流 JSON 文件，自动按文件名前缀分类：

| 前缀 | 分类 | 用途 |
|------|------|------|
| `image_*.json` | 图像生成 | 角色立绘、背景图、UI |
| `audio_*.json` | 音频生成 | BGM、音效 |
| `*_remove_background.json` | 背景移除 | 角色精灵去背景 |
| 其他 | 按输出节点自动检测 | — |

查看已发现的工作流：

```bash
python -m akonado workflows
```

#### 参数注入

工作流通过节点标题（`_meta.title`）自动识别参数：

| 节点标题关键词 | 注入参数 |
|--------------|---------|
| prompt | 用户输入的提示词 |
| width / height | 图像尺寸 |
| seed | 随机种子 |
| duration / audio / length | 音频时长 |

也支持占位符替换（在节点 value 中使用）：

| 占位符 | 映射参数 |
|--------|---------|
| `{prompt}` / `{{prompt}}` / `USER_INPUT` | prompt |
| `{width}` / `{{width}}` | width |
| `{height}` / `{{height}}` | height |
| `{seed}` / `{{seed}}` | seed |
| `{duration}` / `{{duration}}` / `AUDIO_LENGTH` | duration |

#### 种子随机化

KSampler 节点的种子会自动随机化，确保每次生成不同的结果。如需固定种子：

```python
client.generate(prompt="cat", width=1024, height=1024, save_path=Path("cat.png"), seed=42)
```

### MiMoTTS

基于小米 MiMo API 的云端 TTS（OpenAI 兼容格式）。

配置环境变量：`MIMO_API_KEY`、`MIMO_BASE_URL`、`MIMO_TTS_MODEL`

详见 [TTS 配音搭建指南](tts-setup.md)。

### QwenTTS

基于 Qwen3-TTS CustomVoice 模型的本地 GPU 推理。

配置环境变量：`QWEN_TTS_MODEL_PATH`、`QWEN_TTS_DEVICE`、`QWEN_TTS_DTYPE`

详见 [TTS 配音搭建指南](tts-setup.md)。

## 添加自定义 Provider

继承对应的抽象基类即可：

```python
from akonado.providers.base import LLMProvider

class MyProvider(LLMProvider):
    def available(self) -> bool:
        return True

    def generate(self, system: str, user: str, *, temperature: float = 0.7) -> str:
        return "generated text"
```

然后在 `providers/__init__.py` 中导出，generator 即可使用。
