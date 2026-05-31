"""Qwen3-TTS local inference provider.

Runs Qwen3-TTS CustomVoice model locally via the qwen_tts package.
All character data loaded from manifests/voice_config.json.

Configure via environment variables:
    QWEN_TTS_MODEL_PATH  — path to the model directory
    QWEN_TTS_DEVICE      — device string (default: cuda:0)
    QWEN_TTS_DTYPE       — dtype: bfloat16/float16/float32 (default: bfloat16)
"""

from __future__ import annotations

import json
import os
from pathlib import Path

from ..config import MANIFESTS_DIR
from .base import TTSProvider


def _load_voice_config() -> dict:
    path = MANIFESTS_DIR / "voice_config.json"
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _resolve_dtype(dtype_str: str):
    import torch

    mapping = {
        "bfloat16": torch.bfloat16,
        "bf16": torch.bfloat16,
        "float16": torch.float16,
        "fp16": torch.float16,
        "float32": torch.float32,
        "fp32": torch.float32,
    }
    return mapping.get(dtype_str, torch.bfloat16)


class QwenTTS(TTSProvider):
    """Qwen3-TTS local inference (CustomVoice model)."""

    name = "qwen"

    def __init__(
        self,
        model_path: str | None = None,
        device: str | None = None,
        dtype: str | None = None,
    ):
        self._model_path = model_path or os.getenv("QWEN_TTS_MODEL_PATH", "")
        self._device = device or os.getenv("QWEN_TTS_DEVICE", "cuda:0")
        self._dtype_str = dtype or os.getenv("QWEN_TTS_DTYPE", "bfloat16")
        self._model = None
        self._voice_config: dict | None = None

    def _get_voice_config(self) -> dict:
        if self._voice_config is None:
            self._voice_config = _load_voice_config()
        return self._voice_config

    def available(self) -> bool:
        if not self._model_path:
            return False
        if not Path(self._model_path).is_dir():
            return False
        try:
            import qwen_tts  # noqa: F401
            return True
        except ImportError:
            return False

    def _ensure_model(self):
        if self._model is not None:
            return

        import torch
        from qwen_tts import Qwen3TTSModel

        dtype = _resolve_dtype(self._dtype_str)
        attn_impl = "flash_attention_2" if torch.cuda.is_available() else "eager"

        print(f"  [qwen-tts] loading model from {self._model_path}")
        print(f"  [qwen-tts] device={self._device}, dtype={self._dtype_str}, attn={attn_impl}")

        self._model = Qwen3TTSModel.from_pretrained(
            self._model_path,
            device_map=self._device,
            dtype=dtype,
            attn_implementation=attn_impl,
        )
        print("  [qwen-tts] model loaded")

    def synthesize(self, text: str, character: str, save_path: Path) -> bool:
        if not self.available():
            print("  error: QWEN_TTS_MODEL_PATH not set or model not found")
            return False

        try:
            import soundfile as sf
        except ImportError:
            print("  error: pip install soundfile")
            return False

        self._ensure_model()

        voice_config = self._get_voice_config()
        characters = voice_config.get("characters", {})
        char_cfg = characters.get(character)
        if not char_cfg:
            print(f"  error: character '{character}' not in voice_config.json")
            return False
        speaker = char_cfg.get("voices", {}).get("qwen", "")
        if not speaker:
            print(f"  error: no qwen voice for character '{character}'")
            return False
        instruct = char_cfg.get("instruct_qwen", "")

        try:
            wavs, sr = self._model.generate_custom_voice(
                text=text,
                speaker=speaker,
                language="Chinese",
                instruct=instruct,
            )

            if wavs and len(wavs) > 0:
                save_path.parent.mkdir(parents=True, exist_ok=True)
                sf.write(str(save_path), wavs[0], sr)
                return True

            print("  Qwen TTS: no audio generated")
            return False

        except Exception as e:
            print(f"  Qwen TTS error: {e}")
            return False
