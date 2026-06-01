# ComfyUI 搭建指南

Akonado 使用 ComfyUI 作为图像和音频生成后端。本文档介绍如何安装、配置 ComfyUI 并准备所需模型。

## 1. 安装 ComfyUI

### 方式一：官方安装包（推荐）

1. 访问 [ComfyUI Releases](https://github.com/comfyanonymous/ComfyUI/releases)
2. 下载最新版 `ComfyUI_windows_portable.zip`
3. 解压到任意目录，运行 `run_nvidia_gpu.bat`（NVIDIA）或 `run_cpu.bat`（无 GPU）

### 方式二：手动安装

```bash
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI
pip install -r requirements.txt
python main.py
```

### 验证运行

启动后访问 http://127.0.0.1:8188 ，能看到 ComfyUI 界面即表示安装成功。

## 2. 安装自定义节点

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

## 3. 下载模型

### 图像生成（必需）

| 模型 | 下载地址 | 放置路径 |
|------|---------|---------|
| ernie-image-turbo | [HuggingFace](https://huggingface.co/baidu/ERNIE-Image-Turbo) | `ComfyUI/models/unet/` |
| ministral-3-3b | [HuggingFace](https://huggingface.co/Comfy-Org/ministral-3b-3b-instruct) | `ComfyUI/models/clip/` |
| flux2-vae | [HuggingFace](https://huggingface.co/black-forest-labs/FLUX.2-schnell) | `ComfyUI/models/vae/` |
| ernie-image-prompt-enhancer | [HuggingFace](https://huggingface.co/baidu/ERNIE-Image) | `ComfyUI/models/clip/` |

### 音频生成（必需）

| 模型 | 下载地址 | 放置路径 |
|------|---------|---------|
| stable_audio_3_small_music | [HuggingFace](https://huggingface.co/stabilityai/stable-audio-open-small) | `ComfyUI/models/checkpoints/` |
| qwen3.5_2b_bf16 | [HuggingFace](https://huggingface.co/Qwen/Qwen3.5-2B) | `ComfyUI/models/clip/` |
| t5gemma_b_b_ul2 | [HuggingFace](https://huggingface.co/google/t5gemma-b-b-ul2) | `ComfyUI/models/clip/` |

### 背景移除（必需）

| 模型 | 下载地址 | 放置路径 |
|------|---------|---------|
| birefnet | [HuggingFace](https://huggingface.co/ZhengPeng7/BiRefNet) | `ComfyUI/models/birefnet/` |

### 目录结构示例

```
ComfyUI/
├── models/
│   ├── unet/
│   │   └── ernie-image-turbo.safetensors
│   ├── clip/
│   │   ├── ministral-3-3b.safetensors
│   │   ├── ernie-image-prompt-enhancer.safetensors
│   │   ├── qwen3.5_2b_bf16.safetensors
│   │   └── t5gemma_b_b_ul2.safetensors
│   ├── vae/
│   │   └── flux2-vae.safetensors
│   ├── checkpoints/
│   │   └── stable_audio_3_small_music.safetensors
│   └── birefnet/
│       └── birefnet.safetensors
└── custom_nodes/
    ├── ComfyUI-KJNodes/
    ├── ComfyUI-BiRefNet/
    └── ComfyUI-StableAudioSuite/
```

## 4. 放置 Akonado 工作流

Akonado 自带工作流 JSON 文件，位于 `akonado/comfyui/` 目录：

```
akonado/comfyui/
├── image_ernie_image_turbo.json    # 角色立绘、背景图生成
├── audio_stable_audio_3.json       # BGM、音效生成
├── utility_birefnet_remove_background.json  # 角色背景移除
├── logo_workflow.json              # Logo 生成
└── title_bg_workflow.json          # 标题背景生成
```

这些工作流会自动被 ComfyUI Provider 发现，无需手动导入。

## 5. 配置 Akonado

在 `akonado/.env` 中设置 ComfyUI 地址：

```env
COMFYUI_URL=http://127.0.0.1:8188
```

如果 ComfyUI 运行在其他机器或端口，修改此地址即可。

## 6. 验证连接

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

## 7. 自定义工作流

你可以在 `akonado/comfyui/` 中添加自己的工作流 JSON 文件，Akonado 会按文件名前缀自动分类：

- `image_*.json` → 图像生成（角色、背景、UI）
- `audio_*.json` → 音频生成（BGM、音效）
- `*_remove_background.json` → 背景移除

### 参数注入约定

工作流中的节点通过标题（`_meta.title`）识别参数：

| 节点标题关键词 | 注入参数 |
|--------------|---------|
| prompt | 用户输入的提示词 |
| width / height | 图像尺寸 |
| seed | 随机种子（不设置则自动随机化） |
| duration / audio / length | 音频时长 |

如果节点标题不包含关键词，会回退到占位符替换（`{prompt}`、`USER_INPUT` 等）。

## 常见问题

### ComfyUI 启动后报缺模型

检查模型文件名是否与工作流 JSON 中的名称完全一致（含大小写和扩展名）。

### 图像生成很慢

ernie-image-turbo 需要较大显存（建议 8GB+）。如果显存不足，可以：
- 减小生成分辨率（默认 1024x1024）
- 使用 `--force` 参数时注意不要重复生成

### 背景移除失败

确保 `ComfyUI-BiRefNet` 自定义节点已正确安装，且 `birefnet.safetensors` 模型已放置到正确路径。

### 音频生成失败

确保 `ComfyUI-StableAudioSuite` 自定义节点已安装。stable-audio 模型需要较多显存。
