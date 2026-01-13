# Changelog

All notable changes to this project will be documented in this file.

- Placeholder for upcoming changes.

## [0.2.1] - 2026-01-13
- Added a complete winget-free path that downloads and installs Node.js, Python, and 7-Zip directly when the Windows Package Manager is missing.
- Improved the compatibility helpers so the script uses `-UseBasicParsing` on legacy PowerShell and relies on the Python.org metadata API to select a working installer URL.
- Added a single `-Uninstall` switch that removes all tooling (Node.js, Python, 7-Zip, Codex CLI, and `.codex` profile) even on systems without winget.
- Added an explicit installer validation step so the script skips any Python release entry that lacks a downloadable AMD64 installer, preventing 404s like the one you saw.

## [0.1.3] - 2026-01-03
- Added welcome screen and version display.
- Improved Python install reliability.
- Added logging, dry-run, repair, and skip flags.
