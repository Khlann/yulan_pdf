# 页览（Yulan）

在 macOS **预览（Preview）** 里，把 **当前 PDF 页** 导出为 **PNG** 并写入**剪贴板**（也可落盘）。面向简体中文环境做了标题栏页码解析，并避开简体 AppleScript 对英文术语的编译限制。

**English:** Copy the **current Preview PDF page** to the clipboard as PNG, with a small Swift CLI and an optional Hammerspoon hotkey.

## 需要什么

- macOS **13** 及以上（与 `Package.swift` 一致）
- **Xcode** 或 Command Line Tools（用于 `swift build`）
- 使用 Hammerspoon 快捷键时：**[Hammerspoon](https://www.hammerspoon.org/)**，并在 **隐私与安全性 → 辅助功能 / 自动化** 中授权

## 快速开始

在已克隆的仓库根目录执行：

```bash
zsh scripts/install-cli.sh
```

会在 `~/.local/bin/pdfpageexport` 安装 CLI。

### Hammerspoon（推荐）

```bash
zsh scripts/setup-hammerspoon.zsh
```

在 Hammerspoon 里 **Reload Config**。在 **预览** 前台按 **`⌃⌥⌘E`** 复制当前页；**`⌃⌥⌘R`** 用于检查能否通过 JXA 访问预览。

若 `pdfpageexport` 不在默认路径，可在启动环境中设置：

`YULAN_PDFPAGEEXPORT` → 指向可执行的 `pdfpageexport` 绝对路径。

### CLI 示例

```bash
pdfpageexport --pdf ./doc.pdf --page 7 --dpi 144 --out page7.png
pdfpageexport --pdf ./doc.pdf --page 7 --dpi 144 --clipboard
```

JPEG：输出 `.jpg` 并可选 `--jpeg-quality 0.85`。

### 右键 / 服务

预览没有在画布上挂第三方菜单的官方接口；可用 **Automator 快速操作**，在 **服务** 子菜单中出现。服务会通过 JXA 读前台窗口标题并**尽量自动识别当前页**（与标题栏「页码：n/m」一致），失败时再弹窗询问。

**一键安装服务**（会编译 CLI 并写入 `~/Library/Services/`）：

```bash
zsh scripts/install-preview-service.zsh
```

装好后在 **系统设置 → 键盘 → 键盘快捷键 → 服务（或快速操作）** 中勾选 **「页览：复制当前页为 PNG」**；若没有，再到 **系统设置 → 隐私与安全性 → 扩展 → 快速操作** 查看。  
在预览里需 **先划选少量文字** 再右键 → 服务（系统按「文本类」注册才可见；导出的仍是整页）。手动装配步骤见 [`services/README.txt`](services/README.txt)。

## 仓库与版本

- **产品名**：页览 · **英文名**：Yulan  
- **SPM 包名 / 目录**：`yulan_pdf`（历史原因保持不变）  
- **变更记录**：[CHANGELOG.md](CHANGELOG.md)  
- **许可**：[LICENSE](LICENSE)（MIT）

发版时建议：

```bash
git tag -a v0.1.0 -m "页览 0.1.0"
git push origin v0.1.0
```

（若远程名不是 `origin`，请替换。）

## 更多说明

本机验证与排错笔记见 [`VALIDATION.txt`](VALIDATION.txt)。
