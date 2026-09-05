#!/usr/bin/env python3

import argparse
from pathlib import Path
import re
import shutil
import subprocess
import sys


FATAL_OUTPUT_PATTERN = re.compile(
    r"^[ \t]*(?:SCRIPT ERROR|ERROR|FATAL|Parse Error):",
    re.MULTILINE,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run a Godot export, reject protection errors hidden by exit code 0, "
            "and remove explicitly declared partial outputs on failure."
        )
    )
    parser.add_argument(
        "--cleanup",
        action="append",
        default=[],
        metavar="PATH",
        help="Workspace output path to remove if the export fails (repeatable)",
    )
    parser.add_argument(
        "command",
        nargs=argparse.REMAINDER,
        help="Godot export command, preceded by --",
    )
    return parser.parse_args()


def _workspace_output(path_text: str) -> Path:
    workspace = Path.cwd().resolve()
    candidate = Path(path_text)
    if not candidate.is_absolute():
        candidate = workspace / candidate
    candidate = candidate.resolve()
    if candidate == workspace or workspace not in candidate.parents:
        raise ValueError(f"cleanup path must be inside the workspace: {path_text}")
    return candidate


def _remove_output(path_text: str) -> None:
    output = _workspace_output(path_text)
    if output.is_dir():
        shutil.rmtree(output)
    elif output.exists() or output.is_symlink():
        output.unlink()


def run_export(command: list[str]) -> tuple[int, bool]:
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    fatal_output = False
    assert process.stdout is not None
    for line in process.stdout:
        sys.stdout.write(line)
        if FATAL_OUTPUT_PATTERN.search(line):
            fatal_output = True
    return process.wait(), fatal_output


def main() -> int:
    args = parse_args()
    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        print("A Godot export command is required after --.", file=sys.stderr)
        return 2

    try:
        return_code, fatal_output = run_export(command)
    except OSError as error:
        print(f"Unable to start Godot export: {error}", file=sys.stderr)
        return_code, fatal_output = 1, False

    if return_code == 0 and not fatal_output:
        return 0

    for cleanup_path in args.cleanup:
        try:
            _remove_output(cleanup_path)
        except (OSError, ValueError) as error:
            print(f"Unable to clean partial export {cleanup_path}: {error}", file=sys.stderr)
    if fatal_output:
        print(
            "Godot emitted an error despite returning exit code 0.",
            file=sys.stderr,
        )
    return return_code if return_code > 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
