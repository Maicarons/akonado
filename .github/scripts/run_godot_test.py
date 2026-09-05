#!/usr/bin/env python3

import argparse
import os
import re
import subprocess
import sys


ERROR_PATTERN = re.compile(r"(?m)^[ \t]*(?:SCRIPT ERROR|ERROR|FATAL|Parse Error):")
EDITOR_SHUTDOWN_ERROR_PATTERN = re.compile(
    r"(?m)^ERROR: (?:\d+ resources still in use at exit|"
    r"\d+ RID allocations of type '.+' were leaked at exit)"
    r"(?: \(run with --verbose for details\))?\.\n"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a Godot script test and reject errors hidden by exit code 0."
    )
    parser.add_argument("test_path", help="Godot script path to execute")
    parser.add_argument(
        "--godot",
        default=os.environ.get("GODOT_BIN", "godot"),
        help="Godot executable (default: GODOT_BIN or godot)",
    )
    parser.add_argument(
        "--editor",
        action="store_true",
        help="Initialize the editor and enabled plugins before running the test.",
    )
    parser.add_argument(
        "--rendering",
        action="store_true",
        help="Use the compatibility renderer instead of the headless dummy renderer.",
    )
    parser.add_argument(
        "--timeout-seconds",
        type=int,
        default=120,
        help="Terminate a test that does not exit within this many seconds (default: 120).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    command = [args.godot]
    if args.rendering:
        command.extend(["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy"])
    else:
        command.append("--headless")
    if args.editor:
        command.append("--editor")
    command.extend(["--path", ".", "--script", args.test_path])
    if args.timeout_seconds <= 0:
        print("--timeout-seconds must be greater than zero.", file=sys.stderr)
        return 2
    try:
        result = subprocess.run(
            command,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=args.timeout_seconds,
        )
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ""
        if isinstance(output, bytes):
            output = output.decode(errors="replace")
        sys.stdout.write(output)
        print(
            f"Godot test exceeded the {args.timeout_seconds}-second timeout: "
            f"{args.test_path}",
            file=sys.stderr,
        )
        return 124
    sys.stdout.write(result.stdout)
    if result.returncode != 0:
        return result.returncode
    checked_output = result.stdout
    if args.editor:
        checked_output = EDITOR_SHUTDOWN_ERROR_PATTERN.sub("", checked_output)
    if ERROR_PATTERN.search(checked_output):
        print("Godot emitted a script/runtime error despite returning exit code 0.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
