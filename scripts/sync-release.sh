#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: scripts/sync-release.sh <version> [changelog-file]" >&2
  exit 1
fi

VERSION="$1"
CHANGELOG_FILE="${2:-}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "$CHANGELOG_FILE" ]]; then
  CHANGELOG_FILE="$(mktemp)"
  cat >"$CHANGELOG_FILE" <<EOF
## Changelog
- release $VERSION
EOF
  CLEANUP_CHANGELOG=1
else
  CLEANUP_CHANGELOG=0
fi

cd "$REPO_ROOT"

printf '%s\n' "$VERSION" > VERSION

python3 - "$VERSION" <<'PY'
from pathlib import Path
import re
import sys

version = sys.argv[1]
root = Path.cwd()

targets = [
    root / "bootstrap.ps1",
    root / "install.ps1",
    root / "uninstall.ps1",
]

for path in targets:
    text = path.read_text(encoding="ascii")
    text = re.sub(r"\[string\]\$ScriptVersion = '[^']+'", f"[string]$ScriptVersion = '{version}'", text, count=1)
    path.write_text(text, encoding="ascii")

readme = root / "README.md"
text = readme.read_text(encoding="utf-8")
text = re.sub(r"Huidige release: `[^`]+`", f"Huidige release: `{version}`", text, count=1)
readme.write_text(text, encoding="utf-8")
PY

git add -A
git commit -m "Release $VERSION"
git push origin main
git tag -f "$VERSION"
git push origin "refs/tags/$VERSION" --force

if gh release view "$VERSION" --repo wmostert76/codex-one-step-installer >/dev/null 2>&1; then
  gh release edit "$VERSION" --repo wmostert76/codex-one-step-installer --title "$VERSION" --notes-file "$CHANGELOG_FILE"
else
  gh release create "$VERSION" --repo wmostert76/codex-one-step-installer --title "$VERSION" --notes-file "$CHANGELOG_FILE"
fi

if [[ "$CLEANUP_CHANGELOG" == "1" ]]; then
  rm -f "$CHANGELOG_FILE"
fi
