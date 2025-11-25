#Requires -Version 5.1
param([switch]$Check, [switch]$Test, [switch]$Help)

$ErrorActionPreference = "Continue"
trap {
    Write-Host "`n  ERROR: $_" -ForegroundColor Red
    Write-Host "  Press Enter to exit..." -ForegroundColor Yellow
    Read-Host
    exit 1
}
$Host.UI.RawUI.WindowTitle = "Wheel of Names - Offline Server"

$NodeVersion = "20.18.0"
$NodeArch = "win-x64"
$PortableNodeDir = "node-portable"
$NodeZip = "node-v$NodeVersion-$NodeArch.zip"
$NodeUrl = "https://nodejs.org/dist/v$NodeVersion/$NodeZip"
$CaddyVersion = "2.8.4"
$CaddyZip = "caddy_" + $CaddyVersion + "_windows_amd64.zip"
$CaddyUrl = "https://github.com/caddyserver/caddy/releases/download/v$CaddyVersion/$CaddyZip"
$ScriptDir = $PSScriptRoot
$LogDir = Join-Path $ScriptDir "logs"
$UsePortableNode = $false

Set-Location $ScriptDir
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Test-Admin { 
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) 
}

function Test-PortAvailable([int]$Port) {
    try { $c = New-Object System.Net.Sockets.TcpClient; $c.Connect("127.0.0.1", $Port); $c.Close(); $false } 
    catch { $true }
}

function Find-AvailablePort { 
    for ($p = 8080; $p -le 8100; $p++) { if (Test-PortAvailable $p) { return $p } }
    0 
}

function Wait-ForPort([int]$Port, [int]$Timeout = 30) {
    for ($i = 0; $i -lt $Timeout; $i++) { if (-not (Test-PortAvailable $Port)) { return $true }; Start-Sleep 1 }
    $false 
}

function Get-LocalIP { 
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback" -and $_.IPAddress -notmatch "^169\." } | Select-Object -First 1).IPAddress
    if (-not $ip) { "127.0.0.1" } else { $ip }
}

function Install-PortableNodeJS {
    Write-Host "    Downloading Node.js v$NodeVersion (~30MB)..." -ForegroundColor Yellow
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $NodeUrl -OutFile $NodeZip -UseBasicParsing
    Write-Host "    Extracting..." -ForegroundColor Yellow
    Expand-Archive -Path $NodeZip -DestinationPath "." -Force
    if (Test-Path $PortableNodeDir) { Remove-Item $PortableNodeDir -Recurse -Force }
    Rename-Item "node-v$NodeVersion-$NodeArch" $PortableNodeDir
    Remove-Item $NodeZip -Force
}

function Install-Caddy {
    Write-Host "    Downloading Caddy v$CaddyVersion (~45MB)..." -ForegroundColor Yellow
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $CaddyUrl -OutFile $CaddyZip -UseBasicParsing
    Write-Host "    Extracting..." -ForegroundColor Yellow
    Expand-Archive -Path $CaddyZip -DestinationPath "." -Force
    Remove-Item $CaddyZip -Force
}

if ($Help) {
    Write-Host "`n  WHEEL OF NAMES - HELP`n" -ForegroundColor Cyan
    Write-Host "  USAGE:" -ForegroundColor Yellow
    Write-Host "   .\start-wheel-server.ps1           [Start server]"
    Write-Host "   .\start-wheel-server.ps1 -Check    [Diagnostic checks]"
    Write-Host "   .\start-wheel-server.ps1 -Help     [This help]`n"
    Write-Host "  NEW PC? JUST RUN THE SCRIPT!" -ForegroundColor Green
    Write-Host "   Auto-downloads: Node.js, Caddy, npm dependencies"
    Write-Host "   Only prompt: Custom domain (default: wheel.local)`n"
    exit 0
}

Clear-Host
Write-Host "`n  ======================================================" -ForegroundColor Cyan
Write-Host "         WHEEL OF NAMES - OFFLINE SERVER" -ForegroundColor Cyan
Write-Host "  ======================================================`n" -ForegroundColor Cyan
Write-Host "  PRE-FLIGHT SYSTEM CHECKS`n" -ForegroundColor Cyan

