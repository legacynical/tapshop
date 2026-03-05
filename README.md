<pre>
████████╗ █████╗ ██████╗ ███████╗██╗  ██╗ ██████╗ ██████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██║  ██║██╔═══██╗██╔══██╗
   ██║   ███████║██████╔╝███████╗███████║██║   ██║██████╔╝
   ██║   ██╔══██║██╔═══╝ ╚════██║██╔══██║██║   ██║██╔═══╝ 
   ██║   ██║  ██║██║     ███████║██║  ██║╚██████╔╝██║     
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝
</pre>

**Targeted Application Pairing System w/ Hotkey Oriented Playback**

> _Taps on your keyboard converted to efficient window hopping._

---

## What It Does

1. Window pairing slots (`1`-`9`) so one hotkey can jump back to a specific app window.
2. Context-aware pair/focus/minimize flow:
   - First press pairs current window to slot.
   - Later press on same slot focuses paired window.
   - Double-tap while already focused to minimize (configurable).
3. Global media-style controls:
   - YouTube seek/play targeting browser tabs by window title.
   - Spotify transport/seek/volume controls.
---

## Windows — AutoHotkey v2

### Running with AHK Installation

1. Install [AutoHotkey v2.0](https://www.autohotkey.com/)
2. Run `TAPSHOP/TAPSHOP.ahk`

### Running without AHK Installation

This repository ships source scripts. If you want a standalone `.exe`, compile `TAPSHOP/TAPSHOP.ahk` with AutoHotkey v2's compiler (`Ahk2Exe`).

> [!TIP]
> - Place script ahk/exe (or shortcut) in `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup` to autorun on startup.
> - Applications running at admin level will ignore script functions, which can be fixed by also running the script ahk/exe as admin.

> [!WARNING]
> - Setting the run as admin flag on with the script in the Startup folder (as shown below) will NOT autorun the script on startup. 
> - To allow this script to autorun at admin level on startup, use the native Windows Task Scheduler to bypass the UAC prompt requirement needed for script execution permission.

![image](https://github.com/user-attachments/assets/1d315525-54f0-4e9f-aa7c-cfecb1c60ed7)

### Hotkey Bindings (Windows)
> **Windows:** Refer to AHK's [Hotkeys](https://www.autohotkey.com/docs/v2/Hotkeys.htm) & [List of Keys](https://www.autohotkey.com/docs/v2/KeyList.htm) documentation for modifiers & keycodes.

| Hotkey | Action |
|---|---|
| `Win + [1-9]` | Pair/focus/minimize slot `[1-9]` |
| `Ctrl + Win + [1-9]` | Unpair slot `[1-9]` |
| `Ctrl + Win + 0` | Unpair all slots |
| `Win + \`` | Show active window stats |
| `Ctrl + Win + \`` | Toggle TAPSHOP GUI |
| `F19` / `Ctrl + F19` | YouTube rewind `5s` / `10s` |
| `F20` | YouTube play/pause |
| `F21` / `Ctrl + F21` | YouTube forward `5s` / `10s` |
| `Media_Prev` / `Media_Play_Pause` / `Media_Next` | Spotify previous/play-pause/next |
| `Ctrl + Media_Prev` / `Ctrl + Media_Next` | Spotify seek backward/forward |
| `F22` | Spotify like/unlike |
| `F23` / `F24` | Spotify volume down/up |
| `Ctrl + F22` / `Ctrl + F23` / `Ctrl + F24` | System mute / volume down / volume up |

![image](https://github.com/user-attachments/assets/74b8b738-bf9c-4cf7-aa7a-0f064c5dd7ea)

---

## macOS — Hammerspoon

### Setup

1. Install [Hammerspoon](https://www.hammerspoon.org/)
2. Copy or symlink `TAPSHOP/TAPSHOP.lua` into your `~/.hammerspoon/` directory
3. Add `require("TAPSHOP")` to your `~/.hammerspoon/init.lua`
4. Reload Hammerspoon config (⌘ + ⇧ + R from menu bar, or `hs.reload()`)

### Required Permissions (macOS)

1. Grant Hammerspoon Accessibility access in `System Settings -> Privacy & Security -> Accessibility`.
2. If prompted during Spotify actions, allow Apple Events/Automation permissions for Hammerspoon.


### Hotkey Bindings (macOS)

> **macOS:** Refer to Hammerspoon's [hs.hotkey](https://www.hammerspoon.org/docs/hs.hotkey.html) documentation.

### macOS (`TAPSHOP/TAPSHOP.lua`)

| Hotkey | Action |
|---|---|
| `Cmd + Option + [1-9]` | Pair/focus/minimize slot `[1-9]` |
| `Cmd + Option + Shift + [1-9]` | Unpair slot `[1-9]` |
| `Cmd + Option + Shift + 0` | Unpair all slots |
| `Cmd + Option + \`` | Toggle popover UI |
| `Cmd + Option + Left/J` | YouTube rewind `5s` / `10s` |
| `Cmd + Option + Right/L` | YouTube forward `5s` / `10s` |
| `Cmd + Option + K` | YouTube play/pause |
| `F19/F20/F21` (+ Ctrl variants) | Optional YouTube bindings (if key exists) |
| `F7/F8/F9` (+ Ctrl variants) | Optional Spotify media + seek bindings |
| `F22/F23/F24` | Optional Spotify like + volume bindings |
| `Cmd + Option + Ctrl + ,/. / M` | System volume down/up/mute |

<img width="499" height="408" alt="image" src="https://github.com/user-attachments/assets/b3109e53-944b-4f34-86e2-47e50035dbd0" />
---

## Behavior Notes

- YouTube targeting is title-based and browser-filtered. Expected title pattern includes ` - YouTube`; `Subscriptions - YouTube` is intentionally ignored.
- Slot minimize behavior is threshold-based (`minimizeThreshold`), not immediate on first repeat press.
- On Windows, Spotify transport is sent using `WM_APPCOMMAND`; on macOS it uses Hammerspoon Spotify APIs + AppleScript helpers.

---

## Troubleshooting

- YouTube commands do nothing:
  - Ensure a supported browser window title currently matches a YouTube watch page.
  - Open a video tab once to refresh target detection.
- Pairing hotkeys do nothing on Windows:
  - Check if target app is elevated (run TAPSHOP as admin too).
- macOS hotkeys not firing:
  - Confirm Hammerspoon Accessibility permission is enabled.
  - Some optional F-key bindings are only registered if that key exists in `hs.keycodes.map`.
- Spotify actions fail on macOS:
  - Open Spotify at least once and allow Automation prompts for Hammerspoon.

---

## Repository Layout

| Path | Purpose |
|---|---|
| `TAPSHOP/TAPSHOP.ahk` | Main Windows implementation (AHK v2) |
| `TAPSHOP/TAPSHOP.lua` | Main macOS implementation (Hammerspoon) |
| `GYTP-AHKv2-media-keys` | Legacy media-key-focused script |
| `GYTP-AHKv2-keyboard-75` | Legacy 75% keyboard variant |
| `GYTP-AHKv1.1-deprecated` | Legacy AHK v1.1 script |

---

## Legacy Versions

The original single-purpose scripts are preserved in their respective folders:

| Folder | Description |
|---|---|
| `GYTP-AHKv2-media-keys` | AHK v2 — media key hotkeys (original) |
| `GYTP-AHKv2-keyboard-75` | AHK v2 — QMK 75% keyboard variant ([details](./GYTP-AHKv2-keyboard-75/README.md)) |
| `GYTP-AHKv1.1-deprecated` | AHK v1.1 — deprecated |

---

## License

This project's scripts are provided under the MIT license.

**Windows (AHK):** The AutoHotkey interpreter is under the [GPL-2.0 license](https://github.com/AutoHotkey/AutoHotkey?tab=GPL-2.0-1-ov-file). This applies to compiled builds (`.exe`) because they bundle the AHK script and interpreter. For most users or developers this is not a practical concern, as GPL-2.0 is permissive.

**macOS (Hammerspoon/Lua):** The macOS stack relies on [Hammerspoon](https://www.hammerspoon.org/) (MIT) and [Lua](https://www.lua.org/) (MIT). If you distribute software that includes or depends on them, you must retain their copyright notices and the full MIT license text for each. Hammerspoon’s license is in its [repository](https://github.com/Hammerspoon/hammerspoon); Lua’s license is at [lua.org/license.html](https://www.lua.org/license.html).
