local Workspace = require("state.workspace")
local SlotRecord = require("state.slot_record")
local SlotRow = require("state.slot_row")
local configModule = require("config")
local ToastMessage = require("ui.toast_message")

local AppState = {}
AppState.__index = AppState
local PAIR_TOAST_COLOR = { red = 0x7e / 255, green = 0xc8 / 255, blue = 0x7e / 255, alpha = 1 }
local UNPAIR_TOAST_COLOR = { red = 0xc0 / 255, green = 0x40 / 255, blue = 0x30 / 255, alpha = 1 }
local TOAST_WHITE = { white = 1, alpha = 1 }

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
    session = {
      focusedSpaceId = nil,
    },
    hotkeyManager = nil,
    popover = nil,
    settingsWindow = nil,
  }, AppState)

  for i = 1, 9 do
    self.workspaces[#self.workspaces + 1] = Workspace.new(i, "Window " .. tostring(i), cfg.minimizeThreshold)
  end

  self:_refreshFocusedSpaceId()
  self:_restoreWorkspacePairings()

  self:_persistWorkspacePairings()
  return self
end

function AppState:attachUi(popover, settingsWindow)
  self.popover = popover
  self.settingsWindow = settingsWindow
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

function AppState:_refreshFocusedSpaceId()
  if self.windowService and self.windowService.focusedSpaceId then
    self.session.focusedSpaceId = self.windowService.focusedSpaceId()
  end
  return self.session.focusedSpaceId
end

function AppState:getWorkspaceRowModels()
  self:_refreshFocusedSpaceId()
  return SlotRow.buildRows(self.workspaces, self.session, {
    windowService = self.windowService,
  })
end

function AppState:getWindowInfo(win)
  return self.windowService.getWindowInfo(win)
end

function AppState:getYouTubeTargetId()
  return self.youtubeService:getTargetId()
end

function AppState:syncUi()
  local components = {
    self.popover,
    self.settingsWindow,
  }

  for _, component in ipairs(components) do
    if component and component.refreshCache then
      component:refreshCache()
    elseif component and component.refreshIfShown then
      component:refreshIfShown()
    end
  end
end

function AppState:_runPairingAction(actionFn)
  if self.windowService and self.windowService.cancelPendingFrontmostRequest then
    self.windowService.cancelPendingFrontmostRequest()
  end
  actionFn()
  self:_persistWorkspacePairings()
  self:syncUi()
  if self.cfg.popoverAutoHideAfterAction and self.popover and self.popover.hide then
    self.popover:hide()
  end
end

function AppState:_runWorkspaceAction(actionFn)
  if self.windowService and self.windowService.cancelPendingFrontmostRequest then
    self.windowService.cancelPendingFrontmostRequest()
  end
  actionFn()
  self:syncUi()
end

function AppState:_getWorkspace(index)
  return self.workspaces[index]
end

function AppState:_resolvePairedWindow(workspace)
  if not workspace or not workspace:getBaseWindowId() then
    return nil
  end
  return self.windowService.getWindowById(workspace:getBaseWindowId())
end

function AppState:_windowTitleMatchesWorkspace(workspace, win)
  if not workspace or not win then
    return false
  end

  local meta = self.windowService.pairingMetadata and self.windowService.pairingMetadata(win)
  if not meta then
    return false
  end

  local fingerprint = workspace:getFingerprint()
  if fingerprint.bundleID and meta.bundleID and fingerprint.bundleID ~= meta.bundleID then
    return false
  end

  if fingerprint.titleNormalized
    and meta.titleNormalized
    and fingerprint.titleNormalized ~= meta.titleNormalized then
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
    return nil, nil
  end

  return self:_resolveLiveWindowTargetById(workspace:getFullscreenTargetWindowId())
end

function AppState:_resolveTrackedSpaceByWindowId(windowId)
  if not windowId then
    return nil
  end

  if not self.windowService.getWindowSpacesById then
    return nil
  end

  local spaceIds = self.windowService.getWindowSpacesById(windowId)
  local _, _, resolvedSpaceId = self:_resolvedTargetSpaceFromSpaceIds(spaceIds, nil)
  return resolvedSpaceId
end

function AppState:_resolveLiveWindowTargetById(windowId)
  local resolvedSpaceId = self:_resolveTrackedSpaceByWindowId(windowId)
  if not resolvedSpaceId then
    return nil, nil
  end
  return self.windowService.getWindowById(windowId), resolvedSpaceId
end

function AppState:_restorePairedWorkspaceFromRecord(workspace, persisted)
  if not workspace or type(persisted) ~= "table" then
    return false
  end

  local baseWindowId = persisted.baseWindowId
  if not baseWindowId then
    workspace:clear()
    return false
  end

  local baseWin = self.windowService.getWindowById(baseWindowId)
  if baseWin then
    workspace:pair(baseWindowId, persisted.fingerprint)
    if persisted.baseSpaceId then
      workspace:setBaseSpaceId(persisted.baseSpaceId)
    end
    self:_updateWorkspaceBindingSpaceState(workspace, baseWin)

    local fullscreenTargetWindowId = persisted.fullscreenTarget and persisted.fullscreenTarget.windowId or nil
    local fullscreenSpaceId = self:_resolveTrackedSpaceByWindowId(fullscreenTargetWindowId)
    if fullscreenTargetWindowId and fullscreenSpaceId then
      local fullscreenWin = self.windowService.getWindowById(fullscreenTargetWindowId)
      workspace:setFullscreenState({
        fullscreenWindowId = fullscreenTargetWindowId,
        fullscreenSpaceId = fullscreenSpaceId,
        lastKnownSpaceId = workspace:getBaseSpaceId(),
      })
      if fullscreenWin then
        self:_refreshWorkspaceFingerprint(workspace, fullscreenWin)
      end
    elseif self.windowService.isWindowFullscreen(baseWin) then
      local baseSpaceId = workspace:getBaseSpaceId()
      local fullscreenTarget = self:_findFullscreenCompanion(workspace, baseWin, baseSpaceId) or baseWin
      workspace:setFullscreenState({
        fullscreenWindowId = fullscreenTarget:id(),
        fullscreenSpaceId = baseSpaceId,
        lastKnownSpaceId = workspace:getBaseSpaceId(),
      })
    end

    if not workspace:hasTrackedFullscreenTarget() then
      self:_refreshWorkspaceFingerprint(workspace, baseWin)
    end
    return true
  end

  local fullscreenTargetWindowId = persisted.fullscreenTarget and persisted.fullscreenTarget.windowId or nil
  local fullscreenSpaceId = self:_resolveTrackedSpaceByWindowId(fullscreenTargetWindowId)
  if fullscreenTargetWindowId and fullscreenSpaceId then
    workspace:pair(baseWindowId, persisted.fingerprint)
    if persisted.baseSpaceId then
      workspace:setBaseSpaceId(persisted.baseSpaceId)
    end
    workspace:setFullscreenState({
      fullscreenWindowId = fullscreenTargetWindowId,
      fullscreenSpaceId = fullscreenSpaceId,
      lastKnownSpaceId = workspace:getBaseSpaceId(),
    })
    local fullscreenWin = self.windowService.getWindowById(fullscreenTargetWindowId)
    if fullscreenWin then
      self:_refreshWorkspaceFingerprint(workspace, fullscreenWin)
    end
    return true
  end

  local resolvedBaseSpaceId = self:_resolveTrackedSpaceByWindowId(baseWindowId)
  if resolvedBaseSpaceId then
    workspace:pair(baseWindowId, persisted.fingerprint)
    workspace:setBaseSpaceId(resolvedBaseSpaceId)
    return true
  end

  workspace:clear()
  return false
end

function AppState:_workspacePairingSnapshot()
  local pairings = {}
  for index, workspace in ipairs(self.workspaces) do
    if workspace then
      local record = SlotRecord.encode(workspace.binding)
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
        if persisted.kind == "paired" then
          if self:_restorePairedWorkspaceFromRecord(workspace, persisted) then
            restoredCount = restoredCount + 1
          end
        elseif persisted.kind == "recoverable" then
          if self.cfg.recoverClosedWindows then
            workspace:setRecoverable(persisted.fingerprint)
          else
            workspace:clear()
          end
        else
          workspace:clear()
        end
      end
    end
  end
  return restoredCount
end

function AppState:_refreshWorkspaceFingerprint(workspace, win)
  if not workspace then
    return
  end
  if not workspace:getBaseWindowId() then
    return
  end

  local target = win
  if not target or target:id() ~= workspace:getBaseWindowId() then
    target = self.windowService.getWindowById(workspace:getBaseWindowId())
  end

  if not target then
    target = win
  end

  if target then
    workspace:setFingerprint(self.windowService.pairingMetadata(target))
  end
end

function AppState:_refreshPairedWorkspaceMetadataForWindow(win)
  if not win then
    return false
  end

  local id = win:id()
  if not id then
    return false
  end

  local meta = self.windowService.pairingMetadata(win)
  local matchedWorkspace = false
  for _, workspace in ipairs(self.workspaces) do
    if workspace:getBaseWindowId() == id or workspace:getFullscreenTargetWindowId() == id then
      matchedWorkspace = true
      workspace:setFingerprint(meta)
    end
  end

  return matchedWorkspace
end

function AppState:_pairWorkspace(workspace, windowId, win)
  workspace:pair(windowId, self.windowService.pairingMetadata(win))
  local spaceId = self:_updateWorkspaceBindingSpaceState(
    workspace,
    win
  )
  if self.windowService.isWindowFullscreen(win) then
    local fullscreenTarget = self:_findFullscreenCompanion(workspace, win, spaceId) or win
    workspace:setFullscreenState({
      fullscreenWindowId = fullscreenTarget:id(),
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

function AppState:_updateWorkspaceBindingSpaceState(workspace, win)
  if not workspace or not win then
    return nil
  end

  local spaceId = self.windowService.getPrimarySpaceForWindow(win)
  if spaceId ~= nil then
    workspace:setBaseSpaceId(spaceId)
  end
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

  local shouldInspectSpaces = workspace:getBaseSpaceId() ~= nil
    and focusedSpaceId ~= nil
    and workspace:getBaseSpaceId() ~= focusedSpaceId

  if shouldInspectSpaces then
    local targetSpaceId, inFocusedSpace, resolvedSpaceId = self:_resolvedTargetSpaceForWindow(paired, focusedSpaceId)
    if inFocusedSpace then
      if resolvedSpaceId then
        workspace:setBaseSpaceId(resolvedSpaceId)
      end
      self:_refreshWorkspaceFingerprint(workspace, paired)
      self.windowService.requestFrontmost(paired)
      return "base-window"
    end

    if targetSpaceId then
      local switchResult = self.windowService.gotoSpace(targetSpaceId, self.cfg)
      if switchResult.ok then
        workspace:setBaseSpaceId(targetSpaceId)
        self:_refreshWorkspaceFingerprint(workspace, paired)
        self.windowService.requestFrontmostAfterSpaceSwitch(paired, self.cfg)
        return "base-window-space-switch"
      end

      return nil
    end
  end

  self:_refreshWorkspaceFingerprint(workspace, paired)
  self.windowService.requestFrontmost(paired)
  return "base-window"
end

function AppState:_activateExactWindowIdAcrossSpaces(workspace, focusedSpaceId)
  if not workspace or not workspace:getBaseWindowId() then
    return nil
  end

  if workspace:getBaseSpaceId() == nil or workspace:getBaseSpaceId() == focusedSpaceId then
    return nil
  end

  if not self.windowService.getWindowSpacesById then
    return nil
  end

  local spaceIds = self.windowService.getWindowSpacesById(workspace:getBaseWindowId())
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

  self:_updateWorkspaceBindingSpaceState(
    workspace,
    resolved
  )
  workspace:setBaseSpaceId(targetSpaceId)
  self:_refreshWorkspaceFingerprint(workspace, resolved)
  self.windowService.requestFrontmostAfterSpaceSwitch(resolved, self.cfg)
  return "base-window-id-space-switch"
end

function AppState:_isWindowAlreadyPaired(windowId)
  for _, workspace in ipairs(self.workspaces) do
    if workspace:getBaseWindowId() == windowId or workspace:getFullscreenTargetWindowId() == windowId then
      return true
    end
  end
  return false
end

function AppState:_restoreWorkspaceFromCandidate(win)
  if not self.cfg.recoverClosedWindows then
    return false
  end

  if not self.windowService.isCandidateWindow or not self.windowService.isCandidateWindow(win) then
    return false
  end

  local candidateMeta = self.windowService.pairingMetadata(win)
  local candidateId = win:id()
  if not candidateMeta or not candidateId or self:_isWindowAlreadyPaired(candidateId) then
    return false
  end

  local restoredWorkspaces = {}
  for _, workspace in ipairs(self.workspaces) do
    if workspace:canRecover()
      and workspace:matchesRecoveryCandidate(candidateMeta) then
      self:_pairWorkspace(workspace, candidateId, win)
      restoredWorkspaces[#restoredWorkspaces + 1] = workspace
    end
  end

  if #restoredWorkspaces > 0 then
    self:_persistWorkspacePairings()
    self.toast(self:_formatRestoreToast(restoredWorkspaces, win))
    return true
  end
  return false
end

function AppState:_formatPairToast(workspace, win)
  local app = win and win:application() or nil
  local label = self.windowService.windowTitle and self.windowService.windowTitle(win) or self.windowService.displayTitle(win)
  return ToastMessage.windowAction({
    prefixText = string.format("Pairing %s: ", workspace:getName()),
    titleText = label,
    bundleID = app and app:bundleID() or nil,
    appName = app and app:name() or nil,
    prefixColor = TOAST_WHITE,
    titleColor = PAIR_TOAST_COLOR,
    duration = 2.0,
  })
end

function AppState:_formatUnpairToast(workspace, win)
  local app = win and win:application() or nil
  local fingerprint = workspace and workspace:getFingerprint() or {}
  local label = self.windowService.windowTitle and self.windowService.windowTitle(win) or self.windowService.displayTitle(win)
  if label == "[empty]" then
    label = workspace:getStoredWindowTitle()
  end
  return ToastMessage.windowAction({
    prefixText = string.format("Unpairing %s: ", workspace:getName()),
    titleText = label,
    bundleID = app and app:bundleID() or fingerprint.bundleID or nil,
    appName = app and app:name() or fingerprint.appName or nil,
    prefixColor = TOAST_WHITE,
    titleColor = UNPAIR_TOAST_COLOR,
  })
end

function AppState:_formatClosedWindowUnpairToast(workspace)
  local fingerprint = workspace and workspace:getFingerprint() or {}
  return ToastMessage.windowAction({
    prefixText = "[Unpaired Closed Window: ",
    titleText = workspace and workspace:getStoredWindowTitle() or "[empty]",
    bundleID = fingerprint.bundleID or nil,
    appName = fingerprint.appName or nil,
    prefixColor = TOAST_WHITE,
    titleColor = UNPAIR_TOAST_COLOR,
    suffixText = "]",
    suffixColor = TOAST_WHITE,
  })
end

function AppState:_formatRestoreToast(workspaces, win)
  local app = win and win:application() or nil
  local label = self.windowService.windowTitle and self.windowService.windowTitle(win) or self.windowService.displayTitle(win)
  local names = {}
  for _, ws in ipairs(workspaces) do
    names[#names + 1] = ws:getName()
  end
  return ToastMessage.windowAction({
    prefixText = "Restored " .. table.concat(names, ", ") .. ": ",
    titleText = label,
    bundleID = app and app:bundleID() or nil,
    appName = app and app:name() or nil,
    prefixColor = TOAST_WHITE,
    titleColor = PAIR_TOAST_COLOR,
    duration = 2.0,
  })
end

function AppState:_clearRecoverableWorkspaces()
  local changed = false
  for _, workspace in ipairs(self.workspaces) do
    if workspace:isRecoverable() then
      workspace:clear()
      changed = true
    end
  end
  return changed
end

function AppState:_clearWorkspaceAndPersist(workspace)
  if not workspace then
    return
  end
  workspace:clear()
  self:_persistWorkspacePairings()
end

function AppState:pairSlot(index, sourceWindow)
  local workspace = self:_getWorkspace(index)
  if not workspace then
    return
  end

  local win = sourceWindow
  if not win then
    self.toast(ToastMessage.plain("No window to pair!"))
    return
  end

  self:_runPairingAction(function()
    self:_pairWorkspace(workspace, win:id(), win)
    self.toast(self:_formatPairToast(workspace, win))
  end)
end

function AppState:activateSlot(index)
  local workspace = self:_getWorkspace(index)
  if not workspace then
    return
  end

  local bindingChanged = false
  self:_runWorkspaceAction(function()
    local win = hs.window.frontmostWindow()
    if not win then
      self.toast(ToastMessage.plain("No active window found!"))
      return
    end

    local currentId = win:id()
    local focusedSpaceId = self.windowService.focusedSpaceId and self.windowService.focusedSpaceId() or nil
    if not workspace:isPaired() then
      self:_pairWorkspace(workspace, currentId, win)
      bindingChanged = true
      self.toast(self:_formatPairToast(workspace, win))
      return
    end

    if workspace:hasTrackedFullscreenTarget()
      and currentId == workspace:getFullscreenTargetWindowId()
      and focusedSpaceId == workspace:getFullscreenTargetSpaceId()
      and self.windowService.isWindowFullscreen(win) then
      return
    end

    if currentId ~= workspace:getBaseWindowId() then
      if workspace:hasTrackedFullscreenTarget() then
        local resolvedFullscreenSpaceId = self:_resolveTrackedSpaceByWindowId(workspace:getFullscreenTargetWindowId())
        if resolvedFullscreenSpaceId then
          if resolvedFullscreenSpaceId ~= workspace:getFullscreenTargetSpaceId() then
            workspace:setFullscreenState({
              fullscreenWindowId = workspace:getFullscreenTargetWindowId(),
              fullscreenSpaceId = resolvedFullscreenSpaceId,
              lastKnownSpaceId = workspace:getBaseSpaceId(),
            })
            bindingChanged = true
          end

          if focusedSpaceId == resolvedFullscreenSpaceId then
            local fullscreenWin = self.windowService.getWindowById(workspace:getFullscreenTargetWindowId())
            if fullscreenWin then
              workspace:setFullscreenState({
                fullscreenWindowId = fullscreenWin:id(),
                fullscreenSpaceId = resolvedFullscreenSpaceId,
                lastKnownSpaceId = workspace:getBaseSpaceId(),
              })
              self.windowService.requestFrontmost(fullscreenWin)
              self:_refreshWorkspaceFingerprint(workspace, fullscreenWin)
              return
            end
          else
            local switchResult = self.windowService.gotoSpace(resolvedFullscreenSpaceId, self.cfg)
            if switchResult.ok then
              local fullscreenWin = self.windowService.getWindowById(workspace:getFullscreenTargetWindowId())
              if fullscreenWin then
                workspace:setFullscreenState({
                  fullscreenWindowId = fullscreenWin:id(),
                  fullscreenSpaceId = resolvedFullscreenSpaceId,
                  lastKnownSpaceId = workspace:getBaseSpaceId(),
                })
                self.windowService.requestFrontmostAfterSpaceSwitch(fullscreenWin, self.cfg)
                self:_refreshWorkspaceFingerprint(workspace, fullscreenWin)
                return
              end
            end
          end
        else
          workspace:clearFullscreenState()
          bindingChanged = true
        end
      end

      local paired = self:_resolvePairedWindow(workspace)
      if paired then
        workspace:resetInputBuffer()
        self:_activateResolvedPairedWindow(workspace, paired, focusedSpaceId)
      elseif not self:_activateExactWindowIdAcrossSpaces(workspace, focusedSpaceId) then
        self.toast(ToastMessage.plain("Window not found in any spaces"))
      end
      return
    end

    if workspace:hasTrackedFullscreenTarget() and currentId == workspace:getFullscreenTargetWindowId()
      and self.windowService.isWindowFullscreen(win) then
      return
    end

    local paired = self:_resolvePairedWindow(workspace) or win
    workspace:consumeRepeatPress()
    if paired and workspace:shouldMinimize() then
      workspace:resetInputBuffer()
      paired:minimize()
      return
    end
  end)

  if bindingChanged then
    self:_persistWorkspacePairings()
  end
end

function AppState:unpairSlot(index)
  local workspace = self:_getWorkspace(index)
  if not workspace then
    return
  end

  self:_runPairingAction(function()
    if workspace:isPaired() or workspace:isRecoverable() then
      local win = self:_resolvePairedWindow(workspace)
      local toastPayload = self:_formatUnpairToast(workspace, win)
      workspace:clear()
      self.toast(toastPayload)
    else
      self.toast(ToastMessage.plain(workspace:getName() .. " is already unpaired!"))
    end
  end)
end

function AppState:unpairAll()
  self:_runPairingAction(function()
    for _, workspace in ipairs(self.workspaces) do
      workspace:clear()
    end
    self.toast(ToastMessage.plain("[Unpaired All Windows]"))
  end)
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

function AppState:toggleSettingsWindow()
  if not self.settingsWindow then
    return
  end

  if self.settingsWindow.isShown and self.settingsWindow:isShown() then
    if self.settingsWindow.hide then
      self.settingsWindow:hide()
    end
    return
  end

  if self.settingsWindow.show then
    self.settingsWindow:show()
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
  if self.popover and self.popover.syncWindowLevel then
    self.popover:syncWindowLevel()
  end
  if self.settingsWindow and self.settingsWindow.syncWindowLevel then
    self.settingsWindow:syncWindowLevel()
  end
  self:syncUi()
end

function AppState:setPopoverHidePairButtons(enabled)
  self.cfg.popoverHidePairButtons = enabled == true
  self.settingsStore.setBoolean(configModule.keys.popoverHidePairButtons, self.cfg.popoverHidePairButtons)
  self:syncUi()
end

function AppState:setRecoverClosedWindows(enabled)
  self.cfg.recoverClosedWindows = enabled == true
  self.settingsStore.setBoolean(configModule.keys.recoverClosedWindows, self.cfg.recoverClosedWindows)
  if not self.cfg.recoverClosedWindows and self:_clearRecoverableWorkspaces() then
    self:_persistWorkspacePairings()
  end
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
    local closedWindowToast = nil
    for _, workspace in ipairs(self.workspaces) do
      if workspace:getFullscreenTargetWindowId() == deadId and workspace:getBaseWindowId() ~= deadId then
        workspace:clearFullscreenState()
        fullscreenStateChanged = true
      end
      if workspace:getBaseWindowId() == deadId then
        if workspace:hasTrackedFullscreenTarget()
          and workspace:getFullscreenTargetWindowId() ~= deadId then
          goto continue_window_destroy
        end
        if workspace:hasTrackedFullscreenTarget()
          and workspace:getFullscreenTargetWindowId() == deadId
          and self.windowService.isWindowFullscreen(win) then
          workspace:clearFullscreenState()
          fullscreenStateChanged = true
          goto continue_window_destroy
        end
        if self.cfg.recoverClosedWindows then
          workspace:markClosedForRecovery()
        else
          closedWindowToast = self:_formatClosedWindowUnpairToast(workspace)
          workspace:clear()
        end
        basePairingChanged = true
      end
      ::continue_window_destroy::
    end

    if basePairingChanged then
      self:_persistWorkspacePairings()
      if closedWindowToast then
        self.toast(closedWindowToast)
      end
      self:syncUi()
    elseif fullscreenStateChanged then
      self:_persistWorkspacePairings()
      self:syncUi()
    end
    return
  end

  if event == hs.window.filter.windowFullscreened then
    if not win then
      return
    end
    self:_refreshFocusedSpaceId()
    local winId = win:id()
    for _, workspace in ipairs(self.workspaces) do
      if workspace:getBaseWindowId() == winId then
        local spaceId = self:_updateWorkspaceBindingSpaceState(workspace, win)
        local fullscreenTarget = self:_findFullscreenCompanion(workspace, win, spaceId) or win
        workspace:setFullscreenState({
          fullscreenWindowId = fullscreenTarget:id(),
          fullscreenSpaceId = spaceId,
          lastKnownSpaceId = spaceId,
        })
      end
    end
    self:_persistWorkspacePairings()
    self:syncUi()
    return
  end

  if event == hs.window.filter.windowUnfullscreened then
    if not win then
      return
    end
    self:_refreshFocusedSpaceId()
    local winId = win:id()
    for _, workspace in ipairs(self.workspaces) do
      if workspace:getFullscreenTargetWindowId() == winId then
        local spaceId = self:_updateWorkspaceBindingSpaceState(workspace, win)
        workspace:clearFullscreenState()
        if spaceId ~= nil then
          workspace:setBaseSpaceId(spaceId)
        end
      elseif workspace:getBaseWindowId() == winId then
        local spaceId = self:_updateWorkspaceBindingSpaceState(workspace, win)
        workspace:clearFullscreenState()
        if spaceId ~= nil then
          workspace:setBaseSpaceId(spaceId)
        end
      end
    end
    self:_persistWorkspacePairings()
    self:syncUi()
    return
  end

  local restored = false
  if win then
    restored = self:_restoreWorkspaceFromCandidate(win)
  end

  local pairedWorkspaceTouched = self:_refreshPairedWorkspaceMetadataForWindow(win)
  self.youtubeService:handleWindowCandidate(win)

  local shouldRefreshPopover = event == hs.window.filter.windowFocused or pairedWorkspaceTouched or restored
  if win then
    local frontmost = hs.window.frontmostWindow()
    if frontmost and frontmost:id() == win:id() then
      shouldRefreshPopover = true
    end
  end

  if shouldRefreshPopover and self.popover and self.popover.requestRefresh then
    self.popover:requestRefresh("window_event")
  end

end

function AppState:handleActiveWindowChange(win)
  self:_refreshFocusedSpaceId()
  if self.popover and self.popover.requestActiveWindowUpdate then
    self.popover:requestActiveWindowUpdate(win)
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

POPOVER_ACTIONS["toggleSettingsWindow"] = function(self)
  self:toggleSettingsWindow()
end

POPOVER_ACTIONS["setAutoHideAfterAction"] = function(self, body)
  self:setPopoverAutoHide(tonumber(body.slot) == 1)
end

POPOVER_ACTIONS["setAlwaysOnTop"] = function(self, body)
  self:setPopoverAlwaysOnTop(tonumber(body.slot) == 1)
end

POPOVER_ACTIONS["setHidePairButtons"] = function(self, body)
  self:setPopoverHidePairButtons(tonumber(body.slot) == 1)
end

POPOVER_ACTIONS["setRecoverClosedWindows"] = function(self, body)
  self:setRecoverClosedWindows(tonumber(body.slot) == 1)
end

POPOVER_ACTIONS["setPopoverOpacity"] = function(self, body)
  local rawPercent = tonumber(body.slot)
  if rawPercent then
    self:setPopoverOpacity(rawPercent)
  end
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
  return self.youtubeService:sendCommand(keyPress)
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
