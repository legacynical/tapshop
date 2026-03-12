local YoutubeService = {}
YoutubeService.__index = YoutubeService

local keyStrokeMap = {
  ["{Left}"] = "left",
  ["{Right}"] = "right",
}

local function sleepSeconds(sec)
  if sec and sec > 0 then
    hs.timer.usleep(math.floor(sec * 1e6))
  end
end

local function sendKeyStrokes(cfg, keys, app)
  local mapped = keyStrokeMap[keys]
  if mapped then
    hs.eventtap.keyStroke({}, mapped, 0, app)
    return true
  end

  if type(keys) == "string" and #keys == 1 then
    hs.eventtap.keyStroke({}, string.lower(keys), 0, app)
    return true
  end

  if cfg.isHotkeyDebugMode then
    hs.printf("sendKeyStrokes: unsupported key sequence: %s", tostring(keys))
  end
  return false
end

function YoutubeService.new(cfg, windowService, toast)
  return setmetatable({
    cfg = cfg,
    windowService = windowService,
    toast = toast,
    ytTargetId = nil,
  }, YoutubeService)
end

function YoutubeService:isSupportedBrowser(bundleId)
  return self.cfg.browserBundleIDs[bundleId or ""] == true
end

function YoutubeService:isYouTubeWindow(win)
  if not win or not win:isVisible() then
    return false
  end

  local app = win:application()
  if not app then
    return false
  end

  local bundleId = app:bundleID() or ""
  if not self:isSupportedBrowser(bundleId) then
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

function YoutubeService:handleWindowCandidate(win)
  if win and self:isYouTubeWindow(win) then
    local id = win:id()
    if self.ytTargetId ~= id then
      self.ytTargetId = id
      self.toast("YT Target Updated: " .. (win:title() or "[untitled]"))
    end
  end
end

function YoutubeService:handleDestroyedWindowId(id)
  if self.ytTargetId == id then
    self.ytTargetId = nil
  end
end

function YoutubeService:getTargetId()
  return self.ytTargetId
end

function YoutubeService:getTargetWindow()
  if self.ytTargetId then
    local win = self.windowService.getWindowById(self.ytTargetId)
    if win and win:isVisible() and self:isYouTubeWindow(win) then
      return win
    end
  end

  for _, win in ipairs(self.windowService.candidateWindows()) do
    if self:isYouTubeWindow(win) then
      self.ytTargetId = win:id()
      return win
    end
  end

  return nil
end

function YoutubeService:sendCommand(keyPress)
  local target = self:getTargetWindow()
  if not target then
    self.toast("YouTube window not found.")
    return
  end

  local targetApp = target:application()
  if self.cfg.youtubeDirectDispatch and targetApp and sendKeyStrokes(self.cfg, keyPress, targetApp) then
    return
  end

  local previousWindow = hs.window.frontmostWindow()
  if not self.windowService.focusOrRestore(target, self.cfg) then
    self.toast("Focus failed for YT window")
    return
  end

  sleepSeconds(self.cfg.inputDelay)
  sendKeyStrokes(self.cfg, keyPress, nil)

  if previousWindow and previousWindow:id() ~= target:id() then
    self.windowService.focusOrRestore(previousWindow, self.cfg)
  end
end

return YoutubeService
