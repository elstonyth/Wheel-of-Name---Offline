# Wheel of Names - Watchdog / Auto-Recovery
# Monitors Node and Caddy processes and restarts them if they crash

param(
    [int]$Port = 8080,
    [string]$Hostname = "wheel.local",
    [string]$ProjectDir = (Split-Path $PSScriptRoot -Parent),
    [int]$CheckInterval = 5,  # seconds
    [int]$MaxRestarts = 10,   # max restarts before giving up
    [switch]$Verbose
)

$script:nodeRestarts = 0
$script:caddyRestarts = 0
$script:lastNodeRestart = [DateTime]::MinValue
$script:lastCaddyRestart = [DateTime]::MinValue

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    
    $logFile = Join-Path $ProjectDir "logs\watchdog.log"
    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
}

function Test-PortOpen {
    param([int]$Port)
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $result = $client.BeginConnect("127.0.0.1", $Port, $null, $null)
        $success = $result.AsyncWaitHandle.WaitOne(1000, $false)
        if ($success) {
            $client.EndConnect($result)
            $client.Close()
            return $true
        }
        $client.Close()
        return $false
    } catch {
        return $false
    }
}

function Start-NodeServer {
    Write-Log "Starting Node server on port $Port..."
    
    $env:PORT = $Port
    $env:CUSTOM_HOST = $Hostname
    
    $logFile = Join-Path $ProjectDir "logs\node_server.log"
    $process = Start-Process -FilePath "node" -ArgumentList "clone.js serve" -WorkingDirectory $ProjectDir -WindowStyle Hidden -RedirectStandardOutput $logFile -PassThru -ErrorAction SilentlyContinue
    
    if ($process) {
        Write-Log "Node server started with PID: $($process.Id)"
        $script:nodeRestarts++
        $script:lastNodeRestart = Get-Date
        return $process
    }
    Write-Log "Failed to start Node server" "ERROR"
    return $null
}

function Start-CaddyServer {
    $caddyPath = Join-Path $ProjectDir "caddy.exe"
    if (-not (Test-Path $caddyPath)) {
        Write-Log "Caddy not found, skipping" "WARN"
        return $null
    }
    
    Write-Log "Starting Caddy server..."
    
    $logFile = Join-Path $ProjectDir "logs\caddy.log"
    $process = Start-Process -FilePath $caddyPath -ArgumentList "run --config Caddyfile" -WorkingDirectory $ProjectDir -WindowStyle Hidden -RedirectStandardOutput $logFile -PassThru -ErrorAction SilentlyContinue
    
    if ($process) {
        Write-Log "Caddy server started with PID: $($process.Id)"
        $script:caddyRestarts++
        $script:lastCaddyRestart = Get-Date
        return $process
    }
    Write-Log "Failed to start Caddy server" "ERROR"
    return $null
}

function Get-NodeProcess {
    Get-Process -Name "node" -ErrorAction SilentlyContinue | Select-Object -First 1
}

function Get-CaddyProcess {
    Get-Process -Name "caddy" -ErrorAction SilentlyContinue | Select-Object -First 1
}

# Main watchdog loop
Write-Log "=========================================="
Write-Log "Watchdog starting..."
Write-Log "Project: $ProjectDir"
Write-Log "Port: $Port"
Write-Log "Hostname: $Hostname"
Write-Log "Check Interval: ${CheckInterval}s"
Write-Log "=========================================="

# Initial startup
$nodeProc = Get-NodeProcess
if (-not $nodeProc) {
    $nodeProc = Start-NodeServer
}

Start-Sleep -Seconds 2

$caddyProc = Get-CaddyProcess
if (-not $caddyProc) {
    $caddyProc = Start-CaddyServer
}

Write-Log "Watchdog monitoring active. Press Ctrl+C to stop."

try {
    while ($true) {
        Start-Sleep -Seconds $CheckInterval
        
        # Check Node
        $nodeProc = Get-NodeProcess
        $nodePortOpen = Test-PortOpen -Port $Port
        
        if (-not $nodeProc -or -not $nodePortOpen) {
            if ($script:nodeRestarts -ge $MaxRestarts) {
                $timeSinceLast = (Get-Date) - $script:lastNodeRestart
                if ($timeSinceLast.TotalMinutes -gt 10) {
                    # Reset counter after 10 minutes
                    $script:nodeRestarts = 0
                }
            }
            
            if ($script:nodeRestarts -lt $MaxRestarts) {
                Write-Log "Node server not responding, restarting... (restart #$($script:nodeRestarts + 1))" "WARN"
                Stop-Process -Name "node" -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
                $nodeProc = Start-NodeServer
            } else {
                Write-Log "Max restarts reached for Node. Waiting 10 minutes before retry." "ERROR"
            }
        } elseif ($Verbose) {
            Write-Log "Node: OK (PID: $($nodeProc.Id), Port: $Port)" "DEBUG"
        }
        
        # Check Caddy
        $caddyProc = Get-CaddyProcess
        if (-not $caddyProc -and (Test-Path (Join-Path $ProjectDir "caddy.exe"))) {
            if ($script:caddyRestarts -ge $MaxRestarts) {
                $timeSinceLast = (Get-Date) - $script:lastCaddyRestart
                if ($timeSinceLast.TotalMinutes -gt 10) {
                    $script:caddyRestarts = 0
                }
            }
            
            if ($script:caddyRestarts -lt $MaxRestarts) {
                Write-Log "Caddy server died, restarting... (restart #$($script:caddyRestarts + 1))" "WARN"
                $caddyProc = Start-CaddyServer
            } else {
                Write-Log "Max restarts reached for Caddy. Waiting 10 minutes before retry." "ERROR"
            }
        } elseif ($Verbose -and $caddyProc) {
            Write-Log "Caddy: OK (PID: $($caddyProc.Id))" "DEBUG"
        }
    }
} finally {
    Write-Log "Watchdog stopping..."
    Write-Log "Cleaning up processes..."
    Stop-Process -Name "node" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "caddy" -Force -ErrorAction SilentlyContinue
    Write-Log "Watchdog stopped."
}
