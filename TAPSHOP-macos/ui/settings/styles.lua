local popoverStyles = require("ui.popover.styles")

local Styles = {}

function Styles.buildCss(theme)
  return popoverStyles.buildCss(theme) .. [=[

.header {
  align-items: center;
}

.header-titleblock {
  display: flex;
  flex-direction: column;
  gap: calc(2px * var(--ui-scale));
  min-width: 0;
}

.settings-window-title {
  color: var(--text-strong);
  font-size: calc(12px * var(--ui-scale));
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.settings-window-subtitle {
  color: var(--text-muted);
  font-size: calc(10px * var(--ui-scale));
  line-height: 1.2;
}

.settings-window-shell {
  display: flex;
  flex-direction: column;
  gap: calc(6px * var(--ui-scale));
  flex: 1 1 auto;
  min-height: 0;
}

.settings-head {
  padding-top: calc(2px * var(--ui-scale));
}

.settings-tab {
  min-width: calc(74px * var(--ui-scale));
}

.settings-scroll {
  border: 1px solid var(--line);
  border-radius: 10px;
  background: rgba(0, 0, 0, 0.14);
}

.settings-panel {
  padding: calc(8px * var(--ui-scale));
}

.settings-item:last-child,
.settings-slider-block:last-child,
.hotkeys-error:last-child,
.hotkeys-helper:last-child {
  margin-bottom: 0;
}

.header-tooltip {
  display: none;
}
]=]
end

return Styles
