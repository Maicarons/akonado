@echo off
:: Full AI pipeline: premise -> script -> all assets
:: Usage: scripts\Windows\pipeline.cmd "a story about a tea shop"
cd /d "%~dp0\..\.."
if "%~1"=="" (
    echo Usage: scripts\Windows\pipeline.cmd "your story premise"
    pause
    goto :end
)
set PREMISE=%~1
shift
set EXTRA_ARGS=
:parse_args
if "%~1"=="" goto :run
set EXTRA_ARGS=%EXTRA_ARGS% %~1
shift
goto :parse_args
:run
echo [akonado] Step 1/2: Generating script from premise...
python -m akonado skill run -n generate_script -i "%PREMISE%" -o akonado\manifests\script.json
if %errorlevel% neq 0 (
    echo [akonado] Script generation failed.
    pause
    goto :end
)
echo.
echo [akonado] Step 2/2: Generating all assets...
python -m akonado generate all %EXTRA_ARGS%
if %errorlevel% neq 0 (
    echo [akonado] Asset generation had errors.
) else (
    echo.
    echo [akonado] Pipeline complete! Run 'scripts\Windows\godot.cmd' to open in Godot.
)
:end
pause
