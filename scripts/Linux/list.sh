#!/usr/bin/env bash
# List manifest contents
# Usage:
#   scripts/Linux/list.sh             - List all manifests
#   scripts/Linux/list.sh characters  - Show characters manifest
cd "$(dirname "$0")/../.."
python -m akonado list "$@"
