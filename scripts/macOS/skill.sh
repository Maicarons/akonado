#!/usr/bin/env bash
# Run LLM skills
# Usage:
#   scripts/macOS/skill.sh list                                        - List all skills
#   scripts/macOS/skill.sh run -n generate_script -i "a story about X" - Run a skill
cd "$(dirname "$0")/../.."
python -m akonado skill "$@"
