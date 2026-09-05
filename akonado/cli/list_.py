"""List manifest contents command."""

from __future__ import annotations

import argparse
import json


def cmd_list(args: argparse.Namespace) -> None:
    """View manifest contents."""
    from ..config import MANIFESTS_DIR

    if args.type:
        types = [args.type]
    else:
        types = ["characters", "backgrounds", "cgs", "bgm", "se", "voice", "ui", "dialogue"]

    for t in types:
        path = MANIFESTS_DIR / f"{t}.json"
        if not path.exists():
            print(f"[{t}] manifest not found")
            continue

        with open(path, encoding="utf-8") as f:
            data = json.load(f)

        print(f"\n=== {t} ===")
        if t == "characters":
            items = data.get("items", data.get("characters", {}))
            for cid, cfg in items.items():
                exprs = list(cfg["expressions"].keys())
                print(f"  {cid}: {', '.join(exprs)}")
        elif t == "backgrounds":
            items = data.get("items", data.get("backgrounds", {}))
            for bid in items:
                print(f"  {bid}")
        elif t == "cgs":
            items = data.get("items", {})
            for cg_id, cg_cfg in items.items():
                name = cg_cfg.get("name", cg_id) if isinstance(cg_cfg, dict) else cg_id
                scene = cg_cfg.get("scene_ref", "") if isinstance(cg_cfg, dict) else ""
                ref = f" ({scene})" if scene else ""
                print(f"  {cg_id}: {name}{ref}")
        elif t in ("bgm", "se"):
            items = data.get("items", {})
            for item_id in items:
                print(f"  {item_id}")
        elif t == "voice":
            lines = data.get("lines", [])
            print(f"  total: {len(lines)} lines")
            for entry in lines[:5]:
                print(f"    {entry['character']}: {entry['text'][:30]}...")
            if len(lines) > 5:
                print(f"    ... ({len(lines) - 5} more)")
        elif t == "ui":
            for uid in data["items"]:
                print(f"  {uid}")
        elif t == "dialogue":
            lines = data.get("lines", [])
            print(f"  total: {len(lines)} lines")
            chars = set(e["character"] for e in lines)
            print(f"  characters: {', '.join(chars)}")
