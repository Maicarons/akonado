# 快速开始

## 环境要求

| 依赖 | 用途 | 是否必需 |
|------|------|---------|
| Python 3.10+ | 运行 Akonado 管线 | 是 |
| ComfyUI | 图像/音频生成 | 是（[搭建指南](comfyui-setup.md)） |
| TTS 引擎 | 配音合成 | 是（二选一，[搭建指南](tts-setup.md)） |
| Godot 4.6+ | 运行视觉小说 | 运行时需要 |

## 安装

```bash
cd akonado
pip install -e .
```

## 配置

```bash
cp .env.example .env
```

编辑 `akonado/.env`，填入你的 API 密钥：

```env
# LLM（剧本生成必需）
LLM_API_KEY=your-api-key
LLM_BASE_URL=https://api.xiaomimimo.com/v1
LLM_MODEL=mimo-v2.5-pro

# MiMo TTS（配音生成，与 Qwen 二选一）
MIMO_API_KEY=your-api-key
MIMO_BASE_URL=https://api.xiaomimimo.com/v1
MIMO_TTS_MODEL=mimo-v2.5-tts

# ComfyUI（图像/音频生成）
COMFYUI_URL=http://127.0.0.1:8188

# Godot 引擎目录（可选）
GODOT_DIR=G:\SteamLibrary\steamapps\common\Godot Engine
```

## 验证安装

```bash
python -m akonado check
```

输出示例：
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

## 一键生成（推荐）

从一句话概要生成完整的视觉小说资产：

```bash
python -m akonado pipeline "一个关于奶茶店的故事，主角面临传统与现代的选择"
```

### Pipeline 执行流程

1. **生成剧本** → `akonado/manifests/script.json`（章节、场景、角色、背景、音频定义）
2. **生成角色提示** → `akonado/manifests/characters.json`
3. **生成背景提示** → `akonado/manifests/backgrounds.json`
4. **生成音频提示** → `akonado/manifests/bgm.json` + `se.json`
5. **生成配音配置** → `akonado/manifests/voice_config.json`
6. **生成视觉/音频资产** → `assets/` 目录（角色立绘、背景图、BGM、音效、UI）
7. **生成 .ks 脚本** → `story/` 目录
8. **生成配音** → `assets/audio/voice/` 目录

### 自定义参数

```bash
# 指定章节数和每章场景数
python -m akonado pipeline "科幻冒险故事" --chapters 5 --scenes-per-chapter 4

# 使用 Qwen TTS 引擎（本地 GPU）
python -m akonado pipeline "故事概要" --engine qwen

# 指定 Godot 引擎目录
python -m akonado pipeline "故事概要" --godot-dir "C:\path\to\Godot"

# 强制重新生成（不跳过已有文件）
python -m akonado pipeline "故事概要" --force

# 调整 LLM 温度参数（0.0-1.0，越高越有创意）
python -m akonado pipeline "故事概要" --temperature 0.8
```

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--chapters` | 章节数 | 4 |
| `--scenes-per-chapter` | 每章场景数 | 3 |
| `--engine` | TTS 引擎（mimo/qwen） | mimo |
| `--godot-dir` | Godot 引擎目录 | 系统默认 |
| `--force` | 强制重新生成 | false |
| `--temperature` | LLM 温度参数 | 0.7 |

## 分步生成

如果需要更精细的控制，可以分步执行：

```bash
# 1. 生成剧本
python -m akonado skill run -n generate_script -i "故事概要" -o akonado/manifests/script.json

# 2. 生成各类资产
python -m akonado generate characters    # 角色立绘
python -m akonado generate backgrounds   # 背景图
python -m akonado generate bgm           # 背景音乐
python -m akonado generate se            # 音效
python -m akonado generate ui            # UI 资产

# 3. 生成 .ks 脚本（需要先有 script.json）
python -m akonado skill run -n generate_scene_script -i "场景概要" -o story/chapter01/scene01.ks

# 4. 生成配音（需要先有 .ks 脚本）
python -m akonado generate voice

# 5. 或者一次性生成全部
python -m akonado generate all
```

## 在 Godot 中运行

1. 用 Godot 4.6+ 打开项目根目录的 `project.godot`
2. 运行项目即可体验生成的视觉小说

生成的 `.ks` 脚本位于 `story/` 目录，使用 Konado 框架的 DSL 格式。

## Web GUI

启动可视化编辑界面：

```bash
python -m akonado web
```

在浏览器打开 http://127.0.0.1:5000 。详见 [Web GUI 文档](web-gui.md)。

## 清理生成文件

```bash
# 清理单个类型
python -m akonado clean characters

# 清理所有生成的素材
python -m akonado clean all

# 深度清理：素材 + manifests + .ks 脚本
python -m akonado clean all --deep
```

## 快捷脚本

平台快捷脚本位于 `scripts/` 目录：

```bash
# Windows
scripts\Windows\pipeline.cmd "故事概要"   # 完整管线
scripts\Windows\generate.cmd              # 生成全部资产
scripts\Windows\web.cmd                   # 启动 Web GUI
scripts\Windows\godot.cmd                 # 打开 Godot 编辑器

# Linux / macOS
scripts/Linux/pipeline.sh "故事概要"
scripts/macOS/pipeline.sh "故事概要"
```

## 常见问题

### ComfyUI 连接失败

确保 ComfyUI 正在运行：`python -m akonado check`。详见 [ComfyUI 搭建指南](comfyui-setup.md)。

### 配音生成失败

检查 TTS API 密钥配置：`python -m akonado check`。详见 [TTS 配音搭建指南](tts-setup.md)。

### 图片生成失败

检查 ComfyUI 工作流文件是否在 `akonado/comfyui/` 目录：`python -m akonado workflows`。

### 编码错误

如果遇到 `UnicodeDecodeError`，确保系统区域设置支持 UTF-8。
