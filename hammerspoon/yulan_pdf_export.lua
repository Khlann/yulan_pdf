-- yulan_pdf: copy current Preview PDF page as PNG to clipboard (⌃⌥⌘E).
-- 简体中文系统下 AppleScript 无法编译「current page」等英文连续标识符（-2741），
-- 因此：路径用 JXA；页码优先从辅助功能树解析，失败则弹窗让你输入。

-- 右键菜单请用 Automator Quick Action：services/copy_preview_page_to_clipboard.sh（见 services/README.txt）

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
  if (p.windows.length < 1) { throw new Error('no window'); }
  var d = p.windows[0].document();
  if (!d) { throw new Error('no document'); }
  return d.path();
}
]]
  return hs.osascript.javascript(js)
end

-- 解析页码；labeled=true 表示「页码：n/m」类（预览标题栏左侧常拆成多个 AX 子结点，需拼接）
local function parsePageNumberFromAXString(s)
  if type(s) ~= "string" or s == "" then
    return nil, false
  end
  local n =
    s:match("页码%s*[:：]%s*(%d+)%s*[/／]%s*%d+")
    or s:match("[页頁]%s*[码碼]%s*[:：]%s*(%d+)%s*[/／]%s*%d+")
    or s:match("页码%s*(%d+)%s*[/／]%s*%d+")
  if n then
    return tonumber(n), true
  end
  local t = s:match("^%s*(.-)%s*$")
  if not t or t == "" then
    return nil, false
  end
  n =
    t:match("^%s*(%d+)%s*[/／]%s*%d+%s*$")
    or t:match("^%s*(%d+)%s*-%s*%d+%s*$")
    or t:match("^%s*(%d+)%s*–%s*%d+%s*$")
    or t:match("^%s*(%d+)%s*—%s*%d+%s*$")
    or t:lower():match("^%s*page%s+(%d+)%s+of%s+%d+%s*$")
    or t:match("^%s*(%d+)%s+of%s+%d+%s*$")
  if n then
    return tonumber(n), false
  end
  return nil, false
end

-- 从标题栏文案解析页码（与你在控制台用的 prev + window + ax 同源信息）
local function extractPageFromTitleLikeString(t)
  if type(t) ~= "string" or t == "" then
    return nil
  end
  local tl = t:lower()
  local n =
    t:match("页码%s*[:：]%s*(%d+)%s*[/／]%s*%d+")
    or t:match("[页頁]%s*[码碼]%s*[:：]%s*(%d+)%s*[/／]%s*%d+")
    or t:match("页码%s*(%d+)%s*[/／]%s*%d+")
    or tl:match("page%s+(%d+)%s+of%s+%d+")
    or tl:match("[–—%-]%s*page%s+(%d+)%s+of%s+%d+")
  return n and tonumber(n) or nil
end

