@echo off
setlocal

set "HOST=wheelofnames.local"
set "NODE_PORT=8080"
set "CADDYFILE=%~dp0Caddyfile"

echo === Wheel of Names Offline Launcher ===
echo.

if not exist "%CADDYFILE%" (
  echo [ERROR] Caddyfile not found at %CADDYFILE%.
  echo Please create a Caddyfile before running this script.
  pause
  exit /b 1
)

echo This script will:
echo   1. Trust Caddy's internal CA (requires administrator privileges the first time)
echo   2. Start the local Node server (node clone.js serve)
echo   3. Launch Caddy to serve https://%HOST%/
echo.

echo Trusting Caddy internal CA...
caddy trust
if errorlevel 1 (
  echo [WARN] Unable to trust the certificate automatically. You may need to run this script as Administrator.
)

echo Starting Node server on port %NODE_PORT%...
start "Wheel Server" cmd /k "cd /d %~dp0 && node clone.js serve"

echo Starting Caddy reverse proxy for %HOST%...
start "Caddy Proxy" cmd /k "cd /d %~dp0 && caddy run --config \"%CADDYFILE%\""

echo.
echo Servers are starting. Open https://%HOST%/ in your browser (accept the certificate if prompted).
echo Close the spawned command windows to stop the services.
pause

