#!/usr/bin/env bash
# Install akonado Python dependencies
cd "$(dirname "$0")/../.."
echo "[akonado] Installing dependencies..."
pip install requests Pillow python-dotenv openai flask
echo "[akonado] Done."
