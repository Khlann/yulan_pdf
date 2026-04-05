-- yulan_pdf: export current Preview PDF page as PNG (⌃⌥⌘E).
-- 简体中文系统下 AppleScript 无法编译「current page」等英文连续标识符（-2741），
-- 因此：路径用 JXA；页码优先从辅助功能树解析，失败则弹窗让你输入。

local OUT_DIR = os.getenv("HOME") .. "/Desktop"

local function shellQuote(s)
  return "'" .. string.gsub(s, "'", "'\\''") .. "'"
end

local function openAutomationPrivacyPane()
  hs.task
    .new("/usr/bin/open", nil, { "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation" })
    :start()
end

local function findPdfpageexport()
  local home = os.getenv("HOME") or ""
  local candidates = {
    home .. "/.local/bin/pdfpageexport",
    home .. "/Documents/code/sideproject/yulan_pdf/.build/release/pdfpageexport",
  }
  for _, p in ipairs(candidates) do
    if hs.fs.attributes(p, "mode") == "file" then
      return p
    end
  end
  return nil
end

-- 用 JavaScript for Automation 取 POSIX 路径（不受简体中文 AppleScript 方言影响）
local function previewFrontDocumentPathJXA()
  local js = [[
function run() {
  var p = Application('Preview');
  if (p.documents.length < 1) { throw new Error('no document'); }
  return p.documents[0].path();
}
]]
  return hs.osascript.javascript(js)
end

local function parsePageFromText(s)
  if type(s) ~= "string" or s == "" then
    return nil
  end
  local n =
    s:match("第%s*(%d+)%s*页")
    or s:match("Page%s+(%d+)%s+of")
    or s:match("(%d+)%s+of%s+%d+")
    or s:match("^%s*(%d+)%s*/%s*%d+%s*$")
  return n and tonumber(n) or nil
end

local function collectAxStrings(el, depth, maxDepth, budget)
  if depth > maxDepth or budget.count <= 0 then
    return
  end
  budget.count = budget.count - 1
  local fields = { "AXValue", "AXTitle", "AXDescription", "AXHelp" }
  for _, key in ipairs(fields) do
    local v = el:attributeValue(key)
    if type(v) == "string" and #v > 0 then
      local pg = parsePageFromText(v)
      if pg then
        return pg
      end
    end
  end
  local kids = el:attributeValue("AXChildren")
  if type(kids) == "table" then
    for i = 1, math.min(#kids, 80) do
      local pg = collectAxStrings(kids[i], depth + 1, maxDepth, budget)
      if pg then
        return pg
      end
    end
  end
  return nil
end

-- 从预览窗口无障碍树猜当前页（需为 Hammerspoon 打开「辅助功能」）
local function previewCurrentPageFromAX(win)
  if not win then
    return nil
  end
  local ok, axWin = pcall(function()
    return hs.axuielement.windowElement(win)
  end)
  if not ok or not axWin then
    return nil
  end
  return collectAxStrings(axWin, 0, 28, { count = 4000 })
end

local function runExportWithPathAndPage(bin, path, page)
  local pageInt = math.floor(tonumber(page) or 0)
  if pageInt < 1 then
    hs.alert.show("页码无效", 2)
    return
  end
  local base = path:match("([^/]+)%.pdf$") or "page"
  -- Lua 5.4：%d 不能接带小数的 number，secondsSinceEpoch() 为浮点
  local stamp = math.floor(hs.timer.secondsSinceEpoch())
  local dest = string.format("%s/%s-p%d-%d.png", OUT_DIR, base, pageInt, stamp)
  local cmd = string.format(
    "%s --pdf %s --page %d --dpi 144 --out %s",
    shellQuote(bin),
    shellQuote(path),
    pageInt,
    shellQuote(dest)
  )
  hs.task.new("/bin/zsh", function(_t, ok2, _)
    if ok2 then
      hs.alert.show("已保存: " .. dest, 2)
    else
      hs.alert.show("导出失败（打开 Hammerspoon 控制台查看）", 3)
    end
  end, { "-lc", cmd }):start()
end

local function exportPreviewPage()
  local bin = findPdfpageexport()
  if not bin then
    hs.alert.show("找不到 pdfpageexport。请在仓库里执行: scripts/install-cli.sh", 4)
    return
  end

  local okPath, pathOut = previewFrontDocumentPathJXA()
  if not okPath then
    hs.alert.show(
      "JXA 无法控制「预览」。请在 系统设置 → 隐私与安全性 → 自动化 里允许 Hammerspoon 控制「预览」。\n\n"
        .. tostring(pathOut),
      5
    )
    hs.timer.doAfter(1, openAutomationPrivacyPane)
    return
  end

  local path = tostring(pathOut or ""):gsub("%s+$", "")
  if path == "" then
    hs.alert.show("未取得 PDF 路径（请先保存文件）", 3)
    return
  end

  local app = hs.application.frontmostApplication()
  local win = app and app:focusedWindow()
  local page = previewCurrentPageFromAX(win)

  if not page then
    local btn, text = hs.dialog.textPrompt(
      "yulan_pdf",
      "未从界面自动识别页码（需辅助功能权限，或页码不在工具栏）。请输入当前页（数字）：",
      "1",
      "导出",
      "取消"
    )
    if btn ~= "导出" then
      return
    end
    page = tonumber((text or ""):match("%d+"))
    if not page or page < 1 then
      hs.alert.show("页码无效", 2)
      return
    end
    hs.alert.show("将导出第 " .. page .. " 页（请确认与预览一致）", 2)
  end

  runExportWithPathAndPage(bin, path, page)
end

local function requestPreviewAutomationPermission()
  local js = [[
function run() {
  var p = Application('Preview');
  return p.documents.length;
}
]]
  local ok, out = hs.osascript.javascript(js)
  if ok then
    hs.alert.show("JXA 已可访问「预览」（文档数: " .. tostring(out) .. "）。若仍失败请检查辅助功能权限。", 3)
  else
    hs.alert.show(
      "仍无法控制「预览」。请在 自动化 中为 Hammerspoon 打开「预览」。\n\n" .. tostring(out),
      5
    )
    hs.timer.doAfter(1, openAutomationPrivacyPane)
  end
end

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "R", function()
  requestPreviewAutomationPermission()
end)

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "E", function()
  local app = hs.application.frontmostApplication()
  if not app or app:bundleID() ~= "com.apple.Preview" then
    hs.alert.show("请先切换到「预览」")
    return
  end
  exportPreviewPage()
end)

hs.alert.show("yulan_pdf：⌃⌥⌘E 导出；⌃⌥⌘R 测自动化。页码来自界面或弹窗输入；建议在 辅助功能 中授权 Hammerspoon", 3.5)
