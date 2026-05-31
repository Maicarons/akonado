#!/usr/bin/env bash
# Run the game in Godot (play mode)
cd "$(dirname "$0")/../.."
if [ -n "$GODOT_PATH" ]; then
    "$GODOT_PATH" --path "$PWD"
    exit 0
fi
if command -v godot &>/dev/null; then
    godot --path "$PWD"
    exit 0
fi
for app in \
    "/Applications/Godot.app" \
    "/Applications/Godot_v4.6.app" \
    "$HOME/Applications/Godot.app"; do
    if [ -d "$app" ]; then
        "$app/Contents/MacOS/Godot" --path "$PWD"
        exit 0
    fi
done
BREW_GODOT="$(brew --prefix 2>/dev/null)/bin/godot"
if [ -x "$BREW_GODOT" ]; then
    "$BREW_GODOT" --path "$PWD"
    exit 0
fi
echo "[akonado] Godot not found. Set GODOT_PATH or install via: brew install --cask godot"
exit 1
