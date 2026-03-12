local html = require("ui.html")
local webviewPanel = require("ui.webview_panel")

local DebugWindow = {}

function DebugWindow.new(app, cfg, deps)
  local windowService = deps.windowService

  local DEBUG_W = 620
  local DEBUG_H = 360

  local function formatWindowDebug(index, win, includeFlags)
    local appInfo = win and win:application() or nil
    local fields = {
      string.format("id = %s", tostring(win and win:id() or nil)),
      string.format("title = %q", tostring(win and win:title() or "")),
      string.format("app = %q", tostring(appInfo and appInfo:name() or "")),
      string.format("bundleID = %q", tostring(appInfo and appInfo:bundleID() or "")),
    }
    if includeFlags and win then
      fields[#fields + 1] = string.format("visible = %s", tostring(win:isVisible()))
      fields[#fields + 1] = string.format("standard = %s", tostring(win:isStandard()))
      fields[#fields + 1] = string.format("minimized = %s", tostring(win:isMinimized()))
    end
    return string.format("[%d] { %s }", index, table.concat(fields, ", "))
  end

  local function candidateWindowsDebugText()
    local lines = {}
    local wins = windowService.candidateWindows()
    for index, win in ipairs(wins) do
      lines[#lines + 1] = formatWindowDebug(index, win, false)
    end
    if #lines == 0 then
      return "candidateWindows = []"
    end
    return "candidateWindows = [\n" .. table.concat(lines, ",\n") .. "\n]"
  end

  local function orderedWindowsDebugText()
    local lines = {}
    local wins = hs.window.orderedWindows()
    for index, win in ipairs(wins) do
      lines[#lines + 1] = formatWindowDebug(index, win, true)
    end
    if #lines == 0 then
      return "orderedWindows = []"
    end
    return "orderedWindows = [\n" .. table.concat(lines, ",\n") .. "\n]"
  end

  local function windowInfoLine(label, info)
    if not info then
      return label .. " = nil"
    end
    return string.format(
      "%s = { id = %s, title = %q, app = %q, bundleID = %q }",
      label,
      tostring(info.id),
      tostring(info.title or ""),
      tostring(info.appName or ""),
      tostring(info.bundleID or "")
    )
  end

  local function miscDebugText()
    local lines = {}
    local frontmostInfo = app:getWindowInfo(hs.window.frontmostWindow())
    local popoverState = (deps.popover and deps.popover.getDebugState) and deps.popover:getDebugState() or nil
    local ytTargetInfo = app:getYouTubeTargetId() and app:getWindowInfo(windowService.getWindowById(app:getYouTubeTargetId())) or nil

    lines[#lines + 1] = windowInfoLine("frontmostWindow", frontmostInfo)
    lines[#lines + 1] = windowInfoLine("activeWindow", popoverState and popoverState.activeWindow or nil)
    lines[#lines + 1] = windowInfoLine("callerWindow", popoverState and popoverState.callerWindow or nil)
    lines[#lines + 1] = windowInfoLine("targetWindow", ytTargetInfo)
    lines[#lines + 1] = string.format("popoverShown = %s", tostring(popoverState and popoverState.isShown or false))
    lines[#lines + 1] = string.format("ytTargetId = %s", tostring(app:getYouTubeTargetId()))

    return table.concat(lines, "\n")
  end

  local function centeredRect()
    local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
    local visibleFrame = screen:frame()
    return hs.geometry.rect(
      math.floor(visibleFrame.x + (visibleFrame.w - DEBUG_W) / 2),
      math.floor(visibleFrame.y + (visibleFrame.h - DEBUG_H) / 2),
      DEBUG_W,
      DEBUG_H
    )
  end

  local function buildHtml()
    local candidateText = html.escape(candidateWindowsDebugText())
    local orderedText = html.escape(orderedWindowsDebugText())
    local miscText = html.escape(miscDebugText())
    return "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n<style>\n"
      .. "* { box-sizing: border-box; }\n"
      .. "body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, \"SF Pro Text\", sans-serif; background: #111; color: #ddd; }\n"
      .. ".container { height: 100vh; display: flex; flex-direction: column; padding: 12px; gap: 10px; }\n"
      .. ".header { display: flex; align-items: center; justify-content: space-between; }\n"
      .. ".title { font-size: 12px; font-weight: 700; letter-spacing: 0.5px; color: #f1f1f1; }\n"
      .. ".close { border: none; border-radius: 4px; padding: 4px 10px; font-size: 11px; background: #333; color: #bdbdbd; cursor: pointer; }\n"
      .. ".close:hover { background: #444; color: #e0e0e0; }\n"
      .. ".tabs { display: flex; gap: 6px; }\n"
      .. ".tab { border: 1px solid #2f2f2f; border-radius: 6px; padding: 4px 8px; font-size: 11px; background: #1b1b1b; color: #bcbcbc; cursor: pointer; }\n"
      .. ".tab.active { background: #24406f; color: #eef4ff; border-color: #3f62a0; }\n"
      .. ".panel { flex: 1; min-height: 0; display: none; }\n"
      .. ".panel.active { display: block; }\n"
      .. ".payload { height: 100%; margin: 0; padding: 10px; border-radius: 8px; border: 1px solid #2c2c2c; background: #0b0b0b; overflow: auto; white-space: pre-wrap; font-size: 11px; line-height: 1.4; color: #8fd79c; }\n"
      .. "</style>\n</head>\n<body>\n"
      .. "<div class=\"container\">\n"
      .. "  <div class=\"header\">\n"
      .. "    <span class=\"title\">DEBUG WINDOW</span>\n"
      .. "    <button class=\"close\" onclick=\"sendAction('disableDebugWindow')\">Close</button>\n"
      .. "  </div>\n"
      .. "  <div class=\"tabs\">\n"
      .. "    <button class=\"tab active\" data-tab=\"candidateWindows\">candidateWindows</button>\n"
      .. "    <button class=\"tab\" data-tab=\"orderedWindows\">orderedWindows</button>\n"
      .. "    <button class=\"tab\" data-tab=\"misc\">misc</button>\n"
      .. "  </div>\n"
      .. "  <div class=\"panel active\" data-panel=\"candidateWindows\"><pre class=\"payload\">" .. candidateText .. "</pre></div>\n"
      .. "  <div class=\"panel\" data-panel=\"orderedWindows\"><pre class=\"payload\">" .. orderedText .. "</pre></div>\n"
      .. "  <div class=\"panel\" data-panel=\"misc\"><pre class=\"payload\">" .. miscText .. "</pre></div>\n"
      .. "</div>\n"
      .. "<script>\n"
      .. "function sendAction(action){ window.webkit.messageHandlers.tapshopDebugWindow.postMessage({ action: action }); }\n"
      .. "var tabs = document.querySelectorAll('.tab');\n"
      .. "var panels = document.querySelectorAll('.panel');\n"
      .. "function setActiveTab(name){\n"
      .. "  tabs.forEach(function(t){ t.classList.toggle('active', t.dataset.tab === name); });\n"
      .. "  panels.forEach(function(p){ p.classList.toggle('active', p.dataset.panel === name); });\n"
      .. "}\n"
      .. "tabs.forEach(function(tab){ tab.addEventListener('click', function(){ setActiveTab(tab.dataset.tab); }); });\n"
      .. "document.addEventListener('keydown', function(e){ if (e.key === 'Escape') sendAction('disableDebugWindow'); });\n"
      .. "</script>\n"
      .. "</body>\n</html>"
  end

  local panel = webviewPanel.new({
    messageHandler = "tapshopDebugWindow",
    initialRect = centeredRect,
    windowStyle = function()
      return hs.webview.windowMasks.titled
        + hs.webview.windowMasks.closable
        + hs.webview.windowMasks.miniaturizable
        + hs.webview.windowMasks.resizable
    end,
    transparent = false,
    level = hs.drawing.windowLevels.floating,
    allowTextEntry = false,
    buildHtml = buildHtml,
    handleAction = function(_, msg)
      local body = msg.body or {}
      if body.action == "disableDebugWindow" then
        app:setDebugWindow(false)
      end
    end,
    windowCallback = function(_, act)
      if act == "closing" and cfg.popoverDebugWindow then
        app:setDebugWindow(false)
      end
    end,
  })

  local instance = {}

  function instance:refreshIfShown()
    if panel:isShown() then
      panel:refresh()
      return
    end
    panel:markDirty()
  end

  function instance:syncVisibility()
    panel:syncVisibility(cfg.popoverDebugWindow)
  end

  return instance
end

return DebugWindow
