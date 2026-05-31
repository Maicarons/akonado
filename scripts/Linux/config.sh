#!/usr/bin/env bash
# Open .env config for editing
cd "$(dirname "$0")/../.."
if [ ! -f "akonado/.env" ]; then
    echo "[akonado] No .env found. Creating from .env.example..."
    cp "akonado/.env.example" "akonado/.env"
fi
${EDITOR:-nano} "akonado/.env"
