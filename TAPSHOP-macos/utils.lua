local Utils = {}

function Utils.normalizeKey(value)
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

Utils.PAIRING_FIELDS = {
  "windowId",
  "bundleID",
  "appName",
  "titleRaw",
  "titleNormalized",
  "displayTitle",
  "closedAt",
  "fullscreenWindowId",
  "fullscreenSpaceId",
  "fullscreenActive",
  "lastKnownSpaceId",
}

local positiveInt = function(v)
  return type(v) == "number" and v >= 1 and math.floor(v) == v and math.floor(v) or nil
end

local PAIRING_FIELD_NORMALIZERS = {
  windowId = positiveInt,
  bundleID = function(v) return type(v) == "string" and v or nil end,
  appName = function(v) return type(v) == "string" and v or nil end,
  titleRaw = function(v) return type(v) == "string" and v or nil end,
  titleNormalized = function(v) return type(v) == "string" and v or nil end,
  displayTitle = function(v) return type(v) == "string" and v or nil end,
  closedAt = function(v) return type(v) == "number" and v or nil end,
  fullscreenWindowId = positiveInt,
  fullscreenSpaceId = positiveInt,
  fullscreenActive = function(v) return v == true and true or nil end,
  lastKnownSpaceId = positiveInt,
}

function Utils.buildPairingRecord(source)
  if type(source) ~= "table" then
    return nil
  end
  local record = {}
  local hasValue = false
  for _, field in ipairs(Utils.PAIRING_FIELDS) do
    local raw = source[field]
    if raw ~= nil then
      local normalizer = PAIRING_FIELD_NORMALIZERS[field]
      local value
      if normalizer then
        value = normalizer(raw)
      else
        value = raw
      end
      if value ~= nil then
        record[field] = value
        hasValue = true
      end
    end
  end
  return hasValue and record or nil
end

function Utils.extractPairingRecord(source)
  if type(source) ~= "table" then
    return nil
  end
  local record = {}
  local hasValue = false
  for _, field in ipairs(Utils.PAIRING_FIELDS) do
    if source[field] ~= nil then
      record[field] = source[field]
      hasValue = true
    end
  end
  return hasValue and record or nil
end

return Utils
