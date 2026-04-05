#!/bin/zsh
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"
swift build -c release
mkdir -p "${HOME}/.local/bin"
install -m 0755 "${REPO_ROOT}/.build/release/pdfpageexport" "${HOME}/.local/bin/pdfpageexport"
echo "Installed: ${HOME}/.local/bin/pdfpageexport"
