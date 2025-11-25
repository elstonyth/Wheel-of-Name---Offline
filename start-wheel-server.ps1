#Requires -Version 5.1
param([switch]$Check, [switch]$Test, [switch]$Help)

$Host.UI.RawUI.WindowTitle = "Wheel of Names - Offline Server"

# Configuration
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
$SkipAdminFeatures = $false

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
    Write-Host "    Downloading Node.js v$NodeVersion..." -ForegroundColor Yellow
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $NodeUrl -OutFile $NodeZip -UseBasicParsing
    Write-Host "    Extracting..." -ForegroundColor Yellow
    Expand-Archive -Path $NodeZip -DestinationPath "." -Force
    if (Test-Path $PortableNodeDir) { Remove-Item $PortableNodeDir -Recurse -Force }
    Rename-Item "node-v$NodeVersion-$NodeArch" $PortableNodeDir
    Remove-Item $NodeZip -Force
}

function Install-Caddy {
    Write-Host "    Downloading Caddy v$CaddyVersion..." -ForegroundColor Yellow
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $CaddyUrl -OutFile $CaddyZip -UseBasicParsing
    Write-Host "    Extracting..." -ForegroundColor Yellow
    Expand-Archive -Path $CaddyZip -DestinationPath "." -Force
    Remove-Item $CaddyZip -Force
}

# Help Mode
if ($Help) {
    Write-Host ""
    Write-Host "  WHEEL OF NAMES - HELP" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  USAGE:" -ForegroundColor Yellow
    Write-Host "   .\start-wheel-server.ps1           Start server"
    Write-Host "   .\start-wheel-server.ps1 -Check    Diagnostic checks"
    Write-Host "   .\start-wheel-server.ps1 -Help     This help"
    Write-Host ""
    Write-Host "  NEW PC? JUST RUN THE SCRIPT!" -ForegroundColor Green
    Write-Host "   Auto-downloads: Node.js, Caddy, npm dependencies"
    Write-Host "   Only prompt: Custom domain (default: wheel.local)"
    Write-Host ""
    exit 0
}

# Banner
Clear-Host
Write-Host ""
Write-Host "  ========================================================" -ForegroundColor Cyan
Write-Host "         WHEEL OF NAMES - OFFLINE SERVER" -ForegroundColor Cyan
Write-Host "  ========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  PRE-FLIGHT SYSTEM CHECKS" -ForegroundColor Cyan
Write-Host ""

# [1/7] Node.js
Write-Host "  [1/7] " -NoNewline; Write-Host "Checking Node.js..." -ForegroundColor Yellow -NoNewline
$sysNode = Get-Command node -ErrorAction SilentlyContinue
$portNode = Join-Path $ScriptDir "$PortableNodeDir\node.exe"
if ($sysNode) { $nv = & node --version; Write-Host " Found $nv" -ForegroundColor Green }
elseif (Test-Path $portNode) { $UsePortableNode = $true; $env:PATH = "$ScriptDir\$PortableNodeDir;$env:PATH"; $nv = & $portNode --version; Write-Host " Found $nv (portable)" -ForegroundColor Green }
elseif ($Check) { Write-Host " NOT FOUND (will auto-download)" -ForegroundColor Yellow }
else { Write-Host " Downloading..." -ForegroundColor Yellow; Install-PortableNodeJS; $UsePortableNode = $true; $env:PATH = "$ScriptDir\$PortableNodeDir;$env:PATH"; Write-Host "  [1/7] Node.js installed" -ForegroundColor Green }

# [2/7] npm
Write-Host "  [2/7] " -NoNewline; Write-Host "Checking npm..." -ForegroundColor Yellow -NoNewline
$npmPath = Join-Path $ScriptDir "$PortableNodeDir\npm.cmd"
if ($UsePortableNode -and (Test-Path $npmPath)) { Write-Host " Found (portable)" -ForegroundColor Green }
elseif (Get-Command npm -ErrorAction SilentlyContinue) { Write-Host " Found" -ForegroundColor Green }
elseif ($Check) { Write-Host " NOT FOUND" -ForegroundColor Yellow }
else { Write-Host " NOT FOUND" -ForegroundColor Red; Read-Host "Press Enter"; exit 1 }

