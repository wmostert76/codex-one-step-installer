# Codex One-Step Installer v0.4.1
# Installs Node.js, Python, Codex CLI, and Claude Code
# Fully automated - no prompts

param([switch]$Uninstall)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$ConfirmPreference = 'None'

# Force TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Step($msg) { Write-Host "[Codex] $msg" -ForegroundColor Yellow }
function Write-Ok($msg) { Write-Host "[Codex] $msg" -ForegroundColor Green }
function Write-Err($msg) { Write-Host "[Codex] $msg" -ForegroundColor Red }

function Test-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
  # Add common paths
  @("$env:ProgramFiles\nodejs", "$env:LOCALAPPDATA\Microsoft\WindowsApps", "$env:APPDATA\npm") | ForEach-Object {
    if ((Test-Path $_) -and ($env:Path -notlike "*$_*")) { $env:Path += ";$_" }
  }
}

function Install-WinGet {
  if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }

  Write-Step "Bootstrapping winget..."

  try {
    # Method 1: Use Add-AppxPackage directly from GitHub releases
    $tempDir = Join-Path $env:TEMP "winget-install-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    # Download VCLibs
    Write-Step "Downloading VCLibs..."
    $vcLibs = Join-Path $tempDir "vclibs.appx"
    Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile $vcLibs -UseBasicParsing
    Add-AppxPackage -Path $vcLibs -ErrorAction SilentlyContinue

    # Download UI.Xaml
    Write-Step "Downloading UI.Xaml..."
    $xaml = Join-Path $tempDir "xaml.appx"
    Invoke-WebRequest -Uri "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx" -OutFile $xaml -UseBasicParsing
    Add-AppxPackage -Path $xaml -ErrorAction SilentlyContinue

    # Get latest winget release
    Write-Step "Downloading winget..."
    $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing
    $msixUrl = ($releases.assets | Where-Object { $_.name -match '\.msixbundle$' -and $_.name -notmatch 'License' }).browser_download_url
    $licenseUrl = ($releases.assets | Where-Object { $_.name -match 'License.*\.xml$' }).browser_download_url

    $msix = Join-Path $tempDir "winget.msixbundle"
    Invoke-WebRequest -Uri $msixUrl -OutFile $msix -UseBasicParsing

    # Install winget
    Write-Step "Installing winget..."
    if ($licenseUrl) {
      $license = Join-Path $tempDir "license.xml"
      Invoke-WebRequest -Uri $licenseUrl -OutFile $license -UseBasicParsing
      try {
        Add-AppxProvisionedPackage -Online -PackagePath $msix -LicensePath $license -ErrorAction Stop | Out-Null
      } catch {
        Write-Step "Provisioned install failed, trying Add-AppxPackage..."
        Add-AppxPackage -Path $msix -ErrorAction Stop
      }
    } else {
      Add-AppxPackage -Path $msix -ErrorAction Stop
    }

    # Cleanup
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

    # Refresh PATH and verify
    Refresh-Path
    Start-Sleep -Seconds 2

    if (Get-Command winget -ErrorAction SilentlyContinue) {
      Write-Ok "winget installed successfully!"
      return $true
    }
  } catch {
    Write-Err "winget bootstrap failed: $_"
  }

  return $false
}

function Install-NodeJS {
  if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Ok "Node.js already installed: $(node -v)"
    return
  }

  Write-Step "Installing Node.js LTS..."

  if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-source-agreements --accept-package-agreements --silent | Out-Host
  } else {
    # Direct MSI install
    Write-Step "Downloading Node.js installer..."
    $index = Invoke-RestMethod -Uri "https://nodejs.org/dist/index.json" -UseBasicParsing
    $lts = ($index | Where-Object { $_.lts })[0]
    $msiUrl = "https://nodejs.org/dist/$($lts.version)/node-$($lts.version)-x64.msi"
    $msi = Join-Path $env:TEMP "node-install.msi"
    Invoke-WebRequest -Uri $msiUrl -OutFile $msi -UseBasicParsing

    Write-Step "Running Node.js installer..."
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $msi, "/qn", "/norestart", "ADDLOCAL=ALL" -Wait
    Remove-Item $msi -Force -ErrorAction SilentlyContinue
  }

  Refresh-Path
  if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Ok "Node.js installed: $(node -v)"
  }
}

