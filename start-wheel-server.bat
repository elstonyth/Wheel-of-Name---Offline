@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1
title Wheel of Names - Offline Server

rem ==============================================================
rem Wheel of Names Offline - Launcher & Manager
rem ==============================================================

set "REQUEST=%~1"
set "SCRIPT_DIR=%~dp0"
set "NODE_VERSION=20.18.0"
set "NODE_ARCH=win-x64"
set "PORTABLE_NODE_DIR=node-portable"
set "NODE_ZIP=node-v%NODE_VERSION%-%NODE_ARCH%.zip"
set "NODE_URL=https://nodejs.org/dist/v%NODE_VERSION%/%NODE_ZIP%"
set "CADDY_VERSION=2.8.4"
set "CADDY_ZIP=caddy_%CADDY_VERSION%_windows_amd64.zip"
set "CADDY_URL=https://github.com/caddyserver/caddy/releases/download/v%CADDY_VERSION%/%CADDY_ZIP%"

pushd "%SCRIPT_DIR%" >nul 2>&1
if errorLevel 1 (
    echo.
    echo   X Failed to switch to script directory: %SCRIPT_DIR%
    echo   Please extract all files to a local folder and try again.
    pause
    exit /b 1
)
set "PROJECT_ROOT=%CD%"

rem DEBUG: Add immediate pause to catch early errors
if "%DEBUG_PAUSE%"=="1" pause

rem Create debug log
set "DEBUG_LOG=logs\debug.log"
if not exist "logs" mkdir "logs"
echo [%date% %time%] Script started >> "%DEBUG_LOG%"

rem Colors via PowerShell helper
set "PS_GREEN=Write-Host -ForegroundColor Green"
set "PS_YELLOW=Write-Host -ForegroundColor Yellow"
set "PS_RED=Write-Host -ForegroundColor Red"
set "PS_CYAN=Write-Host -ForegroundColor Cyan"

if /I "%REQUEST%"=="--help" goto HELP_MODE
if /I "%REQUEST%"=="--check" goto DIAGNOSTIC_MODE
if /I "%REQUEST%"=="--diagnose" goto DIAGNOSTIC_MODE
if /I "%REQUEST%"=="--quick" goto QUICK_MODE
if /I "%REQUEST%"=="quick" goto QUICK_MODE
if /I "%REQUEST%"=="--dns" goto DNS_MODE
if /I "%REQUEST%"=="dns" goto DNS_MODE
if /I "%REQUEST%"=="--tray" goto TRAY_MODE
if /I "%REQUEST%"=="tray" goto TRAY_MODE
if /I "%REQUEST%"=="--silent" goto SILENT_MODE
if /I "%REQUEST%"=="silent" goto SILENT_MODE
if /I "%REQUEST%"=="--update" goto UPDATE_CHECK_MODE
if /I "%REQUEST%"=="update" goto UPDATE_CHECK_MODE
if /I "%REQUEST%"=="--network" goto NETWORK_DIAG_MODE
if /I "%REQUEST%"=="network" goto NETWORK_DIAG_MODE

rem Load saved config if exists
set "CONFIG_FILE=%~dp0config.json"
set "SAVED_HOSTNAME="
set "SAVED_PORT="
set "QUICK_MODE=0"
if exist "%CONFIG_FILE%" (
    for /f "tokens=2 delims=:," %%a in ('findstr /C:"hostname" "%CONFIG_FILE%"') do (
        set "SAVED_HOSTNAME=%%~a"
        set "SAVED_HOSTNAME=!SAVED_HOSTNAME: =!"
        set "SAVED_HOSTNAME=!SAVED_HOSTNAME:"=!"
    )
    for /f "tokens=2 delims=:," %%a in ('findstr /C:"preferredPort" "%CONFIG_FILE%"') do (
        set "SAVED_PORT=%%~a"
        set "SAVED_PORT=!SAVED_PORT: =!"
    )
)
goto CONTINUE_NORMAL

:QUICK_MODE
set "QUICK_MODE=1"
echo [%date% %time%] Quick mode enabled >> "%DEBUG_LOG%"
goto CONTINUE_NORMAL

:DNS_MODE
echo.
powershell -Command "Write-Host '  🌐 Starting DNS Server...' -ForegroundColor Cyan"
echo.
rem Ensure Node.js is available
call :ENSURE_NODE
if !errorLevel! NEQ 0 exit /b 1

set "SERVER_IP="
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /C:"IPv4"') do (
    for /f "tokens=1" %%b in ("%%a") do (
        if "!SERVER_IP!"=="" set "SERVER_IP=%%b"
    )
)
set "CUSTOM_HOST=wheel.local"
if exist "%CONFIG_FILE%" (
    for /f "tokens=2 delims=:," %%a in ('findstr /C:"hostname" "%CONFIG_FILE%"') do (
        set "CUSTOM_HOST=%%~a"
        set "CUSTOM_HOST=!CUSTOM_HOST: =!"
        set "CUSTOM_HOST=!CUSTOM_HOST:"=!"
    )
)
set "DNS_PORT=53"
set "SERVER_IP=%SERVER_IP%"
node scripts\dns-server.js
exit /b

:TRAY_MODE
echo.
powershell -Command "Write-Host '  🔲 Starting in System Tray Mode...' -ForegroundColor Cyan"
echo.
rem Ensure Node.js is available
call :ENSURE_NODE
if !errorLevel! NEQ 0 exit /b 1

rem Load hostname from config
set "TRAY_HOSTNAME=wheel.local"
set "TRAY_PORT=8080"
if exist "%CONFIG_FILE%" (
    for /f "tokens=2 delims=:," %%a in ('findstr /C:"hostname" "%CONFIG_FILE%"') do (
        set "TRAY_HOSTNAME=%%~a"
        set "TRAY_HOSTNAME=!TRAY_HOSTNAME: =!"
        set "TRAY_HOSTNAME=!TRAY_HOSTNAME:"=!"
    )
)
powershell -ExecutionPolicy Bypass -File "scripts\tray-server.ps1" -Hostname "!TRAY_HOSTNAME!" -Port !TRAY_PORT! -ScriptDir "%~dp0scripts"
exit /b

:SILENT_MODE
echo [%date% %time%] Silent mode starting >> "%DEBUG_LOG%"
rem Ensure Node.js is available
call :ENSURE_NODE
if !errorLevel! NEQ 0 exit /b 1

rem Load hostname from config
set "SILENT_HOSTNAME=wheel.local"
set "SILENT_PORT=8080"
if exist "%CONFIG_FILE%" (
    for /f "tokens=2 delims=:," %%a in ('findstr /C:"hostname" "%CONFIG_FILE%"') do (
        set "SILENT_HOSTNAME=%%~a"
        set "SILENT_HOSTNAME=!SILENT_HOSTNAME: =!"
        set "SILENT_HOSTNAME=!SILENT_HOSTNAME:"=!"
    )
)
rem Start watchdog in background (handles auto-recovery)
start /B powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "scripts\watchdog.ps1" -Hostname "!SILENT_HOSTNAME!" -Port !SILENT_PORT! -ProjectDir "%~dp0"
echo Server started in silent mode with auto-recovery.
echo Logs: logs\watchdog.log
exit /b

:UPDATE_CHECK_MODE
echo.
rem Ensure Node.js is available
call :ENSURE_NODE
if !errorLevel! NEQ 0 exit /b 1

node scripts\update-check.js
echo.
pause
exit /b

:NETWORK_DIAG_MODE
echo.
rem Ensure Node.js is available
call :ENSURE_NODE
if !errorLevel! NEQ 0 exit /b 1

