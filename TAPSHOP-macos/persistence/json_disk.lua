local JsonDisk = {}

local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function parentDir(path)
  return tostring(path):match("^(.*)/[^/]+$") or "."
end

local function ensureDir(path)
  local dir = parentDir(path)

  if hs and hs.fs and type(hs.fs.mkdir) == "function" then
    local current = ""
    if dir:sub(1, 1) == "/" then
      current = "/"
    end

    for segment in string.gmatch(dir, "[^/]+") do
      if current == "" or current == "/" then
        current = current .. segment
      else
        current = current .. "/" .. segment
      end
      pcall(hs.fs.mkdir, current)
    end
    return dir
  end

  os.execute("mkdir -p " .. shellQuote(dir))
  return dir
end

local function tmpPath(path)
  return tostring(path) .. ".tmp"
end

local function corruptPath(path)
  local timestamp = os.date("%Y%m%d-%H%M%S")
  local stem, ext = tostring(path):match("^(.*)(%.[^./]+)$")
  if not stem then
    stem = tostring(path)
    ext = ""
  end
  return string.format("%s.corrupt-%s%s", stem, timestamp, ext)
end

local function skipWhitespace(source, index)
  while index <= #source do
    local char = source:sub(index, index)
    if char ~= " " and char ~= "\n" and char ~= "\r" and char ~= "\t" then
      break
    end
    index = index + 1
  end
  return index
end

