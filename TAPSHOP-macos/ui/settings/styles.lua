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

.settings-window-title-row {
  display: flex;
  align-items: center;
  gap: calc(8px * var(--ui-scale));
}

.settings-window-title {
  color: var(--text-strong);
  font-size: calc(12px * var(--ui-scale));
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.settings-brand-icon {
  width: calc(18px * var(--ui-scale));
  height: calc(18px * var(--ui-scale));
  border-radius: calc(5px * var(--ui-scale));
  flex-shrink: 0;
}

.settings-window-subtitle {
  color: var(--text-muted);
  font-size: calc(10px * var(--ui-scale));
  line-height: 1.2;
}

.header-action-glyph {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
  font-size: calc(13px * var(--ui-scale));
  font-weight: 700;
  line-height: 1;
  pointer-events: none;
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

.remap-modal {
  width: min(calc(360px * var(--ui-scale)), calc(100% - 20px));
  gap: calc(10px * var(--ui-scale));
  padding: calc(12px * var(--ui-scale));
  border-radius: 12px;
  background:
    radial-gradient(circle at top right, rgba(120, 168, 255, 0.14), transparent 42%),
    linear-gradient(180deg, rgba(26, 26, 28, 0.98), rgba(16, 16, 18, 0.99));
  box-shadow:
    0 24px 44px rgba(0, 0, 0, 0.46),
    inset 0 1px 0 rgba(255, 255, 255, 0.06);
}

.remap-modal-label {
  color: var(--text-strong);
  font-size: calc(11px * var(--ui-scale));
  font-weight: 600;
}

.remap-comparison {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
  align-items: end;
  gap: calc(6px * var(--ui-scale));
}

.remap-binding-pane {
  display: flex;
  flex-direction: column;
  gap: calc(4px * var(--ui-scale));
  min-width: 0;
}

.remap-binding-arrow {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  align-self: end;
  width: calc(24px * var(--ui-scale));
  height: calc(24px * var(--ui-scale));
  margin-bottom: calc(1px * var(--ui-scale));
  border-radius: 999px;
  background: rgba(120, 168, 255, 0.12);
  color: #d6e4ff;
  font-size: calc(12px * var(--ui-scale));
  font-weight: 700;
}

.remap-binding-combo {
  width: 100%;
  max-width: 100%;
}

.remap-mods {
  display: grid;
  gap: calc(4px * var(--ui-scale));
}

.remap-mods {
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.remap-mod-btn {
  justify-content: center;
  min-height: calc(24px * var(--ui-scale));
  padding: calc(4px * var(--ui-scale)) calc(7px * var(--ui-scale));
}

.remap-mod-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: calc(4px * var(--ui-scale));
}

.remap-mod-text {
  white-space: nowrap;
}

.remap-mod-symbol {
  opacity: 0.82;
  font-size: calc(11px * var(--ui-scale));
  line-height: 1;
}

.remap-mod-btn.is-active {
  background: rgba(120, 168, 255, 0.24);
  box-shadow: 0 0 0 calc(1px * var(--ui-scale)) rgba(120, 168, 255, 0.34) inset;
}

.remap-capture {
  display: flex;
  flex-direction: column;
  gap: calc(8px * var(--ui-scale));
  padding: calc(10px * var(--ui-scale));
  border: 1px solid rgba(120, 168, 255, 0.18);
  border-radius: 10px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.04), rgba(255, 255, 255, 0.02)),
    rgba(9, 11, 16, 0.78);
  outline: none;
  cursor: text;
}

.remap-capture:focus-visible,
.remap-capture.is-armed {
  border-color: rgba(120, 168, 255, 0.7);
  box-shadow: 0 0 0 calc(1px * var(--ui-scale)) rgba(120, 168, 255, 0.48);
}

.remap-capture.is-ready {
  border-color: rgba(125, 211, 162, 0.68);
  box-shadow: 0 0 0 calc(1px * var(--ui-scale)) rgba(125, 211, 162, 0.34);
}

