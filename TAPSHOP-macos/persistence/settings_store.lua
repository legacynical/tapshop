local JsonDisk = require("persistence.json_disk")
local Normalize = require("persistence.normalize")
local Paths = require("persistence.paths")

local SettingsStore = {}

local SETTINGS_SCHEMA_VERSION = 1
local SETTINGS_DEFAULTS = {
  schemaVersion = SETTINGS_SCHEMA_VERSION,
  popover = {
    autoHideAfterAction = false,
    alwaysOnTop = true,
    hidePairButtons = false,
    backgroundOpacity = 0.85,
  },
  workspace = {
    recoverClosedWindows = true,
  },
  hotkeys = {
    overrides = {},
  },
}

local settingsData = nil
local initialized = false

local function settingsPath()
  return Paths.settings()
end

local function clone(value)
  return Normalize.deepCopy(value)
end

local function normalizeSettings(raw)
  local normalized = Normalize.deepCopy(SETTINGS_DEFAULTS)
  local source = type(raw) == "table" and raw or {}

  if type(source.popover) == "table" then
    if type(source.popover.autoHideAfterAction) == "boolean" then
      normalized.popover.autoHideAfterAction = source.popover.autoHideAfterAction
    end
    if type(source.popover.alwaysOnTop) == "boolean" then
      normalized.popover.alwaysOnTop = source.popover.alwaysOnTop
    end
    if type(source.popover.hidePairButtons) == "boolean" then
      normalized.popover.hidePairButtons = source.popover.hidePairButtons
    end
    local opacity = Normalize.clampOpacity(source.popover.backgroundOpacity)
    if opacity ~= nil then
      normalized.popover.backgroundOpacity = opacity
    end
  end

  if type(source.workspace) == "table" and type(source.workspace.recoverClosedWindows) == "boolean" then
    normalized.workspace.recoverClosedWindows = source.workspace.recoverClosedWindows
  end

  if type(source.hotkeys) == "table" then
    normalized.hotkeys.overrides = Normalize.normalizeHotkeyOverrides(source.hotkeys.overrides)
  end

  return normalized, not Normalize.deepEqual(source, normalized)
end

local function inspect()
  local path = settingsPath()
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

  local normalized, changed = normalizeSettings(raw)
  return {
    path = path,
    data = normalized,
    exists = meta.exists == true,
    recovered = meta.recovered == true,
    changed = changed,
  }
end

local function save(data)
  local normalized = normalizeSettings(data)
  local ok, err = JsonDisk.write(settingsPath(), normalized)
  if not ok then
    return nil, err
  end
  return normalized
end

local function persist()
  local saved, err = save(settingsData)
  if not saved then
    error("failed to persist settings.json: " .. tostring(err))
  end
  settingsData = saved
  return settingsData
end

local function ensureInitialized()
  if initialized then
    return
  end

  local state = inspect()
  if not state.exists or state.recovered or state.changed then
    local saved, err = save(state.data)
    if not saved then
      error("failed to initialize settings.json: " .. tostring(err))
    end
    settingsData = saved
  else
    settingsData = state.data
  end

  initialized = true
end

SettingsStore.schemaVersion = SETTINGS_SCHEMA_VERSION

function SettingsStore.path()
  return settingsPath()
end

function SettingsStore.defaultData()
  return clone(SETTINGS_DEFAULTS)
end

function SettingsStore.bootstrap()
  ensureInitialized()
  return clone(settingsData)
end

function SettingsStore.getHotkeyOverrides()
  ensureInitialized()
  return clone(settingsData.hotkeys.overrides)
end

function SettingsStore.setHotkeyOverrides(overrides)
  ensureInitialized()
  settingsData.hotkeys.overrides = clone(overrides)
  persist()
  return clone(settingsData.hotkeys.overrides)
end

function SettingsStore.resetHotkeyOverrides()
  ensureInitialized()
  settingsData.hotkeys.overrides = {}
  persist()
  return {}
end

function SettingsStore.getPopoverAutoHideAfterAction()
  ensureInitialized()
  return settingsData.popover.autoHideAfterAction == true
end

function SettingsStore.setPopoverAutoHideAfterAction(value)
  ensureInitialized()
  settingsData.popover.autoHideAfterAction = value == true
  persist()
  return settingsData.popover.autoHideAfterAction
end

function SettingsStore.getPopoverAlwaysOnTop()
  ensureInitialized()
  return settingsData.popover.alwaysOnTop == true
end

function SettingsStore.setPopoverAlwaysOnTop(value)
  ensureInitialized()
  settingsData.popover.alwaysOnTop = value == true
  persist()
  return settingsData.popover.alwaysOnTop
end

function SettingsStore.getPopoverHidePairButtons()
  ensureInitialized()
  return settingsData.popover.hidePairButtons == true
end

function SettingsStore.setPopoverHidePairButtons(value)
  ensureInitialized()
  settingsData.popover.hidePairButtons = value == true
  persist()
  return settingsData.popover.hidePairButtons
end

function SettingsStore.getRecoverClosedWindows()
  ensureInitialized()
  return settingsData.workspace.recoverClosedWindows == true
end

function SettingsStore.setRecoverClosedWindows(value)
  ensureInitialized()
  settingsData.workspace.recoverClosedWindows = value == true
  persist()
  return settingsData.workspace.recoverClosedWindows
end

function SettingsStore.getPopoverBackgroundOpacity()
  ensureInitialized()
  return settingsData.popover.backgroundOpacity
end

function SettingsStore.setPopoverBackgroundOpacity(value)
  ensureInitialized()
  settingsData.popover.backgroundOpacity = value
  persist()
  return settingsData.popover.backgroundOpacity
end

return SettingsStore
