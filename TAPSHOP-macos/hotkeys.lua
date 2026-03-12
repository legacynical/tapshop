local Hotkeys = {}

local function bindIfAvailable(mods, key, fn)
  local map = hs.keycodes.map
  local keyLower = string.lower(key)
  if map[key] or map[keyLower] then
    hs.hotkey.bind(mods, key, fn)
  else
    hs.printf(
      "Skipping hotkey: %s + %s (key not in keymap)",
      table.concat(mods, "+"),
      key
    )
  end
end

function Hotkeys.register(app)
  local pairMods = { "cmd", "alt" }
  local unpairMods = { "cmd", "alt", "shift" }
  local hyper = { "cmd", "alt", "ctrl" }

  for i = 1, 9 do
    hs.hotkey.bind(pairMods, tostring(i), function()
      app:activateSlot(i)
    end)
  end

  for i = 1, 9 do
    hs.hotkey.bind(unpairMods, tostring(i), function()
      app:unpairSlot(i)
    end)
  end
  hs.hotkey.bind(unpairMods, "0", function()
    app:unpairAll()
  end)

  local youtubeBindings = {
    { mods = pairMods, key = "`", fn = function() app:togglePopover() end, guarded = false },
    { mods = pairMods, key = "left", fn = function() app:sendYoutubeCommand("{Left}") end, guarded = false },
    { mods = pairMods, key = "right", fn = function() app:sendYoutubeCommand("{Right}") end, guarded = false },
    { mods = pairMods, key = "j", fn = function() app:sendYoutubeCommand("j") end, guarded = false },
    { mods = pairMods, key = "l", fn = function() app:sendYoutubeCommand("l") end, guarded = false },
    { mods = pairMods, key = "k", fn = function() app:sendYoutubeCommand("k") end, guarded = false },
    { mods = {}, key = "F19", fn = function() app:sendYoutubeCommand("{Left}") end, guarded = true },
    { mods = { "ctrl" }, key = "F19", fn = function() app:sendYoutubeCommand("j") end, guarded = true },
    { mods = {}, key = "F21", fn = function() app:sendYoutubeCommand("{Right}") end, guarded = true },
    { mods = { "ctrl" }, key = "F21", fn = function() app:sendYoutubeCommand("l") end, guarded = true },
    { mods = {}, key = "F20", fn = function() app:sendYoutubeCommand("k") end, guarded = true },
  }

  for _, binding in ipairs(youtubeBindings) do
    if binding.guarded then
      bindIfAvailable(binding.mods, binding.key, binding.fn)
    else
      hs.hotkey.bind(binding.mods, binding.key, binding.fn)
    end
  end

  local spotifyBindings = {
    { mods = {}, key = "F7", fn = function() app:spotifyPrevious() end },
    { mods = {}, key = "F8", fn = function() app:spotifyPlayPause() end },
    { mods = {}, key = "F9", fn = function() app:spotifyNext() end },
    { mods = { "ctrl" }, key = "F7", fn = function() app:spotifySeekBack(5) end },
    { mods = { "ctrl" }, key = "F9", fn = function() app:spotifySeekForward(5) end },
    { mods = {}, key = "F22", fn = function() app:spotifyToggleLike() end },
    { mods = {}, key = "F23", fn = function() app:spotifyVolumeDown(6) end },
    { mods = {}, key = "F24", fn = function() app:spotifyVolumeUp(6) end },
  }

  for _, binding in ipairs(spotifyBindings) do
    bindIfAvailable(binding.mods, binding.key, binding.fn)
  end

  local systemVolumeBindings = {
    { key = ",", fn = function() app:adjustSystemVolume(-5) end },
    { key = ".", fn = function() app:adjustSystemVolume(5) end },
    { key = "M", fn = function() app:toggleSystemMute() end },
  }

  for _, binding in ipairs(systemVolumeBindings) do
    hs.hotkey.bind(hyper, binding.key, binding.fn)
  end
end

return Hotkeys
