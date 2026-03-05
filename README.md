# 🚀 Codex OneStep Installer

> One-click installer for AI coding tooling on Windows | Node.js + Python + Codex CLI | Zero configuration required

```
 ██████╗ ██████╗ ██████╗ ███████╗██╗  ██╗
██╔════╝██╔═══██╗██╔══██╗██╔════╝╚██╗██╔╝
██║     ██║   ██║██║  ██║█████╗   ╚███╔╝
██║     ██║   ██║██║  ██║██╔══╝   ██╔██╗
╚██████╗╚██████╔╝██████╔╝███████╗██╔╝ ██╗
 ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝
        ONE-STEP INSTALLER
```

## ✨ Features

- **One Command Install** - Volledige Codex setup in één PowerShell commando
- **Auto Elevation** - Vraagt automatisch Administrator rechten indien nodig
- **Direct Download Installers** - Geen Winget nodig; directe download en stille installatie
- **Pinned Versions** - Gebruik tags voor stabiele, herhaalbare installaties
- **Uninstall Support** - Deep cleanup van Node.js, Python, Codex CLI en bekende caches/sporen met `-Uninstall`

## 🚀 Quick Start

### Installatie (Latest)
```powershell
irm "https://raw.githubusercontent.com/wmostert76/codex-one-step-installer/master/codex-one-step-install.ps1" | iex
```

## 📦 Wat wordt geïnstalleerd?

| Component | Beschrijving |
|-----------|--------------|
| **Node.js LTS** | JavaScript runtime |
| **Python** | Python programming language |
| **Codex CLI** | OpenAI's AI coding assistant |

## 🗑️ Uninstall

```powershell
& ([ScriptBlock]::Create((irm "https://raw.githubusercontent.com/wmostert76/codex-one-step-installer/master/codex-one-step-install.ps1"))) -Uninstall
```

Verwijdert Node.js, Python en Codex CLI.

## ❓ FAQ

| Vraag | Antwoord |
|-------|----------|
| **Is dit veilig?** | Review de script en gebruik pinned tags voor vaste versies |
| **Wat installeert het?** | Codex tooling voor Windows, geconfigureerd voor eerste gebruik |
| **Kan ik dit automatiseren?** | Ja, gebruik pinned tags in CI/provisioning scripts |

## 🛠️ Technische Details

- PowerShell script met automatische privilege escalatie
- Gebruikt directe installer downloads (geen Winget afhankelijkheid)
- Werkt op Windows 10/11 en Windows Server

## 🤝 Contributing

PRs en issues zijn welkom. Bij wijzigingen aan de installer flow, beschrijf de rationale en omgevingsaannames.