function Install-Python {
  if ((Get-Command python -ErrorAction SilentlyContinue) -or (Get-Command py -ErrorAction SilentlyContinue)) {
    Write-Ok "Python already installed"
    return
  }

  Write-Step "Installing Python..."

  if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install --id Python.Python.3.12 -e --source winget --accept-source-agreements --accept-package-agreements --silent | Out-Host
  } else {
    # Direct installer
    Write-Step "Downloading Python installer..."
    $pyUrl = "https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe"
    $pyExe = Join-Path $env:TEMP "python-install.exe"
    Invoke-WebRequest -Uri $pyUrl -OutFile $pyExe -UseBasicParsing

    Write-Step "Running Python installer..."
    Start-Process -FilePath $pyExe -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1" -Wait
    Remove-Item $pyExe -Force -ErrorAction SilentlyContinue
  }

  Refresh-Path
}

function Install-CodexCLI {
  Refresh-Path

  if (Get-Command codex -ErrorAction SilentlyContinue) {
    Write-Ok "Codex CLI already installed"
    return
  }

  Write-Step "Installing Codex CLI..."

  $npm = Get-Command npm -ErrorAction SilentlyContinue
  if (-not $npm) {
    $npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
  }

  if ($npm) {
    & $npm install -g @openai/codex 2>&1 | Out-Host
    Refresh-Path
    if (Get-Command codex -ErrorAction SilentlyContinue) {
      Write-Ok "Codex CLI installed"
    }
  } else {
    Write-Err "npm not found - cannot install Codex CLI"
  }
}

function Install-ClaudeCode {
  Refresh-Path

  if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Ok "Claude Code already installed"
    return
  }

  Write-Step "Installing Claude Code..."

  try {
    $installer = Join-Path $env:TEMP "claude-install.ps1"
    Invoke-WebRequest -Uri "https://claude.ai/install.ps1" -OutFile $installer -UseBasicParsing
    & powershell -NoProfile -ExecutionPolicy Bypass -File $installer
    Remove-Item $installer -Force -ErrorAction SilentlyContinue
    Refresh-Path
    Write-Ok "Claude Code installed"
  } catch {
    Write-Err "Claude Code install failed: $_"
  }
}

function Uninstall-All {
  Write-Step "Uninstalling..."

  # Codex CLI
  if (Get-Command npm -ErrorAction SilentlyContinue) {
    npm uninstall -g @openai/codex 2>&1 | Out-Null
  }

  # Claude Code
  if (Get-Command claude -ErrorAction SilentlyContinue) {
    claude uninstall 2>&1 | Out-Null
  }

  # Node.js & Python via winget or registry
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget uninstall --id OpenJS.NodeJS.LTS -e --silent 2>&1 | Out-Null
    winget uninstall --id Python.Python.3.12 -e --silent 2>&1 | Out-Null
  }

  Write-Ok "Uninstall complete"
}

# === MAIN ===

Clear-Host
Write-Host ""
Write-Host "  Codex One-Step Installer v0.4.1" -ForegroundColor Cyan
Write-Host "  ================================" -ForegroundColor DarkCyan
Write-Host ""

# Check admin
if (-not (Test-Admin)) {
  Write-Step "Relaunching as Administrator..."
  $script = $PSCommandPath
  if (-not $script) {
    $script = Join-Path $env:TEMP "codex-installer.ps1"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/wmostert76/Codex-OneStep-Installer/master/codex-one-step-install.ps1" -OutFile $script -UseBasicParsing
  }
  $args = "-NoProfile -ExecutionPolicy Bypass -File `"$script`""
  if ($Uninstall) { $args += " -Uninstall" }
  Start-Process powershell -Verb RunAs -ArgumentList $args
  exit
}

# Set execution policy
try {
  Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy Unrestricted -Force -ErrorAction Stop
  Write-Ok "Execution policy set to Unrestricted"
} catch {
  try { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force } catch {}
}

if ($Uninstall) {
  Uninstall-All
  exit
}

# Install sequence
Install-WinGet | Out-Null
Install-NodeJS
Install-Python
Install-CodexCLI
Install-ClaudeCode

# Final verification
Write-Host ""
Write-Host "  ================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "  ================================" -ForegroundColor Green
Write-Host ""

Refresh-Path

Write-Host "  Installed versions:" -ForegroundColor Cyan
if (Get-Command node -ErrorAction SilentlyContinue) { Write-Host "    Node.js: $(node -v)" }
if (Get-Command npm -ErrorAction SilentlyContinue) { Write-Host "    npm:     $(npm -v)" }
if (Get-Command python -ErrorAction SilentlyContinue) { Write-Host "    Python:  $(python --version 2>&1)" }
if (Get-Command codex -ErrorAction SilentlyContinue) { Write-Host "    Codex:   $(codex --version 2>&1)" }
if (Get-Command claude -ErrorAction SilentlyContinue) { Write-Host "    Claude:  $(claude --version 2>&1)" }

Write-Host ""
Write-Host "  Open a NEW terminal to use the tools." -ForegroundColor Yellow
Write-Host ""
