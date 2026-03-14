[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Write-Step {
    param([string]$Message)
    Write-Host "[codex-uninstall] $Message"
}

function Refresh-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = ($machinePath, $userPath | Where-Object { $_ }) -join ';'
}

function Get-UninstallEntry {
    param([Parameter(Mandatory = $true)][string[]]$DisplayNames)

    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ($root in $roots) {
        $entry = Get-ItemProperty -Path $root -ErrorAction SilentlyContinue |
            Where-Object {
                if (-not $_.DisplayName) {
                    return $false
                }

                $installedName = $_.DisplayName
                foreach ($candidate in $DisplayNames) {
                    if ($candidate -and ($installedName -eq $candidate -or $installedName.StartsWith($candidate))) {
                        return $true
                    }
                }

                return $false
            } |
            Select-Object -First 1
        if ($entry) {
            return $entry
        }
    }

    return $null
}

function Invoke-UninstallEntry {
    param([Parameter(Mandatory = $true)]$Entry)

    if ($Entry.QuietUninstallString) {
        Write-Step "Running quiet uninstall for $($Entry.DisplayName)"
        $process = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', $Entry.QuietUninstallString) -Wait -PassThru -WindowStyle Hidden
        if ($process.ExitCode -ne 0) {
            throw "$($Entry.DisplayName) uninstall failed with exit code $($process.ExitCode)."
        }
        return
    }

    if ($Entry.UninstallString) {
        Write-Step "Running uninstall for $($Entry.DisplayName)"

        if ($Entry.UninstallString -match 'msiexec(\.exe)?') {
            $arguments = $Entry.UninstallString -replace '^[^ ]+\s*', ''
            $arguments = $arguments -replace '(^|\s)/I(\s|$)', '$1/X$2'
            if ($arguments -notmatch '(^|\s)/(quiet|qn)\b') {
                $arguments = "$arguments /qn /norestart"
            }
            $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $arguments -Wait -PassThru
        }
        else {
            $process = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', $Entry.UninstallString) -Wait -PassThru -WindowStyle Hidden
        }

        if ($process.ExitCode -ne 0) {
            throw "$($Entry.DisplayName) uninstall failed with exit code $($process.ExitCode)."
        }
    }
}

if (-not (Test-IsAdministrator)) {
    throw 'Run this uninstall script from an elevated PowerShell session.'
}

$programDataRoot = Join-Path $env:ProgramData 'CodexOneStepInstaller'
$statePath = Join-Path $programDataRoot 'install-state.json'
$state = $null

if (Test-Path $statePath) {
    $state = Get-Content -Path $statePath -Raw | ConvertFrom-Json
}

Write-Step 'Stopping running Codex processes'
Get-Process -Name 'codex' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Refresh-ProcessPath

$npmCommand = $null
if ($state -and $state.npmCommand -and (Test-Path $state.npmCommand)) {
    $npmCommand = $state.npmCommand
}
elseif (Get-Command 'npm.cmd' -ErrorAction SilentlyContinue) {
    $npmCommand = (Get-Command 'npm.cmd').Source
}
else {
    $candidate = Join-Path ${env:ProgramFiles} 'nodejs\npm.cmd'
    if (Test-Path $candidate) {
        $npmCommand = $candidate
    }
}

if ($npmCommand) {
    Write-Step 'Removing @openai/codex global package'
    $process = Start-Process -FilePath $npmCommand -ArgumentList @('uninstall', '-g', '@openai/codex') -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -ne 0) {
        Write-Warning "npm uninstall returned exit code $($process.ExitCode). Continuing cleanup."
    }
}

$pathsToRemove = @(
    (Join-Path $env:APPDATA 'npm\codex'),
    (Join-Path $env:APPDATA 'npm\codex.cmd'),
    (Join-Path $env:USERPROFILE '.codex'),
    (Join-Path $env:LOCALAPPDATA 'openai\codex')
)

foreach ($path in $pathsToRemove) {
    if (Test-Path $path) {
        Write-Step "Removing $path"
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$nodeDisplayName = if ($state -and $state.nodeVersion) { "Node.js $($state.nodeVersion) (x64)" } else { $null }
$pythonDisplayName = if ($state -and $state.pythonVersion) { "Python $($state.pythonVersion) (64-bit)" } else { $null }

$nodeCandidates = @($nodeDisplayName, 'Node.js') | Where-Object { $_ }
$pythonCandidates = @($pythonDisplayName, 'Python 3.9.13 (64-bit)', 'Python 3.9.13 Core Interpreter (64-bit)') | Where-Object { $_ }

$nodeEntry = Get-UninstallEntry -DisplayNames $nodeCandidates
if ($nodeEntry) {
    Invoke-UninstallEntry -Entry $nodeEntry
}
else {
    Write-Warning 'Node.js uninstall entry was not found.'
}

$pythonEntry = Get-UninstallEntry -DisplayNames $pythonCandidates
if ($pythonEntry) {
    Invoke-UninstallEntry -Entry $pythonEntry
}
else {
    Write-Warning 'Python uninstall entry was not found.'
}

if (Test-Path $programDataRoot) {
    Write-Step "Removing $programDataRoot"
    Remove-Item -Path $programDataRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Step 'Uninstall complete'
