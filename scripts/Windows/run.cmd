@echo off
:: Run the game in Godot (play mode)
cd /d "%~dp0\..\.."
if defined GODOT_PATH (
    "%GODOT_PATH%" --path "%cd%"
    goto :end
)
where godot >nul 2>&1
if %errorlevel%==0 (
    godot --path "%cd%"
    goto :end
)
if exist "C:\Godot\Godot.exe" (
    "C:\Godot\Godot.exe" --path "%cd%"
    goto :end
)
echo [akonado] Godot not found. Set GODOT_PATH or add Godot to PATH.
pause
:end
