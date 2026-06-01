"""akonado CLI entry point.

Usage:
    python -m akonado <command>
    akonado <command>

Commands:
    generate <type>   Generate assets
    list [type]       View manifest contents
    clean <type>      Remove generated files
    check             Check provider availability
    skill             Run LLM skill (prompt template)
    web               Launch web GUI
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def _strip_markdown_code_blocks(text: str) -> str:
    """Strip markdown code block markers from LLM output."""
    text = text.strip()
    if text.startswith("```"):
        # Remove opening line (```json or similar)
        first_newline = text.find("\n")
        if first_newline != -1:
            text = text[first_newline + 1 :]
    if text.endswith("```"):
        text = text[: -3]
    return text.strip()


def _get_providers(engine: str = "mimo"):
    """Instantiate providers based on configuration."""
    from .providers import ComfyUIImageProvider, MiMoTTS, QwenTTS, OpenAICompatibleLLM

    image = ComfyUIImageProvider()
    llm = OpenAICompatibleLLM()

    if engine == "qwen":
        tts = QwenTTS()
    else:
        tts = MiMoTTS()

    return image, tts, llm


def cmd_check(_args: argparse.Namespace) -> None:
    """Check provider availability."""
    from .providers import ComfyUIClient, MiMoTTS, QwenTTS, OpenAICompatibleLLM

    comfyui = ComfyUIClient()
    providers = [
        ("ComfyUI (Image/Audio)", comfyui),
        ("LLM (OpenAI-compatible)", OpenAICompatibleLLM()),
        ("MiMo TTS", MiMoTTS()),
        ("Qwen TTS", QwenTTS()),
    ]

    all_ok = True
    for name, provider in providers:
        ok = provider.available()
        status = "OK" if ok else "NOT AVAILABLE"
        print(f"  {name}: {status}")
        if not ok:
            all_ok = False

    # Show discovered workflows
    workflows = comfyui.list_workflows()
    if workflows:
        print(f"\nComfyUI workflows ({len(workflows)}):")
        for wf in workflows:
            print(f"  - {wf}")
    else:
        print("\nNo ComfyUI workflows found in comfyui/")

    if all_ok:
        print("\nAll providers are available.")
    else:
        print("\nSome providers are not available. Check your .env configuration.")


def cmd_generate(args: argparse.Namespace) -> None:
    """Generate assets."""
    from .generators import (
        generate_characters,
        generate_backgrounds,
        generate_bgm,
        generate_se,
        generate_voice_all,
        generate_ui,
        generate_dialogue,
    )
    from .config import ensure_dirs

    ensure_dirs()
    skip = not args.force
    engine = args.engine or "mimo"
    image, tts, _llm = _get_providers(engine)

    generators = {
        "characters": lambda: generate_characters(image, skip_existing=skip),
        "backgrounds": lambda: generate_backgrounds(image, skip_existing=skip),
        "bgm": lambda: generate_bgm(image, skip_existing=skip),
        "se": lambda: generate_se(image, skip_existing=skip),
        "voice": lambda: generate_voice_all(tts, skip_existing=skip),
        "ui": lambda: generate_ui(image, skip_existing=skip),
        "dialogue": lambda: generate_dialogue(),
    }

    if args.type == "all":
        for name, fn in generators.items():
            print(f"\n{'='*40}")
            print(f"  generating: {name}")
            print(f"{'='*40}")
            fn()
    elif args.type in generators:
        generators[args.type]()
    else:
        print(f"unknown type: {args.type}")
        print(f"available: {', '.join(generators)}, all")
        sys.exit(1)


def cmd_list(args: argparse.Namespace) -> None:
    """View manifest contents."""
    from .config import MANIFESTS_DIR

    if args.type:
        types = [args.type]
    else:
        types = ["characters", "backgrounds", "bgm", "se", "voice", "ui", "dialogue"]

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


def cmd_skill(args: argparse.Namespace) -> None:
    """Run an LLM skill (prompt template) to generate content."""
    from .skills import list_skills, load_skill, render_user_prompt
    from .providers import OpenAICompatibleLLM

    if args.action == "list":
        skills = list_skills()
        print("\nAvailable skills:")
        for s in skills:
            print(f"  {s['name']}: {s['description']}")
        return

    if args.action == "run":
        if not args.name:
            print("Error: --name is required for 'run' action")
            sys.exit(1)

        try:
            skill = load_skill(args.name)
        except FileNotFoundError as e:
            print(e)
            sys.exit(1)

        llm = OpenAICompatibleLLM()
        if not llm.available():
            print("Error: LLM provider not available. Set LLM_API_KEY in .env")
            sys.exit(1)

        template_vars = {}
        if args.input:
            template_vars["input"] = args.input
        if args.var:
            for v in args.var:
                if "=" in v:
                    k, val = v.split("=", 1)
                    template_vars[k] = val

        system = skill["system_prompt"]
        user = render_user_prompt(skill, **template_vars)

        output_format = skill.get("output_format", "text")
        temperature = args.temperature or 0.7

        print(f"[skill] Running '{args.name}'...")
        print(f"[skill] System prompt: {len(system)} chars")
        print(f"[skill] User prompt: {len(user)} chars")
        print()

        result = llm.generate(system, user, temperature=temperature)

        if args.output:
            out_path = Path(args.output)
            out_path.parent.mkdir(parents=True, exist_ok=True)

            if output_format == "json":
                cleaned = _strip_markdown_code_blocks(result)
                try:
                    parsed = json.loads(cleaned)
                    with open(out_path, "w", encoding="utf-8") as f:
                        json.dump(parsed, f, ensure_ascii=False, indent=2)
                except json.JSONDecodeError:
                    with open(out_path, "w", encoding="utf-8") as f:
                        f.write(result)
            else:
                with open(out_path, "w", encoding="utf-8") as f:
                    f.write(result)

            print(f"\n[skill] Output saved to: {out_path}")
        else:
            print(result)

        return


def cmd_clean(args: argparse.Namespace) -> None:
    """Remove generated files for a type or all types."""
    from .config import (
        CHARACTERS_DIR, BACKGROUNDS_DIR, BGM_DIR, SE_DIR,
        VOICE_DIR, UI_DIR, MANIFESTS_DIR, STORY_DIR,
    )

    asset_map = {
        "characters": CHARACTERS_DIR,
        "backgrounds": BACKGROUNDS_DIR,
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


def _run_skill(llm, skill_name: str, template_vars: dict, temperature: float = 0.7) -> str:
    """Run a skill and return the LLM output."""
    from .skills import load_skill, render_user_prompt

    skill = load_skill(skill_name)
    system = skill["system_prompt"]
    user = render_user_prompt(skill, **template_vars)
    print(f"  [skill] Running '{skill_name}' ({len(system)} + {len(user)} chars)...")
    result = llm.generate(system, user, temperature=temperature)
    return _strip_markdown_code_blocks(result)


def _save_json(path, data) -> None:
    """Save data as JSON file."""
    import json as _json

    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        _json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"  [saved] {path}")


def _load_json(path) -> dict:
    """Load JSON file."""
    import json as _json

    with open(path, encoding="utf-8") as f:
        return _json.load(f)


def cmd_pipeline(args: argparse.Namespace) -> None:
    """Full pipeline: premise -> script -> manifests -> assets -> .ks scripts."""
    import json as _json
    from pathlib import Path

    from .config import (
        ensure_dirs, MANIFESTS_DIR, STORY_DIR, GODOT_DIR, ASSETS_DIR,
    )
    from .providers import OpenAICompatibleLLM

    ensure_dirs()
    llm = OpenAICompatibleLLM()
    if not llm.available():
        print("Error: LLM provider not available. Set LLM_API_KEY in .env")
        return

    premise = args.premise
    temperature = args.temperature or 0.7
    num_chapters = args.chapters
    scenes_per_chapter = args.scenes_per_chapter
    godot_dir = Path(args.godot_dir) if args.godot_dir else GODOT_DIR

    # ── Step 1: Generate script.json ──────────────────────────
    print("\n" + "=" * 50)
    print("  Step 1/8: Generating script from premise")
    print("=" * 50)
    script_result = _run_skill(
        llm, "generate_script",
        {"input": premise, "num_chapters": str(num_chapters), "scenes_per_chapter": str(scenes_per_chapter)},
        temperature,
    )
    try:
        script_data = _json.loads(script_result)
    except _json.JSONDecodeError:
        print("Error: Failed to parse script JSON from LLM output")
        print(script_result[:500])
        return
    _save_json(MANIFESTS_DIR / "script.json", script_data)

    # ── Step 2: Generate character manifest ───────────────────
    print("\n" + "=" * 50)
    print("  Step 2/8: Generating character prompts")
    print("=" * 50)
    char_input = _json.dumps(script_data.get("characters", []), ensure_ascii=False, indent=2)
    char_result = _run_skill(
        llm, "generate_character_prompts",
        {"input": char_input, "style": "anime visual novel style", "style_keywords": "clean lineart, soft cel shading"},
        temperature,
    )
    try:
        char_data = _json.loads(char_result)
    except _json.JSONDecodeError:
        print("Warning: Failed to parse character JSON, saving raw output")
        char_data = char_result
    _save_json(MANIFESTS_DIR / "characters.json", char_data if isinstance(char_data, dict) else {"raw": char_data})

    # ── Step 3: Generate background manifest ──────────────────
    print("\n" + "=" * 50)
    print("  Step 3/8: Generating background prompts")
    print("=" * 50)
    bg_input = _json.dumps(script_data.get("backgrounds", []), ensure_ascii=False, indent=2)
    bg_result = _run_skill(
        llm, "generate_background_prompts",
        {"input": bg_input, "style": "anime style background, visual novel background"},
        temperature,
    )
    try:
        bg_data = _json.loads(bg_result)
    except _json.JSONDecodeError:
        print("Warning: Failed to parse background JSON, saving raw output")
        bg_data = bg_result
    _save_json(MANIFESTS_DIR / "backgrounds.json", bg_data if isinstance(bg_data, dict) else {"raw": bg_data})

    # ── Step 4: Generate audio manifests ──────────────────────
    print("\n" + "=" * 50)
    print("  Step 4/8: Generating audio prompts")
    print("=" * 50)
    audio_input_data = {
        "bgm": script_data.get("bgm", []),
        "se": script_data.get("se", []),
    }
    audio_input = _json.dumps(audio_input_data, ensure_ascii=False, indent=2)
    audio_result = _run_skill(
        llm, "generate_audio_prompts",
        {"input": audio_input, "style": "visual novel game audio"},
        temperature,
    )
    try:
        audio_data = _json.loads(audio_result)
    except _json.JSONDecodeError:
        print("Warning: Failed to parse audio JSON, saving raw output")
        audio_data = {"raw": audio_result}
    if isinstance(audio_data, dict):
        if "bgm" in audio_data:
            _save_json(MANIFESTS_DIR / "bgm.json", audio_data["bgm"])
        if "se" in audio_data:
            _save_json(MANIFESTS_DIR / "se.json", audio_data["se"])
    else:
        _save_json(MANIFESTS_DIR / "audio.json", audio_data)

    # ── Step 5: Generate voice config ─────────────────────────
    print("\n" + "=" * 50)
    print("  Step 5/8: Generating voice config")
    print("=" * 50)
    voice_input = _json.dumps(script_data.get("characters", []), ensure_ascii=False, indent=2)
    voice_result = _run_skill(
        llm, "generate_voice_config",
        {"input": voice_input, "mimo_voices": "default", "qwen_speakers": "default"},
        temperature,
    )
    try:
        voice_data = _json.loads(voice_result)
    except _json.JSONDecodeError:
        print("Warning: Failed to parse voice config JSON, saving raw output")
        voice_data = {"raw": voice_result}
    _save_json(MANIFESTS_DIR / "voice_config.json", voice_data if isinstance(voice_data, dict) else {"raw": voice_data})

    # ── Step 6: Generate UI manifest ──────────────────────────
    print("\n" + "=" * 50)
    print("  Step 6/8: Generating UI prompts")
    print("=" * 50)
    ui_input = _json.dumps({
        "title": script_data.get("title", ""),
        "premise": premise,
        "characters": script_data.get("characters", []),
    }, ensure_ascii=False, indent=2)
    ui_result = _run_skill(
        llm, "generate_ui_prompts",
        {"input": ui_input, "style": "anime visual novel style"},
        temperature,
    )
    try:
        ui_data = _json.loads(ui_result)
    except _json.JSONDecodeError:
        print("Warning: Failed to parse UI JSON, saving raw output")
        ui_data = {"raw": ui_result}
    _save_json(MANIFESTS_DIR / "ui.json", ui_data if isinstance(ui_data, dict) else {"raw": ui_data})

    # ── Step 7: Generate visual/audio assets (NOT voice/dialogue) ──
    print("\n" + "=" * 50)
    print("  Step 7/8: Generating visual/audio assets")
    print("=" * 50)
    from .generators import (
        generate_characters, generate_backgrounds,
        generate_bgm, generate_se, generate_voice_all,
        generate_ui, generate_dialogue,
    )
    from .providers import ComfyUIImageProvider, MiMoTTS

    skip = not args.force
    engine = getattr(args, "engine", "mimo") or "mimo"
    image = ComfyUIImageProvider()
    tts = MiMoTTS() if engine == "mimo" else __import__("akonado.providers.tts_qwen", fromlist=["QwenTTS"]).QwenTTS()

    for name, fn in [
        ("characters", lambda: generate_characters(image, skip_existing=skip)),
        ("backgrounds", lambda: generate_backgrounds(image, skip_existing=skip)),
        ("bgm", lambda: generate_bgm(image, skip_existing=skip)),
        ("se", lambda: generate_se(image, skip_existing=skip)),
        ("ui", lambda: generate_ui(image, skip_existing=skip)),
    ]:
        print(f"\n--- {name} ---")
        try:
            fn()
        except Exception as e:
            print(f"  [error] {name}: {e}")

    # ── Step 8a: Generate .ks scripts (BEFORE voice/dialogue) ──
    print("\n" + "=" * 50)
    print("  Step 8/8: Generating .ks scripts, voice & dialogue")
    print("=" * 50)
    chapters = script_data.get("chapters", [])
    char_info = _json.dumps(script_data.get("characters", []), ensure_ascii=False)
    bg_info = _json.dumps(script_data.get("backgrounds", []), ensure_ascii=False)
    bgm_info = _json.dumps(script_data.get("bgm", []), ensure_ascii=False)

    for chapter in chapters:
        chapter_dir = STORY_DIR / chapter["id"]
        chapter_dir.mkdir(parents=True, exist_ok=True)
        for scene in chapter.get("scenes", []):
            scene_vars = {
                "scene_summary": scene.get("summary", ""),
                "characters": char_info,
                "backgrounds": bg_info,
                "bgm_list": bgm_info,
                "context": chapter.get("summary", ""),
                "extra_instructions": f"这是第{chapter['id']}章「{chapter.get('title', '')}」的场景。背景ID: {scene.get('location', '')}",
            }
            ks_result = _run_skill(llm, "generate_scene_script", scene_vars, temperature)
            ks_path = chapter_dir / f"{scene['id']}.ks"
            with open(ks_path, "w", encoding="utf-8") as f:
                f.write(ks_result)
            print(f"  [saved] {ks_path}")

    # ── Step 8b: Generate voice and dialogue (AFTER .ks scripts) ──
    print("\n--- voice ---")
    try:
        generate_voice_all(tts, skip_existing=skip)
    except Exception as e:
        print(f"  [error] voice: {e}")

    print("\n--- dialogue ---")
    try:
        generate_dialogue()
    except Exception as e:
        print(f"  [error] dialogue: {e}")

    # ── Summary ───────────────────────────────────────────────
    print("\n" + "=" * 50)
    print("  Pipeline complete!")
    print("=" * 50)
    print(f"  Premise: {premise[:60]}...")
    print(f"  Chapters: {len(chapters)}")
    total_scenes = sum(len(ch.get("scenes", [])) for ch in chapters)
    print(f"  Scenes: {total_scenes}")
    print(f"  Godot dir: {godot_dir}")
    print(f"  Assets: {ASSETS_DIR}")
    print(f"  Scripts: {STORY_DIR}")


def cmd_workflows(_args: argparse.Namespace) -> None:
    """List discovered ComfyUI workflows."""
    from .providers import ComfyUIClient

    client = ComfyUIClient()
    workflows = client.list_workflows()

    if not workflows:
        print("No ComfyUI workflows found in comfyui/")
        print("Add workflow JSON files with prefixes: image_*, audio_*, utility_*")
        return

    print(f"ComfyUI workflows ({len(workflows)}):\n")
    for wf_name in workflows:
        tpl = client.get_workflow(wf_name)
        node_count = len(tpl.workflow) if tpl else 0
        print(f"  {wf_name}  ({node_count} nodes)")

    print(f"\nComfyUI URL: {client._base_url}")
    print(f"Available: {'Yes' if client.available() else 'No'}")


def cmd_web(args: argparse.Namespace) -> None:
    """Launch web GUI."""
    from .web.app import create_app
    from .config import WEB_HOST, WEB_PORT, WEB_DEBUG

    host = args.host or WEB_HOST
    port = args.port or WEB_PORT
    debug = args.debug or WEB_DEBUG

    app = create_app()
    print(f"[web] Starting akonado web GUI at http://{host}:{port}")
    app.run(host=host, port=port, debug=debug)


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
        help="Asset type: characters/backgrounds/bgm/se/voice/ui/dialogue/all",
    )
    gen_parser.add_argument(
        "--force", "-f", action="store_true",
        help="Force regeneration (don't skip existing files)",
    )
    gen_parser.add_argument(
        "--engine", "-e", choices=["mimo", "qwen"],
        help="TTS engine for voice generation (default: mimo)",
    )

    # list
    list_parser = sub.add_parser("list", aliases=["ls"], help="View manifests")
    list_parser.add_argument("type", nargs="?", help="Asset type (omit for all)")

    # clean
    clean_parser = sub.add_parser("clean", help="Remove generated files")
    clean_parser.add_argument(
        "type",
        help="Type to clean: characters/backgrounds/bgm/se/voice/ui/all/manifests/scripts",
    )
    clean_parser.add_argument(
        "--deep", "-d", action="store_true",
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
    pipe_parser = sub.add_parser("pipeline", aliases=["p"], help="Full pipeline: premise -> all assets")
    pipe_parser.add_argument("premise", help="One-sentence story premise")
    pipe_parser.add_argument("--force", "-f", action="store_true", help="Force regeneration")
    pipe_parser.add_argument("--temperature", "-t", type=float, help="LLM temperature (default: 0.7)")
    pipe_parser.add_argument("--chapters", type=int, default=4, help="Number of chapters (default: 4)")
    pipe_parser.add_argument("--scenes-per-chapter", type=int, default=3, help="Scenes per chapter (default: 3)")
    pipe_parser.add_argument("--godot-dir", type=str, help="Godot engine directory")
    pipe_parser.add_argument("--engine", "-e", choices=["mimo", "qwen"], help="TTS engine (default: mimo)")

    # web
    web_parser = sub.add_parser("web", help="Launch web GUI")
    web_parser.add_argument("--host", help="Host (default: 127.0.0.1)")
    web_parser.add_argument("--port", type=int, help="Port (default: 5000)")
    web_parser.add_argument("--debug", action="store_true", help="Enable debug mode")

    args = parser.parse_args(argv)

    if args.command in ("generate", "g"):
        cmd_generate(args)
    elif args.command in ("list", "ls"):
        cmd_list(args)
    elif args.command == "clean":
        cmd_clean(args)
    elif args.command == "check":
        cmd_check(args)
    elif args.command == "skill":
        cmd_skill(args)
    elif args.command in ("pipeline", "p"):
        cmd_pipeline(args)
    elif args.command in ("workflows", "wf"):
        cmd_workflows(args)
    elif args.command == "web":
        cmd_web(args)
    else:
        parser.print_help()
