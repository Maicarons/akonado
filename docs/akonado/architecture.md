# 架构设计

## 管线流程

Akonado 采用十步管线架构，从一句话概要生成完整的视觉小说资产：

```
一句话概要
    │
    ▼
┌─────────────────────────────────────────────────┐
│  Step 1-7: LLM → 各类 manifests                   │
│    script.json / characters.json                  │
│    backgrounds.json / cgs.json                    │
│    bgm.json + se.json / voice_config.json          │
│    ui.json                                        │
└─────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────┐
│  Step 8: Providers → 生成视觉/音频资产            │
│    ComfyUI → 角色立绘、背景图、CG插画、           │
│              BGM、SE、UI                          │
│    输出到 assets/ 目录                            │
└─────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────┐
│  Step 9a: LLM → .ks 脚本                         │
│    generate_scene_script skill                   │
│    输出到 story/ 目录                             │
├─────────────────────────────────────────────────┤
│  Step 9b: TTS → 配音文件                          │
│    从 .ks 提取台词 → 合成 → 注入 voice label       │
│    输出到 assets/audio/voice/                     │
└─────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────┐
│  Step 10: 生成 Konado 2.8 场景文件 & .tres 资源   │
│    character_scenes → .tscn 场景文件              │
│    background_scenes → .tscn 场景文件              │
│    cg_scenes → .tscn 场景文件                      │
│    godot_resources → .tres 资源清单文件             │
└─────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────┐
│  Godot + Konado 2.8 → 运行视觉小说                │
│  (dialogue_runtime.tscn + 编译的 .ks 脚本)        │
└─────────────────────────────────────────────────┘
```

### 执行顺序的重要性

配音生成（Step 9b）必须在 .ks 脚本生成（Step 9a）之后执行，因为配音流程需要从 .ks 脚本中提取台词行。

场景文件生成（Step 10）必须在所有视觉/音频资产生成之后执行，因为 .tscn 文件需要引用已存在的 PNG/MP3 文件。

### Konado 2.8 架构变更

Konado 2.8 对运行时架构进行了重大重构，Akonado 已全面适配：

| 变更 | Konado 2.5 | Konado 2.8+ |
|------|-----------|-------------|
| 资源命名 | `KND_` 前缀（e.g. `KND_Shot`） | `Konado` 前缀（e.g. `KonadoShot`） |
| 角色系统 | 纹理引用（`KND_CharacterStatus`） | 场景引用（`KonadoCharacterSceneBase`） |
| 背景系统 | 纹理引用（`KND_Background`） | 场景引用（`KonadoBackgroundSceneBase`） |
| 运行时 | 解释器直接解析 .ks | 编译器编译为字节码（`KonadoProgram`） |
| 编辑器 | `ks_editor/` | `script_editor/`（语言服务） |
| 模板 | `template/` | `templates/default/` |
| 主场景 | `konado_dialogue.tscn` | `dialogue_runtime.tscn`（完整运行时） |

## 核心模块

### config.py — 全局配置