set "DIAG_HOSTNAME=wheel.local"
set "DIAG_PORT=8080"
if exist "%CONFIG_FILE%" (
    for /f "tokens=2 delims=:," %%a in ('findstr /C:"hostname" "%CONFIG_FILE%"') do (
        set "DIAG_HOSTNAME=%%~a"
        set "DIAG_HOSTNAME=!DIAG_HOSTNAME: =!"
        set "DIAG_HOSTNAME=!DIAG_HOSTNAME:"=!"
    )
)
node scripts\network-diagnostics.js --hostname=!DIAG_HOSTNAME! --port=!DIAG_PORT!
echo.
pause
exit /b

:CONTINUE_NORMAL

rem ==============================================================
rem REQUEST ADMIN FIRST (to avoid window jump later)
rem ==============================================================

rem Skip elevation in test mode for automated testing
if "%TEST_MODE%"=="1" goto SKIP_EARLY_ELEVATION

net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo.
    powershell -Command "Write-Host '  🔐 ' -NoNewline; Write-Host 'Requesting Administrator privileges...' -ForegroundColor Yellow"
    echo.
    if "%~1"=="" (
        powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    ) else (
        powershell -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    )
    exit /b
)

:SKIP_EARLY_ELEVATION

rem ==============================================================
rem PRE-FLIGHT CHECKS
rem ==============================================================

echo.
powershell -Command "%PS_CYAN% '  🔍 PRE-FLIGHT SYSTEM CHECKS'"
echo.

rem Check Node.js installation (system or portable)
echo [%date% %time%] Checking Node.js... >> "%DEBUG_LOG%"
powershell -Command "Write-Host '  [1/7] ' -NoNewline; %PS_YELLOW% 'Checking Node.js...' -NoNewline"
set "USE_PORTABLE_NODE=0"
where node >nul 2>&1
if %errorLevel% EQU 0 goto FOUND_SYSTEM_NODE
rem System Node.js not found, check for portable
if exist "%PORTABLE_NODE_DIR%\node.exe" goto FOUND_PORTABLE_NODE
rem No Node.js found, auto-download portable
goto DOWNLOAD_NODE

:FOUND_SYSTEM_NODE
for /f "tokens=*" %%i in ('node --version') do set "NODE_VER=%%i"
powershell -Command "%PS_GREEN% ' Found !NODE_VER!'"
echo [%date% %time%] Node.js version: !NODE_VER! >> "%DEBUG_LOG%"
goto NODE_CHECK_DONE

:FOUND_PORTABLE_NODE
set "USE_PORTABLE_NODE=1"
set "PATH=%~dp0%PORTABLE_NODE_DIR%;%PATH%"
for /f "tokens=*" %%i in ('"%PORTABLE_NODE_DIR%\node.exe" --version') do set "NODE_VER=%%i"
powershell -Command "%PS_GREEN% ' Found !NODE_VER! (portable)'"
echo [%date% %time%] Using portable Node.js: !NODE_VER! >> "%DEBUG_LOG%"
goto NODE_CHECK_DONE

:DOWNLOAD_NODE
powershell -Command "%PS_YELLOW% ' Downloading...'"
echo [%date% %time%] Node.js not found, downloading portable... >> "%DEBUG_LOG%"
call :download_nodejs
if %errorLevel% NEQ 0 (
    powershell -Command "%PS_RED% '  ❌ Failed to download Node.js'"
    powershell -Command "%PS_YELLOW% '  📥 Manual install: https://nodejs.org'"
    pause
    exit /b 1
)
set "USE_PORTABLE_NODE=1"
set "PATH=%~dp0%PORTABLE_NODE_DIR%;%PATH%"
for /f "tokens=*" %%i in ('"%PORTABLE_NODE_DIR%\node.exe" --version') do set "NODE_VER=%%i"
powershell -Command "Write-Host '  [1/7] ' -NoNewline; %PS_GREEN% 'Node.js !NODE_VER! installed (portable)'"
echo [%date% %time%] Portable Node.js installed: !NODE_VER! >> "%DEBUG_LOG%"

:NODE_CHECK_DONE

rem Check npm installation
echo [%date% %time%] Checking npm... >> "%DEBUG_LOG%"
powershell -Command "Write-Host '  [2/7] ' -NoNewline; %PS_YELLOW% 'Checking npm...' -NoNewline"
if "%USE_PORTABLE_NODE%"=="1" goto CHECK_PORTABLE_NPM
goto CHECK_SYSTEM_NPM

:CHECK_PORTABLE_NPM
if exist "%PORTABLE_NODE_DIR%\npm.cmd" (
    for /f "tokens=*" %%i in ('call "%PORTABLE_NODE_DIR%\npm.cmd" --version') do set "NPM_VERSION=%%i"
    powershell -Command "%PS_GREEN% ' Found !NPM_VERSION! (portable)'"
    echo [%date% %time%] npm version: !NPM_VERSION! >> "%DEBUG_LOG%"
) else (
    powershell -Command "%PS_RED% ' NOT FOUND'"
    powershell -Command "%PS_RED% '  ❌ npm not found in portable Node.js'"
    pause
    exit /b 1
)
goto NPM_CHECK_DONE

:CHECK_SYSTEM_NPM
where npm >nul 2>&1
if %errorLevel% NEQ 0 (
    powershell -Command "%PS_RED% ' NOT FOUND'"
    powershell -Command "%PS_RED% '  ❌ npm is required but not installed'"
    powershell -Command "%PS_YELLOW% '  💡 npm should come with Node.js - please reinstall Node.js'"
    pause
    exit /b 1
) else (
    for /f "tokens=*" %%i in ('npm --version') do set "NPM_VERSION=%%i"
    powershell -Command "%PS_GREEN% ' Found !NPM_VERSION!'"
    echo [%date% %time%] npm version: !NPM_VERSION! >> "%DEBUG_LOG%"
)

:NPM_CHECK_DONE

rem Check package.json exists
echo [%date% %time%] Checking package.json... >> "%DEBUG_LOG%"
powershell -Command "Write-Host '  [3/7] ' -NoNewline; %PS_YELLOW% 'Checking package.json...' -NoNewline"
if not exist "package.json" (
    powershell -Command "%PS_RED% ' NOT FOUND'"
    echo.
    powershell -Command "%PS_RED% '  ❌ package.json not found in current directory'"
    echo.
    powershell -Command "%PS_YELLOW% '  🔍 Make sure you are running this from the project root'"
    echo    Current directory: %CD%
    echo.
    powershell -Command "%PS_YELLOW% '  📁 Required files in this directory:'"
    if exist "package.json" echo    ✓ package.json
    if exist "clone.js" echo    ✓ clone.js
    if exist "start-wheel-server.bat" echo    ✓ start-wheel-server.bat
    echo.
    pause
    exit /b 1
) else (
    powershell -Command "%PS_GREEN% ' Found'"
    echo [%date% %time%] package.json found >> "%DEBUG_LOG%"
)

rem Check dependencies
echo [%date% %time%] Checking dependencies... >> "%DEBUG_LOG%"
powershell -Command "Write-Host '  [4/7] ' -NoNewline; %PS_YELLOW% 'Checking dependencies...' -NoNewline"
if not exist "node_modules" (
    powershell -Command "%PS_YELLOW% ' Installing...'"
    echo [%date% %time%] Installing dependencies... >> "%DEBUG_LOG%"
    call npm install
    if !errorLevel! NEQ 0 (
        powershell -Command "%PS_RED% ' FAILED'"
        echo.
        powershell -Command "%PS_RED% '  ❌ Failed to install dependencies'"
        echo.
        powershell -Command "%PS_YELLOW% '  🔧 Try these steps:'"
        echo    1. Check internet connection
        echo    2. Run: npm cache clean --force
        echo    3. Run: npm install manually
        echo    4. Check if Node.js version is compatible
        echo.
        powershell -Command "%PS_YELLOW% '  📋 Debug info:'"
        echo    Node.js: %NODE_VERSION%
        echo    npm: %NPM_VERSION%
        echo    Directory: %CD%
        echo.
        pause
        exit /b 1
    )
    powershell -Command "%PS_GREEN% ' Installed'"
    echo [%date% %time%] Dependencies installed successfully >> "%DEBUG_LOG%"
) else (
    powershell -Command "%PS_GREEN% ' OK'"
    echo [%date% %time%] Dependencies already exist >> "%DEBUG_LOG%"
)

