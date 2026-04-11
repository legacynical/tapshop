local PersistedSize = {}

function PersistedSize.load(settingsStore, key, legacyKeys)
  local size = settingsStore.getSize(key)
  if size then
    for _, legacyKey in ipairs(legacyKeys or {}) do
      settingsStore.clearSetting(legacyKey)
    end
    return size
  end

  if hs.settings.get(key) ~= nil then
    settingsStore.clearSetting(key)
  end

  for _, legacyKey in ipairs(legacyKeys or {}) do
    local legacySize = settingsStore.getSize(legacyKey)
    if legacySize then
      settingsStore.setSize(key, legacySize)
      for _, clearKey in ipairs(legacyKeys or {}) do
        settingsStore.clearSetting(clearKey)
      end
      return legacySize
    end
    if hs.settings.get(legacyKey) ~= nil then
      settingsStore.clearSetting(legacyKey)
    end
  end

  return nil
end

return PersistedSize
