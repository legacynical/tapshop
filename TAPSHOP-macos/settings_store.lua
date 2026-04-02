local Utils = require("utils")

local SettingsStore = {}

local VALID_MODS = {
  cmd = true,
  alt = true,
  ctrl = true,
  shift = true,
}
local MOD_SORT_ORDER = {
  cmd = 1,
  alt = 2,
  ctrl = 3,
  shift = 4,
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
    return MOD_SORT_ORDER[a] < MOD_SORT_ORDER[b]
  end)

  return out
end

local function setTableOrClear(key, value)
  if type(value) == "table" and next(value) ~= nil then
    hs.settings.set(key, value)
    return
  end
  hs.settings.clear(key)
end

local function normalizeOverrideEntry(rawOverride)
  if type(rawOverride) ~= "table" then
    return nil
  end

  local normalized = {}
  local mods = normalizeHotkeyMods(rawOverride.mods)
  local key = Utils.normalizeKey(rawOverride.key)

  if mods ~= nil then
    normalized.mods = mods
  end
  if key ~= nil then
    normalized.key = key
  end
  if type(rawOverride.enabled) == "boolean" then
    normalized.enabled = rawOverride.enabled
  end

  if next(normalized) == nil then
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

function SettingsStore.getBooleanWithLegacyKey(key, legacyKey, defaultValue)
  local value = hs.settings.get(key)
  if type(value) == "boolean" then
    return value
  end

  local migrated = SettingsStore.getBoolean(legacyKey, defaultValue)
  SettingsStore.setBoolean(key, migrated)
  if legacyKey and legacyKey ~= "" then
    hs.settings.clear(legacyKey)
  end
  return migrated
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
    if type(id) == "string" then
      local normalized = normalizeOverrideEntry(rawOverride)
      if normalized then
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
      if type(id) == "string" then
        local normalized = normalizeOverrideEntry(rawOverride)
        if normalized then
          payload[id] = normalized
        end
      end
    end
  end

  setTableOrClear(key, payload)
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
          out[slot] = { windowId = windowId }
        end
      elseif type(rawPairing) == "table" then
        local record = Utils.buildPairingRecord(rawPairing)
        if record then
          out[slot] = record
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
        local record = Utils.buildPairingRecord(rawPairing)
        if record then
          payload[tostring(slot)] = record
        end
      end
    end
  end

  setTableOrClear(key, payload)
end

return SettingsStore
