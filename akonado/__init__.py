"""akonado — AI Visual Novel asset generation pipeline.

Full-stack asset generator for visual novels built on Godot + Konado.
Supports 7 asset types: characters, backgrounds, bgm, se, voice, ui, dialogue

Usage:
    python -m akonado <command>

Commands:
    generate <type>   Generate assets (characters/backgrounds/bgm/se/voice/ui/dialogue/all)
    list [type]       View manifest contents
    clean <type>      Remove generated files for a type
    check             Check provider availability
    skill             Run LLM skill (prompt template)
    web               Launch web GUI
"""

__version__ = "0.1.0"
