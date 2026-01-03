# Codex One-Step Installer
# Installs Node.js (incl. npm), Python, and sets PowerShell execution policy to Unrestricted.
# Run this script in an elevated PowerShell for best results.

$ErrorActionPreference = 'Stop'
$ScriptVersion = '0.1.3'

param(
  [switch]$Silent,
  [switch]$SkipNode,
  [switch]$SkipPython,
  [switch]$DryRun,
  [switch]$Repair,
  [string]$CodexPackage
)

$script:TranscriptStarted = $false
$script:LogPath = Join-Path $env:TEMP ("codex-install-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))

function Test-IsAdmin {
  try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch {
    return $false
  }
}

function Start-InstallLog {
  try {
    Start-Transcript -Path $script:LogPath -Append | Out-Null
    $script:TranscriptStarted = $true
  } catch {
    Write-Host "[Codex] Log file not started: $script:LogPath" -ForegroundColor Yellow
  }
}

function Stop-InstallLog {
  if ($script:TranscriptStarted) {
    try { Stop-Transcript | Out-Null } catch {}
  }
}

function Pause-IfNeeded([string]$Message) {
  if ($Silent) {
    return
  }
  if ($Message) {
    Write-Host $Message -ForegroundColor Yellow
  }
  try {
    if ($Host.UI -and $Host.UI.RawUI) {
      $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
  } catch {}
}

function Invoke-Winget([string[]]$Args) {
  if ($DryRun) {
    Write-Host ("[DryRun] winget {0}" -f ($Args -join ' ')) -ForegroundColor Yellow
    return
  }
  & winget @Args
  if ($LASTEXITCODE -ne 0) {
    throw "winget failed with exit code $LASTEXITCODE."
  }
}

Clear-Host
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  ____   ___  ____  _______  __  __            " -ForegroundColor Cyan
Write-Host " / ___| / _ \\|  _ \\| ____\\ \\/ / |  \\/  |" -ForegroundColor Cyan
Write-Host "| |    | | | | | | |  _|  \\  /  | |\\/| |" -ForegroundColor Cyan
Write-Host "| |___ | |_| | |_| | |___ /  \\  | |  | |" -ForegroundColor Cyan
Write-Host " \\____| \\___/|____/|_____/_/\\_\\ |_|  |_|" -ForegroundColor Cyan
Write-Host "" -ForegroundColor Cyan
Write-Host "       ONE-STEP INSTALLER" -ForegroundColor Cyan
Write-Host "           v$ScriptVersion" -ForegroundColor Cyan
Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This will install Codex open in ONE step." -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Codex One-Step Installer v$ScriptVersion" -ForegroundColor Cyan
Write-Host ""
Write-Host "This installer will update winget sources and install Node.js LTS + Python." -ForegroundColor Yellow
Write-Host ""
Pause-IfNeeded "Press any key to start install..."

Start-InstallLog
Write-Host "[Codex] Log file: $script:LogPath" -ForegroundColor Yellow

# Ensure TLS 1.2 for winget downloads
try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

# Warn if not elevated
if (-not (Test-IsAdmin)) {
  Write-Host "[Codex] Not running as Administrator. Some installs may fail." -ForegroundColor Yellow
}

# Set execution policy to Unrestricted (LocalMachine preferred; fall back to CurrentUser)
if ($DryRun) {
  Write-Host "[DryRun] Would set PowerShell execution policy to Unrestricted." -ForegroundColor Yellow
} else {
  try {
    Write-Host "[Codex] Setting PowerShell execution policy to Unrestricted (LocalMachine)..." -ForegroundColor Yellow
    Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy Unrestricted -Force
  } catch {
    Write-Host "[Codex] LocalMachine policy change failed; trying CurrentUser..." -ForegroundColor Yellow
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force
  }
}

# Ensure winget is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  throw "winget not found. Please install App Installer from Microsoft Store, then re-run."
}

function Install-Node {
  if ($SkipNode) {
    Write-Host "[Codex] Skipping Node.js LTS (requested)." -ForegroundColor Yellow
    return
  }
  if (-not $Repair -and (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "[Codex] Node.js already present; skipping." -ForegroundColor Yellow
    return
  }
  Write-Host "[Codex] Installing Node.js LTS..." -ForegroundColor Yellow
  $args = @('install','--id','OpenJS.NodeJS.LTS','-e','--source','winget','--accept-source-agreements','--accept-package-agreements')
  if ($Repair) { $args += '--force' }
  Invoke-Winget $args
}

function Update-WingetSources {
  Write-Host "[Codex] Updating winget sources..." -ForegroundColor Yellow
  Invoke-Winget @('source','update','--accept-source-agreements')
}

function Install-Python {
  if ($SkipPython) {
    Write-Host "[Codex] Skipping Python (requested)." -ForegroundColor Yellow
    return
  }
  if (-not $Repair -and ((Get-Command python -ErrorAction SilentlyContinue) -or (Get-Command py -ErrorAction SilentlyContinue))) {
    Write-Host "[Codex] Python already present; skipping." -ForegroundColor Yellow
    return
  }
  Write-Host "[Codex] Installing Python..." -ForegroundColor Yellow
  $pythonIds = @(
    'Python.Python.3.12',
    'Python.Python.3.11',
    'Python.Python.3'
  )
  foreach ($id in $pythonIds) {
    try {
      $args = @('install','--id',$id,'-e','--source','winget','--accept-source-agreements','--accept-package-agreements')
      if ($Repair) { $args += '--force' }
      Invoke-Winget $args
      return
    } catch {
      Write-Host "[Codex] Python install failed for $id; trying next..." -ForegroundColor Yellow
    }
  }
  throw "Python install failed for all known IDs."
}

function Install-CodexCli {
  if (-not $CodexPackage) {
    Write-Host "[Codex] Codex CLI install skipped (no package specified)." -ForegroundColor Yellow
    Write-Host "[Codex] Use -CodexPackage npm:PACKAGE or pip:PACKAGE to enable." -ForegroundColor Yellow
    return
  }

  $parts = $CodexPackage.Split(':', 2)
  if ($parts.Count -ne 2) {
    throw "Invalid -CodexPackage format. Use npm:PACKAGE or pip:PACKAGE."
  }

  $manager = $parts[0].ToLowerInvariant()
  $package = $parts[1]

  switch ($manager) {
    'npm' {
      if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        throw "npm not found. Install Node.js first or omit -CodexPackage."
      }
      Write-Host "[Codex] Installing Codex CLI via npm ($package)..." -ForegroundColor Yellow
      if ($DryRun) {
        Write-Host ("[DryRun] npm install -g {0}" -f $package) -ForegroundColor Yellow
      } else {
        npm install -g $package
      }
    }
    'pip' {
      if (-not (Get-Command python -ErrorAction SilentlyContinue) -and -not (Get-Command py -ErrorAction SilentlyContinue)) {
        throw "Python not found. Install Python first or omit -CodexPackage."
      }
      Write-Host "[Codex] Installing Codex CLI via pip ($package)..." -ForegroundColor Yellow
      if ($DryRun) {
        Write-Host ("[DryRun] python -m pip install --upgrade {0}" -f $package) -ForegroundColor Yellow
      } else {
        if (Get-Command python -ErrorAction SilentlyContinue) {
          python -m pip install --upgrade $package
        } else {
          py -m pip install --upgrade $package
        }
      }
    }
    default {
      throw "Unknown package manager '$manager'. Use npm or pip."
    }
  }
}

function Refresh-Path {
  $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
}

function Verify-Installs {
  Write-Host "[Codex] Verifying installs..." -ForegroundColor Yellow
  if (-not $SkipNode) {
    if (Get-Command node -ErrorAction SilentlyContinue) {
      node -v
      npm -v
    } else {
      Write-Host "Node.js was not found on PATH." -ForegroundColor Yellow
    }
  }
  if (-not $SkipPython) {
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
}

function Print-Summary {
  Write-Host ""
  Write-Host "[Codex] Summary" -ForegroundColor Cyan
  if (-not $SkipNode) {
    if (Get-Command node -ErrorAction SilentlyContinue) {
      Write-Host ("Node.js: {0}" -f (node -v)) -ForegroundColor Green
      Write-Host ("npm: {0}" -f (npm -v)) -ForegroundColor Green
    } else {
      Write-Host "Node.js: not detected on PATH." -ForegroundColor Yellow
    }
  }
  if (-not $SkipPython) {
    if (Get-Command python -ErrorAction SilentlyContinue) {
      Write-Host ("Python: {0}" -f (python --version)) -ForegroundColor Green
    } elseif (Get-Command py -ErrorAction SilentlyContinue) {
      Write-Host ("Python: {0}" -f (py -V)) -ForegroundColor Green
    } else {
      Write-Host "Python: not detected on PATH." -ForegroundColor Yellow
    }
  }
  if ($CodexPackage) {
    if (Get-Command codex -ErrorAction SilentlyContinue) {
      try { Write-Host ("Codex: {0}" -f (codex --version)) -ForegroundColor Green } catch {}
    } else {
      Write-Host "Codex: not detected on PATH." -ForegroundColor Yellow
    }
  }
  Write-Host ""
  Write-Host "[Codex] If a tool isn't found, open a new terminal or restart PowerShell to refresh PATH." -ForegroundColor Yellow
  Write-Host ("[Codex] Log file: {0}" -f $script:LogPath) -ForegroundColor Yellow
}

function Run-All {
  Update-WingetSources
  Install-Node
  Install-Python
  Install-CodexCli
  Refresh-Path
  Verify-Installs
  Print-Summary
  Write-Host "[Codex] Done." -ForegroundColor Green
}

try {
  Run-All
} finally {
  Stop-InstallLog
}
