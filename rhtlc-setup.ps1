# ─────────────────────────────────────────────────────────────
#  RHTLC One-Click Setup Script (Windows)
#  Automates: install → self-check → connect → chrome → ssh
#  Run in PowerShell as: .\rhtlc-setup.ps1 [full|daily|install|connect|cleanup|browser|ssh]
#  Official RHTLC docs: https://redhattraining.github.io/RHTLC_Docs/
# ─────────────────────────────────────────────────────────────

param(
    [string]$Mode = "full"
)

$ErrorActionPreference = "Stop"

$script:SOCKS_PORT = ""
$script:CONN_SKU = ""

# ── Output helpers ──────────────────────────────────────────
function Write-Info    { param([string]$Msg) Write-Host "[+] $Msg" -ForegroundColor Green }
function Write-Warn    { param([string]$Msg) Write-Host "[!] $Msg" -ForegroundColor Yellow }
function Write-Err     { param([string]$Msg) Write-Host "[X] $Msg" -ForegroundColor Red }
function Write-Step    { param([int]$Num, [string]$Msg) Write-Host "`n-- Step ${Num}: $Msg --" -ForegroundColor White }

function Show-Banner {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "   Red Hat Training Lab Companion (RHTLC) Setup"    -ForegroundColor Cyan
    Write-Host "   Windows Edition"                                  -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
}

# ── Step 1: Create C:\Tools and Download RHTLC ─────────────
function Install-RHTLC {
    Write-Step 1 "Installing RHTLC"

    # Create C:\Tools
    if (-not (Test-Path "C:\Tools")) {
        New-Item -ItemType Directory -Force "C:\Tools" | Out-Null
        Write-Info "Created C:\Tools"
    }

    # Add C:\Tools to PATH for this session
    if ($env:Path -notlike "*C:\Tools*") {
        $env:Path += ";C:\Tools"
    }

    # Download RHTLC
    if (-not (Test-Path "C:\Tools\rhtlc.exe")) {
        Write-Info "Downloading RHTLC..."
        Invoke-WebRequest -Uri "https://pypi.apps.tools-na.prod.nextcle.com/repository/ws-ole/binary/rhtlc-windows-x86_64.exe" -OutFile "C:\Tools\rhtlc.exe"
        Write-Info "RHTLC downloaded to C:\Tools\rhtlc.exe"
    } else {
        Write-Info "RHTLC already exists at C:\Tools\rhtlc.exe"
    }

    # Verify RHTLC
    try {
        $version = & rhtlc --version 2>&1
        Write-Info "RHTLC installed ($version)"
    } catch {
        Write-Err "RHTLC installation failed. Please install manually."
        Write-Err "See: https://redhattraining.github.io/RHTLC_Docs/"
        exit 1
    }

    # Step 2: Locate Ncat
    Write-Step 2 "Checking for Ncat (required SOCKS5 helper)"

    if ($env:Path -notlike "*Nmap*") {
        $env:Path += ";C:\Program Files (x86)\Nmap"
    }

    $ncat = Get-Command ncat.exe -ErrorAction SilentlyContinue
    if ($ncat) {
        Write-Info "Ncat found at $($ncat.Source)"
    } else {
        Write-Warn "Ncat not found in PATH. Searching system..."
        $found = Get-ChildItem "C:\" -Filter ncat.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $ncatDir = $found.DirectoryName
            $env:Path += ";$ncatDir"
            Write-Info "Ncat found at $($found.FullName) — added to PATH"
        } else {
            Write-Err "Ncat not found. RHTLC requires Ncat as the SOCKS5 helper."
            Write-Err "Please install Nmap from https://nmap.org/download.html and re-run this script."
            exit 1
        }
    }

    # Step 3: Self-check
    Write-Step 3 "Verifying RHTLC"
    Write-Info "Running rhtlc self-check..."
    & rhtlc self-check
    Write-Info "Expected: [SUCCESS] SOCKS proxy helper OK"
    Write-Info "Expected: [SUCCESS] Self-check passed"
}

# ── Step 4: Check & manage existing connections ─────────────
function Manage-Connections {
    Write-Step 4 "Checking Existing Connections"

    try {
        $statusOutput = & rhtlc status 2>&1 | Out-String
    } catch {
        $statusOutput = ""
    }

    $activeSkus = [regex]::Matches($statusOutput, 'conn-\d+') | ForEach-Object { $_.Value } | Sort-Object -Unique

    if ($activeSkus.Count -eq 0) {
        Write-Info "No existing connections found"
        return
    }

    Write-Host ""
    Write-Host "Existing active connections found:" -ForegroundColor Yellow
    foreach ($line in ($statusOutput -split "`n")) {
        if ($line -match "^conn-|Port:|Status:") {
            Write-Host "  $($line.Trim())" -ForegroundColor Cyan
        }
    }
    Write-Host ""

    $answer = Read-Host "Do you want to remove existing connections? (y/n)"

    if ($answer -match "^[Yy]") {
        Write-Info "Removing existing connections..."
        foreach ($sku in $activeSkus) {
            Write-Warn "Disconnecting ${sku}..."
            try { & rhtlc disconnect --sku $sku 2>&1 | Out-Null } catch {}
        }
        Write-Info "All existing connections cleaned up"
    } else {
        Write-Info "Keeping existing connections"
        Write-Warn "Your new connection will be assigned the next available port"
    }
}

