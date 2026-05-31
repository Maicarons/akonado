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
# Common Linux install locations
for candidate in \
    /usr/bin/godot \
    /usr/local/bin/godot \
    "$HOME/.local/bin/godot" \
    /opt/godot/godot \
    /snap/bin/godot \
    "$HOME/.local/share/flatpak/app/org.godotengine.Godot/current/active/files/bin/godot"; do
    if [ -x "$candidate" ]; then
        "$candidate" --editor --path "$PWD"
        exit 0
    fi
done
echo "[akonado] Godot not found. Set GODOT_PATH or add Godot to PATH."
echo "Install: https://godotengine.org/download/linux"
exit 1
