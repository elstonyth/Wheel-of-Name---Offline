@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1
title Create Desktop Shortcut

echo.
echo   ╔══════════════════════════════════════════════════════╗
echo   ║     🎡 CREATE DESKTOP SHORTCUT 🎡                    ║
echo   ╚══════════════════════════════════════════════════════╝
echo.

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "DESKTOP=%USERPROFILE%\Desktop"

echo   Choose shortcut type:
echo.
echo   [1] Normal Mode   - Prompts for hostname
echo   [2] Quick Mode    - Uses saved config (no prompts)
echo   [3] Tray Mode     - System tray with auto-recovery
echo   [4] All three
echo.
set /p "CHOICE=  Enter choice [1-4]: "

if "%CHOICE%"=="1" goto CREATE_NORMAL
if "%CHOICE%"=="2" goto CREATE_QUICK
if "%CHOICE%"=="3" goto CREATE_TRAY
if "%CHOICE%"=="4" goto CREATE_ALL
goto CREATE_NORMAL

:CREATE_NORMAL
call :make_shortcut "Wheel of Names" ""
goto DONE

:CREATE_QUICK
call :make_shortcut "Wheel of Names (Quick)" "quick"
goto DONE

:CREATE_TRAY
call :make_shortcut "Wheel of Names (Tray)" "tray"
goto DONE

:CREATE_ALL
call :make_shortcut "Wheel of Names" ""
call :make_shortcut "Wheel of Names (Quick)" "quick"
call :make_shortcut "Wheel of Names (Tray)" "tray"
goto DONE

:make_shortcut
set "NAME=%~1"
set "ARGS=%~2"
set "SHORTCUT=%DESKTOP%\%NAME%.lnk"

powershell -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('%SHORTCUT%'); $s.TargetPath = '%SCRIPT_DIR%\start-wheel-server.bat'; $s.Arguments = '%ARGS%'; $s.WorkingDirectory = '%SCRIPT_DIR%'; $s.Description = 'Start Wheel of Names Offline Server'; $s.Save()"

if exist "%SHORTCUT%" (
    echo   ✓ Created: %NAME%
) else (
    echo   ✗ Failed to create: %NAME%
)
exit /b 0

:DONE
echo.
echo   ✅ Done! Check your desktop.
echo.
pause
exit /b 0