rem Check clone.js exists
echo [%date% %time%] Checking clone.js... >> "%DEBUG_LOG%"
powershell -Command "Write-Host '  [5/7] ' -NoNewline; %PS_YELLOW% 'Checking clone.js...' -NoNewline"
if not exist "clone.js" (
    powershell -Command "%PS_RED% ' NOT FOUND'"
    echo.
    powershell -Command "%PS_RED% '  ❌ clone.js not found - this is the main server file'"
    echo.
    powershell -Command "%PS_YELLOW% '  🔍 Please ensure all project files are present'"
    pause
    exit /b 1
) else (
    powershell -Command "%PS_GREEN% ' Found'"
    echo [%date% %time%] clone.js found >> "%DEBUG_LOG%"
)

rem Check Caddy.exe exists (auto-download if missing)
echo [%date% %time%] Checking Caddy... >> "%DEBUG_LOG%"
powershell -Command "Write-Host '  [6/7] ' -NoNewline; %PS_YELLOW% 'Checking Caddy...' -NoNewline"
if exist "caddy.exe" goto CADDY_EXISTS
powershell -Command "%PS_YELLOW% ' Downloading...'"
echo [%date% %time%] Caddy not found, downloading... >> "%DEBUG_LOG%"
call :download_caddy
if %errorLevel% NEQ 0 (
    powershell -Command "%PS_RED% '  ❌ Failed to download Caddy'"
    powershell -Command "%PS_YELLOW% '  📥 Manual download: https://caddyserver.com/download'"
    pause
    exit /b 1
)
powershell -Command "Write-Host '  [6/7] ' -NoNewline; %PS_GREEN% 'Caddy installed'"
echo [%date% %time%] Caddy installed successfully >> "%DEBUG_LOG%"
goto CADDY_CHECK_DONE
:CADDY_EXISTS
powershell -Command "%PS_GREEN% ' Found'"
echo [%date% %time%] Caddy found >> "%DEBUG_LOG%"
:CADDY_CHECK_DONE

rem Check port availability using PowerShell (simpler approach)
echo [%date% %time%] Checking port availability... >> "%DEBUG_LOG%"
powershell -Command "Write-Host '  [7/7] ' -NoNewline; %PS_YELLOW% 'Checking ports 8080-8090...' -NoNewline"
for /f %%p in ('powershell -Command "foreach ($p in 8080..8090) { $c = New-Object System.Net.Sockets.TcpClient; try { $c.Connect('127.0.0.1', $p); $c.Close() } catch { Write-Output $p; break } }"') do set "PORT_FOUND=%%p"
if "%PORT_FOUND%"=="" set "PORT_FOUND=0"
if "%PORT_FOUND%"=="0" (
    powershell -Command "%PS_YELLOW% ' All in use'"
    echo.
    powershell -Command "%PS_RED% '  ❌ No available ports found (8080-8090)'"
    powershell -Command "%PS_YELLOW% '  🔧 Close other applications using these ports'"
    pause
    exit /b 1
) else (
    powershell -Command "%PS_GREEN% ' Port !PORT_FOUND! available'"
    echo [%date% %time%] Port !PORT_FOUND! available >> "%DEBUG_LOG%"
)

echo.
powershell -Command "%PS_GREEN% '  ✅ All pre-flight checks passed!'"
echo.
powershell -Command "%PS_YELLOW% '  🚀 Starting Wheel of Names server...'"

rem ==============================================================
rem MAIN EXECUTION
rem ==============================================================

set "SCRIPT_PID="
set "NODE_PID="
set "CADDY_PID="
set "TEST_MODE=0"
set "LOCAL_IP="

rem Check for test mode argument
if /I "%~1"=="test" set "TEST_MODE=1"

cls
echo.
powershell -Command "%PS_CYAN% '  ╔══════════════════════════════════════════════════════╗'"
powershell -Command "%PS_CYAN% '  ║                                                      ║'"
powershell -Command "%PS_CYAN% '  ║        🎡  WHEEL OF NAMES - OFFLINE SERVER  🎡       ║'"
powershell -Command "%PS_CYAN% '  ║                                                      ║'"
powershell -Command "%PS_CYAN% '  ╚══════════════════════════════════════════════════════╝'"
echo.

rem 1. Verify Administrator (already elevated at start)
cd /d "%~dp0"
if "%TEST_MODE%"=="1" (
    powershell -Command "%PS_YELLOW% '  ⚠ Test Mode: Running without admin privileges'"
) else (
    powershell -Command "%PS_GREEN% '  ✓ Running as Administrator'"
)

rem Get current script PID for Guardian
echo [%date% %time%] Getting script PID... >> "%DEBUG_LOG%"
set "SCRIPT_PID="
for /f "tokens=2" %%a in ('tasklist /fi "imagename eq cmd.exe" /v ^| findstr /i "%~nx0"') do (
    set "SCRIPT_PID=%%a"
)
if "%SCRIPT_PID%"=="" (
    echo [%date% %time%] WARNING: Could not determine script PID >> "%DEBUG_LOG%"
    set "SCRIPT_PID=0"
)
echo [%date% %time%] Script PID: %SCRIPT_PID% >> "%DEBUG_LOG%"

rem Get local IP for remote control
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /C:"IPv4"') do (
    for /f "tokens=1" %%b in ("%%a") do (
        if "!LOCAL_IP!"=="" set "LOCAL_IP=%%b"
    )
)
if "%LOCAL_IP%"=="" set "LOCAL_IP=127.0.0.1"

echo.
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
powershell -Command "%PS_CYAN% '   SETUP PROGRESS'"
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
echo.

rem 2. Cleanup Existing Processes
echo [%date% %time%] Cleaning up old processes... >> "%DEBUG_LOG%"
powershell -Command "Write-Host '  [1/9] ' -NoNewline; %PS_YELLOW% 'Cleaning up old processes...' -NoNewline"
taskkill /F /IM node.exe >nul 2>&1
taskkill /F /IM caddy.exe >nul 2>&1
echo [%date% %time%] Process cleanup completed >> "%DEBUG_LOG%"
powershell -Command "%PS_GREEN% ' Done'"

rem 3. Check Dependencies
echo [%date% %time%] Checking dependencies... >> "%DEBUG_LOG%"
if not exist "node_modules" (
    echo [%date% %time%] Installing dependencies... >> "%DEBUG_LOG%"
    powershell -Command "Write-Host '  [2/9] ' -NoNewline; %PS_YELLOW% 'Installing dependencies...'"
    call npm install
    if !errorLevel! NEQ 0 (
        echo [%date% %time%] npm install failed with error !errorLevel! >> "%DEBUG_LOG%"
        powershell -Command "%PS_RED% '  ✗ npm install failed. Check Node.js installation.'"
        pause
        exit /b 1
    )
    echo [%date% %time%] Dependencies installed successfully >> "%DEBUG_LOG%"
    powershell -Command "%PS_GREEN% '        ✓ Dependencies installed'"
) else (
    echo [%date% %time%] Dependencies already exist >> "%DEBUG_LOG%"
    powershell -Command "Write-Host '  [2/9] ' -NoNewline; %PS_GREEN% 'Dependencies OK'"
)

