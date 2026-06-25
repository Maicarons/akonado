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
- 背景图、CG 插画、BGM、音效、UI 资产生成
- CG 插画生成：重要剧情场景的高质量插画（角色+背景合一）
- 配音合成：MiMo TTS（云端）/ Qwen3 TTS（本地 GPU）
- JSON 驱动的资产清单，便于编辑和自动化
- Web GUI 可视化编辑与生成控制
- CLI 批量操作
- 可扩展的 provider 和 skill 系统

## Demo 项目

体验 Akonado 生成的完整视觉小说：

| Demo | 类型 | 章节 | 资产规模 | 链接 |
|------|------|------|----------|------|
| **雨夜重逢** | 短篇 | 1 章 1 幕 | 3 角色 · 3 背景 · 35 配音 | [raininght-akonado-demo](https://github.com/Maicarons/raininght-akonado-demo) |
| **旧日记的秘密** | 中篇 | 3 章 9 幕 | 4 角色 · 9 背景 · 4 CG · 220+ 配音 | [olddiary-akonado-demo](https://github.com/Maicarons/olddiary-akonado-demo) |
| **方舟残响** | 长篇 | 5 章 20 幕 | 4 角色 · 15 背景 · 4 CG · 650+ 配音 | [arkscape-akonado-demo](https://github.com/Maicarons/arkscape-akonado-demo) |

所有 Demo 的资产（剧本、立绘、背景、CG、音乐、配音）均由 Akonado 管线自动生成，未经人工修改。

## 快速开始

### 运行视觉小说（Godot）

> 完整指南、API 参考和进阶教程，请访问 Konado 官方网站：https://godothub.com/oss/konado/en/2.4/

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

# 一键生成全部（从一句话开始）
python -m akonado pipeline "这个故事是关于战争与和平的故事"

# 自定义章节和场景数
python -m akonado pipeline "一个关于奶茶店的故事" --chapters 5 --scenes-per-chapter 4

# 使用 Qwen TTS 引擎
python -m akonado pipeline "科幻冒险故事" --engine qwen

# 指定 Godot 引擎目录
python -m akonado pipeline "故事概要" --godot-dir "C:\path\to\Godot"

# 分步操作
python -m akonado skill run -n generate_script -i "一个关于奶茶店的故事"
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
| `python -m akonado pipeline "<premise>"` | 一键生成全部资产（推荐） |
| `python -m akonado check` | 检查 provider 可用性 |
| `python -m akonado generate <type>` | 生成资产（characters/backgrounds/cgs/bgm/se/voice/ui/dialogue/all） |
| `python -m akonado list [type]` | 查看 manifest 内容 |
| `python -m akonado clean <type>` | 删除生成的文件（支持 all/manifests/scripts/类型名，`--deep` 清理全部） |
| `python -m akonado skill list` | 列出可用 skills |
| `python -m akonado skill run -n <name> -i <input>` | 运行 LLM skill |
| `python -m akonado workflows` | 列出 ComfyUI 工作流 |
| `python -m akonado web` | 启动 Web GUI |

---

## Konado 上游项目

本项目基于 [Konado](https://github.com/godothub/konado) 对话框架。

### Konado Project Team

- [DSOE1024](https://github.com/DSOE1024)
- [putyk](https://github.com/putyk)
- [moluopro](https://github.com/moluopro)
- [ioniccrystal](https://github.com/ioniccrystal)
- [fangchu](https://github.com/fangchudark)

### Contributors

<a href="https://github.com/godothub/konado/graphs/contributors" target="_blank">
  <picture>
	<source media="(prefers-color-scheme: dark)" srcset="https://contrib.rocks/image?repo=godothub/konado&theme=dark" />
	<source media="(prefers-color-scheme: light)" srcset="https://contrib.rocks/image?repo=godothub/konado" />
	<img alt="Contributors" src="https://contrib.rocks/image?repo=godothub/konado" />
  </picture>
</a>

### Pipeline 参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--chapters` | 章节数 | 4 |
| `--scenes-per-chapter` | 每章场景数 | 3 |
| `--engine` | TTS 引擎（mimo/qwen） | mimo |
| `--godot-dir` | Godot 引擎目录 | `G:\SteamLibrary\steamapps\common\Godot Engine` |
| `--force` | 强制重新生成（不跳过已有文件） | false |
| `--temperature` | LLM 温度参数 | 0.7 |

## 文档

- [快速开始](docs/akonado/getting-started.md) — 安装、配置、第一个项目
- [ComfyUI 搭建指南](docs/akonado/comfyui-setup.md) — 图像/音频生成后端
- [TTS 配音搭建指南](docs/akonado/tts-setup.md) — MiMo TTS / Qwen TTS 配置
- [架构设计](docs/akonado/architecture.md)
- [后端 Providers](docs/akonado/providers.md)
- [技能 Skills](docs/akonado/skills.md)
- [资产清单 Manifests](docs/akonado/manifests.md)
- [Web GUI](docs/akonado/web-gui.md)
- [English Documentation](docs/akonado/en/)
- [Konado 框架文档](docs/konado/)

## 依赖项目

- [Konado](https://github.com/DSOE1024/Konado) — Godot 视觉小说对话框架（BSD-3-Clause）

## AI 使用免责声明

本项目使用 AI 技术生成视觉小说资产（包括但不限于文本、图像、音频）。请注意：

- **内容由 AI 生成**：所有通过本工具生成的剧本、角色、背景、音乐等内容均由 AI 模型生成，可能存在不准确、不恰当或不符合预期的内容。
- **人工审核建议**：建议在使用生成内容前进行人工审核和编辑，确保内容符合项目需求和质量标准。
- **版权与许可**：AI 生成内容的版权归属取决于所使用的 AI 服务条款。请在使用前了解相关服务的使用条款。
- **模型限制**：生成质量受所用 AI 模型能力限制，不同模型可能产生不同效果。
- **责任声明**：本工具仅供辅助创作使用，使用者应对最终内容负责。

## 许可证

AGPL-3.0-only

注意：本项目许可证范围仅包含akonado包，其他依赖项目请查看其许可证。使用本项目生成的任何产品不受本项目许可证管辖，但对本项目功能本体使用和编辑等行为受到项目许可证管辖。