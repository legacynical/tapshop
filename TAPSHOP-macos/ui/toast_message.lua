local ToastMessage = {}

local DEFAULT_TEXT_COLOR = { white = 1, alpha = 1 }

local function copyTable(value)
  if type(value) ~= "table" then
    return value
  end

  local out = {}
  for key, item in pairs(value) do
    out[key] = item
  end
  return out
end

local function normalizeSegment(segment)
  if type(segment) ~= "table" then
    return {
      text = tostring(segment or ""),
      color = copyTable(DEFAULT_TEXT_COLOR),
    }
  end

  return {
    text = tostring(segment.text or ""),
    color = copyTable(segment.color) or copyTable(DEFAULT_TEXT_COLOR),
  }
end

local function normalizeLine(line)
  if type(line) ~= "table" then
    return {
      segments = {
        normalizeSegment(line),
      },
    }
  end

  local segments = {}
  if type(line.segments) == "table" then
    for _, segment in ipairs(line.segments) do
      segments[#segments + 1] = normalizeSegment(segment)
    end
  elseif line.text ~= nil then
    segments[#segments + 1] = normalizeSegment({
      text = line.text,
      color = line.color,
    })
  end

  if #segments == 0 then
    segments[#segments + 1] = normalizeSegment("")
  end

  local bundleID = nil
  if type(line.imageBundleID) == "string" and line.imageBundleID ~= "" then
    bundleID = line.imageBundleID
  end

  local appName = nil
  if type(line.imageAppName) == "string" and line.imageAppName ~= "" then
    appName = line.imageAppName
  end

  local imagePath = nil
  if type(line.imagePath) == "string" and line.imagePath ~= "" then
    imagePath = line.imagePath
  end

  return {
    imageBundleID = bundleID,
    imageAppName = appName,
    imagePath = imagePath,
    segments = segments,
  }
end

function ToastMessage.plain(text, opts)
  local options = opts or {}
  return {
    duration = options.duration,
    lines = {
      {
        segments = {
          {
            text = tostring(text or ""),
            color = copyTable(options.color) or copyTable(DEFAULT_TEXT_COLOR),
          },
        },
      },
    },
  }
end

function ToastMessage.status(text, opts)
  local message = ToastMessage.plain(text, opts)
  local options = opts or {}

  if type(options.imageBundleID) == "string" and options.imageBundleID ~= "" then
    message.lines[1].imageBundleID = options.imageBundleID
  end
  if type(options.imageAppName) == "string" and options.imageAppName ~= "" then
    message.lines[1].imageAppName = options.imageAppName
  end
  if type(options.imagePath) == "string" and options.imagePath ~= "" then
    message.lines[1].imagePath = options.imagePath
  end

  return message
end

function ToastMessage.windowAction(opts)
  local options = opts or {}
  local titleText = options.titleText
  if titleText == nil or titleText == "" then
    titleText = "[empty]"
  end

  local line = {
    imageBundleID = options.bundleID,
    imageAppName = options.appName,
    imagePath = options.imagePath,
    segments = {
      {
        text = tostring(options.prefixText or ""),
        color = copyTable(options.prefixColor) or copyTable(DEFAULT_TEXT_COLOR),
      },
      {
        text = tostring(titleText),
        color = copyTable(options.titleColor) or copyTable(DEFAULT_TEXT_COLOR),
      },
    },
  }

  if options.suffixText ~= nil and options.suffixText ~= "" then
    line.segments[#line.segments + 1] = {
      text = tostring(options.suffixText),
      color = copyTable(options.suffixColor) or copyTable(DEFAULT_TEXT_COLOR),
    }
  end

  return {
    duration = options.duration,
    lines = { line },
  }
end

function ToastMessage.normalize(input, defaultDuration)
  if type(input) == "table" then
    local lines = {}

    if type(input.lines) == "table" then
      for _, line in ipairs(input.lines) do
        lines[#lines + 1] = normalizeLine(line)
      end
    elseif type(input.segments) == "table" or input.text ~= nil then
      lines[#lines + 1] = normalizeLine(input)
    end

    if #lines > 0 then
      return {
        duration = input.duration ~= nil and input.duration or defaultDuration,
        lines = lines,
      }
    end
  end

  local plain = ToastMessage.plain(tostring(input or ""), {
    duration = defaultDuration,
  })

  return {
    duration = plain.duration,
    lines = {
      normalizeLine(plain.lines[1]),
    },
  }
end

return ToastMessage