Write-Host "  [1/7] " -NoNewline; Write-Host "Checking Node.js..." -ForegroundColor Yellow -NoNewline
$sysNode = Get-Command node -ErrorAction SilentlyContinue
$portNode = Join-Path $ScriptDir "$PortableNodeDir\node.exe"

if ($sysNode) {
    $nv = & node --version 2>$null
    Write-Host " Found $nv" -ForegroundColor Green
} elseif (Test-Path $portNode) {
    $UsePortableNode = $true
    $env:PATH = "$ScriptDir\$PortableNodeDir" + ";" + $env:PATH
    $nv = & $portNode --version 2>$null
    Write-Host " Found $nv (portable)" -ForegroundColor Green
} elseif ($Check) {
    Write-Host " NOT FOUND (will auto-download)" -ForegroundColor Yellow
} else {
    Write-Host " Downloading..." -ForegroundColor Yellow
    Install-PortableNodeJS
    $UsePortableNode = $true
    $env:PATH = "$ScriptDir\$PortableNodeDir" + ";" + $env:PATH
    Write-Host "  [1/7] Node.js installed (portable)" -ForegroundColor Green
}

Write-Host "  [2/7] " -NoNewline; Write-Host "Checking npm..." -ForegroundColor Yellow -NoNewline
$npmPath = Join-Path $ScriptDir "$PortableNodeDir\npm.cmd"
if ($UsePortableNode -and (Test-Path $npmPath)) { Write-Host " Found (portable)" -ForegroundColor Green }
elseif (Get-Command npm -ErrorAction SilentlyContinue) { Write-Host " Found" -ForegroundColor Green }
elseif ($Check) { Write-Host " NOT FOUND" -ForegroundColor Yellow }
else { Write-Host " NOT FOUND" -ForegroundColor Red; exit 1 }

Write-Host "  [3/7] " -NoNewline; Write-Host "Checking package.json..." -ForegroundColor Yellow -NoNewline
if (Test-Path "package.json") { Write-Host " Found" -ForegroundColor Green } 
else { Write-Host " NOT FOUND" -ForegroundColor Red; exit 1 }

Write-Host "  [4/7] " -NoNewline; Write-Host "Checking dependencies..." -ForegroundColor Yellow -NoNewline
if (Test-Path "node_modules") { Write-Host " OK" -ForegroundColor Green }
elseif ($Check) { Write-Host " NOT INSTALLED" -ForegroundColor Yellow }
else { Write-Host " Installing..." -ForegroundColor Yellow; & npm install 2>&1 | Out-Null; Write-Host "  [4/7] Installed" -ForegroundColor Green }

Write-Host "  [5/7] " -NoNewline; Write-Host "Checking clone.js..." -ForegroundColor Yellow -NoNewline
if (Test-Path "clone.js") { Write-Host " Found" -ForegroundColor Green } 
else { Write-Host " NOT FOUND" -ForegroundColor Red; exit 1 }

Write-Host "  [6/7] " -NoNewline; Write-Host "Checking Caddy..." -ForegroundColor Yellow -NoNewline
if (Test-Path "caddy.exe") { Write-Host " Found" -ForegroundColor Green }
elseif ($Check) { Write-Host " NOT FOUND (will auto-download)" -ForegroundColor Yellow }
else { Write-Host " Downloading..." -ForegroundColor Yellow; Install-Caddy; Write-Host "  [6/7] Installed" -ForegroundColor Green }

Write-Host "  [7/7] " -NoNewline; Write-Host "Checking ports..." -ForegroundColor Yellow -NoNewline
$port = Find-AvailablePort
if ($port -gt 0) { Write-Host " Port $port available" -ForegroundColor Green } 
else { Write-Host " ALL IN USE" -ForegroundColor Red; exit 1 }

if ($Check) { Write-Host "`n  All checks passed!`n" -ForegroundColor Cyan; exit 0 }

Write-Host "`n  All pre-flight checks passed!" -ForegroundColor Green

