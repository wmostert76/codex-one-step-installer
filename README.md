# 🚀 Codex OneStep Installer

> One-click installer for AI coding tooling on Windows | Node.js + Python + Codex CLI + Claude Code | Zero configuration required

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
- **Winget-free Support** - Werkt ook op servers zonder Windows Package Manager
- **Pinned Versions** - Gebruik tags voor stabiele, herhaalbare installaties
- **Uninstall Support** - Volledige verwijdering met `-Uninstall` flag

## 🚀 Quick Start

### Installatie (Latest)
```powershell
$script = "$env:TEMP\codex-one-step-install.ps1"
Start-BitsTransfer -Source "https://raw.githubusercontent.com/wmostert76/Codex-OneStep-Installer/master/codex-one-step-install.ps1" -Destination $script
powershell -NoProfile -ExecutionPolicy Bypass -File $script
```

## 📦 Wat wordt geïnstalleerd?

| Component | Beschrijving |
|-----------|--------------|
| **Node.js LTS** | JavaScript runtime |
| **Python** | Python programming language |
| **Codex CLI** | OpenAI's AI coding assistant |
| **Claude Code** | Anthropic's AI coding assistant |

## 🗑️ Uninstall

```powershell
$script = "$env:TEMP\codex-one-step-install.ps1"
Start-BitsTransfer -Source "https://raw.githubusercontent.com/wmostert76/Codex-OneStep-Installer/master/codex-one-step-install.ps1" -Destination $script
powershell -NoProfile -ExecutionPolicy Bypass -File $script -Uninstall
```

Verwijdert Node.js, Python, Codex CLI, Claude Code en `.codex` profile directory.

## ❓ FAQ

| Vraag | Antwoord |
|-------|----------|
| **Is dit veilig?** | Review de script en gebruik pinned tags voor vaste versies |
| **Wat installeert het?** | Codex tooling voor Windows, geconfigureerd voor eerste gebruik |
| **Kan ik dit automatiseren?** | Ja, gebruik pinned tags in CI/provisioning scripts |

## 🛠️ Technische Details

- PowerShell script met automatische privilege escalatie
- Ondersteunt zowel Winget als directe installer downloads
- Werkt op Windows 10/11 en Windows Server

## 🤝 Contributing

PRs en issues zijn welkom. Bij wijzigingen aan de installer flow, beschrijf de rationale en omgevingsaannames.

