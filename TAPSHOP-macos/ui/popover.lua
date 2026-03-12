local configModule = require("config")
local html = require("ui.html")
local webviewPanel = require("ui.webview_panel")

local Popover = {}

function Popover.new(app, cfg, deps)
  local windowService = deps.windowService
  local settingsStore = deps.settingsStore

  local escTap = nil
  local callerWin = nil
  local activeWin = nil
  local isDragging = false
  local isResizing = false
  local savedTopLeft = settingsStore.getPoint(configModule.keys.popoverTopLeft)
  local savedSize = settingsStore.getSize(configModule.keys.popoverSize)

  local POP_W = 500
  local POP_H = 424
  local POP_MIN_W = 320
  local POP_MIN_H = 280

  local POPOVER_CSS = [=[
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

:root {
  --ui-scale: 1;
}

html, body {
  width: 100%;
  height: 100%;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
  background: transparent;
  color: #e0e0e0;
  font-size: calc(13px * var(--ui-scale));
  -webkit-user-select: none;
  overflow: hidden;
}

.container {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: calc(8px * var(--ui-scale));
  height: 100%;
  padding: calc(12px * var(--ui-scale));
  background: __POPOVER_BG__;
  -webkit-backdrop-filter: blur(10px) saturate(115%);
  backdrop-filter: blur(10px) saturate(115%);
  border: 1px solid rgba(255, 255, 255, 0.06);
  border-radius: 12px;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.04);
  overflow: hidden;
}

.header {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  align-items: flex-start;
  gap: calc(12px * var(--ui-scale));
  padding-bottom: calc(10px * var(--ui-scale));
  border-bottom: 1px solid #333;
  cursor: move;
}

.header .title-wrap {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  flex: 1 1 180px;
  gap: calc(6px * var(--ui-scale));
  min-width: 0;
}

.header .title {
  display: block;
  font-weight: 700;
  font-size: calc(14px * var(--ui-scale));
  color: #fff;
  letter-spacing: 0.5px;
}

.header .header-details {
  flex: 1 1 220px;
  min-width: 0;
  max-width: 100%;
  margin-left: auto;
  text-align: right;
}

.header .subtitle-line {
  display: block;
  max-width: 100%;
  overflow-wrap: anywhere;
  white-space: normal;
  line-height: 1.35;
  font-size: calc(11px * var(--ui-scale));
  color: #9aa0a6;
}

.workspace-list {
  flex: 1 1 auto;
  min-height: 0;
  display: grid;
  grid-template-rows: repeat(9, minmax(0, 1fr));
  gap: calc(3px * var(--ui-scale));
  overflow: hidden;
}

.row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: calc(8px * var(--ui-scale));
  min-height: 0;
  padding: calc(3px * var(--ui-scale)) 0;
}

.slot-num {
  width: calc(18px * var(--ui-scale));
  text-align: right;
  color: #fff;
  font-size: calc(11px * var(--ui-scale));
  font-weight: 600;
  margin-right: calc(8px * var(--ui-scale));
  flex-shrink: 0;
}

.slot-label {
  flex: 1 1 170px;
  min-width: 140px;
  overflow: hidden;
  font-size: calc(12px * var(--ui-scale));
}

.slot-text-bg {
  display: inline-block;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  padding: calc(2px * var(--ui-scale)) calc(8px * var(--ui-scale));
  background: rgba(0, 0, 0, 0.14);
  -webkit-backdrop-filter: blur(1.5px);
  backdrop-filter: blur(1.5px);
  border-radius: 999px;
}

.paired {
  color: #7ec87e;
}

.paired-minimized {
  color: #e7c84f;
}

.unpaired {
  color: #555;
  font-style: italic;
}

.slot-buttons {
  display: flex;
  gap: calc(4px * var(--ui-scale));
  flex-shrink: 0;
  flex-wrap: wrap;
  margin-left: auto;
}

