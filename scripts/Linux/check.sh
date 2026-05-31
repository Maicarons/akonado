#!/usr/bin/env bash
# Check provider availability
cd "$(dirname "$0")/../.."
python -m akonado check