rem 4. Set Hostname (skip prompt in test mode)
if "%TEST_MODE%"=="1" (
    set "HOSTNAME=localhost"
    set "EXTRA_HOSTNAMES="
    echo [%date% %time%] Test mode: using localhost >> "%DEBUG_LOG%"
    powershell -Command "Write-Host '  [3/9] ' -NoNewline; %PS_GREEN% 'Using hostname: localhost (test mode)'"
    goto SKIP_HOSTS_SETUP
)

rem Handle quick mode - use saved config without prompts
if "%QUICK_MODE%"=="1" (
    if not "!SAVED_HOSTNAME!"=="" (
        set "HOSTNAME=!SAVED_HOSTNAME!"
        set "EXTRA_HOSTNAMES="
        echo [%date% %time%] Quick mode: using saved hostname !HOSTNAME! >> "%DEBUG_LOG%"
        powershell -Command "Write-Host '  [3/9] ' -NoNewline; %PS_GREEN% 'Using saved hostname: !HOSTNAME! (quick mode)'"
        goto SKIP_HOSTNAME_PROMPT
    )
)

echo.
powershell -Command "%PS_CYAN% '  ┌──────────────────────────────────────────────────────┐'"
powershell -Command "%PS_CYAN% '  │  CUSTOM DOMAIN SETUP                                 │'"
powershell -Command "%PS_CYAN% '  └──────────────────────────────────────────────────────┘'"
echo.
set "HOSTNAME=wheel.local"
set "EXTRA_HOSTNAMES="
if not "!SAVED_HOSTNAME!"=="" set "HOSTNAME=!SAVED_HOSTNAME!"

powershell -Command "%PS_YELLOW% '    Enter primary domain name (or press Enter for default):'"
set /p "HOSTNAME=    [!HOSTNAME!]: "
if "!HOSTNAME!"=="" (
    if not "!SAVED_HOSTNAME!"=="" (
        set "HOSTNAME=!SAVED_HOSTNAME!"
    ) else (
        set "HOSTNAME=wheel.local"
    )
)

echo.
powershell -Command "%PS_YELLOW% '    Add extra domain aliases? (comma-separated, or press Enter to skip)'"
powershell -Command "%PS_YELLOW% '    Example: spin.local, raffle.local'"
set /p "EXTRA_HOSTNAMES=    Extra hostnames: "

rem Build full hostname list for Caddy
set "ALL_HOSTNAMES=!HOSTNAME!"
if not "!EXTRA_HOSTNAMES!"=="" (
    set "ALL_HOSTNAMES=!HOSTNAME!, !EXTRA_HOSTNAMES!"
)

echo.
echo [%date% %time%] Using hostnames: !ALL_HOSTNAMES! >> "%DEBUG_LOG%"
powershell -Command "Write-Host '  [3/9] ' -NoNewline; %PS_GREEN% 'Using hostnames: !HOSTNAME!'"
if not "!EXTRA_HOSTNAMES!"=="" (
    powershell -Command "%PS_GREEN% '                  + !EXTRA_HOSTNAMES!'"
)

rem Save config for quick mode (create if doesn't exist)
if not exist "%CONFIG_FILE%" (
    echo {"hostname":"!HOSTNAME!","hostnames":["!HOSTNAME!"],"preferredPort":8080,"enableDnsServer":false,"dnsPort":53,"autoOpenBrowser":true,"checkUpdatesOnStart":true,"lastUsed":null,"lastUpdateCheck":null} > "%CONFIG_FILE%"
)
powershell -Command "try { $c = Get-Content '%CONFIG_FILE%' -Raw | ConvertFrom-Json; $c.hostname = '!HOSTNAME!'; $c.hostnames = @('!HOSTNAME!'); $c.lastUsed = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'); $c | ConvertTo-Json | Set-Content '%CONFIG_FILE%' } catch { }"

:SKIP_HOSTNAME_PROMPT

rem 4. Update Hosts File (skip in test mode) - Add all hostnames
set "HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts"
powershell -Command "Write-Host '  [4/9] ' -NoNewline; %PS_YELLOW% 'Updating hosts file...' -NoNewline"
set "HOSTS_UPDATED=0"

rem Add primary hostname
findstr /C:"127.0.0.1 !HOSTNAME!" "%HOSTS_FILE%" >nul 2>&1
if !errorLevel! NEQ 0 (
    echo. >> "%HOSTS_FILE%"
    echo 127.0.0.1 !HOSTNAME! >> "%HOSTS_FILE%"
    set "HOSTS_UPDATED=1"
)

rem Add extra hostnames if any
if not "!EXTRA_HOSTNAMES!"=="" (
    for %%h in (!EXTRA_HOSTNAMES!) do (
        set "EXTRA_HOST=%%h"
        set "EXTRA_HOST=!EXTRA_HOST: =!"
        if not "!EXTRA_HOST!"=="" (
            findstr /C:"127.0.0.1 !EXTRA_HOST!" "%HOSTS_FILE%" >nul 2>&1
            if !errorLevel! NEQ 0 (
                echo 127.0.0.1 !EXTRA_HOST! >> "%HOSTS_FILE%"
                set "HOSTS_UPDATED=1"
            )
        )
    )
)

if "!HOSTS_UPDATED!"=="1" (
    powershell -Command "%PS_GREEN% ' Added'"
) else (
    powershell -Command "%PS_GREEN% ' OK (exists)'"
)

rem 4.5 Configure Firewall Rules
powershell -Command "Write-Host '  [5/9] ' -NoNewline; %PS_YELLOW% 'Configuring firewall...' -NoNewline"
set "FW_RULE_NAME=Wheel of Names Server"
netsh advfirewall firewall show rule name="%FW_RULE_NAME%" >nul 2>&1
if !errorLevel! NEQ 0 (
    rem Add firewall rules for HTTP, HTTPS, and Node port
    netsh advfirewall firewall add rule name="%FW_RULE_NAME%" dir=in action=allow protocol=tcp localport=80,443,8080-8090 >nul 2>&1
    if !errorLevel! EQU 0 (
        powershell -Command "%PS_GREEN% ' Added'"
        echo [%date% %time%] Firewall rules added >> "%DEBUG_LOG%"
    ) else (
        powershell -Command "%PS_YELLOW% ' Skipped (may need manual setup)'"
        echo [%date% %time%] Firewall rule creation failed >> "%DEBUG_LOG%"
    )
) else (
    powershell -Command "%PS_GREEN% ' OK (exists)'"
)

:SKIP_HOSTS_SETUP

rem 6. Check if port 8080 is available
set "PORT=8080"
:CHECK_PORT
netstat -an | findstr /C:":%PORT% " | findstr "LISTENING" >nul 2>&1
if %errorLevel% EQU 0 (
    set /a "PORT+=1"
    if !PORT! GTR 8100 (
        powershell -Command "%PS_RED% '  ✗ No available ports (8080-8100)'"
        pause
        exit /b 1
    )
    goto CHECK_PORT
)
powershell -Command "Write-Host '  [6/9] ' -NoNewline; %PS_GREEN% 'Port %PORT% available'"

rem 7. Generate Dynamic Caddyfile with HTTPS support (skip in test mode)
if "%TEST_MODE%"=="1" (
    echo [%date% %time%] Test mode: skipping Caddy setup >> "%DEBUG_LOG%"
    powershell -Command "Write-Host '  [7/9] ' -NoNewline; %PS_GREEN% 'Skipping Caddy (test mode)'"
    goto SKIP_CADDY_SETUP
)

rem Build Caddyfile with all hostnames
set "HTTPS_HOSTS=https://!HOSTNAME!"
set "HTTP_HOSTS=http://!HOSTNAME!"

rem Add extra hostnames to Caddy config
if not "!EXTRA_HOSTNAMES!"=="" (
    for %%h in (!EXTRA_HOSTNAMES!) do (
        set "EH=%%h"
        set "EH=!EH: =!"
        if not "!EH!"=="" (
            set "HTTPS_HOSTS=!HTTPS_HOSTS!, https://!EH!"
            set "HTTP_HOSTS=!HTTP_HOSTS!, http://!EH!"
        )
    )
)

rem Add LAN IP
set "HTTPS_HOSTS=!HTTPS_HOSTS!, https://!LOCAL_IP!"
set "HTTP_HOSTS=!HTTP_HOSTS!, http://!LOCAL_IP!"

(
    echo {
    echo     auto_https disable_redirects
    echo }
    echo.
    echo !HTTPS_HOSTS! {
    echo     tls internal
    echo     reverse_proxy localhost:!PORT!
    echo }
    echo.
    echo !HTTP_HOSTS! {
    echo     reverse_proxy localhost:!PORT!
    echo }
    echo.
    echo http://localhost:80 {
    echo     reverse_proxy localhost:!PORT!
    echo }
) > Caddyfile
powershell -Command "Write-Host '  [7/9] ' -NoNewline; %PS_GREEN% 'Caddyfile generated'"

