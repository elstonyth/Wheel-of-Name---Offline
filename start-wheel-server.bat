@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1
title Wheel of Names - Offline Server

rem ==============================================================
rem Wheel of Names Offline - Launcher & Manager
rem ==============================================================

rem DEBUG: Add immediate pause to catch early errors
if "%DEBUG_PAUSE%"=="1" pause

rem DEBUG: Create debug log
set "DEBUG_LOG=logs\debug-%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%%time:~6,2%.log"
set "DEBUG_LOG=%DEBUG_LOG: =0%"
if not exist "logs" mkdir "logs"
echo [%date% %time%] Script started >> "%DEBUG_LOG%"

set "SCRIPT_PID="
set "NODE_PID="
set "CADDY_PID="
set "TEST_MODE=0"
set "LOCAL_IP="

rem Check for test mode argument
if /I "%~1"=="test" set "TEST_MODE=1"

rem Colors via PowerShell helper
set "PS_GREEN=Write-Host -ForegroundColor Green"
set "PS_YELLOW=Write-Host -ForegroundColor Yellow"
set "PS_RED=Write-Host -ForegroundColor Red"
set "PS_CYAN=Write-Host -ForegroundColor Cyan"

cls
echo.
powershell -Command "%PS_CYAN% '  ╔══════════════════════════════════════════════════════╗'"
powershell -Command "%PS_CYAN% '  ║                                                      ║'"
powershell -Command "%PS_CYAN% '  ║        🎡  WHEEL OF NAMES - OFFLINE SERVER  🎡       ║'"
powershell -Command "%PS_CYAN% '  ║                                                      ║'"
powershell -Command "%PS_CYAN% '  ╚══════════════════════════════════════════════════════╝'"
echo.

rem 1. Check for Administrator Privileges and Auto-Elevate
rem Skip elevation in test mode for automated testing
if "%TEST_MODE%"=="1" (
    echo [%date% %time%] Test mode detected, skipping admin elevation >> "%DEBUG_LOG%"
    powershell -Command "%PS_YELLOW% '  ⚠ Test Mode: Running without admin privileges'"
    goto SKIP_ELEVATION
)

echo [%date% %time%] Checking admin privileges... >> "%DEBUG_LOG%"
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [%date% %time%] Admin check failed, attempting elevation... >> "%DEBUG_LOG%"
    powershell -Command "%PS_YELLOW% '  ⏳ Requesting Administrator privileges...'"
    echo [%date% %time%] Arguments: %* >> "%DEBUG_LOG%"
    echo [%date% %time%] Script path: %~f0 >> "%DEBUG_LOG%"
    if "%~1"=="" (
        powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    ) else (
        powershell -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    )
    echo [%date% %time%] Elevation command executed, exiting... >> "%DEBUG_LOG%"
    exit /b
)
echo [%date% %time%] Running as administrator >> "%DEBUG_LOG%"

:SKIP_ELEVATION

cd /d "%~dp0"
echo [%date% %time%] Changed directory to: %CD% >> "%DEBUG_LOG%"
if %errorLevel% NEQ 0 (
    echo [%date% %time%] ERROR: Failed to change directory >> "%DEBUG_LOG%"
    powershell -Command "%PS_RED% '  ✗ Failed to change to script directory'"
    pause
    exit /b 1
)
powershell -Command "%PS_GREEN% '  ✓ Running as Administrator'"

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
powershell -Command "Write-Host '  [1/8] ' -NoNewline; %PS_YELLOW% 'Cleaning up old processes...' -NoNewline"
taskkill /F /IM node.exe >nul 2>&1
taskkill /F /IM caddy.exe >nul 2>&1
echo [%date% %time%] Process cleanup completed >> "%DEBUG_LOG%"
powershell -Command "%PS_GREEN% ' Done'"

rem 3. Check Dependencies
echo [%date% %time%] Checking dependencies... >> "%DEBUG_LOG%"
if not exist "node_modules" (
    echo [%date% %time%] Installing dependencies... >> "%DEBUG_LOG%"
    powershell -Command "Write-Host '  [2/8] ' -NoNewline; %PS_YELLOW% 'Installing dependencies...'"
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
    powershell -Command "Write-Host '  [2/8] ' -NoNewline; %PS_GREEN% 'Dependencies OK'"
)

rem 4. Set Hostname (skip prompt in test mode)
if "%TEST_MODE%"=="1" (
    set "HOSTNAME=localhost"
    echo [%date% %time%] Test mode: using localhost >> "%DEBUG_LOG%"
    powershell -Command "Write-Host '  [3/8] ' -NoNewline; %PS_GREEN% 'Using hostname: localhost (test mode)'"
    goto SKIP_HOSTS_SETUP
) else (
    echo.
    powershell -Command "%PS_CYAN% '  ┌──────────────────────────────────────────────────────┐'"
    powershell -Command "%PS_CYAN% '  │  CUSTOM DOMAIN SETUP                                 │'"
    powershell -Command "%PS_CYAN% '  └──────────────────────────────────────────────────────┘'"
    echo.
    set "HOSTNAME=wheel.local"
    set /p "HOSTNAME=    Enter domain name [wheel.local]: "
    if "!HOSTNAME!"=="" set "HOSTNAME=wheel.local"
    echo.
    powershell -Command "Write-Host '  [3/8] ' -NoNewline; %PS_GREEN% 'Using hostname: %HOSTNAME%'"
)

