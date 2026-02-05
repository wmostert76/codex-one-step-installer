$ErrorActionPreference = 'Stop'
$cache = [DateTime]::UtcNow.Ticks
$scriptUrl = "https://raw.githubusercontent.com/wmostert76/Codex-OneStep-Installer/master/codex-one-step-install.ps1?nocache=$cache"
$scriptPath = Join-Path $env:TEMP "codex-one-step-install-$cache.ps1"
try {
  Start-BitsTransfer -Source $scriptUrl -Destination $scriptPath -ErrorAction Stop
} catch {
  Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing
}
& $scriptPath
