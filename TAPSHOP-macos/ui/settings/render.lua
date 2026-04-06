local hotkeyList = require("ui.settings.hotkey_list")
local html = require("ui.html")
local icons = require("ui.popover.icons")
local hs = hs

local Render = {}

local function checkedAttr(value)
  if value then
    return "checked"
  end
  return ""
end

local function generalTabHtml(config)
  return "          <div class=\"settings-panel\" data-settings-panel=\"general\">\n"
    .. "            <label class=\"settings-item\">\n"
    .. "              <input type=\"checkbox\" "
    .. checkedAttr(config.autoHideAfterAction)
    .. " onchange=\"sendAction('setAutoHideAfterAction', { slot: this.checked ? 1 : 0 })\">\n"
    .. "              <span>Auto-hide after pair/unpair</span>\n"
    .. "            </label>\n"
    .. "            <label class=\"settings-item\">\n"
    .. "              <input type=\"checkbox\" "
    .. checkedAttr(config.alwaysOnTop)
    .. " onchange=\"sendAction('setAlwaysOnTop', { slot: this.checked ? 1 : 0 })\">\n"
    .. "              <span>Always on top</span>\n"
    .. "            </label>\n"
    .. "            <label class=\"settings-item\">\n"
    .. "              <input type=\"checkbox\" "
    .. checkedAttr(config.hidePairButtons)
    .. " onchange=\"sendAction('setHidePairButtons', { slot: this.checked ? 1 : 0 })\">\n"
    .. "              <span>Hide pair/unpair buttons</span>\n"
    .. "            </label>\n"
    .. "            <label class=\"settings-item\">\n"
    .. "              <input type=\"checkbox\" "
    .. checkedAttr(config.recoverClosedWindows)
    .. " onchange=\"sendAction('setRecoverClosedWindows', { slot: this.checked ? 1 : 0 })\">\n"
    .. "              <span>Recover closed windows</span>\n"
    .. "            </label>\n"
    .. "            <div class=\"settings-slider-block\">\n"
    .. "              <div class=\"settings-slider-label\">Background opacity</div>\n"
    .. "              <input class=\"settings-slider\" type=\"range\" min=\"40\" max=\"100\" step=\"10\" value=\""
    .. tostring(config.opacityPercent)
    .. "\" onchange=\"sendAction('setPopoverOpacity', { slot: this.value })\">\n"
    .. "            </div>\n"
    .. "          </div>\n"
end

local function hotkeysTabHtml(ctx)
  local parts = {
    "          <div class=\"settings-panel\" data-settings-panel=\"hotkeys\">\n",
    "            <div class=\"hotkeys-helper\">Click Remap to record a new shortcut. Save applies it immediately. Clear leaves the action unassigned.</div>\n",
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
  local generalActive = ctx.settingsTab ~= "hotkeys" and " is-active" or ""
  local hotkeysActive = ctx.settingsTab == "hotkeys" and " is-active" or ""
  local parts = {
    "<!DOCTYPE html>\n<html>\n<head>\n  <meta charset=\"utf-8\">\n  <style>\n",
    ctx.css,
    "\n  </style>\n</head>\n<body data-settings-tab=\"",
    html.escape(ctx.settingsTab or "general"),
    "\" data-settings-scroll-top=\"",
    html.escape(tostring(ctx.scrollTop or 0)),
    "\">\n  <div class=\"container\">\n    <div class=\"header\">\n      <div class=\"header-titleblock\">\n        <div class=\"settings-window-title\">TAPSHOP Settings</div>\n        <div class=\"settings-window-subtitle\">General preferences and hotkey overrides</div>\n      </div>\n      <div class=\"header-actions\">\n        ",
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
    icons.headerIconButton({
      className = "settings-restore-btn",
      icon = "restore",
      tooltip = "Restore default hotkeys",
      onclick = "resetAllHotkeys()",
    }),
    "\n        </div>\n      </div>\n      <div class=\"settings-scroll\">\n",
    generalTabHtml(ctx.config),
    hotkeysTabHtml(ctx),
    "      </div>\n",
    remapModalHtml(),
    "    </div>\n  </div>\n<script>\nwindow.tapshopSettingsLayoutPolicy = ",
    hs.json.encode(ctx.layoutPolicy or {}) or "{}",
    ";\n",
    ctx.script,
    "\n</script>\n</body>\n</html>",
  }

  return table.concat(parts)
end

return Render