if (-not $Test -and -not (Test-Admin)) {
    Write-Host "  Requesting Administrator privileges..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit 0
}

Write-Host "`n  SETUP`n" -ForegroundColor Cyan

Stop-Process -Name "node" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "caddy" -Force -ErrorAction SilentlyContinue
Write-Host "  [1/6] Cleaned up" -ForegroundColor Green

if ($Test) { 
    $hostname = "localhost"
    Write-Host "  [2/6] Using: localhost (test mode)" -ForegroundColor Green 
} else {
    Write-Host ""
    Write-Host "  ----------------------------------------" -ForegroundColor Cyan
    Write-Host "    CUSTOM DOMAIN SETUP" -ForegroundColor Cyan
    Write-Host "  ----------------------------------------" -ForegroundColor Cyan
    Write-Host ""
    $hostname = Read-Host "    Enter domain name [wheel.local]"
    if ([string]::IsNullOrWhiteSpace($hostname)) { $hostname = "wheel.local" }
    Write-Host ""
    Write-Host "  [2/6] Using hostname: $hostname" -ForegroundColor Green
}

$hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
if (-not $Test) {
    $entry = "127.0.0.1 $hostname"
    $content = Get-Content $hostsFile -ErrorAction SilentlyContinue
    if ($content -notmatch [regex]::Escape($entry)) { Add-Content $hostsFile "`n$entry" -ErrorAction SilentlyContinue }
    Write-Host "  [3/6] Hosts updated" -ForegroundColor Green
} else { Write-Host "  [3/6] Skipped hosts" -ForegroundColor Green }

if (-not $Test) {
    $caddyContent = "{ auto_https disable_redirects }`nhttps://$hostname { tls internal; reverse_proxy localhost:$port }`nhttp://$hostname { reverse_proxy localhost:$port }"
    Set-Content "Caddyfile" $caddyContent
    Write-Host "  [4/6] Caddyfile OK" -ForegroundColor Green
    & .\caddy.exe trust 2>&1 | Out-Null
    Write-Host "  [5/6] Cert trusted" -ForegroundColor Green
} else { Write-Host "  [4/6] Skipped Caddy" -ForegroundColor Green; Write-Host "  [5/6] Skipped cert" -ForegroundColor Green }

Write-Host "  [6/6] Starting..." -ForegroundColor Yellow -NoNewline
$env:PORT = $port
$nodeProc = Start-Process node -ArgumentList "clone.js serve" -WindowStyle Hidden -PassThru
if (-not $Test) { $caddyProc = Start-Process .\caddy.exe -ArgumentList "run --config Caddyfile" -WindowStyle Hidden -PassThru }
Start-Sleep 2
if (Wait-ForPort $port) { Write-Host " Running!" -ForegroundColor Green } else { Write-Host " FAILED" -ForegroundColor Red; exit 1 }

if ($Test) { Write-Host "`n  Test complete" -ForegroundColor Green; Stop-Process $nodeProc -Force -ErrorAction SilentlyContinue; exit 0 }

Start-Process "https://$hostname"
$localIP = Get-LocalIP

while ($true) {
    Clear-Host
    Write-Host "`n  WHEEL OF NAMES SERVER RUNNING`n" -ForegroundColor Green
    Write-Host "  Main:   https://$hostname" -ForegroundColor Cyan
    Write-Host "  Remote: http://${localIP}:$port/remote" -ForegroundColor Yellow
    Write-Host "  Port:   $port`n"
    Write-Host "  [Q] Quit`n" -ForegroundColor Yellow
    $choice = Read-Host "  Option"
    if ($choice -eq "Q" -or $choice -eq "q") { break }
}

Write-Host "`n  Shutting down..." -ForegroundColor Yellow
Stop-Process -Name "node" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "caddy" -Force -ErrorAction SilentlyContinue
$content = Get-Content $hostsFile -ErrorAction SilentlyContinue | Where-Object { $_ -notmatch [regex]::Escape("127.0.0.1 $hostname") }
Set-Content $hostsFile $content -ErrorAction SilentlyContinue
Write-Host "  Done!`n" -ForegroundColor Green


