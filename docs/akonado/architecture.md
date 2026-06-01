# 架构设计

## 管线流程

Akonado 采用七步管线架构，从一句话概要生成完整的视觉小说资产：

```
一句话概要
    │
    ▼
┌─────────────────────────────────────────────────┐
│  Step 1: LLM → script.json                      │
│    generate_script skill                        │
│    输出: 章节、场景、角色、背景、BGM、SE 定义     │
└─────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────┐
│  Step 2-5: LLM → 各类 manifests                  │
│    characters.json / backgrounds.json            │
│    bgm.json + se.json / voice_config.json        │
└─────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────┐
│  Step 6: Providers → 生成视觉/音频资产            │
│    ComfyUI → 角色立绘、背景图、BGM、SE、UI        │
│    输出到 assets/ 目录                            │
└─────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────┐
│  Step 7a: LLM → .ks 脚本                         │
│    generate_scene_script skill                   │
│    输出到 story/ 目录                             │
├─────────────────────────────────────────────────┤
│  Step 7b: TTS → 配音文件                          │
│    从 .ks 提取台词 → 合成 → 注入 voice label       │
│    输出到 assets/audio/voice/                     │
└─────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────┐
│  Godot + Konado → 运行视觉小说                    │
└─────────────────────────────────────────────────┘
```

### 执行顺序的重要性

配音生成（Step 7b）必须在 .ks 脚本生成（Step 7a）之后执行，因为配音流程需要从 .ks 脚本中提取台词行。

## 核心模块

### config.py — 全局配置

所有配置从 `.env` 文件加载（通过 python-dotenv）。定义：
- 路径常量（assets、manifests、skills、comfyui 目录）
- Provider 凭据（LLM、ComfyUI、TTS）
- Web GUI 设置

### providers/ — 后端抽象层

所有 provider 实现 `base.py` 中的抽象接口：

| 抽象基类 | 职责 | 实现 |
|----------|------|------|
| `LLMProvider` | 文本生成 | `OpenAICompatibleLLM` |
| `ImageProvider` | 图像/音频生成 + 背景移除 | `ComfyUIClient` |
| `TTSProvider` | 语音合成 | `MiMoTTS`、`QwenTTS` |

### generators/ — 资产生成器

每个 generator 读取对应的 manifest JSON，调用 provider 生成输出文件：

| Generator | 输入 Manifest | 输出 |
|-----------|--------------|------|
| `characters.py` | characters.json | `assets/characters/<id>/<expr>.png`（透明背景） |
| `backgrounds.py` | backgrounds.json | `assets/backgrounds/<id>.png` |
| `bgm.py` | bgm.json | `assets/audio/bgm/<id>.mp3` |
| `se.py` | se.json | `assets/audio/se/<id>.mp3` |
| `voice.py` | .ks 脚本 + voice_config.json | `assets/audio/voice/<hash>.wav` |
| `ui.py` | ui.json | `ui/<filename>.png` |
| `dialogue.py` | .ks 脚本 | `manifests/dialogue.json` |

### skills/ — LLM 技能系统

JSON 格式的 prompt 模板，包含 `system_prompt` + `user_prompt_template`（支持 `{placeholder}` 变量）。通过 `skill run` 命令或 Web GUI 运行。

### comfyui/ — 工作流模板

ComfyUI 工作流 JSON 文件，按文件名前缀自动分类：
- `image_*.json` → 图像生成
- `audio_*.json` → 音频生成
- `*_remove_background.json` → 背景移除

### web/ — Flask Web GUI

浏览器端可视化管理：查看/编辑 manifests、运行 skills、触发生成、查看统计。

## 目录结构

```
akonado/                        # 项目根目录（Godot 项目）
├── addons/konado/              # Konado 插件（上游视觉小说框架）
├── assets/                     # 游戏资产（由 AI 生成）
│   ├── characters/             #   角色精灵图（PNG，透明背景）
│   │   └── <character_id>/     #     每个角色一个子目录
│   │       ├── normal.png
│   │       ├── happy.png
│   │       └── ...
│   ├── backgrounds/            #   背景图片（PNG，1920x1080）
│   └── audio/
│       ├── bgm/                #   背景音乐（MP3）
│       ├── se/                 #   音效（MP3）
│       └── voice/              #   配音文件（WAV，内容哈希命名）
├── story/                      # Konado .ks 脚本
│   └── chapter01/
│       └── chapter01_01.ks
├── ui/                         # UI 资产
├── docs/
│   ├── konado/                 #   Konado 框架文档（上游）
│   └── akonado/                #   Akonado AI 管线文档
├── akonado/                    # AI 资产生成管线（Python 包）
│   ├── config.py               #   全局配置
│   ├── cli.py                  #   CLI 入口
│   ├── providers/              #   后端抽象层
│   │   ├── base.py             #     抽象基类
│   │   ├── llm.py              #     OpenAI 兼容 LLM
│   │   ├── comfyui.py          #     ComfyUI 图像/音频
│   │   ├── tts_mimo.py         #     MiMo TTS（云端）
│   │   └── tts_qwen.py         #     Qwen3 TTS（本地）
│   ├── generators/             #   资产生成器
│   ├── skills/                 #   LLM prompt 模板（JSON）
│   ├── manifests/              #   资产清单定义（JSON）
│   ├── comfyui/                #   ComfyUI 工作流模板
│   └── web/                    #   Flask Web GUI
├── scripts/                    # 平台快捷脚本
│   ├── Windows/                #   .cmd 脚本
│   ├── Linux/                  #   .sh 脚本
│   └── macOS/                  #   .sh 脚本
└── tests/                      # 单元测试
```

## 设计原则

1. **后端抽象** — Provider 接口统一，切换后端无需改 generator 代码
2. **JSON 驱动** — 所有数据通过 JSON manifests 流转，便于编辑和版本控制
3. **技能驱动** — LLM prompt 基于模板，可复用、可组合
4. **增量生成** — 默认跳过已存在的文件，`--force` 强制重新生成
5. **解耦** — Python 管线与 Godot 项目相互独立，通过 `assets/` 和 `story/` 交接
