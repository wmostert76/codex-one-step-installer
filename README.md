# codex-one-step-installer

Windows Server 2016 PowerShell installer voor Codex CLI met directe bootstrap, TLS 1.2, uninstall-flow en release-sync.

## Release

- Huidige release: `0.0.9`
- Repo: `wmostert76/codex-one-step-installer`
- Licentie: [MIT](LICENSE)

## Wat dit doet

- forceert TLS 1.2 voor downloads
- downloadt en installeert Node.js
- downloadt en installeert Python
- installeert `@openai/codex` globaal via npm
- slaat Node.js, Python en Codex over als de gevraagde installatie al aanwezig is
- start Codex direct met `--dangerously-bypass-approvals-and-sandbox --search`
- zet een uninstallscript neer dat Codex, Node.js en Python weer verwijdert

## Snelle installatie

Open een elevated PowerShell op Windows Server 2016 en voer dit uit. De bootstrap wordt eerst naar disk gedownload en daarna pas gestart:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$bootstrap = Join-Path $env:TEMP 'codex-bootstrap.ps1'
Start-BitsTransfer -Source 'https://raw.githubusercontent.com/wmostert76/codex-one-step-installer/main/bootstrap.ps1' -Destination $bootstrap
& $bootstrap
```

## Uninstall

Na installatie staat het uninstallscript ook lokaal op `C:\ProgramData\CodexOneStepInstaller\uninstall.ps1`, maar de aanbevolen manier is direct via `irm`.

Uitvoeren:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
irm 'https://raw.githubusercontent.com/wmostert76/codex-one-step-installer/main/uninstall.ps1' | iex
```

Als je toch het lokale bestand wilt starten, gebruik dan `& 'C:\ProgramData\CodexOneStepInstaller\uninstall.ps1'`.

## Bestanden

- `bootstrap.ps1` downloadt `install.ps1` en `uninstall.ps1` en gebruikt eerst `Start-BitsTransfer`, met fallback naar `Invoke-WebRequest`
- `install.ps1` installeert Node.js, Python en Codex, schrijft state weg in `C:\ProgramData\CodexOneStepInstaller` en start Codex direct
- `uninstall.ps1` verwijdert de globale Codex npm-package, ruimt lokale Codex-data op en probeert daarna Node.js en Python netjes te uninstallen
- `VERSION` is de bron voor de releaseversie
- `scripts/sync-release.sh` houdt codeversie, commit, tag en GitHub release gelijk

## Parameters

Optionele install-parameters:

```powershell
.\install.ps1 -NodeVersion 18.20.8 -PythonVersion 3.9.13
.\install.ps1 -SkipLaunch
```

## Standaarden

- standaard Node.js: `18.20.8`
- standaard Python: `3.9.13`
- bootstrap branch: `main`
- GitHub release/tag: gelijk aan de versie in `VERSION` en `ScriptVersion`

## Aandachtspunten

- draai install en uninstall als Administrator
- OpenAI/Codex authenticatie wordt niet door deze scripts geconfigureerd; bij de eerste start moet je nog inloggen of een API-key/config klaar hebben
- Codex wordt officieel via npm geïnstalleerd als `@openai/codex`
- Windows Server 2016 support hangt uiteindelijk ook af van wat de gekozen Node.js build op die host nog ondersteunt
- Python `3.9.25` gaf op 14 maart 2026 een `404` voor de klassieke Windows `amd64.exe`; daarom gebruikt deze repo standaard `3.9.13`

## Release Flow

Gebruik voor een sync release:

```bash
scripts/sync-release.sh 0.0.9
scripts/sync-release.sh 0.0.9 /pad/naar/changelog.md
```

De bedoeling is:

- `VERSION`
- `ScriptVersion` in `bootstrap.ps1`, `install.ps1` en `uninstall.ps1`
- de releasevermelding in deze README
- de Git-tag en GitHub release

Die vier moeten altijd gelijk lopen.
