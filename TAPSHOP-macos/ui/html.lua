local Html = {}

function Html.escape(text)
  local value = tostring(text or "")
  return (value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

return Html
