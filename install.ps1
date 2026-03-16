[CmdletBinding()]
param(
    [string]$RepoOwner = 'wmostert76',
    [string]$RepoName = 'codex-one-step-installer',
    [string]$Branch = 'main',
    [string]$NodeVersion = '18.20.8',
    [string]$PythonVersion = '3.9.13',
    [switch]$SkipLaunch
)

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
    Write-Host "[codex-installer v$ScriptVersion] $Message"
}

function Refresh-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = ($machinePath, $userPath | Where-Object { $_ }) -join ';'
}

function Get-CommandPath {
    param([Parameter(Mandatory = $true)][string]$Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    return $null
}

function Get-InstalledNodeVersion {
    $nodeCommand = Get-CommandPath -Name 'node.exe'
    if (-not $nodeCommand) {
        $candidate = Join-Path ${env:ProgramFiles} 'nodejs\node.exe'
        if (Test-Path $candidate) {
            $nodeCommand = $candidate
        }
    }

    if (-not $nodeCommand) {
        return $null
    }

    $versionOutput = & $nodeCommand '--version' 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $versionOutput) {
        return $null
    }

    return $versionOutput.Trim().TrimStart('v')
}

function Get-InstalledPythonVersion {
    $pythonCommand = Get-CommandPath -Name 'python.exe'
    if (-not $pythonCommand) {
        return $null
    }

    $versionOutput = & $pythonCommand '--version' 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $versionOutput) {
        return $null
    }

    $match = [regex]::Match($versionOutput, 'Python\s+([0-9]+(\.[0-9]+)+)')
    if (-not $match.Success) {
        return $null
    }

    return $match.Groups[1].Value
}

function Get-CodexCommandPath {
    $codexCommand = Get-CommandPath -Name 'codex.cmd'
    if (-not $codexCommand) {
        $candidate = Join-Path $env:APPDATA 'npm\codex.cmd'
        if (Test-Path $candidate) {
            $codexCommand = $candidate
        }
    }

    return $codexCommand
}

function Install-Node {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [Parameter(Mandatory = $true)]
        [string]$TempDir
    )

    $msiName = "node-v$Version-x64.msi"
    $msiPath = Join-Path $TempDir $msiName
    $nodeUrl = "https://nodejs.org/dist/v$Version/$msiName"

    Write-Step "Downloading Node.js $Version"
    Invoke-WebRequest -UseBasicParsing -Uri $nodeUrl -OutFile $msiPath

    Write-Step "Installing Node.js $Version"
    $arguments = @('/i', ('"{0}"' -f $msiPath), '/qn', '/norestart')
    $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Node.js installation failed with exit code $($process.ExitCode)."
    }
}

function Install-Python {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [Parameter(Mandatory = $true)]
        [string]$TempDir
    )

    $installerName = "python-$Version-amd64.exe"
    $installerPath = Join-Path $TempDir $installerName
    $pythonUrl = "https://www.python.org/ftp/python/$Version/$installerName"

    Write-Step "Downloading Python $Version"
    Invoke-WebRequest -UseBasicParsing -Uri $pythonUrl -OutFile $installerPath

    Write-Step "Installing Python $Version"
    $arguments = @(
        '/quiet',
        'InstallAllUsers=1',
        'PrependPath=1',
        'Include_launcher=1',
        'AssociateFiles=1',
        'Shortcuts=0',
        'Include_test=0',
        'Include_doc=0',
        'Include_dev=0'
    )
    $process = Start-Process -FilePath $installerPath -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Python installation failed with exit code $($process.ExitCode)."
    }
}

function Install-Codex {
    param(
        [Parameter(Mandatory = $true)]
        [string]$NpmCommand
    )

    Write-Step 'Installing @openai/codex globally with npm'
    $process = Start-Process -FilePath $NpmCommand -ArgumentList @('install', '-g', '@openai/codex') -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -ne 0) {
        throw "Codex installation failed with exit code $($process.ExitCode)."
    }
}

function Save-State {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProgramDataRoot,
        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )

    $statePath = Join-Path $ProgramDataRoot 'install-state.json'
    $State | ConvertTo-Json | Set-Content -Path $statePath -Encoding ASCII
}

if (-not (Test-IsAdministrator)) {
    throw 'Run this installer from an elevated PowerShell session.'
}

$programDataRoot = Join-Path $env:ProgramData 'CodexOneStepInstaller'
$tempDir = Join-Path $env:TEMP ('codex-installer-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $programDataRoot | Out-Null
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

try {
    Write-Step 'Starting installation'

    $installedNodeVersion = Get-InstalledNodeVersion
    if ($installedNodeVersion -eq $NodeVersion) {
        Write-Step "Skipping Node.js installation because version $NodeVersion is already installed"
    }
    else {
        Install-Node -Version $NodeVersion -TempDir $tempDir
    }

    $installedPythonVersion = Get-InstalledPythonVersion
    if ($installedPythonVersion -eq $PythonVersion) {
        Write-Step "Skipping Python installation because version $PythonVersion is already installed"
    }
    else {
        Install-Python -Version $PythonVersion -TempDir $tempDir
    }

    Refresh-ProcessPath

    $npmCommand = Get-CommandPath -Name 'npm.cmd'
    if (-not $npmCommand) {
        $npmCommand = Join-Path ${env:ProgramFiles} 'nodejs\npm.cmd'
    }
    if (-not (Test-Path $npmCommand)) {
        throw 'npm.cmd was not found after Node.js installation.'
    }

    $codexCommand = Get-CodexCommandPath
    if ($codexCommand) {
        Write-Step 'Skipping Codex installation because codex.cmd is already available'
    }
    else {
        Install-Codex -NpmCommand $npmCommand
    }

    Refresh-ProcessPath

    $codexCommand = Get-CodexCommandPath
    if (-not $codexCommand) {
        throw 'codex.cmd was not found after npm installation.'
    }

    Save-State -ProgramDataRoot $programDataRoot -State @{
        installedAt  = (Get-Date).ToString('o')
        repoOwner    = $RepoOwner
        repoName     = $RepoName
        branch       = $Branch
        nodeVersion  = $NodeVersion
        pythonVersion = $PythonVersion
        npmCommand   = $npmCommand
        codexCommand = $codexCommand
        uninstallScript = (Join-Path $programDataRoot 'uninstall.ps1')
    }

    Write-Step "Installation complete. Uninstall script saved to $programDataRoot\uninstall.ps1"
    Write-Host ''
    Write-Host 'If Codex asks for authentication, complete the login/API key setup in that session.'
    Write-Host ''

    if (-not $SkipLaunch) {
        Write-Step 'Launching Codex with --dangerously-bypass-approvals-and-sandbox --search'
        & $codexCommand '--dangerously-bypass-approvals-and-sandbox' '--search'
    }
}
finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