:SKIP_CADDY_SETUP

rem 7. Setup logs directory
set "LOG_DIR=logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

rem 8. Trust Caddy certificate (with error handling) - skip in test mode
if "%TEST_MODE%"=="1" (
    echo [%date% %time%] Test mode: skipping certificate trust >> "%DEBUG_LOG%"
    powershell -Command "Write-Host '  [8/9] ' -NoNewline; %PS_GREEN% 'Skipping certificate trust (test mode)'"
    goto SKIP_CERT_TRUST
)

powershell -Command "Write-Host '  [8/9] ' -NoNewline; %PS_YELLOW% 'Trusting SSL certificate...' -NoNewline"
if not exist "caddy.exe" (
    powershell -Command "%PS_RED% ' FAILED (caddy.exe not found)'"
    pause
    exit /b 1
)
caddy.exe trust >nul 2>&1
if %errorLevel% NEQ 0 (
    powershell -Command "%PS_YELLOW% ' Warning (may show browser warning)'"
) else (
    powershell -Command "%PS_GREEN% ' Done'"
)

:SKIP_CERT_TRUST

rem 9. Start Node Server
if "%TEST_MODE%"=="1" (
    echo [%date% %time%] Test mode: starting Node server only >> "%DEBUG_LOG%"
    powershell -Command "Write-Host '  [9/9] ' -NoNewline; %PS_YELLOW% 'Starting Node server (test mode)...' -NoNewline"
) else (
    powershell -Command "Write-Host '  [9/9] ' -NoNewline; %PS_YELLOW% 'Starting servers...' -NoNewline"
)
set "NODE_LOG=%LOG_DIR%\node_server.log"
start /B cmd /c "set PORT=!PORT! && set CUSTOM_HOST=!HOSTNAME! && node clone.js serve > "%NODE_LOG%" 2>&1"

rem Wait briefly and get Node PID
timeout /t 2 /nobreak >nul
for /f "tokens=2" %%a in ('tasklist /fi "imagename eq node.exe" /fo list ^| findstr "PID"') do (
    set "NODE_PID=%%a"
)

rem 10. Start Caddy (skip in test mode)
if "%TEST_MODE%"=="1" (
    echo [%date% %time%] Test mode: skipping Caddy startup >> "%DEBUG_LOG%"
    powershell -Command "%PS_GREEN% ' Node server started'"
    goto SKIP_CADDY_START
)

set "CADDY_LOG=%LOG_DIR%\caddy.log"
start /B cmd /c "caddy.exe run --config Caddyfile > "%CADDY_LOG%" 2>&1"

rem Wait briefly and get Caddy PID
timeout /t 2 /nobreak >nul
for /f "tokens=2" %%a in ('tasklist /fi "imagename eq caddy.exe" /fo list ^| findstr "PID"') do (
    set "CADDY_PID=%%a"
)

rem 10.5. Start DNS Server (for network-wide custom URL access)
powershell -Command "Write-Host '  [+] ' -NoNewline -ForegroundColor Cyan; Write-Host 'Starting DNS server for network access...' -NoNewline -ForegroundColor Yellow"
set "DNS_LOG=%LOG_DIR%\dns_server.log"
set "DNS_PORT=53"
start /B cmd /c "set SERVER_IP=!LOCAL_IP! && set CUSTOM_HOST=!HOSTNAME! && set DNS_PORT=53 && node scripts\dns-server.js > "%DNS_LOG%" 2>&1"
timeout /t 1 /nobreak >nul
powershell -Command "Write-Host ' Started' -ForegroundColor Green"

rem 11. Start Guardian Process (monitors this script and kills children on exit)
set "GUARDIAN_SCRIPT=%LOG_DIR%\guardian.ps1"
(
    echo $parentPid = %SCRIPT_PID%
    echo $nodePid = %NODE_PID%
    echo $caddyPid = %CADDY_PID%
    echo while ($true^) {
    echo     Start-Sleep -Seconds 2
    echo     $parent = Get-Process -Id $parentPid -ErrorAction SilentlyContinue
    echo     if (-not $parent^) {
    echo         Write-Host '[Guardian] Parent exited. Cleaning up...'
    echo         Stop-Process -Name 'node' -Force -ErrorAction SilentlyContinue
    echo         Stop-Process -Name 'caddy' -Force -ErrorAction SilentlyContinue
    echo         exit
    echo     }
    echo }
) > "%GUARDIAN_SCRIPT%"
start /B /MIN powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "%GUARDIAN_SCRIPT%"

:SKIP_CADDY_START

rem 12. Wait for Services
call :wait_for_port %PORT% 30
if %errorLevel% NEQ 0 (
    powershell -Command "%PS_RED% ' FAILED'"
    powershell -Command "%PS_RED% '  ✗ Server failed to start. Check %NODE_LOG%'"
    goto CLEANUP
)
powershell -Command "%PS_GREEN% ' Running!'"

rem 13. Test Mode or Interactive Mode
if "%TEST_MODE%"=="1" (
    echo.
    powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
    powershell -Command "%PS_CYAN% '   TEST MODE'"
    powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
    if exist "scripts\test-performance.js" (
        node scripts\test-performance.js --port %PORT%
    ) else (
        powershell -Command "%PS_YELLOW% '  ⚠ Test script not found'"
    )
    goto CLEANUP
)

rem 14. Launch Browser
start https://!HOSTNAME!

