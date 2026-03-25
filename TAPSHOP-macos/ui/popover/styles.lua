local Styles = {}

local function rootVars(theme)
  local c = theme.colors
  local opacity = math.max(0.84, (theme.opacityPercent or 85) / 100)

  return [=[
:root {
  --ui-scale: 1;
  --panel-bg: ]=] .. string.format("rgba(20, 20, 20, %.2f)", opacity) .. [=[;
  --panel-overlay: rgba(12, 12, 12, 0.72);
  --line: rgba(255, 255, 255, 0.08);
  --line-strong: rgba(255, 255, 255, 0.16);
  --text: ]=] .. c.textBase .. [=[;
  --text-strong: ]=] .. c.textPrimary .. [=[;
  --text-muted: ]=] .. c.textMuted .. [=[;
  --accent: ]=] .. c.surfacePrimary .. [=[;
  --accent-hover: ]=] .. c.surfacePrimaryHover .. [=[;
  --danger: ]=] .. c.surfaceDanger .. [=[;
  --danger-hover: ]=] .. c.surfaceDangerHover .. [=[;
  --warning: #d7a94b;
  --conflict: #bc5349;
  --focus: rgba(120, 168, 255, 0.92);
  --tooltip-bg: rgba(10, 10, 10, 0.94);
}
]=]
end

