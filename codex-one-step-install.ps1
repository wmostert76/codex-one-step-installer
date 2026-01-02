# Codex One-Step Installer
# Installs Node.js (incl. npm), Python, and sets PowerShell execution policy to Unrestricted.
# Run this script in an elevated PowerShell for best results.

$ErrorActionPreference = 'Stop'

Write-Host "[Codex] Starting one-step install..." -ForegroundColor Cyan

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

# Install Node.js LTS (includes npm and PATH updates)
Write-Host "[Codex] Installing Node.js LTS..." -ForegroundColor Yellow
winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements

# Install Python (adds to PATH)
Write-Host "[Codex] Installing Python..." -ForegroundColor Yellow
winget install --id Python.Python.3 -e --accept-source-agreements --accept-package-agreements

# Refresh PATH for this session (no reboot required for the script)
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')

# Verify installations
Write-Host "[Codex] Verifying installs..." -ForegroundColor Yellow
node -v
npm -v
python --version

Write-Host "[Codex] Done." -ForegroundColor Green
