#!/usr/bin/env bash
# Clean generated files
# Usage: scripts/macOS/clean.sh <type>
# Types: characters, backgrounds, bgm, se, voice, ui, dialogue
cd "$(dirname "$0")/../.."
if [ $# -eq 0 ]; then
    echo "Usage: scripts/macOS/clean.sh <type>"
    echo "Types: characters, backgrounds, bgm, se, voice, ui, dialogue"
else
    python -m akonado clean "$@"
fi
