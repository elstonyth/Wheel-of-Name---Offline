@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ==============================================================
rem Wheel of Names Offline launcher
rem Usage: start-wheel-server.bat [hostname] [port]
rem Environment overrides: HOST, PORT
rem ==============================================================

pushd "%~dp0" >nul

for /f %%A in ('powershell -NoProfile -Command "if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { 'ADMIN' } else { 'STANDARD' }"') do set "ADMIN_STATE=%%A"
if /I "%ADMIN_STATE%"=="ADMIN" (
  set "IS_ADMIN=1"
) else (
  set "IS_ADMIN="
)
set "ADMIN_STATE="

if "%~1" neq "" (
  set "HOST=%~1"
) else if not defined HOST (
  set "HOST=wheelofnames.local"
)

set "REPO_ROOT=%CD%"
set "CADDYFILE=%REPO_ROOT%\Caddyfile"
set "CLONE_SCRIPT=%REPO_ROOT%\clone.js"
set "LOG_DIR=%REPO_ROOT%\logs"
set "NODE_ENV=production"
if not defined CADDY_HTTP_PORT set "CADDY_HTTP_PORT=8081"
if not defined CADDY_HTTPS_PORT set "CADDY_HTTPS_PORT=8443"

if not exist "%LOG_DIR%" (
  mkdir "%LOG_DIR%" >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] Unable to create log directory "%LOG_DIR%".
    popd
    exit /b 1
  )
)

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format \"yyyyMMdd-HHmmss\""') do set "RUNSTAMP=%%I"
set "SESSION_LOG=%LOG_DIR%\launcher-%RUNSTAMP%.log"
set "NODE_LOG=%LOG_DIR%\node-server-%RUNSTAMP%.log"
set "CADDY_LOG=%LOG_DIR%\caddy-%RUNSTAMP%.log"
set "NODE_PID_FILE=%LOG_DIR%\node-server-%RUNSTAMP%.pid"
set "CADDY_PID_FILE=%LOG_DIR%\caddy-%RUNSTAMP%.pid"
set "NODE_LAUNCH_TMP=%LOG_DIR%\node-launch-%RUNSTAMP%.tmp"
set "CADDY_LAUNCH_TMP=%LOG_DIR%\caddy-launch-%RUNSTAMP%.tmp"
set "NODE_STDOUT_TMP="
set "CADDY_STDOUT_TMP="
> "%SESSION_LOG%" echo === Wheel of Names Offline launch %RUNSTAMP% ===

if "%~2" neq "" set "PORT=%~2"
if not defined PORT set "PORT=8080"

set "PORT_VALUE=%PORT%"
set /a "PORT_INT=%PORT_VALUE%" >nul 2>&1
if errorlevel 1 (
  call :abort "PORT value '%PORT%' is not numeric."
)
if %PORT_INT% lss 1 (
  call :abort "PORT must be between 1 and 65535."
)
if %PORT_INT% gtr 65535 (
  call :abort "PORT must be between 1 and 65535."
)
set "PORT=%PORT_INT%"

call :log INFO "Initializing launcher (host=%HOST%, node port=%PORT%)."

call :require_command powershell
call :require_command node
call :require_file "%CLONE_SCRIPT%" "clone.js file"
call :require_file "%CADDYFILE%" "Caddyfile"
call :check_node_modules
call :resolve_caddy

set "PS_WD=%REPO_ROOT%"
set "PS_NODE_SCRIPT=%CLONE_SCRIPT%"
set "PS_NODE_LOG=%NODE_LOG%"
set "PS_CADDY_EXE=%CADDY_EXE%"
set "PS_CADDYFILE=%CADDYFILE%"
set "PS_CADDY_LOG=%CADDY_LOG%"
set "PS_NODE_PID_FILE=%NODE_PID_FILE%"
set "PS_CADDY_PID_FILE=%CADDY_PID_FILE%"
set "PS_CADDY_HTTP_PORT=%CADDY_HTTP_PORT%"
set "PS_CADDY_HTTPS_PORT=%CADDY_HTTPS_PORT%"

