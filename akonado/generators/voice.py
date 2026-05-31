"""Voice synthesis generator.

Three-step pipeline:
1. extract: Parse .ks scripts -> manifests/voice.json
2. generate: Synthesize voice files via TTSProvider
3. insert: Inject voice labels back into .ks scripts

Voice IDs are content-hash based: md5(character + text)[:8], stable across edits.
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

from ..config import MANIFESTS_DIR, VOICE_DIR, STORY_DIR, get_voice_character_names
from ..providers.base import TTSProvider


def _content_hash(character: str, text: str) -> str:
    """Generate stable hash ID from character + dialogue text."""
    raw = f"{character}{text}".encode("utf-8")
    return hashlib.md5(raw).hexdigest()[:8]


def extract_voice() -> list[dict]:
    """Extract dialogue lines from all .ks scripts into voice.json."""
    voiced_chars = get_voice_character_names()
    lines = []
    ks_files = sorted(STORY_DIR.rglob("*.ks"))

    for ks_path in ks_files:
        with open(ks_path, encoding="utf-8") as f:
            content = f.read()

        for match in re.finditer(r'^\s*"(\w+)"\s+"([^"]+)"', content, re.MULTILINE):
            character = match.group(1)
            text = match.group(2)

            if character not in voiced_chars:
                continue
            if "%" in text or "$" in text:
                continue

            voice_id = _content_hash(character, text)
            lines.append({
                "id": voice_id,
                "file": str(ks_path.relative_to(STORY_DIR.parent)),
                "character": character,
                "text": text,
            })

    manifest = {
        "type": "voice",
        "tts_engine": "mimo",
        "lines": lines,
    }

    manifest_path = MANIFESTS_DIR / "voice.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    print(f"[voice] extracted {len(lines)} lines from {len(ks_files)} scripts")
    return lines


def generate_voice_audio(tts: TTSProvider, *, skip_existing: bool = True) -> None:
    """Generate voice files using the provided TTS provider."""
    manifest_path = MANIFESTS_DIR / "voice.json"
    if not manifest_path.exists():
        print("[voice] manifest not found, run extract first")
        return

    with open(manifest_path, encoding="utf-8") as f:
        data = json.load(f)

    total = len(data["lines"])
    generated = 0
    skipped = 0

    for i, entry in enumerate(data["lines"]):
        voice_id = entry["id"]
        out_path = VOICE_DIR / f"{voice_id}.wav"

        if skip_existing and out_path.exists():
            skipped += 1
            continue

        print(f"[voice] ({i+1}/{total}) {entry['character']}: {entry['text'][:30]}...")
        ok = tts.synthesize(entry["text"], entry["character"], out_path)
        if ok:
            generated += 1
        else:
            print(f"  FAILED: {voice_id}")

    print(f"[voice] generated={generated}, skipped={skipped}, total={total}")


def insert_voice_labels() -> None:
    """Insert voice labels into .ks scripts."""
    manifest_path = MANIFESTS_DIR / "voice.json"
    if not manifest_path.exists():
        print("[voice] manifest not found")
        return

    with open(manifest_path, encoding="utf-8") as f:
        data = json.load(f)

    file_lines: dict[str, list[dict]] = {}
    for entry in data["lines"]:
        fpath = entry["file"]
        file_lines.setdefault(fpath, []).append(entry)

    modified_count = 0

    for rel_path, entries in file_lines.items():
        ks_path = STORY_DIR.parent / rel_path
        if not ks_path.exists():
            print(f"  [warn] file not found: {rel_path}")
            continue

        with open(ks_path, encoding="utf-8") as f:
            content = f.read()

        for entry in entries:
            character = entry["character"]
            text = entry["text"]
            voice_id = entry["id"]

            pattern = rf'^("{re.escape(character)}"\s+"{re.escape(text)}")\s*(\S+)?$'
            match = re.search(pattern, content, re.MULTILINE)

            if match:
                old_line = match.group(0)
                new_line = f'{match.group(1)} {voice_id}'
                if old_line.strip() != new_line.strip():
                    content = content.replace(old_line, new_line)
                    modified_count += 1

        with open(ks_path, "w", encoding="utf-8") as f:
            f.write(content)

    print(f"[voice] labels inserted: {modified_count} lines modified")


def generate_voice_all(tts: TTSProvider, *, skip_existing: bool = True) -> None:
    """Full voice pipeline: extract -> generate -> insert."""
    extract_voice()
    generate_voice_audio(tts, skip_existing=skip_existing)
    insert_voice_labels()
    print("[voice] all done")
