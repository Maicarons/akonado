"""Generate assets command."""

from __future__ import annotations

import argparse
import sys


def cmd_generate(args: argparse.Namespace) -> None:
    """Generate assets."""
    from ..config import ensure_dirs
    from ..generators import (
        generate_all_tres,
        generate_background_scenes,
        generate_backgrounds,
        generate_bgm,
        generate_cg_scenes,
        generate_cgs,
        generate_character_scenes,
        generate_characters,
        generate_dialogue,
        generate_se,
        generate_ui,
        generate_voice_all,
    )
    from .helpers import check_and_fill_missing, get_providers

    ensure_dirs()
    skip = not args.force
    engine = args.engine or "mimo"
    image, tts, _llm = get_providers(engine)

    generators = {
        "characters": lambda: generate_characters(image, skip_existing=skip),
        "backgrounds": lambda: generate_backgrounds(image, skip_existing=skip),
        "cgs": lambda: generate_cgs(image, skip_existing=skip),
        "bgm": lambda: generate_bgm(image, skip_existing=skip),
        "se": lambda: generate_se(image, skip_existing=skip),
        "voice": lambda: generate_voice_all(tts, skip_existing=skip),
        "ui": lambda: generate_ui(image, skip_existing=skip),
        "dialogue": lambda: generate_dialogue(),
        "character_scenes": lambda: generate_character_scenes(skip_existing=skip),
        "background_scenes": lambda: generate_background_scenes(skip_existing=skip),
        "cg_scenes": lambda: generate_cg_scenes(skip_existing=skip),
        "tres": lambda: generate_all_tres(),
    }

    if getattr(args, "check_missing", False):
        check_and_fill_missing(args.type, generators)
        return

    if args.type == "all":
        for name, fn in generators.items():
            print(f"\n{'=' * 40}")
            print(f"  generating: {name}")
            print(f"{'=' * 40}")
            fn()
    elif args.type in generators:
        generators[args.type]()
    else:
        print(f"unknown type: {args.type}")
        print(f"available: {', '.join(generators)}, all")
        sys.exit(1)
