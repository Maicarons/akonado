# 环境搭建指南

本文档指导你从零搭建 Akonado 全套运行环境，包括 Python 管线、LLM API、ComfyUI 图像生成、TTS 配音和 Godot 运行时。

## 总览

Akonado 由以下组件构成，你需要全部搭建才能跑通完整管线：

| 组件 | 用途 | 是否必需 |
|------|------|---------|
| Python 3.10+ | 运行 Akonado 管线 | 是 |
| LLM API | 剧本、角色、场景生成 | 是 |
| ComfyUI | 角色立绘、背景图、BGM、音效生成 | 是 |
| TTS 引擎 | 角色配音合成 | 是（MiMo 或 Qwen 二选一） |
| Godot 4.7+ | 运行生成的视觉小说 | 运行时需要 |

### 硬件要求

| 配置 | 最低要求 | 推荐配置 |
|------|---------|---------|
| CPU | 任意 64 位处理器 | 8 核以上 |
| 内存 | 8GB | 16GB+ |
| 显卡 | 无（用 CPU 跑 ComfyUI 会很慢） | NVIDIA GPU 8GB+ 显存 |
| 硬盘 | 20GB 可用空间 | 50GB+（模型文件较大） |
| 网络 | 需要联网下载模型和调用云端 API | 稳定宽带 |

> 如果没有 NVIDIA GPU，ComfyUI 可以用 CPU 模式运行（非常慢），TTS 可以用 MiMo 云端 API（无需 GPU）。

---

## 第一步：安装 Python 环境

### 1.1 安装 Python

Akonado 需要 Python 3.10 或更高版本（支持 3.10 ~ 3.13）。

**Windows：**

