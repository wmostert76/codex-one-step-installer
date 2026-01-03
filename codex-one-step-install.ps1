# Codex One-Step Installer
# Installs Node.js (incl. npm), Python, and sets PowerShell execution policy to Unrestricted.
# Run this script in an elevated PowerShell for best results.

$ErrorActionPreference = 'Stop'
$ScriptVersion = '0.1.3'

Clear-Host
Write-Host "Codex One-Step Installer v$ScriptVersion" -ForegroundColor Cyan
Write-Host "------------------------" -ForegroundColor Cyan
Write-Host ""
Write-Host "This installer will update winget sources and install Node.js LTS + Python." -ForegroundColor Yellow
Write-Host "Press any key to continue..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
Clear-Host
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  ____   ___  ____  _______  __  __            " -ForegroundColor Cyan
Write-Host " / ___| / _ \\|  _ \\| ____\\ \\/ / |  \\/  |" -ForegroundColor Cyan
Write-Host "| |    | | | | | | |  _|  \\  /  | |\\/| |" -ForegroundColor Cyan
Write-Host "| |___ | |_| | |_| | |___ /  \\  | |  | |" -ForegroundColor Cyan
Write-Host " \\____| \\___/|____/|_____/_/\\_\\ |_|  |_|" -ForegroundColor Cyan
Write-Host "" -ForegroundColor Cyan
Write-Host "       ONE-STEP INSTALLER" -ForegroundColor Cyan
Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This will install Codex open in ONE step." -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

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
  $pythonIds = @(
    'Python.Python.3.12',
    'Python.Python.3.11',
    'Python.Python.3'
  )
  foreach ($id in $pythonIds) {
    try {
      winget install --id $id -e --source winget --accept-source-agreements --accept-package-agreements
      return
    } catch {
      Write-Host "[Codex] Python install failed for $id; trying next..." -ForegroundColor Yellow
    }
  }
  throw "Python install failed for all known IDs."
}

function Refresh-Path {
  $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
}

function Verify-Installs {
  Write-Host "[Codex] Verifying installs..." -ForegroundColor Yellow
  node -v
  npm -v
  try {
    python --version
  } catch {
    if (Get-Command py -ErrorAction SilentlyContinue) {
      py -V
    } else {
      Write-Host "Python was not found; run without arguments to install from the Microsoft Store, or disable this shortcut from Settings > Apps > Advanced app settings > App execution aliases." -ForegroundColor Yellow
    }
  }
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
