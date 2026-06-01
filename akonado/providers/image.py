"""ComfyUI image/audio generation provider (legacy shim).

This module re-exports ComfyUIClient as ComfyUIImageProvider for backward
compatibility. New code should import from akonado.providers.comfyui directly.
"""

from .comfyui import ComfyUIClient as ComfyUIImageProvider

__all__ = ["ComfyUIImageProvider"]
