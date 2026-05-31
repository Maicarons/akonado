@echo off
:: List manifest contents
:: Usage:
::   scripts\Windows\list.cmd                - List all manifests
::   scripts\Windows\list.cmd characters     - Show characters manifest
::   scripts\Windows\list.cmd voice_config   - Show voice config
cd /d "%~dp0\..\.."
python -m akonado list %*
pause
