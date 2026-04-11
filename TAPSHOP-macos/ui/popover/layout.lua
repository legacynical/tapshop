local persistedSize = require("persisted_size")

local Layout = {}

local SCREEN_MARGIN = 32
local PROFILE = {
  defaultSize = { w = 500, h = 273 },
  minWidth = 150,
  targetMinHeight = 125,
}

local function cloneSize(size)
  if type(size) ~= "table" then
    return nil
  end
  if type(size.w) ~= "number" or type(size.h) ~= "number" then
    return nil
  end
  return {
    w = math.floor(size.w),
    h = math.floor(size.h),
  }
end

local function cloneFrame(frame)
  if type(frame) ~= "table" then
    return nil
  end
  if type(frame.x) ~= "number" or type(frame.y) ~= "number" then
    return nil
  end
  if type(frame.w) ~= "number" or type(frame.h) ~= "number" then
    return nil
  end
  return {
    x = math.floor(frame.x),
    y = math.floor(frame.y),
    w = math.floor(frame.w),
    h = math.floor(frame.h),
  }
end

function Layout.defaultSize()
  return cloneSize(PROFILE.defaultSize)
end

function Layout.minWidth()
  return PROFILE.minWidth
end

function Layout.targetMinHeight()
  return PROFILE.targetMinHeight
end

function Layout.clientPolicy()
  return {
    targetMinHeight = PROFILE.targetMinHeight,
  }
end

function Layout.initialRuntimeBounds()
  return {
    minHeight = nil,
    maxHeight = nil,
    minUiScale = nil,
    maxUiScale = nil,
  }
end

function Layout.loadSavedSize(settingsStore, keys)
  local size = persistedSize.load(settingsStore, keys.popoverMainSize, {
    keys.popoverSize,
  }) or Layout.defaultSize()
  return cloneSize(size) or Layout.defaultSize()
end

local function effectiveMinHeight(runtimeBounds)
  local runtimeMin = runtimeBounds and runtimeBounds.minHeight or PROFILE.targetMinHeight
  return math.max(PROFILE.targetMinHeight, math.floor(runtimeMin + 0.5))
end

local function effectiveMaxHeight(screenFrame, runtimeBounds)
  local minHeight = effectiveMinHeight(runtimeBounds)
  local runtimeMax = runtimeBounds and runtimeBounds.maxHeight or nil
  local maxHeight = runtimeMax and math.max(minHeight, math.floor(runtimeMax + 0.5)) or nil

  if screenFrame and type(screenFrame.h) == "number" then
    local screenMaxHeight = math.max(minHeight, math.floor(screenFrame.h - SCREEN_MARGIN))
    if maxHeight then
      maxHeight = math.max(minHeight, math.min(maxHeight, screenMaxHeight))
    else
      maxHeight = screenMaxHeight
    end
  end

  return maxHeight
end

function Layout.clampSize(size, screenFrame, runtimeBounds)
  local defaultSize = Layout.defaultSize()
  local minWidth = PROFILE.minWidth
  local minHeight = effectiveMinHeight(runtimeBounds)
  local maxHeight = effectiveMaxHeight(screenFrame, runtimeBounds)
  local width = math.max(minWidth, math.floor((size and size.w) or defaultSize.w))
  local height = math.floor((size and size.h) or defaultSize.h)

  if screenFrame and type(screenFrame.w) == "number" then
    local maxWidth = math.max(minWidth, math.floor(screenFrame.w - SCREEN_MARGIN))
    width = math.min(width, maxWidth)
  end

  if maxHeight then
    height = math.max(minHeight, math.min(height, maxHeight))
  else
    height = math.max(minHeight, height)
  end

  return {
    w = width,
    h = height,
  }
end

function Layout.clampFrame(frame, screenFrame, runtimeBounds)
  local normalized = cloneFrame(frame)
  local size = Layout.clampSize(normalized, screenFrame, runtimeBounds)
  local nextFrame = {
    x = normalized and normalized.x or 0,
    y = normalized and normalized.y or 0,
    w = size.w,
    h = size.h,
  }

  if screenFrame then
    local maxX = screenFrame.x + screenFrame.w - size.w
    local maxY = screenFrame.y + screenFrame.h - size.h
    nextFrame.x = math.max(screenFrame.x, math.min(nextFrame.x, maxX))
    nextFrame.y = math.max(screenFrame.y, math.min(nextFrame.y, maxY))
  end

  nextFrame.x = math.floor(nextFrame.x)
  nextFrame.y = math.floor(nextFrame.y)
  return nextFrame
end

function Layout.centeredFrame(screenFrame, savedSize, runtimeBounds)
  local size = Layout.clampSize(savedSize, screenFrame, runtimeBounds)

  if not screenFrame then
    return {
      x = 0,
      y = 0,
      w = size.w,
      h = size.h,
    }
  end

  return {
    x = math.floor(screenFrame.x + (screenFrame.w - size.w) / 2),
    y = math.floor(screenFrame.y + (screenFrame.h - size.h) / 2),
    w = size.w,
    h = size.h,
  }
end

function Layout.frameForTopLeft(topLeft, screenFrame, savedSize, runtimeBounds)
  local size = Layout.clampSize(savedSize, screenFrame, runtimeBounds)
  local frame = {
    x = topLeft and topLeft.x or 0,
    y = topLeft and topLeft.y or 0,
    w = size.w,
    h = size.h,
  }
  return Layout.clampFrame(frame, screenFrame, runtimeBounds)
end

return Layout
