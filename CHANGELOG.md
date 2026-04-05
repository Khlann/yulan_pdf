# Changelog

## [Unreleased]

- **Services**：`install-preview-service.zsh` 安装 `YulanCopyPreviewPage.workflow`：`AMAccepts`/`AMProvides` 为 `*`（避免预览 PDF 选区非纯文本导致「服务输入出现问题」），`NSSendTypes` 含 RTF；stdin 经 `cat` 丢弃后 `exec` 导出脚本；预览内需先划选文字再出服务菜单。
- **Services**：`copy_preview_page_to_clipboard.sh` 通过 JXA 读取窗口标题，与 `parse_preview_title.py` 自动解析页码（与 Hammerspoon 规则一致）；无法解析时再弹窗输入。

## [0.1.0] — 2026-04-05

首次发版。

- **pdfpageexport**：Swift PDFKit CLI，单页栅格化为 PNG/JPEG，支持 `--clipboard`。
- **Hammerspoon**：`⌃⌥⌘E` 在「预览」前台时复制当前页；JXA 取文档路径；页码优先从窗口标题 / 辅助功能解析（含简体中文标题 `页码：n/m`）；`⌃⌥⌘R` 探测自动化权限。
- **Services**：`services/copy_preview_page_to_clipboard.sh` + Automator 快速操作说明（需手动输入页码）。
- **辅助**：`preview_ax_dump` 用于本机 AX 树排查。
