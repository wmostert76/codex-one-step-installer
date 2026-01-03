# Codex One-Step Installer
# Installs Node.js (incl. npm), Python, Codex CLI (@openai/codex), and bootstraps .codex profile.
# Run this script in an elevated PowerShell for best results.
$ErrorActionPreference = 'Stop'
$ScriptVersion = '0.1.8'
$scriptUrl = 'https://raw.githubusercontent.com/wmostert76/Codex-OneStep-Installer/master/codex-one-step-install.ps1'
$profileZipUrl = 'https://raw.githubusercontent.com/wmostert76/Codex-OneStep-Installer/master/assets/codex-profile.zip'
$profileZipPassword = 'Wam080976!!!'

function Test-IsAdmin {
  try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch {
    return $false
  }
}

function Pause-Exit {
  Write-Host "" 
  Write-Host "Press any key to close..." -ForegroundColor Yellow
  try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch {}
}

if (-not (Test-IsAdmin)) {
  Write-Host "[Codex] Relaunching in elevated mode..." -ForegroundColor Yellow
  $cmd = "`$env:CODEX_ELEVATED='1'; irm '$scriptUrl' | iex"
  Start-Process -FilePath "powershell" -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command $cmd"
  return
}

function Update-WingetSources {
  Write-Host "[Codex] Updating winget sources..." -ForegroundColor Yellow
  winget source update --accept-source-agreements | Out-Null
}

function Install-Node {
  Write-Host "[Codex] Installing Node.js LTS..." -ForegroundColor Yellow
  winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-source-agreements --accept-package-agreements
}

function Update-Npm {
  Write-Host "[Codex] Updating npm to latest..." -ForegroundColor Yellow
  Refresh-Path
  if (Get-Command npm.cmd -ErrorAction SilentlyContinue) {
    npm.cmd i -g npm@latest
  } elseif (Get-Command npm -ErrorAction SilentlyContinue) {
    npm i -g npm@latest
  } else {
    Write-Host "[Codex] npm not found on PATH; skipping npm update." -ForegroundColor Yellow
  }
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

function Ensure-7Zip {
  if (Test-Path (Join-Path $env:ProgramFiles '7-Zip\7z.exe')) {
    return
  }
  Write-Host "[Codex] Installing 7-Zip..." -ForegroundColor Yellow
  winget install --id 7zip.7zip -e --accept-source-agreements --accept-package-agreements
}

function Install-CodexProfile {
  Write-Host "[Codex] Initializing Codex profile..." -ForegroundColor Yellow
  Ensure-7Zip
  $sevenZip = Join-Path $env:ProgramFiles '7-Zip\7z.exe'
  if (-not (Test-Path $sevenZip)) {
    throw "7-Zip not found after install."
  }
  $tempZip = Join-Path $env:TEMP 'codex-profile.zip'
  Invoke-WebRequest -Uri $profileZipUrl -OutFile $tempZip
  $target = Join-Path $env:USERPROFILE '.codex'
  if (-not (Test-Path $target)) {
    New-Item -ItemType Directory -Force -Path $target | Out-Null
  }
  & $sevenZip x $tempZip -o$env:USERPROFILE -p$profileZipPassword -y
  if ($LASTEXITCODE -ne 0) {
    throw "7-Zip extraction failed with exit code $LASTEXITCODE."
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

try {
  Clear-Host
  Write-Host "Codex One-Step Installer v$ScriptVersion" -ForegroundColor Cyan
  Write-Host "------------------------" -ForegroundColor Cyan
  Write-Host "Installing Node.js LTS, Python, Codex CLI, and profile in one step..." -ForegroundColor Yellow
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

  Update-WingetSources
  Install-Node
  Update-Npm
  Install-Python
  Install-CodexCli
  Install-CodexProfile
  Refresh-Path
  Verify-Installs
  Write-Host "[Codex] Done." -ForegroundColor Green
  Write-Host "[Codex] Launching Codex..." -ForegroundColor Green
  codex --dangerously-bypass-approvals-and-sandbox --search
} catch {
  Write-Host "[Codex] ERROR: $($_.Exception.Message)" -ForegroundColor Red
} finally {
  Pause-Exit
}