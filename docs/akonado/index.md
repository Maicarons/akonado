# Akonado 文档

Akonado 是基于 Godot 4.6 + Konado 的全流程 AI 视觉小说生成管线。从一句话概要出发，自动生成剧本、角色立绘、背景图、BGM、音效、配音和 UI 资产，直接在 Godot 中运行。

## 入门

- [快速开始](getting-started.md) — 安装、配置、第一个项目
- [ComfyUI 搭建指南](comfyui-setup.md) — 图像/音频生成后端安装与配置
- [TTS 配音搭建指南](tts-setup.md) — MiMo TTS（云端）/ Qwen TTS（本地）配置

## 架构与设计

- [架构设计](architecture.md) — 管线流程、目录结构、设计原则
- [后端提供者](providers.md) — LLM / Image / TTS Provider 接口与实现
- [技能系统](skills.md) — LLM prompt 模板、内置技能、自定义技能
- [资产清单](manifests.md) — JSON manifest 格式与字段说明

## 工具

- [Web GUI](web-gui.md) — 浏览器可视化管理界面
- [测试报告](test-report.md) — 单元测试覆盖情况

## 外部参考

- [Konado 框架文档](../konado/) — .ks 脚本语法、对话系统 API
