local Workspace = {}
Workspace.__index = Workspace

local function cloneFingerprint(recoveryMeta)
  if type(recoveryMeta) ~= "table" then
    return {
      bundleID = nil,
      appName = nil,
      titleRaw = nil,
      titleNormalized = nil,
    }
  end

  local function normalizeString(value)
    if type(value) ~= "string" or value == "" then
      return nil
    end
    return value
  end

  return {
    bundleID = normalizeString(recoveryMeta.bundleID),
    appName = normalizeString(recoveryMeta.appName),
    titleRaw = type(recoveryMeta.titleRaw) == "string" and recoveryMeta.titleRaw or nil,
    titleNormalized = normalizeString(recoveryMeta.titleNormalized),
  }
end

function Workspace.new(indexOrName, nameOrThreshold, maybeThreshold)
  local index = nil
  local name = nil
  local minimizeThreshold = nil

  if type(indexOrName) == "number" then
    index = indexOrName
    name = tostring(nameOrThreshold or ("Window " .. tostring(index)))
    minimizeThreshold = maybeThreshold
  else
    name = tostring(indexOrName or "Window")
    minimizeThreshold = nameOrThreshold
  end

  return setmetatable({
    index = index,
    name = name,
    interaction = {
      repeatBuffer = minimizeThreshold,
    },
    binding = {
      kind = "empty",
      baseWindowId = nil,
      baseSpaceId = nil,
      fullscreenTarget = {
        windowId = nil,
        spaceId = nil,
      },
      fingerprint = cloneFingerprint(nil),
      recovery = {
        closedAt = nil,
      },
    },
    _minimizeThreshold = minimizeThreshold,
  }, Workspace)
end

function Workspace:getName()
  return self.name
end

function Workspace:getIndex()
  return self.index
end

function Workspace:getBaseWindowId()
  return self.binding.baseWindowId
end

function Workspace:getBindingKind()
  return self.binding.kind
end

function Workspace:getFingerprint()
  return self.binding.fingerprint
end

function Workspace:getRecoveryClosedAt()
  return self.binding.recovery.closedAt
end

function Workspace:getBaseSpaceId()
  return self.binding.baseSpaceId
end

function Workspace:getFullscreenTargetWindowId()
  return self.binding.fullscreenTarget.windowId
end

function Workspace:getFullscreenTargetSpaceId()
  return self.binding.fullscreenTarget.spaceId
end

function Workspace:isPaired()
  return self.binding.kind == "paired" and self.binding.baseWindowId ~= nil
end

function Workspace:isRecoverable()
  return self.binding.kind == "recoverable"
end

function Workspace:pair(baseWindowId, recoveryMeta)
  self.binding.kind = "paired"
  self.binding.baseWindowId = baseWindowId
  self.binding.baseSpaceId = nil
  self.binding.recovery.closedAt = nil
  self:setFingerprint(recoveryMeta)
  self:clearFullscreenState()
  self:resetInputBuffer()
end

function Workspace:setFingerprint(recoveryMeta)
  self.binding.fingerprint = cloneFingerprint(recoveryMeta)
end

function Workspace:setRecoverable(recoveryMeta, closedAt)
  self.binding.kind = "recoverable"
  self.binding.baseWindowId = nil
  self.binding.baseSpaceId = nil
  self.binding.recovery.closedAt = closedAt
  self:setFingerprint(recoveryMeta)
  self:resetInputBuffer()
  self:clearFullscreenState()
end

function Workspace:clear()
  self.binding.kind = "empty"
  self.binding.baseWindowId = nil
  self.binding.baseSpaceId = nil
  self.binding.fingerprint = cloneFingerprint(nil)
  self.binding.recovery.closedAt = nil
  self:resetInputBuffer()
  self:clearFullscreenState()
end

function Workspace:markClosedForRecovery(closedAt)
  self:setRecoverable(self.binding.fingerprint, closedAt)
end

function Workspace:clearRecoveryTracking()
  self.binding.recovery.closedAt = nil
  if self.binding.kind == "recoverable" then
    self:clear()
  end
end

function Workspace:canRecover(now, timeoutSec)
  local fingerprint = self.binding.fingerprint
  local closedAt = self.binding.recovery.closedAt

  if self.binding.kind ~= "recoverable" then
    return false
  end
  if not fingerprint.bundleID or not fingerprint.titleNormalized or not closedAt then
    return false
  end
  if type(now) ~= "number" or type(timeoutSec) ~= "number" then
    return false
  end
  if now < closedAt then
    return false
  end
  return (now - closedAt) <= timeoutSec
end

function Workspace:matchesRecoveryCandidate(candidateMeta)
  local fingerprint = self.binding.fingerprint

  if type(candidateMeta) ~= "table" then
    return false
  end
  if not fingerprint.bundleID or not fingerprint.titleNormalized then
    return false
  end
  return fingerprint.bundleID == candidateMeta.bundleID
    and fingerprint.titleNormalized == candidateMeta.titleNormalized
end

function Workspace:resetInputBuffer()
  self.interaction.repeatBuffer = self._minimizeThreshold
end

function Workspace:consumeRepeatPress()
  self.interaction.repeatBuffer = self.interaction.repeatBuffer - 1
  return self.interaction.repeatBuffer
end

function Workspace:shouldMinimize()
  return self.interaction.repeatBuffer <= 0
end

function Workspace:setBaseSpaceId(spaceId)
  self.binding.baseSpaceId = spaceId
end

function Workspace:getStoredWindowTitle()
  local titleRaw = self.binding.fingerprint.titleRaw
  if type(titleRaw) == "string" and titleRaw:match("%S") then
    return titleRaw
  end
  return "[empty]"
end

function Workspace:getStoredDisplayTitle()
  local title = self:getStoredWindowTitle()
  if title == "[empty]" then
    return title
  end

  local appName = self.binding.fingerprint.appName
  if type(appName) == "string" and appName:match("%S") then
    return string.format("[%s] %s", appName, title)
  end
  return title
end

function Workspace:setFullscreenState(opts)
  if type(opts) ~= "table" then
    return
  end

  self.binding.fullscreenTarget.windowId = opts.fullscreenWindowId
  self.binding.fullscreenTarget.spaceId = opts.fullscreenSpaceId

  if opts.lastKnownSpaceId ~= nil then
    self.binding.baseSpaceId = opts.lastKnownSpaceId
  end
end

function Workspace:clearFullscreenState()
  self.binding.fullscreenTarget.windowId = nil
  self.binding.fullscreenTarget.spaceId = nil
end

function Workspace:hasTrackedFullscreenTarget()
  return self.binding.fullscreenTarget.windowId ~= nil
end

return Workspace
