#!/usr/bin/env python3
"""Validate the executable contracts shown by the latest Konado.NET docs."""

from __future__ import annotations

import re
import sys
from pathlib import Path


FENCE_PATTERN = re.compile(r"```csharp\s*\n(.*?)```", re.DOTALL)
REQUIRED_API_MEMBERS = (
    "BindDialogueManager",
    "GetDialogueVariable",
    "InitDialogue(Callable callback)",
    "ReloadLocalizedScript",
    "ResolveScriptPath",
    "LoadLocalizedScript",
    "CompileLine(line, lineNumber, path = \"\")",
)


def _check_code_block(path: Path, block: str, block_number: int) -> list[str]:
    errors: list[str] = []
    location = f"{path}: C# block {block_number}"
    if re.search(r"(?<![.\w])Node\b", block) and "using Godot;" not in block:
        errors.append(f"{location} uses Node without 'using Godot;'")
    if re.search(r"(?<![.\w])KonadoApi\b", block) and "using Konado.Runtime.Api;" not in block:
        errors.append(
            f"{location} uses KonadoApi without 'using Konado.Runtime.Api;'"
        )
    if (
        re.search(r"(?<![.\w])KonadoScriptCompiler\b", block)
        and "using Konado.Runtime.Resources;" not in block
    ):
        errors.append(
            f"{location} uses KonadoScriptCompiler without "
            "'using Konado.Runtime.Resources;'"
        )
    return errors


def main(arguments: list[str]) -> int:
    if not arguments:
        print("usage: check_dotnet_docs.py DOC_ROOT [...]", file=sys.stderr)
        return 2

    errors: list[str] = []
    api_pages: list[Path] = []
    markdown_files: list[Path] = []
    for argument in arguments:
        root = Path(argument)
        if not root.is_dir():
            errors.append(f"documentation root does not exist: {root}")
            continue
        markdown_files.extend(sorted(root.rglob("*.md")))
        api_page = root / "dotnet" / "api.md"
        if api_page.is_file():
            api_pages.append(api_page)
        else:
            errors.append(f"Konado.NET API page does not exist: {api_page}")

    for path in markdown_files:
        content = path.read_text(encoding="utf-8")
        for block_number, block in enumerate(FENCE_PATTERN.findall(content), start=1):
            errors.extend(_check_code_block(path, block, block_number))

    for path in api_pages:
        content = path.read_text(encoding="utf-8")
        for member in REQUIRED_API_MEMBERS:
            if member not in content:
                errors.append(f"{path} does not document {member}")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(
        f"Validated {len(markdown_files)} Markdown files and "
        f"{len(api_pages)} Konado.NET API pages."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