call :ensure_hosts_entry "%HOST%"
call :stop_existing_node_server
call :stop_existing_caddy
call :ensure_port_free %PORT% "Node preview server"
call :ensure_port_free %CADDY_HTTP_PORT% "HTTP port for Caddy"
call :ensure_port_free %CADDY_HTTPS_PORT% "HTTPS port for Caddy"

call :log INFO "Starting Node server (log file: %NODE_LOG%)."
call :start_node
call :ensure_process_alive %NODE_PID% "Node server" "%NODE_LOG%"
call :wait_for_port %PORT% "Node server" 30

call :log INFO "Starting Caddy reverse proxy (log file: %CADDY_LOG%)."
call :start_caddy
call :ensure_process_alive %CADDY_PID% "Caddy reverse proxy" "%CADDY_LOG%"

call :wait_for_port %CADDY_HTTPS_PORT% "Caddy HTTPS endpoint" 45

call :trust_caddy

call :log INFO "All services are online."
echo.
echo ------------------------------------------------------------
echo   Local preview : http://localhost:%PORT%/
echo   Browser entry : https://%HOST%:%CADDY_HTTPS_PORT%/
echo   HTTP fallback : http://%HOST%:%CADDY_HTTP_PORT%/
echo   Node logs     : %NODE_LOG%
echo   Caddy logs    : %CADDY_LOG%
echo ------------------------------------------------------------
echo Press any key when you want to stop both services.
pause >nul

call :log INFO "Stop requested by user."
call :shutdown_services
call :log INFO "Services stopped."

popd
exit /b 0

