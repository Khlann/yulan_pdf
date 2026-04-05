#!/bin/zsh
set -euo pipefail
# Copy current Preview document page as PNG to the clipboard.
# Intended for a macOS Quick Action / Automator "Run Shell Script" (appears under right-click → Quick Actions / Services).

resolve_tool() {
  local h="${HOME}"
  local c1="${h}/.local/bin/pdfpageexport"
  local here="${0:A:h:h}"
  local c2="${here}/.build/release/pdfpageexport"
  if [[ -x "${c1}" ]]; then echo "${c1}"; return 0; fi
  if [[ -x "${c2}" ]]; then echo "${c2}"; return 0; fi
  return 1
}

TOOL="$(resolve_tool)" || {
  osascript -e 'display alert "pdfpageexport not found" message "Run: zsh scripts/install-cli.sh in the yulan_pdf repo." as critical' >/dev/null 2>&1 || true
  exit 1
}

PDFPATH="$(osascript -l JavaScript <<'JXA' 2>/dev/null
function run() {
  var p = Application('Preview');
  if (p.documents.length < 1) { throw new Error('no document'); }
  return p.documents[0].path();
}
JXA
)" || true

if [[ -z "${PDFPATH}" ]]; then
  osascript -e 'display alert "Preview" message "请先在前台打开「预览」并打开已保存的 PDF。" as informational' >/dev/null 2>&1 || true
  exit 1
fi

PAGE="$(osascript <<'APPLESCRIPT' 2>/dev/null
tell application "System Events"
  set r to display dialog "Export page number (current page in Preview):" default answer "1" buttons {"Cancel", "OK"} default button "OK"
  if button returned of r is "Cancel" then error number -128
  return text returned of r
end tell
APPLESCRIPT
)" || exit 1

[[ "${PAGE}" =~ '^[0-9]+$' ]] || {
  osascript -e 'display alert "Invalid page" message "Enter a positive integer." as warning' >/dev/null 2>&1 || true
  exit 1
}

if ! "${TOOL}" --pdf "${PDFPATH}" --page "${PAGE}" --dpi 144 --clipboard; then
  osascript -e 'display alert "Export failed" message "See Terminal or logs for pdfpageexport errors." as critical' >/dev/null 2>&1 || true
  exit 1
fi

osascript -e 'display notification "Current PDF page copied to clipboard as PNG" with title "yulan_pdf"' >/dev/null 2>&1 || true
