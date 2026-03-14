# codex-one-step-installer

PowerShell bootstrap voor een lege Windows Server 2016 machine die:

- TLS 1.2 forceert voor downloads
- Node.js downloadt en installeert
- Python downloadt en installeert
- `@openai/codex` globaal via npm installeert
- Codex meteen start met `--dangerously-bypass-approvals-and-sandbox --search`
- een uninstallscript neerzet dat Codex, Node.js en Python weer verwijdert

## Copy/paste install

Open een elevated PowerShell op Windows Server 2016 en plak:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
irm https://raw.githubusercontent.com/wmostert76/codex-one-step-installer/main/bootstrap.ps1 | iex
```

## Copy/paste uninstall

Als de repo live staat en de install een keer is uitgevoerd, staat het uninstallscript lokaal op:

```powershell
C:\ProgramData\CodexOneStepInstaller\uninstall.ps1
```

Start het zo:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
& 'C:\ProgramData\CodexOneStepInstaller\uninstall.ps1'
```

## Bestanden

- `bootstrap.ps1`: downloadt `install.ps1` en `uninstall.ps1` vanuit deze repo en start de installatie
- `install.ps1`: installeert Node.js, Python en Codex, slaat state op in `C:\ProgramData\CodexOneStepInstaller` en start Codex meteen
- `uninstall.ps1`: verwijdert de globale Codex npm package, ruimt lokale Codex-data op en probeert daarna Node.js en Python netjes te uninstallen

## Parameters

`install.ps1` ondersteunt optioneel:

```powershell
.\install.ps1 -NodeVersion 18.20.8 -PythonVersion 3.9.13
.\install.ps1 -SkipLaunch
```

## Belangrijke notities

- Draai install en uninstall als Administrator.
- De bootstrap gaat uit van publicatie op `wmostert76/codex-one-step-installer` branch `main`.
- De installer gebruikt op dit moment standaard `Node.js 18.20.8` en `Python 3.9.13`.
- OpenAI/Codex authenticatie wordt niet in het script ingebakken. Bij de eerste start van Codex moet je dus nog inloggen of een API-key/config klaar hebben staan.
- Codex zelf wordt officieel via npm geïnstalleerd als `@openai/codex`.
- Windows Server 2016 support hangt uiteindelijk ook af van wat de gekozen Node.js build op die host nog ondersteunt. Het script automatiseert de flow, maar kan upstream OS-limieten niet omzeilen.
- Python `3.9.25` gaf op 14 maart 2026 een `404` voor de klassieke Windows `amd64.exe`. Daarom gebruikt deze repo standaard `3.9.13`, de laatste 3.9-release waarvan die installer publiek beschikbaar is.
