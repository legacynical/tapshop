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

  local panel = nil
  local callerWin = nil
  local activeWin = nil
  local pendingActiveWin = nil
  local pendingRefresh = false
  local refreshTimer = nil
  local isDragging = false
  local isResizing = false
  local cachedThemeCss = nil
  local settingsState = {
    open = false,
    tab = "general",
    search = "",
    scrollTop = 0,
    validation = nil,
  }
  local savedTopLeft = settingsStore.getPoint(configModule.keys.popoverTopLeft)
  local savedSize = settingsStore.getSize(configModule.keys.popoverSize)

  local POP_W = 500
  local POP_H = 280
  local POP_MIN_W = 320
  local POP_MIN_H = 280
  local POP_MAX_H = 408
  local POP_SCREEN_MARGIN = 32

  local function normalizeSettingsTab(value)
    if value == "hotkeys" then
      return "hotkeys"
    end
    return "general"
  end

  local function syncUiStateFromBody(body)
    if type(body) ~= "table" then
      return
    end
    if type(body.search) == "string" then
      settingsState.search = body.search
    end
    if type(body.settingsTab) == "string" then
      settingsState.tab = normalizeSettingsTab(body.settingsTab)
    end
    local scrollTop = tonumber(body.scrollTop)
    if scrollTop then
      settingsState.scrollTop = math.max(0, math.floor(scrollTop))
    end
  end

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
      h = clampPopoverHeight((savedSize and savedSize.h) or POP_H, screen),
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
      h = clampPopoverHeight(math.floor(frame.h)),
    }
    settingsStore.setSize(configModule.keys.popoverSize, savedSize)
  end

  local function pushValidationState(panelRef, result)
    if not panelRef:isShown() then
      return
    end
    local payload = hs.json.encode(result or { message = "" }) or "{}"
    panelRef:evaluateJavaScript("window.tapshopApplyValidation(" .. payload .. ")")
  end

  local function pushHotkeyState(panelRef)
    if not panelRef:isShown() then
      return
    end

    local hotkeyState = app:getHotkeyUiState()
    local payload = hs.json.encode({
      rows = hotkeyState.rows or {},
      validation = settingsState.validation,
      scrollTop = settingsState.scrollTop or 0,
    }) or "{}"
    panelRef:evaluateJavaScript("window.tapshopApplyHotkeyState(" .. payload .. ")")
  end

  local function currentHeaderLines()
    local info = windowService.getWindowInfo(activeWin)
      or windowService.getWindowInfo(callerWin)
      or windowService.getWindowInfo()
    local primaryLine = "No active window found"
    local bundleID = nil
    local appName = nil

    if info then
      local rawTitle = info.title or ""
      local title = rawTitle:match("%S") and rawTitle or "[untitled]"
      appName = info.appName or ""
      bundleID = info.bundleID or nil

      primaryLine = title
    end

    return primaryLine, bundleID, appName
  end

  local function buildRenderContext()
    local theme = popoverTheme.buildTheme(cfg)
    local primaryLine, headerBundleID, headerAppName = currentHeaderLines()
    local css = cachedThemeCss or popoverStyles.buildCss(theme)
    local shouldRenderHotkeys = settingsState.open and settingsState.tab == "hotkeys"
    local hotkeyState = {
      rows = {},
      conflictsById = {},
      overrides = {},
    }
    local hotkeysHtml = nil

    if shouldRenderHotkeys then
      hotkeyState = app:getHotkeyUiState()
      if app.hotkeyManager and app.hotkeyManager.getHotkeyHtmlCached then
        hotkeysHtml = app.hotkeyManager:getHotkeyHtmlCached(popoverRender.buildHotkeysListHtml)
      else
        hotkeysHtml = popoverRender.buildHotkeysListHtml(hotkeyState.rows or {})
      end
    end

    if cfg.popoverDebugWindow then
      css = css .. "\n" .. debugStyles.css
    end

    return {
      css = css,
      script = clientScript.script,
      theme = theme,
      primaryLine = primaryLine,
      headerBundleID = headerBundleID,
      headerAppName = headerAppName,
      config = {
        autoHideAfterAction = cfg.popoverAutoHideAfterAction == true,
        alwaysOnTop = cfg.popoverAlwaysOnTop == true,
        debugWindow = cfg.popoverDebugWindow == true,
        opacityPercent = theme.opacityPercent,
      },
      settings = {
        open = settingsState.open == true,
        tab = settingsState.tab,
        search = settingsState.search,
        scrollTop = settingsState.scrollTop or 0,
        validation = settingsState.validation,
      },
      hotkeys = hotkeyState.rows or {},
      hotkeysHtml = hotkeysHtml,
      hotkeyConflicts = hotkeyState.conflictsById or {},
      hotkeyOverrides = hotkeyState.overrides or {},
      rows = app:getWorkspaceRowModels(),
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
      syncUiStateFromBody(body)
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
      if action == "toggleSettings" then
        settingsState.open = not settingsState.open
        settingsState.validation = nil
        if settingsState.open then
          settingsState.tab = normalizeSettingsTab(body.settingsTab)
          if settingsState.tab == "hotkeys" then
            pushHotkeyState(panelRef)
          end
        else
          settingsState.search = ""
          settingsState.scrollTop = 0
        end
        return
      end
      if action == "closeSettings" then
        settingsState.open = false
        settingsState.search = ""
        settingsState.scrollTop = 0
        settingsState.validation = nil
        return
      end
      if action == "setSettingsTab" then
        settingsState.open = true
        settingsState.validation = nil
        settingsState.tab = normalizeSettingsTab(body.settingsTab)
        if settingsState.tab == "hotkeys" then
          pushHotkeyState(panelRef)
        end
        return
      end
      if action == "setHotkeySearch" then
        return
      end
      if action == "pair" then
        body.sourceWindow = activeWin or callerWin
      end
      local result = app:handlePopoverAction(body)
      if action == "updateHotkeyBinding" or action == "resetHotkeyBinding" or action == "resetAllHotkeys" then
        if result and result.ok then
          settingsState.validation = nil
          pushHotkeyState(panelRef)
        else
          settingsState.validation = result
          pushValidationState(panelRef, result)
        end
        return
      end
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
    beforeHide = function()
      isDragging = false
      isResizing = false
      settingsState.open = false
      settingsState.search = ""
      settingsState.scrollTop = 0
      settingsState.validation = nil
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
    cachedThemeCss = nil
    panel:setLevel(currentPopoverLevel())
    if panel:isShown() then
      panel:refresh()
    end
  end

  function instance:warmStaticCaches()
    cachedThemeCss = popoverStyles.buildCss(popoverTheme.buildTheme(cfg))
    if app.warmHotkeyUiCache then
      app:warmHotkeyUiCache(popoverRender.buildHotkeysListHtml)
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
