#!/usr/bin/env python3
"""Validate static add-on resource paths shown in current documentation."""

from __future__ import annotations

import argparse
from pathlib import Path
import re


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
RESOURCE_PATTERN = re.compile(r"res://addons/[A-Za-z0-9_./-]+")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", help="Documentation files or directories.")
    arguments = parser.parse_args()

    markdown_files: list[Path] = []
    for raw_path in arguments.paths:
        path = (REPOSITORY_ROOT / raw_path).resolve()
        if path.is_dir():
            markdown_files.extend(sorted(path.rglob("*.md")))
        elif path.suffix == ".md":
            markdown_files.append(path)

    references: dict[str, set[str]] = {}
    for markdown_file in markdown_files:
        text = markdown_file.read_text(encoding="utf-8")
        for resource_path in RESOURCE_PATTERN.findall(text):
            references.setdefault(resource_path.rstrip(".,;:"), set()).add(
                str(markdown_file.relative_to(REPOSITORY_ROOT))
            )

    missing = {
        resource_path: locations
        for resource_path, locations in references.items()
        if not (REPOSITORY_ROOT / resource_path.removeprefix("res://")).exists()
    }
    if missing:
        for resource_path, locations in sorted(missing.items()):
            print(f"Missing resource: {resource_path}")
            for location in sorted(locations):
                print(f"  referenced by {location}")
        return 1

    print(
        f"Documentation resource check passed: {len(references)} unique paths "
        f"across {len(markdown_files)} Markdown files."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
