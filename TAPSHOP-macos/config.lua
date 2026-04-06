local settingsStore = require("settings_store")

local Config = {}

Config.keys = {
  hotkeyOverrides = "tapshop.hotkeys.overrides",
  popoverAutoHideAfterAction = "tapshop.popover.autoHideAfterAction",
  popoverAlwaysOnTop = "tapshop.popover.alwaysOnTop",
  popoverHidePairButtons = "tapshop.popover.hidePairButtons",
  recoverClosedWindows = "tapshop.workspace.recoverClosedWindows",
  popoverBackgroundOpacity = "tapshop.popover.backgroundOpacity",
  popoverTopLeft = "tapshop.popover.topLeft",
  popoverMainSize = "tapshop.popover.mainSize",
  settingsTopLeft = "tapshop.settings.topLeft",
  settingsSize = "tapshop.settings.size",
  popoverSettingsSize = "tapshop.popover.settingsSize",
  popoverSize = "tapshop.popover.size",
  workspacePairings = "tapshop.workspace.pairings",
}

local DEFAULTS = {
  inputDelay = 0.05,
  minimizeThreshold = 2,
  focusWaitTimeout = 0.22,
  focusPollMicros = 10000,
  youtubeDirectDispatch = true,
  popoverAutoHideAfterAction = false,
  popoverAlwaysOnTop = true,
  popoverHidePairButtons = false,
  recoverClosedWindows = true,
  popoverBackgroundOpacity = 0.85,
  tapshopMsgBottomMargin = 100,
  tapshopMsgWidth = 760,
  tapshopMsgTextSize = 14,
  tapshopMsgMaxLines = 25,
  browserBundleIDs = {
    ["com.apple.Safari"] = true,
    ["com.google.Chrome"] = true,
    ["org.chromium.Chromium"] = true,
    ["com.brave.Browser"] = true,
    ["com.operasoftware.Opera"] = true,
    ["com.operasoftware.OperaGX"] = true,
    ["com.vivaldi.Vivaldi"] = true,
    ["org.mozilla.firefox"] = true,
    ["com.microsoft.edgemac"] = true,
    ["ru.yandex.desktop.yandex-browser"] = true,
    ["org.waterfoxproject.waterfox"] = true,
    ["org.torproject.torbrowser"] = true,
    ["com.maxthon.browser"] = true,
    ["com.maxthon.Maxthon"] = true,
    ["org.mozilla.seamonkey"] = true,
    ["com.hiddenreflex.epic"] = true,
    ["com.hiddenreflex.epicbrowser"] = true,
    ["com.flashpeak.Slimjet"] = true,
    ["com.comodo.dragon"] = true,
    ["com.avast.browser"] = true,
    ["com.srware.iron"] = true,
    ["org.kde.falkon"] = true,
    ["company.thebrowser.Browser"] = true,
    ["company.thebrowser.dia"] = true,
    ["ai.perplexity.comet"] = true,
    ["io.gitlab.librewolf-community.librewolf"] = true,
    ["one.ablaze.floorp"] = true,
  },
}

function Config.load()
  local cfg = {}
  for key, value in pairs(DEFAULTS) do
    cfg[key] = value
  end

  cfg.popoverAutoHideAfterAction = settingsStore.getBoolean(
    Config.keys.popoverAutoHideAfterAction,
    DEFAULTS.popoverAutoHideAfterAction
  )
  cfg.popoverAlwaysOnTop = settingsStore.getBoolean(
    Config.keys.popoverAlwaysOnTop,
    DEFAULTS.popoverAlwaysOnTop
  )
  cfg.popoverHidePairButtons = settingsStore.getBoolean(
    Config.keys.popoverHidePairButtons,
    DEFAULTS.popoverHidePairButtons
  )
  cfg.recoverClosedWindows = settingsStore.getBoolean(
    Config.keys.recoverClosedWindows,
    DEFAULTS.recoverClosedWindows
  )
  cfg.popoverBackgroundOpacity = settingsStore.getOpacity(
    Config.keys.popoverBackgroundOpacity,
    DEFAULTS.popoverBackgroundOpacity
  )
  return cfg
end

return Config
