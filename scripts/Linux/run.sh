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
for candidate in \
    /usr/bin/godot \
    /usr/local/bin/godot \
    "$HOME/.local/bin/godot" \
    /opt/godot/godot \
    /snap/bin/godot \
    "$HOME/.local/share/flatpak/app/org.godotengine.Godot/current/active/files/bin/godot"; do
    if [ -x "$candidate" ]; then
        "$candidate" --path "$PWD"
        exit 0
    fi
done
echo "[akonado] Godot not found. Set GODOT_PATH or add Godot to PATH."
exit 1