.btn {
  border: none;
  border-radius: calc(4px * var(--ui-scale));
  padding: calc(4px * var(--ui-scale)) calc(11px * var(--ui-scale));
  font-size: calc(11px * var(--ui-scale));
  font-weight: 500;
  cursor: pointer;
  transition: opacity 0.12s;
}

.btn:active {
  opacity: 0.6;
}

.btn-primary {
  background: #2d6ee6;
  color: #fff;
  opacity: 0.9;
}

.btn-primary:hover {
  background: #4080f0;
  opacity: 1;
}

.btn-unpair {
  background: #444;
  color: #bbb;
}

.btn-unpair:hover {
  background: #555;
}

.btn-unpair.off {
  opacity: 0.25;
  pointer-events: none;
}

.footer {
  display: flex;
  flex-wrap: wrap;
  gap: calc(6px * var(--ui-scale));
  padding-top: calc(10px * var(--ui-scale));
  border-top: 1px solid #333;
}

.footer-btn {
  border: none;
  border-radius: calc(4px * var(--ui-scale));
  padding: calc(5px * var(--ui-scale)) calc(12px * var(--ui-scale));
  font-size: calc(11px * var(--ui-scale));
  font-weight: 600;
  cursor: pointer;
  transition: opacity 0.12s;
}

.footer-btn:active {
  opacity: 0.6;
}

.footer-danger {
  background: #a03020;
  color: #fff;
  opacity: 0.9;
}

.footer-danger:hover {
  background: #c04030;
  opacity: 1;
}

.footer-close {
  background: #2a2a2a;
  color: #777;
  margin-left: auto;
}

.footer-close:hover {
  background: #3a3a3a;
  color: #aaa;
}

.config-menu {
  position: relative;
}

.config-menu summary {
  list-style: none;
}

.config-menu summary::-webkit-details-marker {
  display: none;
}

.config-panel {
  position: absolute;
  top: 100%;
  left: 0;
  margin-top: calc(6px * var(--ui-scale));
  min-width: 245px;
  max-width: min(280px, calc(100vw - 24px));
  border: 1px solid #3c3c3c;
  border-radius: calc(6px * var(--ui-scale));
  background: #171717;
  box-shadow: 0 12px 24px rgba(0, 0, 0, 0.45);
  padding: calc(8px * var(--ui-scale)) calc(10px * var(--ui-scale));
  z-index: 5;
}

.config-item {
  display: flex;
  align-items: center;
  gap: calc(7px * var(--ui-scale));
  font-size: calc(11px * var(--ui-scale));
  color: #c6c6c6;
  cursor: pointer;
}

.config-item input {
  accent-color: #2d6ee6;
}

.config-slider-wrap {
  display: flex;
  flex-direction: column;
  gap: calc(4px * var(--ui-scale));
  margin-top: calc(8px * var(--ui-scale));
}

.config-slider-row {
  display: flex;
  align-items: center;
  gap: calc(6px * var(--ui-scale));
  font-size: calc(11px * var(--ui-scale));
  color: #c6c6c6;
}

.config-slider {
  width: 100%;
}

.config-trigger {
  border: none;
  border-radius: calc(4px * var(--ui-scale));
  padding: calc(5px * var(--ui-scale)) calc(10px * var(--ui-scale));
  font-size: calc(11px * var(--ui-scale));
  font-weight: 600;
  background: #2a2a2a;
  color: #999;
  cursor: pointer;
}

.config-trigger:hover {
  background: #3a3a3a;
  color: #c0c0c0;
}

