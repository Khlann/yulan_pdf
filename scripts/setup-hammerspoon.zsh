#!/bin/zsh
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"${REPO_ROOT}/scripts/install-cli.sh"
HS_INIT="${HOME}/.hammerspoon/init.lua"
MARKER="-- 页览 Yulan export (auto-added)"
LOADER="dofile([["${REPO_ROOT}/hammerspoon/yulan_pdf_export.lua"]])"
mkdir -p "${HOME}/.hammerspoon"
touch "${HS_INIT}"
if grep -qF "yulan_pdf_export.lua" "${HS_INIT}" 2>/dev/null; then
  echo "Hammerspoon init.lua already references yulan_pdf_export.lua — skipped append."
else
  printf '\n%s\n%s\n' "${MARKER}" "${LOADER}" >> "${HS_INIT}"
  echo "Appended loader to ${HS_INIT}"
fi
echo "Open Hammerspoon and choose Reload Config, then in Preview use ⌃⌥⌘E."
