@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1
title Wheel of Names - Portable Setup

rem ==============================================================
rem Downloads Node.js Portable and sets up the project
rem ==============================================================

set "NODE_VERSION=20.18.0"
set "NODE_ARCH=win-x64"
set "NODE_DIR=node-portable"
set "NODE_ZIP=node-v%NODE_VERSION%-%NODE_ARCH%.zip"
set "NODE_URL=https://nodejs.org/dist/v%NODE_VERSION%/%NODE_ZIP%"

cls
echo.
echo   ╔══════════════════════════════════════════════════════╗
echo   ║                                                      ║
echo   ║     🎡  WHEEL OF NAMES - PORTABLE SETUP  🎡          ║
echo   ║                                                      ║
echo   ╚══════════════════════════════════════════════════════╝
echo.

rem Check if already portable
if exist "%NODE_DIR%\node.exe" (
    echo   ✓ Portable Node.js already installed!
    echo.
    echo   To run the server, use: start-portable.bat
    echo.
    pause
    exit /b 0
)

echo   This will download Node.js v%NODE_VERSION% portable (~30MB^)
echo   and set up the project for standalone use.
echo.
echo   No installation required - everything runs from this folder!
echo.
set /p "CONFIRM=   Continue? (Y/N): "
if /I not "%CONFIRM%"=="Y" (
    echo   Setup cancelled.
    pause
    exit /b 0
)

echo.
echo   [1/4] Downloading Node.js portable...

rem Download using PowerShell
powershell -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%NODE_URL%' -OutFile '%NODE_ZIP%' -UseBasicParsing } catch { Write-Host 'Download failed:' $_.Exception.Message; exit 1 }"
if %errorLevel% NEQ 0 (
    echo   ✗ Download failed. Check your internet connection.
    pause
    exit /b 1
)
echo   ✓ Downloaded

echo   [2/4] Extracting...
powershell -Command "Expand-Archive -Path '%NODE_ZIP%' -DestinationPath '.' -Force"
if %errorLevel% NEQ 0 (
    echo   ✗ Extraction failed.
    pause
    exit /b 1
)

rem Rename to node-portable
if exist "node-v%NODE_VERSION%-%NODE_ARCH%" (
    ren "node-v%NODE_VERSION%-%NODE_ARCH%" "%NODE_DIR%"
)
del "%NODE_ZIP%" 2>nul
echo   ✓ Extracted to %NODE_DIR%\

echo   [3/4] Installing dependencies...
set "PATH=%~dp0%NODE_DIR%;%PATH%"
call "%NODE_DIR%\npm.cmd" install --no-optional
if %errorLevel% NEQ 0 (
    echo   ✗ npm install failed.
    pause
    exit /b 1
)
echo   ✓ Dependencies installed

echo   [4/4] Creating portable launcher...

rem Create start-portable.bat
(
    echo @echo off
    echo setlocal EnableExtensions EnableDelayedExpansion
    echo chcp 65001 ^>nul 2^>^&1
    echo title Wheel of Names - Offline Server ^(Portable^)
    echo.
    echo rem Use bundled Node.js
    echo set "PATH=%%~dp0node-portable;%%PATH%%"
    echo.
    echo rem Run the main launcher
    echo call "%%~dp0start-wheel-server.bat" %%*
) > start-portable.bat

echo   ✓ Created start-portable.bat

echo.
echo   ════════════════════════════════════════════════════════
echo.
echo   ✓ PORTABLE SETUP COMPLETE!
echo.
echo   You can now copy this entire folder to any Windows PC
echo   and run it without installing Node.js!
echo.
echo   To start the server:
echo     • Double-click: start-portable.bat
echo.
echo   Folder size: ~150MB (includes Node.js + dependencies)
echo.
echo   ════════════════════════════════════════════════════════
echo.
pause
