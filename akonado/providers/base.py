"""Provider base classes.

Each provider type (LLM, Image, TTS) defines a common interface so generators
can work with any backend without modification.
"""

from abc import ABC, abstractmethod
from pathlib import Path


class LLMProvider(ABC):
    """Text generation provider (OpenAI-compatible chat API)."""

    @abstractmethod
    def available(self) -> bool:
        """Return True if the provider is configured and ready."""

    @abstractmethod
    def generate(self, system: str, user: str, *, temperature: float = 0.7) -> str:
        """Generate a text response.

        Args:
            system: System prompt.
            user: User message.
            temperature: Sampling temperature.

        Returns:
            Generated text content.
        """


class ImageProvider(ABC):
    """Image generation provider (e.g. ComfyUI)."""

    @abstractmethod
    def available(self) -> bool:
        """Return True if the provider is configured and ready."""

    @abstractmethod
    def generate(
        self,
        prompt: str,
        width: int,
        height: int,
        save_path: Path,
        *,
        seed: int | None = None,
    ) -> None:
        """Generate an image and save to disk.

        Args:
            prompt: Text prompt for image generation.
            width: Image width in pixels.
            height: Image height in pixels.
            save_path: Output file path.
            seed: Optional seed for reproducibility.
        """

    @abstractmethod
    def remove_background(self, input_path: Path, output_path: Path) -> None:
        """Remove background from an image, output transparent PNG.

        Args:
            input_path: Source image path.
            output_path: Destination path (PNG with alpha).
        """

    @abstractmethod
    def generate_audio(
        self,
        prompt: str,
        duration: float,
        save_path: Path,
        *,
        category: str = "Music",
    ) -> None:
        """Generate audio (BGM or SFX) and save to disk.

        Args:
            prompt: Text description of the audio.
            duration: Duration in seconds.
            save_path: Output file path.
            category: Audio category ("Music" or "Sound Effects").
        """


class TTSProvider(ABC):
    """Text-to-speech provider for character voice synthesis."""

    name: str = "base"

    @abstractmethod
    def available(self) -> bool:
        """Return True if the provider is configured and ready."""

    @abstractmethod
    def synthesize(self, text: str, character: str, save_path: Path) -> bool:
        """Synthesize speech for a character line.

        Args:
            text: Dialogue text to speak.
            character: Character name (for voice selection).
            save_path: Output WAV file path.

        Returns:
            True on success, False on failure.
        """
