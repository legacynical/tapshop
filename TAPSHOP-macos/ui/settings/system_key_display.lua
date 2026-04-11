local SystemKeyDisplay = {}

local function iconSvg(inner)
  return '<svg class="keycap-system-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">'
    .. inner
    .. "</svg>"
end

local DISPLAY = {
  BRIGHTNESS_UP = {
    label = "Brightness Up",
    svg = iconSvg([[
<path d="M9 12a3 3 0 1 0 6 0a3 3 0 1 0 -6 0" />
<path d="M12 5l0 -2" />
<path d="M17 7l1.4 -1.4" />
<path d="M19 12l2 0" />
<path d="M17 17l1.4 1.4" />
<path d="M12 19l0 2" />
<path d="M7 17l-1.4 1.4" />
<path d="M5 12l-2 0" />
<path d="M7 7l-1.4 -1.4" />
]]),
  },
  BRIGHTNESS_DOWN = {
    label = "Brightness Down",
    svg = iconSvg([[
<path d="M9 12a3 3 0 1 0 6 0a3 3 0 1 0 -6 0" />
<path d="M12 5l0 .01" />
<path d="M17 7l0 .01" />
<path d="M19 12l0 .01" />
<path d="M17 17l0 .01" />
<path d="M12 19l0 .01" />
<path d="M7 17l0 .01" />
<path d="M5 12l0 .01" />
<path d="M7 7l0 .01" />
]]),
  },
  SOUND_UP = {
    label = "Volume Up",
    svg = iconSvg([[
<path d="M5 14h3l4 4V6L8 10H5z" />
<path d="M16 9.5a4.5 4.5 0 0 1 0 5" />
<path d="M18.5 7a8 8 0 0 1 0 10" />
]]),
  },
  SOUND_DOWN = {
    label = "Volume Down",
    svg = iconSvg([[
<path d="M5 14h3l4 4V6L8 10H5z" />
<path d="M16 9.5a4.5 4.5 0 0 1 0 5" />
]]),
  },
  MUTE = {
    label = "Mute",
    svg = iconSvg([[
<path d="M5 14h3l4 4V6L8 10H5z" />
<path d="M16 9l4 6" />
<path d="M20 9l-4 6" />
]]),
  },
  PLAY = {
    label = "Play/Pause",
    svg = iconSvg([[
<path stroke-linecap="round" stroke-linejoin="round" d="M21 7.5V18M15 7.5V18M3 16.811V8.69c0-.864.933-1.406 1.683-.977l7.108 4.061a1.125 1.125 0 0 1 0 1.954l-7.108 4.061A1.125 1.125 0 0 1 3 16.811Z" />
]]),
  },
  FAST = {
    label = "Fast Forward",
    svg = iconSvg([[
<path stroke-linecap="round" stroke-linejoin="round" d="M3 8.689c0-.864.933-1.406 1.683-.977l7.108 4.061a1.125 1.125 0 0 1 0 1.954l-7.108 4.061A1.125 1.125 0 0 1 3 16.811V8.69ZM12.75 8.689c0-.864.933-1.406 1.683-.977l7.108 4.061a1.125 1.125 0 0 1 0 1.954l-7.108 4.061a1.125 1.125 0 0 1-1.683-.977V8.69Z" />
]]),
  },
  REWIND = {
    label = "Rewind",
    svg = iconSvg([[
<path stroke-linecap="round" stroke-linejoin="round" d="M21 16.811c0 .864-.933 1.406-1.683.977l-7.108-4.061a1.125 1.125 0 0 1 0-1.954l7.108-4.061A1.125 1.125 0 0 1 21 8.689v8.122ZM11.25 16.811c0 .864-.933 1.406-1.683.977l-7.108-4.061a1.125 1.125 0 0 1 0-1.954l7.108-4.061a1.125 1.125 0 0 1 1.683.977v8.122Z" />
]]),
  },
  NEXT = {
    label = "Next",
    svg = iconSvg([[
<path d="M5 6l6 6-6 6z" />
<path d="M11 6l6 6-6 6z" />
<path d="M19 6v12" />
]]),
  },
  PREVIOUS = {
    label = "Previous",
    svg = iconSvg([[
<path d="M19 6l-6 6 6 6z" />
<path d="M13 6l-6 6 6 6z" />
<path d="M5 6v12" />
]]),
  },
  LAUNCH_PANEL = {
    label = "Launchpad",
    svg = iconSvg([[
<rect x="5" y="5" width="4" height="4" rx="0.8" />
<rect x="10" y="5" width="4" height="4" rx="0.8" />
<rect x="15" y="5" width="4" height="4" rx="0.8" />
<rect x="5" y="10" width="4" height="4" rx="0.8" />
<rect x="10" y="10" width="4" height="4" rx="0.8" />
<rect x="15" y="10" width="4" height="4" rx="0.8" />
<rect x="5" y="15" width="4" height="4" rx="0.8" />
<rect x="10" y="15" width="4" height="4" rx="0.8" />
<rect x="15" y="15" width="4" height="4" rx="0.8" />
]]),
  },
  EJECT = {
    label = "Eject",
    svg = iconSvg([[
<path d="M12 5l6 8H6z" />
<path d="M7 20h10" />
]]),
  },
}

function SystemKeyDisplay.get(key)
  return DISPLAY[tostring(key or "")]
end

function SystemKeyDisplay.jsData()
  local out = {}
  for key, meta in pairs(DISPLAY) do
    out[key] = {
      label = meta.label,
      svg = meta.svg,
    }
  end
  return out
end

return SystemKeyDisplay
