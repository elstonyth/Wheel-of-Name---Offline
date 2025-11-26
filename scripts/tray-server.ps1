# Wheel of Names - System Tray Mode
# Runs the server minimized with a system tray icon

param(
    [string]$Hostname = "wheel.local",
    [int]$Port = 8080,
    [string]$ScriptDir = $PSScriptRoot
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Change to project directory
if ($ScriptDir -and (Test-Path $ScriptDir)) {
    $projectDir = Split-Path $ScriptDir -Parent
    Set-Location $projectDir
} else {
    $projectDir = Get-Location
}

# Create notify icon
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
$notifyIcon.Text = "Wheel of Names Server"
$notifyIcon.Visible = $true

# Create context menu
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

# Menu items
$openBrowserItem = New-Object System.Windows.Forms.ToolStripMenuItem
$openBrowserItem.Text = "Open in Browser"
$openBrowserItem.Add_Click({
    Start-Process "https://$Hostname"
})

$openRemoteItem = New-Object System.Windows.Forms.ToolStripMenuItem
$openRemoteItem.Text = "Open Remote Control"
$openRemoteItem.Add_Click({
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback" -and $_.IPAddress -notmatch "^169\." } | Select-Object -First 1).IPAddress
    Start-Process "http://${ip}:${Port}/remote"
})

$showLogsItem = New-Object System.Windows.Forms.ToolStripMenuItem
$showLogsItem.Text = "Show Logs"
$showLogsItem.Add_Click({
    $logPath = Join-Path $projectDir "logs"
    if (Test-Path $logPath) {
        Start-Process "explorer.exe" $logPath
    }
})

$separator = New-Object System.Windows.Forms.ToolStripSeparator

$statusItem = New-Object System.Windows.Forms.ToolStripMenuItem
$statusItem.Text = "Status: Starting..."
$statusItem.Enabled = $false

$separator2 = New-Object System.Windows.Forms.ToolStripSeparator

$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitItem.Text = "Stop Server && Exit"
$exitItem.Add_Click({
    Stop-Processes
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

$contextMenu.Items.Add($openBrowserItem) | Out-Null
$contextMenu.Items.Add($openRemoteItem) | Out-Null
$contextMenu.Items.Add($showLogsItem) | Out-Null
$contextMenu.Items.Add($separator) | Out-Null
$contextMenu.Items.Add($statusItem) | Out-Null
$contextMenu.Items.Add($separator2) | Out-Null
$contextMenu.Items.Add($exitItem) | Out-Null

$notifyIcon.ContextMenuStrip = $contextMenu

# Double-click to open browser
$notifyIcon.Add_DoubleClick({
    Start-Process "https://$Hostname"
})

# Process tracking
$script:nodeProcess = $null
$script:caddyProcess = $null

function Stop-Processes {
    if ($script:nodeProcess -and !$script:nodeProcess.HasExited) {
        $script:nodeProcess.Kill()
    }
    if ($script:caddyProcess -and !$script:caddyProcess.HasExited) {
        $script:caddyProcess.Kill()
    }
    # Also kill by name as backup
    Stop-Process -Name "node" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "caddy" -Force -ErrorAction SilentlyContinue
}

function Start-Services {
    $logDir = Join-Path $projectDir "logs"
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    
    # Start Node
    $env:PORT = $Port
    $env:CUSTOM_HOST = $Hostname
    
    $nodeLog = Join-Path $logDir "node_server.log"
    $script:nodeProcess = Start-Process -FilePath "node" -ArgumentList "clone.js serve" -WorkingDirectory $projectDir -WindowStyle Hidden -RedirectStandardOutput $nodeLog -PassThru
    
    # Start Caddy
    $caddyLog = Join-Path $logDir "caddy.log"
    if (Test-Path (Join-Path $projectDir "caddy.exe")) {
        $script:caddyProcess = Start-Process -FilePath ".\caddy.exe" -ArgumentList "run --config Caddyfile" -WorkingDirectory $projectDir -WindowStyle Hidden -RedirectStandardOutput $caddyLog -PassThru
    }
    
    return $true
}

function Update-Status {
    $nodeRunning = $script:nodeProcess -and !$script:nodeProcess.HasExited
    $caddyRunning = $script:caddyProcess -and !$script:caddyProcess.HasExited
    
    if ($nodeRunning -and $caddyRunning) {
        $statusItem.Text = "Status: Running ✓"
        $notifyIcon.Text = "Wheel of Names - Running`nhttps://$Hostname"
    } elseif ($nodeRunning) {
        $statusItem.Text = "Status: Node Only"
        $notifyIcon.Text = "Wheel of Names - Node Only"
    } else {
        $statusItem.Text = "Status: Stopped"
        $notifyIcon.Text = "Wheel of Names - Stopped"
    }
}

# Start services
$notifyIcon.ShowBalloonTip(3000, "Wheel of Names", "Starting server...", [System.Windows.Forms.ToolTipIcon]::Info)

Start-Services
Start-Sleep -Seconds 3
Update-Status

$notifyIcon.ShowBalloonTip(3000, "Wheel of Names", "Server running at https://$Hostname", [System.Windows.Forms.ToolTipIcon]::Info)

# Timer for status updates and auto-recovery
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000  # Check every 5 seconds
$timer.Add_Tick({
    $nodeRunning = $script:nodeProcess -and !$script:nodeProcess.HasExited
    $caddyRunning = $script:caddyProcess -and !$script:caddyProcess.HasExited
    
    # Auto-recovery
    if (-not $nodeRunning) {
        Write-Host "[Auto-Recovery] Node process died, restarting..."
        $env:PORT = $Port
        $env:CUSTOM_HOST = $Hostname
        $nodeLog = Join-Path $projectDir "logs\node_server.log"
        $script:nodeProcess = Start-Process -FilePath "node" -ArgumentList "clone.js serve" -WorkingDirectory $projectDir -WindowStyle Hidden -RedirectStandardOutput $nodeLog -PassThru
    }
    
    if (-not $caddyRunning -and (Test-Path (Join-Path $projectDir "caddy.exe"))) {
        Write-Host "[Auto-Recovery] Caddy process died, restarting..."
        $caddyLog = Join-Path $projectDir "logs\caddy.log"
        $script:caddyProcess = Start-Process -FilePath ".\caddy.exe" -ArgumentList "run --config Caddyfile" -WorkingDirectory $projectDir -WindowStyle Hidden -RedirectStandardOutput $caddyLog -PassThru
    }
    
    Update-Status
})
$timer.Start()

# Handle application exit
$appContext = New-Object System.Windows.Forms.ApplicationContext
[System.Windows.Forms.Application]::Run($appContext)

# Cleanup
$timer.Stop()
Stop-Processes
$notifyIcon.Visible = $false
$notifyIcon.Dispose()