# ── Step 5: Connect to classroom environment ────────────────
function Connect-Classroom {
    Manage-Connections

    Write-Step 5 "Connecting to Classroom Environment"

    Write-Host ""
    Write-Host "ACTION REQUIRED:" -ForegroundColor Yellow
    Write-Host "  1. Open your browser and go to:"
    Write-Host "     https://rol.redhat.com/rol/app/classes/bbd9ce42-1bb5-403b-a3a0-3f8daf6e09a6" -ForegroundColor Cyan
    Write-Host "  2. Go to the Labs tab"
    Write-Host "  3. Click Create Lab (if not already created)"
    Write-Host "  4. Under the RHTLC section, click COPY RHTLC URL"
    Write-Host ""

    $rhtlcUrl = Read-Host "Paste your RHTLC URL here"

    if ([string]::IsNullOrWhiteSpace($rhtlcUrl)) {
        Write-Err "No URL provided. Exiting."
        exit 1
    }

    Write-Info "Connecting to classroom environment..."
    Write-Warn "IMPORTANT: Run rhtlc connect only ONCE per lab session!"

    $connectOutput = & rhtlc connect "$rhtlcUrl" 2>&1 | Out-String
    Write-Host $connectOutput

    # Parse SOCKS port from output (e.g., socks5://127.0.0.1:1080)
    if ($connectOutput -match 'socks5://127\.0\.0\.1:(\d+)') {
        $script:SOCKS_PORT = $Matches[1]
    } else {
        Write-Warn "Could not detect SOCKS port from output, defaulting to 1080"
        $script:SOCKS_PORT = "1080"
    }

    # Parse connection SKU from output (e.g., conn-1)
    if ($connectOutput -match '(conn-\d+)') {
        $script:CONN_SKU = $Matches[1]
    } else {
        Write-Warn "Could not detect connection SKU from output"
    }

    # Verify only ONE connection
    Write-Info "Verifying connection..."
    & rhtlc status

    Write-Host ""
    Write-Info "Connected successfully!"
    Write-Host "  SOCKS Port:  $($script:SOCKS_PORT)" -ForegroundColor Cyan
    Write-Host "  Connection:  $($script:CONN_SKU)" -ForegroundColor Cyan
}

