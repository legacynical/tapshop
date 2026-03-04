<pre>
████████╗ █████╗ ██████╗ ███████╗██╗  ██╗ ██████╗ ██████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██║  ██║██╔═══██╗██╔══██╗
   ██║   ███████║██████╔╝███████╗███████║██║   ██║██████╔╝
   ██║   ██╔══██║██╔═══╝ ╚════██║██╔══██║██║   ██║██╔═══╝ 
   ██║   ██║  ██║██║     ███████║██║  ██║╚██████╔╝██║     
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝
</pre>

**Targeted Application Pairing System w/ Hotkey Oriented Playback**

> _It's not that the few extra seconds I save from not having to move my mouse and click back and forth will increase my productivity, it's the satifaction of not having to deal with
> that and preventing occassional misfocused window mishaps that will get me to want to use
> it more and work longer._

---

## Windows — AutoHotkey v2

### Running with AHK Installation

1. Install [AutoHotkey v2.0](https://www.autohotkey.com/)
2. Run the `TAPSHOP.ahk` script

### Running without AHK Installation

1. Download [latest GYTP release](https://github.com/legacynical/global-yt-playback/releases)
2. Run the `GYTP.exe` (right-click in system tray for AHK related settings/options, `` Ctrl + Win + ` `` for GUI)

> [!TIP]
> - Place script ahk/exe (or shortcut) in `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup` to autorun on startup.
> - Applications running at admin level will ignore script functions, which can be fixed by also running the script ahk/exe as admin.

> [!WARNING]
> - Setting the run as admin flag on with the script in the Startup folder (as shown below) will NOT autorun the script on startup. 
> - To allow this script to autorun at admin level on startup, use the native Windows Task Scheduler to bypass the UAC prompt requirement needed for script execution permission.

![image](https://github.com/user-attachments/assets/1d315525-54f0-4e9f-aa7c-cfecb1c60ed7)

---

## macOS — Hammerspoon

### Setup

1. Install [Hammerspoon](https://www.hammerspoon.org/)
2. Copy or symlink `TAPSHOP.lua` into your `~/.hammerspoon/` directory
3. Add `require("TAPSHOP")` to your `~/.hammerspoon/init.lua`
4. Reload Hammerspoon config (⌘ + ⇧ + R from menu bar, or `hs.reload()`)

---

## Controls

> [!TIP]
> Change hotkeys in code if you don't have media keys or want to use different ones.<br>
> **Windows:** Refer to AHK's [Hotkeys](https://www.autohotkey.com/docs/v1/Hotkeys.htm) & [List of Keys](https://www.autohotkey.com/docs/v1/KeyList.htm) documentation for modifiers & keycodes.<br>
> **macOS:** Refer to Hammerspoon's [hs.hotkey](https://www.hammerspoon.org/docs/hs.hotkey.html) documentation.

<pre>
        Media_Prev = YT rewind 5 sec
 Ctrl + Media_Prev = YT rewind 10 sec
  Media_Play_Pause = YT toggle play/pause
        Media_Next = YT fast forward 5 sec
 Ctrl + Media_Next = YT fast forward 10 sec
           Win + ` = display active window stats
       Win + [1-9] = pair active as window [1-9]
Ctrl + Win + [1-9] = unpair window [1-9]
    Ctrl + Win + 0 = unpair all windows
    Ctrl + Win + ` = open GUI (hint: ` is same key as ~)
</pre>

![image](https://github.com/user-attachments/assets/74b8b738-bf9c-4cf7-aa7a-0f064c5dd7ea)

---

## Legacy Versions

The original single-purpose scripts are preserved in their respective folders:

| Folder | Description |
|---|---|
| `GYTP-AHKv2-media-keys` | AHK v2 — media key hotkeys (original) |
| `GYTP-AHKv2-keyboard-75` | AHK v2 — QMK 75% keyboard variant ([details](../GYTP-AHKv2-keyboard-75/README.md)) |
| `GYTP-AHKv1.1-deprecated` | AHK v1.1 — deprecated |

---

## License

While this project's scripts are provided under the MIT license, please note that the AHK interpreter is under the [GPL-2.0 license](https://github.com/AutoHotkey/AutoHotkey?tab=GPL-2.0-1-ov-file). This applies to compiled builds (.exe) as it packages both the AHK script and the AHK interpreter. For most users or developers, this shouldn't be of concern as the GPL-2.0 license itself is also quite permissive.
