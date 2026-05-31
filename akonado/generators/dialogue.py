"""Dialogue extractor.

Parses .ks scripts into manifests/dialogue.json for analysis, translation, and voice planning.
"""

from __future__ import annotations

import json
import re

from ..config import MANIFESTS_DIR, STORY_DIR, get_voice_character_names


def generate_dialogue() -> list[dict]:
    """Extract all dialogue lines from .ks scripts into dialogue.json.

    Returns:
        List of extracted dialogue entries.
    """
    voiced_chars = get_voice_character_names()
    lines = []
    ks_files = sorted(STORY_DIR.rglob("*.ks"))

    if not ks_files:
        print("[dialogue] no .ks scripts found in story/")
        return lines

    for ks_path in ks_files:
        rel_path = str(ks_path.relative_to(STORY_DIR.parent))
        chapter = ks_path.parent.name

        with open(ks_path, encoding="utf-8") as f:
            content = f.read()

        line_no = 0
        for raw_line in content.splitlines():
            line_no += 1
            stripped = raw_line.strip()

            match = re.match(r'^"(\w+)"\s+"([^"]+)"', stripped)
            if not match:
                continue

            character = match.group(1)
            text = match.group(2)

            if "%" in text or "$" in text:
                continue

            is_voiced = character in voiced_chars

            lines.append({
                "file": rel_path,
                "chapter": chapter,
                "line_no": line_no,
                "character": character,
                "text": text,
                "voiced": is_voiced,
            })

    manifest = {
        "type": "dialogue",
        "description": "从 .ks 脚本提取的台词数据，用于配音、翻译、分析等",
        "characters": list(voiced_chars),
        "lines": lines,
    }

    manifest_path = MANIFESTS_DIR / "dialogue.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    print(f"[dialogue] extracted {len(lines)} lines from {len(ks_files)} scripts")
    return lines
