local Toast = {}

function Toast.new(cfg)
  local lines = {}
  local timer = nil
  local background = nil
  local textBox = nil
  local defaultSecs = 2.0
  local defaultTextColor = { white = 1, alpha = 1 }
  local prefixColor = { white = 1, alpha = 0.55 }
  local hiddenPrefixColor = { white = 1, alpha = 0 }

  local function styledChunk(text, color)
    return hs.styledtext.new(tostring(text), {
      color = color or defaultTextColor,
      font = {
        name = ".AppleSystemUIFont",
        size = cfg.tapshopMsgTextSize,
      },
    })
  end

  local function normalizeLine(entry)
    if type(entry) == "table" and type(entry.segments) == "table" then
      return entry
    end
    return {
      prefix = true,
      segments = {
        { text = tostring(entry), color = defaultTextColor },
      },
    }
  end

  local function pickScreen()
    return hs.mouse.getCurrentScreen()
      or (hs.window.frontmostWindow() and hs.window.frontmostWindow():screen())
      or hs.screen.mainScreen()
  end

  local function computeRects(lineCount)
    local screen = pickScreen()
    local visibleFrame = screen:frame()
    local width = cfg.tapshopMsgWidth
    local textSize = cfg.tapshopMsgTextSize
    local padding = 14
    local lineHeight = math.floor(textSize * 1.35)
    local height = padding * 2 + (lineCount * lineHeight)

    local x = math.floor(visibleFrame.x + (visibleFrame.w - width) / 2)
    local y = math.floor(visibleFrame.y + visibleFrame.h - cfg.tapshopMsgBottomMargin - height)

    local rect = hs.geometry.rect(x, y, width, height)
    local textRect = hs.geometry.rect(
      x + padding,
      y + padding,
      width - padding * 2,
      height - padding * 2
    )

    return rect, textRect
  end

  local function destroy()
    if timer then
      timer:stop()
      timer = nil
    end
    if background then
      background:delete()
      background = nil
    end
    if textBox then
      textBox:delete()
      textBox = nil
    end
  end

  local function render()
    local styledText = nil
    local showPrefixes = #lines > 1
    for i = 1, #lines do
      local line = normalizeLine(lines[i])
      if styledText then
        styledText = styledText .. styledChunk("\n", defaultTextColor)
      end
      if showPrefixes then
        styledText = (styledText or styledChunk("", defaultTextColor))
        if i == #lines then
          styledText = styledText .. styledChunk("> ", prefixColor)
        else
          -- Reserve the same glyph width as "> " without showing the marker.
          styledText = styledText
            .. styledChunk(">", hiddenPrefixColor)
            .. styledChunk(" ", prefixColor)
        end
      end
      for _, segment in ipairs(line.segments) do
        styledText = (styledText or styledChunk("", defaultTextColor))
          .. styledChunk(segment.text or "", segment.color)
      end
    end

    if not styledText then
      styledText = styledChunk(" ", defaultTextColor)
    end

    local rect, textRect = computeRects(#lines)
    if not background then
      background = hs.drawing.rectangle(rect)
      background:setFill(true)
      background:setFillColor({ red = 0, green = 0, blue = 0, alpha = 0.70 })
      background:setStroke(false)
      background:setRoundedRectRadii(8, 8)
      background:setLevel(hs.drawing.windowLevels.popUpMenu)
      background:setBehavior(hs.drawing.windowBehaviors.canJoinAllSpaces)
    else
      background:setFrame(rect)
    end

    if not textBox then
      textBox = hs.drawing.text(textRect, styledText)
      textBox:setTextSize(cfg.tapshopMsgTextSize)
      textBox:setLevel(hs.drawing.windowLevels.popUpMenu)
      textBox:setBehavior(hs.drawing.windowBehaviors.canJoinAllSpaces)
    else
      textBox:setFrame(textRect)
      textBox:setStyledText(styledText)
    end

    background:show()
    textBox:show()
  end

  local function scheduleClear(secs)
    if timer then
      timer:stop()
      timer = nil
    end

    timer = hs.timer.doAfter(secs, function()
      lines = {}
      destroy()
    end)
  end

  return function(msg, secs)
    lines[#lines + 1] = msg
    if #lines > cfg.tapshopMsgMaxLines then
      table.remove(lines, 1)
    end
    render()
    scheduleClear(secs ~= nil and secs or defaultSecs)
  end
end

return Toast
