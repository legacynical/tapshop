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

local function normalizeRecovery(raw)
  if type(raw) ~= "table" then
    return nil
  end

  local closedAt = type(raw.closedAt) == "number" and raw.closedAt or nil
  if closedAt == nil then
    return nil
  end

  return {
    closedAt = closedAt,
  }
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
  local recovery = normalizeRecovery(raw.recovery)
  local record = {
    version = 2,
    kind = kind,
  }

  if kind == "paired" then
    local baseWindowId = positiveInt(raw.baseWindowId or raw.windowId)
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

  if not fingerprint or not fingerprint.bundleID or not fingerprint.titleNormalized or not recovery then
    return nil
  end

  record.fingerprint = fingerprint
  record.recovery = recovery
  return record
end

local function normalizeLegacyRecord(raw)
  if type(raw) == "number" then
    local baseWindowId = positiveInt(raw)
    if not baseWindowId then
      return nil
    end
    return {
      version = 2,
      kind = "paired",
      baseWindowId = baseWindowId,
    }
  end

  if type(raw) ~= "table" then
    return nil
  end

  local baseWindowId = positiveInt(raw.baseWindowId or raw.windowId)
  local fingerprint = normalizeFingerprint(raw)
  local recovery = type(raw.closedAt) == "number" and { closedAt = raw.closedAt } or nil

  if baseWindowId then
    local record = {
      version = 2,
      kind = "paired",
      baseWindowId = baseWindowId,
    }
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

  if fingerprint and fingerprint.bundleID and fingerprint.titleNormalized and recovery then
    return {
      version = 2,
      kind = "recoverable",
      fingerprint = fingerprint,
      recovery = recovery,
    }
  end

  return nil
end

function SlotRecord.normalize(raw)
  local record = normalizeV2Record(raw)
  if record then
    return record
  end
  return normalizeLegacyRecord(raw)
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
    recovery = cloneTable(binding.recovery),
  })
end

return SlotRecord
