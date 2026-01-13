# Changelog

All notable changes to this project will be documented in this file.

- Placeholder for upcoming changes.

## [0.2.1] - 2026-01-13
- Added a complete winget-free path that downloads and installs Node.js, Python, and 7-Zip directly when the Windows Package Manager is missing.
- Improved the compatibility helpers so the script uses `-UseBasicParsing` on legacy PowerShell and relies on the Python.org metadata API to select a working installer URL.

## [0.1.3] - 2026-01-03
- Added welcome screen and version display.
- Improved Python install reliability.
- Added logging, dry-run, repair, and skip flags.
