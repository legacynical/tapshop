local WindowService = {}
local FAST_FOCUS_RETRY_DELAYS = { 0.02, 0.06 }

local function elapsedMs(startedAt)
  return (hs.timer.absoluteTime() - startedAt) / 1e6
end

local function debugLog(cfg, fmt, ...)
  if cfg and cfg.isGuiDebugMode then
    hs.printf("[tapshop-perf] " .. fmt, ...)
  end
end

local function isFrontmost(win)
  if not win then
    return false
  end

  local frontmost = hs.window.frontmostWindow()
  return frontmost and frontmost:id() == win:id() or false
end

local function requestFocus(win)
  local app = win:application()
  if app and app:isHidden() then
    app:unhide()
  end
  if app then
    app:activate(true)
  end
  if win:isMinimized() then
    win:unminimize()
  end

  win:focus()
end

local function scheduleFastFocusRetries(win)
  for _, delay in ipairs(FAST_FOCUS_RETRY_DELAYS) do
    hs.timer.doAfter(delay, function()
      pcall(function()
        if not win or isFrontmost(win) then
          return
        end
        requestFocus(win)
      end)
    end)
  end
end

function WindowService.getWindowInfo(win)
  win = win or hs.window.frontmostWindow()
  if not win then
    return nil
  end

  local app = win:application()
  return {
    title = win:title() or "",
    id = win:id(),
    appName = app and app:name() or "",
    processName = app and app:name() or "",
    pid = app and app:pid() or nil,
    bundleID = app and app:bundleID() or "",
  }
end

function WindowService.candidateWindows()
  local wins = hs.window.orderedWindows()
  local out = {}
  for _, win in ipairs(wins) do
    if win and win:isVisible() and win:isStandard() and (win:title() or ""):match("%S") then
      out[#out + 1] = win
    end
  end
  return out
end

function WindowService.getWindowById(id)
  if not id then
    return nil
  end
  return hs.window.get(id)
end

function WindowService.displayTitle(win)
  if not win then
    return "[empty]"
  end

  local app = win:application()
  local prefix = app and app:name() or "App"
  local title = win:title() or ""
  if title == "" then
    title = "[untitled]"
  end

  return "[" .. prefix .. "] " .. title
end

function WindowService.waitForFrontmost(win, cfg)
  local timeoutSec = cfg.focusWaitTimeout
  local start = hs.timer.secondsSinceEpoch()
  while (hs.timer.secondsSinceEpoch() - start) < timeoutSec do
    if isFrontmost(win) then
      return true
    end
    hs.timer.usleep(cfg.focusPollMicros)
  end
  return false
end

function WindowService.focusOrRestore(win, cfg)
  local startedAt = hs.timer.absoluteTime()
  if not win then
    debugLog(cfg, "focus.verified result=missing-window durationMs=%.2f", elapsedMs(startedAt))
    return false
  end

  if isFrontmost(win) then
    debugLog(cfg, "focus.verified result=already-frontmost windowId=%s durationMs=%.2f", tostring(win:id()), elapsedMs(startedAt))
    return true
  end

  requestFocus(win)
  local focused = WindowService.waitForFrontmost(win, cfg)
  debugLog(
    cfg,
    "focus.verified result=%s windowId=%s durationMs=%.2f",
    focused and "frontmost" or "timeout",
    tostring(win:id()),
    elapsedMs(startedAt)
  )
  return focused
end

function WindowService.focusOrRestoreFast(win, cfg)
  local startedAt = hs.timer.absoluteTime()
  if not win then
    debugLog(cfg, "focus.fast result=missing-window durationMs=%.2f", elapsedMs(startedAt))
    return false
  end

  if isFrontmost(win) then
    debugLog(cfg, "focus.fast result=already-frontmost windowId=%s durationMs=%.2f", tostring(win:id()), elapsedMs(startedAt))
    return true
  end

  requestFocus(win)
  scheduleFastFocusRetries(win)
  debugLog(cfg, "focus.fast result=focus-requested windowId=%s durationMs=%.2f", tostring(win:id()), elapsedMs(startedAt))
  return true
end

return WindowService
