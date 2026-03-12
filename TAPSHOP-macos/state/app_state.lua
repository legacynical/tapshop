local Workspace = require("state.workspace")
local configModule = require("config")

local AppState = {}
AppState.__index = AppState

local function clampOpacityPercent(value)
  if value < 40 then
    return 40
  end
  if value > 100 then
    return 100
  end
  return value
end

function AppState.new(cfg, deps)
  local self = setmetatable({
    cfg = cfg,
    settingsStore = deps.settingsStore,
    windowService = deps.windowService,
    youtubeService = deps.youtubeService,
    spotifyService = deps.spotifyService,
    toast = deps.toast,
    workspaces = {},
    popover = nil,
    debugWindow = nil,
  }, AppState)

  for i = 1, 9 do
    self.workspaces[#self.workspaces + 1] = Workspace.new("Window " .. tostring(i), cfg.minimizeThreshold)
  end

  return self
end

function AppState:attachUi(popover, debugWindow)
  self.popover = popover
  self.debugWindow = debugWindow
end

function AppState:getWorkspaces()
  return self.workspaces
end

function AppState:getConfig()
  return self.cfg
end

function AppState:getWindowInfo(win)
  return self.windowService.getWindowInfo(win)
end

function AppState:getYouTubeTargetId()
  return self.youtubeService:getTargetId()
end

function AppState:syncUi()
  if self.popover and self.popover.refreshCache then
    self.popover:refreshCache()
  elseif self.popover and self.popover.refreshIfShown then
    self.popover:refreshIfShown()
  end

  if self.debugWindow and self.debugWindow.syncVisibility then
    self.debugWindow:syncVisibility()
  end
end

function AppState:_runPairingAction(actionFn)
  actionFn()
  self:syncUi()
  if self.cfg.popoverAutoHideAfterAction and self.popover and self.popover.hide then
    self.popover:hide()
  end
end

function AppState:_getWorkspace(index)
  return self.workspaces[index]
end

function AppState:_refreshWorkspaceDisplayTitle(workspace, win)
  if not workspace then
    return
  end
  if not workspace.id then
    workspace:setDisplayTitle("[empty]")
    return
  end

  local target = win
  if not target or target:id() ~= workspace.id then
    target = self.windowService.getWindowById(workspace.id)
  end

  if target then
    workspace:setDisplayTitle(self.windowService.displayTitle(target))
  else
    workspace:setDisplayTitle("[empty]")
  end
end

function AppState:_refreshPairedWorkspaceTitlesForWindow(win)
  if not win then
    return
  end

  local id = win:id()
  if not id then
    return
  end

  local title = self.windowService.displayTitle(win)
  for _, workspace in ipairs(self.workspaces) do
    if workspace.id == id then
      workspace:setDisplayTitle(title)
    end
  end
end

function AppState:_pairWorkspace(workspace, windowId, win)
  workspace:pair(windowId, self.windowService.displayTitle(win))
end

function AppState:_formatPairToast(workspace, win)
  local info = self.windowService.getWindowInfo(win)
  if not info then
    return string.format("[Pairing %s]", workspace.label)
  end

  local title = info.title ~= "" and info.title or "[untitled]"
  local processName = info.processName ~= "" and info.processName
    or (info.appName ~= "" and info.appName or "[unknown]")
  local processLine = processName
  if info.pid then
    processLine = string.format("%s (pid:%s)", processLine, tostring(info.pid))
  end

  return string.format(
    "[Pairing %s]\ntitle: %s\nprocess: %s\nwindow id: %s",
    workspace.label,
    title,
    processLine,
    tostring(info.id)
  )
end

function AppState:_clearWorkspace(workspace)
  workspace:clear()
end

function AppState:pairSlot(index, sourceWindow)
  local workspace = self:_getWorkspace(index)
  if not workspace then
    return
  end

  local win = sourceWindow
  if not win then
    self.toast("No window to pair!")
    return
  end

  self:_runPairingAction(function()
    self:_pairWorkspace(workspace, win:id(), win)
    self.toast(self:_formatPairToast(workspace, win), 2.0)
  end)
end

function AppState:activateSlot(index)
  local workspace = self:_getWorkspace(index)
  if not workspace then
    return
  end

  self:_runPairingAction(function()
    local win = hs.window.frontmostWindow()
    if not win then
      self.toast("No active window found!")
      return
    end

    local currentId = win:id()
    if not workspace:isPaired() then
      self:_pairWorkspace(workspace, currentId, win)
      self.toast(self:_formatPairToast(workspace, win), 2.0)
      return
    end

    if currentId ~= workspace.id then
      local paired = self.windowService.getWindowById(workspace.id)
      if paired then
        workspace:resetInputBuffer()
        self.windowService.focusOrRestore(paired, self.cfg)
        self:_refreshWorkspaceDisplayTitle(workspace, paired)
      else
        self:_clearWorkspace(workspace)
        self.toast("[Paired window missing; cleared]")
      end
      return
    end

    local paired = self.windowService.getWindowById(workspace.id)
    workspace:consumeRepeatPress()
    if paired and workspace:shouldMinimize() then
      workspace:resetInputBuffer()
      paired:minimize()
    end
  end)
end

function AppState:unpairSlot(index)
  local workspace = self:_getWorkspace(index)
  if not workspace then
    return
  end

  self:_runPairingAction(function()
    if workspace:isPaired() then
      self:_clearWorkspace(workspace)
      self.toast("[Unpaired " .. workspace.label .. "]")
    else
      self.toast(workspace.label .. " is already unpaired!")
    end
  end)
end

function AppState:unpairAll()
  self:_runPairingAction(function()
    for _, workspace in ipairs(self.workspaces) do
      self:_clearWorkspace(workspace)
    end
    self.toast("[Unpaired All Windows]")
  end)
end

function AppState:togglePopover()
  if self.popover and self.popover.toggle then
    self.popover:toggle()
  end
end

function AppState:setPopoverAutoHide(enabled)
  self.cfg.popoverAutoHideAfterAction = enabled == true
  self.settingsStore.setBoolean(configModule.keys.popoverAutoHideAfterAction, self.cfg.popoverAutoHideAfterAction)
  self:syncUi()
end

function AppState:setPopoverAlwaysOnTop(enabled)
  self.cfg.popoverAlwaysOnTop = enabled == true
  self.settingsStore.setBoolean(configModule.keys.popoverAlwaysOnTop, self.cfg.popoverAlwaysOnTop)
  self:syncUi()
end

function AppState:setPopoverOpacity(opacity)
  local nextOpacity = opacity
  if opacity > 1 then
    local clampedPercent = clampOpacityPercent(math.floor(opacity / 10 + 0.5) * 10)
    nextOpacity = clampedPercent / 100
  end
  self.cfg.popoverBackgroundOpacity = self.settingsStore.setOpacity(
    configModule.keys.popoverBackgroundOpacity,
    nextOpacity
  )
  self:syncUi()
end

function AppState:setDebugWindow(enabled)
  self.cfg.popoverDebugWindow = enabled == true
  self.settingsStore.setBoolean(configModule.keys.popoverDebugWindow, self.cfg.popoverDebugWindow)
  self:syncUi()
end

function AppState:handleWindowEvent(event, win)
  if event == hs.window.filter.windowDestroyed then
    if not win then
      return
    end

    local deadId = win:id()
    self.youtubeService:handleDestroyedWindowId(deadId)

    local changed = false
    for _, workspace in ipairs(self.workspaces) do
      if workspace.id == deadId then
        self:_clearWorkspace(workspace)
        changed = true
      end
    end

    if changed then
      self.toast("[Cleared pairing: window closed]")
      self:syncUi()
    end
    return
  end

  self:_refreshPairedWorkspaceTitlesForWindow(win)
  self.youtubeService:handleWindowCandidate(win)
  if self.cfg.popoverDebugWindow and self.debugWindow and self.debugWindow.refreshIfShown then
    self.debugWindow:refreshIfShown()
  end
end

function AppState:handleActiveWindowChange(win)
  if self.popover and self.popover.updateActiveWindow then
    self.popover:updateActiveWindow(win)
  end
  if self.cfg.popoverDebugWindow and self.debugWindow and self.debugWindow.refreshIfShown then
    self.debugWindow:refreshIfShown()
  end
end

function AppState:handlePopoverAction(body)
  local action = body.action
  if action == "pair" then
    local slot = tonumber(body.slot) or 0
    if slot >= 1 and slot <= 9 then
      self:pairSlot(slot, body.sourceWindow)
    end
    return
  end
  if action == "unpair" then
    local slot = tonumber(body.slot) or 0
    if slot >= 1 and slot <= 9 then
      self:unpairSlot(slot)
    end
    return
  end
  if action == "unpairAll" then
    self:unpairAll()
    return
  end
  if action == "setAutoHideAfterAction" then
    self:setPopoverAutoHide(tonumber(body.slot) == 1)
    return
  end
  if action == "setAlwaysOnTop" then
    self:setPopoverAlwaysOnTop(tonumber(body.slot) == 1)
    return
  end
  if action == "setPopoverOpacity" then
    local rawPercent = tonumber(body.slot)
    if rawPercent then
      self:setPopoverOpacity(rawPercent)
    end
    return
  end
  if action == "setDebugWindow" then
    self:setDebugWindow(tonumber(body.slot) == 1)
  end
end

function AppState:sendYoutubeCommand(keyPress)
  self.youtubeService:sendCommand(keyPress)
end

function AppState:spotifyPrevious()
  self.spotifyService:previous()
end

function AppState:spotifyNext()
  self.spotifyService:next()
end

function AppState:spotifyPlayPause()
  self.spotifyService:playPause()
end

function AppState:spotifySeekBack(seconds)
  self.spotifyService:seekBack(seconds)
end

function AppState:spotifySeekForward(seconds)
  self.spotifyService:seekForward(seconds)
end

function AppState:spotifyVolumeDown(step)
  self.spotifyService:volumeDown(step)
end

function AppState:spotifyVolumeUp(step)
  self.spotifyService:volumeUp(step)
end

function AppState:spotifyToggleLike()
  self.spotifyService:toggleLike()
end

function AppState:toggleSystemMute()
  self.spotifyService:toggleSystemMute()
end

function AppState:adjustSystemVolume(delta)
  local dev = hs.audiodevice.defaultOutputDevice()
  if dev then
    local base = dev:volume() or 25
    if delta < 0 then
      dev:setVolume(math.max(0, base + delta))
    else
      dev:setVolume(math.min(100, base + delta))
    end
  end
end

return AppState