.remap-capture.is-cleared {
  border-color: rgba(240, 201, 123, 0.58);
  box-shadow: 0 0 0 calc(1px * var(--ui-scale)) rgba(240, 201, 123, 0.26);
}

.remap-capture.has-error {
  border-color: rgba(188, 83, 73, 0.72);
  box-shadow: 0 0 0 calc(1px * var(--ui-scale)) rgba(188, 83, 73, 0.32);
}

.remap-capture-topline {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: calc(8px * var(--ui-scale));
}

.remap-capture-status {
  display: inline-flex;
  align-items: center;
  min-height: calc(18px * var(--ui-scale));
  padding: calc(3px * var(--ui-scale)) calc(7px * var(--ui-scale));
  border-radius: 999px;
  background: rgba(120, 168, 255, 0.14);
  color: #cfe0ff;
  font-size: calc(9px * var(--ui-scale));
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.remap-capture-hint {
  color: var(--text-muted);
  font-size: calc(8px * var(--ui-scale));
  text-align: right;
}

.remap-preview-combo {
  --remap-preview-gap: calc(3px * var(--ui-scale));
  --remap-preview-pad: calc(3px * var(--ui-scale));
  display: flex;
  align-items: center;
  justify-content: flex-start;
  width: 100%;
  min-height: calc(24px * var(--ui-scale));
  padding: var(--remap-preview-pad);
  box-sizing: border-box;
  border: 1px solid var(--line);
  border-radius: 7px;
  background: rgba(255, 255, 255, 0.04);
}

.remap-preview-combo.is-empty {
  width: 100%;
  border: 1px dashed rgba(255, 255, 255, 0.12);
  border-radius: 7px;
  background: rgba(255, 255, 255, 0.01);
}

.remap-preview-flow {
  display: flex;
  align-items: center;
  align-content: center;
  gap: var(--remap-preview-gap);
  flex-wrap: wrap;
  width: 100%;
}

.remap-preview-title {
  color: var(--text-muted);
  font-size: calc(9px * var(--ui-scale));
  text-transform: uppercase;
  letter-spacing: 0.06em;
}

.remap-actions {
  display: inline-flex;
  align-items: center;
  gap: calc(5px * var(--ui-scale));
  flex-shrink: 0;
}

.remap-actions .btn {
  min-height: calc(24px * var(--ui-scale));
  padding: calc(3px * var(--ui-scale)) calc(8px * var(--ui-scale));
  font-size: calc(10px * var(--ui-scale));
}

.remap-save-btn[disabled] {
  opacity: 0.45;
  pointer-events: none;
}

.hotkey-unset {
  color: var(--text-muted);
  font-size: calc(10px * var(--ui-scale));
  line-height: 1.2;
  font-style: italic;
}

.keycap {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: calc(20px * var(--ui-scale));
  min-height: calc(19px * var(--ui-scale));
  padding: calc(3px * var(--ui-scale)) calc(6px * var(--ui-scale));
  border: 1px solid var(--line);
  border-bottom-color: rgba(255, 255, 255, 0.2);
  border-radius: 6px;
  background: rgba(255, 255, 255, 0.08);
  color: var(--text-strong);
  font-size: calc(9px * var(--ui-scale));
  line-height: 1;
}

.keycap-system {
  min-width: calc(22px * var(--ui-scale));
}

.keycap-system-icon {
  width: calc(12px * var(--ui-scale));
  height: calc(12px * var(--ui-scale));
  flex-shrink: 0;
}

.remap-unbind-btn {
  color: #f0c97b;
}

.settings-item:last-child,
.settings-slider-block:last-child,
.hotkeys-error:last-child,
.hotkeys-helper:last-child {
  margin-bottom: 0;
}

.header-tooltip {
  display: block;
}
]=]
end

return Styles
