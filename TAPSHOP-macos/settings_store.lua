local SettingsStore = {}

local function clampOpacityValue(value)
  local snapped = math.floor((value * 100) / 10 + 0.5) * 10
  return math.max(40, math.min(100, snapped)) / 100
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

return SettingsStore