-- 从标题栏解析页码：优先 AXTitle（常含「页码：n/m」），再 hs.window:title()（快捷键后有时被截断）
local function previewPageFromWindowTitle(win)
  if not win then
    return nil
  end
  local strings = {}
  local ok, axw = pcall(function()
    return hs.axuielement.windowElement(win)
  end)
  if ok and axw then
    for _, key in ipairs({ "AXTitle", "AXDocument" }) do
      local v = axw:attributeValue(key)
      if type(v) == "string" and #v > 0 then
        strings[#strings + 1] = v
      end
    end
    local a = axw:attributeValue("AXTitle")
    local b = axw:attributeValue("AXDocument")
    if type(a) == "string" or type(b) == "string" then
      strings[#strings + 1] = table.concat({ a or "", b or "" }, " ")
    end
  end
  local wt = win:title()
  if type(wt) == "string" and #wt > 0 then
    strings[#strings + 1] = wt
  end
  local seen = {}
  for _, s in ipairs(strings) do
    if not seen[s] then
      seen[s] = true
      local n = extractPageFromTitleLikeString(s)
      if n then
        return n
      end
    end
  end
  return nil
end

-- 始终用「预览」进程的窗口做 AX（不要用全局 focusedWindow：在 Hammerspoon 控制台里焦点是控制台）
local function previewAppWindowForAX()
  local prev = hs.application.get("com.apple.Preview")
  if not prev then
    return nil
  end
  return prev:focusedWindow() or prev:mainWindow() or (prev:allWindows() or {})[1]
end

local function axChildrenArray(el)
  local kids = el:attributeValue("AXChildren")
  if type(kids) ~= "table" then
    return {}
  end
  local out = {}
  for i = 1, #kids do
    out[#out + 1] = kids[i]
  end
  return out
end

local function axFirstStringField(el)
  if not el then
    return nil
  end
  for _, key in ipairs({ "AXValue", "AXTitle", "AXDescription" }) do
    local v = el:attributeValue(key)
    if type(v) == "string" and #v > 0 then
      return v
    end
  end
  return nil
end

-- 把子树里可见字符串按遍历顺序拼起来（用于「页码」「：」「25/111」分散在多个 AXStaticText 的情况）
local function axConcatDescendantStrings(el, maxDepth, budget)
  if budget.count <= 0 then
    return ""
  end
  budget.count = budget.count - 1
  local chunks = {}
  local s = axFirstStringField(el)
  if s then
    chunks[#chunks + 1] = s
  end
  if maxDepth <= 0 then
    return table.concat(chunks, "")
  end
  local kids = axChildrenArray(el)
  for i = 1, math.min(#kids, 40) do
    local sub = axConcatDescendantStrings(kids[i], maxDepth - 1, budget)
    if #sub > 0 then
      chunks[#chunks + 1] = sub
    end
  end
  return table.concat(chunks, "")
end

local function axElementFrameLeft(el)
  local f = el:attributeValue("AXFrame")
  if type(f) == "table" then
    return f.x or f.x1 or 0
  end
  return 0
end

local function axElementFrameArea(el)
  local f = el:attributeValue("AXFrame")
  if type(f) == "table" then
    local w = f.w or f.width or 0
    local h = f.h or f.height or 0
    return math.abs(w * h)
  end
  return math.huge
end

local function gatherPageIndicatorCandidates(el, depth, maxDepth, budget, out)
  if depth > maxDepth or budget.count <= 0 then
    return
  end
  budget.count = budget.count - 1
  local fields = { "AXValue", "AXTitle", "AXDescription", "AXHelp" }
  for _, key in ipairs(fields) do
    local v = el:attributeValue(key)
    if type(v) == "string" and #v > 0 then
      local pg, labeled = parsePageNumberFromAXString(v)
      if pg then
        out[#out + 1] = {
          page = pg,
          x = axElementFrameLeft(el),
          area = axElementFrameArea(el),
          labeled = labeled,
        }
      end
    end
  end
  local kids = axChildrenArray(el)
  if #kids >= 1 and #kids <= 40 and depth <= 18 and budget.count > 80 then
    local glueBudget = { count = 120 }
    local glued = axConcatDescendantStrings(el, 4, glueBudget)
    if
      #glued >= 3
      and (
        glued:find("页码", 1, true)
        or glued:find("頁碼", 1, true)
        or (glued:find("页", 1, true) and glued:find("码", 1, true))
      )
    then
      local pg, labeled = parsePageNumberFromAXString(glued)
      if pg and labeled then
        out[#out + 1] = {
          page = pg,
          x = axElementFrameLeft(el),
          area = axElementFrameArea(el),
          labeled = true,
        }
      end
    end
  end
  for i = 1, math.min(#kids, 80) do
    gatherPageIndicatorCandidates(kids[i], depth + 1, maxDepth, budget, out)
  end
end

-- 从预览窗口无障碍树猜当前页（仅保留带「页码」语义的命中，忽略幻灯片里的「2 / 73」页脚）
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
  local cands = {}
  gatherPageIndicatorCandidates(axWin, 0, 30, { count = 9000 }, cands)
  local filtered = {}
  for _, c in ipairs(cands) do
    if c.labeled then
      filtered[#filtered + 1] = c
    end
  end
  if #filtered == 0 then
    return nil
  end
  cands = filtered
  table.sort(cands, function(a, b)
    if a.labeled ~= b.labeled then
      return a.labeled
    end
    if a.labeled and b.labeled then
      if a.x ~= b.x then
        return a.x < b.x
      end
      return a.area < b.area
    end
    if a.x ~= b.x then
      return a.x > b.x
    end
    return a.area < b.area
  end)
  return cands[1].page
end

local function runCopyPageToClipboard(bin, path, page)
  local pageInt = math.floor(tonumber(page) or 0)
  if pageInt < 1 then
    hs.alert.show("页码无效", 2)
    return
  end
  local cmd = string.format(
    "%s --pdf %s --page %d --dpi 144 --clipboard",
    shellQuote(bin),
    shellQuote(path),
    pageInt
  )
  hs.task.new("/bin/zsh", function(_t, ok2, _)
    if ok2 then
      hs.alert.show("已复制当前页 PNG 到剪贴板", 2)
    else
      hs.alert.show("复制失败（打开 Hammerspoon 控制台查看）", 3)
    end
  end, { "-lc", cmd }):start()
end

local function exportPreviewPage()
  local bin = findPdfpageexport()
  if not bin then
    hs.alert.show("找不到 pdfpageexport。请在仓库里执行: scripts/install-cli.sh", 4)
    return
  end

  -- 先取窗口与页码，再跑 JXA：避免 Apple 事件先执行后标题栏/焦点变化，导致 title 与控制台不一致
  local win = previewAppWindowForAX()
  local page = previewPageFromWindowTitle(win) or previewCurrentPageFromAX(win)

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

  if not page then
    local btn, text = hs.dialog.textPrompt(
      "yulan_pdf",
      "未从界面自动识别页码（需辅助功能权限，或页码不在工具栏）。请输入当前页（数字）：",
      "1",
      "复制",
      "取消"
    )
    if btn ~= "复制" then
      return
    end
    page = tonumber((text or ""):match("%d+"))
    if not page or page < 1 then
      hs.alert.show("页码无效", 2)
      return
    end
    hs.alert.show("将复制第 " .. page .. " 页（请确认与预览一致）", 2)
  end

  runCopyPageToClipboard(bin, path, page)
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
    hs.alert.show("JXA 已可访问「预览」（文档数: " .. tostring(out) .. "）。若仍失败请检查自动化/辅助功能权限。", 3)
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

hs.alert.show("yulan_pdf：⌃⌥⌘E 复制当前页 PNG 到剪贴板；⌃⌥⌘R 测自动化。右键菜单见 services/README.txt", 3.5)