:WAIT_LOOP
cls
echo.
powershell -Command "%PS_CYAN% '  ╔══════════════════════════════════════════════════════╗'"
powershell -Command "%PS_CYAN% '  ║                                                      ║'"
powershell -Command "%PS_CYAN% '  ║        🎡  WHEEL OF NAMES - OFFLINE SERVER  🎡       ║'"
powershell -Command "%PS_CYAN% '  ║                                                      ║'"
powershell -Command "%PS_CYAN% '  ╚══════════════════════════════════════════════════════╝'"
echo.
powershell -Command "%PS_GREEN% '  ✓ SERVER IS RUNNING'"
echo.
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
powershell -Command "%PS_CYAN% '   🖥️  THIS COMPUTER'"
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
echo.
powershell -Command "Write-Host '   Main URL:    ' -NoNewline; %PS_GREEN% 'https://!HOSTNAME!'"
powershell -Command "Write-Host '   HTTP:        ' -NoNewline; Write-Host 'http://!HOSTNAME!' -ForegroundColor White"
echo.
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
powershell -Command "%PS_CYAN% '   📱 OTHER DEVICES ON YOUR NETWORK'"
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
echo.
powershell -Command "Write-Host '   Direct IP:   ' -NoNewline; %PS_GREEN% 'https://%LOCAL_IP%'"
powershell -Command "Write-Host '   HTTP:        ' -NoNewline; Write-Host 'http://%LOCAL_IP%' -ForegroundColor White"
powershell -Command "Write-Host '   Remote:      ' -NoNewline; %PS_YELLOW% 'http://%LOCAL_IP%:%PORT%/remote'"
echo.
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
powershell -Command "%PS_CYAN% '   🌐 USE CUSTOM URL ON MOBILE (ONE-TIME SETUP)'"
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
echo.
powershell -Command "%PS_GREEN% '   ✓ DNS Server is running automatically!'"
echo.
powershell -Command "Write-Host '   To use ' -NoNewline; Write-Host 'http://!HOSTNAME!' -NoNewline -ForegroundColor Green; Write-Host ' on your phone:'"
echo.
powershell -Command "Write-Host '   1. Open WiFi settings on your phone' -ForegroundColor White"
powershell -Command "Write-Host '   2. Tap your WiFi network → Advanced/Configure' -ForegroundColor White"
powershell -Command "Write-Host '   3. Change DNS to: ' -NoNewline -ForegroundColor White; Write-Host '%LOCAL_IP%' -ForegroundColor Yellow"
powershell -Command "Write-Host '   4. Save and access: ' -NoNewline -ForegroundColor White; Write-Host 'http://!HOSTNAME!' -ForegroundColor Green"
echo.
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
powershell -Command "%PS_CYAN% '   ⚙️  SERVER INFO'"
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
echo.
powershell -Command "Write-Host '   Port:       ' -NoNewline; Write-Host '%PORT%' -ForegroundColor White"
powershell -Command "Write-Host '   Local IP:   ' -NoNewline; Write-Host '%LOCAL_IP%' -ForegroundColor White"
powershell -Command "Write-Host '   Hostname:   ' -NoNewline; Write-Host '!HOSTNAME!' -ForegroundColor White"
powershell -Command "Write-Host '   DNS Server: ' -NoNewline; Write-Host '%LOCAL_IP%:53' -ForegroundColor Green"
powershell -Command "Write-Host '   Logs:       ' -NoNewline; Write-Host '%LOG_DIR%\' -ForegroundColor White"
echo.
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
powershell -Command "%PS_CYAN% '   COMMANDS'"
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
echo.
powershell -Command "Write-Host '   [Q] ' -NoNewline -ForegroundColor Yellow; Write-Host 'Quit and stop server'"
powershell -Command "Write-Host '   [R] ' -NoNewline -ForegroundColor Yellow; Write-Host 'Refresh this display'"
powershell -Command "Write-Host '   [S] ' -NoNewline -ForegroundColor Yellow; Write-Host 'Show QR codes for mobile access'"
powershell -Command "Write-Host '   [N] ' -NoNewline -ForegroundColor Yellow; Write-Host 'Network diagnostics'"
powershell -Command "Write-Host '   [U] ' -NoNewline -ForegroundColor Yellow; Write-Host 'Check for updates'"
echo.
powershell -Command "%PS_CYAN% '  ═══════════════════════════════════════════════════════════'"
echo.

set /p "CHOICE=  Enter option: "
if /I "%CHOICE%"=="Q" goto CLEANUP
if /I "%CHOICE%"=="R" goto WAIT_LOOP
if /I "%CHOICE%"=="S" goto SHOW_QR
if /I "%CHOICE%"=="N" goto SHOW_NETWORK_DIAG
if /I "%CHOICE%"=="U" goto SHOW_UPDATE_CHECK
goto WAIT_LOOP

:SHOW_QR
cls
echo.
powershell -Command "%PS_CYAN% '  ╔══════════════════════════════════════════════════════╗'"
powershell -Command "%PS_CYAN% '  ║           📱 QR CODES FOR MOBILE ACCESS 📱           ║'"
powershell -Command "%PS_CYAN% '  ╚══════════════════════════════════════════════════════╝'"
echo.
node scripts\qr-display.js --port=%PORT% --hostname=!HOSTNAME! --ip=%LOCAL_IP%
echo.
powershell -Command "%PS_YELLOW% '  Press any key to return to main menu...'"
pause >nul
goto WAIT_LOOP

:SHOW_NETWORK_DIAG
cls
echo.
node scripts\network-diagnostics.js --hostname=!HOSTNAME! --port=%PORT%
echo.
powershell -Command "%PS_YELLOW% '  Press any key to return to main menu...'"
pause >nul
goto WAIT_LOOP

:SHOW_UPDATE_CHECK
cls
echo.
node scripts\update-check.js
echo.
powershell -Command "%PS_YELLOW% '  Press any key to return to main menu...'"
pause >nul
goto WAIT_LOOP

:CLEANUP
echo.
powershell -Command "%PS_YELLOW% '  ⏳ Shutting down...'"
taskkill /F /IM node.exe >nul 2>&1
taskkill /F /IM caddy.exe >nul 2>&1

powershell -Command "Write-Host '  ✓ ' -NoNewline -ForegroundColor Green; Write-Host 'Servers stopped'"

powershell -Command "Write-Host '  ⏳ ' -NoNewline; Write-Host 'Restoring hosts file...'"
rem FIX: Escape hostname for regex (periods become literal)
rem Skip hosts file cleanup in test mode or when HOSTS_FILE is empty
if "%TEST_MODE%"=="1" (
    echo [%date% %time%] Test mode: skipping hosts file cleanup >> "%DEBUG_LOG%"
    powershell -Command "Write-Host '  ✓ ' -NoNewline -ForegroundColor Green; Write-Host 'Hosts file cleanup skipped (test mode)'"
) else if "%HOSTS_FILE%"=="" (
    echo [%date% %time%] Hosts file path is empty, skipping cleanup >> "%DEBUG_LOG%"
    powershell -Command "Write-Host '  ✓ ' -NoNewline -ForegroundColor Green; Write-Host 'Hosts file cleanup skipped (no path)'"
) else (
    powershell -Command "$escaped = [regex]::Escape('127.0.0.1 !HOSTNAME!'); (Get-Content '%HOSTS_FILE%') | Where-Object { $_ -notmatch $escaped } | Set-Content '%HOSTS_FILE%'"
    powershell -Command "Write-Host '  ✓ ' -NoNewline -ForegroundColor Green; Write-Host 'Hosts file restored'"
)

powershell -Command "Write-Host '  ✓ ' -NoNewline -ForegroundColor Green; Write-Host 'All done! Goodbye.'"
echo.
if "%TEST_MODE%"=="0" (
    timeout /t 2 >nul
)
echo [%date% %time%] Script completed successfully >> "%DEBUG_LOG%"
exit /b 0

rem ============================================================
rem DIAGNOSTIC MODE
rem ============================================================

:DIAGNOSTIC_MODE
echo.
powershell -Command "Write-Host '  🔧 WHEEL OF NAMES - DIAGNOSTIC MODE' -ForegroundColor Cyan"
echo.
powershell -Command "Write-Host '  Running system checks without starting server...' -ForegroundColor Yellow"

rem Create logs directory for diagnostic mode
if not exist "logs" mkdir "logs"

rem Define colors for diagnostic mode
set "PS_GREEN=Write-Host -ForegroundColor Green"
set "PS_YELLOW=Write-Host -ForegroundColor Yellow"
set "PS_RED=Write-Host -ForegroundColor Red"
set "PS_CYAN=Write-Host -ForegroundColor Cyan"

echo [%date% %time%] Diagnostic mode started >> "%DEBUG_LOG%"

rem Run the same pre-flight checks
goto :PRE_FLIGHT_START