从 [python.org](https://www.python.org/downloads/) 下载安装包，安装时勾选 **"Add Python to PATH"**。

验证安装：
```bash
python --version
# 应输出 Python 3.10.x 或更高版本
```

**Linux / macOS：**
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install python3 python3-pip python3-venv

# macOS (Homebrew)
brew install python@3.12
```

### 1.2 创建虚拟环境（推荐）

```bash
cd akonado
python -m venv .venv

# Windows 激活
.venv\Scripts\activate

# Linux / macOS 激活
source .venv/bin/activate
```

激活后终端提示符会出现 `(.venv)` 前缀，表示虚拟环境已生效。每次打开新终端都需要重新激活。

### 1.3 安装 Akonado

```bash
pip install -e .
```

这会安装 Akonado 及其所有 Python 依赖：
- `requests` — HTTP 请求
- `Pillow` — 图像处理
- `python-dotenv` — 环境变量管理
- `openai` — LLM API 客户端
- `flask` — Web GUI

验证安装：
```bash
python -m akonado --help
```

应显示命令帮助信息。

---

## 第二步：配置 API 密钥

### 2.1 创建配置文件

```bash
cp akonado/.env.example akonado/.env
```

用文本编辑器打开 `akonado/.env`，填入以下配置。

### 2.2 LLM API（必需）

Akonado 使用 LLM 生成剧本、角色定义、场景脚本等文本内容。支持所有 OpenAI 兼容 API。

**使用小米 MiMo（推荐，国内访问快）：**

1. 前往 [小米 MiMo 开放平台](https://mimo.xiaomi.com/) 注册账号
2. 创建应用，获取 API Key
3. 在 `.env` 中填写：

```env
LLM_API_KEY=your-mimo-api-key
LLM_BASE_URL=https://api.xiaomimimo.com/v1
LLM_MODEL=mimo-v2.5-pro
```

**使用 OpenAI：**

```env
LLM_API_KEY=sk-your-openai-key
LLM_BASE_URL=https://api.openai.com/v1
LLM_MODEL=gpt-4o
```

**使用其他兼容 API（DeepSeek、硅基流动等）：**

```env
LLM_API_KEY=your-key
LLM_BASE_URL=https://api.siliconflow.cn/v1
LLM_MODEL=deepseek-ai/DeepSeek-V3
```

只要兼容 OpenAI API 格式即可。

---

## 第三步：搭建 ComfyUI（图像/音频生成）

ComfyUI 是 Akonado 的图像和音频生成后端，用于生成角色立绘、背景图、BGM 和音效。

### 3.1 安装 ComfyUI

**方式一：官方安装包（推荐）**

1. 访问 [ComfyUI Releases](https://github.com/comfyanonymous/ComfyUI/releases)
2. 下载最新版 `ComfyUI_windows_portable.zip`
3. 解压到任意目录（建议路径不含中文和空格）
4. 运行 `run_nvidia_gpu.bat`（NVIDIA 显卡）或 `run_cpu.bat`（无 GPU）

**方式二：手动安装**

```bash
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI
pip install -r requirements.txt
python main.py
```

启动后访问 http://127.0.0.1:8188 ，能看到 ComfyUI 界面即表示安装成功。

### 3.2 安装自定义节点

Akonado 的工作流依赖以下自定义节点：

```bash
cd ComfyUI/custom_nodes

# ComfyUI-KJNodes（PrimitiveStringMultiline 等节点）
git clone https://github.com/kijai/ComfyUI-KJNodes.git

# ComfyUI-BiRefNet（背景移除）
git clone https://github.com/ltdrdata/ComfyUI-BiRefNet.git

# ComfyUI-StableAudioSuite（音频生成）
git clone https://github.com/b-fission/ComfyUI-StableAudioSuite.git
```

安装后重启 ComfyUI。

### 3.3 下载模型

需要下载以下模型到 ComfyUI 对应目录：

**图像生成（必需）：**

| 模型 | 下载地址 | 放置路径 |
|------|---------|---------|
| ernie-image-turbo | [HuggingFace](https://huggingface.co/baidu/ERNIE-Image-Turbo) | `ComfyUI/models/unet/` |
| ministral-3-3b | [HuggingFace](https://huggingface.co/Comfy-Org/ministral-3b-3b-instruct) | `ComfyUI/models/clip/` |
| flux2-vae | [HuggingFace](https://huggingface.co/black-forest-labs/FLUX.2-schnell) | `ComfyUI/models/vae/` |
| ernie-image-prompt-enhancer | [HuggingFace](https://huggingface.co/baidu/ERNIE-Image) | `ComfyUI/models/clip/` |

**音频生成（必需）：**

| 模型 | 下载地址 | 放置路径 |
|------|---------|---------|
| stable_audio_3_small_music | [HuggingFace](https://huggingface.co/stabilityai/stable-audio-open-small) | `ComfyUI/models/checkpoints/` |
| qwen3.5_2b_bf16 | [HuggingFace](https://huggingface.co/Qwen/Qwen3.5-2B) | `ComfyUI/models/clip/` |
| t5gemma_b_b_ul2 | [HuggingFace](https://huggingface.co/google/t5gemma-b-b-ul2) | `ComfyUI/models/clip/` |

**背景移除（必需）：**

| 模型 | 下载地址 | 放置路径 |
|------|---------|---------|
| birefnet | [HuggingFace](https://huggingface.co/ZhengPeng7/BiRefNet) | `ComfyUI/models/birefnet/` |

### 3.4 配置 Akonado 连接 ComfyUI

在 `akonado/.env` 中确认 ComfyUI 地址：

```env
COMFYUI_URL=http://127.0.0.1:8188
```

如果 ComfyUI 运行在其他机器或端口，修改此地址即可。

### 3.5 验证

确保 ComfyUI 正在运行，然后执行：

```bash
python -m akonado check
```

输出应包含：
```
ComfyUI (Image/Audio): OK

ComfyUI workflows (5):
  - audio:stable_audio_3
  - image:ernie_image_turbo
  - image:logo_workflow
  - image:title_bg_workflow
  - utility:remove_bg
```

> 更详细的 ComfyUI 配置说明见 [ComfyUI 搭建指南](comfyui-setup.md)。

---

## 第四步：搭建 TTS 配音引擎

Akonado 支持两种 TTS 引擎，**二选一**即可：

| 引擎 | 特点 | 适合场景 |
|------|------|---------|
| MiMo TTS（云端） | 无需 GPU，按 API 调用计费 | 无 GPU 或不想折腾本地模型 |
| Qwen TTS（本地） | 需要 GPU，免费离线 | 有 8GB+ 显存的 NVIDIA GPU |

### 方案一：MiMo TTS（推荐，无需 GPU）

1. 前往 [小米 MiMo 开放平台](https://mimo.xiaomi.com/) 注册并获取 API Key
2. 在 `akonado/.env` 中填写：

```env
MIMO_API_KEY=your-mimo-api-key
MIMO_BASE_URL=https://api.xiaomimimo.com/v1
MIMO_TTS_MODEL=mimo-v2.5-tts
```

> MiMo TTS 中文必须使用预置音色名（冰糖/茉莉/苏打/白桦），详见 [TTS 配音搭建指南](tts-setup.md)。

### 方案二：Qwen TTS（本地 GPU）

1. 确保有 NVIDIA GPU（8GB+ 显存）和 CUDA 11.8+
2. 安装 qwen_tts 包：

```bash
pip install qwen-tts
```

3. 下载 [Qwen3-TTS CustomVoice 模型](https://huggingface.co/Qwen/Qwen3-TTS) 到本地
4. 在 `akonado/.env` 中填写：

```env
QWEN_TTS_MODEL_PATH=/path/to/Qwen3-TTS-CustomVoice
QWEN_TTS_DEVICE=cuda:0
QWEN_TTS_DTYPE=bfloat16
```

5. 安装音频依赖：

```bash
pip install soundfile
```

### 验证 TTS

```bash
python -m akonado check
```

输出应包含 `MiMo TTS: OK` 或 `Qwen TTS: OK`。

> 详细的音色配置和故障排除见 [TTS 配音搭建指南](tts-setup.md)。

---

## 第五步：安装 Godot（运行时）

Godot 是视觉小说的运行引擎。Akonado 生成的 `.ks` 脚本和资产需要在 Godot 中运行。

### 5.1 下载 Godot

从 [Godot 官网](https://godotengine.org/download) 或 [Steam](https://store.steampowered.com/app/404790/Godot_Engine/) 下载 **Godot 4.7+** 标准版。

### 5.2 配置 Godot 路径（可选）

在 `akonado/.env` 中设置 Godot 引擎目录，方便使用快捷脚本启动：

```env
GODOT_DIR=C:\path\to\Godot Engine
```

如果不设置，你也可以直接用 Godot 打开项目根目录的 `project.godot` 文件。

### 5.3 打开项目

1. 启动 Godot
2. 点击"导入"或"打开项目"
3. 选择 Akonado 项目根目录的 `project.godot` 文件
4. 点击"运行"（F5）即可体验生成的视觉小说

> 注意：`addons/konado/` 是上游 Konado 框架，不要修改它。

---

## 第六步：验证全部组件

```bash
python -m akonado check
```

完整输出示例：
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

- **ComfyUI: OK** — 图像/音频生成可用
- **LLM: OK** — 剧本生成可用
- **MiMo TTS: OK** 或 **Qwen TTS: OK** — 配音可用（至少一个）

如果某个组件显示 `NOT AVAILABLE`，检查对应的 API 密钥和网络连接。

---

## 第七步：运行第一个项目

### 7.1 一键生成（推荐）

```bash
python -m akonado pipeline "一个关于奶茶店的故事，主角面临传统与现代的选择"
```

这会自动执行完整的 7 步管线：

1. **生成剧本** → `akonado/manifests/script.json`
2. **生成角色提示** → `akonado/manifests/characters.json`
3. **生成背景提示** → `akonado/manifests/backgrounds.json`
4. **生成音频提示** → `akonado/manifests/bgm.json` + `se.json`
5. **生成配音配置** → `akonado/manifests/voice_config.json`
6. **生成视觉/音频资产** → `assets/` 目录
7. **生成 .ks 脚本 + 配音** → `story/` + `assets/audio/voice/`

### 7.2 自定义参数

```bash
# 指定章节数和每章场景数
python -m akonado pipeline "科幻冒险故事" --chapters 5 --scenes-per-chapter 4

# 使用 Qwen TTS 引擎（本地 GPU）
python -m akonado pipeline "故事概要" --engine qwen

# 调整 LLM 温度（0.0-1.0，越高越有创意）
python -m akonado pipeline "故事概要" --temperature 0.8

# 强制重新生成（不跳过已有文件）
python -m akonado pipeline "故事概要" --force

# 只生成剧本和 prompt，不生成素材（两阶段工作流）
python -m akonado pipeline "故事概要" --prompts-only
```

### 7.3 在 Godot 中运行

1. 用 Godot 打开 `project.godot`
2. 按 F5 运行
3. 体验你生成的视觉小说！

### 7.4 分步生成

如果需要更精细的控制：

```bash
# 1. 生成剧本
python -m akonado skill run -n generate_script -i "故事概要" -o akonado/manifests/script.json

# 2. 生成各类资产
python -m akonado generate characters    # 角色立绘
python -m akonado generate backgrounds   # 背景图
python -m akonado generate bgm           # 背景音乐
python -m akonado generate se            # 音效
python -m akonado generate ui            # UI 资产

# 3. 生成 .ks 脚本
python -m akonado generate scenes        # 生成所有场景脚本

# 4. 生成配音
python -m akonado generate voice

# 或一次性生成全部
python -m akonado generate all
```

---

## 快捷脚本

平台快捷脚本位于 `scripts/` 目录，简化常用操作：

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

---

## Web GUI

Akonado 提供浏览器端可视化管理界面：

```bash
python -m akonado web
```

在浏览器打开 http://127.0.0.1:5000 ，可以：
- 查看和编辑所有 manifest
- 运行单个 skill
- 触发资产生成
- 查看生成统计

详见 [Web GUI 文档](web-gui.md)。

---

## 常见问题

### pip install 报错

如果遇到 `setuptools` 相关错误，尝试升级 pip：
```bash
pip install --upgrade pip setuptools wheel
```

### ComfyUI 连接失败

确保 ComfyUI 正在运行且地址正确：
```bash
python -m akonado check
```
详见 [ComfyUI 搭建指南](comfyui-setup.md)。

### LLM API 报错

- 检查 API Key 是否正确
- 检查 `LLM_BASE_URL` 是否可访问
- 尝试用 `curl` 测试 API 连通性

### 配音生成失败

- MiMo TTS：检查 `MIMO_API_KEY` 配置
- Qwen TTS：检查模型路径和 GPU 显存
- 详见 [TTS 配音搭建指南](tts-setup.md)

### Godot 运行时报错

- 确保使用 Godot 4.7+ 版本
- 确保 `addons/konado/` 目录完整
- 详见 [Konado 踩坑记录](../../CLAUDE.md#known-pitfalls-踩坑记录)

### UnicodeDecodeError

确保系统区域设置支持 UTF-8。Windows 用户可以在"设置 > 时间和语言 > 区域 > 管理语言设置 > 更改系统区域设置"中勾选"Beta: 使用 Unicode UTF-8 提供全球语言支持"。

### 磁盘空间不足

生成的资产文件可能较大（角色立绘、BGM、配音等）。建议预留 50GB+ 空间。可以用 `python -m akonado clean` 清理不需要的文件。

---

## 下一步

- [工作流程指南](workflow.md) — 两阶段工作流、选择性重新生成、素材补全
- [架构设计](architecture.md) — 了解管线内部工作原理
- [技能系统](skills.md) — 自定义 LLM prompt 模板
- [资产清单](manifests.md) — 了解各 manifest 格式
- [TTS 配音搭建指南](tts-setup.md) — 深入配置配音引擎
- [ComfyUI 搭建指南](comfyui-setup.md) — 深入配置图像/音频生成
