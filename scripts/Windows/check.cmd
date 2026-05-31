@echo off
:: Check provider availability
cd /d "%~dp0\..\.."
python -m akonado check
pause
