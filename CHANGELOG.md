# Changelog

All notable changes to this project will be documented in this file.

- Placeholder for upcoming changes.

## [0.2.6] - 2026-02-05
- Hardened WinGet bootstrap for Windows Sandbox by enforcing fully non-interactive NuGet provider setup with explicit provider detection/import and `CurrentUser` scope module installation.
- Added temporary `ConfirmPreference='None'` handling during bootstrap to suppress confirmation prompts that could still appear in constrained sandbox sessions.

## [0.2.5] - 2026-02-05
- Fixed WinGet bootstrap in Windows Sandbox to run fully non-interactive by forcing NuGet provider bootstrap (`-ForceBootstrap`) and disabling confirmation prompts (`-Confirm:$false`).

## [0.2.4] - 2026-02-05
- Added Claude Code installation using Anthropic's official Windows installer flow (`https://claude.ai/install.ps1`) with target channel `latest`.
- Added skip detection so Claude Code is not reinstalled when already present.
- Added Claude Code verification output and uninstall integration (`claude uninstall` when available).
- Updated README to include Claude Code in the installed and removed components lists.

## [0.2.3] - 2026-02-05
- Switched installer download examples to `Start-BitsTransfer` (with fallback where relevant) so usage no longer relies on streamed `irm ... | iex`.
- Updated the self-elevation flow in `codex-one-step-install.ps1` to download the script to `%TEMP%` and execute it, instead of streaming.
- Updated `bootstrap.ps1` to download and execute the script file via BITS (fallback to `Invoke-WebRequest`).

## [0.2.2] - 2026-02-05
- Added automatic WinGet bootstrap for environments where `winget` is not preinstalled (including Windows Sandbox) using `Microsoft.WinGet.Client` and `Repair-WinGetPackageManager -AllUsers`.
- Added install skip logic so Node.js, Python, and Codex CLI are not reinstalled when already present and working.
- Updated README to remove the pinned-version install section.

## [0.2.1] - 2026-01-13
- Added a complete winget-free path that downloads and installs Node.js and Python directly when the Windows Package Manager is missing.
- Improved the compatibility helpers so the script uses `-UseBasicParsing` on legacy PowerShell and relies on the Python.org metadata API to select a working installer URL.
- Added a single `-Uninstall` switch that removes all tooling (Node.js, Python, Codex CLI, and `.codex` profile) even on systems without winget, and now deletes the matching uninstall registry entries so the apps disappear from “Apps & features.”
- Removed the codex-profile ZIP extraction flow so the installer no longer pulls or extracts the asset, which also removes the 7-Zip dependency while keeping the `.codex` cleanup handy.
- Added an explicit installer validation step so the script skips any Python release entry that lacks a downloadable AMD64 installer, preventing 404s like the one you saw.

## [0.1.3] - 2026-01-03
- Added welcome screen and version display.
- Improved Python install reliability.
- Added logging, dry-run, repair, and skip flags.
