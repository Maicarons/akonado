"""Godot .tres resource generators for Konado 2.8+.

Generates Konado 2.8-compatible .tres files from manifests and generated assets.
"""

from .audio import generate_bgm_tres, generate_se_tres, generate_voice_tres
from .backgrounds import generate_backgrounds_tres
from .characters import generate_characters_tres

__all__ = [
    "generate_characters_tres",
    "generate_backgrounds_tres",
    "generate_bgm_tres",
    "generate_se_tres",
    "generate_voice_tres",
    "generate_all_tres",
]


def generate_all_tres() -> None:
    """Generate all .tres resource files."""
    print("[godot_resources] Generating .tres files...")
    generate_characters_tres()
    generate_backgrounds_tres()
    generate_bgm_tres()
    generate_se_tres()
    generate_voice_tres()
    print("[godot_resources] done")
