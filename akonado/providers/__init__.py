"""akonado providers — backend abstraction for generation services.

Usage:
    from akonado.providers import OpenAICompatibleLLM, ComfyUIImageProvider, MiMoTTS

    llm = OpenAICompatibleLLM()
    if llm.available():
        result = llm.generate("You are a writer.", "Write a scene about...")
"""

from .base import LLMProvider, ImageProvider, TTSProvider
from .llm import OpenAICompatibleLLM
from .image import ComfyUIImageProvider
from .tts_mimo import MiMoTTS
from .tts_qwen import QwenTTS

__all__ = [
    # Base classes
    "LLMProvider",
    "ImageProvider",
    "TTSProvider",
    # Concrete providers
    "OpenAICompatibleLLM",
    "ComfyUIImageProvider",
    "MiMoTTS",
    "QwenTTS",
]
