@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1
title Wheel of Names - Client Setup

echo.
echo   ╔══════════════════════════════════════════════════════╗
echo   ║     🎡 WHEEL OF NAMES - CLIENT DEVICE SETUP 🎡       ║
echo   ╚══════════════════════════════════════════════════════╝
echo.

rem Check for admin rights
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo   ⚠️  This script needs Administrator privileges.
    echo   Requesting elevation...
    powershell -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    exit /b
)

echo   ✓ Running as Administrator
echo.

rem Configuration
set "DEFAULT_HOSTNAME=wheel.local"
set "DEFAULT_SERVER_IP="

rem Get parameters or prompt
if "%~1"=="" (
    set /p "SERVER_IP=  Enter server IP address: "
) else (
    set "SERVER_IP=%~1"
)

if "%~2"=="" (
    set /p "HOSTNAME=  Enter hostname [%DEFAULT_HOSTNAME%]: "
    if "!HOSTNAME!"=="" set "HOSTNAME=%DEFAULT_HOSTNAME%"
) else (
    set "HOSTNAME=%~2"
)

echo.
echo   ─────────────────────────────────────────────────────────
echo   Configuration:
echo   ─────────────────────────────────────────────────────────
echo     Server IP: %SERVER_IP%
echo     Hostname:  %HOSTNAME%
echo   ─────────────────────────────────────────────────────────
echo.

rem Validate IP
if "%SERVER_IP%"=="" (
    echo   ❌ ERROR: Server IP is required
    echo.
    echo   Usage: setup-client.bat [SERVER_IP] [HOSTNAME]
    echo   Example: setup-client.bat 192.168.1.100 wheel.local
    pause
    exit /b 1
)

rem Update hosts file
set "HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts"
set "ENTRY=%SERVER_IP% %HOSTNAME%"

echo   Updating hosts file...

rem Check if entry exists
findstr /C:"%HOSTNAME%" "%HOSTS_FILE%" >nul 2>&1
if %errorLevel% EQU 0 (
    echo   ⚠️  Entry for %HOSTNAME% already exists
    echo   Removing old entry...
    powershell -Command "(Get-Content '%HOSTS_FILE%') | Where-Object { $_ -notmatch '%HOSTNAME%' } | Set-Content '%HOSTS_FILE%'"
)

rem Add new entry
echo. >> "%HOSTS_FILE%"
echo %ENTRY% >> "%HOSTS_FILE%"

rem Flush DNS cache
echo   Flushing DNS cache...
ipconfig /flushdns >nul 2>&1

echo.
echo   ✅ Setup complete!
echo.
echo   ─────────────────────────────────────────────────────────
echo   You can now access the wheel at:
echo   ─────────────────────────────────────────────────────────
echo     https://%HOSTNAME%
echo     http://%HOSTNAME%
echo   ─────────────────────────────────────────────────────────
echo.
echo   ⚠️  NOTE: Your browser may show a certificate warning.
echo      This is normal for local SSL certificates.
echo      Click "Advanced" then "Proceed" to continue.
echo.
echo   To REMOVE this configuration later, run:
echo     setup-client.bat --remove %HOSTNAME%
echo.
pause
exit /b 0

:REMOVE_ENTRY
set "REMOVE_HOST=%~2"
if "%REMOVE_HOST%"=="" (
    echo   ❌ ERROR: Specify hostname to remove
    echo   Usage: setup-client.bat --remove hostname
    exit /b 1
)
echo   Removing %REMOVE_HOST% from hosts file...
powershell -Command "(Get-Content '%HOSTS_FILE%') | Where-Object { $_ -notmatch '%REMOVE_HOST%' } | Set-Content '%HOSTS_FILE%'"
ipconfig /flushdns >nul 2>&1
echo   ✅ Removed!
exit /b 0
