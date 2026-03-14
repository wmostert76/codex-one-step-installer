[CmdletBinding()]
param(
    [string]$RepoOwner = 'wmostert76',
    [string]$RepoName = 'codex-one-step-installer',
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-RawUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch/$FileName"
}

$programDataRoot = Join-Path $env:ProgramData 'CodexOneStepInstaller'
New-Item -ItemType Directory -Force -Path $programDataRoot | Out-Null

$installPath = Join-Path $programDataRoot 'install.ps1'
$uninstallPath = Join-Path $programDataRoot 'uninstall.ps1'

Invoke-WebRequest -UseBasicParsing -Uri (Get-RawUrl -FileName 'install.ps1') -OutFile $installPath
Invoke-WebRequest -UseBasicParsing -Uri (Get-RawUrl -FileName 'uninstall.ps1') -OutFile $uninstallPath

& $installPath -RepoOwner $RepoOwner -RepoName $RepoName -Branch $Branch