:log
set "LOG_LEVEL=%~1"
set "LOG_MESSAGE=%~2"
for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format \"yyyy-MM-dd HH:mm:ss\""`) do set "LOG_TS=%%T"
echo [%LOG_TS%] [%LOG_LEVEL%] %LOG_MESSAGE%
>> "%SESSION_LOG%" echo [%LOG_TS%] [%LOG_LEVEL%] %LOG_MESSAGE%
set "LOG_TS="
set "LOG_LEVEL="
set "LOG_MESSAGE="
goto :eof

:require_command
where %~1 >nul 2>&1
if errorlevel 1 (
  call :abort "Required command '%~1' was not found in PATH."
)
goto :eof

:require_file
if not exist "%~1" (
  call :abort "Required %~2 is missing (%~1)."
)
goto :eof

:check_node_modules
if not exist "node_modules" (
  call :abort "node_modules directory not found. Run 'npm install' before launching."
)
if not exist "node_modules\fs-extra" (
  call :abort "Dependency 'fs-extra' is missing. Run 'npm install'."
)
if not exist "node_modules\puppeteer" (
  call :abort "Dependency 'puppeteer' is missing. Run 'npm install'."
)
call :log INFO "Node dependencies detected."
goto :eof

:resolve_caddy
set "CADDY_EXE="
if exist "%REPO_ROOT%\caddy.exe" (
  set "CADDY_EXE=%REPO_ROOT%\caddy.exe"
) else (
  for /f "delims=" %%I in ('where caddy.exe 2^>nul') do (
    set "CADDY_EXE=%%I"
    goto :caddy_found
  )
)
:caddy_found
if not defined CADDY_EXE (
  call :abort "caddy.exe not found. Place it next to this script or add it to PATH."
)
call :log INFO "Using Caddy binary: %CADDY_EXE%"
goto :eof

:ensure_hosts_entry
set "HOST_TO_CHECK=%~1"
set "HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts"
if not exist "%HOSTS_FILE%" (
  call :log WARN "Hosts file not found at %HOSTS_FILE%. Unable to verify host mapping for %HOST_TO_CHECK%."
  goto :eof
)
set "HOST_FOUND="
for /f "usebackq tokens=* delims=" %%H in (`findstr /I /C:"%HOST_TO_CHECK%" "%HOSTS_FILE%" 2^>nul`) do (
  set "HOST_FOUND=1"
)
if defined HOST_FOUND (
  call :log INFO "Hosts file already contains an entry for %HOST_TO_CHECK%."
  set "HOST_FOUND="
  goto :eof
)

if not defined IS_ADMIN (
  call :log WARN "Hosts file is missing %HOST_TO_CHECK%. Run this script as Administrator or add '127.0.0.1 %HOST_TO_CHECK%' manually."
  goto :eof
)

call :log INFO "Adding hosts file entry for %HOST_TO_CHECK% (requires Administrator)."
set "HOSTS_ADD_STATUS="
for /f %%R in ('powershell -NoProfile -Command "$ErrorActionPreference='Stop'; $path='%HOSTS_FILE%'; $host='%HOST_TO_CHECK%'; $pattern='\\b' + [regex]::Escape($host) + '\\b'; if (Get-Content -Path $path | Where-Object { $_ -match $pattern }) { Write-Output 'PRESENT' } else { Add-Content -Path $path -Value '' -Encoding ASCII; Add-Content -Path $path -Value ('127.0.0.1 ' + $host) -Encoding ASCII; Write-Output 'ADDED' }"') do set "HOSTS_ADD_STATUS=%%R"
if /I "%HOSTS_ADD_STATUS%"=="ADDED" (
  call :log INFO "Hosts file updated: 127.0.0.1 %HOST_TO_CHECK%."
) else (
  call :log INFO "Hosts file already included %HOST_TO_CHECK% (no change)."
)
set "HOSTS_ADD_STATUS="
set "HOST_FOUND="
goto :eof

:ensure_port_free
set "PORT_STATUS="
for /f %%P in ('powershell -NoProfile -Command "$ErrorActionPreference='SilentlyContinue'; $port=%~1; $listener=$null; $status='FREE'; try { $listener=[System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any,$port); $listener.Start() } catch { $status='BUSY' } finally { if($listener){ try { $listener.Stop() } catch {} } }; $status"') do set "PORT_STATUS=%%P"
if /I "%PORT_STATUS%"=="BUSY" (
  call :abort "%~2 (port %~1) is already in use."
)
call :log INFO "%~2 is available on port %~1."
set "PORT_STATUS="
goto :eof

:wait_for_port
set "WF_PORT=%~1"
set "WF_DESC=%~2"
set "WF_TIMEOUT=%~3"
call :log INFO "Waiting for %WF_DESC% (port %WF_PORT%) to accept connections..."
setlocal EnableDelayedExpansion
set /a WF_ELAPSED=0
:wf_loop
set "WF_READY="
for /f %%R in ('powershell -NoProfile -Command "$port=%WF_PORT%; $ready=$false; if (Get-Command Test-NetConnection -ErrorAction SilentlyContinue) { $ready = Test-NetConnection -ComputerName 127.0.0.1 -Port $port -InformationLevel Quiet } else { try { $client = New-Object System.Net.Sockets.TcpClient; $client.Connect('127.0.0.1',$port); $ready = $true } catch { $ready = $false } finally { if($client){ $client.Close() } } }; if($ready){ 'READY' } else { 'WAIT' }"') do set "WF_READY=%%R"
if /I "!WF_READY!"=="READY" (
  endlocal
  call :log INFO "%WF_DESC% is ready."
  goto :eof
)
if !WF_ELAPSED! GEQ %WF_TIMEOUT% (
  endlocal
  call :abort "%WF_DESC% did not open port %WF_PORT% within %WF_TIMEOUT% seconds."
)
set /a WF_ELAPSED+=1
timeout /t 1 /nobreak >nul
goto :wf_loop

:trust_caddy
call :log INFO "Ensuring Caddy trust store is installed..."
"%CADDY_EXE%" trust >nul 2>&1
if errorlevel 1 (
  call :log WARN "Unable to import Caddy root certificate automatically. Run this script once as Administrator."
) else (
  call :log INFO "Caddy internal CA is trusted (or already present)."
)
goto :eof

:: Launch node clone.js serve via PowerShell, capture PID via file
:start_node
set "NODE_PID="
if exist "%NODE_PID_FILE%" del "%NODE_PID_FILE%" >nul 2>&1
if exist "%NODE_LAUNCH_TMP%" del "%NODE_LAUNCH_TMP%" >nul 2>&1
powershell -NoProfile -Command "try { $ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; $wd=$env:PS_WD; $log=$env:PS_NODE_LOG; $script=$env:PS_NODE_SCRIPT; $pidFile=$env:PS_NODE_PID_FILE; $cmdLine = 'node \"' + $script + '\" serve >> \"' + $log + '\" 2>>&1'; $proc = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $cmdLine -WorkingDirectory $wd -PassThru -WindowStyle Hidden; Set-Content -Path $pidFile -Value $proc.Id -Encoding ascii } catch { Write-Host $_.Exception.Message; exit 1 }" > "%NODE_LAUNCH_TMP%" 2>&1
if errorlevel 1 (
  set "NODE_ERROR_MSG="
  for /f "usebackq tokens=* delims=" %%E in ("%NODE_LAUNCH_TMP%") do if not defined NODE_ERROR_MSG set "NODE_ERROR_MSG=%%E"
  if not defined NODE_ERROR_MSG set "NODE_ERROR_MSG=PowerShell failed to start Node. See %NODE_LAUNCH_TMP% for details."
  call :abort "Failed to launch Node server: %NODE_ERROR_MSG%"
)
if not exist "%NODE_PID_FILE%" (
  set "NODE_ERROR_MSG=PowerShell did not record the Node PID."
  if exist "%NODE_LAUNCH_TMP%" set "NODE_ERROR_MSG=%NODE_ERROR_MSG% See %NODE_LAUNCH_TMP%."
  call :abort "%NODE_ERROR_MSG%"
)
for /f "usebackq tokens=* delims=" %%P in ("%NODE_PID_FILE%") do if not defined NODE_PID set "NODE_PID=%%P"
if exist "%NODE_PID_FILE%" del "%NODE_PID_FILE%" >nul 2>&1
if exist "%NODE_LAUNCH_TMP%" del "%NODE_LAUNCH_TMP%" >nul 2>&1
if not defined NODE_PID (
  call :abort "Node PID file was empty."
)
for /f "delims= " %%I in ("%NODE_PID%") do set "NODE_PID=%%I"
call :log INFO "Node server started (PID %NODE_PID%)."
goto :eof

:start_caddy
set "CADDY_PID="
if exist "%CADDY_PID_FILE%" del "%CADDY_PID_FILE%" >nul 2>&1
if exist "%CADDY_LAUNCH_TMP%" del "%CADDY_LAUNCH_TMP%" >nul 2>&1
powershell -NoProfile -Command "try { $ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; $wd=$env:PS_WD; $exe=$env:PS_CADDY_EXE; $cfg=$env:PS_CADDYFILE; $log=$env:PS_CADDY_LOG; $pidFile=$env:PS_CADDY_PID_FILE; $cmdLine = '\"' + $exe + '\" run --config \"' + $cfg + '\" >> \"' + $log + '\" 2>>&1'; $proc = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $cmdLine -WorkingDirectory $wd -PassThru -WindowStyle Hidden; Set-Content -Path $pidFile -Value $proc.Id -Encoding ascii } catch { Write-Host $_.Exception.Message; exit 1 }" > "%CADDY_LAUNCH_TMP%" 2>&1
if errorlevel 1 (
  set "CADDY_ERROR_MSG="
  for /f "usebackq tokens=* delims=" %%E in ("%CADDY_LAUNCH_TMP%") do if not defined CADDY_ERROR_MSG set "CADDY_ERROR_MSG=%%E"
  if not defined CADDY_ERROR_MSG set "CADDY_ERROR_MSG=PowerShell failed to start Caddy. See %CADDY_LAUNCH_TMP% for details."
  call :abort "Failed to launch Caddy: %CADDY_ERROR_MSG%"
)
if not exist "%CADDY_PID_FILE%" (
  set "CADDY_ERROR_MSG=PowerShell did not record the Caddy PID."
  if exist "%CADDY_LAUNCH_TMP%" set "CADDY_ERROR_MSG=%CADDY_ERROR_MSG% See %CADDY_LAUNCH_TMP%."
  call :abort "%CADDY_ERROR_MSG%"
)
for /f "usebackq tokens=* delims=" %%P in ("%CADDY_PID_FILE%") do if not defined CADDY_PID set "CADDY_PID=%%P"
if exist "%CADDY_PID_FILE%" del "%CADDY_PID_FILE%" >nul 2>&1
if exist "%CADDY_LAUNCH_TMP%" del "%CADDY_LAUNCH_TMP%" >nul 2>&1
if not defined CADDY_PID (
  call :abort "Caddy PID file was empty."
)
for /f "delims= " %%I in ("%CADDY_PID%") do set "CADDY_PID=%%I"
call :log INFO "Caddy started (PID %CADDY_PID%)."
goto :eof

:stop_existing_node_server
set "STOPPED_NODE_COUNT=0"
for /f %%K in ('powershell -NoProfile -Command "$ErrorActionPreference='SilentlyContinue'; $target=[IO.Path]::GetFullPath($env:PS_NODE_SCRIPT); $killed=0; Get-CimInstance Win32_Process -Filter \"Name='node.exe'\" | ForEach-Object { if ($_.CommandLine -and $_.CommandLine.IndexOf($target, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and $_.CommandLine -match 'serve') { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; $killed++ } catch {} } }; Write-Output $killed"') do set "STOPPED_NODE_COUNT=%%K"
if not defined STOPPED_NODE_COUNT set "STOPPED_NODE_COUNT=0"
if not "%STOPPED_NODE_COUNT%"=="0" (
  call :log WARN "Stopped %STOPPED_NODE_COUNT% existing Node server instance(s) running clone.js serve."
)
set "STOPPED_NODE_COUNT="
goto :eof

:stop_existing_caddy
set "STOPPED_CADDY_COUNT=0"
for /f %%K in ('powershell -NoProfile -Command "$ErrorActionPreference='SilentlyContinue'; $cfg=[IO.Path]::GetFullPath($env:PS_CADDYFILE); $killed=0; Get-CimInstance Win32_Process -Filter \"Name='caddy.exe'\" | ForEach-Object { if ($_.CommandLine -and $_.CommandLine.IndexOf($cfg, [StringComparison]::OrdinalIgnoreCase) -ge 0) { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; $killed++ } catch {} } }; Write-Output $killed"') do set "STOPPED_CADDY_COUNT=%%K"
if not defined STOPPED_CADDY_COUNT set "STOPPED_CADDY_COUNT=0"
if not "%STOPPED_CADDY_COUNT%"=="0" (
  call :log WARN "Stopped %STOPPED_CADDY_COUNT% existing Caddy instance(s) using %CADDYFILE%."
)
set "STOPPED_CADDY_COUNT="
goto :eof

:ensure_process_alive
set "CHECK_PID=%~1"
set "CHECK_DESC=%~2"
set "CHECK_LOG=%~3"
if not defined CHECK_PID (
  call :abort "%CHECK_DESC% PID is not set."
)
powershell -NoProfile -Command "$ErrorActionPreference='SilentlyContinue'; try { $null = Get-Process -Id %CHECK_PID%; exit 0 } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
  call :abort "%CHECK_DESC% (PID %CHECK_PID%) exited unexpectedly. Check %CHECK_LOG% for details."
)
goto :eof

:shutdown_services
if defined CADDY_PID (
  taskkill /PID %CADDY_PID% /T /F >nul 2>&1
  if errorlevel 1 (
    call :log WARN "Unable to stop Caddy PID %CADDY_PID% (it may have already exited)."
  ) else (
    call :log INFO "Caddy process %CADDY_PID% stopped."
  )
  set "CADDY_PID="
)
if defined NODE_PID (
  taskkill /PID %NODE_PID% /T /F >nul 2>&1
  if errorlevel 1 (
    call :log WARN "Unable to stop Node PID %NODE_PID% (it may have already exited)."
  ) else (
    call :log INFO "Node process %NODE_PID% stopped."
  )
  set "NODE_PID="
)
goto :eof

:abort
call :log ERROR "%~1"
call :shutdown_services
popd
exit /b 1
