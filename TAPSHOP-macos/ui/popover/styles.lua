local Styles = {}

local function rootVars(theme)
  local s = theme.spacing
  local sz = theme.sizing
  local r = theme.radius
  local t = theme.typography
  local c = theme.colors
  local e = theme.effects
  local z = theme.zIndex

  return [=[
:root {
  --ui-scale: 1;

  --space-container: ]=] .. s.container .. [=[;
  --space-shell-gap: ]=] .. s.shellGap .. [=[;
  --space-header-gap: ]=] .. s.headerGap .. [=[;
  --space-header-padding-bottom: ]=] .. s.headerPaddingBottom .. [=[;
  --space-title-wrap-gap: ]=] .. s.titleWrapGap .. [=[;
  --space-header-details-gap: ]=] .. s.headerDetailsGap .. [=[;
  --space-header-actions-gap: ]=] .. s.headerActionsGap .. [=[;
  --space-list-gap: ]=] .. s.listGap .. [=[;
  --space-row-gap: ]=] .. s.rowGap .. [=[;
  --space-slot-label-gap: ]=] .. s.slotLabelGap .. [=[;
  --space-slot-num-margin-right: ]=] .. s.slotNumMarginRight .. [=[;
  --space-pill-x: ]=] .. s.pillX .. [=[;
  --space-pill-y: ]=] .. s.pillY .. [=[;
  --space-min-badge-x: ]=] .. s.minBadgeX .. [=[;
  --space-min-badge-y: ]=] .. s.minBadgeY .. [=[;
  --space-button-x: ]=] .. s.buttonX .. [=[;
  --space-button-y: ]=] .. s.buttonY .. [=[;
  --space-header-button-x: ]=] .. s.headerButtonX .. [=[;
  --space-header-button-y: ]=] .. s.headerButtonY .. [=[;
  --space-config-panel-margin-top: ]=] .. s.configPanelMarginTop .. [=[;
  --space-config-panel-x: ]=] .. s.configPanelX .. [=[;
  --space-config-panel-y: ]=] .. s.configPanelY .. [=[;
  --space-config-item-gap: ]=] .. s.configItemGap .. [=[;
  --space-config-slider-gap: ]=] .. s.configSliderGap .. [=[;
  --space-config-slider-margin-top: ]=] .. s.configSliderMarginTop .. [=[;
  --space-config-slider-row-gap: ]=] .. s.configSliderRowGap .. [=[;
  --space-config-trigger-x: ]=] .. s.configTriggerX .. [=[;
  --space-config-trigger-y: ]=] .. s.configTriggerY .. [=[;
  --space-tooltip-x: ]=] .. s.tooltipX .. [=[;
  --space-tooltip-y: ]=] .. s.tooltipY .. [=[;

  --size-slot-num-width: ]=] .. sz.slotNumWidth .. [=[;
  --size-header-action-width: ]=] .. sz.headerActionWidth .. [=[;
  --size-header-action-height: ]=] .. sz.headerActionHeight .. [=[;
  --size-header-icon: ]=] .. sz.headerIconSize .. [=[;
  --size-config-panel-min-width: ]=] .. sz.configPanelMinWidth .. [=[;
  --size-config-panel-max-width-inset: ]=] .. sz.configPanelMaxWidthInset .. [=[;

  --radius-panel: ]=] .. r.panel .. [=[;
  --radius-sm: ]=] .. r.button .. [=[;
  --radius-md: ]=] .. r.configPanel .. [=[;
  --radius-pill: ]=] .. r.pill .. [=[;
  --radius-tooltip: ]=] .. r.tooltip .. [=[;

  --font-size-body: ]=] .. t.body .. [=[;
  --font-size-title: ]=] .. t.title .. [=[;
  --font-size-header-primary: ]=] .. t.headerPrimary .. [=[;
  --font-size-header-secondary: ]=] .. t.headerSecondary .. [=[;
  --font-size-slot: ]=] .. t.slot .. [=[;
  --font-size-slot-num: ]=] .. t.slotNum .. [=[;
  --font-size-min-badge: ]=] .. t.minBadge .. [=[;
  --font-size-button: ]=] .. t.button .. [=[;
  --font-size-tooltip: ]=] .. t.tooltip .. [=[;

  --color-text-base: ]=] .. c.textBase .. [=[;
  --color-text-primary: ]=] .. c.textPrimary .. [=[;
  --color-text-muted: ]=] .. c.textMuted .. [=[;
  --color-text-close: ]=] .. c.textClose .. [=[;
  --color-text-close-hover: ]=] .. c.textCloseHover .. [=[;
  --color-text-config: ]=] .. c.textConfig .. [=[;
  --color-text-config-hover: ]=] .. c.textConfigHover .. [=[;
  --color-text-config-item: ]=] .. c.textConfigItem .. [=[;
  --color-text-button-muted: ]=] .. c.textButtonMuted .. [=[;
  --color-text-tooltip: ]=] .. c.textTooltip .. [=[;
  --color-state-paired: ]=] .. c.paired .. [=[;
  --color-state-paired-minimized: ]=] .. c.pairedMinimized .. [=[;
  --color-state-unpaired: ]=] .. c.unpaired .. [=[;
  --color-surface-panel: ]=] .. c.surfacePanel .. [=[;
  --color-surface-pill: ]=] .. c.surfacePill .. [=[;
  --color-action-primary: ]=] .. c.surfacePrimary .. [=[;
  --color-action-primary-hover: ]=] .. c.surfacePrimaryHover .. [=[;
  --color-action-neutral: ]=] .. c.surfaceNeutral .. [=[;
  --color-action-neutral-hover: ]=] .. c.surfaceNeutralHover .. [=[;
  --color-action-danger: ]=] .. c.surfaceDanger .. [=[;
  --color-action-danger-hover: ]=] .. c.surfaceDangerHover .. [=[;
  --color-surface-close: ]=] .. c.surfaceClose .. [=[;
  --color-surface-close-hover: ]=] .. c.surfaceCloseHover .. [=[;
  --color-surface-config: ]=] .. c.surfaceConfig .. [=[;
  --color-surface-config-hover: ]=] .. c.surfaceConfigHover .. [=[;
  --color-surface-tooltip: ]=] .. c.surfaceTooltip .. [=[;
  --color-surface-config-panel: ]=] .. c.surfaceConfigPanel .. [=[;
  --color-border-panel: ]=] .. c.borderPanel .. [=[;
  --color-border-config-panel: ]=] .. c.borderConfigPanel .. [=[;
  --color-border-min-badge: ]=] .. c.borderMinBadge .. [=[;
  --color-bg-min-badge: ]=] .. c.bgMinBadge .. [=[;
  --color-focus-ring: ]=] .. c.focusRing .. [=[;

  --effect-panel-shadow: ]=] .. e.panelShadow .. [=[;
  --effect-config-panel-shadow: ]=] .. e.configPanelShadow .. [=[;
  --effect-backdrop: ]=] .. e.backdrop .. [=[;
  --effect-pill-backdrop: ]=] .. e.pillBackdrop .. [=[;
  --transition-fast: ]=] .. e.transitionFast .. [=[;
  --transition-tooltip: ]=] .. e.tooltipTransition .. [=[;

  --z-config-panel: ]=] .. z.configPanel .. [=[;
  --z-tooltip: ]=] .. z.tooltip .. [=[;
}
]=]
end

