-- TAPSHOP (Hammerspoon port)
-- Requires: Accessibility permissions enabled for Hammerspoon

-- =========== Config ===========

local Config = {
  inputDelay = 0.05,           -- seconds
  minimizeThreshold = 2,
  isGuiDebugMode = false,
  isHotkeyDebugMode = false,
  focusWaitTimeout = 0.22,     -- seconds
  focusPollMicros = 10000,     -- 10ms polling
  youtubeDirectDispatch = true,

  cursorMsgBottomMargin = 100,
  cursorMsgWidth = 760,
  cursorMsgTextSize = 14,
  cursorMsgMaxLines = 25,

  browserBundleIDs = {
    ["com.apple.Safari"] = true,
    ["com.google.Chrome"] = true,
    ["org.chromium.Chromium"] = true,
    ["com.brave.Browser"] = true,
    ["com.operasoftware.Opera"] = true,
    ["com.operasoftware.OperaGX"] = true,
    ["com.vivaldi.Vivaldi"] = true,
    ["org.mozilla.firefox"] = true,
    ["com.microsoft.edgemac"] = true,
    ["ru.yandex.desktop.yandex-browser"] = true,
    ["org.waterfoxproject.waterfox"] = true,
    ["org.torproject.torbrowser"] = true,
    ["com.maxthon.browser"] = true,
    ["com.maxthon.Maxthon"] = true,
    ["org.mozilla.seamonkey"] = true,
    ["com.hiddenreflex.epic"] = true,
    ["com.hiddenreflex.epicbrowser"] = true,
    ["com.flashpeak.Slimjet"] = true,
    ["com.comodo.dragon"] = true,
    ["com.avast.browser"] = true,
    ["com.srware.iron"] = true,
    ["org.kde.falkon"] = true,
    ["company.thebrowser.Browser"] = true,
    ["company.thebrowser.dia"] = true,
    ["ai.perplexity.comet"] = true,
    ["io.gitlab.librewolf-community.librewolf"] = true,
    ["one.ablaze.floorp"] = true,
  },
}

-- =========== State ===========

local function Workspace(label)
  return {
    label = label,
    id = nil,
    isPaired = false,
    inputBuffer = Config.minimizeThreshold,
  }
end

local TAPSHOP = {
  cfg = Config,
  workspaces = {},
  ytTargetId = nil,
}