# [3/7] package.json
Write-Host "  [3/7] " -NoNewline; Write-Host "Checking package.json..." -ForegroundColor Yellow -NoNewline
if (Test-Path "package.json") { Write-Host " Found" -ForegroundColor Green } 
else { Write-Host " NOT FOUND" -ForegroundColor Red; Read-Host "Press Enter"; exit 1 }

# [4/7] Dependencies
Write-Host "  [4/7] " -NoNewline; Write-Host "Checking dependencies..." -ForegroundColor Yellow -NoNewline
if (Test-Path "node_modules") { Write-Host " OK" -ForegroundColor Green }
elseif ($Check) { Write-Host " NOT INSTALLED" -ForegroundColor Yellow }
else { Write-Host " Installing..." -ForegroundColor Yellow; & npm install 2>&1 | Out-Null; Write-Host "  [4/7] Installed" -ForegroundColor Green }

# [5/7] clone.js
Write-Host "  [5/7] " -NoNewline; Write-Host "Checking clone.js..." -ForegroundColor Yellow -NoNewline
if (Test-Path "clone.js") { Write-Host " Found" -ForegroundColor Green } 
else { Write-Host " NOT FOUND" -ForegroundColor Red; Read-Host "Press Enter"; exit 1 }

# [6/7] Caddy
Write-Host "  [6/7] " -NoNewline; Write-Host "Checking Caddy..." -ForegroundColor Yellow -NoNewline
if (Test-Path "caddy.exe") { Write-Host " Found" -ForegroundColor Green }
elseif ($Check) { Write-Host " NOT FOUND (will auto-download)" -ForegroundColor Yellow }
else { Write-Host " Downloading..." -ForegroundColor Yellow; Install-Caddy; Write-Host "  [6/7] Installed" -ForegroundColor Green }

# [7/7] Port
Write-Host "  [7/7] " -NoNewline; Write-Host "Checking ports..." -ForegroundColor Yellow -NoNewline
$port = Find-AvailablePort
if ($port -gt 0) { Write-Host " Port $port available" -ForegroundColor Green } 
else { Write-Host " ALL IN USE" -ForegroundColor Red; Read-Host "Press Enter"; exit 1 }

if ($Check) { Write-Host ""; Write-Host "  All checks passed!" -ForegroundColor Green; Write-Host ""; Read-Host "Press Enter"; exit 0 }

Write-Host ""
Write-Host "  All pre-flight checks passed!" -ForegroundColor Green

# Admin check
if (-not $Test -and -not (Test-Admin)) {
    Write-Host ""
    Write-Host "  --------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "  WARNING: Not running as Administrator" -ForegroundColor Yellow
    Write-Host "  Some features (hosts file, SSL, DNS) need admin rights." -ForegroundColor Yellow
    Write-Host "  --------------------------------------------------------" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [Y] Continue anyway (limited features)" -ForegroundColor Cyan
    Write-Host "  [N] Exit and restart as Administrator" -ForegroundColor Cyan
    Write-Host ""
    $choice = Read-Host "  Continue without admin? [y/N]"
    if ($choice -match "^[Yy]") {
        Write-Host "  Continuing with limited features..." -ForegroundColor Yellow
        $SkipAdminFeatures = $true
    } else {
        Write-Host ""
        Write-Host "  To run as Administrator:" -ForegroundColor Cyan
        Write-Host "  1. Right-click PowerShell/Terminal" -ForegroundColor White
        Write-Host "  2. Select 'Run as administrator'" -ForegroundColor White
        Write-Host "  3. Run this script again" -ForegroundColor White
        Write-Host ""
        Read-Host "  Press Enter to exit"
        exit 0
    }
}

Write-Host ""
Write-Host "  --------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  SETUP" -ForegroundColor Cyan
Write-Host "  --------------------------------------------------------" -ForegroundColor Cyan
Write-Host ""

# Cleanup
Stop-Process -Name "node" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "caddy" -Force -ErrorAction SilentlyContinue
Write-Host "  [1/6] Cleaned up old processes" -ForegroundColor Green

# Hostname prompt
if ($Test) { 
    $hostname = "localhost"
    Write-Host "  [2/6] Using: localhost (test mode)" -ForegroundColor Green 
} else {
    Write-Host ""
    Write-Host "  --- CUSTOM DOMAIN SETUP ---" -ForegroundColor Cyan
    Write-Host ""
    $hostname = Read-Host "    Enter domain name [wheel.local]"
    if ([string]::IsNullOrWhiteSpace($hostname)) { $hostname = "wheel.local" }
    Write-Host ""
    Write-Host "  [2/6] Using hostname: $hostname" -ForegroundColor Green
}