:PRE_FLIGHT_START
rem Check Node.js installation (system or portable)
echo [%date% %time%] Checking Node.js... >> "%DEBUG_LOG%"
powershell -Command "Write-Host '  [1/7] Checking Node.js...' -ForegroundColor Yellow -NoNewline"
where node >nul 2>&1
if %errorLevel% EQU 0 goto DIAG_NODE_SYSTEM
if exist "node-portable\node.exe" goto DIAG_NODE_PORTABLE
powershell -Command "Write-Host ' ⚠️ NOT FOUND (will auto-download)' -ForegroundColor Yellow"
goto DIAG_NODE_DONE
:DIAG_NODE_SYSTEM
for /f "tokens=*" %%i in ('node --version') do set "NODE_VER=%%i"
powershell -Command "Write-Host ' ✅ Found !NODE_VER!' -ForegroundColor Green"
goto DIAG_NODE_DONE
:DIAG_NODE_PORTABLE
for /f "tokens=*" %%i in ('"node-portable\node.exe" --version') do set "NODE_VER=%%i"
powershell -Command "Write-Host ' ✅ Found !NODE_VER! (portable)' -ForegroundColor Green"
:DIAG_NODE_DONE

rem Check npm installation
echo [%date% %time%] Checking npm... >> "%DEBUG_LOG%"
powershell -Command "Write-Host '  [2/7] Checking npm...' -ForegroundColor Yellow -NoNewline"
where npm >nul 2>&1
if %errorLevel% EQU 0 goto DIAG_NPM_SYSTEM
if exist "node-portable\npm.cmd" goto DIAG_NPM_PORTABLE
powershell -Command "Write-Host ' ⚠️ NOT FOUND (will auto-download with Node.js)' -ForegroundColor Yellow"
goto DIAG_NPM_DONE
:DIAG_NPM_SYSTEM
for /f "tokens=*" %%i in ('npm --version') do set "NPM_VER=%%i"
powershell -Command "Write-Host ' ✅ Found !NPM_VER!' -ForegroundColor Green"
goto DIAG_NPM_DONE
:DIAG_NPM_PORTABLE
powershell -Command "Write-Host ' ✅ Found (portable)' -ForegroundColor Green"
:DIAG_NPM_DONE

rem Check package.json exists
echo [%date% %time%] Checking package.json... >> "%DEBUG_LOG%"
powershell -Command "Write-Host '  [3/7] Checking package.json...' -ForegroundColor Yellow -NoNewline"
if exist "package.json" (
    powershell -Command "Write-Host ' ✅ Found' -ForegroundColor Green"
) else (
    powershell -Command "Write-Host ' ❌ NOT FOUND' -ForegroundColor Red"
    powershell -Command "Write-Host '     Run from project directory' -ForegroundColor Red"
)

rem Check dependencies
echo [%date% %time%] Checking dependencies... >> "%DEBUG_LOG%"
powershell -Command "Write-Host '  [4/7] Checking dependencies...' -ForegroundColor Yellow -NoNewline"
if exist "node_modules" (
    powershell -Command "Write-Host ' ✅ Installed' -ForegroundColor Green"
) else (
    powershell -Command "Write-Host ' ⚠️ NOT INSTALLED (will auto-install)' -ForegroundColor Yellow"
)

rem Check clone.js exists
echo [%date% %time%] Checking clone.js... >> "%DEBUG_LOG%"
powershell -Command "Write-Host '  [5/7] Checking clone.js...' -ForegroundColor Yellow -NoNewline"
if exist "clone.js" (
    powershell -Command "Write-Host ' ✅ Found' -ForegroundColor Green"
) else (
    powershell -Command "Write-Host ' ❌ NOT FOUND' -ForegroundColor Red"
    powershell -Command "Write-Host '     Main server file missing' -ForegroundColor Red"
)

rem Check Caddy exists
echo [%date% %time%] Checking Caddy... >> "%DEBUG_LOG%"
powershell -Command "Write-Host '  [6/7] Checking Caddy...' -ForegroundColor Yellow -NoNewline"
if exist "caddy.exe" (
    powershell -Command "Write-Host ' ✅ Found' -ForegroundColor Green"
) else (
    powershell -Command "Write-Host ' ⚠️ NOT FOUND (will auto-download)' -ForegroundColor Yellow"
)

rem Check port availability using PowerShell (simpler, avoids batch issues)
echo [%date% %time%] Checking port availability... >> "%DEBUG_LOG%"
powershell -Command "Write-Host '  [7/7] Checking ports 8080-8090...' -ForegroundColor Yellow -NoNewline"
for /f %%p in ('powershell -Command "foreach ($p in 8080..8090) { $c = New-Object System.Net.Sockets.TcpClient; try { $c.Connect('127.0.0.1', $p); $c.Close() } catch { Write-Output $p; break } }"') do set "PORT_FOUND=%%p"
if "%PORT_FOUND%"=="" set "PORT_FOUND=0"
if "%PORT_FOUND%"=="0" (
    powershell -Command "Write-Host ' ❌ ALL IN USE' -ForegroundColor Red"
    powershell -Command "Write-Host '     Close other applications' -ForegroundColor Red"
) else (
    powershell -Command "Write-Host ' ✅ Port %PORT_FOUND% available' -ForegroundColor Green"
)

echo.
powershell -Command "Write-Host '  📋 DIAGNOSTIC SUMMARY' -ForegroundColor Cyan"
echo.
powershell -Command "Write-Host '  ✅ = Ready' -ForegroundColor Green"
powershell -Command "Write-Host '  ⚠️  = Will auto-download/install when you run the script' -ForegroundColor Yellow"
powershell -Command "Write-Host '  ❌ = Critical file missing (must fix manually)' -ForegroundColor Red"
echo.
powershell -Command "Write-Host '  Run: start-wheel-server.bat' -ForegroundColor Cyan"
powershell -Command "Write-Host '  Everything except custom URL is fully automated!' -ForegroundColor Green"
echo.
powershell -Command "Write-Host '  📁 Debug logs: logs\debug-*.log' -ForegroundColor Yellow"
echo.
pause
exit /b 0

rem ============================================================
rem HELP MODE
rem ============================================================

