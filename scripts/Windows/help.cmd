@echo off
echo.
echo  Akonado Scripts (Windows)
echo  ========================
echo.
echo  Setup:
echo    scripts\Windows\setup.cmd           Install Python dependencies
echo    scripts\Windows\config.cmd          Open .env config for editing
echo    scripts\Windows\check.cmd           Check provider availability
echo.
echo  AI Pipeline:
echo    scripts\Windows\skill.cmd list      List available LLM skills
echo    scripts\Windows\skill.cmd run ...   Run an LLM skill
echo    scripts\Windows\generate.cmd        Generate all assets
echo    scripts\Windows\generate.cmd TYPE   Generate specific asset type
echo    scripts\Windows\pipeline.cmd "X"    Full pipeline: premise -> all assets
echo    scripts\Windows\list.cmd            List all manifests
echo    scripts\Windows\clean.cmd TYPE      Delete generated files
echo.
echo  Godot:
echo    scripts\Windows\godot.cmd           Open Godot editor
echo    scripts\Windows\run.cmd             Run game in Godot
echo.
echo  Web GUI:
echo    scripts\Windows\web.cmd             Launch browser GUI
echo.
echo  Generate types: characters, backgrounds, bgm, se, voice, ui, dialogue, all
echo  Clean types:    characters, backgrounds, bgm, se, voice, ui, dialogue
echo.
pause
