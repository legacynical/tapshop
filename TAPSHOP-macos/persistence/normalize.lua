local SlotRecord = require("state.slot_record")

local Normalize = {}

local SYSTEM_KEY_NAMES = {
  SOUND_UP = true,
  SOUND_DOWN = true,
  MUTE = true,
  BRIGHTNESS_UP = true,
  BRIGHTNESS_DOWN = true,
  CONTRAST_UP = true,
  CONTRAST_DOWN = true,
  POWER = true,
  LAUNCH_PANEL = true,
  VIDMIRROR = true,
  PLAY = true,
  EJECT = true,
  NEXT = true,
  PREVIOUS = true,
  FAST = true,
  REWIND = true,
  ILLUMINATION_UP = true,
  ILLUMINATION_DOWN = true,
  ILLUMINATION_TOGGLE = true,
  CAPS_LOCK = true,
  HELP = true,
  NUM_LOCK = true,
}

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

local function normalizedSystemKeyCode(value)
  if type(value) ~= "number" then
    return nil
  end
  if value < 0 then
    return nil
  end
  return math.floor(value)
end

function Normalize.deepCopy(value)
  if type(value) ~= "table" then
    return value
  end

  local out = {}
  for key, nested in pairs(value) do
    out[key] = Normalize.deepCopy(nested)
  end
  return out
end

function Normalize.deepEqual(left, right)
  if type(left) ~= type(right) then
    return false
  end

  if type(left) ~= "table" then
    return left == right
  end

  for key, value in pairs(left) do
    if not Normalize.deepEqual(value, right[key]) then
      return false
    end
  end

  for key, value in pairs(right) do
    if not Normalize.deepEqual(value, left[key]) then
      return false
    end
  end

  return true
end

function Normalize.isSystemKey(value)
  if type(value) ~= "string" or value == "" then
    return false
  end
  local upper = string.upper(value)
  if SYSTEM_KEY_NAMES[upper] == true then
    return true
  end
  return upper:match("^SYSTEM_%d+$") ~= nil
end

function Normalize.systemKeyCodeLabel(keyCode)
  local normalized = normalizedSystemKeyCode(keyCode)
  if normalized == nil then
    return nil
  end
  return "SYSTEM_" .. tostring(normalized)
end

function Normalize.normalizeRawKeyCode(keyCode)
  return Normalize.systemKeyCodeLabel(keyCode)
end

function Normalize.normalizeSystemKeyInfo(info)
  if type(info) ~= "table" then
    return nil
  end

  local knownKey = Normalize.normalizeKey(info.key)
  if knownKey and Normalize.isSystemKey(knownKey) then
    return knownKey
  end

  return Normalize.systemKeyCodeLabel(info.keyCode)
end

function Normalize.isSystemKeyPress(info)
  if type(info) ~= "table" then
    return false
  end
  return info.down ~= false
end

function Normalize.normalizeKey(value)
  if value == false then
    return false
  end
  if type(value) ~= "string" or value == "" then
    return nil
  end
  local upper = string.upper(value)
  if Normalize.isSystemKey(upper) then
    return upper
  end
  if value:match("^F%d+$") then
    return value
  end
  return string.lower(value)
end

function Normalize.clampOpacity(value)
  if type(value) ~= "number" then
    return nil
  end
  local snapped = math.floor((value * 100) / 10 + 0.5) * 10
  return math.max(40, math.min(100, snapped)) / 100
end

function Normalize.normalizePositiveInteger(value)
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

function Normalize.normalizePoint(value)
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

function Normalize.normalizeSize(value)
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

function Normalize.normalizeHotkeyMods(value)
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

function Normalize.normalizeOverrideEntry(rawOverride)
  if type(rawOverride) ~= "table" then
    return nil
  end

  local normalized = {}
  local mods = Normalize.normalizeHotkeyMods(rawOverride.mods)
  local key = Normalize.normalizeKey(rawOverride.key)

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

function Normalize.normalizeHotkeyOverrides(value)
  local out = {}
  if type(value) ~= "table" then
    return out
  end

  for id, rawOverride in pairs(value) do
    if type(id) == "string" then
      local normalized = Normalize.normalizeOverrideEntry(rawOverride)
      if normalized then
        out[id] = normalized
      end
    end
  end

  return out
end

function Normalize.normalizeWindowPairings(value)
  local out = {}
  if type(value) ~= "table" then
    return out
  end

  for rawSlot, rawPairing in pairs(value) do
    local slot = Normalize.normalizePositiveInteger(tonumber(rawSlot))
    if slot and slot >= 1 and slot <= 9 then
      local record = SlotRecord.normalize(rawPairing)
      if record then
        out[slot] = record
      end
    end
  end

  return out
end

function Normalize.encodeWindowPairings(pairings)
  local payload = {}
  if type(pairings) ~= "table" then
    return payload
  end

  for rawSlot, rawPairing in pairs(pairings) do
    local slot = Normalize.normalizePositiveInteger(tonumber(rawSlot))
    if slot and slot >= 1 and slot <= 9 then
      local record = SlotRecord.normalize(rawPairing)
      if record then
        payload[tostring(slot)] = record
      end
    end
  end

  return payload
end

return Normalize