:HELP_MODE
echo.
powershell -Command "%PS_CYAN% '  📖 WHEEL OF NAMES - HELP'"
echo.
powershell -Command "%PS_YELLOW% '  USAGE:'"
echo    start-wheel-server.bat           [Start interactive mode]
echo    start-wheel-server.bat quick     [Quick start - use saved config]
echo    start-wheel-server.bat tray      [System tray mode with auto-recovery]
echo    start-wheel-server.bat silent    [Background mode with watchdog]
echo    start-wheel-server.bat dns       [Start DNS server for network]
echo    start-wheel-server.bat update    [Check for updates]
echo    start-wheel-server.bat network   [Network diagnostics]
echo    start-wheel-server.bat test      [Run automated tests]
echo    start-wheel-server.bat --check   [Run system checks]
echo    start-wheel-server.bat --help    [Show this help]
echo.
powershell -Command "%PS_GREEN% '  ✨ NEW PC? JUST RUN THE SCRIPT!'"
echo    The script automatically downloads and installs:
echo      • Node.js (portable, ~30MB)
echo      • Caddy web server (~45MB)
echo      • All npm dependencies
echo.
echo    Only interactive prompt: Custom domain name (default: wheel.local)
echo.
powershell -Command "%PS_YELLOW% '  📱 OTHER DEVICES ON YOUR NETWORK:'"
echo    Method 1: Use IP directly
echo       → Other devices can access via https://YOUR_IP
echo.
echo    Method 2: Setup custom URL on each device
echo       → Copy setup-client.bat to the device
echo       → Run: setup-client.bat SERVER_IP wheel.local
echo.
echo    Method 3: Run DNS server (automatic for all devices)
echo       → Run: start-wheel-server.bat dns
echo       → Set other devices' DNS to this computer's IP
echo.
powershell -Command "%PS_YELLOW% '  🚀 QUICK MODE:'"
echo    After first run, use "quick" to skip prompts:
echo       → start-wheel-server.bat quick
echo    Settings are saved in config.json
echo.
powershell -Command "%PS_YELLOW% '  TROUBLESHOOTING:'"
echo    ❌ Script closes immediately?
echo       → Run: start-wheel-server.bat --check
echo.
echo    ❌ Port already in use?
echo       → Script automatically finds next available port (8080-8100)
echo.
echo    ❌ Permission denied?
echo       → Script requests admin privileges automatically
echo.
echo    ❌ Other devices can't connect?
echo       → Firewall rules are auto-configured (ports 80, 443, 8080-8090)
echo       → Try: start-wheel-server.bat dns
echo.
powershell -Command "%PS_YELLOW% '  🔲 SYSTEM TRAY MODE:'"
echo    Minimize to tray with auto-recovery:
echo       → start-wheel-server.bat tray
echo    Double-click tray icon to open browser.
echo    Right-click for menu options.
echo.
powershell -Command "%PS_YELLOW% '  📱 QR CODE ACCESS:'"
echo    While server is running, press [S] to show QR codes
echo    for easy mobile device access.
echo.
powershell -Command "%PS_YELLOW% '  🌐 MULTIPLE HOSTNAMES:'"
echo    You can set up multiple domain aliases during setup.
echo    Example: wheel.local, spin.local, raffle.local
echo    All will point to the same wheel interface.
echo.
powershell -Command "%PS_YELLOW% '  🔄 UPDATE CHECK:'"
echo    Check for new versions:
echo       → start-wheel-server.bat update
echo    Or press [U] while server is running.
echo.
powershell -Command "%PS_YELLOW% '  🔍 NETWORK DIAGNOSTICS:'"
echo    Troubleshoot connectivity issues:
echo       → start-wheel-server.bat network
echo    Or press [N] while server is running.
echo.
powershell -Command "%PS_YELLOW% '  LOGS LOCATION:'"
echo    Debug logs: logs\debug-*.log
echo    Server logs: logs\node_server.log
echo    Caddy logs: logs\caddy.log
echo.
powershell -Command "%PS_CYAN% '  🌐 For more help: https://github.com/elstonyth/Wheel-of-Name---Offline'"
echo.
pause
exit /b 0

rem ============================================================
rem SUBROUTINES
rem ============================================================

:ENSURE_NODE
rem Ensures Node.js is available (system or portable), downloads if needed
rem Also ensures npm dependencies are installed and Caddy is present
where node >nul 2>&1
if %errorLevel% EQU 0 goto :ENSURE_NODE_FOUND
rem Check for portable node
if exist "%PORTABLE_NODE_DIR%\node.exe" (
    set "PATH=%~dp0%PORTABLE_NODE_DIR%;%PATH%"
    goto :ENSURE_NODE_FOUND
)
rem Need to download Node.js
echo   Node.js not found. Downloading portable version...
call :download_nodejs
if %errorLevel% NEQ 0 (
    echo   ERROR: Failed to download Node.js
    echo   Please install Node.js manually from https://nodejs.org
    exit /b 1
)
set "PATH=%~dp0%PORTABLE_NODE_DIR%;%PATH%"

:ENSURE_NODE_FOUND
rem Check if dependencies are installed
if not exist "node_modules" (
    echo   Installing dependencies...
    if exist "%PORTABLE_NODE_DIR%\npm.cmd" (
        call "%PORTABLE_NODE_DIR%\npm.cmd" install
    ) else (
        call npm install
    )
    if !errorLevel! NEQ 0 (
        echo   ERROR: Failed to install dependencies
        exit /b 1
    )
)
rem Check if Caddy is installed
if not exist "caddy.exe" (
    echo   Caddy not found. Downloading...
    call :download_caddy
    if !errorLevel! NEQ 0 (
        echo   WARNING: Failed to download Caddy. HTTPS may not work.
    )
)
rem Ensure Caddyfile exists (create basic one if missing)
if not exist "Caddyfile" (
    echo   Creating default Caddyfile...
    echo { > Caddyfile
    echo     auto_https disable_redirects >> Caddyfile
    echo } >> Caddyfile
    echo. >> Caddyfile
    echo http://localhost:80 { >> Caddyfile
    echo     reverse_proxy localhost:8080 >> Caddyfile
    echo } >> Caddyfile
)
exit /b 0

:wait_for_port
rem Usage: call :wait_for_port PORT TIMEOUT_SECONDS
set "_port=%~1"
set "_timeout=%~2"
set "_elapsed=0"
:wait_loop_inner
powershell -Command "try { $c = New-Object System.Net.Sockets.TcpClient; $ar = $c.BeginConnect('127.0.0.1', %_port%, $null, $null); $w = $ar.AsyncWaitHandle.WaitOne(1000, $false); if ($w) { $c.EndConnect($ar); $c.Close(); exit 0 } else { $c.Close(); exit 1 } } catch { exit 1 }" >nul 2>&1
if %errorLevel% EQU 0 (
    exit /b 0
)
set /a "_elapsed+=1"
if %_elapsed% GEQ %_timeout% (
    exit /b 1
)
timeout /t 1 /nobreak >nul
goto wait_loop_inner

:download_nodejs
rem Downloads and extracts portable Node.js
echo    Downloading Node.js v%NODE_VERSION% (~30MB)...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri '%NODE_URL%' -OutFile '%NODE_ZIP%' -UseBasicParsing } catch { Write-Host 'Download failed:' $_.Exception.Message; exit 1 }"
if %errorLevel% NEQ 0 (
    echo [%date% %time%] Node.js download failed >> "%DEBUG_LOG%"
    exit /b 1
)
echo    Extracting...
powershell -Command "Expand-Archive -Path '%NODE_ZIP%' -DestinationPath '.' -Force"
if %errorLevel% NEQ 0 (
    del "%NODE_ZIP%" 2>nul
    echo [%date% %time%] Node.js extraction failed >> "%DEBUG_LOG%"
    exit /b 1
)
rem Rename extracted folder to node-portable
if exist "node-v%NODE_VERSION%-%NODE_ARCH%" (
    if exist "%PORTABLE_NODE_DIR%" rd /s /q "%PORTABLE_NODE_DIR%"
    ren "node-v%NODE_VERSION%-%NODE_ARCH%" "%PORTABLE_NODE_DIR%"
)
del "%NODE_ZIP%" 2>nul
echo [%date% %time%] Node.js portable installed >> "%DEBUG_LOG%"
exit /b 0

:download_caddy
rem Downloads and extracts Caddy server
echo    Downloading Caddy v%CADDY_VERSION% (~45MB)...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri '%CADDY_URL%' -OutFile '%CADDY_ZIP%' -UseBasicParsing } catch { Write-Host 'Download failed:' $_.Exception.Message; exit 1 }"
if %errorLevel% NEQ 0 (
    echo [%date% %time%] Caddy download failed >> "%DEBUG_LOG%"
    exit /b 1
)
echo    Extracting...
powershell -Command "Expand-Archive -Path '%CADDY_ZIP%' -DestinationPath '.' -Force"
if %errorLevel% NEQ 0 (
    del "%CADDY_ZIP%" 2>nul
    echo [%date% %time%] Caddy extraction failed >> "%DEBUG_LOG%"
    exit /b 1
)
del "%CADDY_ZIP%" 2>nul
echo [%date% %time%] Caddy installed >> "%DEBUG_LOG%"
exit /b 0
