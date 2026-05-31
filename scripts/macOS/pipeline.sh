#!/usr/bin/env bash
# Full AI pipeline: premise -> script -> all assets
# Usage: scripts/macOS/pipeline.sh "a story about a tea shop"
cd "$(dirname "$0")/../.."
if [ $# -eq 0 ]; then
    echo "Usage: scripts/macOS/pipeline.sh \"your story premise\""
    exit 1
fi
PREMISE="$1"
shift
echo "[akonado] Step 1/2: Generating script from premise..."
python -m akonado skill run -n generate_script -i "$PREMISE" -o akonado/manifests/script.json
if [ $? -ne 0 ]; then
    echo "[akonado] Script generation failed."
    exit 1
fi
echo ""
echo "[akonado] Step 2/2: Generating all assets..."
python -m akonado generate all "$@"
if [ $? -ne 0 ]; then
    echo "[akonado] Asset generation had errors."
else
    echo ""
    echo "[akonado] Pipeline complete! Run 'scripts/macOS/godot.sh' to open in Godot."
fi
