@echo off
cd /d "%~dp0.."

echo Installing dependencies with HMM...
echo.

if not exist "hmm.json" (
    echo ERROR: hmm.json not found!
    pause
    exit /b 1
)

haxelib list | findstr /C:"hmm" >nul
if errorlevel 1 (
    echo hmm not found. Installing hmm globally...
    haxelib --global install hmm
    haxelib --global run hmm setup
)

haxelib run hmm install

if errorlevel 1 (
    echo.
    echo ERROR: Failed to install dependencies.
    pause
    exit /b 1
)

echo.
echo Dependencies installed successfully!
pause