local Workspace = {}
Workspace.__index = Workspace

function Workspace.new(label, minimizeThreshold)
  return setmetatable({
    label = label,
    id = nil,
    inputBuffer = minimizeThreshold,
    displayTitle = "[empty]",
    _minimizeThreshold = minimizeThreshold,
  }, Workspace)
end

function Workspace:isPaired()
  return self.id ~= nil
end

function Workspace:pair(windowId, displayTitle)
  self.id = windowId
  self.inputBuffer = self._minimizeThreshold
  self.displayTitle = displayTitle or "[empty]"
end

function Workspace:clear()
  self.id = nil
  self.inputBuffer = self._minimizeThreshold
  self.displayTitle = "[empty]"
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

return Workspace
