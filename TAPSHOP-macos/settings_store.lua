local SettingsStore = {}

local VALID_MODS = {
  cmd = true,
  alt = true,
  ctrl = true,
  shift = true,
}

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

local function normalizeOptionalString(value)
  if type(value) ~= "string" then
    return nil
  end
  return value
end

local function normalizeOptionalNumber(value)
  if type(value) ~= "number" then
    return nil
  end
  return value
end

local function normalizeHotkeyMods(value)
  if type(value) ~= "table" then
    return nil
  end

  local out = {}
  local seen = {}
  for _, rawMod in ipairs(value) do
    if type(rawMod) == "string" and VALID_MODS[rawMod] and not seen[rawMod] then
      seen[rawMod] = true
      out[#out + 1] = rawMod
    end
  end

  table.sort(out, function(a, b)
    local order = { cmd = 1, alt = 2, ctrl = 3, shift = 4 }
    return order[a] < order[b]
  end)

  return out
end

local function normalizeHotkeyKey(value)
  if value == false then
    return false
  end
  if type(value) ~= "string" or value == "" then
    return nil
  end
  if value:match("^F%d+$") then
    return value
  end
  return string.lower(value)
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

function SettingsStore.getHotkeyOverrides(key)
  local value = hs.settings.get(key)
  local out = {}
  if type(value) ~= "table" then
    return out
  end

  for id, rawOverride in pairs(value) do
    if type(id) == "string" and type(rawOverride) == "table" then
      local normalized = {}
      local mods = normalizeHotkeyMods(rawOverride.mods)
      local hotkey = normalizeHotkeyKey(rawOverride.key)

      if mods ~= nil then
        normalized.mods = mods
      end
      if hotkey ~= nil then
        normalized.key = hotkey
      end
      if type(rawOverride.enabled) == "boolean" then
        normalized.enabled = rawOverride.enabled
      end

      if next(normalized) ~= nil then
        out[id] = normalized
      end
    end
  end

  return out
end

function SettingsStore.setHotkeyOverrides(key, overrides)
  local payload = {}
  if type(overrides) == "table" then
    for id, rawOverride in pairs(overrides) do
      if type(id) == "string" and type(rawOverride) == "table" then
        local normalized = {}
        local mods = normalizeHotkeyMods(rawOverride.mods)
        local hotkey = normalizeHotkeyKey(rawOverride.key)

        if mods ~= nil then
          normalized.mods = mods
        end
        if hotkey ~= nil then
          normalized.key = hotkey
        end
        if type(rawOverride.enabled) == "boolean" then
          normalized.enabled = rawOverride.enabled
        end

        if next(normalized) ~= nil then
          payload[id] = normalized
        end
      end
    end
  end

  hs.settings.set(key, payload)
end

function SettingsStore.clearSetting(key)
  hs.settings.clear(key)
end

function SettingsStore.getWindowPairings(key)
  local value = hs.settings.get(key)
  local out = {}
  if type(value) ~= "table" then
    return out
  end

  for rawSlot, rawPairing in pairs(value) do
    local slot = normalizePositiveInteger(tonumber(rawSlot))
    if slot and slot >= 1 and slot <= 9 then
      if type(rawPairing) == "number" then
        local windowId = normalizePositiveInteger(rawPairing)
        if windowId then
          out[slot] = windowId
        end
      elseif type(rawPairing) == "table" then
        local windowId = normalizePositiveInteger(rawPairing.windowId)
        local bundleID = normalizeOptionalString(rawPairing.bundleID)
        local appName = normalizeOptionalString(rawPairing.appName)
        local titleRaw = normalizeOptionalString(rawPairing.titleRaw)
        local titleNormalized = normalizeOptionalString(rawPairing.titleNormalized)
        local displayTitle = normalizeOptionalString(rawPairing.displayTitle)
        local closedAt = normalizeOptionalNumber(rawPairing.closedAt)

        if windowId or bundleID or appName or titleRaw or titleNormalized or displayTitle or closedAt then
          out[slot] = {
            windowId = windowId,
            bundleID = bundleID,
            appName = appName,
            titleRaw = titleRaw,
            titleNormalized = titleNormalized,
            displayTitle = displayTitle,
            closedAt = closedAt,
          }
        end
      end
    end
  end

  return out
end

function SettingsStore.setWindowPairings(key, pairings)
  local payload = {}
  if type(pairings) == "table" then
    for rawSlot, rawPairing in pairs(pairings) do
      local slot = normalizePositiveInteger(tonumber(rawSlot))
      if slot and slot >= 1 and slot <= 9 and type(rawPairing) == "table" then
        local windowId = normalizePositiveInteger(rawPairing.windowId)
        local bundleID = normalizeOptionalString(rawPairing.bundleID)
        local appName = normalizeOptionalString(rawPairing.appName)
        local titleRaw = normalizeOptionalString(rawPairing.titleRaw)
        local titleNormalized = normalizeOptionalString(rawPairing.titleNormalized)
        local displayTitle = normalizeOptionalString(rawPairing.displayTitle)
        local closedAt = normalizeOptionalNumber(rawPairing.closedAt)

        if windowId or bundleID or appName or titleRaw or titleNormalized or displayTitle or closedAt then
          payload[tostring(slot)] = {
            windowId = windowId,
            bundleID = bundleID,
            appName = appName,
            titleRaw = titleRaw,
            titleNormalized = titleNormalized,
            displayTitle = displayTitle,
            closedAt = closedAt,
          }
        end
      end
    end
  end

  hs.settings.set(key, payload)
end

return SettingsStore
