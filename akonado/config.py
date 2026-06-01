"""akonado global configuration.

All settings load from environment variables (via .env file) with sensible defaults.
Copy .env.example to .env and fill in your API keys.
"""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

# Load .env from akonado folder
_AKONADO_ROOT = Path(__file__).resolve().parent
_PROJECT_ROOT = _AKONADO_ROOT.parent
load_dotenv(_AKONADO_ROOT / ".env")

# ── Paths ─────────────────────────────────────────────────────
AKONADO_ROOT = _AKONADO_ROOT
PROJECT_ROOT = _PROJECT_ROOT
ASSETS_DIR = PROJECT_ROOT / "assets"
CHARACTERS_DIR = ASSETS_DIR / "characters"
BACKGROUNDS_DIR = ASSETS_DIR / "backgrounds"
AUDIO_DIR = ASSETS_DIR / "audio"
BGM_DIR = AUDIO_DIR / "bgm"
SE_DIR = AUDIO_DIR / "se"
VOICE_DIR = AUDIO_DIR / "voice"
UI_DIR = PROJECT_ROOT / "ui"
STORY_DIR = PROJECT_ROOT / "story"
RESOURCES_DIR = PROJECT_ROOT / "resources"
MANIFESTS_DIR = AKONADO_ROOT / "manifests"
SKILLS_DIR = AKONADO_ROOT / "skills"
COMFYUI_DIR = AKONADO_ROOT / "comfyui"
OUTPUT_DIR = AKONADO_ROOT / "output"
ENV_FILE = _AKONADO_ROOT / ".env"

# ── LLM Provider (OpenAI-compatible) ──────────────────────────
LLM_API_KEY = os.getenv("LLM_API_KEY", "")
LLM_BASE_URL = os.getenv("LLM_BASE_URL", "https://api.openai.com/v1")
LLM_MODEL = os.getenv("LLM_MODEL", "gpt-5.5")

# ── MiMo TTS (Xiaomi Cloud) ──────────────────────────────────
MIMO_API_KEY = os.getenv("MIMO_API_KEY", "")
MIMO_BASE_URL = os.getenv("MIMO_BASE_URL", "https://api.xiaomimimo.com/v1")
MIMO_TTS_MODEL = os.getenv("MIMO_TTS_MODEL", "mimo-v2.5-tts")

# ── Qwen3 TTS (Local inference) ───────────────────────────────
QWEN_TTS_MODEL_PATH = os.getenv("QWEN_TTS_MODEL_PATH", "")
QWEN_TTS_DEVICE = os.getenv("QWEN_TTS_DEVICE", "cuda:0")
QWEN_TTS_DTYPE = os.getenv("QWEN_TTS_DTYPE", "bfloat16")

# ── ComfyUI ───────────────────────────────────────────────────
COMFYUI_URL = os.getenv("COMFYUI_URL", "http://127.0.0.1:8188")

# ── Godot Engine ──────────────────────────────────────────────
GODOT_DIR = Path(os.getenv(
    "GODOT_DIR",
    r"G:\SteamLibrary\steamapps\common\Godot Engine",
))

# ── Web GUI ───────────────────────────────────────────────────
WEB_HOST = os.getenv("WEB_HOST", "127.0.0.1")
WEB_PORT = int(os.getenv("WEB_PORT", "5000"))
WEB_DEBUG = os.getenv("WEB_DEBUG", "false").lower() == "true"

# ── Voice Characters (lazy-loaded from manifest) ──────────────
def get_voice_characters() -> dict[str, dict]:
    """Load character voice config from manifests/voice_config.json."""
    import json

    path = MANIFESTS_DIR / "voice_config.json"
    if not path.exists():
        return {}
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return data.get("characters", {})


def get_voice_character_names() -> set[str]:
    """Get set of character names that have voice config."""
    return set(get_voice_characters().keys())


def ensure_dirs() -> None:
    """Create all required directories if they don't exist."""
    for d in [
        CHARACTERS_DIR, BACKGROUNDS_DIR, BGM_DIR, SE_DIR,
        VOICE_DIR, UI_DIR, STORY_DIR, RESOURCES_DIR,
        OUTPUT_DIR, COMFYUI_DIR,
    ]:
        d.mkdir(parents=True, exist_ok=True)
