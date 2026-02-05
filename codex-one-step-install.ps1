# Codex One-Step Installer
# Installs Node.js (incl. npm), Python, Codex CLI (@openai/codex), and Claude Code.
# Run this script in an elevated PowerShell for best results.
param(
  [switch] $Uninstall
)
$ErrorActionPreference = 'Stop'
$ScriptVersion = '0.2.7'
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

function Pause-Exit {
  Write-Host "" 
  Write-Host "Press any key to close..." -ForegroundColor Yellow
  try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch {}
}

if (-not (Test-IsAdmin)) {
  Write-Host "[Codex] Relaunching in elevated mode..." -ForegroundColor Yellow
  $elevatedScript = $PSCommandPath
  if ([string]::IsNullOrWhiteSpace($elevatedScript) -or -not (Test-Path $elevatedScript)) {
    $cache = [DateTime]::UtcNow.Ticks
    $elevatedScript = Join-Path $env:TEMP 'codex-one-step-install-elevated.ps1'
    $elevatedUrl = "$scriptUrl?nocache=$cache"
    try {
      Start-BitsTransfer -Source $elevatedUrl -Destination $elevatedScript -ErrorAction Stop
    } catch {
      Invoke-WebRequest -Uri $elevatedUrl -OutFile $elevatedScript -UseBasicParsing
    }
  }
  $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$elevatedScript`""
  if ($Uninstall) {
    $argList += " -Uninstall"
  }
  Start-Process -FilePath "powershell" -Verb RunAs -ArgumentList $argList
  return
}

function Set-ExecutionPolicySafe {
  try {
    Write-Host "[Codex] Setting PowerShell execution policy to Unrestricted (LocalMachine)..." -ForegroundColor Yellow
    Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy Unrestricted -Force -ErrorAction Stop
    return
  } catch {
    Write-Host "[Codex] LocalMachine policy change failed; trying CurrentUser..." -ForegroundColor Yellow
  }
  try {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force -ErrorAction Stop
  } catch {
    Write-Host "[Codex] Execution policy change blocked by system policy; continuing..." -ForegroundColor Yellow
  }
}

$script:CodexWingetAvailable = $null
$script:CodexWingetChecked = $false
$script:CodexNodeAlreadyPresent = $false

function Test-WingetAvailable {
  if (-not $script:CodexWingetChecked) {
    try {
      Get-Command winget -ErrorAction Stop | Out-Null
      $script:CodexWingetAvailable = $true
    } catch {
      $script:CodexWingetAvailable = $false
    }
    $script:CodexWingetChecked = $true
  }
  return $script:CodexWingetAvailable
}

function Install-WingetIfMissing {
  if (Test-WingetAvailable) {
    return $true
  }
  Write-Host "[Codex] winget not found; attempting bootstrap via Microsoft.WinGet.Client..." -ForegroundColor Yellow
  $previousProgressPreference = $global:ProgressPreference
  $previousConfirmPreference = $global:ConfirmPreference
  try {
    $global:ProgressPreference = 'SilentlyContinue'
    $global:ConfirmPreference = 'None'
    try {
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } catch {}
    try {
      Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    } catch {}
    if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
      Install-PackageProvider -Name NuGet -MinimumVersion '2.8.5.201' -Force -ForceBootstrap -Scope CurrentUser -Confirm:$false | Out-Null
    }
    Import-PackageProvider -Name NuGet -MinimumVersion '2.8.5.201' -Force -ErrorAction SilentlyContinue | Out-Null
    Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -Scope CurrentUser -AllowClobber -Confirm:$false | Out-Null
    Import-Module Microsoft.WinGet.Client -Force -ErrorAction Stop
    Repair-WinGetPackageManager -AllUsers | Out-Null
    $script:CodexWingetChecked = $false
    if (Test-WingetAvailable) {
      Write-Host "[Codex] winget bootstrap succeeded." -ForegroundColor Green
      return $true
    }
    Write-Host "[Codex] winget bootstrap ran, but winget is still unavailable." -ForegroundColor Yellow
  } catch {
    Write-Host "[Codex] winget bootstrap failed: $($_.Exception.Message)" -ForegroundColor Yellow
  } finally {
    $global:ProgressPreference = $previousProgressPreference
    $global:ConfirmPreference = $previousConfirmPreference
  }
  return $false
}

function Test-NodeInstalled {
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    return $false
  }
  try {
    $version = node -v 2>$null
    return -not [string]::IsNullOrWhiteSpace($version)
  } catch {
    return $false
  }
}

function Test-PythonInstalled {
  if (Get-Command python -ErrorAction SilentlyContinue) {
    try {
      $version = python --version 2>$null
      if (-not [string]::IsNullOrWhiteSpace($version)) {
        return $true
      }
    } catch {}
  }
  if (Get-Command py -ErrorAction SilentlyContinue) {
    try {
      $version = py -V 2>$null
      return -not [string]::IsNullOrWhiteSpace($version)
    } catch {
      return $false
    }
  }
  return $false
}

function Test-CodexInstalled {
  if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    return $false
  }
  try {
    $version = codex --version 2>$null
    return -not [string]::IsNullOrWhiteSpace($version)
  } catch {
    return $false
  }
}

function Test-ClaudeInstalled {
  if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    return $false
  }
  try {
    $version = claude --version 2>$null
    return -not [string]::IsNullOrWhiteSpace($version)
  } catch {
    return $false
  }
}

function Invoke-WebRequestCompat {
  param (
    [Parameter(Mandatory)]
    [hashtable]
    $Params
  )
  if ($PSVersionTable.PSVersion.Major -lt 6) {
    $Params.UseBasicParsing = $true
  }
  Invoke-WebRequest @Params
}

function Download-ToTemp {
  param (
    [Parameter(Mandatory)]
    [string] $Url,
    [string] $FileName
  )
  try {
    $name = if ($FileName) { $FileName } else { [System.IO.Path]::GetFileName($Url) }
    $target = Join-Path $env:TEMP $name
    if (Test-Path $target) {
      Remove-Item -Force $target
    }
    Write-Host "[Codex] Downloading $name..." -ForegroundColor Yellow
    Invoke-WebRequestCompat -Params @{ Uri = $Url; OutFile = $target }
    return $target
  } catch {
    throw "Failed to download ${Url}: $($_.Exception.Message)"
  }
}

function Test-UrlExists {
  param (
    [Parameter(Mandatory)]
    [string] $Url
  )
  try {
    Invoke-WebRequestCompat -Params @{ Uri = $Url; Method = 'Head' } | Out-Null
    return $true
  } catch {
    return $false
  }
}

function Get-LatestNodeLtsRelease {
  try {
    $index = Invoke-RestMethod 'https://nodejs.org/dist/index.json'
  } catch {
    throw "Failed to fetch Node.js release metadata: $($_.Exception.Message)"
  }
  $ltsRelease = $index | Where-Object { $_.lts } | Select-Object -First 1
  if (-not $ltsRelease) {
    throw "Could not determine the latest Node.js LTS release."
  }
  return $ltsRelease
}

function Install-NodeManual {
  $release = Get-LatestNodeLtsRelease
  $installerFile = "node-$($release.version)-x64.msi"
  $url = "https://nodejs.org/dist/$($release.version)/$installerFile"
  $installer = Download-ToTemp -Url $url -FileName $installerFile
  Write-Host "[Codex] Running Node.js installer..." -ForegroundColor Yellow
  try {
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $installer, "/qn", "/norestart", "ADDLOCAL=ALL" -Wait -PassThru
    if ($process.ExitCode -ne 0) {
      throw "Node.js installer failed with exit code $($process.ExitCode)."
    }
  } finally {
    if (Test-Path $installer) {
      Remove-Item -Force $installer -ErrorAction SilentlyContinue
    }
  }
}

function Get-PythonInstallerUrl {
  param (
    [Parameter(Mandatory)]
    [Version] $Version
  )
  $verString = $Version.ToString()
  return "https://www.python.org/ftp/python/$verString/python-$verString-amd64.exe"
}

function Get-LatestPythonRelease {
  try {
    $releases = Invoke-RestMethod 'https://www.python.org/api/v2/downloads/release/?is_published=true'
  } catch {
    throw "Failed to fetch Python release metadata: $($_.Exception.Message)"
  }
  $candidates = @()
  foreach ($release in $releases) {
    if (-not $release.name.StartsWith('Python ')) {
      continue
    }
    $match = [regex]::Match($release.name, 'Python (?<version>\d+\.\d+\.\d+)')
    if (-not $match.Success) {
      continue
    }
    if ($release.pre_release) {
      continue
    }
    $version = [Version]$match.Groups['version'].Value
    $candidates += [PSCustomObject]@{
      Version = $version
      Release = $release
    }
  }
  if (-not $candidates) {
    throw "Could not parse Python release metadata."
  }
  $sorted = $candidates | Sort-Object -Property Version -Descending
  foreach ($candidate in $sorted) {
    $installerUrl = Get-PythonInstallerUrl -Version $candidate.Version
    if (Test-UrlExists -Url $installerUrl) {
      return [PSCustomObject]@{
        Version = $candidate.Version
        Release = $candidate.Release
        InstallerUrl = $installerUrl
      }
    } else {
      Write-Host "[Codex] Python installer for version $($candidate.Version) missing; trying next release..." -ForegroundColor Yellow
    }
  }
  throw "Could not find a downloadable Python installer."
}

function Install-PythonManual {
  $pythonMeta = Get-LatestPythonRelease
  $url = $pythonMeta.InstallerUrl
  $installerFile = [System.IO.Path]::GetFileName($url)
  $installer = Download-ToTemp -Url $url -FileName $installerFile
  Write-Host "[Codex] Running Python installer..." -ForegroundColor Yellow
  $args = "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_launcher=1", "Include_test=0"
  try {
    $process = Start-Process -FilePath $installer -ArgumentList $args -Wait -PassThru
    if ($process.ExitCode -ne 0) {
      throw "Python installer failed with exit code $($process.ExitCode)."
    }
  } finally {
    if (Test-Path $installer) {
      Remove-Item -Force $installer -ErrorAction SilentlyContinue
    }
  }
}

function Update-WingetSources {
  if (-not (Test-WingetAvailable)) {
    Write-Host "[Codex] winget not available; skipping source update." -ForegroundColor Yellow
    return
  }
  Write-Host "[Codex] Updating winget sources..." -ForegroundColor Yellow
  winget source update --accept-source-agreements | Out-Null
}

function Install-Node {
  if (Test-NodeInstalled) {
    $script:CodexNodeAlreadyPresent = $true
    Write-Host "[Codex] Node.js is already installed; skipping." -ForegroundColor Yellow
    return
  }
  Write-Host "[Codex] Installing Node.js LTS..." -ForegroundColor Yellow        
  if (Test-WingetAvailable) {
    winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-source-agreements --accept-package-agreements
  } else {
    Write-Host "[Codex] winget missing; installing Node.js via the official MSI." -ForegroundColor Yellow
    Install-NodeManual
  }
}

function Update-Npm {
  if ($script:CodexNodeAlreadyPresent) {
    Write-Host "[Codex] Skipping npm update because Node.js was already present." -ForegroundColor Yellow
    return
  }
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
  if (Test-PythonInstalled) {
    Write-Host "[Codex] Python is already installed; skipping." -ForegroundColor Yellow
    return
  }
  Write-Host "[Codex] Installing Python..." -ForegroundColor Yellow
  if (-not (Test-WingetAvailable)) {
    Write-Host "[Codex] winget missing; installing Python via the official installer." -ForegroundColor Yellow
    Install-PythonManual
    return
  }
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
  if (Test-CodexInstalled) {
    Write-Host "[Codex] Codex CLI is already installed; skipping." -ForegroundColor Yellow
    return
  }
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

function Install-ClaudeCode {
  if (Test-ClaudeInstalled) {
    Write-Host "[Codex] Claude Code is already installed; skipping." -ForegroundColor Yellow
    return
  }

  Write-Host "[Codex] Installing Claude Code (latest)..." -ForegroundColor Yellow
  $installerUrl = 'https://claude.ai/install.ps1'
  $installerPath = Join-Path $env:TEMP 'claude-install.ps1'
  try {
    try {
      Start-BitsTransfer -Source $installerUrl -Destination $installerPath -ErrorAction Stop
    } catch {
      Invoke-WebRequestCompat -Params @{ Uri = $installerUrl; OutFile = $installerPath }
    }
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $installerPath, "latest" -Wait -PassThru
    if ($process.ExitCode -ne 0) {
      throw "Claude Code installer failed with exit code $($process.ExitCode)."
    }
  } finally {
    if (Test-Path $installerPath) {
      Remove-Item -Force $installerPath -ErrorAction SilentlyContinue
    }
  }
}

function Get-UninstallRegistryEntries {
  param (
    [Parameter(Mandatory)]
    [string] $Pattern
  )
  $paths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
  )
  $entries = @()
  foreach ($path in $paths) {
    if (-not (Test-Path $path)) {
      continue
    }
    Get-ChildItem -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
      try {
        $props = Get-ItemProperty -Path $_.PSPath -ErrorAction Stop
      } catch {
        continue
      }
      if ($props.DisplayName -and ($props.DisplayName -match $Pattern)) {
        $entries += [PSCustomObject]@{
          DisplayName = $props.DisplayName
          UninstallString = $props.UninstallString
          RegistryPath = $_.PSPath
        }
      }
    }
  }
  return $entries
}

function Remove-UninstallRegistryEntry {
  param (
    [Parameter(Mandatory)]
    [string] $RegistryPath
  )
  try {
    Remove-Item -LiteralPath $RegistryPath -Force -Recurse -ErrorAction Stop
    Write-Host "[Codex] Removed uninstall registry entry at $RegistryPath." -ForegroundColor Yellow
  } catch {
    Write-Host ("[Codex] Failed to remove registry entry {0}: {1}" -f $RegistryPath, $_.Exception.Message) -ForegroundColor Yellow
  }
}

function Run-ManualUninstall {
  param (
    [Parameter(Mandatory)]
    [string] $Pattern,
    [Parameter(Mandatory)]
    [string] $FriendlyName
  )
  $entries = Get-UninstallRegistryEntries -Pattern $Pattern
  if (-not $entries) {
    Write-Host "[Codex] No $FriendlyName entries found; skipping." -ForegroundColor Yellow
    return
  }
  foreach ($entry in $entries | Sort-Object DisplayName -Unique) {
    if (-not $entry.UninstallString) {
      continue
    }
    Write-Host "[Codex] Uninstalling $FriendlyName ($($entry.DisplayName))..." -ForegroundColor Yellow
    $guidMatch = [regex]::Match($entry.UninstallString, '\{[0-9A-Fa-f\-]{36}\}')
    if ($guidMatch.Success) {
      $exe = "msiexec.exe"
      $args = "/x", $guidMatch.Value, "/qn", "/norestart"
    } else {
      $exe = "cmd.exe"
      $args = "/c", $entry.UninstallString
    }
    try {
      $process = Start-Process -FilePath $exe -ArgumentList $args -Wait -PassThru -ErrorAction Stop
      if ($process.ExitCode -ne 0) {
        Write-Host "[Codex] $FriendlyName uninstall returned code $($process.ExitCode)." -ForegroundColor Yellow
      }
    } catch {
      Write-Host "[Codex] Failed to uninstall $FriendlyName ($($entry.DisplayName)): $($_.Exception.Message)" -ForegroundColor Yellow
    }
    if ($entry.RegistryPath) {
      Remove-UninstallRegistryEntry -RegistryPath $entry.RegistryPath
    }
  }
}

function Uninstall-Node {
  Write-Host "[Codex] Removing Node.js..." -ForegroundColor Yellow
  if (Test-WingetAvailable) {
    try {
      winget uninstall --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
    } catch {
      Write-Host "[Codex] winget refused to remove Node.js; falling back to registry-based uninstall." -ForegroundColor Yellow
      Run-ManualUninstall -Pattern 'Node\.js' -FriendlyName 'Node.js'
    }
    return
  }
  Run-ManualUninstall -Pattern 'Node\.js' -FriendlyName 'Node.js'
}

function Uninstall-Python {
  Write-Host "[Codex] Removing Python..." -ForegroundColor Yellow
  $pythonIds = @(
    'Python.Python.3.12',
    'Python.Python.3.11',
    'Python.Python.3'
  )
  if (Test-WingetAvailable) {
    foreach ($id in $pythonIds) {
      try {
        winget uninstall --id $id -e --accept-source-agreements --accept-package-agreements
        return
      } catch {
        Write-Host "[Codex] winget uninstall failed for $id; trying next." -ForegroundColor Yellow
      }
    }
    Write-Host "[Codex] No Python uninstalls succeeded via winget; falling back to registry." -ForegroundColor Yellow
  }
  Run-ManualUninstall -Pattern '^Python 3' -FriendlyName 'Python 3.x'
}

function Remove-CodexCli {
  Write-Host "[Codex] Removing Codex CLI..." -ForegroundColor Yellow
  Refresh-Path
  if (Get-Command npm.cmd -ErrorAction SilentlyContinue) {
    npm.cmd uninstall -g @openai/codex
  } elseif (Get-Command npm -ErrorAction SilentlyContinue) {
    npm uninstall -g @openai/codex
  } else {
    Write-Host "[Codex] npm not found; skipping Codex CLI uninstall." -ForegroundColor Yellow
  }
}

function Remove-ClaudeCode {
  Write-Host "[Codex] Removing Claude Code..." -ForegroundColor Yellow
  Refresh-Path
  if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "[Codex] Claude Code not found; skipping uninstall." -ForegroundColor Yellow
    return
  }
  try {
    claude uninstall
  } catch {
    Write-Host "[Codex] Claude Code uninstall returned an error; continuing." -ForegroundColor Yellow
  }
}

function Remove-CodexProfile {
  $target = Join-Path $env:USERPROFILE '.codex'
  if (Test-Path $target) {
    Write-Host "[Codex] Removing Codex profile at $target..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force -Path $target
  } else {
    Write-Host "[Codex] No Codex profile directory found; skipping." -ForegroundColor Yellow
  }
}

function Run-UninstallFlow {
  Write-Host "[Codex] Running uninstall sequence..." -ForegroundColor Cyan
  Remove-CodexCli
  Remove-ClaudeCode
  Uninstall-Node
  Uninstall-Python
  Remove-CodexProfile
  Write-Host "[Codex] Uninstall complete." -ForegroundColor Green
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
  if (Get-Command claude -ErrorAction SilentlyContinue) {
    claude --version
  } else {
    Write-Host "Claude Code was not found on PATH." -ForegroundColor Yellow
  }
}

if ($Uninstall) {
  Run-UninstallFlow
  Pause-Exit
  return
}

try {
  Clear-Host
  Write-Host "Codex One-Step Installer v$ScriptVersion" -ForegroundColor Cyan
  Write-Host "------------------" -ForegroundColor Cyan
  Write-Host "Installing Node.js LTS, Python, Codex CLI, and Claude Code in one step..." -ForegroundColor Yellow
  Write-Host ""

  # Ensure TLS 1.2 for winget downloads
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  } catch {}

  Set-ExecutionPolicySafe

  # Prepare winget sources, with automatic bootstrap for Windows Sandbox-like environments
  if ((Test-WingetAvailable) -or (Install-WingetIfMissing)) {
    Update-WingetSources
  } else {
    Write-Host "[Codex] winget unavailable after bootstrap attempt; switching to direct installers for Node.js and Python." -ForegroundColor Yellow
  }
  Install-Node
  Update-Npm
  Install-Python
  Install-CodexCli
  Install-ClaudeCode
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
