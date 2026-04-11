local Assets = {}

local cachedModuleDir = nil

local function moduleDir()
  if cachedModuleDir then
    return cachedModuleDir
  end

  local source = debug.getinfo(1, "S").source
  local scriptPath = source:sub(1, 1) == "@" and source:sub(2) or source
  cachedModuleDir = scriptPath:match("^(.*)/[^/]+$")
  return cachedModuleDir
end

function Assets.path(name)
  local dir = moduleDir()
  if not dir or type(name) ~= "string" or name == "" then
    return nil
  end

  return dir .. "/assets/" .. name
end

function Assets.tapshopIconPath()
  return Assets.path("tapshop.png")
end

return Assets
