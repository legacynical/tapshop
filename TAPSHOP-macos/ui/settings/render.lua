local hotkeyList = require("ui.settings.hotkey_list")
local html = require("ui.html")
local icons = require("ui.popover.icons")
local systemKeyDisplay = require("ui.settings.system_key_display")
local hs = hs

local Render = {}

local function checkedAttr(value)
  if value then
    return "checked"
  end
  return ""
end

local function headerGlyphButtonHtml(opts)
  return '<button type="button" class="header-btn icon-only '
    .. html.escape(opts.className or "")
    .. '" aria-label="'
    .. html.escape(opts.ariaLabel or opts.tooltip or "")
    .. '" data-tooltip="'
    .. html.escape(opts.tooltip or "")
    .. '" onclick="'
    .. html.escape(opts.onclick or "")
    .. '"><span class="header-action-glyph" aria-hidden="true">'
    .. html.escape(opts.glyph or "")
    .. "</span></button>"
end

local function generalTabHtml(config)
  return "          <div class=\"settings-panel\" data-settings-panel=\"general\">\n"
    .. "            <label class=\"settings-item\">\n"
    .. "              <input type=\"checkbox\" "
    .. checkedAttr(config.autoHideAfterAction)
    .. " data-settings-config=\"autoHideAfterAction\""
    .. " onchange=\"sendAction('setAutoHideAfterAction', { slot: this.checked ? 1 : 0 })\">\n"
    .. "              <span>Auto-hide after pair/unpair</span>\n"
    .. "            </label>\n"
    .. "            <label class=\"settings-item\">\n"
    .. "              <input type=\"checkbox\" "
    .. checkedAttr(config.alwaysOnTop)
    .. " data-settings-config=\"alwaysOnTop\""
    .. " onchange=\"sendAction('setAlwaysOnTop', { slot: this.checked ? 1 : 0 })\">\n"
    .. "              <span>Always on top</span>\n"
    .. "            </label>\n"
    .. "            <label class=\"settings-item\">\n"
    .. "              <input type=\"checkbox\" "
    .. checkedAttr(config.hidePairButtons)
    .. " data-settings-config=\"hidePairButtons\""
    .. " onchange=\"sendAction('setHidePairButtons', { slot: this.checked ? 1 : 0 })\">\n"
    .. "              <span>Hide pair/unpair buttons</span>\n"
    .. "            </label>\n"
    .. "            <label class=\"settings-item\">\n"
    .. "              <input type=\"checkbox\" "
    .. checkedAttr(config.recoverClosedWindows)
    .. " data-settings-config=\"recoverClosedWindows\""
    .. " onchange=\"sendAction('setRecoverClosedWindows', { slot: this.checked ? 1 : 0 })\">\n"
    .. "              <span>Recover closed windows</span>\n"
    .. "            </label>\n"
    .. "            <div class=\"settings-slider-block\">\n"
    .. "              <div class=\"settings-slider-label\">Background opacity</div>\n"
    .. "              <input class=\"settings-slider\" data-settings-config=\"opacityPercent\" type=\"range\" min=\"40\" max=\"100\" step=\"10\" value=\""
    .. tostring(config.opacityPercent)
    .. "\" onchange=\"sendAction('setPopoverOpacity', { slot: this.value })\">\n"
    .. "            </div>\n"
    .. "          </div>\n"
end

