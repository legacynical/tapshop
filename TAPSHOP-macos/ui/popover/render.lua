local html = require("ui.html")
local icons = require("ui.popover.icons")

local Render = {}

local function checkedAttr(value)
  if value then
    return "checked"
  end
  return ""
end

local function rowHtml(row)
  local minBadge = row.isMinimized and '<span class="min-badge">MIN</span>' or ""
  local unpairClass = row.canUnpair and "btn btn-unpair" or "btn btn-unpair off"

  return "    <div class=\"row\">\n"
    .. "      <span class=\"slot-num\">" .. tostring(row.index) .. "</span>\n"
    .. "      <span class=\"slot-label " .. row.className .. "\"><span class=\"slot-text-bg\">"
    .. html.escape(row.label)
    .. "</span>"
    .. minBadge
    .. "</span>\n"
    .. "      <div class=\"slot-buttons\">\n"
    .. "        <button class=\"btn btn-primary\" onclick=\"sendAction('pair'," .. tostring(row.index) .. ")\">Pair</button>\n"
    .. "        <button class=\"" .. unpairClass .. "\" onclick=\"sendAction('unpair'," .. tostring(row.index) .. ")\">Unpair</button>\n"
    .. "      </div>\n"
    .. "    </div>\n"
end

function Render.buildHtml(ctx)
  local parts = {
    "<!DOCTYPE html>\n<html>\n<head>\n  <meta charset=\"utf-8\">\n  <style>\n",
    ctx.css,
    "\n  </style>\n</head>\n<body>\n  <div class=\"container\">\n    <div class=\"header\">\n      <div class=\"title-wrap\">\n        <span class=\"title\"><span class=\"title-trigger\">TAPS</span><span class=\"title-hop\">HOP</span></span>\n      </div>\n      <div class=\"header-details\">\n        <span class=\"header-primary\">",
    html.escape(ctx.primaryLine),
    "</span>\n        <span class=\"header-secondary\">",
    html.escape(ctx.secondaryLine),
    "</span>\n      </div>\n      <div class=\"header-actions\">\n        ",
    icons.headerIconButton({
      className = "header-danger",
      icon = "clearAll",
      tooltip = "Unpair ALL",
      onclick = "sendAction('unpairAll')",
    }),
    "\n        <details class=\"config-menu\">\n          ",
    icons.configIconTrigger({
      icon = "config",
      tooltip = "Config",
    }),
    "\n          <div class=\"config-panel\">\n            <label class=\"config-item\">\n              <input type=\"checkbox\" ",
    checkedAttr(ctx.config.autoHideAfterAction),
    " onchange=\"sendAction('setAutoHideAfterAction', this.checked ? 1 : 0)\">\n              Auto-hide after pair/unpair\n            </label>\n            <label class=\"config-item\">\n              <input type=\"checkbox\" ",
    checkedAttr(ctx.config.alwaysOnTop),
    " onchange=\"sendAction('setAlwaysOnTop', this.checked ? 1 : 0)\">\n              Always on top\n            </label>\n            <div class=\"config-slider-wrap\">\n              <div class=\"config-slider-row\">\n                <span>Background opacity</span>\n              </div>\n              <input class=\"config-slider\" type=\"range\" min=\"40\" max=\"100\" step=\"10\" value=\"",
    tostring(ctx.config.opacityPercent),
    "\" onchange=\"sendAction('setPopoverOpacity', this.value)\">\n            </div>\n            <label class=\"config-item config-item-debug\">\n              <input type=\"checkbox\" ",
    checkedAttr(ctx.config.debugWindow),
    " onchange=\"sendAction('setDebugWindow', this.checked ? 1 : 0)\">\n              Debug\n            </label>\n          </div>\n        </details>\n        ",
    icons.headerIconButton({
      className = "header-close",
      icon = "hide",
      tooltip = "Hide",
      onclick = "sendAction('close')",
    }),
    "\n      </div>\n    </div>\n    <div class=\"header-tooltip\" aria-hidden=\"true\"></div>\n    <div class=\"workspace-list\">\n",
  }

  for _, row in ipairs(ctx.rows) do
    parts[#parts + 1] = rowHtml(row)
  end

  parts[#parts + 1] = "  </div>\n</div>\n<script>\n"
  parts[#parts + 1] = ctx.script
  parts[#parts + 1] = "\n</script>\n</body>\n</html>"

  return table.concat(parts)
end

return Render
