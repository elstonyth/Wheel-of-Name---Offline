@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ==============================================================
rem Wheel of Names Offline - Launcher & Manager
rem ==============================================================

rem 1. Check for Administrator Privileges and Auto-Elevate
fsutil dirty query %systemdrive% >nul
if %errorLevel% NEQ 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
echo [INFO] Running as Administrator.

rem 2. Cleanup Existing Processes
echo [INFO] Cleaning up old processes...
taskkill /F /IM node.exe /IM caddy.exe >nul 2>&1

rem 3. Check Dependencies
if not exist "node_modules" (
    echo [INFO] Installing dependencies...
    call npm install
    if %errorLevel% NEQ 0 (
        echo [ERROR] npm install failed. Please check your Node.js installation.
        pause
        exit /b 1
    )
)

rem 4. Prompt for Custom Hostname
echo.
echo ============================================================
echo   CUSTOM URL SETUP
echo ============================================================
echo.
set "HOSTNAME=wheel.local"
set /p "HOSTNAME=Enter desired domain name (default: wheel.local): "
echo.
echo [INFO] Using hostname: %HOSTNAME%

rem 5. Update Hosts File
set "HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts"
echo [INFO] Updating hosts file...
findstr /C:"127.0.0.1 %HOSTNAME%" "%HOSTS_FILE%" >nul
if %errorLevel% NEQ 0 (
    echo. >> "%HOSTS_FILE%"
    echo 127.0.0.1 %HOSTNAME% >> "%HOSTS_FILE%"
    echo [SUCCESS] Added %HOSTNAME% to hosts file.
) else (
    echo [INFO] %HOSTNAME% already exists in hosts file.
)

rem 6. Generate Dynamic Caddyfile
echo [INFO] Generating Caddyfile...
(
    echo http://%HOSTNAME% {
    echo     reverse_proxy localhost:8080
    echo }
    echo.
    echo http://localhost:80 {
    echo     reverse_proxy localhost:8080
    echo }
) > Caddyfile

rem 7. Start Node Server
echo [INFO] Starting Node server...
set "LOG_DIR=logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
set "NODE_LOG=%LOG_DIR%\node_server.log"
start /B /MIN cmd /c "node clone.js serve > "%NODE_LOG%" 2>&1"

rem 8. Start Caddy
echo [INFO] Starting Caddy...
set "CADDY_LOG=%LOG_DIR%\caddy.log"
if not exist "caddy.exe" (
    echo [ERROR] caddy.exe not found!
    pause
    exit /b 1
)
rem Trust the certificate first (silently if possible)
caddy.exe trust >nul 2>&1
start /B /MIN cmd /c "caddy.exe run --config Caddyfile > "%CADDY_LOG%" 2>&1"

rem 9. Wait for Services
echo [INFO] Waiting for services to start...
timeout /t 5 /nobreak >nul

rem 10. Launch Browser
echo [INFO] Launching browser...
start http://%HOSTNAME%

:WAIT_LOOP
echo.
echo ============================================================
echo   SERVER RUNNING
echo ============================================================
echo   URL: http://%HOSTNAME%
echo.
echo   IMPORTANT:
echo   [Q] Type 'Q' and press Enter to STOP server and RESTORE internet access.
echo   [X] If you close this window directly, run this script again and press Q.
echo ============================================================
echo.

set /p "CHOICE=Enter option (Q to quit): "
if /I "%CHOICE%"=="Q" goto CLEANUP
goto WAIT_LOOP

:CLEANUP
echo.
echo [INFO] Stopping servers...
taskkill /F /IM node.exe /IM caddy.exe >nul 2>&1

echo [INFO] Restoring hosts file (removing %HOSTNAME%)...
powershell -Command "(Get-Content '%HOSTS_FILE%') | Where-Object { $_ -notmatch '127.0.0.1 %HOSTNAME%' } | Set-Content '%HOSTS_FILE%'"

echo [SUCCESS] Done. Access to %HOSTNAME% has been restored.
echo [INFO] Closing window in 3 seconds...
timeout /t 3 >nul
exit
