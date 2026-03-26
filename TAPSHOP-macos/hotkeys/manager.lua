local Conflicts = require("hotkeys.conflicts")
local Registry = require("hotkeys.registry")
local Utils = require("utils")

local HotkeyManager = {}
HotkeyManager.__index = HotkeyManager

local SYSTEM_SHORTCUTS = {
  ["cmd+h"] = "Hide Application",
  ["cmd+q"] = "Quit Application",
  ["cmd+space"] = "Spotlight",
  ["cmd+tab"] = "App Switcher",
  ["cmd+shift+q"] = "Log Out",
  ["cmd+alt+esc"] = "Force Quit",
  ["ctrl+up"] = "Mission Control",
  ["ctrl+down"] = "App Expose",
  ["ctrl+left"] = "Switch Space Left",
  ["ctrl+right"] = "Switch Space Right",
}

local FALLBACK_BINDING_ID = "popover.toggle"
local FALLBACK_MODS = { "cmd", "alt" }
local FALLBACK_KEY = "`"
local FALLBACK_WINDOW_SECONDS = 0.8

local function cloneArray(values)
  local out = {}
  for _, value in ipairs(values or {}) do
    out[#out + 1] = value
  end
  return out
end

local function cloneBinding(binding)
  return {
    id = binding.id,
    group = binding.group,
    label = binding.label,
    mods = cloneArray(binding.mods),
    key = binding.key,
    action = binding.action,
    args = cloneArray(binding.args),
    guarded = binding.guarded == true,
    enabled = binding.enabled ~= false,
  }
end

local function bindingUsesDefaultPopoverShortcut(binding)
  if not binding then
    return false
  end
  return Conflicts.normalizeCombo(binding.mods, binding.key) == Conflicts.normalizeCombo(FALLBACK_MODS, FALLBACK_KEY)
end

local function keyIsAvailable(key)
  if key == false or key == nil or key == "" then
    return false
  end
  local map = hs.keycodes.map
  local raw = tostring(key or "")
  if raw:match("^F%d+$") then
    return map[raw] ~= nil
  end
  local lowered = string.lower(raw)
  if raw == lowered then
    return map[raw] ~= nil
  end
  return map[raw] ~= nil or map[lowered] ~= nil
end

local function bindHotkeySafe(mods, key, fn)
  local ok, bindingOrErr = pcall(hs.hotkey.bind, mods, key, fn)
  if ok then
    return bindingOrErr
  end
  hs.printf("[tapshop-hotkeys] failed to bind %s: %s", tostring(key), tostring(bindingOrErr))
  return nil
end

local function isBindingAssigned(binding)
  return binding
    and binding.enabled ~= false
    and binding.key ~= false
    and binding.key ~= nil
    and binding.key ~= ""
end

function HotkeyManager.new(app, settingsStore, settingsKey)
  local defaults = Registry.bindings()
  local defaultsById = {}
  for _, binding in ipairs(defaults) do
    defaultsById[binding.id] = cloneBinding(binding)
  end

  local self = setmetatable({
    app = app,
    settingsStore = settingsStore,
    settingsKey = settingsKey,
    defaults = defaults,
    defaultsById = defaultsById,
    liveHotkeys = {},
    resolvedById = {},
    conflictsById = {},
    fallbackHotkey = nil,
    fallbackPresses = {},
    uiStateCache = nil,
    uiStateDirty = true,
    htmlCache = nil,
    htmlCacheDirty = true,
  }, HotkeyManager)

  self:resolve()
  return self
end

function HotkeyManager:_loadOverrides()
  return self.settingsStore.getHotkeyOverrides(self.settingsKey)
end

function HotkeyManager:_saveOverrides(overrides)
  self.settingsStore.setHotkeyOverrides(self.settingsKey, overrides)
end

function HotkeyManager:invalidateUiCache()
  self.uiStateCache = nil
  self.uiStateDirty = true
  self.htmlCache = nil
  self.htmlCacheDirty = true
end

function HotkeyManager:resolve()
  local overrides = self:_loadOverrides()
  local resolvedById = {}
  for _, defaultBinding in ipairs(self.defaults) do
    local merged = cloneBinding(defaultBinding)
    local override = overrides[defaultBinding.id]
    if override then
      if override.mods ~= nil then
        merged.mods = Conflicts.normalizeMods(override.mods)
      end
      if override.key ~= nil then
        merged.key = override.key
      end
      if override.enabled ~= nil then
        merged.enabled = override.enabled == true
        if override.enabled == false then
          merged.mods = {}
          merged.key = false
        end
      end
    end
    resolvedById[merged.id] = merged
  end
  self.resolvedById = resolvedById
  self.conflictsById = Conflicts.detect(resolvedById)

  local popoverBinding = resolvedById[FALLBACK_BINDING_ID]
  if popoverBinding and not bindingUsesDefaultPopoverShortcut(popoverBinding) then
    local reservedCombo = Conflicts.normalizeCombo(FALLBACK_MODS, FALLBACK_KEY)
    for id, binding in pairs(resolvedById) do
      if id ~= FALLBACK_BINDING_ID and isBindingAssigned(binding) and Conflicts.normalizeCombo(binding.mods, binding.key) == reservedCombo then
        self.conflictsById[id] = self.conflictsById[id] or {}
        self.conflictsById[id][#self.conflictsById[id] + 1] = FALLBACK_BINDING_ID
        self.conflictsById[FALLBACK_BINDING_ID] = self.conflictsById[FALLBACK_BINDING_ID] or {}
        self.conflictsById[FALLBACK_BINDING_ID][#self.conflictsById[FALLBACK_BINDING_ID] + 1] = id
      end
    end
  end
end

function HotkeyManager:_dispatch(binding)
  local method = self.app[binding.action]
  if type(method) ~= "function" then
    hs.printf("[tapshop-hotkeys] unknown action %s for %s", tostring(binding.action), tostring(binding.id))
    return
  end
  method(self.app, table.unpack(binding.args or {}))
end

function HotkeyManager:_deleteBinding(id)
  local hotkey = self.liveHotkeys[id]
  if hotkey and hotkey.delete then
    hotkey:delete()
  end
  self.liveHotkeys[id] = nil
end

function HotkeyManager:_deleteFallback()
  if self.fallbackHotkey and self.fallbackHotkey.delete then
    self.fallbackHotkey:delete()
  end
  self.fallbackHotkey = nil
  self.fallbackPresses = {}
end

function HotkeyManager:_bindFallbackIfNeeded()
  self:_deleteFallback()
  local binding = self.resolvedById[FALLBACK_BINDING_ID]
  if bindingUsesDefaultPopoverShortcut(binding) then
    return
  end

  local windowSeconds = FALLBACK_WINDOW_SECONDS
  self.fallbackHotkey = bindHotkeySafe(FALLBACK_MODS, FALLBACK_KEY, function()
    local now = hs.timer.secondsSinceEpoch()
    local presses = {}
    for _, ts in ipairs(self.fallbackPresses) do
      if (now - ts) <= windowSeconds then
        presses[#presses + 1] = ts
      end
    end
    presses[#presses + 1] = now
    self.fallbackPresses = presses
    if #presses >= 3 then
      self.fallbackPresses = {}
      if self.app and self.app.showPopover then
        self.app:showPopover()
      end
    end
  end)
end

function HotkeyManager:bindAll()
  self:unbindAll()
  self:resolve()

  for _, binding in ipairs(self.defaults) do
    local resolved = self.resolvedById[binding.id]
    if resolved and isBindingAssigned(resolved) and not self.conflictsById[resolved.id] then
      if not keyIsAvailable(resolved.key) then
        goto continue
      end
      self.liveHotkeys[resolved.id] = bindHotkeySafe(resolved.mods, resolved.key, function()
        self:_dispatch(resolved)
      end)
    end
    ::continue::
  end

  self:_bindFallbackIfNeeded()
end

function HotkeyManager:unbindAll()
  for id, hotkey in pairs(self.liveHotkeys) do
    if hotkey and hotkey.delete then
      hotkey:delete()
    end
    self.liveHotkeys[id] = nil
  end
  self:_deleteFallback()
end

function HotkeyManager:_warningFor(binding)
  if not isBindingAssigned(binding) then
    return nil
  end
  local combo = Conflicts.normalizeCombo(binding.mods, binding.key)
  if SYSTEM_SHORTCUTS[combo] then
    return "Likely reserved by macOS: " .. SYSTEM_SHORTCUTS[combo]
  end
  if not keyIsAvailable(binding.key) then
    return "Key is unavailable in the current keyboard layout."
  end
  return nil
end

function HotkeyManager:_buildUiRows()
  local overrides = self:_loadOverrides()
  local rows = {}
  for _, defaultBinding in ipairs(self.defaults) do
    local binding = self.resolvedById[defaultBinding.id]
    local warning = self:_warningFor(binding)
    rows[#rows + 1] = {
      id = binding.id,
      group = binding.group,
      label = binding.label,
      mods = cloneArray(binding.mods),
      key = binding.key,
      isAssigned = isBindingAssigned(binding),
      enabled = binding.enabled == true,
      guarded = binding.guarded == true,
      isModified = overrides[binding.id] ~= nil,
      isUnavailable = isBindingAssigned(binding) and not keyIsAvailable(binding.key),
      conflictIds = cloneArray(self.conflictsById[binding.id]),
      warning = warning,
    }
  end
  return rows
end

function HotkeyManager:_buildUiState()
  self:resolve()
  return {
    rows = self:_buildUiRows(),
    conflictsById = self.conflictsById,
    overrides = self:_loadOverrides(),
    recordingSupported = true,
  }
end

function HotkeyManager:warmUiState()
  self:getUiState()
end

function HotkeyManager:getUiState()
  if self.uiStateDirty or not self.uiStateCache then
    self.uiStateCache = self:_buildUiState()
    self.uiStateDirty = false
  end
  return self.uiStateCache
end

function HotkeyManager:getHotkeyHtmlCached(rendererFn)
  if type(rendererFn) ~= "function" then
    return self.htmlCache
  end
  if self.htmlCacheDirty or not self.htmlCache then
    self.htmlCache = rendererFn(self:getUiState().rows or {})
    self.htmlCacheDirty = false
  end
  return self.htmlCache
end

function HotkeyManager:warmHtml(rendererFn)
  if type(rendererFn) == "function" then
    self:getHotkeyHtmlCached(rendererFn)
  else
    self:warmUiState()
  end
end

function HotkeyManager:_buildOverride(binding)
  local defaultBinding = self.defaultsById[binding.id]
  local override = {}
  if binding.key == false then
    override.mods = {}
    override.key = false
  elseif Conflicts.normalizeCombo(binding.mods, binding.key) ~= Conflicts.normalizeCombo(defaultBinding.mods, defaultBinding.key) then
    override.mods = cloneArray(binding.mods)
    override.key = binding.key
  end
  if binding.enabled ~= defaultBinding.enabled then
    override.enabled = binding.enabled == true
  end
  if next(override) == nil then
    return nil
  end
  return override
end

function HotkeyManager:_applyCandidate(candidateById)
  local conflictsById = Conflicts.detect(candidateById)
  if next(conflictsById) ~= nil then
    return false, {
      code = "conflict",
      ids = conflictsById,
      message = "Shortcut conflicts with another TAPSHOP binding.",
    }
  end

  local popoverBinding = candidateById[FALLBACK_BINDING_ID]
  if not popoverBinding then
    return false, {
      code = "popover_required",
      ids = {
        [FALLBACK_BINDING_ID] = {},
      },
      message = "The popover shortcut is missing.",
    }
  end

  if not bindingUsesDefaultPopoverShortcut(popoverBinding) then
    local reservedCombo = Conflicts.normalizeCombo(FALLBACK_MODS, FALLBACK_KEY)
    for id, binding in pairs(candidateById) do
      if id ~= FALLBACK_BINDING_ID and isBindingAssigned(binding) and Conflicts.normalizeCombo(binding.mods, binding.key) == reservedCombo then
        return false, {
          code = "popover_fallback_reserved",
          ids = {
            [id] = { FALLBACK_BINDING_ID },
            [FALLBACK_BINDING_ID] = { id },
          },
          message = "Cmd+Option+` is reserved for the hidden popover recovery shortcut.",
        }
      end
    end
  end

  return true, nil
end

function HotkeyManager:updateBinding(id, payload)
  local current = self.resolvedById[id]
  local defaultBinding = self.defaultsById[id]
  if not current or not defaultBinding then
    return {
      ok = false,
      code = "missing_binding",
      ids = {
        [id] = {},
      },
      message = "Unknown hotkey binding.",
    }
  end

  local candidateById = {}
  for _, binding in ipairs(self.defaults) do
    candidateById[binding.id] = cloneBinding(self.resolvedById[binding.id])
  end

  local candidate = candidateById[id]
  if payload.mods ~= nil then
    candidate.mods = Conflicts.normalizeMods(payload.mods)
  end
  if payload.key ~= nil then
    local normalizedKey = Utils.normalizeKey(payload.key)
    if normalizedKey == nil then
      return {
        ok = false,
        code = "invalid_key",
        ids = {
          [id] = {},
        },
        message = "Shortcut key is invalid.",
      }
    end
    if normalizedKey ~= false and not keyIsAvailable(normalizedKey) then
      return {
        ok = false,
        code = "unavailable_key",
        ids = {
          [id] = {},
        },
        message = "Shortcut key is unavailable in the current keyboard layout.",
      }
    end
    candidate.key = normalizedKey
    if normalizedKey == false then
      candidate.mods = {}
      candidate.enabled = true
    end
  end
  if payload.enabled ~= nil then
    candidate.enabled = payload.enabled == true
  end

  local ok, err = self:_applyCandidate(candidateById)
  if not ok then
    return {
      ok = false,
      code = err.code,
      ids = err.ids,
      message = err.message,
    }
  end

  local overrides = self:_loadOverrides()
  local override = self:_buildOverride(candidate)
  if override then
    overrides[id] = override
  else
    overrides[id] = nil
  end
  self:_saveOverrides(overrides)
  self:invalidateUiCache()
  self:bindAll()

  return {
    ok = true,
    warning = self:_warningFor(self.resolvedById[id]),
  }
end

function HotkeyManager:resetBinding(id)
  local overrides = self:_loadOverrides()
  overrides[id] = nil
  self:_saveOverrides(overrides)
  self:invalidateUiCache()
  self:bindAll()
  return {
    ok = true,
  }
end

function HotkeyManager:resetAll()
  self.settingsStore.clearSetting(self.settingsKey)
  self:invalidateUiCache()
  self:bindAll()
  return {
    ok = true,
  }
end

return HotkeyManager
