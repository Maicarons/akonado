#!/usr/bin/env python3
"""Validate local files referenced by Godot plugin.cfg metadata."""

from __future__ import annotations

import configparser
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]


def unquote(value: str) -> str:
    return value.strip().strip('"').strip("'")


def main() -> int:
    errors: list[str] = []
    configs = sorted((REPOSITORY_ROOT / "addons").glob("*/plugin.cfg"))

    for config_path in configs:
        parser = configparser.ConfigParser(interpolation=None)
        parser.read(config_path, encoding="utf-8")
        if "plugin" not in parser:
            errors.append(f"{config_path.relative_to(REPOSITORY_ROOT)}: missing [plugin]")
            continue

        for key in ("script", "icon"):
            value = unquote(parser["plugin"].get(key, ""))
            if not value:
                if key == "script":
                    errors.append(
                        f"{config_path.relative_to(REPOSITORY_ROOT)}: missing script"
                    )
                continue
            referenced_path = config_path.parent / value
            if not referenced_path.is_file():
                errors.append(
                    f"{config_path.relative_to(REPOSITORY_ROOT)}: "
                    f"{key} target does not exist: {value}"
                )

    if errors:
        print("\n".join(errors))
        return 1

    print(f"Plugin metadata check passed: {len(configs)} plugin.cfg files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
