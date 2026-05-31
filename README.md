# Akonado

[English](README.en.md)

基于 Godot + Konado 的全流程 AI 视觉小说生成管线。

<div align="center">
  <img src="https://img.shields.io/badge/Godot-4.6+-blue.svg?style=flat-square&logo=godotengine&logoSize=14" alt="Godot" height="20">
  <img src="https://img.shields.io/badge/Python-3.10+-green.svg?style=flat-square&logo=python&logoSize=14" alt="Python" height="20">
  <img src="https://img.shields.io/badge/License-AGPL_3.0-purple.svg?style=flat-square&logoSize=14" alt="License" height="20">
</div>

<br>

## 简介

Akonado 是一个 AI 驱动的视觉小说资产生成管线。从一句话概要出发，自动生成完整剧本、角色立绘、背景图、BGM、音效、配音和 UI 资产，配合 Godot 引擎和 Konado 插件直接运行视觉小说。

**核心能力：**

- 一句话 → 完整剧本 + 角色 + 场景设定
- 角色立绘生成（ComfyUI，自动去背景）
- 背景图、BGM、音效、UI 资产生成
- 配音合成：MiMo TTS（云端）/ Qwen3 TTS（本地 GPU）
- JSON 驱动的资产清单，便于编辑和自动化
- Web GUI 可视化编辑与生成控制
- CLI 批量操作
- 可扩展的 provider 和 skill 系统

## 快速开始

### 运行视觉小说（Godot）

1. 克隆本仓库
2. 用 Godot 4.6+ 打开项目
3. 使用 Akonado 生成资产后即可运行

### 生成资产（Python）

```bash
# 安装
cd akonado
pip install -e .

# 配置 API 密钥
cp .env.example .env
# 编辑 .env 填入你的密钥

# 检查 provider 可用性
python -m akonado check

# 从一句话生成剧本
python -m akonado skill run -n generate_script -i "一个关于奶茶店的故事"

# 生成所有资产
python -m akonado generate all

# 启动 Web GUI
python -m akonado web
```

## 项目结构

```
akonado/                  # 本项目根目录（Godot 项目）
  addons/konado/          # Konado 插件（上游视觉小说框架）
  assets/                 # 游戏资产（由 AI 生成）
  story/                  # .ks 脚本（由 AI 生成）
  docs/
    konado/               # Konado 框架文档
    akonado/              # Akonado AI 管线文档
  akonado/                # AI 资产生成管线（Python 包）
    providers/            # 后端抽象层（LLM、Image、TTS）
    generators/           # 资产生成器
    skills/               # LLM prompt 模板（JSON）
    manifests/            # 资产清单定义（JSON）
    web/                  # Flask Web GUI
    comfyui/              # ComfyUI 工作流模板
```

## 命令一览

| 命令 | 说明 |
|------|------|
| `python -m akonado check` | 检查 provider 可用性 |
| `python -m akonado generate <type>` | 生成资产（characters/backgrounds/bgm/se/voice/ui/dialogue/all） |
| `python -m akonado list [type]` | 查看 manifest 内容 |
| `python -m akonado clean <type>` | 删除生成的文件 |
| `python -m akonado skill list` | 列出可用 skills |
| `python -m akonado skill run -n <name> -i <input>` | 运行 LLM skill |
| `python -m akonado web` | 启动 Web GUI |

## 文档

- [快速开始](docs/akonado/getting-started.md)
- [架构设计](docs/akonado/architecture.md)
- [后端 Providers](docs/akonado/providers.md)
- [技能 Skills](docs/akonado/skills.md)
- [资产清单 Manifests](docs/akonado/manifests.md)
- [Web GUI](docs/akonado/web-gui.md)
- [Konado 框架文档](docs/konado/)

## 依赖项目

- [Konado](https://github.com/DSOE1024/Konado) — Godot 视觉小说对话框架（BSD-3-Clause）

## 许可证

AGPL-3.0-only