function Styles.buildCss(theme)
  return table.concat({
    "/* Reset / base */\n",
    [=[
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}
]=],
    "\n",
    "/* Root variables */\n",
    rootVars(theme),
    "\n",
    "/* Shell / layout */\n",
    [=[
html, body {
  width: 100%;
  height: 100%;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
  background: transparent;
  color: var(--color-text-base);
  font-size: calc(var(--font-size-body) * var(--ui-scale));
  -webkit-user-select: none;
  overflow: hidden;
}

.container {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: calc(var(--space-shell-gap) * var(--ui-scale));
  height: 100%;
  padding: calc(var(--space-container) * var(--ui-scale));
  background: var(--color-surface-panel);
  -webkit-backdrop-filter: var(--effect-backdrop);
  backdrop-filter: var(--effect-backdrop);
  border: 1px solid var(--color-border-panel);
  border-radius: var(--radius-panel);
  box-shadow: var(--effect-panel-shadow);
  overflow: hidden;
}

.workspace-list {
  flex: 0 0 auto;
  display: grid;
  grid-template-rows: repeat(9, auto);
  gap: calc(var(--space-list-gap) * var(--ui-scale));
  align-content: start;
}
]=],
    "\n",
    "/* Header */\n",
    [=[
.header {
  display: flex;
  flex-wrap: nowrap;
  align-items: flex-start;
  gap: calc(var(--space-header-gap) * var(--ui-scale));
  padding-bottom: calc(var(--space-header-padding-bottom) * var(--ui-scale));
  border-bottom: 1px solid #333;
  cursor: move;
}

.title-wrap {
  display: inline-flex;
  align-items: center;
  gap: calc(var(--space-title-wrap-gap) * var(--ui-scale));
  flex: 0 0 auto;
}

.title {
  font-weight: 700;
  font-size: calc(var(--font-size-title) * var(--ui-scale));
  color: var(--color-text-primary);
  letter-spacing: 0.5px;
  line-height: 1.1;
}

.header-details {
  display: flex;
  flex-direction: column;
  gap: calc(var(--space-header-details-gap) * var(--ui-scale));
  flex: 1 1 180px;
  min-width: 0;
}

.header-primary {
  display: block;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  line-height: 1.2;
  font-size: calc(var(--font-size-header-primary) * var(--ui-scale));
  font-weight: 600;
  color: var(--color-text-primary);
}

.header-secondary {
  display: block;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  line-height: 1.2;
  font-size: calc(var(--font-size-header-secondary) * var(--ui-scale));
  color: var(--color-text-muted);
}

.header-actions {
  display: flex;
  align-items: center;
  flex-wrap: nowrap;
  gap: calc(var(--space-header-actions-gap) * var(--ui-scale));
  margin-left: auto;
  flex-shrink: 0;
}
]=],
    "\n",
    "/* Workspace rows */\n",
    [=[
.row {
  display: flex;
  align-items: center;
  flex-wrap: nowrap;
  gap: calc(var(--space-row-gap) * var(--ui-scale));
  min-height: 0;
}

.slot-num {
  width: calc(var(--size-slot-num-width) * var(--ui-scale));
  text-align: right;
  color: var(--color-text-primary);
  font-size: calc(var(--font-size-slot-num) * var(--ui-scale));
  font-weight: 600;
  margin-right: calc(var(--space-slot-num-margin-right) * var(--ui-scale));
  flex-shrink: 0;
}

.slot-label {
  display: flex;
  align-items: center;
  gap: calc(var(--space-slot-label-gap) * var(--ui-scale));
  flex: 1 1 0;
  width: 0;
  min-width: 0;
  overflow: hidden;
  font-size: calc(var(--font-size-slot) * var(--ui-scale));
}

.slot-text-bg {
  display: inline-block;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  padding: calc(var(--space-pill-y) * var(--ui-scale)) calc(var(--space-pill-x) * var(--ui-scale));
  background: var(--color-surface-pill);
  -webkit-backdrop-filter: var(--effect-pill-backdrop);
  backdrop-filter: var(--effect-pill-backdrop);
  border-radius: var(--radius-pill);
  min-width: 0;
}

.min-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: calc(var(--space-min-badge-y) * var(--ui-scale)) calc(var(--space-min-badge-x) * var(--ui-scale));
  border-radius: var(--radius-pill);
  background: var(--color-bg-min-badge);
  border: 1px solid var(--color-border-min-badge);
  color: var(--color-state-paired-minimized);
  font-size: calc(var(--font-size-min-badge) * var(--ui-scale));
  font-weight: 700;
  letter-spacing: 0.35px;
  flex-shrink: 0;
}

.slot-buttons {
  display: flex;
  gap: calc(var(--space-row-gap) * var(--ui-scale));
  flex-shrink: 0;
  flex-wrap: nowrap;
  margin-left: auto;
}
]=],
    "\n",
    "/* Button primitives */\n",
    [=[
.btn,
.header-btn,
.config-trigger {
  border: none;
  border-radius: calc(var(--radius-sm) * var(--ui-scale));
  cursor: pointer;
}

.btn {
  padding: calc(var(--space-button-y) * var(--ui-scale)) calc(var(--space-button-x) * var(--ui-scale));
  font-size: calc(var(--font-size-button) * var(--ui-scale));
  font-weight: 500;
  transition: var(--transition-fast);
  white-space: nowrap;
}

.btn:active,
.header-btn:active {
  opacity: 0.6;
}

.btn-primary {
  background: var(--color-action-primary);
  color: var(--color-text-primary);
  opacity: 0.9;
}

.btn-primary:hover {
  background: var(--color-action-primary-hover);
  opacity: 1;
}

.btn-unpair {
  background: var(--color-action-neutral);
  color: var(--color-text-button-muted);
}

.btn-unpair:hover {
  background: var(--color-action-neutral-hover);
}

.header-btn {
  padding: calc(var(--space-header-button-y) * var(--ui-scale)) calc(var(--space-header-button-x) * var(--ui-scale));
  font-size: calc(var(--font-size-button) * var(--ui-scale));
  font-weight: 600;
  transition: var(--transition-fast);
}

.header-danger {
  background: var(--color-action-danger);
  color: var(--color-text-primary);
  opacity: 0.9;
}

.header-danger:hover {
  background: var(--color-action-danger-hover);
  opacity: 1;
}

.header-close {
  background: var(--color-surface-close);
  color: var(--color-text-close);
}

.header-close:hover {
  background: var(--color-surface-close-hover);
  color: var(--color-text-close-hover);
}

.header-btn.icon-only,
.config-trigger.icon-only {
  width: calc(var(--size-header-action-width) * var(--ui-scale));
  height: calc(var(--size-header-action-height) * var(--ui-scale));
  padding: 0;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.header-btn.icon-only:focus-visible,
.config-trigger.icon-only:focus-visible {
  outline: none;
  box-shadow: 0 0 0 calc(1px * var(--ui-scale)) var(--color-focus-ring);
}

.header-icon {
  width: calc(var(--size-header-icon) * var(--ui-scale));
  height: calc(var(--size-header-icon) * var(--ui-scale));
  display: block;
  stroke: currentColor;
  fill: none;
  pointer-events: none;
}
]=],
    "\n",
    "/* Config menu */\n",
    [=[
.config-menu {
  position: relative;
}

.config-menu summary {
  list-style: none;
}

.config-menu summary::-webkit-details-marker {
  display: none;
}

.config-panel {
  position: absolute;
  top: 100%;
  right: 0;
  margin-top: calc(var(--space-config-panel-margin-top) * var(--ui-scale));
  min-width: var(--size-config-panel-min-width);
  max-width: min(280px, calc(100vw - var(--size-config-panel-max-width-inset)));
  border: 1px solid var(--color-border-config-panel);
  border-radius: calc(var(--radius-md) * var(--ui-scale));
  background: var(--color-surface-config-panel);
  box-shadow: var(--effect-config-panel-shadow);
  padding: calc(var(--space-config-panel-y) * var(--ui-scale)) calc(var(--space-config-panel-x) * var(--ui-scale));
  z-index: var(--z-config-panel);
}

.config-item {
  display: flex;
  align-items: center;
  gap: calc(var(--space-config-item-gap) * var(--ui-scale));
  font-size: calc(var(--font-size-button) * var(--ui-scale));
  color: var(--color-text-config-item);
  cursor: pointer;
}

.config-item input {
  accent-color: var(--color-action-primary);
}

.config-item-debug {
  margin-top: calc(var(--space-config-slider-margin-top) * var(--ui-scale));
}

.config-slider-wrap {
  display: flex;
  flex-direction: column;
  gap: calc(var(--space-config-slider-gap) * var(--ui-scale));
  margin-top: calc(var(--space-config-slider-margin-top) * var(--ui-scale));
}

.config-slider-row {
  display: flex;
  align-items: center;
  gap: calc(var(--space-config-slider-row-gap) * var(--ui-scale));
  font-size: calc(var(--font-size-button) * var(--ui-scale));
  color: var(--color-text-config-item);
}

.config-slider {
  width: 100%;
}

.config-trigger {
  padding: calc(var(--space-config-trigger-y) * var(--ui-scale)) calc(var(--space-config-trigger-x) * var(--ui-scale));
  font-size: calc(var(--font-size-button) * var(--ui-scale));
  font-weight: 600;
  background: var(--color-surface-config);
  color: var(--color-text-config);
}

.config-trigger:hover {
  background: var(--color-surface-config-hover);
  color: var(--color-text-config-hover);
}
]=],
    "\n",
    "/* Tooltip */\n",
    [=[
.header-tooltip {
  position: absolute;
  top: 0;
  left: 0;
  padding: calc(var(--space-tooltip-y) * var(--ui-scale)) calc(var(--space-tooltip-x) * var(--ui-scale));
  border-radius: calc(var(--radius-tooltip) * var(--ui-scale));
  background: var(--color-surface-tooltip);
  color: var(--color-text-tooltip);
  font-size: calc(var(--font-size-tooltip) * var(--ui-scale));
  line-height: 1;
  white-space: nowrap;
  pointer-events: none;
  opacity: 0;
  visibility: hidden;
  transform: translate3d(0, 0, 0);
  transition: var(--transition-tooltip);
  z-index: var(--z-tooltip);
}
]=],
    "\n",
    "/* State modifiers */\n",
    [=[
.paired {
  color: var(--color-state-paired);
}

.paired-minimized {
  color: var(--color-state-paired-minimized);
}

.unpaired {
  color: var(--color-state-unpaired);
  font-style: italic;
}

.btn-unpair.off {
  opacity: 0.25;
  pointer-events: none;
}

.header-tooltip.is-visible {
  opacity: 1;
  visibility: visible;
}
]=],
  })
end

return Styles
