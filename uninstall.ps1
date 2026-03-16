[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
[string]$ScriptVersion = '0.0.9'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Write-Step {
    param([string]$Message)
    Write-Host "[codex-uninstall v$ScriptVersion] $Message"
}

function Refresh-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = ($machinePath, $userPath | Where-Object { $_ }) -join ';'
}

function Split-CommandString {
    param([Parameter(Mandatory = $true)][string]$CommandString)

    $trimmedCommand = $CommandString.Trim()
    if ($trimmedCommand.StartsWith('"')) {
        $endQuoteIndex = $trimmedCommand.IndexOf('"', 1)
        if ($endQuoteIndex -lt 0) {
            throw "Unable to parse uninstall command: $CommandString"
        }

        return @{
            FilePath     = $trimmedCommand.Substring(1, $endQuoteIndex - 1)
            ArgumentList = $trimmedCommand.Substring($endQuoteIndex + 1).Trim()
        }
    }

    $parts = $trimmedCommand -split '\s+', 2
    return @{
        FilePath     = $parts[0]
        ArgumentList = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    }
}

function Test-IgnorableUninstallExitCode {
    param([int]$ExitCode)

    return $ExitCode -in @(1605, 1614)
}

function Get-UninstallEntries {
    param(
        [string[]]$DisplayNames = @(),
        [scriptblock]$FilterScript
    )

    $results = @()
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ($root in $roots) {
        $entries = Get-ItemProperty -Path $root -ErrorAction SilentlyContinue |
            Where-Object {
                if (-not $_.DisplayName) {
                    return $false
                }

                if ($FilterScript) {
                    return [bool](& $FilterScript $_)
                }

                $installedName = $_.DisplayName
                foreach ($candidate in $DisplayNames) {
                    if ($candidate -and ($installedName -eq $candidate -or $installedName.StartsWith($candidate))) {
                        return $true
                    }
                }

                return $false
            }
        if ($entries) {
            $results += $entries
        }
    }

    return @(
        $results |
            Sort-Object -Property DisplayName |
            Group-Object -Property PSPath |
            ForEach-Object { $_.Group[0] }
    )
}

function Invoke-UninstallEntry {
    param([Parameter(Mandatory = $true)]$Entry)

    if ($Entry.QuietUninstallString) {
        Write-Step "Running quiet uninstall for $($Entry.DisplayName)"
        $command = Split-CommandString -CommandString $Entry.QuietUninstallString
        $process = Start-Process -FilePath $command.FilePath -ArgumentList $command.ArgumentList -Wait -PassThru -WindowStyle Hidden
        if ($process.ExitCode -ne 0) {
            if (Test-IgnorableUninstallExitCode -ExitCode $process.ExitCode) {
                Write-Warning "$($Entry.DisplayName) uninstall returned exit code $($process.ExitCode). Continuing because the product may already be removed."
                return
            }

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
            $command = Split-CommandString -CommandString $Entry.UninstallString
            $process = Start-Process -FilePath $command.FilePath -ArgumentList $command.ArgumentList -Wait -PassThru -WindowStyle Hidden
        }

        if ($process.ExitCode -ne 0) {
            if (Test-IgnorableUninstallExitCode -ExitCode $process.ExitCode) {
                Write-Warning "$($Entry.DisplayName) uninstall returned exit code $($process.ExitCode). Continuing because the product may already be removed."
                return
            }

            throw "$($Entry.DisplayName) uninstall failed with exit code $($process.ExitCode)."
        }
    }
}

