local Workspace = require("state.workspace")
local configModule = require("config")

local AppState = {}
AppState.__index = AppState
local PAIR_TOAST_COLOR = { red = 0x7e / 255, green = 0xc8 / 255, blue = 0x7e / 255, alpha = 1 }
local UNPAIR_TOAST_COLOR = { red = 0xc0 / 255, green = 0x40 / 255, blue = 0x30 / 255, alpha = 1 }
local TOAST_WHITE = { white = 1, alpha = 1 }
local DEBUG_STATE_KEYS = {
  "lastAction",
  "lastSlot",
  "lastFocusResult",
  "lastPairingMutation",
  "lastYoutubeAction",
}

local function elapsedMs(startedAt)
  return (hs.timer.absoluteTime() - startedAt) / 1e6
end

local function debugLog(cfg, fmt, ...)
  if cfg and cfg.isGuiDebugMode then
    hs.printf("[tapshop-perf] " .. fmt, ...)
  end
end

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
    debugState = {
      lastAction = nil,
      lastSlot = nil,
      lastFocusResult = nil,
      lastPairingMutation = nil,
      lastYoutubeAction = nil,
    },
  }, AppState)

  for i = 1, 9 do
    self.workspaces[#self.workspaces + 1] = Workspace.new("Window " .. tostring(i), cfg.minimizeThreshold)
  end

  self:_restoreWorkspacePairings()
  self:_persistWorkspacePairings()

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

function AppState:getDebugState()
  return self.debugState
end

function AppState:getWindowInfo(win)
  return self.windowService.getWindowInfo(win)
end

function AppState:getYouTubeTargetId()
  return self.youtubeService:getTargetId()
end

function AppState:_recordDebugAction(fields)
  if type(fields) ~= "table" then
    return
  end

  for _, key in ipairs(DEBUG_STATE_KEYS) do
    if fields[key] ~= nil then
      self.debugState[key] = fields[key]
    end
  end

  if self.cfg.popoverDebugWindow and self.debugWindow and self.debugWindow.refreshIfShown then
    self.debugWindow:refreshIfShown()
  end
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
  self:_persistWorkspacePairings()
  self:syncUi()
  if self.cfg.popoverAutoHideAfterAction and self.popover and self.popover.hide then
    self.popover:hide()
  end
end

function AppState:_getWorkspace(index)
  return self.workspaces[index]
end

function AppState:_resolvePairedWindow(workspace)
  if not workspace or not workspace.id then
    return nil
  end
  return self.windowService.getWindowById(workspace.id)
end

function AppState:_workspacePairingSnapshot()
  local pairings = {}
  for index, workspace in ipairs(self.workspaces) do
    if workspace then
      local hasMetadata = workspace.bundleID
        or workspace.appName
        or workspace.titleRaw
        or workspace.titleNormalized
        or workspace.displayTitle ~= "[empty]"
        or workspace.closedAt
      if workspace.id or hasMetadata then
        pairings[index] = {
          windowId = workspace.id,
          bundleID = workspace.bundleID,
          appName = workspace.appName,
          titleRaw = workspace.titleRaw,
          titleNormalized = workspace.titleNormalized,
          displayTitle = workspace.displayTitle,
          closedAt = workspace.closedAt,
        }
      end
    end
  end
  return pairings
end

function AppState:_persistWorkspacePairings()
  self.settingsStore.setWindowPairings(
    configModule.keys.workspacePairings,
    self:_workspacePairingSnapshot()
  )
end

function AppState:_restoreWorkspacePairings()
  local pairings = self.settingsStore.getWindowPairings(configModule.keys.workspacePairings)
  for index, persisted in pairs(pairings) do
    local workspace = self:_getWorkspace(index)
    if workspace then
      if type(persisted) == "number" then
        local win = self.windowService.getWindowById(persisted)
        if win then
          self:_pairWorkspace(workspace, persisted, win)
        end
      elseif type(persisted) == "table" then
        local windowId = persisted.windowId
        local win = self.windowService.getWindowById(windowId)
        if win then
          self:_pairWorkspace(workspace, windowId, win)
        else
          workspace:pairWithMetadata(nil, "[empty]", {
            bundleID = persisted.bundleID,
            appName = persisted.appName,
            titleRaw = persisted.titleRaw,
            titleNormalized = persisted.titleNormalized,
          })
          workspace:setDisplayTitle("[empty]")
          workspace:clearRecoveryTracking()
        end
      end
    end
  end
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
    return false
  end

  local id = win:id()
  if not id then
    return false
  end

  local title = self.windowService.displayTitle(win)
  local matchedWorkspace = false
  for _, workspace in ipairs(self.workspaces) do
    if workspace.id == id then
      matchedWorkspace = true
      workspace:setDisplayTitle(title)
    end
  end

  return matchedWorkspace
end

function AppState:_pairWorkspace(workspace, windowId, win)
  workspace:pairWithMetadata(windowId, self.windowService.displayTitle(win), self.windowService.pairingMetadata(win))
end

function AppState:_slotIndexForWorkspace(workspace)
  for index, candidate in ipairs(self.workspaces) do
    if candidate == workspace then
      return index
    end
  end
  return nil
end

function AppState:_isWindowAlreadyPaired(windowId)
  for _, workspace in ipairs(self.workspaces) do
    if workspace.id == windowId then
      return true
    end
  end
  return false
end

function AppState:_expireRecoveryTracking(now)
  local changed = false
  for _, workspace in ipairs(self.workspaces) do
    if workspace.closedAt and not workspace:canRecover(now, self.cfg.relaunchRecoveryTimeout) then
      workspace:clearRecoveryTracking()
      changed = true
    end
  end
  if changed then
    self:_persistWorkspacePairings()
  end
  return changed
end

function AppState:_restoreWorkspaceFromCandidate(win, now)
  if not self.windowService.isCandidateWindow or not self.windowService.isCandidateWindow(win) then
    return false
  end

  local candidateMeta = self.windowService.pairingMetadata(win)
  local candidateId = win:id()
  if not candidateMeta or not candidateId or self:_isWindowAlreadyPaired(candidateId) then
    return false
  end

  for _, workspace in ipairs(self.workspaces) do
    if workspace:canRecover(now, self.cfg.relaunchRecoveryTimeout)
      and workspace:matchesRecoveryCandidate(candidateMeta) then
      self:_pairWorkspace(workspace, candidateId, win)
      self:_persistWorkspacePairings()
      self.toast({
        segments = {
          { text = string.format("Restored %s: ", workspace.label), color = TOAST_WHITE },
          { text = candidateMeta.displayTitle or "[empty]", color = PAIR_TOAST_COLOR },
        },
      }, 2.0)
      self:_recordDebugAction({
        lastAction = "window_restored",
        lastSlot = self:_slotIndexForWorkspace(workspace),
        lastPairingMutation = "restore",
      })
      return true
    end
  end

  return false
end

function AppState:_formatPairToast(workspace, win)
  local label = self.windowService.displayTitle(win)
  if label == "[empty]" then
    return string.format("[Pairing %s]", workspace.label)
  end
  return {
    segments = {
      { text = string.format("Pairing %s: ", workspace.label), color = TOAST_WHITE },
      { text = label, color = PAIR_TOAST_COLOR },
    },
  }
end

function AppState:_formatUnpairToast(workspace, win)
  local label = self.windowService.displayTitle(win)
  if label == "[empty]" then
    label = workspace.displayTitle or "[empty]"
  end
  return {
    segments = {
      { text = string.format("Unpairing %s: ", workspace.label), color = TOAST_WHITE },
      { text = label, color = UNPAIR_TOAST_COLOR },
    },
  }
end

function AppState:_clearWorkspace(workspace)
  workspace:clear()
end

function AppState:_clearWorkspaceAndPersist(workspace)
  if not workspace then
    return
  end
  self:_clearWorkspace(workspace)
  self:_persistWorkspacePairings()
end

function AppState:_handleMissingPairedWindow(workspace, toastMessage)
  self:_clearWorkspaceAndPersist(workspace)
  if toastMessage then
    self.toast(toastMessage)
  end
  return "cleared_missing_paired_window"
end

function AppState:pairSlot(index, sourceWindow)
  local workspace = self:_getWorkspace(index)
  if not workspace then
    return
  end

  local win = sourceWindow
  if not win then
    self.toast("No window to pair!")
    self:_recordDebugAction({
      lastAction = "pair_slot_missing_window",
      lastSlot = index,
    })
    return
  end

  self:_runPairingAction(function()
    self:_pairWorkspace(workspace, win:id(), win)
    self.toast(self:_formatPairToast(workspace, win), 2.0)
  end)
  self:_recordDebugAction({
    lastAction = "pair_slot",
    lastSlot = index,
    lastPairingMutation = "pair",
  })
end

function AppState:activateSlot(index)
  local startedAt = hs.timer.absoluteTime()
  local workspace = self:_getWorkspace(index)
  if not workspace then
    local result = "missing_workspace"
    self:_recordDebugAction({
      lastAction = result,
      lastSlot = index,
    })
    debugLog(self.cfg, "activateSlot slot=%d result=%s durationMs=%.2f", index, result, elapsedMs(startedAt))
    return
  end

  local result = "noop"
  local focusCode = nil
  local pairingMutation = nil

  self:_runPairingAction(function()
    local win = hs.window.frontmostWindow()
    if not win then
      self.toast("No active window found!")
      result = "no_frontmost_window"
      return
    end

    local currentId = win:id()
    if not workspace:isPaired() then
      self:_pairWorkspace(workspace, currentId, win)
      self.toast(self:_formatPairToast(workspace, win), 2.0)
      result = "paired_current_window"
      pairingMutation = "pair"
      return
    end

    if currentId ~= workspace.id then
      local paired = self:_resolvePairedWindow(workspace)
      if paired then
        workspace:resetInputBuffer()
        local focusResult = self.windowService.focusOrRestoreFast(paired, self.cfg)
        focusCode = focusResult.code
        self:_refreshWorkspaceDisplayTitle(workspace, paired)
        result = focusResult.code
      else
        result = self:_handleMissingPairedWindow(workspace, "[Paired window missing; cleared]")
        pairingMutation = "clear_missing"
      end
      return
    end

    local paired = self:_resolvePairedWindow(workspace) or win
    workspace:consumeRepeatPress()
    if paired and workspace:shouldMinimize() then
      workspace:resetInputBuffer()
      paired:minimize()
      result = "minimized_paired_window"
      return
    end

    result = "repeat_press_buffered"
  end)

  self:_recordDebugAction({
    lastAction = result,
    lastSlot = index,
    lastFocusResult = focusCode,
    lastPairingMutation = pairingMutation,
  })
  debugLog(self.cfg, "activateSlot slot=%d result=%s durationMs=%.2f", index, result, elapsedMs(startedAt))
end

function AppState:unpairSlot(index)
  local workspace = self:_getWorkspace(index)
  if not workspace then
    return
  end

  local didUnpair = false
  self:_runPairingAction(function()
    if workspace:isPaired() then
      local win = self:_resolvePairedWindow(workspace)
      local toastPayload = self:_formatUnpairToast(workspace, win)
      self:_clearWorkspace(workspace)
      self.toast(toastPayload)
      didUnpair = true
    else
      self.toast(workspace.label .. " is already unpaired!")
    end
  end)
  self:_recordDebugAction({
    lastAction = didUnpair and "unpair_slot" or "unpair_slot_noop",
    lastSlot = index,
    lastPairingMutation = didUnpair and "unpair" or nil,
  })
end

function AppState:unpairAll()
  self:_runPairingAction(function()
    for _, workspace in ipairs(self.workspaces) do
      self:_clearWorkspace(workspace)
    end
    self.toast("[Unpaired All Windows]")
  end)
  self:_recordDebugAction({
    lastAction = "unpair_all",
    lastPairingMutation = "unpair_all",
  })
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
    local firstChangedSlot = nil
    for _, workspace in ipairs(self.workspaces) do
      if workspace.id == deadId then
        if not firstChangedSlot then
          firstChangedSlot = self:_slotIndexForWorkspace(workspace)
        end
        workspace:markClosedForRecovery(hs.timer.secondsSinceEpoch())
        changed = true
      end
    end

    if changed then
      self:_persistWorkspacePairings()
      self:_recordDebugAction({
        lastAction = "window_destroyed",
        lastSlot = firstChangedSlot,
        lastPairingMutation = "clear_destroyed",
      })
      self.toast("[Cleared pairing: window closed]")
      self:syncUi()
    end
    return
  end

  local now = hs.timer.secondsSinceEpoch()
  local recoveryStateChanged = self:_expireRecoveryTracking(now)
  local restored = false
  if win then
    restored = self:_restoreWorkspaceFromCandidate(win, now)
  end

  local pairedWorkspaceTouched = self:_refreshPairedWorkspaceTitlesForWindow(win)
  self.youtubeService:handleWindowCandidate(win)

  local shouldRefreshPopover = event == hs.window.filter.windowFocused or pairedWorkspaceTouched or recoveryStateChanged or restored
  if win then
    local frontmost = hs.window.frontmostWindow()
    if frontmost and frontmost:id() == win:id() then
      shouldRefreshPopover = true
    end
  end

  if shouldRefreshPopover and self.popover and self.popover.requestRefresh then
    self.popover:requestRefresh("window_event")
  end

  if self.cfg.popoverDebugWindow and self.debugWindow and self.debugWindow.refreshIfShown then
    self.debugWindow:refreshIfShown()
  end
end

function AppState:handleActiveWindowChange(win)
  if self.popover and self.popover.requestActiveWindowUpdate then
    self.popover:requestActiveWindowUpdate(win)
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
  local result = self.youtubeService:sendCommand(keyPress)
  if result then
    self:_recordDebugAction({
      lastAction = "youtube_command",
      lastFocusResult = result.focusResult,
      lastYoutubeAction = result.code,
    })
  end
  return result
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
