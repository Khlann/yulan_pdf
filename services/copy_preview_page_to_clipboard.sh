#!/bin/zsh
set -euo pipefail
# Copy current Preview document page as PNG to the clipboard.
# Intended for a macOS Quick Action / Automator "Run Shell Script" (appears under right-click → Quick Actions / Services).

resolve_tool() {
  if [[ -n "${YULAN_PDFPAGEEXPORT:-}" && -x "${YULAN_PDFPAGEEXPORT}" ]]; then
    echo "${YULAN_PDFPAGEEXPORT}"
    return 0
  fi
  local h="${HOME}"
  local c1="${h}/.local/bin/pdfpageexport"
  # 脚本在仓库 services/ 时，.. 为仓库根；在 workflow/Contents/Resources/ 时此路径不存在
  local repo_root="${0:A:h:h}"
  local c2="${repo_root}/.build/release/pdfpageexport"
  if [[ -x "${c1}" ]]; then echo "${c1}"; return 0; fi
  if [[ -x "${c2}" ]]; then echo "${c2}"; return 0; fi
  return 1
}

TOOL="$(resolve_tool)" || {
  osascript -e 'display alert "pdfpageexport not found" message "Run: zsh scripts/install-cli.sh in the 页览 (yulan_pdf) repo." as critical' >/dev/null 2>&1 || true
  exit 1
}

SERVICE_DIR="${0:A:h}"
PYTHON3="/usr/bin/python3"
[[ -x "${PYTHON3}" ]] || PYTHON3="python3"
PARSER="${SERVICE_DIR}/parse_preview_title.py"

JSON="$(osascript -l JavaScript <<'JXA' 2>/dev/null
function run() {
  var p = Application('Preview');
  if (p.windows.length < 1) { throw new Error('no window'); }
  var w = p.windows[0];
  var d = w.document();
  if (!d) { throw new Error('no document'); }
  var path = d.path();
  if (!path) { throw new Error('unsaved'); }
  var title = '';
  try { title = w.name(); } catch (e) {}
  return JSON.stringify({ path: path, title: title });
}
JXA
)" || true

if [[ -z "${JSON}" ]]; then
  osascript -e 'display alert "Preview" message "请先在前台打开「预览」并打开已保存的 PDF。" as informational' >/dev/null 2>&1 || true
  exit 1
fi

if [[ ! -f "${PARSER}" ]]; then
  osascript -e 'display alert "页览" message "缺少同目录下的 parse_preview_title.py，请从仓库完整复制 services/ 文件夹。" as critical' >/dev/null 2>&1 || true
  exit 1
fi

lines=("${(@f)$(print -r -- "${JSON}" | "${PYTHON3}" "${PARSER}")}") || true
PDFPATH="${lines[1]:-}"
PAGE="${lines[2]:-}"

if [[ -z "${PDFPATH}" ]]; then
  osascript -e 'display alert "Preview" message "未能取得 PDF 路径。" as informational' >/dev/null 2>&1 || true
  exit 1
fi

if [[ -z "${PAGE}" ]]; then
  PAGE="$(osascript <<'APPLESCRIPT' 2>/dev/null
tell application "System Events"
  set r to display dialog "未能从窗口标题识别页码（例如无「页码：n/m」）。请输入当前页：" default answer "1" buttons {"取消", "好"} default button "好"
  if button returned of r is "取消" then error number -128
  return text returned of r
end tell
APPLESCRIPT
)" || exit 1
fi

[[ "${PAGE}" =~ '^[0-9]+$' ]] || {
  osascript -e 'display alert "页码无效" message "请输入正整数。" as warning' >/dev/null 2>&1 || true
  exit 1
}

if ! "${TOOL}" --pdf "${PDFPATH}" --page "${PAGE}" --dpi 144 --clipboard; then
  osascript -e 'display alert "Export failed" message "See Terminal or logs for pdfpageexport errors." as critical' >/dev/null 2>&1 || true
  exit 1
fi

osascript -e 'display notification "Current PDF page copied to clipboard as PNG" with title "页览 Yulan"' >/dev/null 2>&1 || true
