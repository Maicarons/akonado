"""Run LLM skill command."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def cmd_skill(args: argparse.Namespace) -> None:
    """Run an LLM skill (prompt template) to generate content."""
    from ..providers import OpenAICompatibleLLM
    from ..skills import list_skills, load_skill, render_user_prompt
    from .helpers import strip_markdown_code_blocks

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
                cleaned = strip_markdown_code_blocks(result)
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
