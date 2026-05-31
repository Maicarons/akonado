@echo off
:: Launch Godot editor with this project
:: Set GODOT_PATH env var or ensure godot is in PATH.
cd /d "%~dp0\..\.."
if defined GODOT_PATH (
    "%GODOT_PATH%" --editor --path "%cd%"
    goto :end
)
where godot >nul 2>&1
if %errorlevel%==0 (
    godot --editor --path "%cd%"
    goto :end
)
if exist "C:\Godot\Godot.exe" (
    "C:\Godot\Godot.exe" --editor --path "%cd%"
    goto :end
)
echo [akonado] Godot not found. Set GODOT_PATH or add Godot to PATH.
echo Example: set GODOT_PATH=C:\path\to\Godot_v4.6-stable_win64.exe
pause
:end
