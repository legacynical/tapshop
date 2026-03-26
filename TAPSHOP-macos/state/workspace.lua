local Workspace = {}
Workspace.__index = Workspace

function Workspace.new(label, minimizeThreshold)
  return setmetatable({
    label = label,
    id = nil,
    inputBuffer = minimizeThreshold,
    displayTitle = "[empty]",
    bundleID = nil,
    appName = nil,
    titleRaw = nil,
    titleNormalized = nil,
    closedAt = nil,
    _minimizeThreshold = minimizeThreshold,
  }, Workspace)
end

function Workspace:isPaired()
  return self.id ~= nil
end

function Workspace:pair(windowId, displayTitle)
  self:pairWithMetadata(windowId, displayTitle, nil)
end

function Workspace:pairWithMetadata(windowId, displayTitle, matchMeta)
  self.id = windowId
  self.inputBuffer = self._minimizeThreshold
  self.displayTitle = displayTitle or "[empty]"
  self.bundleID = matchMeta and matchMeta.bundleID or nil
  self.appName = matchMeta and matchMeta.appName or nil
  self.titleRaw = matchMeta and matchMeta.titleRaw or nil
  self.titleNormalized = matchMeta and matchMeta.titleNormalized or nil
  self.closedAt = nil
end

function Workspace:clear()
  self.id = nil
  self.inputBuffer = self._minimizeThreshold
  self.displayTitle = "[empty]"
  self.bundleID = nil
  self.appName = nil
  self.titleRaw = nil
  self.titleNormalized = nil
  self.closedAt = nil
  self:clearFullscreenState()
end

function Workspace:markClosedForRecovery(closedAt)
  self.id = nil
  self.inputBuffer = self._minimizeThreshold
  self.displayTitle = "[empty]"
  self.closedAt = closedAt
end

function Workspace:clearRecoveryTracking()
  self.closedAt = nil
end

function Workspace:canRecover(now, timeoutSec)
  if self.id ~= nil then
    return false
  end
  if not self.bundleID or not self.titleNormalized or not self.closedAt then
    return false
  end
  if type(now) ~= "number" or type(timeoutSec) ~= "number" then
    return false
  end
  return (now - self.closedAt) <= timeoutSec
end

function Workspace:matchesRecoveryCandidate(candidateMeta)
  if type(candidateMeta) ~= "table" then
    return false
  end
  if not self.bundleID or not self.titleNormalized then
    return false
  end
  return self.bundleID == candidateMeta.bundleID
    and self.titleNormalized == candidateMeta.titleNormalized
end

function Workspace:resetInputBuffer()
  self.inputBuffer = self._minimizeThreshold
end

function Workspace:consumeRepeatPress()
  self.inputBuffer = self.inputBuffer - 1
  return self.inputBuffer
end

function Workspace:shouldMinimize()
  return self.inputBuffer <= 0
end

function Workspace:setDisplayTitle(title)
  self.displayTitle = title or "[empty]"
end

function Workspace:setFullscreenState(opts)
  if type(opts) ~= "table" then
    return
  end
  self.fullscreenWindowId = opts.fullscreenWindowId
  self.fullscreenSpaceId = opts.fullscreenSpaceId
  self.fullscreenActive = true
  self.lastKnownSpaceId = opts.lastKnownSpaceId
end

function Workspace:clearFullscreenState()
  self.fullscreenWindowId = nil
  self.fullscreenSpaceId = nil
  self.fullscreenActive = nil
  self.lastKnownSpaceId = nil
end

function Workspace:hasTrackedFullscreenTarget()
  return self.fullscreenActive == true and self.fullscreenWindowId ~= nil
end

return Workspace
