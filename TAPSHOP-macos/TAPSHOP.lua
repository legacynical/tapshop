-- TAPSHOP (Hammerspoon port)
-- Requires: Accessibility permissions enabled for Hammerspoon

local function ensureModulePath()
  local source = debug.getinfo(1, "S").source
  local scriptPath = source:sub(1, 1) == "@" and source:sub(2) or source
  local scriptDir = scriptPath:match("^(.*)/[^/]+$")
  if not scriptDir then
    return
  end

  local modulePath = scriptDir .. "/?.lua;" .. scriptDir .. "/?/init.lua;"
  if not package.path:find(scriptDir, 1, true) then
    package.path = modulePath .. package.path
  end
end

ensureModulePath()

local Config = require("config")
local settingsStore = require("settings_store")
local AppState = require("state.app_state")
local HotkeyManager = require("hotkeys.manager")
local windowService = require("services.window_service")
local YoutubeService = require("services.youtube_service")
local SpotifyService = require("services.spotify_service")
local Toast = require("ui.toast")
local Popover = require("ui.popover")
local DebugWindow = require("ui.debug_window")

local cfg = Config.load()
local toast = Toast.new(cfg)
local youtubeService = YoutubeService.new(cfg, windowService, toast)
local spotifyService = SpotifyService.new()

local app = AppState.new(cfg, {
  settingsStore = settingsStore,
  windowService = windowService,
  youtubeService = youtubeService,
  spotifyService = spotifyService,
  toast = toast,
})

local hotkeyManager = HotkeyManager.new(app, settingsStore, Config.keys.hotkeyOverrides)
app:attachHotkeyManager(hotkeyManager)

local popover = Popover.new(app, cfg, {
  settingsStore = settingsStore,
  windowService = windowService,
})

local debugWindow = DebugWindow.new(app, cfg, {
  windowService = windowService,
  popover = popover,
})

app:attachUi(popover, debugWindow)

local windowFilter = hs.window.filter.new()
windowFilter:subscribe({
  hs.window.filter.windowFocused,
  hs.window.filter.windowTitleChanged,
  hs.window.filter.windowCreated,
  hs.window.filter.windowDestroyed,
  hs.window.filter.windowVisible,
  hs.window.filter.windowMinimized,
  hs.window.filter.windowUnminimized,
}, function(win, _, event)
  pcall(function()
    app:handleWindowEvent(event, win)
  end)
end)

local popoverWindowTracker = hs.window.filter.new()
popoverWindowTracker:subscribe({
  hs.window.filter.windowFocused,
}, function(win)
  pcall(function()
    app:handleActiveWindowChange(win)
  end)
end)

app.windowFilter = windowFilter
app.popoverWindowTracker = popoverWindowTracker

hotkeyManager:bindAll()

toast("TAPSHOP ready (Hammerspoon)")

hs.timer.doAfter(0.10, function()
  local ok, err = pcall(function()
    if app.warmHotkeyUiCache then
      app:warmHotkeyUiCache()
    end
    if popover.warmStaticCaches then
      popover:warmStaticCaches()
    end
  end)
  if not ok then
    hs.printf("[tapshop-warm] background warm failed: %s", tostring(err))
  end
end)

return app
