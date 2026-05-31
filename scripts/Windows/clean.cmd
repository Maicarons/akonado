@echo off
:: Clean generated files
:: Usage: scripts\Windows\clean.cmd <type>
:: Types: characters, backgrounds, bgm, se, voice, ui, dialogue
cd /d "%~dp0\..\.."
if "%~1"=="" (
    echo Usage: scripts\Windows\clean.cmd ^<type^>
    echo Types: characters, backgrounds, bgm, se, voice, ui, dialogue
) else (
    python -m akonado clean %*
)
pause
