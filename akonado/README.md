# Akonado

基于 Godot + Konado 的 AI 视觉小说资产生成管线。

## 功能特性

- 一句话生成完整剧本：从一句话概要生成完整的视觉小说剧本 + 角色 + 场景
- 角色立绘生成：通过 ComfyUI 生成，自动去背景
- 背景图、CG 插画、BGM、音效、UI 资产生成
- CG 插画生成：重要剧情场景的高质量插画（角色+背景合一）
- 配音合成：MiMo TTS（云端）或 Qwen3 TTS（本地 GPU）
- JSON 管理资产清单，便于编辑和自动化
- Web GUI 可视化编辑和生成控制
- CLI 支持批量操作
- 可扩展的 skill 系统和 prompt 模板

## 快速开始

```bash
# 1. 安装依赖
cd akonado
pip install -e .

# 2. 配置 API 密钥
cp .env.example .env
# 编辑 .env 填入你的密钥

# 3. 检查 provider 可用性
python -m akonado check

# 4. 从概要生成剧本
python -m akonado skill run -n generate_script -i "一个关于奶茶店的故事"

# 5. 生成资产
python -m akonado generate all

# 6. 启动 Web GUI
python -m akonado web
```

## 工作流程

### 一键生成

```bash
python -m akonado pipeline "一个关于奶茶店的故事"
```

### 两阶段工作流（推荐）

先生成剧本和 prompt，手动调整后再生成素材：

```bash
# 阶段一：只生成剧本和 prompt（不生成图片/音频）
python -m akonado pipeline "故事概要" --prompts-only

# 编辑 manifests/*.json 调整角色外观、背景描述、BGM 等...

# 阶段二：生成实际素材
python -m akonado generate all
```

### 选择性重新生成

```bash
# 重新生成某一类素材（已有文件自动跳过）
python -m akonado generate characters
python -m akonado generate voice --engine qwen

# 强制覆盖已有文件
python -m akonado generate characters --force

# 检测缺失素材并自动补全
python -m akonado generate all --check-missing
```

### 清理

```bash
python -m akonado clean characters   # 清理角色素材
python -m akonado clean all          # 清理全部素材
python -m akonado clean all --deep   # 连 manifests 和 .ks 脚本一起清理
```

## 架构

```
akonado/
  config.py           # 全局配置（加载 .env）
  cli.py              # CLI 入口
  providers/          # 后端抽象层
    base.py           # 抽象基类（LLM、Image、TTS）
    llm.py            # OpenAI 兼容 LLM
    image.py          # ComfyUI 图像/音频
    tts_mimo.py       # MiMo TTS（云端）
    tts_qwen.py       # Qwen3 TTS（本地 GPU）
  generators/         # 资产生成管线
    characters.py     # 角色精灵图生成器
    backgrounds.py    # 背景图片生成器
    cg.py             # CG插画生成器（高质量场景插画）
    bgm.py            # 背景音乐生成器
    se.py             # 音效生成器
    voice.py          # 配音合成管线
    ui.py             # UI 资产生成器
    dialogue.py       # .ks 脚本台词提取器
  skills/             # LLM prompt 模板（JSON）
    generate_script.json
    generate_character_prompts.json
    generate_background_prompts.json
    generate_cg_prompts.json
    generate_audio_prompts.json
    generate_scene_script.json
    generate_voice_config.json
  manifests/          # 资产定义（JSON，由 skill 生成）
  comfyui/            # ComfyUI 工作流模板
  web/                # Flask Web GUI
    app.py            # Flask 应用
    templates/        # HTML 模板
```

## 命令

| 命令 | 说明 |
|------|------|
| `python -m akonado pipeline "概要"` | 一键生成完整管线（剧本→prompt→素材→.ks） |
| `python -m akonado pipeline "概要" --prompts-only` | 只生成剧本和 prompt，不生成素材 |
| `python -m akonado generate <type>` | 生成资产（characters/backgrounds/cgs/bgm/se/voice/ui/dialogue/all） |
| `python -m akonado generate all --check-missing` | 检测缺失素材并自动补全 |
| `python -m akonado check` | 检查 provider 可用性 |
| `python -m akonado list [type]` | 查看 manifest 内容 |
| `python -m akonado clean <type>` | 删除生成的文件 |
| `python -m akonado skill list` | 列出可用 skills |
| `python -m akonado skill run -n <name> -i <input>` | 运行 LLM skill |
| `python -m akonado web` | 启动 Web GUI |

## Providers

### LLM（在线）
任何 OpenAI 兼容 API 均可。在 `.env` 中配置 `LLM_API_KEY`、`LLM_BASE_URL`、`LLM_MODEL`。

### Image/Audio（本地）
使用 ComfyUI 进行图像和音频生成。将工作流 JSON 文件放在 `comfyui/` 目录。

### TTS
- **MiMo TTS**：云端，在 `.env` 中配置 `MIMO_API_KEY`
- **Qwen3 TTS**：本地 GPU 推理，在 `.env` 中配置 `QWEN_TTS_MODEL_PATH`

## 添加自定义 Provider

实现 `providers/base.py` 中的基类：

```python
from akonado.providers.base import LLMProvider

class MyCustomLLM(LLMProvider):
    def available(self) -> bool:
        return True

    def generate(self, system: str, user: str, *, temperature: float = 0.7) -> str:
        # 你的实现
        return "generated text"
```

## 许可证

AGPL-3.0-only
