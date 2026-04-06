local Toast = {}
local ToastMessage = require("ui.toast_message")

function Toast.new(cfg)
  local lines = {}
  local timer = nil
  local canvas = nil
  local defaultSecs = 2.0
  local defaultTextColor = { white = 1, alpha = 1 }
  local prefixColor = { white = 1, alpha = 0.55 }
  local hiddenPrefixColor = { white = 1, alpha = 0 }
  local iconGap = 8
  local padding = 14
  local cornerRadius = 8

  local function styledChunk(text, color)
    return hs.styledtext.new(tostring(text), {
      color = color or defaultTextColor,
      font = {
        name = ".AppleSystemUIFont",
        size = cfg.tapshopMsgTextSize,
      },
    })
  end

  local function lineHeight()
    return math.floor(cfg.tapshopMsgTextSize * 1.35)
  end

  local function lineImage(line)
    if type(line) ~= "table" then
      return nil
    end

    if line.image then
      return line.image
    end

    local bundleID = line.imageBundleID
    if (type(bundleID) ~= "string" or bundleID == "")
      and type(line.imageAppName) == "string"
      and line.imageAppName ~= "" then
      local app = hs.application.find(line.imageAppName)
      bundleID = app and app:bundleID() or nil
    end

    if type(bundleID) ~= "string" or bundleID == "" then
      return nil
    end

    local image = hs.image.imageFromAppBundle(bundleID)
    if not image then
      return nil
    end

    local size = math.max(12, math.floor(lineHeight() * 0.95))
    return image:setSize({ h = size, w = size })
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
    local height = padding * 2 + (lineCount * lineHeight())

    local x = math.floor(visibleFrame.x + (visibleFrame.w - width) / 2)
    local y = math.floor(visibleFrame.y + visibleFrame.h - cfg.tapshopMsgBottomMargin - height)

    local rect = hs.geometry.rect(x, y, width, height)
    local contentRect = {
      x = padding,
      y = padding,
      w = width - padding * 2,
      h = height - padding * 2,
    }

    return rect, contentRect
  end

  local function destroy()
    if timer then
      timer:stop()
      timer = nil
    end
    if canvas then
      canvas:delete()
      canvas = nil
    end
  end

  local function styledSegments(segments, prefixStyled)
    local styledText = prefixStyled

    for _, segment in ipairs(segments or {}) do
      styledText = (styledText or styledChunk("", defaultTextColor))
        .. styledChunk(segment.text or "", segment.color)
    end

    return styledText or styledChunk(" ", defaultTextColor)
  end

  local function prefixStyledText(isLatest, showPrefixes)
    if not showPrefixes then
      return nil
    end

    local styledText = styledChunk("", defaultTextColor)
    if isLatest then
      return styledText .. styledChunk("> ", prefixColor)
    end

    return styledText
      .. styledChunk(">", hiddenPrefixColor)
      .. styledChunk(" ", prefixColor)
  end

  local function resolveLineParts(line, isLatest, showPrefixes)
    local prefix = prefixStyledText(isLatest, showPrefixes)
    local segments = line.segments or {}
    local image = lineImage(line)

    if image and #segments >= 2 then
      return {
        { kind = "text", styled = styledSegments({ segments[1] }, prefix) },
        { kind = "image", image = image },
        { kind = "text", styled = styledSegments({ table.unpack(segments, 2) }), flexible = true },
      }
    end

    if image then
      return {
        { kind = "image", image = image },
        { kind = "text", styled = styledSegments(segments, prefix), flexible = true },
      }
    end

    return {
      { kind = "text", styled = styledSegments(segments, prefix), flexible = true },
    }
  end

  local function buildElements(rect, contentRect)
    local elements = {
      {
        id = "background",
        type = "rectangle",
        action = "fill",
        roundedRectRadii = { xRadius = cornerRadius, yRadius = cornerRadius },
        fillColor = { red = 0, green = 0, blue = 0, alpha = 0.70 },
        frame = { x = 0, y = 0, w = rect.w, h = rect.h },
      },
    }

    local currentLineHeight = lineHeight()
    local imageSize = math.max(12, math.floor(currentLineHeight * 0.95))
    local showPrefixes = #lines > 1

    for i = 1, #lines do
      local line = lines[i]
      local parts = resolveLineParts(line, i == #lines, showPrefixes)
      local lineY = contentRect.y + ((i - 1) * currentLineHeight)
      local cursorX = contentRect.x
      local remainingWidth = contentRect.w

      for partIndex, part in ipairs(parts) do
        if part.kind == "image" then
          elements[#elements + 1] = {
            id = string.format("line_%d_part_%d_image", i, partIndex),
            type = "image",
            action = "fill",
            image = part.image,
            imageScaling = "scaleProportionally",
            frame = {
              x = cursorX,
              y = lineY + math.max(0, math.floor((currentLineHeight - imageSize) / 2)),
              w = imageSize,
              h = imageSize,
            },
          }
          cursorX = cursorX + imageSize + iconGap
          remainingWidth = math.max(0, (contentRect.x + contentRect.w) - cursorX)
        else
          local desired = hs.drawing.getTextDrawingSize(part.styled)
          local partWidth = remainingWidth
          if not part.flexible then
            partWidth = desired and math.ceil(desired.w) + 4 or remainingWidth
            partWidth = math.min(math.max(1, partWidth), remainingWidth)
          end

          elements[#elements + 1] = {
            id = string.format("line_%d_part_%d_text", i, partIndex),
            type = "text",
            action = "fill",
            text = part.styled,
            frame = {
              x = cursorX,
              y = lineY,
              w = math.max(1, partWidth),
              h = currentLineHeight,
            },
          }
          cursorX = cursorX + partWidth
          remainingWidth = math.max(0, (contentRect.x + contentRect.w) - cursorX)
        end
      end
    end

    return elements
  end

  local function ensureCanvas(rect)
    if not canvas then
      canvas = hs.canvas.new(rect)
      canvas:level(hs.canvas.windowLevels.popUpMenu)
      canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
    else
      canvas:frame(rect)
    end
    return canvas
  end

  local function render()
    local rect, contentRect = computeRects(#lines)
    local target = ensureCanvas(rect)
    local elements = buildElements(rect, contentRect)
    target:replaceElements(table.unpack(elements))
    target:show()
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
    local normalized = ToastMessage.normalize(msg, secs)
    for _, line in ipairs(normalized.lines) do
      lines[#lines + 1] = line
    end
    if #lines > cfg.tapshopMsgMaxLines then
      while #lines > cfg.tapshopMsgMaxLines do
        table.remove(lines, 1)
      end
    end
    render()
    scheduleClear(normalized.duration or secs or defaultSecs)
  end
end

return Toast
