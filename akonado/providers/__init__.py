"""akonado providers — backend abstraction for generation services.

Usage:
    from akonado.providers import OpenAICompatibleLLM, ComfyUIClient, MiMoTTS

    llm = OpenAICompatibleLLM()
    if llm.available():
        result = llm.generate("You are a writer.", "Write a scene about...")
"""

from .base import LLMProvider, ImageProvider, TTSProvider
from .llm import OpenAICompatibleLLM
from .comfyui import ComfyUIClient, WorkflowTemplate
from .tts_mimo import MiMoTTS
from .tts_qwen import QwenTTS

# Backward-compatible alias
ComfyUIImageProvider = ComfyUIClient

__all__ = [
    # Base classes
    "LLMProvider",
    "ImageProvider",
    "TTSProvider",
    # Concrete providers
    "OpenAICompatibleLLM",
    "ComfyUIClient",
    "ComfyUIImageProvider",  # backward compat alias
    "WorkflowTemplate",
    "MiMoTTS",
    "QwenTTS",
]
