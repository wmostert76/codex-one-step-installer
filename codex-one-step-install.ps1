# Codex One-Step Installer v0.5.0
# Installs Node.js, Python, and Codex CLI
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

function Remove-PathEntry {
  param(
    [string]$TargetPath,
    [ValidateSet('User','Machine')] [string]$Scope = 'User'
  )
  if (-not $TargetPath) { return }
  $existing = [Environment]::GetEnvironmentVariable('Path', $Scope)
  if (-not $existing) { return }

  $targetNorm = $TargetPath.Trim().TrimEnd('\').ToLowerInvariant()
  $parts = $existing -split ';' | Where-Object { $_ -and $_.Trim() -ne '' }
  $filtered = @()
  foreach ($part in $parts) {
    $partNorm = $part.Trim().TrimEnd('\').ToLowerInvariant()
    if ($partNorm -ne $targetNorm) { $filtered += $part.Trim() }
  }
  $newPath = ($filtered -join ';')
  [Environment]::SetEnvironmentVariable('Path', $newPath, $Scope)
}

function Remove-DirectorySafe {
  param([string]$PathToRemove)
  if (-not $PathToRemove) { return }
  if (Test-Path $PathToRemove) {
    try {
      Remove-Item $PathToRemove -Recurse -Force -ErrorAction Stop
      Write-Step "Removed: $PathToRemove"
    } catch {
      Write-Err "Could not remove $PathToRemove : $_"
    }
  }
}

function Invoke-UninstallString {
  param([string]$UninstallString)
  if (-not $UninstallString) { return }

  $expanded = [Environment]::ExpandEnvironmentVariables($UninstallString).Trim()
  if (-not $expanded) { return }

  if ($expanded -match 'msiexec(\.exe)?') {
    $args = ($expanded -replace '.*?msiexec(\.exe)?\s*', '')
    if ($args -notmatch '(/x|/uninstall)') { $args = "/x $args" }
    if ($args -notmatch '(/qn|/quiet)') { $args += " /qn" }
    if ($args -notmatch '/norestart') { $args += " /norestart" }
    Start-Process -FilePath "msiexec.exe" -ArgumentList $args -Wait -WindowStyle Hidden
    return
  }

  if ($expanded.StartsWith('"')) {
    $parts = $expanded -split '"'
    $exe = $parts[1]
    $args = $expanded.Substring($exe.Length + 2).Trim()
    if ($args -notmatch '(/S|/silent|/quiet|/qn)') { $args += " /S" }
    Start-Process -FilePath $exe -ArgumentList $args -Wait -WindowStyle Hidden
    return
  }

  $firstSpace = $expanded.IndexOf(' ')
  if ($firstSpace -gt 0) {
    $exe = $expanded.Substring(0, $firstSpace)
    $args = $expanded.Substring($firstSpace + 1)
    if ($args -notmatch '(/S|/silent|/quiet|/qn)') { $args += " /S" }
    Start-Process -FilePath $exe -ArgumentList $args -Wait -WindowStyle Hidden
  } else {
    Start-Process -FilePath $expanded -ArgumentList "/S" -Wait -WindowStyle Hidden
  }
}

function Uninstall-ByDisplayNamePattern {
  param([string]$Pattern)
  if (-not $Pattern) { return }

  $roots = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
  )

  foreach ($root in $roots) {
    $apps = Get-ItemProperty $root -ErrorAction SilentlyContinue | Where-Object {
      $_.DisplayName -and $_.DisplayName -match $Pattern
    }
    foreach ($app in $apps) {
      $uninstall = if ($app.QuietUninstallString) { $app.QuietUninstallString } else { $app.UninstallString }
      if ($uninstall) {
        Write-Step "Uninstalling $($app.DisplayName) via registry..."
        try { Invoke-UninstallString -UninstallString $uninstall } catch { Write-Err "Uninstall failed for $($app.DisplayName): $_" }
      }
    }
  }
}

function Install-WinGet {
  if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }

  Write-Step "Bootstrapping winget via PowerShell module..."

  try {
    # Install NuGet provider (required for Install-Module)
    Write-Step "Installing NuGet provider..."
    Install-PackageProvider -Name NuGet -Force | Out-Null

    # Install WinGet PowerShell module
    Write-Step "Installing Microsoft.WinGet.Client module..."
    Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null

    # Bootstrap winget using Repair-WinGetPackageManager
    Write-Step "Running Repair-WinGetPackageManager..."
    Repair-WinGetPackageManager -AllUsers

    # Refresh PATH
    Refresh-Path
    Start-Sleep -Seconds 2

    if (Get-Command winget -ErrorAction SilentlyContinue) {
      Write-Ok "winget installed successfully!"
      return $true
    }
  } catch {
    Write-Err "winget bootstrap failed: $_"
  }

  Write-Step "Continuing without winget (using direct installers)..."
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

  # Find npm
  $npmPath = "$env:ProgramFiles\nodejs\npm.cmd"
  if (-not (Test-Path $npmPath)) {
    $npmPath = (Get-Command npm.cmd -ErrorAction SilentlyContinue).Source
  }
  if (-not $npmPath) {
    $npmPath = (Get-Command npm -ErrorAction SilentlyContinue).Source
  }

  if ($npmPath -and (Test-Path $npmPath)) {
    # Run npm with ErrorActionPreference = Continue to ignore stderr notices
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    Write-Step "Running: npm install -g @openai/codex"
    cmd /c "`"$npmPath`" install -g @openai/codex" 2>&1 | ForEach-Object { Write-Host $_ }

    $ErrorActionPreference = $prevEAP

    # Ensure npm global bin is in PATH (persistent)
    $npmPrefix = cmd /c "`"$npmPath`" config get prefix" 2>$null
    if ($npmPrefix) {
      $npmPrefix = $npmPrefix.Trim()
      $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
      if ($userPath -notlike "*$npmPrefix*") {
        Write-Step "Adding npm global path to User PATH: $npmPrefix"
        [Environment]::SetEnvironmentVariable('Path', "$userPath;$npmPrefix", 'User')
      }
      if ($env:Path -notlike "*$npmPrefix*") {
        $env:Path += ";$npmPrefix"
      }
    }

    Refresh-Path
    if (Get-Command codex -ErrorAction SilentlyContinue) {
      Write-Ok "Codex CLI installed"
    } else {
      Write-Step "Codex installed but not in PATH yet - open a new terminal"
    }
  } else {
    Write-Err "npm not found - cannot install Codex CLI"
  }
}

