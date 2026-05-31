#!/usr/bin/env bash
# List manifest contents
# Usage:
#   scripts/macOS/list.sh             - List all manifests
#   scripts/macOS/list.sh characters  - Show characters manifest
cd "$(dirname "$0")/../.."
python -m akonado list "$@"
