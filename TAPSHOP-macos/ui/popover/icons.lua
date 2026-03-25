local html = require("ui.html")

local Icons = {}

local ICON_SVGS = {
  hide = [=[
<path d="M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49" />
<path d="M14.084 14.158a3 3 0 0 1-4.242-4.242" />
<path d="M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143" />
<path d="m2 2 20 20" />
]=],
  config = [=[
<path d="M9.671 4.136a2.34 2.34 0 0 1 4.659 0 2.34 2.34 0 0 0 3.319 1.915 2.34 2.34 0 0 1 2.33 4.033 2.34 2.34 0 0 0 0 3.831 2.34 2.34 0 0 1-2.33 4.033 2.34 2.34 0 0 0-3.319 1.915 2.34 2.34 0 0 1-4.659 0 2.34 2.34 0 0 0-3.32-1.915 2.34 2.34 0 0 1-2.33-4.033 2.34 2.34 0 0 0 0-3.831A2.34 2.34 0 0 1 6.35 6.051a2.34 2.34 0 0 0 3.319-1.915" />
<circle cx="12" cy="12" r="3" />
]=],
  clearAll = [=[
<path d="M10 11v6" />
<path d="M14 11v6" />
<path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6" />
<path d="M3 6h18" />
<path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
]=],
  restore = [=[
<path d="M3 2v6h6" />
<path d="M3 8a9 9 0 1 0 3-6.7L3 4" />
]=],
}

function Icons.iconSvg(name)
  local icon = ICON_SVGS[name] or ""
  return '<svg class="header-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">'
    .. icon
    .. "</svg>"
end

function Icons.headerIconButton(opts)
  local tooltip = html.escape(opts.tooltip)
  local ariaLabel = html.escape(opts.ariaLabel or opts.tooltip)
  return '<button type="button" class="header-btn icon-only '
    .. opts.className
    .. '" aria-label="'
    .. ariaLabel
    .. '" data-tooltip="'
    .. tooltip
    .. '" onclick="'
    .. opts.onclick
    .. '">'
    .. Icons.iconSvg(opts.icon)
    .. "</button>"
end

return Icons
