local Workspace = require("state.workspace")
local configModule = require("config")
local Utils = require("utils")

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
  "lastActivationPath",
}

local elapsedMs = Utils.elapsedMs
local debugLog = Utils.debugLog

function AppState.new(cfg, deps)
  local self = setmetatable({
    cfg = cfg,
    settingsStore = deps.settingsStore,
    windowService = deps.windowService,
    youtubeService = deps.youtubeService,
    spotifyService = deps.spotifyService,
    systemAudioService = deps.systemAudioService,
    toast = deps.toast,
    workspaces = {},
    hotkeyManager = nil,
    popover = nil,
    debugWindow = nil,
    debugState = {
      lastAction = nil,
      lastSlot = nil,
      lastFocusResult = nil,
      lastPairingMutation = nil,
      lastYoutubeAction = nil,
      lastActivationPath = nil,
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

function AppState:attachHotkeyManager(hotkeyManager)
  self.hotkeyManager = hotkeyManager
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

function AppState:getWorkspaceRowModels()
  local function persistedWindowTitle(workspace)
    if workspace.titleRaw and workspace.titleRaw:match("%S") then
      return workspace.titleRaw
    end

    local displayTitle = workspace.displayTitle or ""
    local parsedTitle = displayTitle:match("^%b[]%s+(.*)$")
    if parsedTitle and parsedTitle:match("%S") then
      return parsedTitle
    end

    if displayTitle:match("%S") then
      return displayTitle
    end

    return "[empty]"
  end

  local rows = {}
  for index, workspace in ipairs(self.workspaces) do
    local isPaired = workspace:isPaired()
    local statusKind = "unpaired"
    local className = "unpaired"
    local label = "[empty]"
    local isMinimized = false
    local activationMode = "unresolved"
    local bundleID = workspace.bundleID
    local appName = workspace.appName

    if isPaired then
      local pairedWin = self.windowService.getWindowById(workspace.id)
      if pairedWin then
        local app = pairedWin:application()
        isMinimized = pairedWin:isMinimized()
        label = (self.windowService.windowTitle and self.windowService.windowTitle(pairedWin))
          or self.windowService.displayTitle(pairedWin)
        bundleID = app and app:bundleID() or bundleID
        appName = app and app:name() or appName
        if isMinimized then
          statusKind = "paired_minimized"
          className = "paired-minimized"
        else
          statusKind = "paired_main"
          className = "paired"
        end
        activationMode = "base_window"
      elseif workspace:hasTrackedFullscreenTarget() then
        local fullscreenWin = self.windowService.getWindowById(workspace.fullscreenWindowId)
        if fullscreenWin then
          local app = fullscreenWin:application()
          label = self.windowService.windowTitle(fullscreenWin) .. " [fullscreen]"
          bundleID = app and app:bundleID() or bundleID
          appName = app and app:name() or appName
          statusKind = "paired_fullscreen"
          className = "paired-fullscreen"
          activationMode = "fullscreen_window"
        else
          statusKind = "paired_unresolved"
          className = "paired-unresolved"
          label = persistedWindowTitle(workspace)
        end
      else
        statusKind = "paired_unresolved"
        className = "paired-unresolved"
        label = persistedWindowTitle(workspace)
      end
    end

    rows[#rows + 1] = {
      index = index,
      label = label,
      className = className,
      isMinimized = isMinimized,
      canUnpair = isPaired,
      bundleID = bundleID,
      appName = appName,
      statusKind = statusKind,
      activationMode = activationMode,
      fingerprint = tostring(index) .. "|" .. label,
    }
  end
  return rows
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

  if self.cfg.isDebugMode and self.debugWindow and self.debugWindow.refreshIfShown then
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

function AppState:_runWorkspaceAction(actionFn)
  actionFn()
  self:_persistWorkspacePairings()
  self:syncUi()
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

function AppState:_windowTitleMatchesWorkspace(workspace, win)
  if not workspace or not win then
    return false
  end

  local meta = self.windowService.pairingMetadata and self.windowService.pairingMetadata(win)
  if not meta then
    return false
  end

  if workspace.bundleID and meta.bundleID and workspace.bundleID ~= meta.bundleID then
    return false
  end

  if workspace.titleNormalized and meta.titleNormalized and workspace.titleNormalized ~= meta.titleNormalized then
    return false
  end

  return true
end

function AppState:_findFullscreenCompanion(workspace, sourceWin, fullscreenSpaceId)
  if not workspace or not sourceWin or not fullscreenSpaceId then
    return nil
  end
  if not self.windowService.candidateWindows then
    return nil
  end

  local sourceId = sourceWin:id()
  for _, candidate in ipairs(self.windowService:candidateWindows()) do
    if candidate and candidate:id() ~= sourceId
      and self.windowService.isWindowFullscreen(candidate)
      and self.windowService.windowIsInSpace(candidate, fullscreenSpaceId)
      and self:_windowTitleMatchesWorkspace(workspace, candidate) then
      return candidate
    end
  end

  return nil
end

function AppState:_resolveFullscreenTargetForActivation(workspace)
  if not workspace or not workspace:hasTrackedFullscreenTarget() then
    return nil
  end

  local tracked = self.windowService.getWindowById(workspace.fullscreenWindowId)
  if tracked then
    return tracked
  end

  if not workspace.fullscreenSpaceId then
    return nil
  end

  local bestEffort = self.windowService.bestEffortFrontmostWindowInSpace
    and self.windowService.bestEffortFrontmostWindowInSpace(workspace.fullscreenSpaceId)
    or nil
  if bestEffort and self:_windowTitleMatchesWorkspace(workspace, bestEffort) then
    return bestEffort
  end

  return nil
end

function AppState:_workspacePairingSnapshot()
  local pairings = {}
  for index, workspace in ipairs(self.workspaces) do
    if workspace then
      local record = Utils.extractPairingRecord({
        windowId = workspace.id,
        bundleID = workspace.bundleID,
        appName = workspace.appName,
        titleRaw = workspace.titleRaw,
        titleNormalized = workspace.titleNormalized,
        displayTitle = workspace.displayTitle ~= "[empty]" and workspace.displayTitle or nil,
        closedAt = workspace.closedAt,
      })
      if record then
        pairings[index] = record
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
  local restoredCount = 0
  for index, persisted in pairs(pairings) do
    local workspace = self:_getWorkspace(index)
    if workspace then
      if type(persisted) == "table" then
        local windowId = persisted.windowId
        local win = self.windowService.getWindowById(windowId)
        if win then
          self:_pairWorkspace(workspace, windowId, win)
          restoredCount = restoredCount + 1
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
  return restoredCount
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
  workspace:clearFullscreenState()
  local spaceId = self:_updateWorkspaceRuntimeSpaceState(
    workspace,
    win,
    self.windowService.isWindowFullscreen(win)
  )
  if workspace.fullscreenActive == true then
    workspace:setFullscreenState({
      fullscreenWindowId = win:id(),
      fullscreenSpaceId = spaceId,
      lastKnownSpaceId = spaceId,
    })
  end
end

function AppState:_slotIndexForWorkspace(workspace)
  for index, candidate in ipairs(self.workspaces) do
    if candidate == workspace then
      return index
    end
  end
  return nil
end

function AppState:_updateWorkspaceRuntimeSpaceState(workspace, win, isFullscreen)
  if not workspace or not win then
    return nil
  end

  local spaceId = self.windowService.getPrimarySpaceForWindow(win)
  workspace.lastKnownSpaceId = spaceId
  workspace.fullscreenActive = isFullscreen == true
  return spaceId
end

function AppState:_resolvedTargetSpaceForWindow(win, focusedSpaceId)
  if not win or not self.windowService.getWindowSpaces then
    return nil
  end

  local spaceIds = self.windowService.getWindowSpaces(win)
  return self:_resolvedTargetSpaceFromSpaceIds(spaceIds, focusedSpaceId)
end

function AppState:_resolvedTargetSpaceFromSpaceIds(spaceIds, focusedSpaceId)
  if type(spaceIds) ~= "table" or #spaceIds == 0 then
    return nil, false, nil
  end

  local primarySpaceId = nil
  for _, spaceId in ipairs(spaceIds) do
    if not primarySpaceId then
      primarySpaceId = spaceId
    end
    if self.windowService.isFullscreenSpace
      and self.windowService.isFullscreenSpace(spaceId) then
      primarySpaceId = spaceId
      break
    end
  end

  if focusedSpaceId ~= nil then
    for _, spaceId in ipairs(spaceIds) do
      if spaceId == focusedSpaceId then
        return nil, true, primarySpaceId or focusedSpaceId
      end
    end
  end

  return primarySpaceId, false, primarySpaceId
end

function AppState:_activateResolvedPairedWindow(workspace, paired, focusedSpaceId)
  if not workspace or not paired then
    return nil
  end

  local shouldInspectSpaces = workspace.lastKnownSpaceId ~= nil
    and focusedSpaceId ~= nil
    and workspace.lastKnownSpaceId ~= focusedSpaceId

  if shouldInspectSpaces then
    local targetSpaceId, inFocusedSpace, resolvedSpaceId = self:_resolvedTargetSpaceForWindow(paired, focusedSpaceId)
    if inFocusedSpace then
      if resolvedSpaceId then
        workspace.lastKnownSpaceId = resolvedSpaceId
      end
      self:_refreshWorkspaceDisplayTitle(workspace, paired)
      local focusResult = self.windowService.focusOrRestoreFast(paired, self.cfg)
      return {
        focusCode = focusResult.code,
        result = focusResult.code,
        activationPath = "base-window",
      }
    end

    if targetSpaceId then
      local switchResult = self.windowService.gotoSpace(targetSpaceId, self.cfg)
      if switchResult.ok then
        workspace.lastKnownSpaceId = targetSpaceId
        self:_refreshWorkspaceDisplayTitle(workspace, paired)
        local focusResult = self.windowService.focusWindowAfterSpaceSwitch(paired, self.cfg)
        return {
          focusCode = focusResult.code,
          result = focusResult.code,
          activationPath = "base-window-space-switch",
        }
      end

      return {
        focusCode = nil,
        result = switchResult.code or "space_switch_failed",
        activationPath = "base-window-space-switch-failed",
      }
    end
  end

  self:_refreshWorkspaceDisplayTitle(workspace, paired)
  local focusResult = self.windowService.focusOrRestoreFast(paired, self.cfg)
  return {
    focusCode = focusResult.code,
    result = focusResult.code,
    activationPath = "base-window",
  }
end

function AppState:_activateExactWindowIdAcrossSpaces(workspace, focusedSpaceId)
  if not workspace or not workspace.id then
    return nil
  end

  if workspace.lastKnownSpaceId == nil or workspace.lastKnownSpaceId == focusedSpaceId then
    return nil
  end

  if not self.windowService.getWindowSpacesById then
    return nil
  end

  local spaceIds = self.windowService.getWindowSpacesById(workspace.id)
  local targetSpaceId, inFocusedSpace = self:_resolvedTargetSpaceFromSpaceIds(spaceIds, focusedSpaceId)
  if inFocusedSpace or not targetSpaceId then
    return nil
  end

  local switchResult = self.windowService.gotoSpace(targetSpaceId, self.cfg)
  if not switchResult.ok then
    return nil
  end

  local resolved = self:_resolvePairedWindow(workspace)
  if not resolved then
    return nil
  end

  self:_updateWorkspaceRuntimeSpaceState(
    workspace,
    resolved,
    self.windowService.isWindowFullscreen(resolved)
  )
  workspace.lastKnownSpaceId = targetSpaceId
  self:_refreshWorkspaceDisplayTitle(workspace, resolved)
  local focusResult = self.windowService.focusWindowAfterSpaceSwitch(resolved, self.cfg)
  return {
    focusCode = focusResult.code,
    result = focusResult.code,
    activationPath = "base-window-id-space-switch",
  }
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

function AppState:_clearWorkspaceAndPersist(workspace)
  if not workspace then
    return
  end
  workspace:clear()
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
  local activationPath = nil

  self:_runWorkspaceAction(function()
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
        local focusedSpaceId = self.windowService.focusedSpaceId and self.windowService.focusedSpaceId() or nil
        local activation = self:_activateResolvedPairedWindow(workspace, paired, focusedSpaceId)
        focusCode = activation and activation.focusCode or nil
        result = activation and activation.result or "focus_requested"
        activationPath = activation and activation.activationPath or "base-window"
      elseif workspace:hasTrackedFullscreenTarget() then
        local switchResult = self.windowService.gotoSpace(workspace.fullscreenSpaceId, self.cfg)
        if not switchResult.ok then
          result = switchResult.code or "space_switch_failed"
          activationPath = "fullscreen-space-switch-failed"
        else
          local fullscreenWin = self:_resolveFullscreenTargetForActivation(workspace)
          if fullscreenWin then
            workspace:setFullscreenState({
              fullscreenWindowId = fullscreenWin:id(),
              fullscreenSpaceId = workspace.fullscreenSpaceId,
              lastKnownSpaceId = workspace.fullscreenSpaceId,
            })
            self.windowService.focusWindowAfterSpaceSwitch(fullscreenWin, self.cfg)
            self:_refreshWorkspaceDisplayTitle(workspace, fullscreenWin)
            result = "focus_scheduled_after_space_switch"
            activationPath = "fullscreen-space-switch"
          else
            result = "paired_window_unresolved"
            activationPath = "fullscreen-target-unresolved"
          end
        end
      else
        local focusedSpaceId = self.windowService.focusedSpaceId and self.windowService.focusedSpaceId() or nil
        local activation = self:_activateExactWindowIdAcrossSpaces(workspace, focusedSpaceId)
        if activation then
          focusCode = activation.focusCode
          result = activation.result
          activationPath = activation.activationPath
        else
          self.toast("Window not found in any spaces")
          result = "paired_window_unresolved"
          activationPath = "unresolved"
        end
      end
      return
    end

    if workspace:hasTrackedFullscreenTarget() and self.windowService.isWindowFullscreen(win) then
      result = "already_frontmost_fullscreen"
      activationPath = "fullscreen-repeat"
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
    lastActivationPath = activationPath,
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
      workspace:clear()
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
      workspace:clear()
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

function AppState:showPopover()
  if self.popover and self.popover.show then
    self.popover:show()
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
  local normalized = opacity > 1 and (opacity / 100) or opacity
  self.cfg.popoverBackgroundOpacity = self.settingsStore.setOpacity(
    configModule.keys.popoverBackgroundOpacity,
    normalized
  )
  self:syncUi()
end

function AppState:setDebugMode(enabled)
  self.cfg.isDebugMode = enabled == true
  self.settingsStore.setBoolean(configModule.keys.debugMode, self.cfg.isDebugMode)
  self:syncUi()
end

function AppState:getHotkeyUiState()
  if not self.hotkeyManager or not self.hotkeyManager.getUiState then
    return {
      rows = {},
      conflictsById = {},
      overrides = {},
      recordingSupported = false,
    }
  end
  return self.hotkeyManager:getUiState()
end

function AppState:warmHotkeyUiCache(rendererFn)
  if not self.hotkeyManager then
    return
  end
  if self.hotkeyManager.warmUiState then
    self.hotkeyManager:warmUiState()
  end
  if rendererFn and self.hotkeyManager.warmHtml then
    self.hotkeyManager:warmHtml(rendererFn)
  end
end

function AppState:updateHotkeyBinding(id, payload)
  if not self.hotkeyManager or not self.hotkeyManager.updateBinding then
    return {
      ok = false,
      code = "missing_manager",
      ids = {
        [tostring(id or "")] = {},
      },
      message = "Hotkey manager unavailable.",
    }
  end

  local result = self.hotkeyManager:updateBinding(id, payload or {})
  return result
end

function AppState:resetHotkeyBinding(id)
  if not self.hotkeyManager or not self.hotkeyManager.resetBinding then
    return {
      ok = false,
      code = "missing_manager",
      ids = {
        [tostring(id or "")] = {},
      },
      message = "Hotkey manager unavailable.",
    }
  end

  local result = self.hotkeyManager:resetBinding(id)
  return result
end

function AppState:resetAllHotkeys()
  if not self.hotkeyManager or not self.hotkeyManager.resetAll then
    return {
      ok = false,
      code = "missing_manager",
      message = "Hotkey manager unavailable.",
    }
  end

  local result = self.hotkeyManager:resetAll()
  return result
end

function AppState:handleWindowEvent(event, win)
  if event == hs.window.filter.windowDestroyed then
    if not win then
      return
    end

    local deadId = win:id()
    self.youtubeService:handleDestroyedWindowId(deadId)

    local basePairingChanged = false
    local fullscreenStateChanged = false
    local firstChangedSlot = nil
    for _, workspace in ipairs(self.workspaces) do
      if workspace.fullscreenWindowId == deadId and workspace.id ~= deadId then
        workspace:clearFullscreenState()
        fullscreenStateChanged = true
      end
      if workspace.id == deadId then
        if workspace:hasTrackedFullscreenTarget()
          and workspace.fullscreenWindowId == deadId
          and self.windowService.isWindowFullscreen(win) then
          workspace:clearFullscreenState()
          fullscreenStateChanged = true
          goto continue_window_destroy
        end
        if not firstChangedSlot then
          firstChangedSlot = self:_slotIndexForWorkspace(workspace)
        end
        workspace:markClosedForRecovery(hs.timer.secondsSinceEpoch())
        basePairingChanged = true
      end
      ::continue_window_destroy::
    end

    if basePairingChanged then
      self:_persistWorkspacePairings()
      self:_recordDebugAction({
        lastAction = "window_destroyed",
        lastSlot = firstChangedSlot,
        lastPairingMutation = "clear_destroyed",
      })
      self.toast("[Cleared pairing: window closed]")
      self:syncUi()
    elseif fullscreenStateChanged then
      self:syncUi()
    end
    return
  end

  if event == hs.window.filter.windowFullscreened then
    if not win then
      return
    end
    local winId = win:id()
    for _, workspace in ipairs(self.workspaces) do
      if workspace.id == winId then
        local spaceId = self:_updateWorkspaceRuntimeSpaceState(workspace, win, true)
        local fullscreenTarget = self:_findFullscreenCompanion(workspace, win, spaceId) or win
        workspace:setFullscreenState({
          fullscreenWindowId = fullscreenTarget:id(),
          fullscreenSpaceId = spaceId,
          lastKnownSpaceId = spaceId,
        })
      end
    end
    self:syncUi()
    return
  end

  if event == hs.window.filter.windowUnfullscreened then
    if not win then
      return
    end
    local winId = win:id()
    for _, workspace in ipairs(self.workspaces) do
      if workspace.fullscreenWindowId == winId then
        local spaceId = self:_updateWorkspaceRuntimeSpaceState(workspace, win, false)
        workspace:clearFullscreenState()
        workspace.lastKnownSpaceId = spaceId
        workspace.fullscreenActive = false
      elseif workspace.id == winId then
        local spaceId = self:_updateWorkspaceRuntimeSpaceState(workspace, win, false)
        workspace:clearFullscreenState()
        workspace.lastKnownSpaceId = spaceId
        workspace.fullscreenActive = false
      end
    end
    self:syncUi()
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

  if self.cfg.isDebugMode and self.debugWindow and self.debugWindow.refreshIfShown then
    self.debugWindow:refreshIfShown()
  end
end

function AppState:handleActiveWindowChange(win)
  if self.popover and self.popover.requestActiveWindowUpdate then
    self.popover:requestActiveWindowUpdate(win)
  end
  if self.cfg.isDebugMode and self.debugWindow and self.debugWindow.refreshIfShown then
    self.debugWindow:refreshIfShown()
  end
end

local POPOVER_ACTIONS = {}

local function slotAction(self, body, method)
  local slot = tonumber(body.slot) or 0
  if slot >= 1 and slot <= 9 then
    method(self, slot, body.sourceWindow)
  end
end

POPOVER_ACTIONS["pair"] = function(self, body)
  slotAction(self, body, self.pairSlot)
end

POPOVER_ACTIONS["unpair"] = function(self, body)
  slotAction(self, body, self.unpairSlot)
end

POPOVER_ACTIONS["unpairAll"] = function(self)
  self:unpairAll()
end

POPOVER_ACTIONS["setAutoHideAfterAction"] = function(self, body)
  self:setPopoverAutoHide(tonumber(body.slot) == 1)
end

POPOVER_ACTIONS["setAlwaysOnTop"] = function(self, body)
  self:setPopoverAlwaysOnTop(tonumber(body.slot) == 1)
end

POPOVER_ACTIONS["setPopoverOpacity"] = function(self, body)
  local rawPercent = tonumber(body.slot)
  if rawPercent then
    self:setPopoverOpacity(rawPercent)
  end
end

POPOVER_ACTIONS["setDebugMode"] = function(self, body)
  self:setDebugMode(tonumber(body.slot) == 1)
end

POPOVER_ACTIONS["updateHotkeyBinding"] = function(self, body)
  return self:updateHotkeyBinding(body.id, {
    mods = body.mods,
    key = body.key,
    enabled = body.enabled,
  })
end

POPOVER_ACTIONS["resetHotkeyBinding"] = function(self, body)
  return self:resetHotkeyBinding(body.id)
end

POPOVER_ACTIONS["resetAllHotkeys"] = function(self)
  return self:resetAllHotkeys()
end

function AppState:handlePopoverAction(body)
  local handler = POPOVER_ACTIONS[body.action]
  if handler then
    return handler(self, body)
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
  self.systemAudioService:toggleMute()
end

function AppState:adjustSystemVolume(delta)
  self.systemAudioService:adjustVolume(delta)
end

return AppState