local function hotkeysTabHtml(ctx)
  local parts = {
    "          <div class=\"settings-panel\" data-settings-panel=\"hotkeys\">\n",
    "            <div class=\"hotkeys-helper\">Click Remap to open the recorder. Press a new shortcut, media key, or system key, then save it or unbind the action.</div>\n",
  }

  if ctx.validation and ctx.validation.message then
    parts[#parts + 1] = "            <div class=\"hotkeys-error\" data-hotkey-validation>"
    parts[#parts + 1] = html.escape(ctx.validation.message)
    parts[#parts + 1] = "</div>\n"
  else
    parts[#parts + 1] = "            <div class=\"hotkeys-error is-hidden\" data-hotkey-validation></div>\n"
  end

  parts[#parts + 1] = "            <div class=\"hotkeys-list\" data-hotkeys-list>\n"
  parts[#parts + 1] = ctx.hotkeysHtml or hotkeyList.buildHtml(ctx.hotkeys or {})
  parts[#parts + 1] = "            </div>\n"
  parts[#parts + 1] = "          </div>\n"
  return table.concat(parts)
end

local function remapModalHtml()
  return [[
      <div class="remap-modal-shell" data-remap-shell hidden>
        <button type="button" class="remap-modal-backdrop" aria-label="Close remap recorder" data-remap-action="cancel"></button>
        <div class="remap-modal" role="dialog" aria-modal="true" aria-labelledby="remap-modal-title">
          <div class="remap-modal-label" id="remap-modal-title" data-remap-label></div>
          <div class="remap-comparison">
            <div class="remap-binding-pane">
              <div class="remap-preview-title">Current</div>
              <div class="remap-preview-combo remap-binding-combo" data-remap-current></div>
            </div>
            <div class="remap-binding-arrow" aria-hidden="true">→</div>
            <div class="remap-binding-pane">
              <div class="remap-preview-title">New</div>
              <div class="remap-preview-combo remap-binding-combo" data-remap-draft></div>
            </div>
          </div>
          <div class="remap-mods" role="group" aria-label="Modifier keys">
            <button type="button" class="btn hotkey-btn remap-mod-btn" data-remap-mod="cmd"><span class="remap-mod-text">Cmd</span><span class="remap-mod-symbol">⌘</span></button>
            <button type="button" class="btn hotkey-btn remap-mod-btn" data-remap-mod="alt"><span class="remap-mod-text">Option</span><span class="remap-mod-symbol">⌥</span></button>
            <button type="button" class="btn hotkey-btn remap-mod-btn" data-remap-mod="ctrl"><span class="remap-mod-text">Ctrl</span><span class="remap-mod-symbol">⌃</span></button>
            <button type="button" class="btn hotkey-btn remap-mod-btn" data-remap-mod="shift"><span class="remap-mod-text">Shift</span><span class="remap-mod-symbol">⇧</span></button>
          </div>
          <div class="remap-capture" data-remap-capture tabindex="0" role="button" aria-label="Record new hotkey">
            <div class="remap-capture-topline">
              <span class="remap-capture-status" data-remap-status>Listening</span>
              <span class="remap-capture-hint" data-remap-hint>Press any shortcut, media key, or system key</span>
            </div>
          </div>
          <div class="hotkeys-error is-hidden" data-remap-error></div>
          <div class="remap-actions">
            <button type="button" class="btn hotkey-btn remap-unbind-btn" data-remap-action="unbind">Unbind</button>
            <button type="button" class="btn hotkey-btn" data-remap-action="cancel">Cancel</button>
            <button type="button" class="btn hotkey-btn btn-primary remap-save-btn" data-remap-save data-remap-action="save">Save</button>
          </div>
        </div>
      </div>
]]
end

function Render.buildHtml(ctx)
  local generalActive = ctx.settingsTab ~= "hotkeys" and " is-active" or ""
  local hotkeysActive = ctx.settingsTab == "hotkeys" and " is-active" or ""
  local brandIcon = icons.tapshopBrandIconHtml("settings-brand-icon", 18)
  local parts = {
    "<!DOCTYPE html>\n<html>\n<head>\n  <meta charset=\"utf-8\">\n  <style>\n",
    ctx.css,
    "\n  </style>\n</head>\n<body data-settings-tab=\"",
    html.escape(ctx.settingsTab or "general"),
    "\" data-settings-scroll-top=\"",
    html.escape(tostring(ctx.scrollTop or 0)),
    "\">\n  <div class=\"container\">\n    <div class=\"header\">\n      <div class=\"header-titleblock\">\n        <div class=\"settings-window-title-row\">\n          ",
    brandIcon,
    "\n          <div class=\"settings-window-title\">TAPSHOP Settings</div>\n        </div>\n        <div class=\"settings-window-subtitle\">General preferences and hotkey overrides</div>\n      </div>\n      <div class=\"header-actions\">\n        ",
    icons.headerIconButton({
      className = "header-close",
      icon = "hide",
      tooltip = "Hide settings",
      onclick = "sendAction('close')",
    }),
    "\n      </div>\n    </div>\n    <div class=\"settings-window-shell\">\n      <div class=\"settings-head\">\n        <div class=\"settings-tabs\">\n          <button type=\"button\" data-settings-tab-button=\"general\" class=\"settings-tab",
    generalActive,
    "\" onclick=\"switchSettingsTab('general')\">General</button>\n          <button type=\"button\" data-settings-tab-button=\"hotkeys\" class=\"settings-tab",
    hotkeysActive,
    "\" onclick=\"switchSettingsTab('hotkeys')\">Hotkeys</button>\n        </div>\n        <div class=\"settings-tools\">\n          <input class=\"hotkey-search\" type=\"text\" value=\"",
    html.escape(ctx.search or ""),
    "\" placeholder=\"Search hotkeys\" oninput=\"handleSearchInput(this.value)\">\n          ",
    headerGlyphButtonHtml({
      className = "settings-restore-btn",
      glyph = "↺",
      tooltip = "Reset All",
      onclick = "resetAllHotkeys()",
    }),
    "\n        </div>\n      </div>\n      <div class=\"header-tooltip\" aria-hidden=\"true\"></div>\n      <div class=\"settings-scroll\">\n",
    generalTabHtml(ctx.config),
    hotkeysTabHtml(ctx),
    "      </div>\n",
    remapModalHtml(),
    "    </div>\n  </div>\n<script>\nwindow.tapshopSettingsLayoutPolicy = ",
    hs.json.encode(ctx.layoutPolicy or {}) or "{}",
    ";\nwindow.tapshopSystemKeyDisplay = ",
    hs.json.encode(systemKeyDisplay.jsData()) or "{}",
    ";\n",
    ctx.script,
    "\n</script>\n</body>\n</html>",
  }

  return table.concat(parts)
end

return Render