function Uninstall-All {
  Write-Step "Uninstalling..."

  # Codex CLI
  if (Get-Command npm -ErrorAction SilentlyContinue) {
    npm uninstall -g @openai/codex 2>&1 | Out-Null
  }

  # Node.js & Python via winget
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget uninstall --id OpenJS.NodeJS.LTS -e --silent --disable-interactivity 2>&1 | Out-Null
    winget uninstall --id OpenJS.NodeJS -e --silent --disable-interactivity 2>&1 | Out-Null
    winget uninstall --id Python.Python.3.12 -e --silent --disable-interactivity 2>&1 | Out-Null
    winget uninstall --id Python.Python.3.11 -e --silent --disable-interactivity 2>&1 | Out-Null
    winget uninstall --id Python.Python.3.10 -e --silent --disable-interactivity 2>&1 | Out-Null
  }

  # Registry fallback (for direct installer cases)
  Uninstall-ByDisplayNamePattern -Pattern '^Node\.js'
  Uninstall-ByDisplayNamePattern -Pattern '^Python 3\.(10|11|12)'

  # Remove PATH traces
  $npmPrefix = $null
  if (Get-Command npm -ErrorAction SilentlyContinue) {
    try { $npmPrefix = (npm config get prefix 2>$null).Trim() } catch {}
  }
  Remove-PathEntry -TargetPath "$env:ProgramFiles\nodejs" -Scope Machine
  Remove-PathEntry -TargetPath "$env:ProgramFiles\nodejs" -Scope User
  Remove-PathEntry -TargetPath "$env:APPDATA\npm" -Scope User
  Remove-PathEntry -TargetPath "$env:LOCALAPPDATA\Microsoft\WindowsApps" -Scope User
  if ($npmPrefix) {
    Remove-PathEntry -TargetPath $npmPrefix -Scope User
    Remove-PathEntry -TargetPath $npmPrefix -Scope Machine
  }
  Remove-PathEntry -TargetPath "$env:ProgramFiles\Python312" -Scope Machine
  Remove-PathEntry -TargetPath "$env:ProgramFiles\Python312\Scripts" -Scope Machine
  Remove-PathEntry -TargetPath "$env:LOCALAPPDATA\Programs\Python\Python312" -Scope User
  Remove-PathEntry -TargetPath "$env:LOCALAPPDATA\Programs\Python\Python312\Scripts" -Scope User

  # Remove file system traces from install + common tool caches
  @(
    "$env:ProgramFiles\nodejs",
    "$env:APPDATA\npm",
    "$env:APPDATA\npm-cache",
    "$env:LOCALAPPDATA\npm-cache",
    "$env:USERPROFILE\.npm",
    "$env:USERPROFILE\.node-gyp",
    "$env:LOCALAPPDATA\Programs\Python\Python312",
    "$env:ProgramFiles\Python312",
    "$env:ProgramData\Python",
    "$env:APPDATA\Python",
    "$env:LOCALAPPDATA\pip\Cache",
    "$env:USERPROFILE\.codex",
    "$env:USERPROFILE\.openai"
  ) | ForEach-Object { Remove-DirectorySafe -PathToRemove $_ }

  # Remove script temp files if present
  Remove-Item "$env:TEMP\codex-one-step-install.ps1" -Force -ErrorAction SilentlyContinue
  Remove-Item "$env:TEMP\codex-installer.ps1" -Force -ErrorAction SilentlyContinue

  Refresh-Path

  Write-Ok "Uninstall complete (deep cleanup done)"
}

# === MAIN ===

Clear-Host
Write-Host ""
Write-Host "  Codex One-Step Installer v0.5.0" -ForegroundColor Cyan
Write-Host "  ================================" -ForegroundColor DarkCyan
Write-Host ""

# Check admin
if (-not (Test-Admin)) {
  Write-Step "Relaunching as Administrator..."
  $script = $PSCommandPath
  if (-not $script) {
    $script = Join-Path $env:TEMP "codex-installer.ps1"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/wmostert76/codex-one-step-installer/master/codex-one-step-install.ps1" -OutFile $script -UseBasicParsing
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

Write-Host ""
Write-Host "  Open a NEW terminal to use the tools." -ForegroundColor Yellow
Write-Host ""
