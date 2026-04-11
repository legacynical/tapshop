local html = require("ui.html")
local assets = require("ui.assets")
local hs = hs

local Icons = {}
local APP_ICON_URL_CACHE = {}

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
  return '<svg class="header-action-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">'
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

function Icons.appIconUrl(bundleID, size)
  if type(bundleID) ~= "string" or bundleID == "" then
    return nil
  end

  local cacheKey = table.concat({ bundleID, tostring(size or 18) }, "::")
  local cached = APP_ICON_URL_CACHE[cacheKey]
  if cached ~= nil then
    return cached ~= false and cached or nil
  end

  local image = hs.image.imageFromAppBundle(bundleID)
  if not image then
    APP_ICON_URL_CACHE[cacheKey] = false
    return nil
  end

  local ok, encoded = pcall(function()
    return image:setSize({ h = size or 18, w = size or 18 }):encodeAsURLString()
  end)
  APP_ICON_URL_CACHE[cacheKey] = ok and encoded or false
  return ok and encoded or nil
end

function Icons.imageUrlFromPath(imagePath, size)
  if type(imagePath) ~= "string" or imagePath == "" or not hs.image or not hs.image.imageFromPath then
    return nil
  end

  local cacheKey = table.concat({ "path", imagePath, tostring(size or 18) }, "::")
  local cached = APP_ICON_URL_CACHE[cacheKey]
  if cached ~= nil then
    return cached ~= false and cached or nil
  end

  local image = hs.image.imageFromPath(imagePath)
  if not image then
    APP_ICON_URL_CACHE[cacheKey] = false
    return nil
  end

  local ok, encoded = pcall(function()
    return image:setSize({ h = size or 18, w = size or 18 }):encodeAsURLString()
  end)
  APP_ICON_URL_CACHE[cacheKey] = ok and encoded or false
  return ok and encoded or nil
end

function Icons.appIconHtml(bundleID, appName, className, size)
  local iconUrl = Icons.appIconUrl(bundleID, size or 18)
  if not iconUrl then
    return ""
  end

  return '<img class="'
    .. html.escape(className or "slot-app-icon")
    .. '" src="'
    .. html.escape(iconUrl)
    .. '" alt="" aria-hidden="true" title="'
    .. html.escape(appName or "")
    .. '">'
end

function Icons.imagePathHtml(imagePath, className, size, title)
  local iconUrl = Icons.imageUrlFromPath(imagePath, size or 18)
  if not iconUrl then
    return ""
  end

  return '<img class="'
    .. html.escape(className or "slot-app-icon")
    .. '" src="'
    .. html.escape(iconUrl)
    .. '" alt="" aria-hidden="true" title="'
    .. html.escape(title or "")
    .. '">'
end

function Icons.tapshopBrandIconHtml(className, size)
  return Icons.imagePathHtml(assets.tapshopIconPath(), className or "title-brand-icon", size or 16, "TAPSHOP")
end

function Icons.slotAppIconHtml(bundleID, appName, className)
  return Icons.appIconHtml(bundleID, appName, className or "slot-app-icon", 18)
end

return Icons