@media (max-width: 420px) {
  .header .header-details {
    margin-left: 0;
    text-align: left;
  }

  .slot-buttons {
    width: 100%;
    margin-left: calc(26px * var(--ui-scale));
  }
}

]=]

  local POPOVER_FOOTER = [=[
  </div>
  <div class="footer">
    <button class="footer-btn footer-danger" onclick="sendAction('unpairAll')">
      Unpair ALL
    </button>
    <button class="footer-btn footer-close" onclick="sendAction('close')">
      Close
    </button>
  </div>
</div>
<script>
  function sendAction(action, slot, dx, dy, dw, dh, direction) {
    window.webkit.messageHandlers.tapshop.postMessage({
      action: action,
      slot: slot || 0,
      dx: dx || 0,
      dy: dy || 0,
      dw: dw || 0,
      dh: dh || 0,
      direction: direction || "",
    });
  }

  var BASE_WIDTH = 500;
  var BASE_HEIGHT = 424;
  var RESIZE_ZONE = 10;

  function updateUiScale() {
    var widthScale = window.innerWidth / BASE_WIDTH;
    var heightScale = window.innerHeight / BASE_HEIGHT;
    var scale = Math.min(1, widthScale, heightScale);
    scale = Math.max(0.6, scale);
    document.documentElement.style.setProperty("--ui-scale", scale.toFixed(3));
  }

  function getResizeDirection(e) {
    var nearLeft = e.clientX <= RESIZE_ZONE;
    var nearRight = e.clientX >= window.innerWidth - RESIZE_ZONE;
    var nearTop = e.clientY <= RESIZE_ZONE;
    var nearBottom = e.clientY >= window.innerHeight - RESIZE_ZONE;

    if (nearTop && nearLeft) return "nw";
    if (nearTop && nearRight) return "ne";
    if (nearBottom && nearLeft) return "sw";
    if (nearBottom && nearRight) return "se";
    if (nearLeft) return "w";
    if (nearRight) return "e";
    if (nearTop) return "n";
    if (nearBottom) return "s";
    return "";
  }

  function cursorForDirection(direction) {
    if (direction === "n" || direction === "s") return "ns-resize";
    if (direction === "e" || direction === "w") return "ew-resize";
    if (direction === "ne" || direction === "sw") return "nesw-resize";
    if (direction === "nw" || direction === "se") return "nwse-resize";
    return "";
  }

  function setGlobalCursor(cursor) {
    document.documentElement.style.cursor = cursor || "";
    document.body.style.cursor = cursor || "";
  }

  var dragState = {
    active: false,
    lastX: 0,
    lastY: 0,
  };

  var resizeState = {
    active: false,
    lastX: 0,
    lastY: 0,
    direction: "",
  };

  document.addEventListener("mousedown", function (e) {
    if (e.button !== 0) return;
    var direction = getResizeDirection(e);
    if (!direction) return;
    resizeState.active = true;
    resizeState.direction = direction;
    resizeState.lastX = e.screenX;
    resizeState.lastY = e.screenY;
    setGlobalCursor(cursorForDirection(direction));
    sendAction("resizeStart", 0, 0, 0, 0, 0, direction);
    e.preventDefault();
    e.stopPropagation();
  }, true);

  var header = document.querySelector(".header");
  if (header) {
    header.addEventListener("mousedown", function (e) {
      if (e.button !== 0) return;
      if (e.target && e.target.closest && e.target.closest(".config-menu")) return;
      dragState.active = true;
      dragState.lastX = e.screenX;
      dragState.lastY = e.screenY;
      sendAction("dragStart");
      e.preventDefault();
    });
  }

  window.addEventListener("mousemove", function (e) {
    if (!dragState.active) return;

    var dx = e.screenX - dragState.lastX;
    var dy = e.screenY - dragState.lastY;
    dragState.lastX = e.screenX;
    dragState.lastY = e.screenY;

    if (dx !== 0 || dy !== 0) {
      sendAction("dragMove", 0, dx, dy);
    }
  });

  window.addEventListener("mouseup", function () {
    if (!dragState.active) return;
    dragState.active = false;
    sendAction("dragEnd");
  });

  window.addEventListener("mousemove", function (e) {
    if (!resizeState.active) return;

    var dw = e.screenX - resizeState.lastX;
    var dh = e.screenY - resizeState.lastY;
    resizeState.lastX = e.screenX;
    resizeState.lastY = e.screenY;

    if (dw !== 0 || dh !== 0) {
      sendAction("resizeMove", 0, 0, 0, dw, dh, resizeState.direction);
    }
  });

  window.addEventListener("mouseup", function () {
    if (!resizeState.active) return;
    resizeState.active = false;
    resizeState.direction = "";
    setGlobalCursor("");
    sendAction("resizeEnd");
  });

  document.addEventListener("mousemove", function (e) {
    if (dragState.active || resizeState.active) return;
    setGlobalCursor(cursorForDirection(getResizeDirection(e)));
  });

  document.addEventListener("mouseleave", function () {
    if (dragState.active || resizeState.active) return;
    setGlobalCursor("");
  });

  window.addEventListener("resize", updateUiScale);
  updateUiScale();

  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape") sendAction("close");
  });

  var configMenu = document.querySelector(".config-menu");
  document.addEventListener("mousedown", function (e) {
    if (!configMenu || !configMenu.hasAttribute("open")) return;
    if (e.target && e.target.closest && e.target.closest(".config-menu")) return;
    configMenu.removeAttribute("open");
  });
