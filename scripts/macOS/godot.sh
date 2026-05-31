#!/usr/bin/env bash
# Launch Godot editor with this project
# Set GODOT_PATH env var or ensure godot is in PATH.
cd "$(dirname "$0")/../.."
if [ -n "$GODOT_PATH" ]; then
    "$GODOT_PATH" --editor --path "$PWD"
    exit 0
fi
if command -v godot &>/dev/null; then
    godot --editor --path "$PWD"
    exit 0
fi
# macOS .app bundle
for app in \
    "/Applications/Godot.app" \
    "/Applications/Godot_v4.6.app" \
    "$HOME/Applications/Godot.app"; do
    if [ -d "$app" ]; then
        "$app/Contents/MacOS/Godot" --editor --path "$PWD"
        exit 0
    fi
done
# Homebrew cask
BREW_GODOT="$(brew --prefix 2>/dev/null)/bin/godot"
if [ -x "$BREW_GODOT" ]; then
    "$BREW_GODOT" --editor --path "$PWD"
    exit 0
fi
echo "[akonado] Godot not found. Set GODOT_PATH or install via:"
echo "  brew install --cask godot"
echo "  https://godotengine.org/download/macos"
exit 1
