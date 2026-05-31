#!/usr/bin/env bash
# Launch Akonado Web GUI
cd "$(dirname "$0")/../.."
echo "[akonado] Starting Web GUI at http://127.0.0.1:5000"
python -m akonado web "$@"
