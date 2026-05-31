# 快速开始

## 环境要求

- Python 3.10+
- Godot 4.6+（运行视觉小说）
- ComfyUI（图像/音频生成，可选）
- CUDA GPU（Qwen3 TTS 本地推理，可选）

## 安装

```bash
cd akonado
pip install -e .
```

## 配置

```bash
cp .env.example .env
```

编辑 `.env` 填入你的 API 密钥：

```env
# LLM（剧本生成必需）
LLM_API_KEY=your-api-key
LLM_BASE_URL=https://api.xiaomimimo.com/v1
LLM_MODEL=mimo-v2.5-pro

# MiMo TTS（配音生成必需）
MIMO_API_KEY=your-api-key
MIMO_BASE_URL=https://api.xiaomimimo.com/v1
MIMO_TTS_MODEL=mimo-v2.5-tts

# ComfyUI（图像/音频生成必需）
COMFYUI_URL=http://127.0.0.1:8188
```

## 验证安装

```bash
python -m akonado check
```

## 生成视觉小说

### 第一步：生成剧本

```bash
python -m akonado skill run -n generate_script \
  -i "一个关于奶茶店的故事，主角面临传统与现代的选择" \
  -o akonado/output/script.json
```

### 第二步：生成角色立绘 prompt

```bash
python -m akonado skill run -n generate_character_prompts \
  -i "$(cat akonado/output/script.json)" \
  -o akonado/manifests/characters.json
```

### 第三步：生成所有资产

```bash
python -m akonado generate all
```

### 第四步：使用 Web GUI（替代方案）

```bash
python -m akonado web
```

在浏览器打开 http://127.0.0.1:5000 。