</script>
</body>
</html>]=]

  local function currentPopoverSize()
    return {
      w = math.max(POP_MIN_W, savedSize and savedSize.w or POP_W),
      h = math.max(POP_MIN_H, savedSize and savedSize.h or POP_H),
    }
  end

  local function centeredRect(screen)
    local size = currentPopoverSize()
    local visibleFrame = screen:frame()
    return hs.geometry.rect(
      math.floor(visibleFrame.x + (visibleFrame.w - size.w) / 2),
      math.floor(visibleFrame.y + (visibleFrame.h - size.h) / 2),
      size.w,
      size.h
    )
  end

  local function currentPopoverLevel()
    if cfg.popoverAlwaysOnTop then
      return hs.drawing.windowLevels.popUpMenu
    end
    return hs.drawing.windowLevels.normal
  end

  local function saveTopLeftFromFrame(panel)
    local frame = panel:getWebview():frame()
    savedTopLeft = {
      x = math.floor(frame.x),
      y = math.floor(frame.y),
    }
    settingsStore.setPoint(configModule.keys.popoverTopLeft, savedTopLeft)
  end

  local function saveSizeFromFrame(panel)
    local frame = panel:getWebview():frame()
    savedSize = {
      w = math.max(POP_MIN_W, math.floor(frame.w)),
      h = math.max(POP_MIN_H, math.floor(frame.h)),
    }
    settingsStore.setSize(configModule.keys.popoverSize, savedSize)
  end

  local function getHeader()
    local info = windowService.getWindowInfo(activeWin)
      or windowService.getWindowInfo(callerWin)
      or windowService.getWindowInfo()
    local subtitleLines = {}
    if info then
      subtitleLines[#subtitleLines + 1] = "<span class=\"subtitle-line\">"
        .. html.escape(info.title) .. "</span>"
      subtitleLines[#subtitleLines + 1] = "<span class=\"subtitle-line\">"
        .. html.escape(string.format("%s (%s)", info.appName, info.bundleID))
        .. "</span>"
      subtitleLines[#subtitleLines + 1] = "<span class=\"subtitle-line\">"
        .. html.escape("Window ID: " .. tostring(info.id)) .. "</span>"
    else
      subtitleLines[#subtitleLines + 1] = "<span class=\"subtitle-line\">No active window found</span>"
    end

    local checked = cfg.popoverAutoHideAfterAction and "checked" or ""
    local alwaysOnTopChecked = cfg.popoverAlwaysOnTop and "checked" or ""
    local debugWindowChecked = cfg.popoverDebugWindow and "checked" or ""
    local opacityPercent = math.floor((cfg.popoverBackgroundOpacity or 0.85) * 100 + 0.5)
    local popoverBgCss = string.format("rgba(24, 24, 24, %.2f)", opacityPercent / 100)
    local renderedCss = POPOVER_CSS:gsub("__POPOVER_BG__", popoverBgCss)

    return "<!DOCTYPE html>\n<html>\n<head>\n  <meta charset=\"utf-8\">\n  <style>\n"
      .. renderedCss
      .. "\n  </style>\n</head>\n<body>\n  <div class=\"container\">\n    <div class=\"header\">\n      <div class=\"title-wrap\">\n        <span class=\"title\">TAPSHOP</span>\n        <details class=\"config-menu\">\n          <summary class=\"config-trigger\">Config</summary>\n          <div class=\"config-panel\">\n            <label class=\"config-item\">\n              <input type=\"checkbox\" "
      .. checked
      .. " onchange=\"sendAction('setAutoHideAfterAction', this.checked ? 1 : 0)\">\n              Auto-hide after pair/unpair\n            </label>\n            <label class=\"config-item\">\n              <input type=\"checkbox\" "
      .. alwaysOnTopChecked
      .. " onchange=\"sendAction('setAlwaysOnTop', this.checked ? 1 : 0)\">\n              Always on top\n            </label>\n            <div class=\"config-slider-wrap\">\n              <div class=\"config-slider-row\">\n                <span>Background opacity</span>\n              </div>\n              <input class=\"config-slider\" type=\"range\" min=\"40\" max=\"100\" step=\"10\" value=\""
      .. tostring(opacityPercent)
      .. "\" onchange=\"sendAction('setPopoverOpacity', this.value)\">\n            </div>\n            <label class=\"config-item\" style=\"margin-top: 8px;\">\n              <input type=\"checkbox\" "
      .. debugWindowChecked
      .. " onchange=\"sendAction('setDebugWindow', this.checked ? 1 : 0)\">\n              Debug Window\n            </label>\n          </div>\n        </details>\n      </div>\n      <div class=\"header-details\">\n        "
      .. table.concat(subtitleLines, "\n          ")
      .. "\n      </div>\n    </div>\n    <div class=\"workspace-list\">\n"
  end

  local function rowHtml(index, workspace)
    local title = html.escape(workspace.displayTitle or "[empty]")
    local isPaired = workspace:isPaired()
    local className = "unpaired"
    if isPaired then
      local pairedWin = windowService.getWindowById(workspace.id)
      if pairedWin and pairedWin:isMinimized() then
        className = "paired-minimized"
      else
        className = "paired"
      end
    end
    local offClass = isPaired and "" or " off"

    return "    <div class=\"row\">\n"
      .. "      <span class=\"slot-num\">" .. index .. "</span>\n"
      .. "      <span class=\"slot-label " .. className .. "\"><span class=\"slot-text-bg\">" .. title .. "</span></span>\n"
      .. "      <div class=\"slot-buttons\">\n"
      .. "        <button class=\"btn btn-primary\" onclick=\"sendAction('pair'," .. index .. ")\">Pair</button>\n"
      .. "        <button class=\"btn btn-unpair" .. offClass .. "\" onclick=\"sendAction('unpair'," .. index .. ")\">Unpair</button>\n"
      .. "      </div>\n"
      .. "    </div>\n"
  end

  local function buildHtml()
    local parts = { getHeader() }
    for index, workspace in ipairs(app:getWorkspaces()) do
      parts[#parts + 1] = rowHtml(index, workspace)
    end
    parts[#parts + 1] = POPOVER_FOOTER
    return table.concat(parts)
  end

  local panel = webviewPanel.new({
    messageHandler = "tapshop",
    initialRect = function()
      local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
      return centeredRect(screen)
    end,
    windowStyle = hs.webview.windowMasks.borderless,
    transparent = true,
    level = currentPopoverLevel,
    allowTextEntry = true,
    buildHtml = buildHtml,
    handleAction = function(panelRef, msg)
      local body = msg.body or {}
      local action = body.action
      if action == "dragStart" then
        isDragging = true
        return
      end
      if action == "dragMove" then
        if not isDragging then
          return
        end
        local dx = tonumber(body.dx) or 0
        local dy = tonumber(body.dy) or 0
        if dx == 0 and dy == 0 then
          return
        end
        local frame = panelRef:getWebview():frame()
        panelRef:getWebview():topLeft({
          x = frame.x + dx,
          y = frame.y + dy,
        })
        return
      end
      if action == "dragEnd" then
        isDragging = false
        saveTopLeftFromFrame(panelRef)
        return
      end
      if action == "resizeStart" then
        isResizing = true
        return
      end
      if action == "resizeMove" then
        if not isResizing then
          return
        end
        local dw = tonumber(body.dw) or 0
        local dh = tonumber(body.dh) or 0
        local direction = tostring(body.direction or "")
        if dw == 0 and dh == 0 then
          return
        end
        local frame = panelRef:getWebview():frame()
        local nextX = frame.x
        local nextY = frame.y
        local nextW = frame.w
        local nextH = frame.h

        if direction:find("w", 1, true) then
          nextW = math.max(POP_MIN_W, frame.w - dw)
          nextX = frame.x + (frame.w - nextW)
        elseif direction:find("e", 1, true) then
          nextW = math.max(POP_MIN_W, frame.w + dw)
        end

        if direction:find("n", 1, true) then
          nextH = math.max(POP_MIN_H, frame.h - dh)
          nextY = frame.y + (frame.h - nextH)
        elseif direction:find("s", 1, true) then
          nextH = math.max(POP_MIN_H, frame.h + dh)
        end

        panelRef:getWebview():frame(hs.geometry.rect(nextX, nextY, nextW, nextH))
        return
      end
      if action == "resizeEnd" then
        isResizing = false
        saveTopLeftFromFrame(panelRef)
        saveSizeFromFrame(panelRef)
        return
      end
      if action == "close" then
        panelRef:hide()
        return
      end
      if action == "pair" then
        body.sourceWindow = activeWin or callerWin
      end
      app:handlePopoverAction(body)
      if action == "setAlwaysOnTop" then
        panelRef:setLevel(currentPopoverLevel())
      end
    end,
    windowCallback = function(panelRef, act, _, state)
      if act == "focusChange" and state == false and panelRef:isShown() and not cfg.popoverAlwaysOnTop then
        panelRef:hide()
      end
    end,
    beforeShow = function(_, view)
      callerWin = hs.window.frontmostWindow()
      activeWin = callerWin
      local size = currentPopoverSize()
      if savedTopLeft then
        view:frame(hs.geometry.rect(savedTopLeft.x, savedTopLeft.y, size.w, size.h))
      else
        local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
        view:frame(centeredRect(screen))
      end
      view:level(currentPopoverLevel())
    end,
    afterShow = function(panelRef)
      if not escTap then
        escTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(evt)
          if evt:getKeyCode() == hs.keycodes.map.escape and panelRef:isShown() then
            panelRef:hide()
            return true
          end
          return false
        end)
      end
      escTap:start()
    end,
    beforeHide = function()
      isDragging = false
      isResizing = false
      if escTap then
        escTap:stop()
      end
    end,
  })

  local instance = {}

  function instance:show()
    panel:show()
  end

  function instance:hide()
    panel:hide()
  end

  function instance:toggle()
    panel:toggle()
  end

  function instance:refreshIfShown()
    if panel:isShown() then
      panel:refresh()
      return
    end
    panel:markDirty()
  end

  function instance:refreshCache()
    panel:markDirty()
    panel:setLevel(currentPopoverLevel())
    if panel:isShown() then
      panel:refresh()
    end
  end

  function instance:updateActiveWindow(win)
    if win then
      activeWin = win
    else
      activeWin = hs.window.frontmostWindow() or activeWin
    end
    self:refreshIfShown()
  end

  function instance:getDebugState()
    return {
      isShown = panel:isShown(),
      callerWindow = windowService.getWindowInfo(callerWin),
      activeWindow = windowService.getWindowInfo(activeWin),
    }
  end

  return instance
end

return Popover
