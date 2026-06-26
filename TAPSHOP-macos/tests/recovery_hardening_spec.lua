package.path = "TAPSHOP-macos/?.lua;TAPSHOP-macos/?/init.lua;" .. package.path

local currentFrontmost = nil

hs = {
  printf = function() end,
  window = {
    filter = {
      windowDestroyed = "windowDestroyed",
      windowFocused = "windowFocused",
      windowTitleChanged = "windowTitleChanged",
      windowCreated = "windowCreated",
      windowVisible = "windowVisible",
      windowMinimized = "windowMinimized",
      windowUnminimized = "windowUnminimized",
      windowFullscreened = "windowFullscreened",
      windowUnfullscreened = "windowUnfullscreened",
    },
    frontmostWindow = function()
      return currentFrontmost
    end,
  },
}

local AppState = require("state.app_state")
local Workspace = require("state.workspace")
local SlotRow = require("state.slot_row")

local Window = {}
Window.__index = Window

function Window.new(opts)
  return setmetatable(opts or {}, Window)
end

function Window:id()
  return self._id
end

function Window:title()
  return self._title or ""
end

function Window:isVisible()
  return self._visible == true
end

function Window:isStandard()
  return self._standard ~= false
end

function Window:isMinimized()
  return self._minimized == true
end

function Window:isFullScreen()
  return self._fullscreen == true
end

function Window:minimize()
  self._minimized = true
end

function Window:application()
  local bundleID = self._bundleID or "com.example.App"
  local appName = self._appName or "Example"
  return {
    bundleID = function()
      return bundleID
    end,
    name = function()
      return appName
    end,
    isHidden = function()
      return false
    end,
    unhide = function() end,
  }
end

local function normalizeTitle(title)
  local normalized = tostring(title or ""):lower()
  normalized = normalized:gsub("%s+", " ")
  normalized = normalized:match("^%s*(.-)%s*$") or ""
  return normalized
end

local function makeWindowService(windows, candidates)
  local service = {
    windows = windows or {},
    candidates = candidates or {},
    currentSpace = 1,
    requestedFrontmost = nil,
    gotoSpaceResult = nil,
  }

  function service.getWindowById(id)
    return service.windows[id]
  end

  function service.getWindowSpaces(win)
    return (win and win._spaces) or {}
  end

  function service.getWindowSpacesById(id)
    local win = service.windows[id]
    return (win and win._spaces) or {}
  end

  function service.getPrimarySpaceForWindow(win)
    return win and win._spaces and win._spaces[1] or nil
  end

  function service.windowIsInSpace(win, spaceId)
    for _, candidate in ipairs(service.getWindowSpaces(win)) do
      if candidate == spaceId then
        return true
      end
    end
    return false
  end

  function service.isWindowFullscreen(win)
    return win ~= nil and win:isFullScreen()
  end

  function service.isFullscreenSpace(spaceId)
    return spaceId == 200
  end

  function service.pairingMetadata(win)
    local app = win and win:application() or nil
    local title = win and win:title() or ""
    return {
      bundleID = app and app:bundleID() or "",
      appName = app and app:name() or "",
      titleRaw = title,
      titleNormalized = normalizeTitle(title),
    }
  end

  function service.displayTitle(win)
    return win and win:title() or "[empty]"
  end

  function service.windowTitle(win)
    return win and win:title() or "[empty]"
  end

  function service.isRecoveryCandidateWindow(win)
    return win ~= nil and win:isStandard() and win:title():match("%S") ~= nil
  end

  function service:recoveryCandidateWindows()
    return self.candidates
  end

  function service:candidateWindows()
    return self.candidates
  end

  function service.focusedSpaceId()
    return service.currentSpace
  end

  function service.gotoSpace(spaceId)
    if service.gotoSpaceResult then
      return service.gotoSpaceResult
    end
    service.currentSpace = spaceId
    return {
      ok = true,
      code = "space_switch_verified",
      spaceId = spaceId,
    }
  end

  function service.requestFrontmost(win)
    service.requestedFrontmost = win
    return {
      ok = win ~= nil,
      code = win and "focus_requested" or "missing_window",
    }
  end

  function service.requestFrontmostAfterSpaceSwitch(win)
    service.requestedFrontmost = win
    return {
      ok = win ~= nil,
      code = win and "focus_requested_after_space_switch" or "missing_window",
    }
  end

  return service
end