function Invoke-NodeFallbackUninstall {
    $candidatePaths = @(
        (Join-Path ${env:ProgramFiles} 'nodejs\uninstall.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'nodejs\uninstall.exe')
    ) | Where-Object { $_ }

    foreach ($candidate in $candidatePaths) {
        if (Test-Path $candidate) {
            Write-Step "Running fallback uninstall for Node.js via $candidate"
            $process = Start-Process -FilePath $candidate -ArgumentList '/S' -Wait -PassThru -WindowStyle Hidden
            if ($process.ExitCode -ne 0 -and -not (Test-IgnorableUninstallExitCode -ExitCode $process.ExitCode)) {
                throw "Node.js fallback uninstall failed with exit code $($process.ExitCode)."
            }

            return $true
        }
    }

    return $false
}

function Get-PackagesByName {
    param([Parameter(Mandatory = $true)][string[]]$NamePatterns)

    $results = @()
    foreach ($providerName in @('Programs', 'msi')) {
        try {
            $packages = Get-Package -ProviderName $providerName -ErrorAction Stop
            foreach ($package in $packages) {
                foreach ($pattern in $NamePatterns) {
                    if ($pattern -and $package.Name -like $pattern) {
                        $results += $package
                        break
                    }
                }
            }
        }
        catch {
            continue
        }
    }

    return @(
        $results |
            Sort-Object -Property Name, Version |
            Group-Object -Property FastPackageReference |
            ForEach-Object { $_.Group[0] }
    )
}

function Invoke-PackageUninstall {
    param([Parameter(Mandatory = $true)][object[]]$Packages)

    foreach ($package in $Packages) {
        Write-Step "Running package uninstall for $($package.Name)"
        try {
            Uninstall-Package -InputObject $package -Force -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Warning "Package uninstall for $($package.Name) failed: $($_.Exception.Message)"
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
    (Join-Path $env:APPDATA 'npm'),
    (Join-Path $env:APPDATA 'NuGet'),
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
$pythonCoreDisplayName = if ($state -and $state.pythonVersion) { "Python $($state.pythonVersion) Core Interpreter (64-bit)" } else { $null }

$nodeCandidates = @($nodeDisplayName, 'Node.js') | Where-Object { $_ }
$pythonCandidates = @(
    $pythonDisplayName,
    $pythonCoreDisplayName,
    'Python 3.9.13 (64-bit)',
    'Python 3.9.13 Core Interpreter (64-bit)'
) | Where-Object { $_ }

$nodeEntries = Get-UninstallEntries -DisplayNames $nodeCandidates
if ($nodeEntries.Count -gt 0) {
    Invoke-UninstallEntries -Entries $nodeEntries
}
else {
    Write-Warning 'Node.js uninstall entry was not found.'
    if (-not (Invoke-NodeFallbackUninstall)) {
        Write-Warning 'Node.js fallback uninstall path was not found.'
        $nodePackages = Get-PackagesByName -NamePatterns @('Node.js*', 'Nodejs*')
        if ($nodePackages.Count -gt 0) {
            Invoke-PackageUninstall -Packages $nodePackages
        }
        else {
            Write-Warning 'Node.js package uninstall entry was not found.'
        }
    }
}

$pythonEntries = Get-UninstallEntries -DisplayNames $pythonCandidates
if ($pythonEntries.Count -eq 0) {
    $pythonEntries = Get-UninstallEntries -FilterScript {
        param($Entry)

        if (-not $Entry.DisplayName) {
            return $false
        }

        $displayName = $Entry.DisplayName
        if ($displayName -notmatch '^Python ') {
            return $false
        }

        return $displayName -match '^Python \d+(\.\d+)+(\s+Core Interpreter)? \(64-bit\)$'
    }
}

function Invoke-UninstallEntries {
    param([Parameter(Mandatory = $true)][object[]]$Entries)

    foreach ($entry in $Entries) {
        Invoke-UninstallEntry -Entry $entry
    }
}

if ($pythonEntries.Count -gt 0) {
    Invoke-UninstallEntries -Entries $pythonEntries
}
else {
    Write-Warning 'Python uninstall entry was not found.'
}

$pythonLauncherEntries = Get-UninstallEntries -DisplayNames @('Python Launcher')
if ($pythonLauncherEntries.Count -gt 0) {
    Invoke-UninstallEntries -Entries $pythonLauncherEntries
}
else {
    $pythonLauncherPackages = Get-PackagesByName -NamePatterns @('Python Launcher*')
    if ($pythonLauncherPackages.Count -gt 0) {
        Invoke-PackageUninstall -Packages $pythonLauncherPackages
    }
    else {
        Write-Warning 'Python Launcher uninstall entry was not found.'
    }
}

if (Test-Path $programDataRoot) {
    Write-Step "Removing $programDataRoot"
    Remove-Item -Path $programDataRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Step 'Uninstall complete'
