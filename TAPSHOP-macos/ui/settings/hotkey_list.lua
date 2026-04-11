local html = require("ui.html")
local systemKeyDisplay = require("ui.settings.system_key_display")

local HotkeyList = {}

local KEY_LABELS = {
  left = "Left",
  right = "Right",
  up = "Up",
  down = "Down",
  ["return"] = "Return",
  delete = "Delete",
  forwarddelete = "Forward Delete",
  escape = "Esc",
  space = "Space",
  tab = "Tab",
  ["`"] = "`",
  [","] = ",",
  ["."] = ".",
  BRIGHTNESS_UP = "Brightness Up",
  BRIGHTNESS_DOWN = "Brightness Down",
  SOUND_UP = "Volume Up",
  SOUND_DOWN = "Volume Down",
  PLAY = "Play/Pause",
  LAUNCH_PANEL = "Launchpad",
}

local MOD_LABELS = {
  cmd = "⌘",
  alt = "⌥",
  ctrl = "⌃",
  shift = "⇧",
}

local MOD_TITLES = {
  cmd = "Command",
  alt = "Option",
  ctrl = "Control",
  shift = "Shift",
}

local function titleCaseWords(value)
  local lowered = string.lower(value or "")
  local parts = {}
  for part in lowered:gmatch("[^_]+") do
    parts[#parts + 1] = part:gsub("^%l", string.upper)
  end
  return table.concat(parts, " ")
end

local function displayKey(key)
  local raw = tostring(key or "")
  local systemMeta = systemKeyDisplay.get(raw)
  if systemMeta then
    return systemMeta.label
  end
  if KEY_LABELS[raw] then
    return KEY_LABELS[raw]
  end
  local systemCode = raw:match("^SYSTEM_(%d+)$")
  if systemCode then
    return "SYSTEM_" .. systemCode
  end
  if raw:match("^[A-Z0-9_]+$") and raw:find("_", 1, true) then
    return titleCaseWords(raw)
  end
  return string.upper(raw)
end

local function keycapHtml(content, title, className)
  local classes = "keycap"
  if className and className ~= "" then
    classes = classes .. " " .. className
  end
  return '<span class="' .. classes .. '" title="' .. html.escape(title or "") .. '">' .. content .. "</span>"
end

local function comboHtml(mods, key)
  if key == false or key == nil or key == "" then
    return ""
  end

  local parts = {}
  for _, mod in ipairs(mods or {}) do
    parts[#parts + 1] = keycapHtml(
      html.escape(MOD_LABELS[mod] or mod),
      MOD_TITLES[mod] or tostring(mod),
      nil
    )
  end

  local rawKey = tostring(key or "")
  local systemMeta = systemKeyDisplay.get(rawKey)
  if systemMeta then
    parts[#parts + 1] = keycapHtml(systemMeta.svg, systemMeta.label, "keycap-system")
  else
    local label = displayKey(rawKey)
    parts[#parts + 1] = keycapHtml(html.escape(label), label, nil)
  end

  return table.concat(parts)
end

local function hotkeyRowHtml(row)
  local classes = { "hotkey-row" }
  if row.isModified then
    classes[#classes + 1] = "is-modified"
  end
  if row.isUnavailable then
    classes[#classes + 1] = "is-unavailable"
  end
  if row.warning then
    classes[#classes + 1] = "has-warning"
  end
  if #(row.conflictIds or {}) > 0 then
    classes[#classes + 1] = "has-conflict"
  end

  local comboTitle = row.isAssigned and "Current shortcut" or "No shortcut assigned"
  local comboClass = row.isAssigned and "hotkey-combo" or "hotkey-combo hotkey-combo-empty"
  local comboInner = row.isAssigned and comboHtml(row.mods, row.key) or '<span class="hotkey-unset">(unset)</span>'
  local rawKey = row.isAssigned and tostring(row.key) or ""
  local comboSearch = row.isAssigned and string.lower(table.concat(row.mods or {}, " ") .. " " .. rawKey) or ""
  local resetHtml = ""
  if row.isModified then
    resetHtml = '<button type="button" class="btn hotkey-btn hotkey-reset-btn" title="Reset to default" data-hotkey-action="reset" data-hotkey-id="'
      .. html.escape(row.id)
      .. '">↺</button>'
  end

  return "              <div class=\""
    .. table.concat(classes, " ")
    .. "\" data-hotkey-row data-id=\""
    .. html.escape(row.id)
    .. "\" data-label=\""
    .. html.escape(string.lower(row.label))
    .. "\" data-group=\""
    .. html.escape(string.lower(row.group))
    .. "\" data-key=\""
    .. html.escape(rawKey)
    .. "\" data-mods=\""
    .. html.escape(table.concat(row.mods or {}, " "))
    .. "\" data-assigned=\""
    .. (row.isAssigned and "1" or "0")
    .. "\" data-combo=\""
    .. html.escape(comboSearch)
    .. "\">\n"
    .. "                <div class=\"hotkey-main\">\n"
    .. "                  <span class=\"hotkey-label\">"
    .. html.escape(row.label)
    .. "</span>\n"
    .. "                  <div class=\""
    .. comboClass
    .. "\" title=\""
    .. html.escape(comboTitle)
    .. "\">"
    .. comboInner
    .. "</div>\n"
    .. "                </div>\n"
    .. "                <div class=\"hotkey-actions\">\n"
    .. "                  "
    .. resetHtml
    .. "\n"
    .. "                  <button type=\"button\" class=\"btn hotkey-btn hotkey-remap-btn\" title=\"Record shortcut\" data-hotkey-action=\"remap\" data-hotkey-id=\""
    .. html.escape(row.id)
    .. "\">Remap</button>\n"
    .. "                </div>\n"
    .. "              </div>\n"
end

function HotkeyList.buildHtml(rows)
  local parts = {}
  local currentGroup = nil
  for index, row in ipairs(rows or {}) do
    if row.group ~= currentGroup then
      currentGroup = row.group
      parts[#parts + 1] = "                <section class=\"hotkey-group\" data-hotkey-group=\""
      parts[#parts + 1] = html.escape(string.lower(row.group))
      parts[#parts + 1] = "\">\n"
      parts[#parts + 1] = "                  <div class=\"hotkey-group-title\">"
      parts[#parts + 1] = html.escape(row.group)
      parts[#parts + 1] = "</div>\n"
    end

    parts[#parts + 1] = hotkeyRowHtml(row)

    local nextRow = rows[index + 1]
    if not nextRow or nextRow.group ~= currentGroup then
      parts[#parts + 1] = "                </section>\n"
    end
  end

  return table.concat(parts)
end

return HotkeyList
