local Paths = {}

local function homeDir()
  return os.getenv("HOME") or "~"
end

local function testOverride()
  return rawget(_G, "__tapshop_test_data_dir")
end

function Paths.baseDir()
  return testOverride() or (homeDir() .. "/.hammerspoon/tapshop")
end

function Paths.settings()
  return Paths.baseDir() .. "/settings.json"
end

function Paths.appdata()
  return Paths.baseDir() .. "/appdata.json"
end

return Paths
