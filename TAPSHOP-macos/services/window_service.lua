local WindowService = {}

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
    local frontmost = hs.window.frontmostWindow()
    if frontmost and win and frontmost:id() == win:id() then
      return true
    end
    hs.timer.usleep(cfg.focusPollMicros)
  end
  return false
end

function WindowService.focusOrRestore(win, cfg)
  if not win then
    return false
  end

  local app = win:application()
  local frontmost = hs.window.frontmostWindow()
  if frontmost and frontmost:id() == win:id() then
    return true
  end

  if app and app:isHidden() then
    app:unhide()
  end
  if app then
    app:activate(true)
  end
  if win:isMinimized() then
    win:unminimize()
    hs.timer.usleep(15000)
  end

  win:focus()
  return WindowService.waitForFrontmost(win, cfg)
end

return WindowService
