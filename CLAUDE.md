# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Akonado is an AI-powered visual novel asset generation pipeline built on Godot 4.6 + Konado. From a one-sentence premise, it generates complete scripts, character sprites, backgrounds, BGM, sound effects, voice acting, and UI assets. The generated output runs directly in Godot using the Konado dialogue framework.

The project has two layers:
- **Python package** (`akonado/`) — CLI + Web GUI for AI asset generation (the main codebase you'll work on)
- **Godot project** (root) — runs the generated visual novel using `addons/konado/` as a dependency

## Python Package (`akonado/`)

### Setup
```bash
cd akonado
pip install -e .          # install in editable mode
cp .env.example .env      # configure API keys
python -m akonado check   # verify providers
```

### CLI Commands
```bash
python -m akonado skill run -n generate_script -i "故事概要"   # generate script from premise
python -m akonado generate all                                 # generate all assets
python -m akonado generate characters                          # generate specific type
python -m akonado generate voice --engine qwen                 # use local Qwen TTS
python -m akonado list [type]                                  # view manifest contents
python -m akonado clean <type>                                 # remove generated files
python -m akonado skill list                                   # list available LLM skills
python -m akonado web                                          # launch Web GUI (Flask)
```

### Convenience Scripts
Platform-specific wrappers in `scripts/Windows/`, `scripts/Linux/`, `scripts/macOS/`:
```bash
scripts/Windows/pipeline.cmd "故事概要"   # full pipeline: premise -> script -> all assets
scripts/Windows/generate.cmd              # generate all assets
scripts/Windows/web.cmd                   # launch web GUI
scripts/Windows/godot.cmd                 # open Godot editor
```

### Architecture

**Config** (`config.py`): All settings from `.env` via python-dotenv. Defines paths for assets, manifests, skills, and provider credentials (LLM, ComfyUI, TTS).

**Providers** (`providers/`): Abstract base classes in `base.py`, concrete implementations:
- `llm.py` — OpenAI-compatible LLM (any provider with OpenAI API format)
- `image.py` — ComfyUI image/audio generation
- `tts_mimo.py` — MiMo TTS (Xiaomi cloud)
- `tts_qwen.py` — Qwen3 TTS (local GPU)

**Generators** (`generators/`): Asset pipelines that read manifests and call providers:
- `characters.py`, `backgrounds.py`, `cg.py`, `bgm.py`, `se.py`, `voice.py`, `ui.py` — produce files in `assets/`
- `cg.py` — generates CG插画 (high-quality illustrations combining characters + backgrounds into a single image, used for key story moments). CGs are stored in `assets/cgs/` and registered as backgrounds in `backgrounds.tres` so they can be used with the `background` command in .ks scripts.
- `dialogue.py` — extracts `.ks` script lines into `story/`

**Skills** (`skills/`): JSON prompt templates with `system_prompt` + `user_prompt` (supports `{{input}}` placeholders). Run via `skill run -n <name>`.

**Web** (`web/`): Flask app for visual manifest editing and generation control.

### Linting
```bash
ruff check akonado/        # lint
ruff format akonado/       # format
```

Ruff config is in `pyproject.toml`: line-length 100, target Python 3.10, rules E/F/W/I.

### Dependencies
`requests`, `Pillow`, `python-dotenv`, `openai`, `flask`. Dev: `pytest`, `ruff`.

## Godot Project (root)

Open `project.godot` in Godot 4.6+ to run the visual novel. The `addons/konado/` folder is the upstream Konado framework (not akonado code) — do not modify it directly.

Key Konado concepts:
- `.ks` scripts (in `story/`) use a line-oriented DSL: `"character" "text"` for dialogue, `actor show`, `background switch`, `play bgm` for game commands
- `KND_DialogueManager` is the runtime orchestrator
- `KonadoScriptsInterpreter` parses `.ks` into `KND_Shot` node graphs

### Known Pitfalls (踩坑记录)

**1. .ks 脚本必须使用 ASCII 直引号**
Konado 解析器的正则只认 ASCII `"` (0x22)。编辑时如果引入 Unicode 弯引号 `"` `"` (U+201C/U+201D)，解析器会报"无法识别的语法"。Claude Code 的 Edit 工具偶尔会引入弯引号，修改 .ks 文件后务必用 `python3` 检查：
```bash
python3 -c "
with open('story/xxx.ks','rb') as f:
    for i,line in enumerate(f.read().split(b'\n')):
        if b'\xe2\x80\x9c' in line: print(f'Curly quote at line {i}')
"
```

**2. .ks 脚本必须使用 LF 换行符**
混合 CRLF/LF 会导致解析器行号偏移。修改后统一换行符：
```bash
python3 -c "
with open('story/xxx.ks','rb') as f: c=f.read()
with open('story/xxx.ks','wb') as f: f.write(c.replace(b'\r\n',b'\n'))
"
```

**3. branch 内容必须缩进 4 个空格**
`_parse_indented_block()` 通过缩进判断 branch 内容边界。未缩进的行会被当作 branch 外内容，导致解析失败或分支不执行。

**4. main.tscn 必须设置 `init_onstart = false`**
`KND_DialogueManager._ready()` 会在父脚本之前执行。如果 `init_onstart` 为 true，会在 `start_dialogue_shot` 被设置前就初始化，导致"未设置对话镜头"错误。

**5. actor move 不能移动到当前位置**
`character_moved` 信号只在位置实际改变时触发。移动到同一位置会导致信号永不触发，状态机卡死。

**6. actor show 不能在已占用位置**
同一位置出现两个角色会导致重叠。出场前规划好位置分配（0-4）。

**7. MiMo TTS 必须使用中文音色名**
`voice_config.json` 中 `voices.mimo` 必须使用中文预置音色：`冰糖`(女)、`茉莉`(女)、`苏打`(男)、`白桦`(男)。不要用英文音色（Dean、Mia 等是英文音色，不适合中文配音）。

**8. `_autoPlayButton` 必须在模板场景中绑定**
`addons/konado/template/konado_dialogue.tscn` 的 `node_paths` 必须包含 `_autoPlayButton`，否则运行时报"未指定 _autoPlayButton"。

**9. 使用CG前必须先actor exit所有角色**
CG是完整插画（角色+背景在同一张图中），显示CG时如果角色立绘还在屏幕上会导致重叠。正确流程：先 `actor exit` 所有在场角色，再 `background cg_id fade`。CG显示完毕后如需继续对话，可重新 `actor show` 角色。

### GDScript Style (for any Godot-side changes)
- Tabs for indentation, LF line endings, UTF-8
- File names: `snake_case.gd`, classes: `PascalCase`, functions/vars: `snake_case`
- Constants: `CONSTANT_CASE`, signals: past tense `snake_case`

## Commit Convention

Conventional Commits: `<type>(<scope>): <subject>`

Types: `feat`, `fix`, `docs`, `test`, `ci`. Examples:
- `feat(generators): Add character sprite generation`
- `fix(tts): Handle empty text in voice synthesis`
- `docs(readme): Update quick start guide`
