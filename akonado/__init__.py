"""akonado — AI Visual Novel asset generation pipeline.

Full-stack asset generator for visual novels built on Godot + Konado 2.8+.
Supports 10 generator types: characters, backgrounds, cgs, bgm, se, voice, ui,
dialogue, character_scenes, background_scenes, cg_scenes, tres.

Usage:
    python -m akonado <command>

Commands:
    generate <type>   Generate assets (characters/backgrounds/cgs/bgm/se/voice/ui/dialogue/character_scenes/background_scenes/cg_scenes/tres/all)
    list [type]       View manifest contents
    clean <type>      Remove generated files for a type
    check             Check provider availability
    skill             Run LLM skill (prompt template)
    web               Launch Web GUI
"""

__version__ = "2.8.0"
