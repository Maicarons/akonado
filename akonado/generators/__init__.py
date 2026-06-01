"""akonado generators — asset generation pipeline.

Each generator reads from a JSON manifest and produces output files.
All generators accept provider instances for backend abstraction.
"""

from .characters import generate_characters
from .backgrounds import generate_backgrounds
from .bgm import generate_bgm
from .se import generate_se
from .voice import generate_voice_all, extract_voice, generate_voice_audio, insert_voice_labels
from .ui import generate_ui
from .dialogue import generate_dialogue
from .godot_resources import (
    generate_characters_tres,
    generate_backgrounds_tres,
    generate_bgm_tres,
    generate_se_tres,
    generate_voice_tres,
    generate_all_tres,
)

__all__ = [
    "generate_characters",
    "generate_backgrounds",
    "generate_bgm",
    "generate_se",
    "generate_voice_all",
    "extract_voice",
    "generate_voice_audio",
    "insert_voice_labels",
    "generate_ui",
    "generate_dialogue",
    "generate_characters_tres",
    "generate_backgrounds_tres",
    "generate_bgm_tres",
    "generate_se_tres",
    "generate_voice_tres",
    "generate_all_tres",
]
