local Utils = {}

function Utils.normalizeKey(value)
  if value == false then
    return false
  end
  if type(value) ~= "string" or value == "" then
    return nil
  end
  if value:match("^F%d+$") then
    return value
  end
  return string.lower(value)
end

return Utils
