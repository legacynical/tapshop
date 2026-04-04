local html = require("ui.html")
local icons = require("ui.popover.icons")

local Render = {}

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
}

local MOD_LABELS = {
  cmd = "⌘",
  alt = "⌥",
  ctrl = "⌃",
  shift = "⇧",
}

local function checkedAttr(value)
  if value then
    return "checked"
  end
  return ""
end

local function displayKey(key)
  local raw = tostring(key or "")
  return KEY_LABELS[raw] or string.upper(raw)
end

local function jsStringLiteral(value)
  return string.format("%q", tostring(value or ""))
end

local function comboHtml(mods, key)
  if key == false or key == nil or key == "" then
    return ""
  end

  local parts = {}
  for _, mod in ipairs(mods or {}) do
    parts[#parts + 1] = '<span class="keycap">' .. html.escape(MOD_LABELS[mod] or mod) .. "</span>"
  end
  parts[#parts + 1] = '<span class="keycap">' .. html.escape(displayKey(key)) .. "</span>"
  return table.concat(parts)
end

local function rowHtml(row, config)
  config = config or {}
  local hidePairButtons = config.hidePairButtons == true
  local unpairClass = row.canUnpair and "btn btn-unpair" or "btn btn-unpair off"
  local appIcon = icons.slotAppIconHtml(row.iconBundleID, row.iconAppName)
  local badgeHtml = ""
  local buttonsHtml = ""

  if row.badgeText and row.badgeText ~= "" then
    local badgeClass = "slot-badge"
    if row.state == "minimized" then
      badgeClass = badgeClass .. " is-minimized"
    elseif row.state == "fullscreen" then
      badgeClass = badgeClass .. " is-fullscreen"
    end
    badgeHtml = '<span class="' .. badgeClass .. '">' .. html.escape(row.badgeText) .. "</span>"
  end

  if not hidePairButtons then
    buttonsHtml = "        <div class=\"slot-buttons\">\n"
      .. "          <button class=\"btn btn-primary\" type=\"button\" onclick=\"sendAction('pair', { slot: "
      .. tostring(row.index)
      .. " })\">Pair</button>\n"
      .. "          <button class=\""
      .. unpairClass
      .. "\" type=\"button\" onclick=\"sendAction('unpair', { slot: "
      .. tostring(row.index)
      .. " })\">Unpair</button>\n"
      .. "        </div>\n"
  end

  return "      <div class=\"row\">\n"
    .. "        <span class=\"slot-num\">" .. tostring(row.index) .. "</span>\n"
    .. "        <span class=\"slot-label " .. row.className .. "\"><span class=\"slot-text-bg\">"
    .. appIcon
    .. "<span class=\"slot-text\">"
    .. html.escape(row.label)
    .. "</span>"
    .. "</span>"
    .. badgeHtml
    .. "</span>\n"
    .. buttonsHtml
    .. "      </div>\n"
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
  local quotedId = html.escape(jsStringLiteral(row.id))
  local resetHtml = ""
  if row.isModified then
    resetHtml = '<button type="button" class="btn hotkey-btn hotkey-reset-btn" title="Reset row" onclick="resetBinding('
      .. quotedId
      .. ')">Reset</button>'
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
    .. "                  <button type=\"button\" class=\"btn hotkey-btn hotkey-remap-btn\" title=\"Record shortcut\" onclick=\"openRemapModal("
    .. quotedId
    .. ")\">Remap</button>\n"
    .. "                  "
    .. resetHtml
    .. "\n"
    .. "                </div>\n"
    .. "              </div>\n"
end

local function generalTabHtml(config)
  return "            <div class=\"settings-panel\" data-settings-panel=\"general\">\n"
    .. "              <label class=\"settings-item\">\n"
    .. "                <input type=\"checkbox\" "
    .. checkedAttr(config.autoHideAfterAction)
    .. " onchange=\"sendAction('setAutoHideAfterAction', { slot: this.checked ? 1 : 0 })\">\n"
    .. "                <span>Auto-hide after pair/unpair</span>\n"
    .. "              </label>\n"
    .. "              <label class=\"settings-item\">\n"
    .. "                <input type=\"checkbox\" "
    .. checkedAttr(config.alwaysOnTop)
    .. " onchange=\"sendAction('setAlwaysOnTop', { slot: this.checked ? 1 : 0 })\">\n"
    .. "                <span>Always on top</span>\n"
    .. "              </label>\n"
    .. "              <label class=\"settings-item\">\n"
    .. "                <input type=\"checkbox\" "
    .. checkedAttr(config.hidePairButtons)
    .. " onchange=\"sendAction('setHidePairButtons', { slot: this.checked ? 1 : 0 })\">\n"
    .. "                <span>Hide pair/unpair buttons</span>\n"
    .. "              </label>\n"
    .. "              <div class=\"settings-slider-block\">\n"
    .. "                <div class=\"settings-slider-label\">Background opacity</div>\n"
    .. "                <input class=\"settings-slider\" type=\"range\" min=\"40\" max=\"100\" step=\"10\" value=\""
    .. tostring(config.opacityPercent)
    .. "\" onchange=\"sendAction('setPopoverOpacity', { slot: this.value })\">\n"
    .. "              </div>\n"
    .. "            </div>\n"
end

function Render.buildHotkeysListHtml(rows)
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

local function hotkeysTabHtml(ctx)
  local parts = {
    "            <div class=\"settings-panel\" data-settings-panel=\"hotkeys\">\n",
    "              <div class=\"hotkeys-helper\">Click Remap to record a new shortcut. Save applies it immediately. Clear leaves the action unassigned.</div>\n",
  }

  if ctx.settings.validation and ctx.settings.validation.message then
    parts[#parts + 1] = "              <div class=\"hotkeys-error\" data-hotkey-validation>"
    parts[#parts + 1] = html.escape(ctx.settings.validation.message)
    parts[#parts + 1] = "</div>\n"
  else
    parts[#parts + 1] = "              <div class=\"hotkeys-error is-hidden\" data-hotkey-validation></div>\n"
  end

  parts[#parts + 1] = "              <div class=\"hotkeys-list\" data-hotkeys-list>\n"
  parts[#parts + 1] = ctx.hotkeysHtml or Render.buildHotkeysListHtml(ctx.hotkeys or {})

  parts[#parts + 1] = "              </div>\n"
  parts[#parts + 1] = "            </div>\n"
  return table.concat(parts)
end

local function remapModalHtml()
  return [[
        <div class="remap-modal-shell" data-remap-shell hidden>
          <button type="button" class="remap-modal-backdrop" aria-label="Close remap recorder" onclick="cancelRemapModal()"></button>
          <div class="remap-modal" role="dialog" aria-modal="true">
            <div class="remap-modal-label" data-remap-label></div>
            <div class="remap-preview-row">
              <span class="remap-preview-title">Current</span>
              <div class="remap-preview-combo" data-remap-current></div>
            </div>
            <div class="remap-preview-row">
              <span class="remap-preview-title">New</span>
              <div class="remap-preview-combo" data-remap-draft></div>
            </div>
            <div class="hotkeys-error is-hidden" data-remap-error></div>
            <div class="remap-actions">
              <button type="button" class="btn btn-primary remap-save-btn" data-remap-save onclick="saveRemapModal()">Save</button>
              <button type="button" class="btn hotkey-btn" onclick="clearRemapBinding()">Clear</button>
              <button type="button" class="btn hotkey-btn" onclick="cancelRemapModal()">Cancel</button>
            </div>
          </div>
        </div>
]]
end

function Render.buildHtml(ctx)
  local settingsOpenClass = ctx.settings.open and " is-open" or ""
  local workspaceDimClass = ctx.settings.open and " is-dimmed" or ""
  local generalActive = ctx.settings.tab ~= "hotkeys" and " is-active" or ""
  local hotkeysActive = ctx.settings.tab == "hotkeys" and " is-active" or ""
  local headerAppIcon = icons.appIconHtml(ctx.headerBundleID, ctx.headerAppName, "header-active-win-icon", 16)

  local parts = {
    "<!DOCTYPE html>\n<html>\n<head>\n  <meta charset=\"utf-8\">\n  <style>\n",
    ctx.css,
    "\n  </style>\n</head>\n<body data-settings-open=\"",
    ctx.settings.open and "1" or "0",
    "\" data-settings-tab=\"",
    html.escape(ctx.settings.tab or "general"),
    "\" data-settings-scroll-top=\"",
    html.escape(tostring(ctx.settings.scrollTop or 0)),
    "\">\n  <div class=\"container\">\n    <div class=\"header\">\n      <div class=\"title-wrap\">\n        <span class=\"title\"><span class=\"title-trigger\">TAPS</span><span class=\"title-hop\">HOP</span></span>\n      </div>\n      <div class=\"header-active-win\">",
    headerAppIcon,
    "<span class=\"header-active-win-title\">",
    html.escape(ctx.primaryLine),
    "</span>\n      </div>\n      <div class=\"header-actions\">\n        ",
    icons.headerIconButton({
      className = "header-danger",
      icon = "clearAll",
      tooltip = "Unpair ALL",
      onclick = "sendAction('unpairAll')",
    }),
    "\n        ",
    icons.headerIconButton({
      className = "header-config",
      icon = "config",
      tooltip = "Settings",
      onclick = "toggleSettings()",
    }),
    "\n        ",
    icons.headerIconButton({
      className = "header-close",
      icon = "hide",
      tooltip = "Hide",
      onclick = "sendAction('close')",
    }),
    "\n      </div>\n    </div>\n    <div class=\"header-tooltip\" aria-hidden=\"true\"></div>\n    <div class=\"body-shell\">\n      <div class=\"workspace-list",
    workspaceDimClass,
    "\">\n",
  }

  for _, row in ipairs(ctx.rows) do
    parts[#parts + 1] = rowHtml(row, ctx.config)
  end

  parts[#parts + 1] = "      </div>\n"
  parts[#parts + 1] = "      <div class=\"settings-sheet"
  parts[#parts + 1] = settingsOpenClass
  parts[#parts + 1] = "\">\n"
  parts[#parts + 1] = "        <div class=\"settings-head\">\n"
  parts[#parts + 1] = "          <button type=\"button\" class=\"btn settings-back-btn\" onclick=\"closeSettings()\">Back</button>\n"
  parts[#parts + 1] = "          <div class=\"settings-head-main\">\n"
  parts[#parts + 1] = "            <div class=\"settings-tabs\">\n"
  parts[#parts + 1] = "              <button type=\"button\" data-settings-tab-button=\"general\" class=\"settings-tab"
  parts[#parts + 1] = generalActive
  parts[#parts + 1] = "\" onclick=\"switchSettingsTab('general')\">General</button>\n"
  parts[#parts + 1] = "              <button type=\"button\" data-settings-tab-button=\"hotkeys\" class=\"settings-tab"
  parts[#parts + 1] = hotkeysActive
  parts[#parts + 1] = "\" onclick=\"switchSettingsTab('hotkeys')\">Hotkeys</button>\n"
  parts[#parts + 1] = "            </div>\n"
  parts[#parts + 1] = "            <div class=\"settings-tools\">\n"
  parts[#parts + 1] = "              <input class=\"hotkey-search\" type=\"text\" value=\""
  parts[#parts + 1] = html.escape(ctx.settings.search or "")
  parts[#parts + 1] = "\" placeholder=\"Search hotkeys\" oninput=\"handleSearchInput(this.value)\">\n"
  parts[#parts + 1] = icons.headerIconButton({
    className = "settings-restore-btn",
    icon = "restore",
    tooltip = "Restore default",
    onclick = "resetAllHotkeys()",
  })
  parts[#parts + 1] = "\n            </div>\n"
  parts[#parts + 1] = "          </div>\n"
  parts[#parts + 1] = "        </div>\n"
  parts[#parts + 1] = "        <div class=\"settings-scroll\">\n"
  parts[#parts + 1] = generalTabHtml(ctx.config)
  parts[#parts + 1] = hotkeysTabHtml(ctx)
  parts[#parts + 1] = "        </div>\n"
  parts[#parts + 1] = remapModalHtml()
  parts[#parts + 1] = "      </div>\n"
  parts[#parts + 1] = "    </div>\n</div>\n<script>\n"
  parts[#parts + 1] = ctx.script
  parts[#parts + 1] = "\n</script>\n</body>\n</html>"

  return table.concat(parts)
end

return Render