rem 4. Update Hosts File (skip in test mode)
set "HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts"
powershell -Command "Write-Host '  [4/8] ' -NoNewline; %PS_YELLOW% 'Updating hosts file...' -NoNewline"
findstr /C:"127.0.0.1 %HOSTNAME%" "%HOSTS_FILE%" >nul 2>&1
if %errorLevel% NEQ 0 (
    echo. >> "%HOSTS_FILE%"
    echo 127.0.0.1 %HOSTNAME% >> "%HOSTS_FILE%"
    powershell -Command "%PS_GREEN% ' Added'"
) else (
    powershell -Command "%PS_GREEN% ' OK (exists)'"
)

:SKIP_HOSTS_SETUP

rem 5. Check if port 8080 is available
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
powershell -Command "Write-Host '  [5/8] ' -NoNewline; %PS_GREEN% 'Port %PORT% available'"

rem 6. Generate Dynamic Caddyfile with HTTPS support (skip in test mode)
if "%TEST_MODE%"=="1" (
    echo [%date% %time%] Test mode: skipping Caddy setup >> "%DEBUG_LOG%"
    powershell -Command "Write-Host '  [6/8] ' -NoNewline; %PS_GREEN% 'Skipping Caddy (test mode)'"
    goto SKIP_CADDY_SETUP
)

(
    echo {
    echo     auto_https disable_redirects
    echo }
    echo.
    echo https://%HOSTNAME% {
    echo     tls internal
    echo     reverse_proxy localhost:%PORT%
    echo }
    echo.
    echo http://%HOSTNAME% {
    echo     reverse_proxy localhost:%PORT%
    echo }
    echo.
    echo http://localhost:80 {
    echo     reverse_proxy localhost:%PORT%
    echo }
) > Caddyfile
powershell -Command "Write-Host '  [6/8] ' -NoNewline; %PS_GREEN% 'Caddyfile generated'"

:SKIP_CADDY_SETUP

rem 7. Setup logs directory
set "LOG_DIR=logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

rem 8. Trust Caddy certificate (with error handling) - skip in test mode
if "%TEST_MODE%"=="1" (
    echo [%date% %time%] Test mode: skipping certificate trust >> "%DEBUG_LOG%"
    powershell -Command "Write-Host '  [7/8] ' -NoNewline; %PS_GREEN% 'Skipping certificate trust (test mode)'"
    goto SKIP_CERT_TRUST
)

powershell -Command "Write-Host '  [7/8] ' -NoNewline; %PS_YELLOW% 'Trusting SSL certificate...' -NoNewline"
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
    powershell -Command "Write-Host '  [8/8] ' -NoNewline; %PS_YELLOW% 'Starting Node server (test mode)...' -NoNewline"
) else (
    powershell -Command "Write-Host '  [8/8] ' -NoNewline; %PS_YELLOW% 'Starting servers...' -NoNewline"
)
set "NODE_LOG=%LOG_DIR%\node_server.log"
start /B cmd /c "set PORT=%PORT% && node clone.js serve > "%NODE_LOG%" 2>&1"

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
start https://%HOSTNAME%

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
powershell -Command "%PS_CYAN% '   ACCESS URLS'"
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
echo.
powershell -Command "Write-Host '   🌐 Main Display:  ' -NoNewline; %PS_GREEN% 'https://%HOSTNAME%'"
powershell -Command "Write-Host '   🌐 HTTP Access:   ' -NoNewline; Write-Host 'http://%HOSTNAME%' -ForegroundColor White"
echo.
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
powershell -Command "%PS_CYAN% '   📱 REMOTE CONTROL (open on your phone)'"
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
echo.
powershell -Command "Write-Host '   📱 Remote URL:    ' -NoNewline; %PS_YELLOW% 'http://%LOCAL_IP%:%PORT%/remote'"
echo.
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
powershell -Command "%PS_CYAN% '   ⚙️  SERVER INFO'"
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
echo.
powershell -Command "Write-Host '   Port:     ' -NoNewline; Write-Host '%PORT%' -ForegroundColor White"
powershell -Command "Write-Host '   Local IP: ' -NoNewline; Write-Host '%LOCAL_IP%' -ForegroundColor White"
powershell -Command "Write-Host '   Logs:     ' -NoNewline; Write-Host '%LOG_DIR%\' -ForegroundColor White"
echo.
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
powershell -Command "%PS_CYAN% '   HOW TO STOP'"
powershell -Command "%PS_CYAN% '  ─────────────────────────────────────────────────────────'"
echo.
powershell -Command "Write-Host '   [Q] ' -NoNewline -ForegroundColor Yellow; Write-Host 'Type Q + Enter to stop cleanly'"
powershell -Command "Write-Host '   [X] ' -NoNewline -ForegroundColor Yellow; Write-Host 'Close window (auto-cleanup enabled)'"
echo.
powershell -Command "%PS_CYAN% '  ═══════════════════════════════════════════════════════════'"
echo.

set /p "CHOICE=  Enter option (Q to quit): "
if /I "%CHOICE%"=="Q" goto CLEANUP
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
    set "ESCAPED_HOSTNAME=%HOSTNAME:.=\.%"
    powershell -Command "$escaped = [regex]::Escape('127.0.0.1 %HOSTNAME%'); (Get-Content '%HOSTS_FILE%') | Where-Object { $_ -notmatch $escaped } | Set-Content '%HOSTS_FILE%'"
    powershell -Command "Write-Host '  ✓ ' -NoNewline -ForegroundColor Green; Write-Host 'Hosts file restored'"
)

powershell -Command "Write-Host '  ✓ ' -NoNewline -ForegroundColor Green; Write-Host 'Hosts file restored'"
echo.
powershell -Command "%PS_GREEN% '  ✓ All done! Goodbye.'"
echo.
if "%TEST_MODE%"=="0" (
    timeout /t 2 >nul
)
echo [%date% %time%] Script completed successfully >> "%DEBUG_LOG%"
exit /b 0

rem ============================================================
rem SUBROUTINES
rem ============================================================

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