# ── Step 6: Launch Chrome with SOCKS proxy ──────────────────
function Launch-Browser {
    Write-Step 6 "Launching Chrome with SOCKS Proxy"

    $chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
    if (-not (Test-Path $chromePath)) {
        $chromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
    }
    if (-not (Test-Path $chromePath)) {
        Write-Warn "Google Chrome is not installed."
        $answer = Read-Host "Do you want to install Google Chrome? (y/n)"
        if ($answer -match "^[Yy]") {
            Write-Info "Downloading Google Chrome installer..."
            $installerPath = Join-Path $env:TEMP "ChromeSetup.exe"
            Invoke-WebRequest -Uri "https://dl.google.com/chrome/install/latest/chrome_installer.exe" -OutFile $installerPath
            Write-Info "Installing Google Chrome (this may take a minute)..."
            Start-Process $installerPath -ArgumentList "/silent", "/install" -Wait
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
            $chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
            if (-not (Test-Path $chromePath)) {
                $chromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
            }
            if (-not (Test-Path $chromePath)) {
                Write-Err "Chrome installation failed. Please install manually and re-run this script."
                exit 1
            }
            Write-Info "Google Chrome installed successfully!"
        } else {
            Write-Err "Chrome is required for OpenShift console access. Exiting."
            exit 1
        }
    }

    $port = if ($script:SOCKS_PORT) { $script:SOCKS_PORT } else { "1080" }

    $profileDir = Join-Path $env:TEMP "rhtlc-chrome"
    Remove-Item $profileDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $profileDir | Out-Null

    Write-Info "Starting Chrome with SOCKS proxy on port ${port}..."

    Start-Process $chromePath -ArgumentList `
        "--user-data-dir=$profileDir", `
        "--proxy-server=socks5://127.0.0.1:${port}", `
        "--host-resolver-rules=MAP * 0.0.0.0,EXCLUDE localhost"

    Start-Sleep -Seconds 2
    Write-Info "Chrome launched!"
    Write-Host ""
    Write-Host "  In Chrome, navigate to the console URL from: oc whoami --show-console" -ForegroundColor Cyan
    Write-Host "  The browser is using SOCKS5 proxy on 127.0.0.1:${port}" -ForegroundColor Cyan
}

# ── Step 7: SSH into workstation ────────────────────────────
function Connect-SSH {
    Write-Step 7 "SSH into Workstation"

    $sshTarget = "student@workstation.lab.example.com"
    if ($script:CONN_SKU) {
        $sshTarget = "student@workstation-$($script:CONN_SKU)"
    }

    Write-Host ""
    Write-Host "IMPORTANT: You are about to enter the Linux workstation." -ForegroundColor Yellow
    Write-Host "  Do NOT run Windows PowerShell commands inside the workstation." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Once inside the workstation, run:" -ForegroundColor Green
    Write-Host "  oc login -u admin -p redhatocp https://api.ocp4.example.com:6443" -ForegroundColor Cyan
    Write-Host "  If that fails, try:" -ForegroundColor Yellow
    Write-Host "  oc login -u admin -p redhatocp https://api.lab.example.com:6443" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Then run:" -ForegroundColor Green
    Write-Host "  oc whoami --show-console" -ForegroundColor Cyan
    Write-Host "  oc get nodes" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Use the URL from 'oc whoami --show-console' in the Chrome window." -ForegroundColor Green
    Write-Host ""
    Write-Host "Connecting to workstation via SSH..." -ForegroundColor Green
    Write-Host "  SSH Command: rhtlc ssh $sshTarget"
    Write-Host "  Password:    student"
    Write-Host ""

    & rhtlc ssh $sshTarget
}

# ── Troubleshoot: test proxy connectivity ───────────────────
function Test-Proxy {
    Write-Step 0 "Troubleshooting Proxy Connectivity"

    $port = if ($script:SOCKS_PORT) { $script:SOCKS_PORT } else { "1080" }

    Write-Info "Checking RHTLC status..."
    & rhtlc status

    Write-Host ""
    Write-Info "Testing proxy connectivity (trying ocp4 first)..."
    $result = & curl.exe --proxy "socks5h://127.0.0.1:${port}" -I "https://console-openshift-console.apps.ocp4.example.com" 2>&1 | Out-String
    Write-Host $result

    if ($result -match "Could not resolve|Failed to connect|connection refused") {
        Write-Warn "ocp4 URL did not work, trying lab URL..."
        & curl.exe --proxy "socks5h://127.0.0.1:${port}" -I "https://console-openshift-console.apps.lab.example.com" 2>&1
    }

    Write-Host ""
    Write-Warn "If you see SEC_E_UNTRUSTED_ROOT, that is a certificate trust issue."
    Write-Warn "It does NOT mean the RHTLC connection is down."
    Write-Warn "Do NOT create another RHTLC connection."
}

# ── Disconnect all connections ──────────────────────────────
function Disconnect-All {
    Write-Step 0 "Disconnecting All Connections"

    try {
        $statusOutput = & rhtlc status 2>&1 | Out-String
    } catch {
        $statusOutput = ""
    }

    $activeSkus = [regex]::Matches($statusOutput, 'conn-\d+') | ForEach-Object { $_.Value } | Sort-Object -Unique

    if ($activeSkus.Count -eq 0) {
        Write-Info "No active connections to disconnect"
        return
    }

    foreach ($sku in $activeSkus) {
        Write-Warn "Disconnecting ${sku}..."
        try { & rhtlc disconnect --sku $sku 2>&1 | Out-Null } catch {}
    }

    & rhtlc status
    Write-Info "All connections disconnected"
}

# ── Main ────────────────────────────────────────────────────
Show-Banner

switch ($Mode) {
    "install" {
        Install-RHTLC
    }
    "connect" {
        Connect-Classroom
    }
    "browser" {
        Launch-Browser
    }
    "ssh" {
        Connect-SSH
    }
    "full" {
        Install-RHTLC
        Connect-Classroom
        Launch-Browser
        Connect-SSH
    }
    "daily" {
        Write-Step 1 "Daily Lab Access"
        Write-Info "Starting session..."
        Manage-Connections
        Launch-Browser
        Connect-SSH
    }
    "cleanup" {
        Manage-Connections
    }
    "troubleshoot" {
        Test-Proxy
    }
    "disconnect" {
        Disconnect-All
    }
    default {
        Write-Host "Usage: .\rhtlc-setup.ps1 [-Mode] <command>"
        Write-Host ""
        Write-Host "  full         - First-time setup: install + connect + chrome + ssh (default)"
        Write-Host "  daily        - Daily use: manage connections + chrome + ssh"
        Write-Host "  install      - Only install RHTLC + Ncat check + self-check"
        Write-Host "  connect      - Only connect to classroom"
        Write-Host "  cleanup      - Manage existing connections"
        Write-Host "  browser      - Only launch proxied Chrome"
        Write-Host "  ssh          - Only SSH into workstation"
        Write-Host "  troubleshoot - Test proxy connectivity"
        Write-Host "  disconnect   - Disconnect all connections"
        Write-Host ""
        Write-Host "Three Important Rules:" -ForegroundColor Yellow
        Write-Host "  1. Run rhtlc connect only ONCE per lab session"
        Write-Host "  2. RHTLC runs on Windows; oc runs inside the workstation"
        Write-Host "  3. Chrome uses the SOCKS5 proxy 127.0.0.1:1080"
        exit 1
    }
}

Write-Host ""
Write-Info "All done! Happy learning!"
Write-Host ""
