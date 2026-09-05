"""Clean generated assets command."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def cmd_clean(args: argparse.Namespace) -> None:
    """Remove generated files for a type or all types."""
    from ..config import (
        BACKGROUNDS_DIR,
        BGM_DIR,
        CGS_DIR,
        CHARACTERS_DIR,
        MANIFESTS_DIR,
        SE_DIR,
        STORY_DIR,
        UI_DIR,
        VOICE_DIR,
    )

    asset_map = {
        "characters": CHARACTERS_DIR,
        "backgrounds": BACKGROUNDS_DIR,
        "cgs": CGS_DIR,
        "bgm": BGM_DIR,
        "se": SE_DIR,
        "voice": VOICE_DIR,
        "ui": UI_DIR,
    }

    def _clean_dir(target_dir: Path, label: str) -> int:
        if not target_dir.exists():
            return 0
        count = 0
        for f in target_dir.iterdir():
            if f.is_file():
                f.unlink()
                count += 1
        if count:
            print(f"  [{label}] cleaned {count} files from {target_dir}")
        return count

    target = args.type

    if target == "all":
        total = 0
        for label, d in asset_map.items():
            total += _clean_dir(d, label)
        if args.deep:
            total += _clean_dir(MANIFESTS_DIR, "manifests")
            total += _clean_dir(STORY_DIR, "scripts")
        print(f"\n[all] cleaned {total} files total")
        return

    if target == "manifests":
        _clean_dir(MANIFESTS_DIR, "manifests")
        return

    if target == "scripts":
        _clean_dir(STORY_DIR, "scripts")
        return

    if target in asset_map:
        _clean_dir(asset_map[target], target)
        return

    print(f"unknown type: {target}")
    print(f"available: {', '.join(asset_map)}, all, manifests, scripts")
    sys.exit(1)