function Styles.buildCss(theme)
  return table.concat({
    rootVars(theme),
    [=[
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

html, body {
  width: 100%;
  height: 100%;
}

body {
  background: transparent;
  color: var(--text);
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
  font-size: calc(12px * var(--ui-scale));
  -webkit-user-select: none;
  overflow: hidden;
}

button,
input {
  font: inherit;
}

.container {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: calc(6px * var(--ui-scale));
  height: 100%;
  padding: calc(10px * var(--ui-scale));
  background: var(--panel-bg);
  border: 1px solid var(--line);
  border-radius: 12px;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.04);
  -webkit-backdrop-filter: blur(10px) saturate(115%);
  backdrop-filter: blur(10px) saturate(115%);
  overflow: hidden;
}

.header {
  display: flex;
  align-items: flex-start;
  gap: calc(10px * var(--ui-scale));
  padding-bottom: calc(7px * var(--ui-scale));
  border-bottom: 1px solid #333;
  cursor: move;
  flex: 0 0 auto;
}

.title-wrap {
  display: inline-flex;
  align-items: center;
  gap: calc(8px * var(--ui-scale));
  flex: 0 0 auto;
}

.title {
  display: inline-flex;
  align-items: center;
  font-weight: 700;
  font-size: calc(14px * var(--ui-scale));
  color: var(--text-strong);
  letter-spacing: 0.5px;
  line-height: 1.1;
}

.title-trigger,
.title-hop {
  display: inline-block;
}

.title-trigger {
  cursor: pointer;
}

.title-hop {
  transform-origin: center bottom;
}

.title-hop.is-hopping {
  animation: hop-cartoon 700ms cubic-bezier(0.22, 1, 0.36, 1);
}

@keyframes hop-cartoon {
  0% { transform: translateY(0) scaleX(1) scaleY(1); }
  12% { transform: translateY(1px) scaleX(1.15) scaleY(0.84); }
  32% { transform: translateY(calc(-13px * var(--ui-scale))) scaleX(0.88) scaleY(1.18); }
  46% { transform: translateY(calc(-19px * var(--ui-scale))) scaleX(0.96) scaleY(1.06); }
  64% { transform: translateY(0) scaleX(1.1) scaleY(0.88); }
  76% { transform: translateY(calc(-6px * var(--ui-scale))) scaleX(0.97) scaleY(1.04); }
  100% { transform: translateY(0) scaleX(1) scaleY(1); }
}

.header-details {
  display: flex;
  flex-direction: column;
  gap: calc(3px * var(--ui-scale));
  flex: 1 1 auto;
  min-width: 0;
}

.header-primary,
.header-secondary {
  display: block;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  line-height: 1.2;
}

.header-primary {
  font-size: calc(11px * var(--ui-scale));
  font-weight: 600;
  color: var(--text-strong);
}

.header-secondary {
  font-size: calc(7px * var(--ui-scale));
  color: var(--text-muted);
}

.header-actions {
  display: flex;
  align-items: center;
  gap: calc(6px * var(--ui-scale));
  margin-left: auto;
  flex-shrink: 0;
}

.header-btn,
.btn,
.settings-tab {
  border: none;
  border-radius: calc(4px * var(--ui-scale));
  cursor: pointer;
  transition: background 120ms ease, color 120ms ease, opacity 120ms ease, border-color 120ms ease;
}

.header-btn {
  width: calc(30px * var(--ui-scale));
  height: calc(26px * var(--ui-scale));
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0;
}

.header-btn:focus-visible,
.btn:focus-visible,
.settings-tab:focus-visible,
.hotkey-search:focus-visible {
  outline: none;
  box-shadow: 0 0 0 1px var(--focus);
}

.header-danger {
  background: var(--danger);
  color: var(--text-strong);
}

.header-danger:hover {
  background: var(--danger-hover);
}

.header-config {
  background: #4b4b4b;
  color: #d2d2d2;
}

.header-config:hover {
  background: #5a5a5a;
  color: #fff;
}

.header-close {
  background: #2a2a2a;
  color: #777;
}

.header-close:hover {
  background: #3a3a3a;
  color: #aaa;
}

.settings-restore-btn {
  background: rgba(255, 255, 255, 0.06);
  color: var(--text-muted);
}

.settings-restore-btn:hover {
  background: rgba(255, 255, 255, 0.12);
  color: var(--text-strong);
}

.header-icon {
  width: calc(14px * var(--ui-scale));
  height: calc(14px * var(--ui-scale));
  display: block;
  stroke: currentColor;
  fill: none;
  pointer-events: none;
}

.header-tooltip {
  position: absolute;
  top: 0;
  left: 0;
  padding: calc(3px * var(--ui-scale)) calc(6px * var(--ui-scale));
  border-radius: 5px;
  background: var(--tooltip-bg);
  color: #f5f7fa;
  font-size: calc(10px * var(--ui-scale));
  line-height: 1;
  white-space: nowrap;
  pointer-events: none;
  opacity: 0;
  visibility: hidden;
  transition: opacity 120ms ease;
  z-index: 30;
}

.header-tooltip.is-visible {
  opacity: 1;
  visibility: visible;
}

.body-shell {
  position: relative;
  flex: 1 1 auto;
  min-height: 0;
}

.workspace-list {
  position: relative;
  display: grid;
  grid-template-rows: repeat(9, auto);
  gap: calc(3px * var(--ui-scale));
  align-content: start;
  transition: opacity 90ms ease;
}

.workspace-list.is-dimmed {
  opacity: 0.18;
  pointer-events: none;
}

.row {
  display: flex;
  align-items: center;
  gap: calc(4px * var(--ui-scale));
}

.slot-num {
  width: calc(18px * var(--ui-scale));
  text-align: right;
  color: var(--text-strong);
  font-size: calc(11px * var(--ui-scale));
  font-weight: 600;
  margin-right: calc(8px * var(--ui-scale));
  flex-shrink: 0;
}

.slot-label {
  display: flex;
  align-items: center;
  gap: calc(6px * var(--ui-scale));
  flex: 1 1 0;
  width: 0;
  min-width: 0;
  overflow: hidden;
  font-size: calc(12px * var(--ui-scale));
}

.slot-text-bg {
  display: inline-block;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  padding: calc(2px * var(--ui-scale)) calc(8px * var(--ui-scale));
  background: rgba(0, 0, 0, 0.14);
  border-radius: 999px;
  min-width: 0;
}

.min-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: calc(1px * var(--ui-scale)) calc(5px * var(--ui-scale));
  border-radius: 999px;
  background: rgba(231, 200, 79, 0.16);
  border: 1px solid rgba(231, 200, 79, 0.32);
  color: #e7c84f;
  font-size: calc(9px * var(--ui-scale));
  font-weight: 700;
  flex-shrink: 0;
}

.slot-buttons {
  display: flex;
  gap: calc(4px * var(--ui-scale));
  margin-left: auto;
  flex-shrink: 0;
}

.btn {
  padding: calc(4px * var(--ui-scale)) calc(11px * var(--ui-scale));
  font-size: calc(11px * var(--ui-scale));
  font-weight: 500;
  white-space: nowrap;
}

.btn-primary {
  background: var(--accent);
  color: var(--text-strong);
}

.btn-primary:hover {
  background: var(--accent-hover);
}

.btn-unpair {
  background: #444;
  color: #bbb;
}

.btn-unpair:hover {
  background: #555;
}

.btn-unpair.off {
  opacity: 0.25;
  pointer-events: none;
}

.paired { color: #7ec87e; }
.paired-minimized { color: #e7c84f; }
.unpaired { color: #555; font-style: italic; }

.settings-sheet {
  position: absolute;
  inset: 0;
  display: none;
  flex-direction: column;
  gap: calc(6px * var(--ui-scale));
  min-height: 0;
  padding: calc(6px * var(--ui-scale));
  border: 1px solid var(--line-strong);
  border-radius: 9px;
  background: var(--panel-overlay);
}

.settings-sheet.is-open {
  display: flex;
}

.settings-head {
  display: flex;
  align-items: center;
  gap: calc(6px * var(--ui-scale));
  flex: 0 0 auto;
}

.settings-back-btn {
  padding: calc(4px * var(--ui-scale)) calc(7px * var(--ui-scale));
  font-size: calc(10px * var(--ui-scale));
  background: rgba(255, 255, 255, 0.06);
  color: var(--text-muted);
}

.settings-back-btn:hover {
  background: rgba(255, 255, 255, 0.12);
  color: var(--text-strong);
}

.settings-head-main {
  display: flex;
  align-items: center;
  gap: calc(6px * var(--ui-scale));
  flex: 1 1 auto;
  min-width: 0;
}

.settings-tabs {
  display: inline-flex;
  align-items: center;
  gap: calc(4px * var(--ui-scale));
  padding: calc(2px * var(--ui-scale));
  background: rgba(0, 0, 0, 0.24);
  border: 1px solid var(--line);
  border-radius: 999px;
  flex-shrink: 0;
}

.settings-tab {
  background: transparent;
  color: var(--text-muted);
  padding: calc(4px * var(--ui-scale)) calc(10px * var(--ui-scale));
  font-size: calc(10px * var(--ui-scale));
  border-radius: 999px;
}

.settings-tab.is-active {
  background: rgba(255, 255, 255, 0.1);
  color: var(--text-strong);
}

.settings-tools {
  display: flex;
  align-items: center;
  gap: calc(5px * var(--ui-scale));
  margin-left: auto;
  min-width: 0;
}

.hotkey-search {
  width: calc(142px * var(--ui-scale));
  min-width: 0;
  border: 1px solid var(--line);
  border-radius: 7px;
  background: rgba(0, 0, 0, 0.24);
  color: var(--text-strong);
  padding: calc(5px * var(--ui-scale)) calc(8px * var(--ui-scale));
  font-size: calc(10px * var(--ui-scale));
}

.settings-restore-btn {
  width: calc(26px * var(--ui-scale));
  height: calc(24px * var(--ui-scale));
}

body[data-settings-tab="general"] .settings-tools {
  opacity: 0;
  pointer-events: none;
}

.settings-scroll {
  position: relative;
  flex: 1 1 auto;
  min-height: 0;
  overflow: hidden;
}

.settings-panel {
  display: none;
  height: 100%;
  overflow: auto;
  padding-right: calc(2px * var(--ui-scale));
}

body[data-settings-tab="general"] .settings-panel[data-settings-panel="general"],
body[data-settings-tab="hotkeys"] .settings-panel[data-settings-panel="hotkeys"] {
  display: block;
}

.settings-item,
.settings-slider-block {
  display: flex;
  align-items: center;
  gap: calc(8px * var(--ui-scale));
  padding: calc(8px * var(--ui-scale)) calc(9px * var(--ui-scale));
  margin-bottom: calc(6px * var(--ui-scale));
  border: 1px solid var(--line);
  border-radius: 9px;
  background: rgba(255, 255, 255, 0.04);
}

.settings-item {
  cursor: pointer;
}

.settings-item input {
  accent-color: var(--accent);
}

.settings-slider-block {
  flex-direction: column;
  align-items: stretch;
}

.settings-slider-label {
  font-size: calc(11px * var(--ui-scale));
  color: var(--text-strong);
}

.settings-slider {
  width: 100%;
}

.hotkeys-helper {
  margin-bottom: calc(6px * var(--ui-scale));
  color: var(--text-muted);
  font-size: calc(9px * var(--ui-scale));
  line-height: 1.3;
}

.hotkeys-error {
  margin-bottom: calc(6px * var(--ui-scale));
  padding: calc(6px * var(--ui-scale)) calc(8px * var(--ui-scale));
  border-radius: 7px;
  border: 1px solid rgba(188, 83, 73, 0.4);
  background: rgba(188, 83, 73, 0.14);
  color: #ffd5d0;
  font-size: calc(9px * var(--ui-scale));
}

.hotkeys-error.is-hidden {
  display: none;
}

.hotkeys-list {
  display: flex;
  flex-direction: column;
  gap: calc(7px * var(--ui-scale));
}

.hotkey-group {
  display: flex;
  flex-direction: column;
  gap: calc(4px * var(--ui-scale));
}

.hotkey-group.is-hidden {
  display: none;
}

.hotkey-group-title {
  padding: 0 calc(2px * var(--ui-scale));
  color: var(--text-muted);
  font-size: calc(9px * var(--ui-scale));
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.hotkey-row {
  display: flex;
  align-items: center;
  gap: calc(8px * var(--ui-scale));
  padding: calc(6px * var(--ui-scale)) calc(8px * var(--ui-scale));
  border: 1px solid var(--line);
  border-left: 2px solid transparent;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.04);
}

.hotkey-row.is-hidden {
  display: none;
}

.hotkey-row.is-modified {
  border-left-color: var(--warning);
}

.hotkey-row.has-conflict {
  border-color: rgba(188, 83, 73, 0.55);
  background: rgba(188, 83, 73, 0.12);
}

.hotkey-row.has-live-conflict {
  border-color: rgba(188, 83, 73, 0.55);
  background: rgba(188, 83, 73, 0.12);
}

.hotkey-row.is-unavailable,
.hotkey-row.has-warning {
  border-color: rgba(215, 169, 75, 0.35);
}

.hotkey-main {
  display: flex;
  align-items: center;
  gap: calc(8px * var(--ui-scale));
  flex: 1 1 auto;
  min-width: 0;
}

.hotkey-label {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--text-strong);
  font-size: calc(10px * var(--ui-scale));
}

.hotkey-combo,
.remap-preview-combo {
  display: inline-flex;
  align-items: center;
  gap: calc(3px * var(--ui-scale));
  flex-wrap: wrap;
  width: fit-content;
  max-width: 100%;
  min-height: calc(24px * var(--ui-scale));
  padding: calc(3px * var(--ui-scale));
  border: 1px solid var(--line);
  border-radius: 7px;
  background: rgba(255, 255, 255, 0.04);
}

.hotkey-combo-empty,
.remap-preview-combo.is-empty {
  display: inline-flex;
  align-items: center;
  padding: 0;
  min-height: 0;
  border: none;
  background: transparent;
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
  padding: calc(3px * var(--ui-scale)) calc(6px * var(--ui-scale));
  border: 1px solid var(--line);
  border-bottom-color: rgba(255, 255, 255, 0.2);
  border-radius: 6px;
  background: rgba(255, 255, 255, 0.08);
  color: var(--text-strong);
  font-size: calc(9px * var(--ui-scale));
  line-height: 1;
}

.hotkey-actions,
.remap-actions {
  display: inline-flex;
  align-items: center;
  gap: calc(5px * var(--ui-scale));
  flex-shrink: 0;
}

.hotkey-btn {
  background: rgba(255, 255, 255, 0.08);
  color: var(--text-strong);
  padding: calc(3px * var(--ui-scale)) calc(8px * var(--ui-scale));
  font-size: calc(10px * var(--ui-scale));
}

.hotkey-btn:hover {
  background: rgba(255, 255, 255, 0.14);
}

.hotkey-reset-btn {
  color: #f0c97b;
}

.remap-modal-shell[hidden] {
  display: none;
}

.remap-modal-shell {
  position: absolute;
  inset: 0;
  z-index: 20;
}

.remap-modal-backdrop {
  position: absolute;
  inset: 0;
  border: none;
  background: rgba(0, 0, 0, 0.32);
  cursor: default;
}

.remap-modal {
  position: absolute;
  top: 50%;
  left: 50%;
  width: min(calc(320px * var(--ui-scale)), calc(100% - 20px));
  transform: translate(-50%, -50%);
  display: flex;
  flex-direction: column;
  gap: calc(10px * var(--ui-scale));
  padding: calc(12px * var(--ui-scale));
  border: 1px solid var(--line-strong);
  border-radius: 12px;
  background: rgba(18, 18, 18, 0.98);
  box-shadow: 0 18px 36px rgba(0, 0, 0, 0.45);
}

.remap-modal-label {
  color: var(--text-strong);
  font-size: calc(12px * var(--ui-scale));
  font-weight: 600;
}

.remap-preview-row {
  display: flex;
  flex-direction: column;
  gap: calc(6px * var(--ui-scale));
}

.remap-preview-title {
  color: var(--text-muted);
  font-size: calc(10px * var(--ui-scale));
  text-transform: uppercase;
  letter-spacing: 0.06em;
}

.remap-save-btn[disabled] {
  opacity: 0.45;
  pointer-events: none;
}
]=],
  })
end

return Styles
