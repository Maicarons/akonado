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
    from .providers import ComfyUIImageProvider, MiMoTTS, QwenTTS, OpenAICompatibleLLM

    providers = [
        ("ComfyUI (Image/Audio)", ComfyUIImageProvider()),
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
                try:
                    parsed = json.loads(result)
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
    """Remove generated files for a type."""
    from .config import CHARACTERS_DIR, BACKGROUNDS_DIR, BGM_DIR, SE_DIR, VOICE_DIR, UI_DIR

    dir_map = {
        "characters": CHARACTERS_DIR,
        "backgrounds": BACKGROUNDS_DIR,
        "bgm": BGM_DIR,
        "se": SE_DIR,
        "voice": VOICE_DIR,
        "ui": UI_DIR,
    }

    if args.type not in dir_map:
        print(f"unknown type: {args.type}")
        print(f"available: {', '.join(dir_map)}")
        sys.exit(1)

    target_dir = dir_map[args.type]
    if not target_dir.exists():
        print(f"  directory not found: {target_dir}")
        return

    count = 0
    for f in target_dir.iterdir():
        if f.is_file():
            f.unlink()
            count += 1

    print(f"[{args.type}] cleaned {count} files from {target_dir}")


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
    clean_parser.add_argument("type", help="Asset type")

    # check
    sub.add_parser("check", help="Check provider availability")

    # skill
    skill_parser = sub.add_parser("skill", help="Run LLM skill (prompt template)")
    skill_parser.add_argument("action", choices=["list", "run"], help="List or run skills")
    skill_parser.add_argument("--name", "-n", help="Skill name to run")
    skill_parser.add_argument("--input", "-i", help="Input text (one-sentence premise)")
    skill_parser.add_argument("--var", action="append", help="Template variable (key=value)")
    skill_parser.add_argument("--output", "-o", help="Save output to file")
    skill_parser.add_argument("--temperature", "-t", type=float, help="LLM temperature")

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
    elif args.command == "web":
        cmd_web(args)
    else:
        parser.print_help()
