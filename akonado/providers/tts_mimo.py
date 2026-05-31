"""MiMo V2.5 TTS provider (Xiaomi Cloud, OpenAI-compatible API).

All character profiles, emotion rules, and voice mappings are loaded from
manifests/voice_config.json — no game-specific data in this file.

Configure via environment variables: MIMO_API_KEY, MIMO_BASE_URL, MIMO_TTS_MODEL
"""

from __future__ import annotations

import base64
import json
from pathlib import Path

from ..config import MIMO_API_KEY, MIMO_BASE_URL, MIMO_TTS_MODEL, MANIFESTS_DIR
from .base import TTSProvider


def _load_voice_config() -> dict:
    """Load voice configuration from manifest."""
    path = MANIFESTS_DIR / "voice_config.json"
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _analyze_emotion(voice_config: dict, character: str, text: str) -> str:
    """Analyze dialogue emotion using rules from manifest."""
    characters = voice_config.get("characters", {})
    char_cfg = characters.get(character, {})
    profile = char_cfg.get("profile", f"你是{character}。")

    emotion = "平静"
    for rule in voice_config.get("emotion_rules", []):
        label = rule["label"]
        keywords = rule["keywords"]
        if any(kw in text for kw in keywords):
            emotion = label
            break

    directions = voice_config.get("emotion_directions", {})
    direction = directions.get(emotion, "用自然平和的语气说这句台词。")

    for punct, boost in voice_config.get("punctuation_boost", {}).items():
        if punct in text:
            direction = direction.rstrip("。") + boost
            break

    return f"{profile}\n{direction}"


class MiMoTTS(TTSProvider):
    """MiMo V2.5 TTS via Xiaomi Cloud (OpenAI-compatible API)."""

    name = "mimo"

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
    ):
        self._api_key = api_key or MIMO_API_KEY
        self._base_url = base_url or MIMO_BASE_URL
        self._model = model or MIMO_TTS_MODEL
        self._voice_config: dict | None = None

    def _get_voice_config(self) -> dict:
        if self._voice_config is None:
            self._voice_config = _load_voice_config()
        return self._voice_config

    def available(self) -> bool:
        return bool(self._api_key)

    def synthesize(self, text: str, character: str, save_path: Path) -> bool:
        if not self.available():
            print("  error: MIMO_API_KEY not configured")
            return False

        try:
            from openai import OpenAI
        except ImportError:
            print("  error: pip install openai")
            return False

        voice_config = self._get_voice_config()
        characters = voice_config.get("characters", {})
        char_cfg = characters.get(character)
        if not char_cfg:
            print(f"  error: character '{character}' not in voice_config.json")
            return False
        voice = char_cfg.get("voices", {}).get("mimo", "")
        if not voice:
            print(f"  error: no mimo voice for character '{character}'")
            return False
        style = _analyze_emotion(voice_config, character, text)

        client = OpenAI(api_key=self._api_key, base_url=self._base_url)
        try:
            completion = client.chat.completions.create(
                model=self._model,
                messages=[
                    {"role": "user", "content": style},
                    {"role": "assistant", "content": text},
                ],
                audio={"format": "wav", "voice": voice},
            )
            audio_bytes = base64.b64decode(completion.choices[0].message.audio.data)
            save_path.parent.mkdir(parents=True, exist_ok=True)
            with open(save_path, "wb") as f:
                f.write(audio_bytes)
            return True
        except Exception as e:
            print(f"  MiMo TTS error: {e}")
            return False
