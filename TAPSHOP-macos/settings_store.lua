local SettingsStore = {}

local function clampOpacityValue(value)
  local snapped = math.floor((value * 100) / 10 + 0.5) * 10
  return math.max(40, math.min(100, snapped)) / 100
end

local function normalizePositiveInteger(value)
  if type(value) ~= "number" then
    return nil
  end
  if value < 1 then
    return nil
  end

  local normalized = math.floor(value)
  if normalized ~= value then
    return nil
  end

  return normalized
end

function SettingsStore.getBoolean(key, defaultValue)
  local value = hs.settings.get(key)
  if type(value) == "boolean" then
    return value
  end
  return defaultValue
end

function SettingsStore.setBoolean(key, value)
  hs.settings.set(key, value == true)
end

function SettingsStore.getOpacity(key, defaultValue)
  local value = hs.settings.get(key)
  if type(value) == "number" and value >= 0.40 and value <= 1.00 then
    return clampOpacityValue(value)
  end
  return clampOpacityValue(defaultValue)
end

function SettingsStore.setOpacity(key, value)
  local normalized = clampOpacityValue(value)
  hs.settings.set(key, normalized)
  return normalized
end

function SettingsStore.getPoint(key)
  local value = hs.settings.get(key)
  if type(value) ~= "table" then
    return nil
  end
  if type(value.x) ~= "number" or type(value.y) ~= "number" then
    return nil
  end
  return {
    x = math.floor(value.x),
    y = math.floor(value.y),
  }
end

function SettingsStore.setPoint(key, point)
  if type(point) ~= "table" then
    return
  end
  if type(point.x) ~= "number" or type(point.y) ~= "number" then
    return
  end
  hs.settings.set(key, {
    x = math.floor(point.x),
    y = math.floor(point.y),
  })
end

function SettingsStore.getSize(key)
  local value = hs.settings.get(key)
  if type(value) ~= "table" then
    return nil
  end
  if type(value.w) ~= "number" or type(value.h) ~= "number" then
    return nil
  end
  return {
    w = math.floor(value.w),
    h = math.floor(value.h),
  }
end

function SettingsStore.setSize(key, size)
  if type(size) ~= "table" then
    return
  end
  if type(size.w) ~= "number" or type(size.h) ~= "number" then
    return
  end
  hs.settings.set(key, {
    w = math.floor(size.w),
    h = math.floor(size.h),
  })
end

function SettingsStore.getWindowPairings(key)
  local value = hs.settings.get(key)
  local out = {}
  if type(value) ~= "table" then
    return out
  end

  for rawSlot, rawWindowId in pairs(value) do
    local slot = normalizePositiveInteger(tonumber(rawSlot))
    local windowId = normalizePositiveInteger(rawWindowId)
    if slot and slot >= 1 and slot <= 9 and windowId then
      out[slot] = windowId
    end
  end

  return out
end

function SettingsStore.setWindowPairings(key, pairings)
  local payload = {}
  if type(pairings) == "table" then
    for rawSlot, rawWindowId in pairs(pairings) do
      local slot = normalizePositiveInteger(tonumber(rawSlot))
      local windowId = normalizePositiveInteger(rawWindowId)
      if slot and slot >= 1 and slot <= 9 and windowId then
        payload[tostring(slot)] = windowId
      end
    end
  end

  hs.settings.set(key, payload)
end

return SettingsStore