local function parseString(source, index)
  local parts = {}
  index = index + 1

  while index <= #source do
    local char = source:sub(index, index)
    if char == "\"" then
      return table.concat(parts), index + 1
    end

    if char == "\\" then
      local esc = source:sub(index + 1, index + 1)
      if esc == "\"" or esc == "\\" or esc == "/" then
        parts[#parts + 1] = esc
        index = index + 2
      elseif esc == "b" then
        parts[#parts + 1] = "\b"
        index = index + 2
      elseif esc == "f" then
        parts[#parts + 1] = "\f"
        index = index + 2
      elseif esc == "n" then
        parts[#parts + 1] = "\n"
        index = index + 2
      elseif esc == "r" then
        parts[#parts + 1] = "\r"
        index = index + 2
      elseif esc == "t" then
        parts[#parts + 1] = "\t"
        index = index + 2
      elseif esc == "u" then
        local hex = source:sub(index + 2, index + 5)
        if #hex ~= 4 or not hex:match("^[0-9a-fA-F]+$") then
          return nil, "invalid unicode escape"
        end
        local codepoint = tonumber(hex, 16)
        if codepoint <= 0x7F then
          parts[#parts + 1] = string.char(codepoint)
        elseif codepoint <= 0x7FF then
          parts[#parts + 1] = string.char(
            0xC0 + math.floor(codepoint / 0x40),
            0x80 + (codepoint % 0x40)
          )
        else
          parts[#parts + 1] = string.char(
            0xE0 + math.floor(codepoint / 0x1000),
            0x80 + (math.floor(codepoint / 0x40) % 0x40),
            0x80 + (codepoint % 0x40)
          )
        end
        index = index + 6
      else
        return nil, "invalid escape sequence"
      end
    else
      parts[#parts + 1] = char
      index = index + 1
    end
  end

  return nil, "unterminated string"
end

local parseValue

local function parseNumber(source, index)
  local start = index
  local char = source:sub(index, index)
  if char == "-" then
    index = index + 1
  end

  local firstDigit = source:sub(index, index)
  if firstDigit == "0" then
    index = index + 1
  else
    if not firstDigit:match("%d") then
      return nil, "invalid number"
    end
    while source:sub(index, index):match("%d") do
      index = index + 1
    end
  end

  if source:sub(index, index) == "." then
    index = index + 1
    if not source:sub(index, index):match("%d") then
      return nil, "invalid number fraction"
    end
    while source:sub(index, index):match("%d") do
      index = index + 1
    end
  end

  local exponent = source:sub(index, index)
  if exponent == "e" or exponent == "E" then
    index = index + 1
    local sign = source:sub(index, index)
    if sign == "+" or sign == "-" then
      index = index + 1
    end
    if not source:sub(index, index):match("%d") then
      return nil, "invalid exponent"
    end
    while source:sub(index, index):match("%d") do
      index = index + 1
    end
  end

  local value = tonumber(source:sub(start, index - 1))
  if value == nil then
    return nil, "invalid number"
  end
  return value, index
end

local function parseArray(source, index)
  local out = {}
  index = index + 1
  index = skipWhitespace(source, index)
  if source:sub(index, index) == "]" then
    return out, index + 1
  end

  while index <= #source do
    local value, nextIndex = parseValue(source, index)
    if type(nextIndex) ~= "number" then
      return nil, nextIndex or value
    end
    out[#out + 1] = value
    index = skipWhitespace(source, nextIndex)
    local char = source:sub(index, index)
    if char == "]" then
      return out, index + 1
    end
    if char ~= "," then
      return nil, "expected ',' or ']'"
    end
    index = skipWhitespace(source, index + 1)
  end

  return nil, "unterminated array"
end

local function parseObject(source, index)
  local out = {}
  index = index + 1
  index = skipWhitespace(source, index)
  if source:sub(index, index) == "}" then
    return out, index + 1
  end

  while index <= #source do
    if source:sub(index, index) ~= "\"" then
      return nil, "expected string key"
    end
    local key, nextIndex = parseString(source, index)
    if type(nextIndex) ~= "number" then
      return nil, nextIndex or key
    end
    index = skipWhitespace(source, nextIndex)
    if source:sub(index, index) ~= ":" then
      return nil, "expected ':'"
    end
    index = skipWhitespace(source, index + 1)
    local value, valueIndex = parseValue(source, index)
    if type(valueIndex) ~= "number" then
      return nil, valueIndex or value
    end
    out[key] = value
    index = skipWhitespace(source, valueIndex)
    local char = source:sub(index, index)
    if char == "}" then
      return out, index + 1
    end
    if char ~= "," then
      return nil, "expected ',' or '}'"
    end
    index = skipWhitespace(source, index + 1)
  end

  return nil, "unterminated object"
end

parseValue = function(source, index)
  index = skipWhitespace(source, index)
  local char = source:sub(index, index)
  if char == "{" then
    return parseObject(source, index)
  end
  if char == "[" then
    return parseArray(source, index)
  end
  if char == "\"" then
    return parseString(source, index)
  end
  if char == "-" or char:match("%d") then
    return parseNumber(source, index)
  end
  if source:sub(index, index + 3) == "true" then
    return true, index + 4
  end
  if source:sub(index, index + 4) == "false" then
    return false, index + 5
  end
  if source:sub(index, index + 3) == "null" then
    return nil, index + 4
  end
  return nil, "unexpected token"
end

local function decodeJson(source)
  local value, index = parseValue(source or "", 1)
  if type(index) ~= "number" then
    return nil, index or value
  end

  index = skipWhitespace(source, index)
  if index <= #source then
    return nil, "trailing content"
  end
  return value
end

local function encodeString(value)
  local escaped = tostring(value)
  escaped = escaped:gsub("\\", "\\\\")
  escaped = escaped:gsub("\"", "\\\"")
  escaped = escaped:gsub("\b", "\\b")
  escaped = escaped:gsub("\f", "\\f")
  escaped = escaped:gsub("\n", "\\n")
  escaped = escaped:gsub("\r", "\\r")
  escaped = escaped:gsub("\t", "\\t")
  return "\"" .. escaped .. "\""
end

local function isArray(value)
  local maxIndex = 0
  local count = 0
  for key, _ in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return false
    end
    if key > maxIndex then
      maxIndex = key
    end
    count = count + 1
  end
  return maxIndex == count
end

local function sortedKeys(value)
  local keys = {}
  for key, _ in pairs(value) do
    keys[#keys + 1] = key
  end
  table.sort(keys, function(left, right)
    if type(left) == type(right) then
      return tostring(left) < tostring(right)
    end
    return type(left) < type(right)
  end)
  return keys
end

local function encodePretty(value, depth)
  local valueType = type(value)
  if valueType == "nil" then
    return "null"
  end
  if valueType == "boolean" or valueType == "number" then
    return tostring(value)
  end
  if valueType == "string" then
    return encodeString(value)
  end
  if valueType ~= "table" then
    error("unsupported JSON type: " .. valueType)
  end

  local indent = string.rep("  ", depth)
  local childIndent = string.rep("  ", depth + 1)

  if isArray(value) then
    if #value == 0 then
      return "[]"
    end
    local parts = {}
    for i = 1, #value do
      parts[#parts + 1] = childIndent .. encodePretty(value[i], depth + 1)
    end
    return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
  end

  local keys = sortedKeys(value)
  if #keys == 0 then
    return "{}"
  end

  local parts = {}
  for _, key in ipairs(keys) do
    parts[#parts + 1] = childIndent .. encodeString(key) .. ": " .. encodePretty(value[key], depth + 1)
  end
  return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
end

local function readAll(path)
  local handle = io.open(path, "r")
  if not handle then
    return nil
  end
  local contents = handle:read("*a")
  handle:close()
  return contents
end

function JsonDisk.read(path)
  local contents = readAll(path)
  if contents == nil then
    return nil, { exists = false, invalid = false }
  end

  local decoded, err = decodeJson(contents)
  if err ~= nil then
    return nil, { exists = true, invalid = true, error = err }
  end
  if type(decoded) ~= "table" then
    return nil, { exists = true, invalid = true, error = "root must be an object" }
  end

  return decoded, { exists = true, invalid = false }
end

function JsonDisk.backupCorrupt(path)
  local backupPath = corruptPath(path)
  os.remove(backupPath)
  os.rename(path, backupPath)
  if hs and type(hs.printf) == "function" then
    hs.printf("[tapshop-persistence] recovered corrupt JSON %s -> %s", tostring(path), tostring(backupPath))
  end
  return backupPath
end

function JsonDisk.write(path, value)
  ensureDir(path)

  local nextTmpPath = tmpPath(path)
  local handle, err = io.open(nextTmpPath, "w")
  if not handle then
    return nil, err
  end

  local ok, encodedOrErr = pcall(encodePretty, value, 0)
  if not ok then
    handle:close()
    os.remove(nextTmpPath)
    return nil, encodedOrErr
  end

  handle:write(encodedOrErr)
  handle:write("\n")
  handle:flush()
  handle:close()

  os.remove(path)
  local renamed, renameErr = os.rename(nextTmpPath, path)
  if not renamed then
    os.remove(nextTmpPath)
    return nil, renameErr
  end

  return true
end

return JsonDisk
