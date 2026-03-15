local DebugStyles = {}

DebugStyles.css = [=[
.container {
  outline: 1px solid rgba(255, 255, 255, 0.95);
  outline-offset: -1px;
  position: relative;
}

.workspace-list {
  outline: 1px solid rgba(255, 0, 255, 0.9);
  outline-offset: -1px;
  position: relative;
}

.row {
  outline: 1px solid rgba(255, 140, 0, 0.95);
  outline-offset: -1px;
  position: relative;
}

.slot-num {
  outline: 1px solid rgba(255, 80, 80, 0.95);
  outline-offset: -1px;
  position: relative;
}

.slot-label {
  outline: 1px solid rgba(0, 220, 255, 0.95);
  outline-offset: -1px;
  position: relative;
}

.slot-text-bg {
  outline: 1px solid rgba(0, 255, 120, 0.95);
  outline-offset: -1px;
  position: relative;
}

.min-badge {
  outline: 1px solid rgba(255, 230, 0, 0.95);
  outline-offset: -1px;
  position: relative;
}

.slot-buttons {
  outline: 1px solid rgba(180, 120, 255, 0.95);
  outline-offset: -1px;
  position: relative;
}

.container::before,
.workspace-list::before,
.row::before,
.slot-num::before,
.slot-label::before,
.slot-text-bg::before,
.min-badge::before,
.slot-buttons::before {
  position: absolute;
  top: 0;
  left: 0;
  padding: 0 calc(3px * var(--ui-scale));
  font-size: calc(7px * var(--ui-scale));
  font-weight: 700;
  line-height: 1.2;
  letter-spacing: 0.2px;
  color: #111;
  pointer-events: none;
  z-index: 2;
}

.container::before {
  content: "container";
  background: rgba(255, 255, 255, 0.95);
}

.workspace-list::before {
  content: "workspace-list grid";
  background: rgba(255, 0, 255, 0.9);
}

.row::before {
  content: "row flex";
  background: rgba(255, 140, 0, 0.95);
}

.slot-num::before {
  content: "slot-num";
  background: rgba(255, 80, 80, 0.95);
}

.slot-label::before {
  content: "slot-label flex";
  background: rgba(0, 220, 255, 0.95);
}

.slot-text-bg::before {
  content: "slot-text-bg pill";
  background: rgba(0, 255, 120, 0.95);
}

.min-badge::before {
  content: "min-badge";
  background: rgba(255, 230, 0, 0.95);
}

.slot-buttons::before {
  content: "slot-buttons";
  background: rgba(180, 120, 255, 0.95);
}
]=]

return DebugStyles
