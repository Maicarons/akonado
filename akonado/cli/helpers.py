"""CLI utility helpers."""

from __future__ import annotations

import json
import sys

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


def strip_markdown_code_blocks(text: str) -> str:
    """Strip markdown code block markers from LLM output."""
    import re

    text = text.strip()
    if text.startswith("```"):
        first_newline = text.find("\n")
        if first_newline != -1:
            text = text[first_newline + 1 :]
    if text.endswith("```"):
        text = text[:-3]
    text = text.strip()
    if not text.startswith("{"):
        match = re.search(r"\{.*\}", text, re.DOTALL)
        if match:
            text = match.group()
    return text


def get_providers(engine: str = "mimo"):
    """Instantiate providers based on configuration."""
    from ..providers import ComfyUIImageProvider, MiMoTTS, OpenAICompatibleLLM, QwenTTS

    image = ComfyUIImageProvider()
    llm = OpenAICompatibleLLM()

    if engine == "qwen":
        tts = QwenTTS()
    else:
        tts = MiMoTTS()

    return image, tts, llm


def run_skill(llm, skill_name: str, template_vars: dict, temperature: float = 0.7) -> str:
    """Run a skill and return the LLM output."""
    from ..skills import load_skill, render_user_prompt

    skill = load_skill(skill_name)
    system = skill["system_prompt"]
    user = render_user_prompt(skill, **template_vars)
    print(f"  [skill] Running '{skill_name}' ({len(system)} + {len(user)} chars)...")
    result = llm.generate(system, user, temperature=temperature)
    return strip_markdown_code_blocks(result)


def save_json(path, data) -> None:
    """Save data as JSON file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"  [saved] {path}")


def load_json(path) -> dict:
    """Load JSON file."""
    with open(path, encoding="utf-8") as f:
        return json.load(f, strict=False)


def check_and_fill_missing(type_filter: str, generators: dict) -> None:
    """Check manifests vs actual files, report missing, and regenerate."""
    missing: dict[str, list[str]] = {}

    def _check_characters():
        path = MANIFESTS_DIR / "characters.json"
        if not path.exists():
            return
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        items = data.get("items", data.get("characters", {}))
        for char_id, cfg in items.items():
            for expr_name in cfg.get("expressions", {}):
                if not (CHARACTERS_DIR / char_id / f"{expr_name}.png").exists():
                    missing.setdefault("characters", []).append(f"{char_id}/{expr_name}.png")

    def _check_backgrounds():
        path = MANIFESTS_DIR / "backgrounds.json"
        if not path.exists():
            return
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        items = data.get("items", data.get("backgrounds", {}))
        for bg_id in items:
            if not (BACKGROUNDS_DIR / f"{bg_id}.png").exists():
                missing.setdefault("backgrounds", []).append(f"{bg_id}.png")

    def _check_cgs():
        path = MANIFESTS_DIR / "cgs.json"
        if not path.exists():
            return
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        items = data.get("items", {})
        for cg_id in items:
            if not (CGS_DIR / f"{cg_id}.png").exists():
                missing.setdefault("cgs", []).append(f"{cg_id}.png")

    def _check_bgm():
        path = MANIFESTS_DIR / "bgm.json"
        if not path.exists():
            return
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        items = data.get("items", {})
        for item_id in items:
            if not (BGM_DIR / f"{item_id}.mp3").exists():
                missing.setdefault("bgm", []).append(f"{item_id}.mp3")

    def _check_se():
        path = MANIFESTS_DIR / "se.json"
        if not path.exists():
            return
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        items = data.get("items", {})
        for item_id in items:
            if not (SE_DIR / f"{item_id}.mp3").exists():
                missing.setdefault("se", []).append(f"{item_id}.mp3")

    def _check_ui():
        path = MANIFESTS_DIR / "ui.json"
        if not path.exists():
            return
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        items = data.get("items", {})
        for item_id in items:
            if not (UI_DIR / f"{item_id}.png").exists():
                missing.setdefault("ui", []).append(f"{item_id}.png")

    def _check_voice():
        path = MANIFESTS_DIR / "voice_config.json"
        if not path.exists():
            return
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        lines = data.get("lines", [])
        for entry in lines:
            char = entry.get("character", "")
            idx = entry.get("index", 0)
            if not (VOICE_DIR / char / f"{idx:04d}.mp3").exists():
                missing.setdefault("voice", []).append(f"{char}/{idx:04d}.mp3")

    def _check_dialogue():
        path = MANIFESTS_DIR / "script.json"
        if not path.exists():
            return
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        for chapter in data.get("chapters", []):
            for scene in chapter.get("scenes", []):
                ks_path = STORY_DIR / chapter["id"] / f"{scene['id']}.ks"
                if not ks_path.exists():
                    missing.setdefault("dialogue", []).append(f"{chapter['id']}/{scene['id']}.ks")

    checkers = {
        "characters": _check_characters,
        "backgrounds": _check_backgrounds,
        "cgs": _check_cgs,
        "bgm": _check_bgm,
        "se": _check_se,
        "voice": _check_voice,
        "ui": _check_ui,
        "dialogue": _check_dialogue,
    }

    if type_filter == "all":
        for checker in checkers.values():
            checker()
    elif type_filter in checkers:
        checkers[type_filter]()
    else:
        print(f"unknown type: {type_filter}")
        sys.exit(1)

    if not missing:
        print("All assets are present. Nothing to regenerate.")
        return

    print("Missing assets found:")
    total = 0
    for asset_type, files in missing.items():
        print(f"\n  [{asset_type}] {len(files)} missing:")
        for f in files[:10]:
            print(f"    - {f}")
        if len(files) > 10:
            print(f"    ... and {len(files) - 10} more")
        total += len(files)
    print(f"\nTotal: {total} missing assets")

    print("\nRegenerating missing assets...")
    for asset_type in missing:
        if asset_type in generators:
            print(f"\n{'=' * 40}")
            print(f"  regenerating: {asset_type}")
            print(f"{'=' * 40}")
            generators[asset_type]()

    print("\nDone!")
