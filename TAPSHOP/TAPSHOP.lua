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
  popoverAutoHideAfterAction = false,
  popoverAlwaysOnTop = true,
  popoverBackgroundOpacity = 0.85,
  popoverDebugWindow = false,

  tapshopMsgBottomMargin = 100,
  tapshopMsgWidth = 760,
  tapshopMsgTextSize = 14,
  tapshopMsgMaxLines = 25,

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

local POPOVER_AUTO_HIDE_KEY = "tapshop.popover.autoHideAfterAction"
local storedAutoHide = hs.settings.get(POPOVER_AUTO_HIDE_KEY)
if type(storedAutoHide) == "boolean" then
  Config.popoverAutoHideAfterAction = storedAutoHide
end

local POPOVER_ALWAYS_ON_TOP_KEY = "tapshop.popover.alwaysOnTop"
local storedAlwaysOnTop = hs.settings.get(POPOVER_ALWAYS_ON_TOP_KEY)
if type(storedAlwaysOnTop) == "boolean" then
  Config.popoverAlwaysOnTop = storedAlwaysOnTop
end

local POPOVER_BG_OPACITY_KEY = "tapshop.popover.backgroundOpacity"
local storedBgOpacity = hs.settings.get(POPOVER_BG_OPACITY_KEY)
if type(storedBgOpacity) == "number" and storedBgOpacity >= 0.40 and storedBgOpacity <= 1.00 then
  local snapped = math.floor((storedBgOpacity * 100) / 10 + 0.5) * 10
  Config.popoverBackgroundOpacity = math.max(40, math.min(100, snapped)) / 100
end

local POPOVER_DEBUG_WINDOW_KEY = "tapshop.popover.debugWindow"
local storedDebugWindow = hs.settings.get(POPOVER_DEBUG_WINDOW_KEY)
if type(storedDebugWindow) == "boolean" then
  Config.popoverDebugWindow = storedDebugWindow
end

-- =========== State ===========

