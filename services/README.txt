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
     Body: paste the full path to:
       .../yulan_pdf/services/copy_preview_page_to_clipboard.sh
     Or paste the script contents.

3) Save as e.g. "Copy Preview Page as PNG".

4) System Settings → Keyboard → Keyboard Shortcuts → Services (or Quick Actions):
   enable your new item.

5) In Preview, right-click the document area → Quick Actions / Services → run it.
   You will be prompted for the page number (Preview does not expose current page to Services).

Notes:
- Hammerspoon (⌃⌥⌘E) can still auto-detect page via Accessibility when configured; this shell path is menu-oriented and asks for the page.
