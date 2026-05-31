@echo off
:: Generate assets
:: Usage:
::   scripts\Windows\generate.cmd                    - Generate all assets
::   scripts\Windows\generate.cmd characters         - Generate characters only
::   scripts\Windows\generate.cmd backgrounds        - Generate backgrounds only
::   scripts\Windows\generate.cmd bgm                - Generate BGM only
::   scripts\Windows\generate.cmd se                 - Generate sound effects only
::   scripts\Windows\generate.cmd voice              - Generate voice only
::   scripts\Windows\generate.cmd voice --engine qwen - Generate voice with Qwen TTS
::   scripts\Windows\generate.cmd ui                 - Generate UI assets only
::   scripts\Windows\generate.cmd dialogue           - Extract dialogue only
::   scripts\Windows\generate.cmd all --force        - Force regenerate all
cd /d "%~dp0\..\.."
if "%~1"=="" (
    python -m akonado generate all
) else (
    python -m akonado generate %*
)
pause
