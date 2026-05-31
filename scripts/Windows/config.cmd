@echo off
:: Open .env config for editing
cd /d "%~dp0\..\.."
if not exist "akonado\.env" (
    echo [akonado] No .env found. Creating from .env.example...
    copy "akonado\.env.example" "akonado\.env" >nul
)
start "" "akonado\.env"
