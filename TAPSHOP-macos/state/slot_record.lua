local SlotRecord = {}

local VALID_KINDS = {
  paired = true,
  recoverable = true,
}

local function positiveInt(value)
  return type(value) == "number" and value >= 1 and math.floor(value) == value and value or nil
end

local function normalizeString(value)
  if type(value) ~= "string" or value == "" then
    return nil
  end
  return value
end

local function normalizeFingerprint(raw)
  if type(raw) ~= "table" then
    return nil
  end

  local fingerprint = {
    bundleID = normalizeString(raw.bundleID),
    appName = normalizeString(raw.appName),
    titleRaw = type(raw.titleRaw) == "string" and raw.titleRaw or nil,
    titleNormalized = normalizeString(raw.titleNormalized),
  }

  return next(fingerprint) ~= nil and fingerprint or nil
end

local function normalizeFullscreenTarget(raw)
  if type(raw) ~= "table" then
    return nil
  end

  local windowId = positiveInt(raw.windowId)
  local spaceId = positiveInt(raw.spaceId)
  if not windowId or not spaceId then
    return nil
  end

  return {
    windowId = windowId,
    spaceId = spaceId,
  }
end

local function cloneTable(source)
  local out = {}
  for key, value in pairs(source or {}) do
    if type(value) == "table" then
      out[key] = cloneTable(value)
    else
      out[key] = value
    end
  end
  return out
end

local function normalizeV2Record(raw)
  if type(raw) ~= "table" then
    return nil
  end

  local kind = raw.kind
  local version = raw.version
  if type(kind) ~= "string" or (version ~= nil and version ~= 2) then
    return nil
  end
  if not VALID_KINDS[kind] then
    return nil
  end

  local fingerprint = normalizeFingerprint(raw.fingerprint)
  local record = {
    version = 2,
    kind = kind,
  }

  if kind == "paired" then
    local baseWindowId = positiveInt(raw.baseWindowId)
    if not baseWindowId then
      return nil
    end
    record.baseWindowId = baseWindowId
    local baseSpaceId = positiveInt(raw.baseSpaceId)
    if baseSpaceId then
      record.baseSpaceId = baseSpaceId
    end
    local fullscreenTarget = normalizeFullscreenTarget(raw.fullscreenTarget)
    if fullscreenTarget then
      record.fullscreenTarget = fullscreenTarget
    end
    if fingerprint then
      record.fingerprint = fingerprint
    end
    return record
  end

  if not fingerprint or not fingerprint.bundleID or not fingerprint.titleNormalized then
    return nil
  end

  record.fingerprint = fingerprint
  return record
end

function SlotRecord.normalize(raw)
  return normalizeV2Record(raw)
end

function SlotRecord.encode(binding)
  if type(binding) ~= "table" then
    return nil
  end

  return normalizeV2Record({
    version = 2,
    kind = binding.kind,
    baseWindowId = binding.baseWindowId,
    baseSpaceId = binding.baseSpaceId,
    fullscreenTarget = cloneTable(binding.fullscreenTarget),
    fingerprint = cloneTable(binding.fingerprint),
  })
end

return SlotRecord
