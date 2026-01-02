# Codex One-Step Installer
# Installs Node.js (incl. npm), Python, and sets PowerShell execution policy to Unrestricted.
# Run this script in an elevated PowerShell for best results.

$ErrorActionPreference = 'Stop'

Write-Host "Codex One-Step Installer" -ForegroundColor Cyan
Write-Host "------------------------" -ForegroundColor Cyan

# Ensure TLS 1.2 for winget downloads
try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

# Set execution policy to Unrestricted (LocalMachine preferred; fall back to CurrentUser)
try {
  Write-Host "[Codex] Setting PowerShell execution policy to Unrestricted (LocalMachine)..." -ForegroundColor Yellow
  Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy Unrestricted -Force
} catch {
  Write-Host "[Codex] LocalMachine policy change failed; trying CurrentUser..." -ForegroundColor Yellow
  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force
}

# Ensure winget is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  throw "winget not found. Please install App Installer from Microsoft Store, then re-run."
}

function Install-Node {
  Write-Host "[Codex] Installing Node.js LTS..." -ForegroundColor Yellow
  winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
}

function Install-Python {
  Write-Host "[Codex] Installing Python..." -ForegroundColor Yellow
  winget install --id Python.Python.3 -e --accept-source-agreements --accept-package-agreements
}

function Refresh-Path {
  $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
}

function Verify-Installs {
  Write-Host "[Codex] Verifying installs..." -ForegroundColor Yellow
  node -v
  npm -v
  python --version
}

function Run-All {
  Install-Node
  Install-Python
  Refresh-Path
  Verify-Installs
  Write-Host "[Codex] Done." -ForegroundColor Green
}

Write-Host ""
Write-Host "Choose an option:" -ForegroundColor Cyan
Write-Host "  [1] Install Node.js LTS"
Write-Host "  [2] Install Python"
Write-Host "  [3] Run all (default)"
Write-Host "  [4] Exit"
Write-Host ""

$choice = Read-Host "Selection"
switch ($choice) {
  '1' { Install-Node; Refresh-Path; Verify-Installs }
  '2' { Install-Python; Refresh-Path; Verify-Installs }
  '4' { return }
  default { Run-All }
}
