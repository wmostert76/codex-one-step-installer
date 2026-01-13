```
 ██████╗ ██████╗ ██████╗ ███████╗██╗  ██╗
██╔════╝██╔═══██╗██╔══██╗██╔════╝╚██╗██╔╝
██║     ██║   ██║██║  ██║█████╗   ╚███╔╝ 
██║     ██║   ██║██║  ██║██╔══╝   ██╔██╗ 
╚██████╗╚██████╔╝██████╔╝███████╗██╔╝ ██╗
 ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝
        ONE-STEP INSTALLER
```

Install Codex tooling on Windows in one command. One click runs the full install.

## Quick start
Direct raw script (latest):
```powershell
irm "https://raw.githubusercontent.com/wmostert76/Codex-OneStep-Installer/master/codex-one-step-install.ps1" | iex
```

Pinned to a tag (example):
```powershell
irm "https://raw.githubusercontent.com/wmostert76/Codex-OneStep-Installer/v1.0.0/codex-one-step-install.ps1" | iex
```
---

## Technical details (engineering tone)
This installer pulls and runs a PowerShell script that guides the setup of Codex tooling on Windows.

### Winget-free environments
When `winget` is unavailable (for example on Server SKUs without App Installer), the script now downloads the official Node.js, Python, and 7-Zip installers directly and installs them silently, so the same installer still works even without the Windows Package Manager.

### What it does
- Downloads the installer script and executes it in the current shell.
- Runs the full install flow (Node.js LTS + Python + Codex CLI) automatically.  
- Elevates to Administrator if needed and continues.
- Supports pinned tag installs for stable, repeatable environments.

### Script summary
- `codex-one-step-install.ps1` downloads the required tooling and runs the setup flow.
- The raw GitHub URL targets a specific branch or tag for stability.

### Safety notes
- Review the script before running if you prefer.
- Use the pinned tag for CI or provisioning to avoid surprises.

---

## Minimal (just the commands)

```powershell
irm "https://raw.githubusercontent.com/wmostert76/Codex-OneStep-Installer/master/codex-one-step-install.ps1" | iex
irm "https://raw.githubusercontent.com/wmostert76/Codex-OneStep-Installer/v1.0.0/codex-one-step-install.ps1" | iex
```

## FAQ
**Is this safe to run?**
Review the script and use pinned tags if you want a fixed version.

**What does it install?**
Codex tooling for Windows, configured for a smooth first run.

**Can I automate this?**
Yes. Use the pinned tag in CI or provisioning scripts to avoid surprises.

## Contributing
PRs and issues are welcome. If you propose changes to the installer flow, include the rationale and any environment assumptions.
