#!/usr/bin/env bash
# Generate assets
# Usage:
#   scripts/macOS/generate.sh                      - Generate all assets
#   scripts/macOS/generate.sh characters           - Generate characters only
#   scripts/macOS/generate.sh backgrounds          - Generate backgrounds only
#   scripts/macOS/generate.sh voice --engine qwen  - Generate voice with Qwen TTS
#   scripts/macOS/generate.sh all --force          - Force regenerate all
cd "$(dirname "$0")/../.."
if [ $# -eq 0 ]; then
    python -m akonado generate all
else
    python -m akonado generate "$@"
fi
