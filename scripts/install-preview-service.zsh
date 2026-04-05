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
# ASCII 包名，避免部分系统组件对中文路径注册异常；菜单标题仍由 Info.plist 决定为中文
WF_NAME="YulanCopyPreviewPage.workflow"
DEST="${DEST_DIR}/${WF_NAME}"
rm -rf "${DEST}" "${DEST_DIR}/页览 复制预览当前页.workflow"
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
        "serviceInputTypeIdentifier": "com.apple.Automator.text",
        "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
        "serviceProcessesInput": 0,
        "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
    },
}

doc_out.write_bytes(plistlib.dumps(doc, fmt=plistlib.FMT_XML))

info = {
    "CFBundleDevelopmentRegion": "zh_CN",
    "CFBundleIdentifier": "io.github.khlann.yulan.copyPreviewPage",
    "CFBundleName": "YulanCopyPreviewPage",
    "CFBundlePackageType": "BNDL",
    "CFBundleShortVersionString": "1.0",
    "NSServices": [
        {
            "NSMenuItem": {"default": "页览：复制当前页为 PNG"},
            "NSMessage": "runWorkflowAsService",
            "NSRequiredContext": {"NSApplicationIdentifier": "com.apple.Preview"},
            "NSSendTypes": [
                "public.utf8-plain-text",
                "public.plain-text",
                "NSStringPboardType",
                "NSPDFPboardType",
            ],
        }
    ],
}
info_out.write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_XML))
PY

plutil -lint "$DOC_OUT" >/dev/null
plutil -lint "$INFO_OUT" >/dev/null

# 刷新 Pasteboard 服务注册
killall pbs 2>/dev/null || true
launchctl kickstart -k "gui/$(id -u)/com.apple.pbs" 2>/dev/null || true

echo ""
echo "已安装: ${DEST}"
echo ""
echo "请到以下位置勾选启用（不同 macOS 版本入口不同，都找一下）："
echo "  • 系统设置 → 键盘 → 键盘快捷键 → 服务"
echo "  • 系统设置 → 键盘 → 键盘快捷键 → 快速操作"
echo "  • 系统设置 → 隐私与安全性 → 扩展 → 快速操作（部分版本）"
echo ""
echo "在「预览」里：本服务按「文本类」注册，请先划选少量文字再右键 → 服务 →「页览：复制当前页为 PNG」。"
echo "（脚本仍按前台预览窗口导出整页，与选中文字内容无关。）"
echo ""
echo "若仍没有：完全退出并重新打开「预览」，或注销一次。"
