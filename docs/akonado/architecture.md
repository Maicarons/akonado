# 架构设计

## 概述

Akonado 采用管线架构：

```
输入（一句话）
    |
    v
[Skill] -- LLM 生成 --> [Manifests（JSON）]
    |
    v
[Generators] 读取 manifests --> [Providers] --> [输出文件]
    |
    v
[Godot + Konado] 加载资产 --> [视觉小说]
```

## 目录结构

```
akonado/                    # Python 包
  config.py                 # 全局配置
  cli.py                    # CLI 入口
  providers/                # 后端抽象层
    base.py                 # 抽象基类
    llm.py                  # OpenAI 兼容 LLM
    image.py                # ComfyUI 图像/音频
    tts_mimo.py             # MiMo TTS（云端）
    tts_qwen.py             # Qwen3 TTS（本地）
  generators/               # 资产生成器
    characters.py           # 角色精灵图
    backgrounds.py          # 背景图片
    bgm.py                  # 背景音乐
    se.py                   # 音效
    voice.py                # 配音合成
    ui.py                   # UI 资产
    dialogue.py             # 台词提取器
  skills/                   # LLM prompt 模板
  manifests/                # 资产定义（JSON）
  comfyui/                  # ComfyUI 工作流
  web/                      # Flask Web GUI

assets/                     # 生成输出（Godot 项目根目录）
  characters/               # 角色精灵图（PNG）
  backgrounds/              # 背景图片（PNG）
  audio/bgm/                # 背景音乐（MP3）
  audio/se/                 # 音效（MP3）
  audio/voice/              # 配音文件（WAV）

story/                      # Konado .ks 脚本
ui/                         # UI 资产
```

## 设计原则

1. **后端抽象**：所有后端实现公共接口
2. **JSON 驱动**：所有数据通过 JSON manifests 流转
3. **技能驱动**：LLM prompt 基于模板，可版本控制
4. **增量生成**：默认跳过已存在的文件
5. **解耦**：Python 管线与 Godot 项目相互独立
