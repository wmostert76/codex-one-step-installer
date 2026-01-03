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

function Update-WingetSources {
  Write-Host "[Codex] Updating winget sources..." -ForegroundColor Yellow
  winget source update --accept-source-agreements | Out-Null
}

function Install-Python {
  Write-Host "[Codex] Installing Python..." -ForegroundColor Yellow
  winget install --id Python.Python.3 -e --source winget --accept-source-agreements --accept-package-agreements
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
  Update-WingetSources
  Install-Node
  Install-Python
  Refresh-Path
  Verify-Installs
  Write-Host "[Codex] Done." -ForegroundColor Green
}

Run-All
