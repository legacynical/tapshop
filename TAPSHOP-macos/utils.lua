local Utils = {}
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

local function normalizedSystemKeyCode(value)
  if type(value) ~= "number" then
    return nil
  end
  if value < 0 then
    return nil
  end
  return math.floor(value)
end

function Utils.isSystemKey(value)
  if type(value) ~= "string" or value == "" then
    return false
  end
  local upper = string.upper(value)
  if SYSTEM_KEY_NAMES[upper] == true then
    return true
  end
  return upper:match("^SYSTEM_%d+$") ~= nil
end

function Utils.systemKeyCodeLabel(keyCode)
  local normalized = normalizedSystemKeyCode(keyCode)
  if normalized == nil then
    return nil
  end
  return "SYSTEM_" .. tostring(normalized)
end

function Utils.normalizeRawKeyCode(keyCode)
  return Utils.systemKeyCodeLabel(keyCode)
end

function Utils.normalizeSystemKeyInfo(info)
  if type(info) ~= "table" then
    return nil
  end

  local knownKey = Utils.normalizeKey(info.key)
  if knownKey and Utils.isSystemKey(knownKey) then
    return knownKey
  end

  return Utils.systemKeyCodeLabel(info.keyCode)
end

function Utils.isSystemKeyPress(info)
  if type(info) ~= "table" then
    return false
  end
  return info.down ~= false
end

function Utils.normalizeKey(value)
  if value == false then
    return false
  end
  if type(value) ~= "string" or value == "" then
    return nil
  end
  local upper = string.upper(value)
  if Utils.isSystemKey(upper) then
    return upper
  end
  if value:match("^F%d+$") then
    return value
  end
  return string.lower(value)
end

return Utils