# Hosts file
$hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
if (-not $Test -and -not $SkipAdminFeatures) {
    $entry = "127.0.0.1 $hostname"
    try {
        $fileContent = Get-Content $hostsFile -ErrorAction Stop
        if ($fileContent -notmatch [regex]::Escape($entry)) { 
            Add-Content $hostsFile "`n$entry" -ErrorAction Stop
        }
        Write-Host "  [3/6] Hosts file updated" -ForegroundColor Green
    } catch {
        Write-Host "  [3/6] Hosts file skipped (need admin)" -ForegroundColor Yellow
    }
} elseif ($SkipAdminFeatures) {
    Write-Host "  [3/6] Hosts file skipped (no admin)" -ForegroundColor Yellow
} else { 
    Write-Host "  [3/6] Skipped hosts (test mode)" -ForegroundColor Green 
}

# Caddyfile
if (-not $Test) {
    $caddyContent = @"
{
    auto_https disable_redirects
}

https://$hostname {
    tls internal
    reverse_proxy localhost:$port
}

http://$hostname {
    reverse_proxy localhost:$port
}
"@
    Set-Content "Caddyfile" $caddyContent
    Write-Host "  [4/6] Caddyfile generated" -ForegroundColor Green
    
    if (-not $SkipAdminFeatures) {
        try { 
            & .\caddy.exe trust 2>&1 | Out-Null
            Write-Host "  [5/6] Certificate trusted" -ForegroundColor Green 
        } catch { 
            Write-Host "  [5/6] Cert trust skipped" -ForegroundColor Yellow 
        }
    } else {
        Write-Host "  [5/6] Cert trust skipped (no admin)" -ForegroundColor Yellow
    }
} else { 
    Write-Host "  [4/6] Skipped Caddyfile (test mode)" -ForegroundColor Green
    Write-Host "  [5/6] Skipped cert (test mode)" -ForegroundColor Green 
}

# Start servers
Write-Host "  [6/6] Starting servers..." -ForegroundColor Yellow

$env:PORT = $port
$env:CUSTOM_HOST = $hostname

# Start Node directly (not as job) so output is visible
$caddyLog = Join-Path $LogDir "caddy.log"

# Start Caddy in background
if (-not $Test) {
    Start-Process -FilePath ".\caddy.exe" -ArgumentList "run --config Caddyfile" -WindowStyle Hidden -RedirectStandardOutput $caddyLog -RedirectStandardError $caddyLog
}

# Wait a moment
Start-Sleep 2

# Get local IP
$localIP = Get-LocalIP

# Open browser
if (-not $Test) {
    Start-Process "https://$hostname"
}

Write-Host ""
Write-Host "  ========================================================" -ForegroundColor Green
Write-Host "  SERVER STARTING..." -ForegroundColor Green
Write-Host "  ========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Main URL:    https://$hostname" -ForegroundColor Cyan
Write-Host "  Remote URL:  http://${localIP}:$port/remote" -ForegroundColor Yellow
Write-Host "  Port:        $port" -ForegroundColor White
Write-Host ""
Write-Host "  Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""
Write-Host "  --------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  SERVER OUTPUT:" -ForegroundColor Cyan
Write-Host "  --------------------------------------------------------" -ForegroundColor Cyan
Write-Host ""

# Run Node in foreground so user sees output including QR code
try {
    & node clone.js serve
} finally {
    Write-Host ""
    Write-Host "  Shutting down..." -ForegroundColor Yellow
    Stop-Process -Name "caddy" -Force -ErrorAction SilentlyContinue
    
    # Cleanup hosts file
    if (-not $Test -and -not $SkipAdminFeatures -and $hostname -ne "localhost") {
        try {
            $content = Get-Content $hostsFile -ErrorAction SilentlyContinue | Where-Object { $_ -notmatch [regex]::Escape("127.0.0.1 $hostname") }
            Set-Content $hostsFile $content -ErrorAction SilentlyContinue
        } catch { }
    }
    
    Write-Host "  Done!" -ForegroundColor Green
}