for i = 1, 9 do
  TAPSHOP.workspaces[#TAPSHOP.workspaces + 1] = Workspace("Window " .. tostring(i))
end

-- =========== CursorMsg ===========

local CursorMsg = (function()
  local lines = {}
  local timer = nil
  local bg = nil
  local txt = nil

  local function pickScreen()
    return hs.mouse.getCurrentScreen()
      or (hs.window.frontmostWindow() and hs.window.frontmostWindow():screen())
      or hs.screen.mainScreen()
  end

  local function computeRects(lineCount)
    local scr = pickScreen()
    local vf = scr:frame()
    local w = Config.cursorMsgWidth
    local textSize = Config.cursorMsgTextSize
    local padding = 14
    local lineHeight = math.floor(textSize * 1.35)
    local h = padding * 2 + (lineCount * lineHeight)

    local x = math.floor(vf.x + (vf.w - w) / 2)
    local y = math.floor(vf.y + vf.h - Config.cursorMsgBottomMargin - h)

    local rect = hs.geometry.rect(x, y, w, h)
    local textRect = hs.geometry.rect(
      x + padding,
      y + padding,
      w - padding * 2,
      h - padding * 2
    )

    return rect, textRect
  end

  local function destroy()
    if bg then
      bg:delete()
      bg = nil
    end
    if txt then
      txt:delete()
      txt = nil
    end
  end

  local function render(secs)
    local buf = {}
    for i = 1, #lines do
      local prefix = (i == #lines) and "> " or "  "
      buf[#buf + 1] = prefix .. tostring(lines[i])
    end

    local text = table.concat(buf, "\n")
    if text == "" then
      text = " "
    end

    local rect, textRect = computeRects(#lines)

    if not bg then
      bg = hs.drawing.rectangle(rect)
      bg:setFill(true)
      bg:setFillColor({ red = 0, green = 0, blue = 0, alpha = 0.70 })
      bg:setStroke(false)
      bg:setRoundedRectRadii(8, 8)
      bg:setLevel(hs.drawing.windowLevels.popUpMenu)
      bg:setBehavior(hs.drawing.windowBehaviors.canJoinAllSpaces)
    else
      bg:setFrame(rect)
    end

    if not txt then
      txt = hs.drawing.text(textRect, text)
      txt:setTextSize(Config.cursorMsgTextSize)
      txt:setTextColor({ white = 1, alpha = 1 })
      txt:setLevel(hs.drawing.windowLevels.popUpMenu)
      txt:setBehavior(hs.drawing.windowBehaviors.canJoinAllSpaces)
    else
      txt:setFrame(textRect)
      txt:setText(text)
    end

    bg:show()
    txt:show()

    if timer then
      timer:stop()
      timer = nil
    end
    timer = hs.timer.doAfter(secs, function()
      lines = {}
      destroy()
    end)
  end

  return function(msg, secs)
    secs = secs or 2.0
    lines[#lines + 1] = tostring(msg)
    if #lines > Config.cursorMsgMaxLines then
      table.remove(lines, 1)
    end
    render(secs)
  end
end)()

-- =========== Helpers ===========

local function sleepSeconds(sec)
  if sec and sec > 0 then
    hs.timer.usleep(math.floor(sec * 1e6))
  end
end

local function GetWinInfo(win)
  win = win or hs.window.frontmostWindow()
  if not win then
    return nil
  end
  local app = win:application()
  return {
    title = win:title() or "",
    id = win:id(),
    appName = app and app:name() or "",
    bundleID = app and app:bundleID() or "",
  }
end

local function candidateWindows()
  local wins = hs.window.orderedWindows()
  local out = {}
  for _, w in ipairs(wins) do
    if w
      and w:isVisible()
      and w:isStandard()
      and (w:title() or ""):match("%S")
    then
      out[#out + 1] = w
    end
  end
  return out
end

local function waitForFrontmost(win, timeoutSec)
  timeoutSec = timeoutSec or Config.focusWaitTimeout
  local start = hs.timer.secondsSinceEpoch()
  while (hs.timer.secondsSinceEpoch() - start) < timeoutSec do
    local fw = hs.window.frontmostWindow()
    if fw and win and fw:id() == win:id() then
      return true
    end
    hs.timer.usleep(Config.focusPollMicros)
  end
  return false
end

local function focusOrRestore(win)
  if not win then
    return false
  end

  local app = win:application()
  local fw = hs.window.frontmostWindow()
  if fw and fw:id() == win:id() then
    return true
  end

  if app and app:isHidden() then
    app:unhide()
  end
  if app then
    app:activate(true)
  end
  if win:isMinimized() then
    win:unminimize()
    hs.timer.usleep(15000)
  end

  win:focus()
  return waitForFrontmost(win)
end

-- =========== YouTube window tracking ===========

local function isYouTubeWindow(win)
  if not win or not win:isVisible() then
    return false
  end
  local app = win:application()
  if not app then
    return false
  end

  local bid = app:bundleID() or ""
  if not TAPSHOP.cfg.browserBundleIDs[bid] then
    return false
  end

  local title = win:title() or ""
  if title == "" then
    return false
  end
  if title:find("Subscriptions - YouTube", 1, true) then
    return false
  end

  return title:find(" - YouTube", 1, true) ~= nil
end

local function setYTTargetIfApplicable(win)
  if win and isYouTubeWindow(win) then
    local id = win:id()
    if TAPSHOP.ytTargetId ~= id then
      TAPSHOP.ytTargetId = id
      CursorMsg("YT Target Updated: " .. (win:title() or "[untitled]"))
    end
  end
end

local function getYTTargetWindow()
  if TAPSHOP.ytTargetId then
    local w = hs.window.get(TAPSHOP.ytTargetId)
    if w and w:isVisible() and isYouTubeWindow(w) then
      return w
    end
  end

  for _, w in ipairs(candidateWindows()) do
    if isYouTubeWindow(w) then
      TAPSHOP.ytTargetId = w:id()
      return w
    end
  end

  return nil
end

-- =========== Window event subscription ===========

local wf = hs.window.filter.new()
wf:subscribe({
  hs.window.filter.windowFocused,
  hs.window.filter.windowTitleChanged,
  hs.window.filter.windowCreated,
  hs.window.filter.windowDestroyed,
  hs.window.filter.windowVisible,
  hs.window.filter.windowUnminimized,
}, function(win, appName, event)
  pcall(function()
    if event == hs.window.filter.windowDestroyed then
      if win then
        local deadId = win:id()
        if TAPSHOP.ytTargetId and deadId == TAPSHOP.ytTargetId then
          TAPSHOP.ytTargetId = nil
        end
        local changed = false
        for _, ws in ipairs(TAPSHOP.workspaces) do
          if ws.id == deadId then
            ws.id = nil
            ws.isPaired = false
            ws.inputBuffer = TAPSHOP.cfg.minimizeThreshold
            changed = true
          end
        end
        if changed then
          CursorMsg("[Cleared pairing: window closed]")
          rebuildMenu()
        end
      end
      return
    end
    setYTTargetIfApplicable(win)
  end)
end)

-- =========== Window pairing ===========

local function pairWindow(workspace)
  local win = hs.window.frontmostWindow()
  if not win then
    CursorMsg("No active window found!")
    return
  end

  local currentId = win:id()

  if not workspace.isPaired or not workspace.id then
    workspace.id = currentId
    workspace.isPaired = true
    workspace.inputBuffer = TAPSHOP.cfg.minimizeThreshold

    local info = GetWinInfo(win)
    CursorMsg(
      string.format(
        "[Pairing %s]\n%s\nid:%s\napp:%s",
        workspace.label,
        info.title,
        tostring(info.id),
        info.appName
      ),
      2.0
    )
    return
  end

  if currentId ~= workspace.id then
    local paired = hs.window.get(workspace.id)
    if paired then
      workspace.inputBuffer = TAPSHOP.cfg.minimizeThreshold
      focusOrRestore(paired)
    else
      workspace.id = nil
      workspace.isPaired = false
      CursorMsg("[Paired window missing; cleared]")
    end
  else
    workspace.inputBuffer = workspace.inputBuffer - 1
    local paired = hs.window.get(workspace.id)
    if paired and workspace.inputBuffer <= 0 then
      workspace.inputBuffer = TAPSHOP.cfg.minimizeThreshold
      paired:minimize()
    end
  end
end

local function unpairWindow(workspace)
  if workspace.isPaired then
    workspace.id = nil
    workspace.isPaired = false
    workspace.inputBuffer = TAPSHOP.cfg.minimizeThreshold
    CursorMsg("[Unpaired " .. workspace.label .. "]")
  else
    CursorMsg(workspace.label .. " is already unpaired!")
  end
end

local function unpairAll()
  for _, ws in ipairs(TAPSHOP.workspaces) do
    ws.id = nil
    ws.isPaired = false
    ws.inputBuffer = TAPSHOP.cfg.minimizeThreshold
  end
  CursorMsg("[Unpaired All Windows]")
end

-- =========== YouTube control ===========

local keyStrokeMap = {
  ["{Left}"] = "left",
  ["{Right}"] = "right",
}

local function sendKeyStrokes(keys, app)
  local mapped = keyStrokeMap[keys]
  if mapped then
    hs.eventtap.keyStroke({}, mapped, 0, app)
    return true
  end

  if type(keys) == "string" and #keys == 1 then
    hs.eventtap.keyStroke({}, string.lower(keys), 0, app)
    return true
  end

  if Config.isHotkeyDebugMode then
    hs.printf("sendKeyStrokes: unsupported key sequence: %s", tostring(keys))
  end
  return false
end

local function YoutubeControl(keyPress)
  local target = getYTTargetWindow()
  if not target then
    CursorMsg("YouTube window not found.")
    return
  end

  local targetApp = target:application()
  if TAPSHOP.cfg.youtubeDirectDispatch and targetApp and sendKeyStrokes(keyPress, targetApp) then
    return
  end

  local prevWin = hs.window.frontmostWindow()

  if not focusOrRestore(target) then
    CursorMsg("Focus failed for YT window")
    return
  end

  sleepSeconds(TAPSHOP.cfg.inputDelay)
  sendKeyStrokes(keyPress, nil)

  if prevWin and prevWin:id() ~= target:id() then
    focusOrRestore(prevWin)
  end
end

-- =========== Spotify control ===========

local function spotifyAdjustPosition(delta)
  local pos = hs.spotify.getPosition()
  if type(pos) == "number" then
    hs.spotify.setPosition(math.max(0, pos + delta))
    return
  end

  local script = string.format(
    [[
      tell application "Spotify"
        if it is running then
          try
            set p to player position
            set player position to (p + %f)
          end try
        end if
      end tell
    ]],
    delta
  )
  hs.osascript.applescript(script)
end

local function spotifyToggleLike()
  local script = [[
    tell application "Spotify"
      if it is running then
        try
          set t to current track
          try
            set liked of t to not (liked of t)
          on error
            set starred of t to not (starred of t)
          end try
        end try
      end if
    end tell
  ]]
  hs.osascript.applescript(script)
end

local function SpotifyControlV2(appCommand)
  if appCommand == "APPCOMMAND_MEDIA_PREVIOUSTRACK" then
    hs.spotify.previous()
  elseif appCommand == "APPCOMMAND_MEDIA_NEXTTRACK" then
    hs.spotify.next()
  elseif appCommand == "APPCOMMAND_MEDIA_PLAY_PAUSE" then
    hs.spotify.playpause()
  elseif appCommand == "APPCOMMAND_MEDIA_REWIND" then
    spotifyAdjustPosition(-5)
  elseif appCommand == "APPCOMMAND_MEDIA_FAST_FORWARD" then
    spotifyAdjustPosition(5)
  elseif appCommand == "APPCOMMAND_VOLUME_DOWN" then
    pcall(function()
      local currentVol = hs.spotify.getVolume()
      if currentVol == nil then
        currentVol = 50
      end
      hs.spotify.setVolume(math.max(0, currentVol - 6))
    end)
  elseif appCommand == "APPCOMMAND_VOLUME_UP" then
    pcall(function()
      local currentVol = hs.spotify.getVolume()
      if currentVol == nil then
        currentVol = 50
      end
      hs.spotify.setVolume(math.min(100, currentVol + 6))
    end)
  elseif appCommand == "APPCOMMAND_VOLUME_MUTE" then
    local dev = hs.audiodevice.defaultOutputDevice()
    if dev then
      dev:setMuted(not dev:muted())
    end
  end
end

-- =========== Active window info ===========

local function DisplayActiveWindowStats()
  local info = GetWinInfo()
  if info then
    hs.dialog.blockAlert(
      "Active Window",
      string.format(
        "Title: %s\nID: %s\nApp: %s\nBundleID: %s",
        info.title,
        tostring(info.id),
        info.appName,
        info.bundleID
      ),
      "OK",
      "",
      "informational"
    )
  end
end

-- =========== Menubar ===========

local menuBar = hs.menubar.new(true)

local function winTitleById(id)
  local w = id and hs.window.get(id)
  if w then
    local app = w:application()
    local prefix = app and app:name() or "App"
    local title = w:title() or ""
    if w:isMinimized() then
      title = title .. " (minimized)"
    end
    return "[" .. prefix .. "] " .. title
  end
  return "[Unpaired]"
end

local Popover

local function rebuildMenu()
  local items = {}
  items[#items + 1] = { title = "Active Window Details…", fn = DisplayActiveWindowStats }
  items[#items + 1] = { title = "-" }

  for i, ws in ipairs(TAPSHOP.workspaces) do
    items[#items + 1] = {
      title = string.format("%d) %s", i, winTitleById(ws.id)),
      disabled = true,
    }
    items[#items + 1] = {
      title = "  Pair with current window",
      fn = function()
        pairWindow(ws)
        rebuildMenu()
        Popover.refreshIfShown()
      end,
    }
    items[#items + 1] = {
      title = "  Unpair",
      fn = function()
        unpairWindow(ws)
        rebuildMenu()
        Popover.refreshIfShown()
      end,
    }
    items[#items + 1] = { title = "-" }
  end

  items[#items + 1] = {
    title = "Unpair ALL",
    fn = function()
      unpairAll()
      rebuildMenu()
      Popover.refreshIfShown()
    end,
  }

  menuBar:setMenu(items)
end

menuBar:setTitle("TAPSHOP")
rebuildMenu()

-- =========== Popover ===========
-- Classes: container, header, title, row, slot-num, slot-label, paired, unpaired,
-- slot-buttons, btn, btn-primary, btn-unpair, footer, footer-btn, footer-info,
-- footer-danger, footer-close

Popover = (function()
  local wv = nil
  local uc = nil
  local escTap = nil
  local callerWin = nil
  local isShown = false
  local isDragging = false
  local POSITION_SETTINGS_KEY = "tapshop.popover.topLeft"

  local POP_W = 500
  local POP_H = 410
  local savedTopLeft = hs.settings.get(POSITION_SETTINGS_KEY)
  local hasSavedPosition = type(savedTopLeft) == "table"
    and type(savedTopLeft.x) == "number"
    and type(savedTopLeft.y) == "number"

  local POPOVER_CSS = [=[
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
  background: #1e1e1e;
  color: #e0e0e0;
  font-size: 13px;
  -webkit-user-select: none;
  overflow: hidden;
}

.container {
  padding: 12px;
}

.header {
  display: flex;
  align-items: center;
  padding-bottom: 10px;
  border-bottom: 1px solid #333;
  margin-bottom: 6px;
  cursor: move;
}

.header .title {
  font-weight: 700;
  font-size: 14px;
  color: #fff;
  letter-spacing: 0.5px;
}

.row {
  display: flex;
  align-items: center;
  padding: 5px 0;
}

.slot-num {
  width: 18px;
  text-align: right;
  color: #666;
  font-size: 11px;
  font-weight: 600;
  margin-right: 8px;
  flex-shrink: 0;
}

.slot-label {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  padding-right: 8px;
  font-size: 12px;
}

.paired {
  color: #7ec87e;
}

.unpaired {
  color: #555;
  font-style: italic;
}

.slot-buttons {
  display: flex;
  gap: 4px;
  flex-shrink: 0;
}

.btn {
  border: none;
  border-radius: 4px;
  padding: 4px 11px;
  font-size: 11px;
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
}

.btn-primary:hover {
  background: #4080f0;
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
  gap: 6px;
  margin-top: 10px;
  padding-top: 10px;
  border-top: 1px solid #333;
}

.footer-btn {
  border: none;
  border-radius: 4px;
  padding: 5px 12px;
  font-size: 11px;
  font-weight: 600;
  cursor: pointer;
  transition: opacity 0.12s;
}

.footer-btn:active {
  opacity: 0.6;
}

.footer-info {
  background: #3a3a3a;
  color: #aaa;
}

.footer-info:hover {
  background: #4a4a4a;
  color: #ccc;
}

.footer-danger {
  background: #a03020;
  color: #fff;
}

.footer-danger:hover {
  background: #c04030;
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
]=]

  local POPOVER_FOOTER = [=[
  <div class="footer">
    <button class="footer-btn footer-info" onclick="sendAction('info')">
      Window Details
    </button>
    <button class="footer-btn footer-danger" onclick="sendAction('unpairAll')">
      Unpair ALL
    </button>
    <button class="footer-btn footer-close" onclick="sendAction('close')">
      Close
    </button>
  </div>
</div>
<script>
  function sendAction(action, slot, dx, dy) {
    window.webkit.messageHandlers.tapshop.postMessage({
      action: action,
      slot: slot || 0,
      dx: dx || 0,
      dy: dy || 0,
    });
  }

  var dragState = {
    active: false,
    lastX: 0,
    lastY: 0,
  };

  var header = document.querySelector(".header");
  if (header) {
    header.addEventListener("mousedown", function (e) {
      if (e.button !== 0) return;
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

  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape") sendAction("close");
  });
</script>
</body>
</html>]=]

  local function escapeHtml(s)
    return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
  end

  local function getHeader()
    return "<!DOCTYPE html>\n<html>\n<head>\n  <meta charset=\"utf-8\">\n  <style>\n"
      .. POPOVER_CSS
      .. "\n  </style>\n</head>\n<body>\n  <div class=\"container\">\n    <div class=\"header\">\n      <span class=\"title\">TAPSHOP</span>\n    </div>\n"
  end

  local function rowHtml(i, ws)
    local title = escapeHtml(winTitleById(ws.id))
    local isPaired = ws.isPaired and ws.id
    local cls = isPaired and "paired" or "unpaired"
    local off = isPaired and "" or " off"
    return "    <div class=\"row\">\n"
      .. "      <span class=\"slot-num\">" .. i .. "</span>\n"
      .. "      <span class=\"slot-label " .. cls .. "\">" .. title .. "</span>\n"
      .. "      <div class=\"slot-buttons\">\n"
      .. "        <button class=\"btn btn-primary\" onclick=\"sendAction('pair'," .. i .. ")\">Pair</button>\n"
      .. "        <button class=\"btn btn-unpair" .. off .. "\" onclick=\"sendAction('unpair'," .. i .. ")\">Unpair</button>\n"
      .. "      </div>\n"
      .. "    </div>\n"
  end

  local function buildHtml()
    local parts = { getHeader() }
    for i, ws in ipairs(TAPSHOP.workspaces) do
      parts[#parts + 1] = rowHtml(i, ws)
    end
    parts[#parts + 1] = POPOVER_FOOTER
    return table.concat(parts)
  end

  local function centeredRect(screen)
    local vf = screen:frame()
    return hs.geometry.rect(
      math.floor(vf.x + (vf.w - POP_W) / 2),
      math.floor(vf.y + (vf.h - POP_H) / 2),
      POP_W,
      POP_H
    )
  end

  local function saveTopLeftFromFrame()
    if not wv then return end
    local frame = wv:frame()
    savedTopLeft = {
      x = math.floor(frame.x),
      y = math.floor(frame.y),
    }
    hasSavedPosition = true
    hs.settings.set(POSITION_SETTINGS_KEY, savedTopLeft)
  end

  local function hide()
    if not isShown then return end
    isDragging = false
    isShown = false
    if wv then wv:hide() end
    if escTap then escTap:stop() end
  end

  local actionHandlers = {
    pair = function(body)
      local slot = tonumber(body.slot) or 0
      if slot < 1 or slot > 9 then return end
      local ws = TAPSHOP.workspaces[slot]
      if callerWin then
        ws.id = callerWin:id()
        ws.isPaired = true
        ws.inputBuffer = TAPSHOP.cfg.minimizeThreshold
        local info = GetWinInfo(callerWin)
        CursorMsg(
          string.format("[Pairing %s]\n%s", ws.label, info and info.title or "[unknown]"),
          2.0
        )
      else
        CursorMsg("No window to pair!")
      end
      rebuildMenu()
    end,
    unpair = function(body)
      local slot = tonumber(body.slot) or 0
      if slot < 1 or slot > 9 then return end
      unpairWindow(TAPSHOP.workspaces[slot])
      rebuildMenu()
    end,
    unpairAll = function()
      unpairAll()
      rebuildMenu()
    end,
    info = function()
      if callerWin then
        local info = GetWinInfo(callerWin)
        if info then
          hs.dialog.blockAlert(
            "Active Window",
            string.format(
              "Title: %s\nID: %s\nApp: %s\nBundleID: %s",
              info.title, tostring(info.id), info.appName, info.bundleID
            ),
            "OK", "", "informational"
          )
        end
      else
        DisplayActiveWindowStats()
      end
    end,
    close = function() end,
    dragStart = function()
      isDragging = true
    end,
    dragMove = function(body)
      if not isDragging or not wv then return end

      local dx = tonumber(body.dx) or 0
      local dy = tonumber(body.dy) or 0
      if dx == 0 and dy == 0 then return end

      local frame = wv:frame()
      wv:topLeft({
        x = frame.x + dx,
        y = frame.y + dy,
      })
    end,
    dragEnd = function()
      isDragging = false
      saveTopLeftFromFrame()
    end,
  }

  local function handleAction(msg)
    local body = msg.body or {}
    local action = body.action
    local isDragAction = action == "dragStart" or action == "dragMove" or action == "dragEnd"

    if not isDragAction then
      hide()
    end

    if actionHandlers[action] then
      actionHandlers[action](body)
    end
  end

  local function ensureWebview()
    if wv then return end

    uc = hs.webview.usercontent.new("tapshop")
    uc:setCallback(handleAction)

    local scr = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
    local rect = centeredRect(scr)

    wv = hs.webview.new(rect, { developerExtrasEnabled = false }, uc)
    wv:windowStyle(hs.webview.windowMasks.borderless)
    wv:level(hs.drawing.windowLevels.popUpMenu)
    wv:allowNewWindows(false)
    wv:allowNavigationGestures(false)
    wv:allowTextEntry(true)

    wv:windowCallback(function(act, _, state)
      if act == "focusChange" and state == false and isShown then
        hide()
      end
    end)
  end

  local function show()
    callerWin = hs.window.frontmostWindow()
    ensureWebview()

    local scr = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
    if hasSavedPosition then
      wv:frame(hs.geometry.rect(savedTopLeft.x, savedTopLeft.y, POP_W, POP_H))
    else
      wv:frame(centeredRect(scr))
    end

    wv:html(buildHtml())
    wv:show()
    isShown = true

    if not escTap then
      escTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(evt)
        if evt:getKeyCode() == hs.keycodes.map["escape"] and isShown then
          hide()
          return true
        end
        return false
      end)
    end
    escTap:start()
  end

  local function refreshIfShown()
    if not isShown or not wv then return end
    wv:html(buildHtml())
  end

  local function toggle()
    if isShown then
      hide()
    else
      show()
    end
  end

  return { toggle = toggle, show = show, hide = hide, refreshIfShown = refreshIfShown }
end)()

-- =========== Hotkeys ===========

local function bindIfAvailable(mods, key, fn)
  local map = hs.keycodes.map
  local kLower = string.lower(key)
  if map[key] or map[kLower] then
    hs.hotkey.bind(mods, key, fn)
  else
    hs.printf(
      "Skipping hotkey: %s + %s (key not in keymap)",
      table.concat(mods, "+"),
      key
    )
  end
end

local pairMods = { "cmd", "alt" }
local unpairMods = { "cmd", "alt", "shift" }
local toggleMenuBar = { "cmd", "alt", "shift" }
local hyper = { "cmd", "alt", "ctrl" }

-- Cmd+Option+1..9: context-aware pair/focus/minimize
for i = 1, 9 do
  hs.hotkey.bind(pairMods, tostring(i), function()
    pairWindow(TAPSHOP.workspaces[i])
    rebuildMenu()
    Popover.refreshIfShown()
  end)
end

-- Cmd+Option+Shift+1..9: unpair; Cmd+Option+Shift+0: unpair all
for i = 1, 9 do
  hs.hotkey.bind(unpairMods, tostring(i), function()
    unpairWindow(TAPSHOP.workspaces[i])
    rebuildMenu()
  end)
end
hs.hotkey.bind(unpairMods, "0", function()
  unpairAll()
  rebuildMenu()
end)

-- Active window info (Cmd+Option+`)
hs.hotkey.bind(pairMods, "`", DisplayActiveWindowStats)

-- Popover toggle (Cmd+Option+Shift+`)
hs.hotkey.bind(toggleMenuBar, "`", function()  Popover.toggle() end)

-- YouTube controls (Cmd+Option layer)
hs.hotkey.bind(pairMods, "left",  function() YoutubeControl("{Left}") end)
hs.hotkey.bind(pairMods, "right", function() YoutubeControl("{Right}") end)
hs.hotkey.bind(pairMods, "j",     function() YoutubeControl("j") end)
hs.hotkey.bind(pairMods, "l",     function() YoutubeControl("l") end)
hs.hotkey.bind(pairMods, "k",     function() YoutubeControl("k") end)

-- F19/F20/F21: YouTube seek/pause (guarded)
bindIfAvailable({},         "F19", function() YoutubeControl("{Left}")  end) -- rewind 5 sec
bindIfAvailable({ "ctrl" }, "F19", function() YoutubeControl("j")       end) -- rewind 10 sec
bindIfAvailable({},         "F21", function() YoutubeControl("{Right}") end) -- fast forward 5 sec
bindIfAvailable({ "ctrl" }, "F21", function() YoutubeControl("l")       end) -- fast forward 10 sec
bindIfAvailable({},         "F20", function() YoutubeControl("k")       end) -- play/pause

-- Spotify media keys (guarded)
bindIfAvailable({},         "F7", function() SpotifyControlV2("APPCOMMAND_MEDIA_PREVIOUSTRACK") end) -- skip to previous
bindIfAvailable({},         "F8", function() SpotifyControlV2("APPCOMMAND_MEDIA_PLAY_PAUSE")    end) -- play/pause
bindIfAvailable({},         "F9", function() SpotifyControlV2("APPCOMMAND_MEDIA_NEXTTRACK")     end) -- skip to next

-- Ctrl+F7/F9: seek backward/forward (guarded)
bindIfAvailable({ "ctrl" }, "F7", function() SpotifyControlV2("APPCOMMAND_MEDIA_REWIND")        end)
bindIfAvailable({ "ctrl" }, "F9", function() SpotifyControlV2("APPCOMMAND_MEDIA_FAST_FORWARD")  end)

-- F22/F23/F24: like + volume (guarded)
bindIfAvailable({}, "F22", spotifyToggleLike)
bindIfAvailable({}, "F23", function() SpotifyControlV2("APPCOMMAND_VOLUME_DOWN") end)
bindIfAvailable({}, "F24", function() SpotifyControlV2("APPCOMMAND_VOLUME_UP")   end)

-- Alternate volume controls (Hyper layer)
hs.hotkey.bind(hyper, ",", function()
  local dev = hs.audiodevice.defaultOutputDevice()
  if dev then
    dev:setVolume(math.max(0, (dev:volume() or 25) - 5))
  end
end)
hs.hotkey.bind(hyper, ".", function()
  local dev = hs.audiodevice.defaultOutputDevice()
  if dev then
    dev:setVolume(math.min(100, (dev:volume() or 25) + 5))
  end
end)
hs.hotkey.bind(hyper, "M", function()
  local dev = hs.audiodevice.defaultOutputDevice()
  if dev then
    dev:setMuted(not dev:muted())
  end
end)

CursorMsg("TAPSHOP ready (Hammerspoon)")