local function makeApp(windowService, workspace)
  local profile = {
    id = 1,
    workspaces = {
      workspace or Workspace.new(1, "Test Window", 2),
    },
  }
  local app = setmetatable({
    cfg = {
      recoverClosedWindows = true,
      focusWaitTimeout = 0,
      focusPollMicros = 1,
    },
    appdata = {
      setProfilesWindowPairings = function() end,
    },
    windowService = windowService,
    youtubeService = {
      handleDestroyedWindowId = function() end,
      handleWindowCandidate = function() end,
    },
    toastMessages = {},
    profiles = {
      profile,
    },
    session = {
      activeProfileId = 1,
      focusedSpaceId = 1,
    },
  }, AppState)
  app.toast = function(message)
    app.toastMessages[#app.toastMessages + 1] = message
  end
  return app, profile.workspaces[1]
end

local function pairWorkspace(workspace, windowId, title)
  workspace:pair(windowId, {
    bundleID = "com.example.App",
    appName = "Example",
    titleRaw = title,
    titleNormalized = normalizeTitle(title),
  })
end

local tests = {}

tests.fullscreen_base_destroyed_becomes_recoverable = function()
  local deadWin = Window.new({
    _id = 10,
    _title = "Full Doc",
    _fullscreen = true,
    _spaces = {
      200,
    },
  })
  local service = makeWindowService({
    [10] = deadWin,
  }, {})
  local app, workspace = makeApp(service)
  pairWorkspace(workspace, 10, "Full Doc")
  workspace:setFullscreenState({
    fullscreenWindowId = 10,
    fullscreenSpaceId = 200,
    lastKnownSpaceId = 200,
  })

  app:handleWindowEvent(hs.window.filter.windowDestroyed, deadWin)

  assert(workspace:isRecoverable(), "fullscreen base should become recoverable")
  assert(workspace:getBaseWindowId() == nil, "stale fullscreen base id should be cleared")
end

tests.minimized_candidate_can_relink_stale_pairing = function()
  local restored = Window.new({
    _id = 20,
    _title = "Minimized Doc",
    _visible = false,
    _minimized = true,
    _spaces = {
      1,
    },
  })
  local service = makeWindowService({
    [20] = restored,
  }, {
    restored,
  })
  local app, workspace = makeApp(service)
  pairWorkspace(workspace, 10, "Minimized Doc")
  workspace:setBaseSpaceId(1)

  local repairResult = app:_repairStalePairedWorkspace(workspace, {
    reason = "test",
  })
  local row = SlotRow.build(workspace, {
    focusedSpaceId = 1,
  }, {
    windowService = service,
  })

  assert(repairResult.ok, "minimized candidate should relink")
  assert(workspace:getBaseWindowId() == 20, "workspace should point at restored minimized id")
  assert(row.state == "minimized", "row should show minimized state")
end

tests.startup_relinks_stale_persisted_pairing = function()
  local restored = Window.new({
    _id = 20,
    _title = "Startup Doc",
    _spaces = {
      1,
    },
  })
  local service = makeWindowService({
    [20] = restored,
  }, {
    restored,
  })
  local appdata = {
    getActiveProfileId = function()
      return 1
    end,
    getProfilesWindowPairings = function()
      return {
        [1] = {
          [1] = {
            version = 2,
            kind = "paired",
            baseWindowId = 10,
            fingerprint = {
              bundleID = "com.example.App",
              appName = "Example",
              titleRaw = "Startup Doc",
              titleNormalized = "startup doc",
            },
          },
        },
      }
    end,
    setProfilesWindowPairings = function() end,
    setActiveProfileId = function() end,
  }
  local app = AppState.new({
    recoverClosedWindows = true,
    minimizeThreshold = 2,
  }, {
    settings = {},
    appdata = appdata,
    windowService = service,
    youtubeService = {
      handleDestroyedWindowId = function() end,
      handleWindowCandidate = function() end,
    },
    spotifyService = {},
    systemAudioService = {},
    toast = function() end,
  })

  assert(app.profiles[1].workspaces[1]:getBaseWindowId() == 20, "startup should relink stale pairing")
end

tests.activation_repairs_stale_pairing_before_error = function()
  local restored = Window.new({
    _id = 20,
    _title = "Activation Doc",
    _spaces = {
      1,
    },
  })
  local frontmost = Window.new({
    _id = 30,
    _title = "Other",
    _spaces = {
      1,
    },
  })
  local service = makeWindowService({
    [20] = restored,
    [30] = frontmost,
  }, {
    restored,
  })
  local app, workspace = makeApp(service)
  pairWorkspace(workspace, 10, "Activation Doc")
  workspace:setBaseSpaceId(1)
  currentFrontmost = frontmost

  app:activateSlot(1)

  assert(workspace:getBaseWindowId() == 20, "activation should relink stale pairing")
  assert(service.requestedFrontmost == restored, "activation should focus restored window")
end

tests.stale_off_space_locator_renders_unresolved = function()
  local service = makeWindowService({}, {})
  local _, workspace = makeApp(service)
  pairWorkspace(workspace, 10, "Off Space Doc")
  workspace:setBaseSpaceId(200)

  local row = SlotRow.build(workspace, {
    focusedSpaceId = 1,
  }, {
    windowService = service,
  })

  assert(row.state == "unresolved", "stale off-Space locator should not render as off_space")
end

tests.ambiguous_recovery_does_not_pair_wrong_window = function()
  local one = Window.new({
    _id = 20,
    _title = "Ambiguous Doc",
    _spaces = {
      1,
    },
  })
  local two = Window.new({
    _id = 21,
    _title = "Ambiguous Doc",
    _spaces = {
      1,
    },
  })
  local service = makeWindowService({
    [20] = one,
    [21] = two,
  }, {
    one,
    two,
  })
  local app, workspace = makeApp(service)
  pairWorkspace(workspace, 10, "Ambiguous Doc")

  local repairResult = app:_repairStalePairedWorkspace(workspace, {
    reason = "test",
  })

  assert(repairResult.code == "ambiguous_recovery_match", "ambiguous matches should be reported")
  assert(workspace:isRecoverable(), "ambiguous stale slot should become recoverable")
end

tests.space_switch_failure_returns_specific_code = function()
  local target = Window.new({
    _id = 20,
    _title = "Space Doc",
    _spaces = {
      200,
    },
  })
  local service = makeWindowService({
    [20] = target,
  }, {})
  service.gotoSpaceResult = {
    ok = false,
    code = "space_switch_timeout",
    spaceId = 200,
  }
  local app, workspace = makeApp(service)
  pairWorkspace(workspace, 20, "Space Doc")
  workspace:setBaseSpaceId(200)

  local activationResult = app:_activateResolvedPairedWindow(workspace, target, 1)

  assert(activationResult.code == "space_switch_timeout", "Space switch failure should be specific")
end

local failures = 0
for name, fn in pairs(tests) do
  local ok, err = pcall(fn)
  if ok then
    print("ok - " .. name)
  else
    failures = failures + 1
    print("not ok - " .. name .. ": " .. tostring(err))
  end
end

if failures > 0 then
  os.exit(1)
end
