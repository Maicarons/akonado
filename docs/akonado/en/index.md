# Akonado Documentation

Akonado is an AI-powered visual novel asset generation pipeline built on Godot 4.7 + Konado 2.5. From a one-sentence premise, it automatically generates scripts, character sprites, backgrounds, BGM, sound effects, voice acting, and UI assets that run directly in Godot.

## Getting Started

- [Environment Setup Guide](getting-started.md) -- Full environment setup from scratch: Python, LLM API, ComfyUI, TTS, Godot
- [ComfyUI Setup Guide](comfyui-setup.md) -- Image/audio generation backend setup (detailed)
- [TTS Setup Guide](tts-setup.md) -- MiMo TTS (cloud) / Qwen TTS (local) configuration (detailed)

## Architecture & Design

- [Architecture](architecture.md) -- Pipeline flow, directory structure, design principles
- [Providers](providers.md) -- LLM / Image / TTS provider interfaces and implementations
- [Skills](skills.md) -- LLM prompt templates, built-in skills, custom skills
- [Manifests](manifests.md) -- JSON manifest format and field reference

## Tools

- [Web GUI](web-gui.md) -- Browser-based visual management interface
- [Test Report](test-report.md) -- Unit test coverage

## External References

- [Konado Framework Docs](../konado/) -- .ks script syntax, dialogue system API
