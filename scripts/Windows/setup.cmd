@echo off
:: Install akonado Python dependencies
cd /d "%~dp0\..\.."
echo [akonado] Installing dependencies...
pip install requests Pillow python-dotenv openai flask
echo [akonado] Done.
pause
