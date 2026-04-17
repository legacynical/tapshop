local JsonDisk = require("persistence.json_disk")
local Normalize = require("persistence.normalize")
local Paths = require("persistence.paths")

local AppDataStore = {}

local APPDATA_SCHEMA_VERSION = 1
local APPDATA_DEFAULTS = {
  schemaVersion = APPDATA_SCHEMA_VERSION,
  workspace = {
    pairings = {},
  },
  windows = {
    popover = {
      topLeft = nil,
      size = nil,
    },
    settings = {
      topLeft = nil,
      size = nil,
    },
  },
}

local appdata = nil
local initialized = false

local function appdataPath()
  return Paths.appdata()
end

local function clone(value)
  return Normalize.deepCopy(value)
end

local function normalizeAppdata(raw)
  local normalized = Normalize.deepCopy(APPDATA_DEFAULTS)
  local source = type(raw) == "table" and raw or {}

  if type(source.workspace) == "table" then
    normalized.workspace.pairings = Normalize.encodeWindowPairings(source.workspace.pairings)
  end

  if type(source.windows) == "table" then
    if type(source.windows.popover) == "table" then
      normalized.windows.popover.topLeft = Normalize.normalizePoint(source.windows.popover.topLeft)
      normalized.windows.popover.size = Normalize.normalizeSize(source.windows.popover.size)
    end
    if type(source.windows.settings) == "table" then
      normalized.windows.settings.topLeft = Normalize.normalizePoint(source.windows.settings.topLeft)
      normalized.windows.settings.size = Normalize.normalizeSize(source.windows.settings.size)
    end
  end

  return normalized, not Normalize.deepEqual(source, normalized)
end

local function inspect()
  local path = appdataPath()
  local raw, meta = JsonDisk.read(path)
  if meta.invalid then
    JsonDisk.backupCorrupt(path)
    raw = nil
    meta = {
      exists = false,
      invalid = false,
      recovered = true,
    }
  end

  local normalized, changed = normalizeAppdata(raw)
  return {
    path = path,
    data = normalized,
    exists = meta.exists == true,
    recovered = meta.recovered == true,
    changed = changed,
  }
end

local function save(data)
  local normalized = normalizeAppdata(data)
  local ok, err = JsonDisk.write(appdataPath(), normalized)
  if not ok then
    return nil, err
  end
  return normalized
end

local function persist()
  local saved, err = save(appdata)
  if not saved then
    error("failed to persist appdata.json: " .. tostring(err))
  end
  appdata = saved
  return appdata
end

local function ensureInitialized()
  if initialized then
    return
  end

  local state = inspect()
  if not state.exists or state.recovered or state.changed then
    local saved, err = save(state.data)
    if not saved then
      error("failed to initialize appdata.json: " .. tostring(err))
    end
    appdata = saved
  else
    appdata = state.data
  end

  initialized = true
end

AppDataStore.schemaVersion = APPDATA_SCHEMA_VERSION

function AppDataStore.path()
  return appdataPath()
end

function AppDataStore.defaultData()
  return clone(APPDATA_DEFAULTS)
end

function AppDataStore.bootstrap()
  ensureInitialized()
  return clone(appdata)
end

function AppDataStore.getWindowPairings()
  ensureInitialized()
  return Normalize.normalizeWindowPairings(appdata.workspace.pairings)
end

function AppDataStore.setWindowPairings(pairings)
  ensureInitialized()
  appdata.workspace.pairings = clone(pairings)
  persist()
  return AppDataStore.getWindowPairings()
end

function AppDataStore.getPopoverTopLeft()
  ensureInitialized()
  return clone(appdata.windows.popover.topLeft)
end

function AppDataStore.setPopoverTopLeft(point)
  ensureInitialized()
  appdata.windows.popover.topLeft = clone(point)
  persist()
  return clone(appdata.windows.popover.topLeft)
end

function AppDataStore.getPopoverSize()
  ensureInitialized()
  return clone(appdata.windows.popover.size)
end

function AppDataStore.setPopoverSize(size)
  ensureInitialized()
  appdata.windows.popover.size = clone(size)
  persist()
  return clone(appdata.windows.popover.size)
end

function AppDataStore.getSettingsWindowTopLeft()
  ensureInitialized()
  return clone(appdata.windows.settings.topLeft)
end

function AppDataStore.setSettingsWindowTopLeft(point)
  ensureInitialized()
  appdata.windows.settings.topLeft = clone(point)
  persist()
  return clone(appdata.windows.settings.topLeft)
end

function AppDataStore.getSettingsWindowSize()
  ensureInitialized()
  return clone(appdata.windows.settings.size)
end

function AppDataStore.setSettingsWindowSize(size)
  ensureInitialized()
  appdata.windows.settings.size = clone(size)
  persist()
  return clone(appdata.windows.settings.size)
end

return AppDataStore
