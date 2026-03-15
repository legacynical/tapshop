local ClientScript = {}

ClientScript.script = [=[
function sendAction(action, slot, dx, dy, dw, dh, direction) {
  window.webkit.messageHandlers.tapshop.postMessage({
    action: action,
    slot: slot || 0,
    dx: dx || 0,
    dy: dy || 0,
    dw: dw || 0,
    dh: dh || 0,
    direction: direction || "",
  });
}

var MIN_UI_SCALE = 0.5;
var MAX_UI_SCALE = 1.5;
var RESIZE_ZONE = 10;

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
  if (!container || !header || !workspaceList) return 0;

  setUiScale(scale);
  void container.offsetHeight;

  var containerStyle = window.getComputedStyle(container);
  var gap = readPx(containerStyle.rowGap || containerStyle.gap);

  return header.getBoundingClientRect().height
    + workspaceList.getBoundingClientRect().height
    + gap
    + readPx(containerStyle.paddingTop)
    + readPx(containerStyle.paddingBottom)
    + readPx(containerStyle.borderTopWidth)
    + readPx(containerStyle.borderBottomWidth);
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
var headerActions = document.querySelector(".header-actions");
var headerTooltip = document.querySelector(".header-tooltip");
var tooltipTarget = null;

function hideHeaderTooltip() {
  tooltipTarget = null;
  if (!headerTooltip) return;
  headerTooltip.classList.remove("is-visible");
  headerTooltip.textContent = "";
}

function showHeaderTooltip(el) {
  if (!container || !headerActions || !headerTooltip || !el) return;
  if (dragState.active || resizeState.active) return;
  if (configMenu && configMenu.hasAttribute("open") && el.closest(".config-menu")) {
    hideHeaderTooltip();
    return;
  }

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
  var topBase = headerRect
    ? ((headerRect.bottom - containerRect.top) + 4)
    : (readPx(style.paddingTop) + 28);

  headerTooltip.style.left = left + "px";
  headerTooltip.style.top = topBase + "px";
}

var dragState = {
  active: false,
  lastX: 0,
  lastY: 0,
};

var resizeState = {
  active: false,
  lastX: 0,
  lastY: 0,
  direction: "",
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
  sendAction("resizeStart", 0, 0, 0, 0, 0, direction);
  e.preventDefault();
  e.stopPropagation();
}, true);

var header = document.querySelector(".header");
if (header) {
  header.addEventListener("mousedown", function (e) {
    if (e.button !== 0) return;
    if (
      e.target
      && e.target.closest
      && e.target.closest(".config-menu, .header-actions, button, input, label, summary")
    ) return;
    dragState.active = true;
    dragState.lastX = e.screenX;
    dragState.lastY = e.screenY;
    hideHeaderTooltip();
    sendAction("dragStart");
    e.preventDefault();
  });
}

window.addEventListener("mousemove", function (e) {
  if (!dragState.active) return;

  var dx = e.screenX - dragState.lastX;
  var dy = e.screenY - dragState.lastY;
  dragState.lastX = e.screenX;
  dragState.lastY = e.screenY;

  if (dx !== 0 || dy !== 0) {
    sendAction("dragMove", 0, dx, dy);
  }
});

window.addEventListener("mouseup", function () {
  if (!dragState.active) return;
  dragState.active = false;
  sendAction("dragEnd");
});

window.addEventListener("mousemove", function (e) {
  if (!resizeState.active) return;

  var dw = e.screenX - resizeState.lastX;
  var dh = e.screenY - resizeState.lastY;
  resizeState.lastX = e.screenX;
  resizeState.lastY = e.screenY;

  if (dw !== 0 || dh !== 0) {
    sendAction("resizeMove", 0, 0, 0, dw, dh, resizeState.direction);
  }
});

window.addEventListener("mouseup", function () {
  if (!resizeState.active) return;
  resizeState.active = false;
  resizeState.direction = "";
  setGlobalCursor("");
  sendAction("resizeEnd");
});

document.addEventListener("mousemove", function (e) {
  if (dragState.active || resizeState.active) return;
  setGlobalCursor(cursorForDirection(getResizeDirection(e)));
});

document.addEventListener("mouseleave", function () {
  if (dragState.active || resizeState.active) return;
  setGlobalCursor("");
});

window.addEventListener("resize", updateUiScale);
updateUiScale();

document.addEventListener("keydown", function (e) {
  if (e.key === "Escape") sendAction("close");
});

var configMenu = document.querySelector(".config-menu");
var tooltipControls = document.querySelectorAll("[data-tooltip]");
document.addEventListener("mousedown", function (e) {
  hideHeaderTooltip();
  if (!configMenu || !configMenu.hasAttribute("open")) return;
  if (e.target && e.target.closest && e.target.closest(".config-menu")) return;
  configMenu.removeAttribute("open");
});

tooltipControls.forEach(function (el) {
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
  el.addEventListener("mousedown", function () {
    hideHeaderTooltip();
  });
});

if (configMenu) {
  configMenu.addEventListener("toggle", function () {
    hideHeaderTooltip();
  });
}
]=]

return ClientScript
