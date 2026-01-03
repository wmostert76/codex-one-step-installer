$ErrorActionPreference = 'Stop'
$cache = [DateTime]::UtcNow.Ticks
$scriptUrl = "https://raw.githubusercontent.com/wmostert76/Codex-OneStep-Installer/master/codex-one-step-install.ps1?nocache=$cache"
$scriptText = irm $scriptUrl
& ([scriptblock]::Create($scriptText))
