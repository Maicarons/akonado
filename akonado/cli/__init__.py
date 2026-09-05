"""akonado CLI entry point.

Usage:
    python -m akonado <command>
    akonado <command>
"""

from __future__ import annotations

import argparse

from .check import cmd_check
from .clean import cmd_clean
from .generate import cmd_generate
from .list_ import cmd_list
from .pipeline import cmd_pipeline
from .skill import cmd_skill
from .web import cmd_web
from .workflows import cmd_workflows


def main(argv: list[str] | None = None) -> None:
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        prog="akonado",
        description="AI Visual Novel asset generation pipeline (Godot + Konado)",
    )
    sub = parser.add_subparsers(dest="command")

    # generate
    gen_parser = sub.add_parser("generate", aliases=["g"], help="Generate assets")
    gen_parser.add_argument(
        "type",
        help="Asset type: characters/backgrounds/cgs/bgm/se/voice/ui/"
        "dialogue/character_scenes/background_scenes/cg_scenes/tres/all",
    )
    gen_parser.add_argument("--force", "-f", action="store_true", help="Force regeneration")
    gen_parser.add_argument(
        "--engine",
        "-e",
        choices=["mimo", "qwen"],
        help="TTS engine for voice generation (default: mimo)",
    )
    gen_parser.add_argument(
        "--check-missing",
        "-c",
        action="store_true",
        help="Check for missing assets and regenerate them",
    )

    # list
    list_parser = sub.add_parser("list", aliases=["ls"], help="View manifests")
    list_parser.add_argument("type", nargs="?", help="Asset type (omit for all)")

    # clean
    clean_parser = sub.add_parser("clean", help="Remove generated files")
    clean_parser.add_argument(
        "type",
        help="Type to clean: characters/backgrounds/cgs/bgm/se/voice/ui/all/manifests/scripts",
    )
    clean_parser.add_argument(
        "--deep",
        "-d",
        action="store_true",
        help="With 'all': also remove manifests and scripts",
    )

    # check
    sub.add_parser("check", help="Check provider availability")

    # workflows
    sub.add_parser("workflows", aliases=["wf"], help="List discovered ComfyUI workflows")

    # skill
    skill_parser = sub.add_parser("skill", help="Run LLM skill (prompt template)")
    skill_parser.add_argument("action", choices=["list", "run"], help="List or run skills")
    skill_parser.add_argument("--name", "-n", help="Skill name to run")
    skill_parser.add_argument("--input", "-i", help="Input text (one-sentence premise)")
    skill_parser.add_argument("--var", action="append", help="Template variable (key=value)")
    skill_parser.add_argument("--output", "-o", help="Save output to file")
    skill_parser.add_argument("--temperature", "-t", type=float, help="LLM temperature")

    # pipeline
    pipe_parser = sub.add_parser(
        "pipeline", aliases=["p"], help="Full pipeline: premise -> all assets"
    )
    pipe_parser.add_argument("premise", help="One-sentence story premise")
    pipe_parser.add_argument("--force", "-f", action="store_true", help="Force regeneration")
    pipe_parser.add_argument(
        "--prompts-only",
        action="store_true",
        help="Only generate script and manifest prompts, skip asset generation",
    )
    pipe_parser.add_argument(
        "--scripts-only",
        action="store_true",
        help="Generate manifests + .ks scripts, skip visual/audio asset generation",
    )
    pipe_parser.add_argument(
        "--temperature",
        "-t",
        type=float,
        help="LLM temperature (default: 0.7)",
    )
    pipe_parser.add_argument(
        "--chapters",
        type=int,
        default=4,
        help="Number of chapters (default: 4)",
    )
    pipe_parser.add_argument(
        "--scenes-per-chapter",
        type=int,
        default=3,
        help="Scenes per chapter (default: 3)",
    )
    pipe_parser.add_argument("--godot-dir", type=str, help="Godot engine directory")
    pipe_parser.add_argument(
        "--engine", "-e", choices=["mimo", "qwen"], help="TTS engine (default: mimo)"
    )

    # web
    web_parser = sub.add_parser("web", help="Launch web GUI")
    web_parser.add_argument("--host", help="Host (default: 127.0.0.1)")
    web_parser.add_argument("--port", type=int, help="Port (default: 5000)")
    web_parser.add_argument("--debug", action="store_true", help="Enable debug mode")

    args = parser.parse_args(argv)

    if args.command in ("generate", "g"):
        fn = cmd_generate
    elif args.command in ("list", "ls"):
        fn = cmd_list
    elif args.command == "clean":
        fn = cmd_clean
    elif args.command == "check":
        fn = cmd_check
    elif args.command == "skill":
        fn = cmd_skill
    elif args.command in ("pipeline", "p"):
        fn = cmd_pipeline
    elif args.command in ("workflows", "wf"):
        fn = cmd_workflows
    elif args.command == "web":
        fn = cmd_web
    else:
        parser.print_help()
        return

    fn(args)


__all__ = [
    "main",
    "cmd_check",
    "cmd_clean",
    "cmd_generate",
    "cmd_list",
    "cmd_pipeline",
    "cmd_skill",
    "cmd_web",
    "cmd_workflows",
]
