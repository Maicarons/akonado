#!/usr/bin/env bash
# Generate assets
# Usage:
#   scripts/Linux/generate.sh                      - Generate all assets
#   scripts/Linux/generate.sh characters           - Generate characters only
#   scripts/Linux/generate.sh backgrounds          - Generate backgrounds only
#   scripts/Linux/generate.sh voice --engine qwen  - Generate voice with Qwen TTS
#   scripts/Linux/generate.sh all --force          - Force regenerate all
cd "$(dirname "$0")/../.."
if [ $# -eq 0 ]; then
    python -m akonado generate all
else
    python -m akonado generate "$@"
fi
