@echo off
:: Run LLM skills
:: Usage:
::   scripts\Windows\skill.cmd list                                      - List all skills
::   scripts\Windows\skill.cmd run -n generate_script -i "a story about X" - Run a skill
::   scripts\Windows\skill.cmd run -n generate_script -i "X" -o output.json - Save output
cd /d "%~dp0\..\.."
python -m akonado skill %*
pause
