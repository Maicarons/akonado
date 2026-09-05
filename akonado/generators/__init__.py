"""akonado generators — asset generation pipeline.

Each generator reads from a JSON manifest and produces output files.
All generators accept provider instances for backend abstraction.
"""

from .background_scenes import generate_background_scenes, generate_cg_scenes
from .backgrounds import generate_backgrounds
from .bgm import generate_bgm
from .cg import generate_cgs
from .character_scenes import generate_character_scenes
from .characters import generate_characters
from .dialogue import generate_dialogue
from .godot import (
    generate_all_tres,
    generate_backgrounds_tres,
    generate_bgm_tres,
    generate_characters_tres,
    generate_se_tres,
    generate_voice_tres,
)
from .se import generate_se
from .ui import generate_ui
from .voice import extract_voice, generate_voice_all, generate_voice_audio, insert_voice_labels

__all__ = [
    "generate_characters",
    "generate_backgrounds",
    "generate_cgs",
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
    "generate_character_scenes",
    "generate_background_scenes",
    "generate_cg_scenes",
]
