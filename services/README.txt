页览 (Yulan) — Quick Action / Service for Preview (see repo README for full setup).

Right-click menu (macOS): Preview does not allow third-party items on the canvas menu. The supported approach is a Quick Action / Service, which appears as:

  Right-click → Quick Actions → «your action»
  or Right-click → Services → «your action»

(depending on macOS version and settings).

Setup (once):

1) Build & install the CLI:
     cd /path/to/yulan_pdf && zsh scripts/install-cli.sh

2) Open Automator → New → Quick Action (or Service on older macOS).
   - "Workflow receives" = "no input"
   - "in" = "Preview" (if available); otherwise "any application"
   - Add action: Run Shell Script
     Shell: /bin/zsh
     Pass input: to stdin (default)
     Body: 填写本仓库中脚本的**绝对路径**（推荐），例如：
       /path/to/yulan_pdf/services/copy_preview_page_to_clipboard.sh
     请保留同目录下的 parse_preview_title.py（服务脚本会调用它）。
     不要只复制 .sh 正文到 Automator，否则找不到解析器。

3) Save as e.g. "Copy Preview Page as PNG".

4) System Settings → Keyboard → Keyboard Shortcuts → Services (or Quick Actions):
   enable your new item.

5) In Preview, right-click（含在文本上右键）→ 服务 / 快速操作 → 运行你保存的动作。
   页码优先从**前台预览窗口标题**解析（与标题栏「页码：n/m」或英文 "page n of m" 一致）；
   若标题里没有可识别格式，会弹出对话框让你手动输入页码。

Notes:
- 需要 macOS 自带的 /usr/bin/python3（一般系统均有）。
- Hammerspoon (⌃⌥⌘E) 在标题不可靠时仍可用辅助功能树兜底；服务脚本不依赖 Hammerspoon。