所有配置从 `.env` 文件加载（通过 python-dotenv）。定义：
- 路径常量（assets、manifests、skills、comfyui 目录）
- Provider 凭据（LLM、ComfyUI、TTS）
- Web GUI 设置
- Konado 2.8 资源脚本路径常量

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
| `cg.py` | cgs.json | `assets/cgs/<id>.png`（CG 插画，1920x1080） |
| `bgm.py` | bgm.json | `assets/audio/bgm/<id>.mp3` |
| `se.py` | se.json | `assets/audio/se/<id>.mp3` |
| `voice.py` | .ks 脚本 + voice_config.json | `assets/audio/voice/<hash>.wav` |
| `ui.py` | ui.json | `ui/<filename>.png` |
| `dialogue.py` | .ks 脚本 | `manifests/dialogue.json` |
| `character_scenes.py` | characters.json + PNG | `assets/characters/<id>/<id>.tscn`（角色场景） |
| `background_scenes.py` | backgrounds.json + PNG | `assets/backgrounds/<id>.tscn`（背景场景） |
| `cg_scenes.py` | cgs.json + PNG | `assets/cgs/<id>.tscn`（CG 场景） |
| `godot_resources.py` | 所有 asset + .tscn | `*.tres`（资源清单文件） |

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
├── addons/konado/              # Konado 插件（上游视觉小说框架 v2.8+）
├── assets/                     # 游戏资产（由 AI 生成）
│   ├── characters/             #   角色精灵图（PNG）+ 场景文件（.tscn）
│   │   └── <character_id>/
│   │       ├── normal.png
│   │       ├── happy.png
│   │       ├── <id>.tscn       #   Konado 2.8 角色场景
│   │       └── ...
│   ├── backgrounds/            #   背景图片（PNG）+ 场景文件（.tscn）
│   │       ├── <id>.png
│   │       └── <id>.tscn
│   ├── cgs/                    #   CG 插画（PNG）+ 场景文件（.tscn）
│   │       ├── <id>.png
│   │       └── <id>.tscn
│   └── audio/
│       ├── bgm/                #   背景音乐（MP3）+ bgm.tres
│       ├── se/                 #   音效（MP3）+ se.tres
│       └── voice/              #   配音文件（WAV）+ voice.tres
├── story/                      # Konado .ks 脚本
│   └── chapter01/
│       └── chapter01_01.ks
├── ui/                         # UI 资产
├── resources/                  # Konado 2.8 资源模板
│   ├── akonado_character_scene.gd
│   └── akonado_character_scene.tscn
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
│   │   ├── characters.py       #     角色精灵图
│   │   ├── character_scenes.py #     角色场景（.tscn）
│   │   ├── backgrounds.py      #     背景图片
│   │   ├── background_scenes.py#     背景场景（.tscn）
│   │   ├── cg.py               #     CG 插画
│   │   ├── bgm.py              #     背景音乐
│   │   ├── se.py               #     音效
│   │   ├── voice.py            #     配音
│   │   ├── ui.py               #     UI 资产
│   │   ├── dialogue.py         #     台词提取
│   │   └── godot_resources.py  #     .tres 资源文件
│   ├── skills/                 #   LLM prompt 模板（JSON）
│   ├── manifests/              #   资产清单定义（JSON）
│   ├── comfyui/                #   ComfyUI 工作流模板
│   └── web/                    #   Flask Web GUI
├── scripts/                    # 平台快捷脚本
│   ├── Windows/                #   .cmd 脚本
│   ├── Linux/                  #   .sh 脚本
│   └── macOS/                  #   .sh 脚本
├── main.tscn                   # 主场景（Konado 2.8 dialogue_runtime）
├── main.gd                     # 主场景脚本
├── project.godot               # Godot 项目配置
└── tests/                      # 单元测试
```

## 设计原则

1. **后端抽象** — Provider 接口统一，切换后端无需改 generator 代码
2. **JSON 驱动** — 所有数据通过 JSON manifests 流转，便于编辑和版本控制
3. **技能驱动** — LLM prompt 基于模板，可复用、可组合
4. **增量生成** — 默认跳过已存在的文件，`--force` 强制重新生成
5. **解耦** — Python 管线与 Godot 项目相互独立，通过 `assets/` 和 `story/` 交接

## Konado 2.8 关键概念

### 场景化资源

Konado 2.8 将角色和背景从"纹理引用"改为"场景引用"：

- **角色**：每个角色有一个 `.tscn` 场景文件，继承 `KonadoCharacterSceneBase`，内部包含 `TextureRect` 和各种表情状态
- **背景**：每个背景有一个 `.tscn` 场景文件，继承 `KonadoBackgroundSceneBase`，内部包含 `TextureRect`
- **CG**：CG 插画注册为背景，同样使用场景文件

### 字节码运行时

Konado 2.8 引入虚拟机和字节码系统：

1. `.ks` 源文件 → `KonadoScriptCompiler` 编译为 `KonadoProgram`（字节码）
2. `KonadoProgram` 包含：操作码（opcodes）、操作数（operands）、常量池（constants）
3. `KonadoVirtualMachine` 执行字节码，驱动对话、角色、背景、音频等系统
4. 支持可恢复的故障会话（`KonadoRuntimeFailureSession`）

### 资源清单文件 (.tres)

Akonado 生成的 `.tres` 文件引用的是场景文件（`.tscn`）而非直接引用纹理：

- `characters.tres` → `KonadoCharacterList` → `KonadoCharacter.character_scene`（PackedScene）
- `backgrounds.tres` → `KonadoBackgroundList` → `KonadoBackground.background_scene`（PackedScene）