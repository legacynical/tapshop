local clientScript = require("ui.popover.client_script")
local configModule = require("config")
local debugStyles = require("ui.popover.debug_styles")
local popoverRender = require("ui.popover.render")
local popoverStyles = require("ui.popover.styles")
local popoverTheme = require("ui.popover.theme")
local webviewPanel = require("ui.webview_panel")

local Popover = {}

function Popover.new(app, cfg, deps)
  local windowService = deps.windowService
  local settingsStore = deps.settingsStore

  local escTap = nil
  local panel = nil
  local callerWin = nil
  local activeWin = nil
  local pendingActiveWin = nil
  local pendingRefresh = false
  local refreshTimer = nil
  local isDragging = false
  local isResizing = false
  local savedTopLeft = settingsStore.getPoint(configModule.keys.popoverTopLeft)
  local savedSize = settingsStore.getSize(configModule.keys.popoverSize)

  local POP_W = 500
  local POP_H = 272
  local POP_MIN_W = 320
  local POP_MIN_H = 260
  local POP_MAX_H = 408
  local POP_SCREEN_MARGIN = 32

  local function pickScreen()
    return hs.mouse.getCurrentScreen()
      or (activeWin and activeWin:screen())
      or (callerWin and callerWin:screen())
      or hs.screen.mainScreen()
  end

  local function maxPopoverHeight(screen)
    local visibleFrame = screen:frame()
    return math.max(POP_MIN_H, math.min(POP_MAX_H, math.floor(visibleFrame.h - POP_SCREEN_MARGIN)))
  end

  local function clampPopoverHeight(height, screen)
    return math.max(POP_MIN_H, math.min(height, maxPopoverHeight(screen or pickScreen())))
  end

  local function currentPopoverSize(screen)
    return {
      w = math.max(POP_MIN_W, savedSize and savedSize.w or POP_W),
      h = clampPopoverHeight(POP_H, screen),
    }
  end

  local function centeredRect(screen)
    local size = currentPopoverSize(screen)
    local visibleFrame = screen:frame()
    return hs.geometry.rect(
      math.floor(visibleFrame.x + (visibleFrame.w - size.w) / 2),
      math.floor(visibleFrame.y + (visibleFrame.h - size.h) / 2),
      size.w,
      size.h
    )
  end

  local function currentPopoverLevel()
    if cfg.popoverAlwaysOnTop then
      return hs.drawing.windowLevels.popUpMenu
    end
    return hs.drawing.windowLevels.normal
  end

  local function saveTopLeftFromFrame(panel)
    local frame = panel:getWebview():frame()
    savedTopLeft = {
      x = math.floor(frame.x),
      y = math.floor(frame.y),
    }
    settingsStore.setPoint(configModule.keys.popoverTopLeft, savedTopLeft)
  end

  local function saveSizeFromFrame(panel)
    local frame = panel:getWebview():frame()
    savedSize = {
      w = math.max(POP_MIN_W, math.floor(frame.w)),
      h = POP_H,
    }
    settingsStore.setSize(configModule.keys.popoverSize, savedSize)
  end

  local function currentHeaderLines()
    local info = windowService.getWindowInfo(activeWin)
      or windowService.getWindowInfo(callerWin)
      or windowService.getWindowInfo()
    local primaryLine = "No active window found"
    local secondaryLine = ""

    if info then
      local rawTitle = info.title or ""
      local title = rawTitle:match("%S") and rawTitle or "[untitled]"
      local windowId = tostring(info.id or "?")
      local appName = info.appName or ""

      primaryLine = title
      if appName:match("%S") then
        secondaryLine = string.format("%s (%s)", appName, windowId)
      else
        secondaryLine = string.format("(%s)", windowId)
      end
    end

    return primaryLine, secondaryLine
  end

  local function slotLabel(workspace, pairedWin)
    if not workspace:isPaired() then
      return "[empty]"
    end

    if pairedWin then
      local info = windowService.getWindowInfo(pairedWin)
      if info then
        local appName = info.appName or ""
        local rawTitle = info.title or ""
        local title = rawTitle:match("%S") and rawTitle or "[untitled]"
        if appName:match("%S") then
          return string.format("[%s] %s", appName, title)
        end
      end
    end

    return workspace.displayTitle or "[empty]"
  end

  local function buildRowsViewModel()
    local rows = {}

    for index, workspace in ipairs(app:getWorkspaces()) do
      local isPaired = workspace:isPaired()
      local pairedWin = nil
      local isMinimized = false
      local className = "unpaired"

      if isPaired then
        pairedWin = windowService.getWindowById(workspace.id)
        isMinimized = pairedWin and pairedWin:isMinimized() or false
        if isMinimized then
          className = "paired-minimized"
        else
          className = "paired"
        end
      end

      rows[#rows + 1] = {
        index = index,
        label = slotLabel(workspace, pairedWin),
        className = className,
        isMinimized = isMinimized,
        canUnpair = isPaired,
      }
    end

    return rows
  end

  local function buildRenderContext()
    local theme = popoverTheme.buildTheme(cfg)
    local primaryLine, secondaryLine = currentHeaderLines()
    local css = popoverStyles.buildCss(theme)

    if cfg.popoverDebugWindow then
      css = css .. "\n" .. debugStyles.css
    end

    return {
      css = css,
      script = clientScript.script,
      theme = theme,
      primaryLine = primaryLine,
      secondaryLine = secondaryLine,
      config = {
        autoHideAfterAction = cfg.popoverAutoHideAfterAction == true,
        alwaysOnTop = cfg.popoverAlwaysOnTop == true,
        debugWindow = cfg.popoverDebugWindow == true,
        opacityPercent = theme.opacityPercent,
      },
      rows = buildRowsViewModel(),
    }
  end

  local function stopRefreshTimer()
    if refreshTimer then
      refreshTimer:stop()
      refreshTimer = nil
    end
  end

  local function flushQueuedRefresh()
    pendingRefresh = false
    stopRefreshTimer()

    if pendingActiveWin ~= nil then
      activeWin = pendingActiveWin
      pendingActiveWin = nil
    end

    if panel:isShown() then
      panel:refresh()
      return
    end

    panel:markDirty()
  end

  local function queueRefresh()
    if pendingRefresh then
      return
    end

    pendingRefresh = true
    stopRefreshTimer()
    refreshTimer = hs.timer.doAfter(0, flushQueuedRefresh)
  end

  panel = webviewPanel.new({
    messageHandler = "tapshop",
    initialRect = function()
      local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
      return centeredRect(screen)
    end,
    windowStyle = hs.webview.windowMasks.borderless,
    transparent = true,
    level = currentPopoverLevel,
    allowTextEntry = true,
    buildHtml = function()
      return popoverRender.buildHtml(buildRenderContext())
    end,
    handleAction = function(panelRef, msg)
      local body = msg.body or {}
      local action = body.action
      if action == "dragStart" then
        isDragging = true
        return
      end
      if action == "dragMove" then
        if not isDragging then
          return
        end
        local dx = tonumber(body.dx) or 0
        local dy = tonumber(body.dy) or 0
        if dx == 0 and dy == 0 then
          return
        end
        local frame = panelRef:getWebview():frame()
        panelRef:getWebview():topLeft({
          x = frame.x + dx,
          y = frame.y + dy,
        })
        return
      end
      if action == "dragEnd" then
        isDragging = false
        saveTopLeftFromFrame(panelRef)
        return
      end
      if action == "resizeStart" then
        isResizing = true
        return
      end
      if action == "resizeMove" then
        if not isResizing then
          return
        end
        local dw = tonumber(body.dw) or 0
        local dh = tonumber(body.dh) or 0
        local direction = tostring(body.direction or "")
        if dw == 0 and dh == 0 then
          return
        end
        local frame = panelRef:getWebview():frame()
        local nextX = frame.x
        local nextY = frame.y
        local nextW = frame.w
        local nextH = frame.h

        if direction:find("w", 1, true) then
          nextW = math.max(POP_MIN_W, frame.w - dw)
          nextX = frame.x + (frame.w - nextW)
        elseif direction:find("e", 1, true) then
          nextW = math.max(POP_MIN_W, frame.w + dw)
        end

        if direction:find("n", 1, true) then
          nextH = clampPopoverHeight(frame.h - dh)
          nextY = frame.y + (frame.h - nextH)
        elseif direction:find("s", 1, true) then
          nextH = clampPopoverHeight(frame.h + dh)
        end

        panelRef:getWebview():frame(hs.geometry.rect(nextX, nextY, nextW, nextH))
        return
      end
      if action == "resizeEnd" then
        isResizing = false
        saveTopLeftFromFrame(panelRef)
        saveSizeFromFrame(panelRef)
        return
      end
      if action == "close" then
        panelRef:hide()
        return
      end
      if action == "pair" then
        body.sourceWindow = activeWin or callerWin
      end
      app:handlePopoverAction(body)
      if action == "setAlwaysOnTop" then
        panelRef:setLevel(currentPopoverLevel())
      end
    end,
    windowCallback = function(panelRef, act, _, state)
      if act == "focusChange" and state == false and panelRef:isShown() and not cfg.popoverAlwaysOnTop then
        panelRef:hide()
      end
    end,
    beforeShow = function(_, view)
      callerWin = hs.window.frontmostWindow()
      activeWin = callerWin
      local size = currentPopoverSize()
      if savedTopLeft then
        view:frame(hs.geometry.rect(savedTopLeft.x, savedTopLeft.y, size.w, size.h))
      else
        local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
        view:frame(centeredRect(screen))
      end
      view:level(currentPopoverLevel())
    end,
    afterShow = function(panelRef)
      if not escTap then
        escTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(evt)
          if evt:getKeyCode() == hs.keycodes.map.escape and panelRef:isShown() then
            panelRef:hide()
            return true
          end
          return false
        end)
      end
      escTap:start()
    end,
    beforeHide = function()
      isDragging = false
      isResizing = false
      if escTap then
        escTap:stop()
      end
    end,
  })

  local instance = {}

  function instance:show()
    panel:show()
  end

  function instance:hide()
    panel:hide()
  end

  function instance:toggle()
    panel:toggle()
  end

  function instance:refreshIfShown()
    if panel:isShown() then
      panel:refresh()
      return
    end
    panel:markDirty()
  end

  function instance:refreshCache()
    panel:markDirty()
    panel:setLevel(currentPopoverLevel())
    if panel:isShown() then
      panel:refresh()
    end
  end

  function instance:requestRefresh(_)
    queueRefresh()
  end

  function instance:requestActiveWindowUpdate(win)
    pendingActiveWin = win or hs.window.frontmostWindow() or activeWin
    queueRefresh()
  end

  function instance:updateActiveWindow(win)
    self:requestActiveWindowUpdate(win)
  end

  function instance:getDebugState()
    return {
      isShown = panel:isShown(),
      callerWindow = windowService.getWindowInfo(callerWin),
      activeWindow = windowService.getWindowInfo(activeWin),
    }
  end

  return instance
end

return Popover
