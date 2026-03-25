local ClientScript = {}

ClientScript.script = [=[
var MOD_SYMBOLS = {
  cmd: "⌘",
  alt: "⌥",
  ctrl: "⌃",
  shift: "⇧"
};

var KEY_LABELS = {
  left: "Left",
  right: "Right",
  up: "Up",
  down: "Down",
  return: "Return",
  delete: "Delete",
  forwarddelete: "Forward Delete",
  escape: "Esc",
  space: "Space",
  tab: "Tab"
};

var PHYSICAL_KEY_MAP = {
  Backquote: "`",
  Digit0: "0",
  Digit1: "1",
  Digit2: "2",
  Digit3: "3",
  Digit4: "4",
  Digit5: "5",
  Digit6: "6",
  Digit7: "7",
  Digit8: "8",
  Digit9: "9",
  Minus: "-",
  Equal: "=",
  BracketLeft: "[",
  BracketRight: "]",
  Backslash: "\\",
  Semicolon: ";",
  Quote: "'",
  Comma: ",",
  Period: ".",
  Slash: "/",
  Space: "space",
  Tab: "tab",
  Enter: "return",
  Backspace: "delete",
  Delete: "forwarddelete",
  Escape: "escape",
  ArrowLeft: "left",
  ArrowRight: "right",
  ArrowUp: "up",
  ArrowDown: "down"
};

function currentSettingsTab() {
  return document.body.getAttribute("data-settings-tab") || "general";
}

function settingsOpen() {
  return document.body.getAttribute("data-settings-open") === "1";
}

function getSearchInput() {
  return document.querySelector(".hotkey-search");
}

function getActiveSettingsPanel() {
  return document.querySelector('.settings-panel[data-settings-panel="' + currentSettingsTab() + '"]');
}

function getSettingsScrollEl() {
  return getActiveSettingsPanel() || document.querySelector(".settings-scroll");
}

function getSearchValue() {
  var input = getSearchInput();
  return input ? input.value : "";
}

function getSettingsScrollTop() {
  var el = getSettingsScrollEl();
  return el ? el.scrollTop : 0;
}

function sendAction(action, extra) {
  var payload = extra || {};
  payload.action = action;
  if (payload.slot == null) payload.slot = 0;
  if (payload.dx == null) payload.dx = 0;
  if (payload.dy == null) payload.dy = 0;
  if (payload.dw == null) payload.dw = 0;
  if (payload.dh == null) payload.dh = 0;
  if (payload.direction == null) payload.direction = "";
  if (payload.search == null) payload.search = getSearchValue();
  if (payload.scrollTop == null) payload.scrollTop = getSettingsScrollTop();
  if (payload.settingsTab == null) payload.settingsTab = currentSettingsTab();
  window.webkit.messageHandlers.tapshop.postMessage(payload);
}

function setSettingsOpenState(open) {
  document.body.setAttribute("data-settings-open", open ? "1" : "0");
  var sheet = document.querySelector(".settings-sheet");
  var list = document.querySelector(".workspace-list");
  if (sheet) sheet.classList.toggle("is-open", open);
  if (list) list.classList.toggle("is-dimmed", open);
}

function setSettingsTabState(tab) {
  document.body.setAttribute("data-settings-tab", tab);
  document.querySelectorAll("[data-settings-tab-button]").forEach(function (button) {
    button.classList.toggle("is-active", button.getAttribute("data-settings-tab-button") === tab);
  });
}

function restoreSettingsScrollState() {
  var el = getSettingsScrollEl();
  if (!el) return;
  var value = parseFloat(document.body.getAttribute("data-settings-scroll-top") || "0") || 0;
  el.scrollTop = Math.max(0, value);
}

function clearValidationUi() {
  document.querySelectorAll(".hotkey-row.has-live-conflict").forEach(function (row) {
    row.classList.remove("has-live-conflict");
  });
  var validation = document.querySelector("[data-hotkey-validation]");
  if (validation) {
    validation.textContent = "";
    validation.classList.add("is-hidden");
  }
  var modalError = document.querySelector("[data-remap-error]");
  if (modalError) {
    modalError.textContent = "";
    modalError.classList.add("is-hidden");
  }
}

function escapeHtml(value) {
  return String(value == null ? "" : value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function renderHotkeyRowHtml(row) {
  var classes = ["hotkey-row"];
  if (row.isModified) classes.push("is-modified");
  if (row.isUnavailable) classes.push("is-unavailable");
  if (row.warning) classes.push("has-warning");
  if ((row.conflictIds || []).length > 0) classes.push("has-conflict");

  var rawKey = row.isAssigned ? String(row.key || "") : "";
  var comboSearch = row.isAssigned ? ((row.mods || []).join(" ") + " " + rawKey).toLowerCase() : "";
  var comboTitle = row.isAssigned ? "Current shortcut" : "No shortcut assigned";
  var comboClass = row.isAssigned ? "hotkey-combo" : "hotkey-combo hotkey-combo-empty";
  var comboInner = row.isAssigned ? comboHtml(row.mods, row.key) : '<span class="hotkey-unset">(unset)</span>';
  var resetHtml = row.isModified
    ? '<button type="button" class="btn hotkey-btn hotkey-reset-btn" title="Reset row" onclick="resetBinding('
      + JSON.stringify(row.id)
      + ')">Reset</button>'
    : "";

  return ''
    + '<div class="' + classes.join(" ") + '"'
    + ' data-hotkey-row'
    + ' data-id="' + escapeHtml(row.id) + '"'
    + ' data-label="' + escapeHtml(String(row.label || "").toLowerCase()) + '"'
    + ' data-group="' + escapeHtml(String(row.group || "").toLowerCase()) + '"'
    + ' data-key="' + escapeHtml(rawKey) + '"'
    + ' data-mods="' + escapeHtml((row.mods || []).join(" ")) + '"'
    + ' data-assigned="' + (row.isAssigned ? "1" : "0") + '"'
    + ' data-combo="' + escapeHtml(comboSearch) + '">'
    + '<div class="hotkey-main">'
    + '<span class="hotkey-label">' + escapeHtml(row.label) + '</span>'
    + '<div class="' + comboClass + '" title="' + escapeHtml(comboTitle) + '">' + comboInner + '</div>'
    + '</div>'
    + '<div class="hotkey-actions">'
    + '<button type="button" class="btn hotkey-btn hotkey-remap-btn" title="Record shortcut" onclick="openRemapModal(' + JSON.stringify(row.id) + ')">Remap</button>'
    + resetHtml
    + '</div>'
    + '</div>';
}

function renderHotkeyList(rows) {
  var list = document.querySelector("[data-hotkeys-list]");
  if (!list) return;

  var html = "";
  var currentGroup = null;
  (rows || []).forEach(function (row) {
    if (row.group !== currentGroup) {
      if (currentGroup !== null) html += "</section>";
      currentGroup = row.group;
      html += '<section class="hotkey-group" data-hotkey-group="' + escapeHtml(String(row.group || "").toLowerCase()) + '">';
      html += '<div class="hotkey-group-title">' + escapeHtml(row.group) + '</div>';
    }
    html += renderHotkeyRowHtml(row);
  });
  if (currentGroup !== null) html += "</section>";

  list.innerHTML = html;
}

function showValidationUi(result) {
  clearValidationUi();
  if (!result || !result.message) return;

  var validation = document.querySelector("[data-hotkey-validation]");
  if (validation) {
    validation.textContent = result.message;
    validation.classList.remove("is-hidden");
  }

  if (result.ids) {
    Object.keys(result.ids).forEach(function (id) {
      var row = document.querySelector('[data-hotkey-row][data-id="' + id + '"]');
      if (row) row.classList.add("has-live-conflict");
    });
  }

  if (remapState.open && remapState.errorEl) {
    remapState.errorEl.textContent = result.message;
    remapState.errorEl.classList.remove("is-hidden");
  }
}

window.tapshopApplyValidation = function (result) {
  showValidationUi(result || null);
};

window.tapshopApplyHotkeyState = function (state) {
  state = state || {};
  cancelRemapModal();
  renderHotkeyList(state.rows || []);
  document.body.setAttribute("data-settings-scroll-top", String(state.scrollTop || 0));
  filterHotkeyRows(getSearchValue());
  restoreSettingsScrollState();
  showValidationUi(state.validation || null);
};

function toggleSettings() {
  var nextOpen = !settingsOpen();
  if (nextOpen) {
    setSettingsOpenState(true);
    clearValidationUi();
  } else {
    closeSettings();
    return;
  }
  sendAction("toggleSettings");
}

function closeSettings() {
  cancelRemapModal();
  clearValidationUi();
  var input = getSearchInput();
  if (input) input.value = "";
  filterHotkeyRows("");
  setSettingsOpenState(false);
  sendAction("closeSettings", { search: "" });
}

function switchSettingsTab(tab) {
  cancelRemapModal();
  clearValidationUi();
  setSettingsTabState(tab);
  sendAction("setSettingsTab", { settingsTab: tab });
}

function resetBinding(id) {
  cancelRemapModal();
  clearValidationUi();
  sendAction("resetHotkeyBinding", { id: id });
}

function resetAllHotkeys() {
  cancelRemapModal();
  if (!window.confirm("Restore all hotkeys to defaults?")) return;
  clearValidationUi();
  sendAction("resetAllHotkeys");
}

function normalizeKey(e) {
  var code = e.code || "";
  var key = e.key || "";

  if (PHYSICAL_KEY_MAP[code]) {
    return PHYSICAL_KEY_MAP[code];
  }

  if (/^Key[A-Z]$/.test(code)) {
    return code.slice(3).toLowerCase();
  }

  if (/^F\d+$/.test(key)) return key;

  var keyMap = {
    ArrowLeft: "left",
    ArrowRight: "right",
    ArrowUp: "up",
    ArrowDown: "down",
    Escape: "escape",
    Enter: "return",
    Backspace: "delete",
    Delete: "forwarddelete",
    " ": "space",
    Tab: "tab"
  };
  return keyMap[key] || key.toLowerCase();
}

function displayKey(key) {
  return KEY_LABELS[key] || String(key || "").toUpperCase();
}

function comboHtml(mods, key) {
  if (key === false || key == null || key === "") {
    return "";
  }
  var parts = [];
  (mods || []).forEach(function (mod) {
    parts.push('<span class="keycap">' + (MOD_SYMBOLS[mod] || mod) + '</span>');
  });
  parts.push('<span class="keycap">' + displayKey(key) + "</span>");
  return parts.join("");
}

function filterHotkeyRows(value) {
  var query = (value || "").toLowerCase().trim();
  var rows = document.querySelectorAll("[data-hotkey-row]");
  rows.forEach(function (row) {
    var label = row.getAttribute("data-label") || "";
    var group = row.getAttribute("data-group") || "";
    var combo = row.getAttribute("data-combo") || "";
    var match = !query || label.indexOf(query) !== -1 || group.indexOf(query) !== -1 || combo.indexOf(query) !== -1;
    row.classList.toggle("is-hidden", !match);
  });

  document.querySelectorAll("[data-hotkey-group]").forEach(function (group) {
    var visible = group.querySelector("[data-hotkey-row]:not(.is-hidden)");
    group.classList.toggle("is-hidden", !visible);
  });
}

function handleSearchInput(value) {
  filterHotkeyRows(value);
}

var remapState = {
  open: false,
  targetId: null,
  targetLabel: "",
  currentMods: [],
  currentKey: null,
  draftMods: [],
  draftKey: null,
  cleared: false,
  shellEl: null,
  labelEl: null,
  currentEl: null,
  draftEl: null,
  errorEl: null,
  saveEl: null
};

function syncRemapActionState() {
  if (!remapState.saveEl) return;
  var canSave = remapState.cleared || remapState.draftKey;
  remapState.saveEl.disabled = !canSave;
}

function renderRemapPreview() {
  if (!remapState.currentEl || !remapState.draftEl) return;
  remapState.currentEl.innerHTML = comboHtml(remapState.currentMods, remapState.currentKey);
  remapState.currentEl.classList.toggle("is-empty", !remapState.currentKey);

  var draftKey = remapState.cleared ? false : remapState.draftKey;
  var draftMods = remapState.cleared ? [] : remapState.draftMods;
  remapState.draftEl.innerHTML = comboHtml(draftMods, draftKey);
  remapState.draftEl.classList.toggle("is-empty", !(remapState.cleared || remapState.draftKey));
  syncRemapActionState();
}

function openRemapModal(id) {
  var row = document.querySelector('[data-hotkey-row][data-id="' + id + '"]');
  if (!row || !remapState.shellEl) return;

  clearValidationUi();
  remapState.open = true;
  remapState.targetId = id;
  remapState.targetLabel = row.getAttribute("data-label") || "";
  remapState.currentKey = row.getAttribute("data-assigned") === "1" ? row.getAttribute("data-key") : false;
  remapState.currentMods = (row.getAttribute("data-mods") || "").split(" ").filter(Boolean);
  remapState.draftMods = [];
  remapState.draftKey = null;
  remapState.cleared = false;

  remapState.labelEl.textContent = row.querySelector(".hotkey-label").textContent;
  remapState.errorEl.textContent = "";
  remapState.errorEl.classList.add("is-hidden");
  remapState.shellEl.hidden = false;
  renderRemapPreview();
}

function cancelRemapModal() {
  if (!remapState.open) return;
  remapState.open = false;
  remapState.targetId = null;
  remapState.draftMods = [];
  remapState.draftKey = null;
  remapState.cleared = false;
  if (remapState.errorEl) {
    remapState.errorEl.textContent = "";
    remapState.errorEl.classList.add("is-hidden");
  }
  if (remapState.shellEl) remapState.shellEl.hidden = true;
}

function clearRemapBinding() {
  remapState.cleared = true;
  remapState.draftMods = [];
  remapState.draftKey = false;
  if (remapState.errorEl) {
    remapState.errorEl.textContent = "";
    remapState.errorEl.classList.add("is-hidden");
  }
  renderRemapPreview();
}

function saveRemapModal() {
  if (!remapState.open || !remapState.targetId) return;
  clearValidationUi();
  if (remapState.cleared) {
    sendAction("updateHotkeyBinding", {
      id: remapState.targetId,
      mods: [],
      key: false
    });
    return;
  }
  if (!remapState.draftKey) return;
  sendAction("updateHotkeyBinding", {
    id: remapState.targetId,
    mods: remapState.draftMods,
    key: remapState.draftKey
  });
}

var MIN_UI_SCALE = 0.5;
var MAX_UI_SCALE = 1.5;
var RESIZE_ZONE = 10;
var TITLE_TAP_WINDOW_MS = 650;

function setUiScale(scale) {
  document.documentElement.style.setProperty("--ui-scale", scale.toFixed(3));
}

function readPx(value) {
  return parseFloat(value || "0") || 0;
}

function measureContentHeightAtScale(scale) {
  var container = document.querySelector(".container");
  var header = document.querySelector(".header");
  var workspaceList = document.querySelector(".workspace-list");
  var settingsSheet = document.querySelector(".settings-sheet");
  var settingsHead = document.querySelector(".settings-head");
  var settingsScroll = document.querySelector(".settings-scroll");
  var activePanel = document.querySelector('.settings-panel[data-settings-panel="' + currentSettingsTab() + '"]');
  if (!container || !header) return 0;

  setUiScale(scale);
  void container.offsetHeight;

  var containerStyle = window.getComputedStyle(container);
  var containerGap = readPx(containerStyle.rowGap || containerStyle.gap);
  var total = readPx(containerStyle.paddingTop)
    + readPx(containerStyle.paddingBottom)
    + readPx(containerStyle.borderTopWidth)
    + readPx(containerStyle.borderBottomWidth)
    + header.getBoundingClientRect().height
    + containerGap;

  if (settingsOpen() && settingsSheet && settingsHead && settingsScroll && activePanel) {
    var sheetStyle = window.getComputedStyle(settingsSheet);
    var scrollStyle = window.getComputedStyle(settingsScroll);
    total = total
      + readPx(sheetStyle.paddingTop)
      + readPx(sheetStyle.paddingBottom)
      + readPx(sheetStyle.borderTopWidth)
      + readPx(sheetStyle.borderBottomWidth)
      + readPx(sheetStyle.rowGap || sheetStyle.gap)
      + settingsHead.getBoundingClientRect().height
      + readPx(scrollStyle.paddingTop)
      + readPx(scrollStyle.paddingBottom)
      + Math.min(activePanel.scrollHeight, settingsScroll.getBoundingClientRect().height || activePanel.scrollHeight);
    return total;
  }

  if (!workspaceList) return total;
  return total + workspaceList.getBoundingClientRect().height;
}

function updateUiScale() {
  var baseHeight = measureContentHeightAtScale(1);
  var maxHeight = measureContentHeightAtScale(MAX_UI_SCALE);
  if (!baseHeight || !maxHeight || maxHeight <= baseHeight) {
    setUiScale(1);
    return;
  }

  var scalableHeight = (maxHeight - baseHeight) / (MAX_UI_SCALE - 1);
  if (scalableHeight <= 0) {
    setUiScale(1);
    return;
  }

  var fixedHeight = baseHeight - scalableHeight;
  var scale = (window.innerHeight - fixedHeight) / scalableHeight;
  scale = Math.min(MAX_UI_SCALE, scale);
  scale = Math.max(MIN_UI_SCALE, scale);
  setUiScale(scale);
}

function getResizeDirection(e) {
  var nearLeft = e.clientX <= RESIZE_ZONE;
  var nearRight = e.clientX >= window.innerWidth - RESIZE_ZONE;
  var nearTop = e.clientY <= RESIZE_ZONE;
  var nearBottom = e.clientY >= window.innerHeight - RESIZE_ZONE;

  if (nearTop && nearLeft) return "nw";
  if (nearTop && nearRight) return "ne";
  if (nearBottom && nearLeft) return "sw";
  if (nearBottom && nearRight) return "se";
  if (nearLeft) return "w";
  if (nearRight) return "e";
  if (nearTop) return "n";
  if (nearBottom) return "s";
  return "";
}

function cursorForDirection(direction) {
  if (direction === "n" || direction === "s") return "ns-resize";
  if (direction === "e" || direction === "w") return "ew-resize";
  if (direction === "ne" || direction === "sw") return "nesw-resize";
  if (direction === "nw" || direction === "se") return "nwse-resize";
  return "";
}

function setGlobalCursor(cursor) {
  document.documentElement.style.cursor = cursor || "";
  document.body.style.cursor = cursor || "";
}

var container = document.querySelector(".container");
var header = document.querySelector(".header");
var headerActions = document.querySelector(".header-actions");
var headerTooltip = document.querySelector(".header-tooltip");
var titleTrigger = document.querySelector(".title-trigger");
var titleHop = document.querySelector(".title-hop");
var tooltipTarget = null;
var titleTapTimestamps = [];

function hideHeaderTooltip() {
  tooltipTarget = null;
  if (!headerTooltip) return;
  headerTooltip.classList.remove("is-visible");
  headerTooltip.textContent = "";
}

function readPx(value) {
  return parseFloat(value || "0") || 0;
}

function showHeaderTooltip(el) {
  if (!container || !headerActions || !headerTooltip || !el) return;
  if (dragState.active || resizeState.active) return;

  var tooltipText = el.getAttribute("data-tooltip") || "";
  if (!tooltipText) {
    hideHeaderTooltip();
    return;
  }

  tooltipTarget = el;
  headerTooltip.textContent = tooltipText;
  headerTooltip.classList.add("is-visible");

  var containerRect = container.getBoundingClientRect();
  var headerRect = header ? header.getBoundingClientRect() : null;
  var buttonRect = el.getBoundingClientRect();
  var style = window.getComputedStyle(container);
  var paddingLeft = readPx(style.paddingLeft);
  var paddingRight = readPx(style.paddingRight);
  var tooltipRect = headerTooltip.getBoundingClientRect();
  var minLeft = paddingLeft + 6;
  var maxLeft = containerRect.width - tooltipRect.width - paddingRight - 6;
  var centeredLeft = (buttonRect.left - containerRect.left) + (buttonRect.width / 2) - (tooltipRect.width / 2);
  var left = Math.max(minLeft, Math.min(centeredLeft, maxLeft));
  var topBase = headerRect ? ((headerRect.bottom - containerRect.top) + 4) : 30;

  headerTooltip.style.left = left + "px";
  headerTooltip.style.top = topBase + "px";
}

function triggerTitleHop() {
  if (!titleHop) return;
  titleHop.classList.remove("is-hopping");
  void titleHop.offsetWidth;
  titleHop.classList.add("is-hopping");
}

var dragState = {
  active: false,
  moved: false,
  lastX: 0,
  lastY: 0
};

var resizeState = {
  active: false,
  lastX: 0,
  lastY: 0,
  direction: ""
};

document.addEventListener("mousedown", function (e) {
  if (e.button !== 0) return;
  var direction = getResizeDirection(e);
  if (!direction) return;
  resizeState.active = true;
  resizeState.direction = direction;
  resizeState.lastX = e.screenX;
  resizeState.lastY = e.screenY;
  setGlobalCursor(cursorForDirection(direction));
  hideHeaderTooltip();
  sendAction("resizeStart", { direction: direction });
  e.preventDefault();
  e.stopPropagation();
}, true);

if (header) {
  header.addEventListener("mousedown", function (e) {
    if (e.button !== 0) return;
    if (
      e.target
      && e.target.closest
      && e.target.closest(".header-actions, .title-trigger, button, input, label")
    ) return;
    dragState.active = true;
    dragState.moved = false;
    dragState.lastX = e.screenX;
    dragState.lastY = e.screenY;
    hideHeaderTooltip();
    sendAction("dragStart");
    e.preventDefault();
  });
}

window.addEventListener("mousemove", function (e) {
  if (dragState.active) {
    var dx = e.screenX - dragState.lastX;
    var dy = e.screenY - dragState.lastY;
    dragState.lastX = e.screenX;
    dragState.lastY = e.screenY;
    if (dx !== 0 || dy !== 0) {
      dragState.moved = true;
      sendAction("dragMove", { dx: dx, dy: dy });
    }
  }

  if (resizeState.active) {
    var dw = e.screenX - resizeState.lastX;
    var dh = e.screenY - resizeState.lastY;
    resizeState.lastX = e.screenX;
    resizeState.lastY = e.screenY;
    if (dw !== 0 || dh !== 0) {
      sendAction("resizeMove", { dw: dw, dh: dh, direction: resizeState.direction });
    }
  }
});

window.addEventListener("mouseup", function () {
  if (dragState.active) {
    var shouldCloseSettings = settingsOpen() && !dragState.moved;
    dragState.active = false;
    sendAction("dragEnd");
    if (shouldCloseSettings) {
      closeSettings();
      return;
    }
  }

  if (resizeState.active) {
    resizeState.active = false;
    resizeState.direction = "";
    setGlobalCursor("");
    sendAction("resizeEnd");
  }
});

document.addEventListener("mousemove", function (e) {
  if (dragState.active || resizeState.active) return;
  setGlobalCursor(cursorForDirection(getResizeDirection(e)));
});

document.addEventListener("mouseleave", function () {
  if (dragState.active || resizeState.active) return;
  setGlobalCursor("");
});

document.addEventListener("keydown", function (e) {
  if (remapState.open) {
    e.preventDefault();
    e.stopPropagation();

    var modifierKeys = { Meta: true, Alt: true, Control: true, Shift: true };
    if (modifierKeys[e.key]) return;

    var mods = [];
    if (e.metaKey) mods.push("cmd");
    if (e.altKey) mods.push("alt");
    if (e.ctrlKey) mods.push("ctrl");
    if (e.shiftKey) mods.push("shift");

    var key = normalizeKey(e);
    if (key === "escape" && mods.length === 0) {
      cancelRemapModal();
      return;
    }

    remapState.cleared = false;
    remapState.draftMods = mods;
    remapState.draftKey = key;
    if (remapState.errorEl) {
      remapState.errorEl.textContent = "";
      remapState.errorEl.classList.add("is-hidden");
    }
    renderRemapPreview();
    return;
  }

  if (e.key === "Escape") {
    e.preventDefault();
    e.stopPropagation();
    if (settingsOpen()) {
      closeSettings();
    } else {
      sendAction("close");
    }
  }
});

document.addEventListener("mousedown", function (e) {
  hideHeaderTooltip();
});

document.querySelectorAll("[data-tooltip]").forEach(function (el) {
  el.addEventListener("mouseenter", function () {
    showHeaderTooltip(el);
  });
  el.addEventListener("mouseleave", function () {
    if (tooltipTarget === el) hideHeaderTooltip();
  });
  el.addEventListener("focusin", function () {
    showHeaderTooltip(el);
  });
  el.addEventListener("focusout", function () {
    if (tooltipTarget === el) hideHeaderTooltip();
  });
});

if (titleTrigger) {
  titleTrigger.addEventListener("mousedown", function (e) {
    if (e.button !== 0) return;
    e.stopPropagation();
  });
  titleTrigger.addEventListener("click", function () {
    var now = Date.now();
    titleTapTimestamps.push(now);
    titleTapTimestamps = titleTapTimestamps.filter(function (ts) {
      return now - ts <= TITLE_TAP_WINDOW_MS;
    });
    if (titleTapTimestamps.length >= 3) {
      titleTapTimestamps = [];
      triggerTitleHop();
    }
  });
}

if (titleHop) {
  titleHop.addEventListener("animationend", function () {
    titleHop.classList.remove("is-hopping");
  });
}

window.addEventListener("resize", updateUiScale);
updateUiScale();
filterHotkeyRows(getSearchValue());
setSettingsOpenState(settingsOpen());
setSettingsTabState(currentSettingsTab());
restoreSettingsScrollState();

remapState.shellEl = document.querySelector("[data-remap-shell]");
remapState.labelEl = document.querySelector("[data-remap-label]");
remapState.currentEl = document.querySelector("[data-remap-current]");
remapState.draftEl = document.querySelector("[data-remap-draft]");
remapState.errorEl = document.querySelector("[data-remap-error]");
remapState.saveEl = document.querySelector("[data-remap-save]");
]=]

return ClientScript
