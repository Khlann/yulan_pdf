#!/bin/zsh
set -euo pipefail
# 生成「页览」Automator 服务并安装到 ~/Library/Services（无需手点自动操作）。
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SH_PATH="${REPO_ROOT}/services/copy_preview_page_to_clipboard.sh"
PY_PARSER="${REPO_ROOT}/services/parse_preview_title.py"

if [[ ! -f "$SH_PATH" || ! -f "$PY_PARSER" ]]; then
  echo "error: missing services/copy_preview_page_to_clipboard.sh or parse_preview_title.py" >&2
  exit 1
fi
chmod +x "$SH_PATH" 2>/dev/null || true

echo "Building pdfpageexport…"
"${REPO_ROOT}/scripts/install-cli.sh"

DEST_DIR="${HOME}/Library/Services"
WF_NAME="页览 复制预览当前页.workflow"
DEST="${DEST_DIR}/${WF_NAME}"
mkdir -p "${DEST}/Contents"

DOC_OUT="${DEST}/Contents/document.wflow"
INFO_OUT="${DEST}/Contents/Info.plist"

/usr/bin/python3 - "$SH_PATH" "$DOC_OUT" "$INFO_OUT" "$REPO_ROOT" <<'PY'
import plistlib
import sys
import uuid
from pathlib import Path

shell_script_path = Path(sys.argv[1]).resolve()
doc_out = Path(sys.argv[2])
info_out = Path(sys.argv[3])
repo_root = Path(sys.argv[4])

def uid() -> str:
    return str(uuid.uuid4()).upper()

base_path = repo_root / "services/vendor/automator_run_shell_base.wflow"
with open(base_path, "rb") as f:
    src = plistlib.load(f)

act_wrap = src["actions"][0]
inner = act_wrap["action"]
inner["UUID"] = uid()
inner["InputUUID"] = uid()
inner["OutputUUID"] = uid()

cmd = str(shell_script_path) + "\n"
inner["ActionParameters"] = {
    "COMMAND_STRING": cmd,
    "CheckedForUserDefaultShell": False,
    "inputMethod": 0,
    "shell": "/bin/zsh",
    "source": "",
}

doc = {
    "AMApplicationBuild": src["AMApplicationBuild"],
    "AMApplicationVersion": src["AMApplicationVersion"],
    "AMDocumentVersion": src["AMDocumentVersion"],
    "actions": [act_wrap],
    "connectors": {},
    "variables": [],
    "workflowMetaData": {
        "serviceApplicationBundleID": "com.apple.Preview",
        "serviceApplicationPath": "/System/Applications/Preview.app",
        "serviceInputTypeIdentifier": "com.apple.Automator.nothing",
        "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
        "serviceProcessesInput": 0,
        "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
    },
}

doc_out.write_bytes(plistlib.dumps(doc, fmt=plistlib.FMT_XML))

info = {
    "NSServices": [
        {
            "NSMenuItem": {"default": "页览：复制当前页为 PNG"},
            "NSMessage": "runWorkflowAsService",
            "NSRequiredContext": {"NSApplicationIdentifier": "com.apple.Preview"},
        }
    ]
}
info_out.write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_XML))
PY

plutil -lint "$DOC_OUT" >/dev/null
plutil -lint "$INFO_OUT" >/dev/null

# 刷新服务注册（不同系统版本行为略有差异）
if killall pbs 2>/dev/null; then
  :
fi

echo ""
echo "已安装: ${DEST}"
echo "请在「系统设置 → 键盘 → 键盘快捷键 → 服务（或快速操作）」中勾选「页览：复制当前页为 PNG」。"
echo "若右键菜单里暂时看不到，可注销重新登录一次，或用「自动操作」打开该工作流再关闭以触发注册。"
