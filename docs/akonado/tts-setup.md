# TTS 配音搭建指南

Akonado 支持两种 TTS 引擎用于角色配音生成。你可以根据环境选择其中一种。

## 方案对比

| 特性 | MiMo TTS（云端） | Qwen TTS（本地） |
|------|----------------|-----------------|
| 需要 GPU | 否 | 是（建议 8GB+ 显存） |
| 网络要求 | 需要联网 | 离线可用 |
| 费用 | 按 API 调用计费 | 免费 |
| 延迟 | 取决于网络 | 首次加载较慢，后续快 |
| 音质 | 优秀 | 优秀 |

## 方案一：MiMo TTS（云端，推荐）

小米 MiMo V2.5 TTS，通过 OpenAI 兼容 API 调用，无需本地 GPU。

### 1. 获取 API 密钥

前往 [小米 MiMo 开放平台](https://mimo.xiaomi.com/) 注册并获取 API Key。

### 2. 配置环境变量

在 `akonado/.env` 中填写：

```env
MIMO_API_KEY=your-api-key-here
MIMO_BASE_URL=https://api.xiaomimimo.com/v1
MIMO_TTS_MODEL=mimo-v2.5-tts
```

### 3. 验证

```bash
python -m akonado check
```

输出应包含 `MiMo TTS: OK`。

### 4. 使用

```bash
# pipeline 中默认使用 MiMo TTS
python -m akonado pipeline "故事概要"

# 或单独生成配音
python -m akonado generate voice
```

## 方案二：Qwen3 TTS（本地 GPU）

基于 Qwen3-TTS CustomVoice 模型的本地推理，支持自定义说话人音色。

### 1. 环境要求

- NVIDIA GPU，建议 8GB+ 显存
- CUDA 11.8+ 和 cuDNN
- Python 3.10+

### 2. 安装 qwen_tts 包

```bash
# 方式一：从 PyPI 安装
pip install qwen-tts

# 方式二：从源码安装
git clone https://github.com/QwenLM/Qwen3-TTS.git
cd Qwen3-TTS
pip install -e .
```

### 3. 下载模型

从 [HuggingFace](https://huggingface.co/Qwen/Qwen3-TTS) 下载 Qwen3-TTS CustomVoice 模型到本地目录。

### 4. 配置环境变量

在 `akonado/.env` 中填写：

```env
QWEN_TTS_MODEL_PATH=/path/to/Qwen3-TTS-CustomVoice
QWEN_TTS_DEVICE=cuda:0
QWEN_TTS_DTYPE=bfloat16
```

| 参数 | 说明 |
|------|------|
| `QWEN_TTS_MODEL_PATH` | 模型目录的绝对路径 |
| `QWEN_TTS_DEVICE` | 设备，如 `cuda:0`、`cuda:1`、`cpu` |
| `QWEN_TTS_DTYPE` | 精度：`bfloat16`（推荐）、`float16`、`float32` |

### 5. 安装音频依赖

```bash
pip install soundfile
```

### 6. 验证

```bash
python -m akonado check
```

输出应包含 `Qwen TTS: OK`。

### 7. 使用

```bash
# pipeline 中指定 Qwen 引擎
python -m akonado pipeline "故事概要" --engine qwen

# 或单独生成
python -m akonado generate voice --engine qwen
```

## 配音配置（voice_config.json）

两种 TTS 引擎都通过 `akonado/manifests/voice_config.json` 配置角色声音。Pipeline 会自动生成此文件，你也可以手动编辑。

### MiMo 预置音色（中文）

MiMo TTS 中文必须使用以下预置音色名，**不要使用英文音色**（Dean、Mia 等是英文音色，不适合中文配音）：

| 音色名 | 性别 | 描述 |
|--------|------|------|
| `冰糖` | 女性 | 阳光积极、亲切自然 |
| `茉莉` | 女性 | 温柔知性 |
| `苏打` | 男性 | 标准普通话、温暖阳光 |
| `白桦` | 男性 | 沉稳、低音、有磁性 |

### Qwen 常用中文音色

| 参数名 | 中文名 | 性别 | 描述 |
|--------|--------|------|------|
| `Ethan` | 晨煦 | 男 | 阳光温暖、标准普通话 |
| `Cherry` | 芊悦 | 女 | 阳光亲切 |
| `Serena` | 苏瑶 | 女 | 温柔 |
| `Eldric Sage` | 沧明子 | 男 | 沉稳睿智老者 |
| `Vincent` | 田叔 | 男 | 沙哑烟嗓 |
| `Kai` | 凯 | 男 | 沉稳 |
| `Moon` | 月白 | 男 | 率性帅气 |
| `Maia` | 四月 | 女 | 知性温柔 |
| `Ryan` | 甜茶 | 男 | 戏感十足 |
| `Chelsie` | 千雪 | 女 | 二次元 |
| `Nofish` | 不吃鱼 | 男 | 设计师口音 |

### 配置结构

```json
{
  "characters": {
    "陈默": {
      "profile": "28岁男性摄影师，沉默寡言，内心细腻敏感。",
      "instruct_mimo": "角色: 28岁男性摄影师，沉默寡言，内心细腻敏感。语速偏慢，语气平静中带有淡淡的疏离感。",
      "instruct_qwen": "用沉稳、略带距离感，但内在细腻温和的语气说。",
      "voices": {
        "mimo": "白桦",
        "qwen": "Ethan"
      },
      "gender": "male"
    },
    "林晚": {
      "profile": "27岁女性建筑设计师，外表干练，内心温柔。",
      "instruct_mimo": "角色: 27岁女性建筑设计师，外表干练专业，内心温柔怀旧。语速适中，表达情感时语速放缓。",
      "instruct_qwen": "用清晰、专业、干练的语气说，表达情感时转为温和。",
      "voices": {
        "mimo": "冰糖",
        "qwen": "Cherry"
      },
      "gender": "female"
    }
  },
  "emotion_rules": [
    {"label": "开心", "keywords": ["哈哈", "太好了", "开心"]},
    {"label": "悲伤", "keywords": ["对不起", "难过", "眼泪"]}
  ],
  "emotion_directions": {
    "平静": "用自然平和的语气说这句台词。",
    "开心": "用愉快、轻快的语气说这句台词。",
    "悲伤": "用低沉、略带哽咽的语气说这句台词。"
  }
}
```

### 字段说明

| 字段 | 说明 |
|------|------|
| `profile` | 角色声音描述，用于 TTS 情感控制 |
| `voices.mimo` | MiMo TTS 音色名（必须是中文预置音色：冰糖/茉莉/苏打/白桦） |
| `voices.qwen` | Qwen TTS 音色参数名（如 Ethan、Cherry） |
| `instruct_mimo` | MiMo TTS 风格指令（自然语言描述角色说话风格、情绪、语速） |
| `instruct_qwen` | Qwen TTS 的语气指导 |
| `emotion_rules` | 根据关键词自动判断台词情绪 |
| `emotion_directions` | 不同情绪对应的语气指导 |

## 常见问题

### MiMo TTS 报 "API key not configured"

检查 `akonado/.env` 中的 `MIMO_API_KEY` 是否正确填写。

### Qwen TTS 报 "model not found"

检查 `QWEN_TTS_MODEL_PATH` 路径是否存在，且包含模型文件（`config.json`、`*.safetensors` 等）。

### Qwen TTS 报 "CUDA out of memory"

- 尝试使用 `QWEN_TTS_DTYPE=float16` 减少显存占用
- 或使用 `QWEN_TTS_DEVICE=cpu`（速度会很慢）
- 关闭其他占用显存的程序

### Qwen TTS 报 "No module named 'qwen_tts'"

确保已正确安装 qwen_tts 包：
```bash
pip install qwen-tts
# 或从源码安装
pip install -e /path/to/Qwen3-TTS
```

### 配音文件在哪里

生成的配音文件保存在 `assets/audio/voice/` 目录，文件名为内容哈希（`md5(character + text)[:8].wav`），确保相同台词不会重复生成。

### 如试听效果

生成后可直接用播放器打开 `.wav` 文件试听。如果效果不满意，可以：
1. 修改 `voice_config.json` 中的 `profile` 或 `instruct_qwen` 调整音色
2. 调整 `emotion_directions` 中的语气描述
3. 删除对应的 `.wav` 文件后重新生成：`python -m akonado generate voice --force`