local function Workspace(label)
  return {
    label = label,
    id = nil,
    isPaired = false,
    inputBuffer = Config.minimizeThreshold,
    displayTitle = "[empty]",
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
local Popover = nil
local DebugWindow = nil
local function syncUi()
  if Popover and Popover.refreshCache then
    Popover.refreshCache()
  elseif Popover and Popover.refreshIfShown then
    Popover.refreshIfShown()
  end
  if DebugWindow and DebugWindow.syncVisibility then
    DebugWindow.syncVisibility()
  end
end

local function runPairingAction(actionFn)
  actionFn()
  syncUi()
  if TAPSHOP.cfg.popoverAutoHideAfterAction and Popover and Popover.hide then
    Popover.hide()
  end
end


-- =========== TapshopMsg ===========

local TapshopMsg = (function()
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
    local w = Config.tapshopMsgWidth
    local textSize = Config.tapshopMsgTextSize
    local padding = 14
    local lineHeight = math.floor(textSize * 1.35)
    local h = padding * 2 + (lineCount * lineHeight)

    local x = math.floor(vf.x + (vf.w - w) / 2)
    local y = math.floor(vf.y + vf.h - Config.tapshopMsgBottomMargin - h)

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
      txt:setTextSize(Config.tapshopMsgTextSize)
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
    if #lines > Config.tapshopMsgMaxLines then
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
      TapshopMsg("YT Target Updated: " .. (win:title() or "[untitled]"))
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

local refreshWorkspaceDisplayTitle
local refreshPairedWorkspaceTitlesForWindow

local function setWorkspacePairing(workspace, id, win)
  workspace.id = id
  workspace.isPaired = true
  workspace.inputBuffer = TAPSHOP.cfg.minimizeThreshold
  refreshWorkspaceDisplayTitle(workspace, win)
end

local function clearWorkspacePairing(workspace)
  workspace.id = nil
  workspace.isPaired = false
  workspace.inputBuffer = TAPSHOP.cfg.minimizeThreshold
  workspace.displayTitle = "[empty]"
end

-- =========== Window event subscription ===========

local wf = hs.window.filter.new()
wf:subscribe({
  hs.window.filter.windowFocused,
  hs.window.filter.windowTitleChanged,
  hs.window.filter.windowCreated,
  hs.window.filter.windowDestroyed,
  hs.window.filter.windowVisible,
  hs.window.filter.windowMinimized,
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
            clearWorkspacePairing(ws)
            changed = true
          end
        end
        if changed then
          TapshopMsg("[Cleared pairing: window closed]")
          syncUi()
        end
      end
      return
    end
    refreshPairedWorkspaceTitlesForWindow(win)
    setYTTargetIfApplicable(win)
    if TAPSHOP.cfg.popoverDebugWindow and DebugWindow and DebugWindow.refreshIfShown then
      DebugWindow.refreshIfShown()
    end
  end)
end)

-- =========== Window pairing ===========

local function pairWindow(workspace)
  local win = hs.window.frontmostWindow()
  if not win then
    TapshopMsg("No active window found!")
    return
  end

  local currentId = win:id()

  if not workspace.isPaired or not workspace.id then
    setWorkspacePairing(workspace, currentId, win)

    local info = GetWinInfo(win)
    TapshopMsg(
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
      refreshWorkspaceDisplayTitle(workspace, paired)
    else
      clearWorkspacePairing(workspace)
      TapshopMsg("[Paired window missing; cleared]")
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
    clearWorkspacePairing(workspace)
    TapshopMsg("[Unpaired " .. workspace.label .. "]")
  else
    TapshopMsg(workspace.label .. " is already unpaired!")
  end
end

local function unpairAll()
  for _, ws in ipairs(TAPSHOP.workspaces) do
    clearWorkspacePairing(ws)
  end
  TapshopMsg("[Unpaired All Windows]")
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
    TapshopMsg("YouTube window not found.")
    return
  end

  local targetApp = target:application()
  if TAPSHOP.cfg.youtubeDirectDispatch and targetApp and sendKeyStrokes(keyPress, targetApp) then
    return
  end

  local prevWin = hs.window.frontmostWindow()

  if not focusOrRestore(target) then
    TapshopMsg("Focus failed for YT window")
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

local function windowDisplayTitle(win)
  if not win then
    return "[empty]"
  end
  local app = win:application()
  local prefix = app and app:name() or "App"
  local title = win:title() or ""
  if win:isMinimized() then
    title = title .. " (minimized)"
  end
  return "[" .. prefix .. "] " .. title
end

refreshWorkspaceDisplayTitle = function(workspace, win)
  if not workspace then
    return
  end
  if not workspace.id then
    workspace.displayTitle = "[empty]"
    return
  end

  local target = win
  if not target or target:id() ~= workspace.id then
    target = hs.window.get(workspace.id)
  end

  if target then
    workspace.displayTitle = windowDisplayTitle(target)
  else
    workspace.displayTitle = "[empty]"
  end
end

refreshPairedWorkspaceTitlesForWindow = function(win)
  if not win then
    return
  end
  local id = win:id()
  if not id then
    return
  end

  local title = windowDisplayTitle(win)
  for _, ws in ipairs(TAPSHOP.workspaces) do
    if ws.id == id then
      ws.displayTitle = title
    end
  end
end

local function winTitleById(id)
  local w = id and hs.window.get(id)
  if w then return windowDisplayTitle(w) end
  return "[empty]"
end


-- =========== Popover ===========

Popover = (function()
  local wv = nil
  local uc = nil
  local escTap = nil
  local callerWin = nil
  local activeWin = nil
  local isShown = false
  local isDragging = false
  local cachedHtml = nil
  local isHtmlDirty = true
  local POSITION_SETTINGS_KEY = "tapshop.popover.topLeft"

  local POP_W = 500
  local POP_H = 424
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
  background: transparent;
  color: #e0e0e0;
  font-size: 13px;
  -webkit-user-select: none;
  overflow: hidden;
}

.container {
  height: 100%;
  padding: 12px;
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
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
  padding-bottom: 10px;
  border-bottom: 1px solid #333;
  margin-bottom: 6px;
  cursor: move;
}

.header .title-wrap {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 6px;
  min-width: 0;
}

.header .title {
  display: block;
  font-weight: 700;
  font-size: 14px;
  color: #fff;
  letter-spacing: 0.5px;
}

.header .header-details {
  margin-left: auto;
  text-align: right;
}

.header .subtitle-line {
  display: block;
  max-width: 300px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 11px;
  color: #9aa0a6;
}

.row {
  display: flex;
  align-items: center;
  padding: 5px 0;
}

.slot-num {
  width: 18px;
  text-align: right;
  color: #fff;
  font-size: 11px;
  font-weight: 600;
  margin-right: 8px;
  flex-shrink: 0;
}

.slot-label {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  margin-right: 8px;
  font-size: 12px;
}

.slot-text-bg {
  display: inline-block;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  padding: 2px 8px;
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
  margin-top: 6px;
  min-width: 245px;
  border: 1px solid #3c3c3c;
  border-radius: 6px;
  background: #171717;
  box-shadow: 0 12px 24px rgba(0, 0, 0, 0.45);
  padding: 8px 10px;
  z-index: 5;
}

.config-item {
  display: flex;
  align-items: center;
  gap: 7px;
  font-size: 11px;
  color: #c6c6c6;
  cursor: pointer;
}

.config-item input {
  accent-color: #2d6ee6;
}

.config-slider-wrap {
  display: flex;
  flex-direction: column;
  gap: 4px;
  margin-top: 8px;
}

.config-slider-row {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 11px;
  color: #c6c6c6;
}

.config-slider {
  width: 100%;
}

.config-trigger {
  border: none;
  border-radius: 4px;
  padding: 5px 10px;
  font-size: 11px;
  font-weight: 600;
  background: #2a2a2a;
  color: #999;
  cursor: pointer;
}

.config-trigger:hover {
  background: #3a3a3a;
  color: #c0c0c0;
}

]=]

  local POPOVER_FOOTER = [=[
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

  local function escapeHtml(s)
    return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
  end

  local function getHeader()
    local info = GetWinInfo(activeWin) or GetWinInfo(callerWin) or GetWinInfo()
    local subtitleLines = {}
    if info then
      subtitleLines[#subtitleLines + 1] = "<span class=\"subtitle-line\">"
        .. escapeHtml(info.title) .. "</span>"
      subtitleLines[#subtitleLines + 1] = "<span class=\"subtitle-line\">"
        .. escapeHtml(string.format("%s (%s)", info.appName, info.bundleID))
        .. "</span>"
      subtitleLines[#subtitleLines + 1] = "<span class=\"subtitle-line\">"
        .. escapeHtml("Window ID: " .. tostring(info.id)) .. "</span>"
    else
      subtitleLines[#subtitleLines + 1] = "<span class=\"subtitle-line\">No active window found</span>"
    end
    local checked = TAPSHOP.cfg.popoverAutoHideAfterAction and "checked" or ""
    local alwaysOnTopChecked = TAPSHOP.cfg.popoverAlwaysOnTop and "checked" or ""
    local debugWindowChecked = TAPSHOP.cfg.popoverDebugWindow and "checked" or ""
    local opacityPercent = math.floor((TAPSHOP.cfg.popoverBackgroundOpacity or 0.85) * 100 + 0.5)
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
      .. "\n      </div>\n    </div>\n"
  end

  local function rowHtml(i, ws)
    local title = escapeHtml(ws.displayTitle or winTitleById(ws.id))
    local isPaired = ws.isPaired and ws.id
    local cls = "unpaired"
    if isPaired then
      local pairedWin = hs.window.get(ws.id)
      if pairedWin and pairedWin:isMinimized() then
        cls = "paired-minimized"
      else
        cls = "paired"
      end
    end
    local off = isPaired and "" or " off"
    return "    <div class=\"row\">\n"
      .. "      <span class=\"slot-num\">" .. i .. "</span>\n"
      .. "      <span class=\"slot-label " .. cls .. "\"><span class=\"slot-text-bg\">" .. title .. "</span></span>\n"
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

  local function renderHtml()
    if not wv then return end
    cachedHtml = buildHtml()
    isHtmlDirty = false
    wv:html(cachedHtml)
  end

  local function markHtmlDirty()
    isHtmlDirty = true
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

  local function currentPopoverLevel()
    if TAPSHOP.cfg.popoverAlwaysOnTop then
      return hs.drawing.windowLevels.popUpMenu
    end
    return hs.drawing.windowLevels.normal
  end

  local function applyPopoverLevel()
    if not wv then return end
    wv:level(currentPopoverLevel())
  end

  local function clampPopoverOpacityPercent(value)
    if value < 40 then return 40 end
    if value > 100 then return 100 end
    return value
  end

  local actionHandlers = {
    pair = function(body)
      runPairingAction(function()
        local slot = tonumber(body.slot) or 0
        if slot < 1 or slot > 9 then return end
        local ws = TAPSHOP.workspaces[slot]
        local targetWin = activeWin or callerWin
        if targetWin then
          setWorkspacePairing(ws, targetWin:id(), targetWin)
          local info = GetWinInfo(targetWin)
          TapshopMsg(
            string.format("[Pairing %s]\n%s", ws.label, info and info.title or "[unknown]"),
            2.0
          )
        else
          TapshopMsg("No window to pair!")
        end
      end)
    end,
    unpair = function(body)
      runPairingAction(function()
        local slot = tonumber(body.slot) or 0
        if slot < 1 or slot > 9 then return end
        unpairWindow(TAPSHOP.workspaces[slot])
      end)
    end,
    unpairAll = function()
      runPairingAction(unpairAll)
    end,
    close = function() end,
    setAutoHideAfterAction = function(body)
      local nextValue = tonumber(body.slot) == 1
      TAPSHOP.cfg.popoverAutoHideAfterAction = nextValue
      hs.settings.set(POPOVER_AUTO_HIDE_KEY, nextValue)
      syncUi()
    end,
    setAlwaysOnTop = function(body)
      local nextValue = tonumber(body.slot) == 1
      TAPSHOP.cfg.popoverAlwaysOnTop = nextValue
      hs.settings.set(POPOVER_ALWAYS_ON_TOP_KEY, nextValue)
      applyPopoverLevel()
      syncUi()
    end,
    setPopoverOpacity = function(body)
      local rawPercent = tonumber(body.slot)
      if not rawPercent then return end
      local clampedPercent = clampPopoverOpacityPercent(math.floor(rawPercent / 10 + 0.5) * 10)
      local nextOpacity = clampedPercent / 100
      TAPSHOP.cfg.popoverBackgroundOpacity = nextOpacity
      hs.settings.set(POPOVER_BG_OPACITY_KEY, nextOpacity)
      syncUi()
    end,
    setDebugWindow = function(body)
      local nextValue = tonumber(body.slot) == 1
      TAPSHOP.cfg.popoverDebugWindow = nextValue
      hs.settings.set(POPOVER_DEBUG_WINDOW_KEY, nextValue)
      syncUi()
    end,
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

    if actionHandlers[action] then
      actionHandlers[action](body)
    end

    if isDragAction then return end
    if action == "close" then
      hide()
      return
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
    wv:transparent(true)
    applyPopoverLevel()
    wv:allowNewWindows(false)
    wv:allowNavigationGestures(false)
    wv:allowTextEntry(true)

    wv:windowCallback(function(act, _, state)
      if act == "focusChange"
        and state == false
        and isShown
        and not TAPSHOP.cfg.popoverAlwaysOnTop
      then
        hide()
      end
    end)
  end

  local function show()
    callerWin = hs.window.frontmostWindow()
    activeWin = callerWin
    ensureWebview()

    local scr = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
    if hasSavedPosition then
      wv:frame(hs.geometry.rect(savedTopLeft.x, savedTopLeft.y, POP_W, POP_H))
    else
      wv:frame(centeredRect(scr))
    end

    if isHtmlDirty or not cachedHtml then
      renderHtml()
    end
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
    if not wv then
      markHtmlDirty()
      return
    end

    if not isShown then
      markHtmlDirty()
      return
    end

    renderHtml()
  end

  local function refreshCache()
    if not wv then
      markHtmlDirty()
      return
    end

    renderHtml()
  end

  local function updateActiveWindow(win)
    if win then
      activeWin = win
    else
      activeWin = hs.window.frontmostWindow() or activeWin
    end
    refreshIfShown()
  end

  local function getDebugState()
    return {
      isShown = isShown,
      callerWindow = GetWinInfo(callerWin),
      activeWindow = GetWinInfo(activeWin),
    }
  end

  local function toggle()
    if isShown then
      hide()
    else
      show()
    end
  end

  return {
    toggle = toggle,
    show = show,
    hide = hide,
    refreshIfShown = refreshIfShown,
    refreshCache = refreshCache,
    updateActiveWindow = updateActiveWindow,
    getDebugState = getDebugState,
  }
end)()

-- =========== Debug Window ===========

DebugWindow = (function()
  local wv = nil
  local uc = nil
  local isShown = false
  local cachedHtml = nil
  local isHtmlDirty = true

  local DEBUG_W = 620
  local DEBUG_H = 360

  local function formatWindowDebug(index, w, includeFlags)
    local app = w and w:application() or nil
    local fields = {
      string.format("id = %s", tostring(w and w:id() or nil)),
      string.format("title = %q", tostring(w and w:title() or "")),
      string.format("app = %q", tostring(app and app:name() or "")),
      string.format("bundleID = %q", tostring(app and app:bundleID() or "")),
    }
    if includeFlags and w then
      fields[#fields + 1] = string.format("visible = %s", tostring(w:isVisible()))
      fields[#fields + 1] = string.format("standard = %s", tostring(w:isStandard()))
      fields[#fields + 1] = string.format("minimized = %s", tostring(w:isMinimized()))
    end
    return string.format("[%d] { %s }", index, table.concat(fields, ", "))
  end

  local function candidateWindowsDebugText()
    local lines = {}
    local wins = candidateWindows()
    for i, w in ipairs(wins) do
      lines[#lines + 1] = formatWindowDebug(i, w, false)
    end
    if #lines == 0 then
      return "candidateWindows = []"
    end
    return "candidateWindows = [\n" .. table.concat(lines, ",\n") .. "\n]"
  end

  local function orderedWindowsDebugText()
    local lines = {}
    local wins = hs.window.orderedWindows()
    for i, w in ipairs(wins) do
      lines[#lines + 1] = formatWindowDebug(i, w, true)
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
    local frontmostInfo = GetWinInfo(hs.window.frontmostWindow())
    local popoverState = (Popover and Popover.getDebugState) and Popover.getDebugState() or nil
    local ytTargetInfo = TAPSHOP.ytTargetId and GetWinInfo(hs.window.get(TAPSHOP.ytTargetId)) or nil

    lines[#lines + 1] = windowInfoLine("frontmostWindow", frontmostInfo)
    lines[#lines + 1] = windowInfoLine("activeWindow", popoverState and popoverState.activeWindow or nil)
    lines[#lines + 1] = windowInfoLine("callerWindow", popoverState and popoverState.callerWindow or nil)
    lines[#lines + 1] = windowInfoLine("targetWindow", ytTargetInfo)
    lines[#lines + 1] = string.format("popoverShown = %s", tostring(popoverState and popoverState.isShown or false))
    lines[#lines + 1] = string.format("ytTargetId = %s", tostring(TAPSHOP.ytTargetId))

    return table.concat(lines, "\n")
  end

  local function centeredRect()
    local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
    local vf = screen:frame()
    return hs.geometry.rect(
      math.floor(vf.x + (vf.w - DEBUG_W) / 2),
      math.floor(vf.y + (vf.h - DEBUG_H) / 2),
      DEBUG_W,
      DEBUG_H
    )
  end

  local function escapeHtml(s)
    return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
  end

  local function buildHtml()
    local candidateText = escapeHtml(candidateWindowsDebugText())
    local orderedText = escapeHtml(orderedWindowsDebugText())
    local miscText = escapeHtml(miscDebugText())
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

  local function renderHtml()
    if not wv then return end
    cachedHtml = buildHtml()
    isHtmlDirty = false
    wv:html(cachedHtml)
  end

  local function markHtmlDirty()
    isHtmlDirty = true
  end

  local function hide()
    if not isShown then return end
    isShown = false
    if wv then wv:hide() end
  end

  local function handleAction(msg)
    local body = msg.body or {}
    if body.action == "disableDebugWindow" then
      TAPSHOP.cfg.popoverDebugWindow = false
      hs.settings.set(POPOVER_DEBUG_WINDOW_KEY, false)
      syncUi()
      return
    end
  end

  local function ensureWebview()
    if wv then return end
    uc = hs.webview.usercontent.new("tapshopDebugWindow")
    uc:setCallback(handleAction)
    wv = hs.webview.new(centeredRect(), { developerExtrasEnabled = false }, uc)
    wv:windowStyle(
      hs.webview.windowMasks.titled
      + hs.webview.windowMasks.closable
      + hs.webview.windowMasks.miniaturizable
      + hs.webview.windowMasks.resizable
    )
    wv:transparent(false)
    wv:level(hs.drawing.windowLevels.floating)
    wv:allowNewWindows(false)
    wv:allowNavigationGestures(false)
    wv:allowTextEntry(false)
    wv:windowCallback(function(act)
      if act == "closing" then
        isShown = false
        if TAPSHOP.cfg.popoverDebugWindow then
          TAPSHOP.cfg.popoverDebugWindow = false
          hs.settings.set(POPOVER_DEBUG_WINDOW_KEY, false)
          if Popover and Popover.refreshIfShown then
            Popover.refreshIfShown()
          end
        end
      end
    end)
  end

  local function show()
    ensureWebview()
    if isHtmlDirty or not cachedHtml then
      renderHtml()
    end
    wv:show()
    isShown = true
  end

  local function refreshIfShown()
    if not wv then
      markHtmlDirty()
      return
    end
    if not isShown then
      markHtmlDirty()
      return
    end
    renderHtml()
  end

  local function syncVisibility()
    if TAPSHOP.cfg.popoverDebugWindow then
      show()
      return
    end
    hide()
  end

  return {
    refreshIfShown = refreshIfShown,
    syncVisibility = syncVisibility,
  }
end)()

local popoverWindowTracker = hs.window.filter.new()
popoverWindowTracker:subscribe({
  hs.window.filter.windowFocused,
  hs.window.filter.windowTitleChanged,
}, function(win)
  pcall(function()
    Popover.updateActiveWindow(win)
    if TAPSHOP.cfg.popoverDebugWindow and DebugWindow and DebugWindow.refreshIfShown then
      DebugWindow.refreshIfShown()
    end
  end)
end)

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
local hyper = { "cmd", "alt", "ctrl" }

-- Cmd+Option+1..9: context-aware pair/focus/minimize
for i = 1, 9 do
  hs.hotkey.bind(pairMods, tostring(i), function()
    runPairingAction(function()
      pairWindow(TAPSHOP.workspaces[i])
    end)
  end)
end

-- Cmd+Option+Shift+1..9: unpair; Cmd+Option+Shift+0: unpair all
for i = 1, 9 do
  hs.hotkey.bind(unpairMods, tostring(i), function()
    runPairingAction(function()
      unpairWindow(TAPSHOP.workspaces[i])
    end)
  end)
end
hs.hotkey.bind(unpairMods, "0", function()
  runPairingAction(unpairAll)
end)

-- Popover toggle (Cmd+Option+`)
hs.hotkey.bind(pairMods, "`", function()  Popover.toggle() end)

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

TapshopMsg("TAPSHOP ready (Hammerspoon)")
