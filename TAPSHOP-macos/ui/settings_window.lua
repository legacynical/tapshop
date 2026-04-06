local clientScript = require("ui.settings.client_script")
local configModule = require("config")
local hotkeyList = require("ui.settings.hotkey_list")
local settingsLayout = require("ui.settings.layout")
local settingsRender = require("ui.settings.render")
local settingsStyles = require("ui.settings.styles")
local popoverTheme = require("ui.popover.theme")
local webviewPanel = require("ui.webview_panel")

local SettingsWindow = {}

function SettingsWindow.new(app, cfg, deps)
  local settingsStore = deps.settingsStore

  local panel = nil
  local cachedThemeCss = nil
  local isDragging = false
  local isResizing = false
  local isFocused = false
  local state = {
    tab = "general",
    search = "",
    scrollTop = 0,
    validation = nil,
  }
  local savedTopLeft = settingsStore.getPoint(configModule.keys.settingsTopLeft)
  local savedSize = settingsLayout.loadSavedSize(settingsStore, configModule.keys)
  local runtimeBounds = settingsLayout.initialRuntimeBounds()

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
      state.search = body.search
    end
    if type(body.settingsTab) == "string" then
      state.tab = normalizeSettingsTab(body.settingsTab)
    end
    local scrollTop = tonumber(body.scrollTop)
    if scrollTop then
      state.scrollTop = math.max(0, math.floor(scrollTop))
    end
  end

  local function pickScreen()
    return hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  end

  local function screenFrame(screen)
    if not screen then
      return nil
    end
    local frame = screen:frame()
    return {
      x = math.floor(frame.x),
      y = math.floor(frame.y),
      w = math.floor(frame.w),
      h = math.floor(frame.h),
    }
  end

  local function frameTable(frame)
    return {
      x = math.floor(frame.x),
      y = math.floor(frame.y),
      w = math.floor(frame.w),
      h = math.floor(frame.h),
    }
  end

  local function geometryRect(frame)
    return hs.geometry.rect(frame.x, frame.y, frame.w, frame.h)
  end

  local function currentPanelLevel()
    if cfg.popoverAlwaysOnTop then
      return hs.drawing.windowLevels.popUpMenu
    end
    return hs.drawing.windowLevels.normal
  end

  local function saveTopLeftFromFrame(panelRef)
    local frame = panelRef:getWebview():frame()
    savedTopLeft = {
      x = math.floor(frame.x),
      y = math.floor(frame.y),
    }
    settingsStore.setPoint(configModule.keys.settingsTopLeft, savedTopLeft)
  end

  local function saveSize(size, screen)
    local clamped = settingsLayout.clampSize(
      size,
      screenFrame(screen or pickScreen()),
      runtimeBounds
    )
    savedSize = clamped
    settingsStore.setSize(configModule.keys.settingsSize, clamped)
    return clamped
  end

  local function saveSizeFromFrame(panelRef)
    local frame = panelRef:getWebview():frame()
    return saveSize({
      w = math.floor(frame.w),
      h = math.floor(frame.h),
    })
  end

  local function requestBoundsRecompute(panelRef)
    if panelRef and panelRef:isShown() then
      panelRef:evaluateJavaScript("window.tapshopRecomputeBounds && window.tapshopRecomputeBounds()")
    end
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
      validation = state.validation,
      scrollTop = state.scrollTop or 0,
    }) or "{}"
    panelRef:evaluateJavaScript("window.tapshopApplyHotkeyState(" .. payload .. ")")
  end

  local function buildRenderContext()
    local theme = popoverTheme.buildTheme(cfg)
    local css = cachedThemeCss or settingsStyles.buildCss(theme)
    local shouldRenderHotkeys = state.tab == "hotkeys"
    local hotkeyState = {
      rows = {},
      conflictsById = {},
      overrides = {},
    }
    local hotkeysHtml = nil

    if shouldRenderHotkeys then
      hotkeyState = app:getHotkeyUiState()
      if app.hotkeyManager and app.hotkeyManager.getHotkeyHtmlCached then
        hotkeysHtml = app.hotkeyManager:getHotkeyHtmlCached(hotkeyList.buildHtml)
      else
        hotkeysHtml = hotkeyList.buildHtml(hotkeyState.rows or {})
      end
    end

    return {
      css = css,
      script = clientScript.script,
      layoutPolicy = settingsLayout.clientPolicy(),
      config = {
        autoHideAfterAction = cfg.popoverAutoHideAfterAction == true,
        alwaysOnTop = cfg.popoverAlwaysOnTop == true,
        hidePairButtons = cfg.popoverHidePairButtons == true,
        recoverClosedWindows = cfg.recoverClosedWindows == true,
        opacityPercent = theme.opacityPercent,
      },
      settingsTab = state.tab,
      search = state.search,
      scrollTop = state.scrollTop or 0,
      validation = state.validation,
      hotkeys = hotkeyState.rows or {},
      hotkeysHtml = hotkeysHtml,
    }
  end

  panel = webviewPanel.new({
    messageHandler = "tapshopSettings",
    initialRect = function()
      local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
      return geometryRect(settingsLayout.centeredFrame(
        screenFrame(screen),
        savedSize,
        runtimeBounds
      ))
    end,
    windowStyle = hs.webview.windowMasks.borderless,
    transparent = true,
    level = currentPanelLevel,
    allowTextEntry = true,
    buildHtml = function()
      return settingsRender.buildHtml(buildRenderContext())
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
        local minWidth = settingsLayout.minWidth()
        local currentScreenFrame = screenFrame(pickScreen())

        if direction:find("w", 1, true) then
          nextW = math.max(minWidth, frame.w - dw)
          nextX = frame.x + (frame.w - nextW)
        elseif direction:find("e", 1, true) then
          nextW = math.max(minWidth, frame.w + dw)
        end

        if direction:find("n", 1, true) then
          nextH = settingsLayout.clampSize({
            w = nextW,
            h = frame.h - dh,
          }, currentScreenFrame, runtimeBounds).h
          nextY = frame.y + (frame.h - nextH)
        elseif direction:find("s", 1, true) then
          nextH = settingsLayout.clampSize({
            w = nextW,
            h = frame.h + dh,
          }, currentScreenFrame, runtimeBounds).h
        end

        panelRef:getWebview():frame(hs.geometry.rect(nextX, nextY, nextW, nextH))
        return
      end
      if action == "updateSettingsBounds" then
        local targetMinHeight = tonumber(body.targetMinHeight)
        local derivedMinHeight = tonumber(body.derivedMinHeight)
        local derivedMaxHeight = tonumber(body.derivedMaxHeight)
        local derivedMinUiScale = tonumber(body.derivedMinUiScale)
        local maxUiScale = tonumber(body.maxUiScale)
        local measuredMinHeight = tonumber(body.measuredMinHeight)
        local currentHeight = tonumber(body.currentHeight)
        local currentUiScale = tonumber(body.currentUiScale)
        local shellHeight = tonumber(body.shellHeight)
        local scrollHeight = tonumber(body.scrollHeight)
        if not derivedMinHeight or not derivedMaxHeight then
          return
        end

        local normalizedMinHeight = math.max(settingsLayout.targetMinHeight(), math.floor(derivedMinHeight + 0.5))
        local normalizedMaxHeight = math.max(normalizedMinHeight, math.floor(derivedMaxHeight + 0.5))
        runtimeBounds = {
          minHeight = normalizedMinHeight,
          maxHeight = normalizedMaxHeight,
          minUiScale = derivedMinUiScale,
          maxUiScale = maxUiScale,
          targetMinHeight = targetMinHeight,
          measuredMinHeight = measuredMinHeight,
          currentHeight = currentHeight,
          currentUiScale = currentUiScale,
          shellHeight = shellHeight,
          scrollHeight = scrollHeight,
        }

        if not isResizing then
          local currentFrame = frameTable(panelRef:getWebview():frame())
          local nextFrame = settingsLayout.clampFrame(
            currentFrame,
            screenFrame(pickScreen()),
            runtimeBounds
          )
          if nextFrame.x ~= currentFrame.x
            or nextFrame.y ~= currentFrame.y
            or nextFrame.w ~= currentFrame.w
            or nextFrame.h ~= currentFrame.h then
            panelRef:getWebview():frame(geometryRect(nextFrame))
            saveTopLeftFromFrame(panelRef)
            saveSize({
              w = nextFrame.w,
              h = nextFrame.h,
            })
          else
            local clampedSavedSize = settingsLayout.clampSize(savedSize, screenFrame(pickScreen()), runtimeBounds)
            if savedSize.w ~= clampedSavedSize.w or savedSize.h ~= clampedSavedSize.h then
              saveSize(clampedSavedSize)
            end
          end
        end
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
      if action == "setSettingsTab" then
        state.validation = nil
        state.tab = normalizeSettingsTab(body.settingsTab)
        if state.tab == "hotkeys" then
          pushHotkeyState(panelRef)
        end
        requestBoundsRecompute(panelRef)
        return
      end
      if action == "setHotkeySearch" then
        return
      end

      local result = app:handlePopoverAction(body)
      if action == "updateHotkeyBinding" or action == "resetHotkeyBinding" or action == "resetAllHotkeys" then
        if result and result.ok then
          state.validation = nil
          pushHotkeyState(panelRef)
        else
          state.validation = result
          pushValidationState(panelRef, result)
        end
        return
      end
      if action == "setAlwaysOnTop" then
        panelRef:setLevel(currentPanelLevel())
      end
    end,
    windowCallback = function(_, act, _, focusState)
      if act == "focusChange" then
        isFocused = focusState == true
      end
    end,
    beforeShow = function(_, view)
      local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
      if savedTopLeft then
        local frame = settingsLayout.frameForTopLeft(
          savedTopLeft,
          screenFrame(screen),
          savedSize,
          runtimeBounds
        )
        view:frame(geometryRect(frame))
        if frame.x ~= savedTopLeft.x or frame.y ~= savedTopLeft.y then
          savedTopLeft = { x = frame.x, y = frame.y }
          settingsStore.setPoint(configModule.keys.settingsTopLeft, savedTopLeft)
        end
      else
        view:frame(geometryRect(settingsLayout.centeredFrame(
          screenFrame(screen),
          savedSize,
          runtimeBounds
        )))
      end
      view:level(currentPanelLevel())
    end,
    afterShow = function(panelRef)
      requestBoundsRecompute(panelRef)
    end,
    beforeHide = function()
      isDragging = false
      isResizing = false
      isFocused = false
      state.search = ""
      state.scrollTop = 0
      state.validation = nil
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

  function instance:toggleOrFocus()
    if panel:isShown() and isFocused then
      panel:hide()
      return
    end
    panel:show()
  end

  function instance:isShown()
    return panel:isShown()
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
    panel:setLevel(currentPanelLevel())
    if panel:isShown() then
      panel:refresh()
      requestBoundsRecompute(panel)
    end
  end

  function instance:warmStaticCaches()
    local theme = popoverTheme.buildTheme(cfg)
    cachedThemeCss = settingsStyles.buildCss(theme)

    if app.warmHotkeyUiCache then
      app:warmHotkeyUiCache(hotkeyList.buildHtml)
    end
  end

  function instance:syncWindowLevel()
    panel:setLevel(currentPanelLevel())
  end

  return instance
end

return SettingsWindow
