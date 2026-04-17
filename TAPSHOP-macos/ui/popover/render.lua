local icons = require("ui.icons")
local hs = hs

local Render = {}

local function escapeHtml(text)
  local value = tostring(text or "")
  return (value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local function rowHtml(row, config)
  config = config or {}
  local hidePairButtons = config.hidePairButtons == true
  local unpairClass = row.canUnpair and "btn btn-unpair" or "btn btn-unpair off"
  local appIconClass = row.iconMuted and "slot-app-icon is-muted" or "slot-app-icon"
  local appIcon = icons.slotAppIconHtml(row.iconBundleID, row.iconAppName, appIconClass)
  local badgeHtml = ""
  local buttonsHtml = ""

  if row.badgeText and row.badgeText ~= "" then
    local badgeClass = "slot-badge"
    if row.state == "minimized" then
      badgeClass = badgeClass .. " is-minimized"
    elseif row.state == "fullscreen" then
      badgeClass = badgeClass .. " is-fullscreen"
    end
    badgeHtml = '<span class="' .. badgeClass .. '">' .. escapeHtml(row.badgeText) .. "</span>"
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
    .. escapeHtml(row.label)
    .. "</span>"
    .. "</span>"
    .. badgeHtml
    .. "</span>\n"
    .. buttonsHtml
    .. "      </div>\n"
end

function Render.buildHtml(ctx)
  local headerAppIcon = icons.appIconHtml(ctx.headerBundleID, ctx.headerAppName, "header-active-win-icon", 16)
  local brandIcon = icons.tapshopBrandIconHtml("title-brand-icon", 16)
  local parts = {
    "<!DOCTYPE html>\n<html>\n<head>\n  <meta charset=\"utf-8\">\n  <style>\n",
    ctx.css,
    "\n  </style>\n</head>\n<body tabindex=\"0\">\n  <div class=\"container\">\n    <div class=\"header\">\n      <div class=\"title-wrap\">\n        <button class=\"title-logo\" type=\"button\" aria-label=\"Tapshop\">",
    brandIcon,
    "</button>\n      </div>\n      <div class=\"header-active-win\">",
    headerAppIcon,
    "<span class=\"header-active-win-title\">",
    escapeHtml(ctx.primaryLine),
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
      onclick = "sendAction('toggleSettingsWindow')",
    }),
    "\n        ",
    icons.headerIconButton({
      className = "header-close",
      icon = "hide",
      tooltip = "Hide",
      onclick = "sendAction('close')",
    }),
    "\n      </div>\n    </div>\n    <div class=\"header-tooltip\" aria-hidden=\"true\"></div>\n    <div class=\"body-shell\">\n      <div class=\"workspace-list\">\n",
  }

  for _, row in ipairs(ctx.rows) do
    parts[#parts + 1] = rowHtml(row, ctx.config)
  end

  parts[#parts + 1] = "      </div>\n"
  parts[#parts + 1] = "    </div>\n</div>\n<script>\nwindow.tapshopLayoutPolicy = "
  parts[#parts + 1] = hs.json.encode(ctx.layoutPolicy or {}) or "{}"
  parts[#parts + 1] = ";\n"
  parts[#parts + 1] = ctx.script
  parts[#parts + 1] = "\n</script>\n</body>\n</html>"

  return table.concat(parts)
end

return Render
