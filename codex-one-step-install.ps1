# Codex One-Step Installer
# Installs Node.js (incl. npm), Python, and Codex CLI (@openai/codex).
# Run this script in an elevated PowerShell for best results.
$ErrorActionPreference = 'Stop'
$ScriptVersion = '0.1.3'
$scriptUrl = 'https://raw.githubusercontent.com/wmostert76/Codex-OneStep-Installer/master/codex-one-step-install.ps1'

function Test-IsAdmin {
  try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch {
    return $false
  }
}

if (-not (Test-IsAdmin)) {
  Write-Host "[Codex] Relaunching in elevated mode..." -ForegroundColor Yellow
  $cmd = "`$env:CODEX_ELEVATED='1'; irm '$scriptUrl' | iex"
  Start-Process -FilePath "powershell" -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command $cmd"
  return
}

Clear-Host
Write-Host "Codex One-Step Installer v$ScriptVersion" -ForegroundColor Cyan
Write-Host "------------------------" -ForegroundColor Cyan
Write-Host "Installing Node.js LTS, Python, and Codex CLI in one step..." -ForegroundColor Yellow
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

function Update-WingetSources {
  Write-Host "[Codex] Updating winget sources..." -ForegroundColor Yellow
  winget source update --accept-source-agreements | Out-Null
}

function Install-Node {
  Write-Host "[Codex] Installing Node.js LTS..." -ForegroundColor Yellow
  winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-source-agreements --accept-package-agreements
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

function Install-CodexCli {
  Write-Host "[Codex] Installing Codex CLI (@openai/codex)..." -ForegroundColor Yellow
  Refresh-Path
  if (Get-Command npm.cmd -ErrorAction SilentlyContinue) {
    npm.cmd i -g @openai/codex
  } elseif (Get-Command npm -ErrorAction SilentlyContinue) {
    npm i -g @openai/codex
  } else {
    throw "npm not found on PATH after Node.js install. Please open a new terminal and re-run."
  }
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
  if (Get-Command codex -ErrorAction SilentlyContinue) {
    codex --version
  } else {
    Write-Host "Codex CLI was not found on PATH." -ForegroundColor Yellow
  }
}

Update-WingetSources
Install-Node
Install-Python
Install-CodexCli
Refresh-Path
Verify-Installs
Write-Host "[Codex] Done." -ForegroundColor Green