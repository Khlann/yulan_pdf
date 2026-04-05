页览 (Yulan) — Quick Action / Service for Preview (see repo README for full setup).

Right-click menu (macOS): Preview does not allow third-party items on the canvas menu. The supported approach is a Quick Action / Service, which appears as:

  Right-click → Quick Actions → «your action»
  or Right-click → Services → «your action»

(depending on macOS version and settings).

Setup (once):

A) 自动安装（推荐，无需手点「自动操作」）：

     cd /path/to/yulan_pdf && zsh scripts/install-preview-service.zsh

   会：编译安装 pdfpageexport，并把服务装到
   ~/Library/Services/YulanCopyPreviewPage.workflow
   然后到「系统设置 → 键盘 → 键盘快捷键 → 服务（或快速操作）」里勾选「页览：复制当前页为 PNG」。
   若列表里没有，再到「系统设置 → 隐私与安全性 → 扩展 → 快速操作」查看。

   说明：为让系统注册该服务，工作流按「文本」类声明（与 Finder 自带服务同理）。
   在预览中请先划选少量文字，再右键 → 服务；导出内容仍是整页 PNG，与选中文字无关。

B) 手动用「自动操作」装配时：

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
