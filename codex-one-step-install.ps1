# Codex One-Step Installer
# Installs Node.js (incl. npm), Python, Codex CLI (@openai/codex), and bootstraps .codex profile.
# Run this script in an elevated PowerShell for best results.
$ErrorActionPreference = 'Stop'
$ScriptVersion = '0.1.12'
$scriptUrl = 'https://raw.githubusercontent.com/wmostert76/Codex-OneStep-Installer/master/codex-one-step-install.ps1'
$profileZipUrl = 'https://raw.githubusercontent.com/wmostert76/Codex-OneStep-Installer/master/assets/codex-profile.zip'

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

function Read-Password {
  Write-Host "Enter profile ZIP password (exact, no trimming):" -ForegroundColor Yellow
  return (Read-Host)
}

if (-not (Test-IsAdmin)) {
  Write-Host "[Codex] Relaunching in elevated mode..." -ForegroundColor Yellow
  $cmd = "`$env:CODEX_ELEVATED='1'; irm '$scriptUrl' | iex"
  Start-Process -FilePath "powershell" -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command $cmd"
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
    Invoke-WebRequest -Uri $Url -OutFile $target
    return $target
  } catch {
    throw "Failed to download $Url: $($_.Exception.Message)"
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

function Get-LatestPythonRelease {
  try {
    $page = Invoke-WebRequest 'https://www.python.org/ftp/python/'
  } catch {
    throw "Failed to fetch Python releases page: $($_.Exception.Message)"
  }
  $matches = [regex]::Matches($page.Content, 'href="(?<version>\d+\.\d+\.\d+)/"')
  $versions = $matches | ForEach-Object { $_.Groups['version'].Value } | Where-Object { $_ -match '^3\.' } | Select-Object -Unique
  if (-not $versions) {
    throw "Could not parse Python release versions from the downloads page."
  }
  return $versions | Sort-Object {[Version]$_} -Descending | Select-Object -First 1
}

function Install-PythonManual {
  $version = Get-LatestPythonRelease
  $installerFile = "python-$version-amd64.exe"
  $url = "https://www.python.org/ftp/python/$version/$installerFile"
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

function Get-Latest7ZipInstaller {
  try {
    $page = Invoke-WebRequest 'https://www.7-zip.org/'
  } catch {
    throw "Failed to download 7-Zip landing page: $($_.Exception.Message)"
  }
  $match = [regex]::Match($page.Content, 'href="(?<path>/a/7z\d+-x64\.exe)"')
  if (-not $match.Success) {
    throw "Could not determine the 7-Zip installer URL."
  }
  return "https://www.7-zip.org$($match.Groups['path'].Value)"
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
  Write-Host "[Codex] Installing Node.js LTS..." -ForegroundColor Yellow        
  if (Test-WingetAvailable) {
    winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-source-agreements --accept-package-agreements
  } else {
    Write-Host "[Codex] winget missing; installing Node.js via the official MSI." -ForegroundColor Yellow
    Install-NodeManual
  }
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
  $sevenZipPath = Join-Path $env:ProgramFiles '7-Zip\7z.exe'
  if (Test-Path $sevenZipPath) {
    return
  }
  Write-Host "[Codex] Installing 7-Zip..." -ForegroundColor Yellow
  if (Test-WingetAvailable) {
    winget install --id 7zip.7zip -e --accept-source-agreements --accept-package-agreements
    return
  }
  $url = Get-Latest7ZipInstaller
  $installer = Download-ToTemp -Url $url
  Write-Host "[Codex] Running 7-Zip installer..." -ForegroundColor Yellow
  try {
    $process = Start-Process -FilePath $installer -ArgumentList '/S' -Wait -PassThru
    if ($process.ExitCode -ne 0) {
      throw "7-Zip installer failed with exit code $($process.ExitCode)."
    }
  } finally {
    if (Test-Path $installer) {
      Remove-Item -Force $installer -ErrorAction SilentlyContinue
    }
  }
  if (-not (Test-Path $sevenZipPath)) {
    throw "7-Zip installation completed but 7z.exe was not found."
  }
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
  $pwd = Read-Password
  $tempDir = Join-Path $env:TEMP ("codex-profile-test-{0}" -f ([Guid]::NewGuid().ToString('N')))
  New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
  $argsTest = @('x', $tempZip, "-o$tempDir", "-p$pwd", '-y')
  & $sevenZip @argsTest
  if ($LASTEXITCODE -ne 0) {
    try { Remove-Item -Recurse -Force $tempDir } catch {}
    throw "7-Zip extraction failed with exit code $LASTEXITCODE."
  }
  try { Remove-Item -Recurse -Force $tempDir } catch {}
  $argsFinal = @('x', $tempZip, "-o$target", "-p$pwd", '-y')
  & $sevenZip @argsFinal
  if ($LASTEXITCODE -ne 0) {
    throw "7-Zip extraction to profile failed with exit code $LASTEXITCODE."
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
  Write-Host "------------------" -ForegroundColor Cyan
  Write-Host "Installing Node.js LTS, Python, Codex CLI, and profile in one step..." -ForegroundColor Yellow
  Write-Host ""

  # Ensure TLS 1.2 for winget downloads
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  } catch {}

  Set-ExecutionPolicySafe

  # Prepare winget sources if available
  if (Test-WingetAvailable) {
    Update-WingetSources
  } else {
    Write-Host "[Codex] winget not found; switching to direct installers for Node.js, Python, and 7-Zip." -ForegroundColor Yellow
  }
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
