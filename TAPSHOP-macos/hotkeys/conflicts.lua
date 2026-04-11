local Utils = require("utils")

local Conflicts = {}

local MOD_ORDER = {
  cmd = 1,
  alt = 2,
  ctrl = 3,
  shift = 4,
}

local function normalizeKey(key)
  return Utils.normalizeKey(key) or ""
end

function Conflicts.normalizeMods(mods)
  local normalized = {}
  for _, mod in ipairs(mods or {}) do
    local value = tostring(mod)
    if MOD_ORDER[value] then
      normalized[#normalized + 1] = value
    end
  end
  table.sort(normalized, function(a, b)
    return MOD_ORDER[a] < MOD_ORDER[b]
  end)

  local deduped = {}
  local last = nil
  for _, mod in ipairs(normalized) do
    if mod ~= last then
      deduped[#deduped + 1] = mod
    end
    last = mod
  end
  return deduped
end

function Conflicts.normalizeCombo(mods, key)
  local parts = Conflicts.normalizeMods(mods)
  parts[#parts + 1] = normalizeKey(key)
  return table.concat(parts, "+")
end

function Conflicts.detect(bindingsById)
  local comboMap = {}
  for id, binding in pairs(bindingsById or {}) do
    if binding.enabled and binding.key ~= false and binding.key ~= nil and binding.key ~= "" then
      local combo = Conflicts.normalizeCombo(binding.mods, binding.key)
      comboMap[combo] = comboMap[combo] or {}
      comboMap[combo][#comboMap[combo] + 1] = id
    end
  end

  local conflictsById = {}
  for _, ids in pairs(comboMap) do
    if #ids > 1 then
      for _, id in ipairs(ids) do
        conflictsById[id] = {}
        for _, otherId in ipairs(ids) do
          if otherId ~= id then
            conflictsById[id][#conflictsById[id] + 1] = otherId
          end
        end
      end
    end
  end
  return conflictsById
end

return Conflicts
