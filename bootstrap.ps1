[CmdletBinding()]
param(
    [string]$RepoOwner = 'wmostert76',
    [string]$RepoName = 'codex-one-step-installer',
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'
[string]$ScriptVersion = '0.0.2'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Write-Host "[codex-bootstrap v$ScriptVersion] Starting"

function Get-RawUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch/$FileName"
}

function Download-File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    try {
        Start-BitsTransfer -Source $Url -Destination $Destination -ErrorAction Stop
    }
    catch {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Destination
    }
}

$programDataRoot = Join-Path $env:ProgramData 'CodexOneStepInstaller'
New-Item -ItemType Directory -Force -Path $programDataRoot | Out-Null

$installPath = Join-Path $programDataRoot 'install.ps1'
$uninstallPath = Join-Path $programDataRoot 'uninstall.ps1'

Download-File -Url (Get-RawUrl -FileName 'install.ps1') -Destination $installPath
Download-File -Url (Get-RawUrl -FileName 'uninstall.ps1') -Destination $uninstallPath

& $installPath -RepoOwner $RepoOwner -RepoName $RepoName -Branch $Branch
