@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ==============================================================
rem Wheel of Names Offline - Launcher & Manager
rem ==============================================================
rem Usage: start-wheel-server.bat [test]
rem   - No args: Interactive mode with browser launch
rem   - test: Automated test mode with Puppeteer
rem ==============================================================

set "SCRIPT_PID="
set "NODE_PID="
set "CADDY_PID="
set "TEST_MODE=0"

rem Check for test mode argument
if /I "%~1"=="test" set "TEST_MODE=1"

rem 1. Check for Administrator Privileges and Auto-Elevate
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [INFO] Requesting Administrator privileges...
    set "_ARGS=%*"
    powershell -Command "Start-Process -FilePath '%~f0' -ArgumentList '%_ARGS%' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
echo [INFO] Running as Administrator.

rem Get current script PID for Guardian
for /f "tokens=2" %%a in ('tasklist /fi "imagename eq cmd.exe" /v ^| findstr /i "%~nx0"') do (
    set "SCRIPT_PID=%%a"
)

rem 2. Cleanup Existing Processes
echo [INFO] Cleaning up old processes...
taskkill /F /IM node.exe >nul 2>&1
taskkill /F /IM caddy.exe >nul 2>&1

rem 3. Check Dependencies
if not exist "node_modules" (
    echo [INFO] Installing dependencies...
    call npm install
    if !errorLevel! NEQ 0 (
        echo [ERROR] npm install failed. Please check your Node.js installation.
        pause
        exit /b 1
    )
)

rem 4. Set Hostname (skip prompt in test mode)
if "%TEST_MODE%"=="1" (
    set "HOSTNAME=wheel.local"
    echo [INFO] Test mode: Using default hostname wheel.local
) else (
    echo.
    echo ============================================================
    echo   CUSTOM URL SETUP
    echo ============================================================
    echo.
    set "HOSTNAME=wheel.local"
    set /p "HOSTNAME=Enter desired domain name (default: wheel.local): "
)
echo.
echo [INFO] Using hostname: %HOSTNAME%

rem 5. Update Hosts File
set "HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts"
echo [INFO] Updating hosts file...
findstr /C:"127.0.0.1 %HOSTNAME%" "%HOSTS_FILE%" >nul 2>&1
if %errorLevel% NEQ 0 (
    echo. >> "%HOSTS_FILE%"
    echo 127.0.0.1 %HOSTNAME% >> "%HOSTS_FILE%"
    echo [SUCCESS] Added %HOSTNAME% to hosts file.
) else (
    echo [INFO] %HOSTNAME% already exists in hosts file.
)

rem 6. Check if port 8080 is available
echo [INFO] Checking port 8080 availability...
set "PORT=8080"
:CHECK_PORT
netstat -an | findstr /C:":%PORT% " | findstr "LISTENING" >nul 2>&1
if %errorLevel% EQU 0 (
    echo [WARN] Port %PORT% is in use. Trying port !PORT!+1...
    set /a "PORT+=1"
    if !PORT! GTR 8100 (
        echo [ERROR] No available ports found between 8080-8100.
        pause
        exit /b 1
    )
    goto CHECK_PORT
)
echo [INFO] Using port %PORT%

rem 7. Generate Dynamic Caddyfile with HTTPS support
echo [INFO] Generating Caddyfile...
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

rem 8. Setup logs directory
set "LOG_DIR=logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

rem 9. Trust Caddy certificate (with error handling)
echo [INFO] Trusting Caddy root certificate...
if not exist "caddy.exe" (
    echo [ERROR] caddy.exe not found!
    pause
    exit /b 1
)
caddy.exe trust >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [WARN] Caddy trust command failed. HTTPS may show certificate warnings.
)

rem 10. Start Node Server
echo [INFO] Starting Node server on port %PORT%...
set "NODE_LOG=%LOG_DIR%\node_server.log"
start /B cmd /c "set PORT=%PORT% && node clone.js serve > "%NODE_LOG%" 2>&1"

rem Wait briefly and get Node PID
timeout /t 2 /nobreak >nul
for /f "tokens=2" %%a in ('tasklist /fi "imagename eq node.exe" /fo list ^| findstr "PID"') do (
    set "NODE_PID=%%a"
)

rem 11. Start Caddy
echo [INFO] Starting Caddy...
set "CADDY_LOG=%LOG_DIR%\caddy.log"
start /B cmd /c "caddy.exe run --config Caddyfile > "%CADDY_LOG%" 2>&1"

rem Wait briefly and get Caddy PID
timeout /t 2 /nobreak >nul
for /f "tokens=2" %%a in ('tasklist /fi "imagename eq caddy.exe" /fo list ^| findstr "PID"') do (
    set "CADDY_PID=%%a"
)

rem 12. Start Guardian Process (monitors this script and kills children on exit)
echo [INFO] Starting Guardian process...
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

rem 13. Wait for Services
echo [INFO] Waiting for services to start...
call :wait_for_port %PORT% 30
if %errorLevel% NEQ 0 (
    echo [ERROR] Node server failed to start on port %PORT%. Check %NODE_LOG%
    goto CLEANUP
)

rem 14. Test Mode or Interactive Mode
if "%TEST_MODE%"=="1" (
    echo.
    echo ============================================================
    echo   TEST MODE - Running automated tests
    echo ============================================================
    if exist "scripts\test-performance.js" (
        node scripts\test-performance.js --port %PORT%
    ) else (
        echo [WARN] Test script not found at scripts\test-performance.js
    )
    goto CLEANUP
)

rem 15. Launch Browser
echo [INFO] Launching browser...
start https://%HOSTNAME%

:WAIT_LOOP
echo.
echo ============================================================
echo   SERVER RUNNING
echo ============================================================
echo   HTTP:  http://%HOSTNAME%
echo   HTTPS: https://%HOSTNAME%
echo   Port:  %PORT%
echo.
echo   IMPORTANT:
echo   [Q] Type 'Q' and press Enter to STOP server and RESTORE hosts.
echo   [X] Closing window will auto-cleanup via Guardian process.
echo ============================================================
echo.

set /p "CHOICE=Enter option (Q to quit): "
if /I "%CHOICE%"=="Q" goto CLEANUP
goto WAIT_LOOP

:CLEANUP
echo.
echo [INFO] Stopping servers...
taskkill /F /IM node.exe >nul 2>&1
taskkill /F /IM caddy.exe >nul 2>&1

echo [INFO] Restoring hosts file (removing %HOSTNAME%)...
rem FIX: Escape hostname for regex (periods become literal)
set "ESCAPED_HOSTNAME=%HOSTNAME:.=\.%"
powershell -Command "$escaped = [regex]::Escape('127.0.0.1 %HOSTNAME%'); (Get-Content '%HOSTS_FILE%') | Where-Object { $_ -notmatch $escaped } | Set-Content '%HOSTS_FILE%'"

echo [SUCCESS] Done. Access to %HOSTNAME% has been restored.
if "%TEST_MODE%"=="0" (
    echo [INFO] Closing window in 3 seconds...
    timeout /t 3 >nul
)
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
