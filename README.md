# VibeUI

A modern, single-file Roblox UI library — a ground-up rewrite of the abandoned
*Scoot UI Library* by samet. VibeUI keeps the clean dark/cyan aesthetic but
rebuilds the internals around a proper cleanup model, a single global input
dispatcher, a live theme system, and typed, documented components.

> Heads up: VibeUI targets Roblox **script executors** (it uses `writefile`,
> `getcustomasset`, `cloneref`, `gethui`, …). When those globals are missing
> (e.g. plain Studio) it **degrades gracefully** — the UI still works; only
> filesystem features (config save/load, custom font, palette images) disable.

## Try it instantly

Paste this into your executor and run it — a full demo window opens immediately
(press **Right Ctrl** to toggle it):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/RealSlimShady2000/VibeUI/main/demo.luau"))()
```

## Install (build your own UI)

```lua
local VibeUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/RealSlimShady2000/VibeUI/main/VibeUI.luau"))()
```

See [`demo.luau`](demo.luau) / [`examples/usage.luau`](examples/usage.luau) for a full demo you can copy from.

## Quick start

```lua
local Window  = VibeUI:Window({ Title = "VibeUI", Logo = "77218680285262" })
local Tab     = Window:Tab({ Name = "Combat", Columns = 2 })
local Section = Tab:Section({ Name = "Aimbot", Side = 1 })

Section:Toggle({ Name = "Enabled", Flag = "AimbotEnabled", Callback = print })
```

The menu toggles with **Right Ctrl** by default (configurable in Settings).

## API overview

### Library
| Method | Description |
| --- | --- |
| `VibeUI:Window(config)` | Create the main window. Returns a `Window`. |
| `VibeUI:Watermark(text)` | Draggable watermark. `:SetText` / `:SetVisibility`. |
| `VibeUI:KeybindList()` | Active-keybind list (call before creating keybinds). |
| `VibeUI:Notification(...)` | Toast. See **Notifications** below. Returns a handle with `:Close()`. |
| `VibeUI:SetNotificationSide(side)` | `"BottomRight"`/`"BottomLeft"`/`"TopRight"`/`"TopLeft"`. |
| `VibeUI:SetTransparency(alpha)` | Make the whole UI see-through. `0` = opaque … `1` = invisible. Also a Settings slider. |
| `VibeUI:SetOutlines(bool)` | Toggle element border outlines for a flatter look. Also a Theme toggle. |
| `VibeUI:SetScale(n)` | Global UI scale, `0.5`–`2`. Also a Settings slider. |
| `VibeUI:InventoryViewer()` | Draggable inventory panel: `:SetPlayer/:SetHealth/:SetDistance/:AddTool(name,img?)/:RemoveAll/:SetVisibility`. |
| `VibeUI:UserProfile(opts)` | Discord-style profile card (avatar + name + subtitle). `opts`: `DisplayName/Username/Status/Image/Position`. Methods: `:SetDisplayName/:SetUsername/:SetStatus/:SetAvatar/:SetVisibility`. Auto-fills from the local player. |
| `VibeUI:Loader(opts)` | Loading screen. See **Overlays** below. |
| `VibeUI:MessageBox(opts)` | Modal message box with buttons. See **Overlays**. |
| `VibeUI:KeySystem(opts)` | Key gate with a `Validate` hook for auth/whitelisting. See **Overlays**. |
| `VibeUI:CreateSettingsPage(window, watermark?, keybindList?)` | Adds a Theming/Configs/Interface tab. |
| `VibeUI:GetConfig()` / `:LoadConfig(json)` | Serialize / apply all flags. |
| `VibeUI:ListConfigs()` / `:SaveConfig(name)` / `:DeleteConfig(name)` / `:ReadConfig(name)` | Config files (no-ops without a filesystem). |
| `VibeUI:Unload()` | Tear everything down and disconnect all events. |
| `VibeUI.Flags` | `flag -> value` table, live. |

`WindowConfig`: `Title`, `Logo` (rbxassetid string, no prefix), `Size` (UDim2),
`FadeTime`, `Resizable`, `Keybind`, `Layout` (`"Side"` default sidebar, or
`"Top"` for a horizontal tab bar above full-width content).

Every window has a **title bar** with **minimize** (collapses to the bar) and
**maximize** (fills the screen) buttons — also `window:SetMinimized(b)` /
`window:SetMaximized(b)`. The window is draggable by the title bar and by the
empty area of the sidebar / top bar. Switch layout live with
`window:SetLayout("Side" | "Top")` (also a Settings toggle).

Notifications are customizable: `Config.NotificationDuration` (default seconds,
Settings slider), `Config.NotificationSound` (asset id, Settings toggle), and
per-call `{ Duration =, Sound =, Volume = }`.

### Window → Tab → Section
```lua
local tab     = Window:Tab({ Name = "Combat", Columns = 2 })
local section = tab:Section({ Name = "Aimbot", Side = 1 }) -- Side = column index
```

### Elements (all on `Section`)
| Element | Signature | Returns / notes |
| --- | --- | --- |
| Toggle | `:Toggle({Name, Flag, Default, Tooltip, Info, InfoType, Callback})` | `:Set/:Get/:SetText/:SetVisibility`; `:AddColorpicker{}`, `:AddKeybind{}`, `:AddInfo(text, kind)` |
| Button | `:Button()` then `btn:Add(name, cb)` | multi-button row |
| Slider | `:Slider({Name, Flag, Min, Max, Default, Decimals, Suffix, Callback})` | `:Set/:Get` |
| Dropdown | `:Dropdown({Name, Flag, Items, Default, Multi, Search, Callback})` | `:Set/:Get/:Add/:Remove/:Refresh` |
| Searchbox | `:Searchbox({...})` | Dropdown with `Search = true` |
| Textbox | `:Textbox({Name, Flag, Default, Placeholder, Numeric, Finished, Callback})` | `:Set/:Get` |
| Label | `:Label(name)` | `:SetText`; `:AddColorpicker{}`, `:AddKeybind{}`, `:AddInfo(text, kind)` |
| Paragraph | `:Paragraph({Name, Content})` | wrapping multi-line text |
| Divider | `:Divider()` | horizontal separator |

### Colorpicker
`:AddColorpicker({ Flag, Default = Color3, Alpha = 0..1, Callback(color, alpha) })`
on a Toggle or Label. Full HSV palette + hue + alpha. `:Get()` → `color, alpha`.

### Keybind
`:AddKeybind({ Flag, Default = Enum.KeyCode, Mode = "Toggle"|"Hold"|"Always", Callback(toggled) })`
on a Toggle or Label. Left-click to rebind, right-click for the mode menu.
`:Get()` → `key, mode, toggled`.

## Notifications

A dedicated toast system. Toasts stack in a configurable screen corner
(default bottom-right), show a type-coloured accent stripe + glyph, wrap long
text, run a shrinking progress bar, dismiss on click, and auto-close after
`Duration` seconds. Call it two ways:

```lua
-- positional (quick)
VibeUI:Notification("Saved", "Config written to disk", 4, "success")

-- config table (full control) — returns a handle
local toast = VibeUI:Notification({
    Title       = "Update available",
    Description  = "A new version of the script is out.",
    Type        = "info",      -- "info" | "success" | "warning" | "error"
    Duration    = 6,           -- seconds; use 0 to require manual close
    Icon        = "rbxassetid://...", -- optional, replaces the type glyph
})
toast:Close()  -- dismiss early

VibeUI:SetNotificationSide("TopRight")  -- move the stack
```

## Info markers

Add a small `i` / `!` marker with a hover tooltip for tips and warnings:

```lua
section:Toggle({ Name = "Risky feature", Info = "May get you banned", InfoType = "warning" })
section:Label("Aim settings"):AddInfo("Higher = snappier", "tip")  -- kinds: info | tip | warning | error
```

## Overlays (loader / message box / key system)

```lua
-- Loading screen
local load = VibeUI:Loader({ Title = "VibeUI", Status = "Connecting…", Logo = "77218680285262" })
load:SetProgress(0.4); load:SetStatus("Fetching data…")
load:Finish(0.4) -- fills to 100% then closes  (or load:Close())

-- Message box
VibeUI:MessageBox({
    Title = "Unsaved changes",
    Text  = "Save before closing?",
    Confirm = function() print("save") end,   -- → "Confirm" button
    Cancel  = function() print("discard") end, -- → "Cancel" button
    -- or fully custom: Buttons = { {Text="Yes", Primary=true, Callback=fn}, {Text="No", Callback=fn} }
})

-- Key system (plug in any auth — HTTP whitelist, etc.)
VibeUI:KeySystem({
    Title = "VibeUI",
    Note  = "Enter your key to continue.",
    SaveKey = true,                              -- persists a valid key and auto-retries next launch
    Links = { { Text = "Get Key", Url = "https://your.link/key" } }, -- copies URL to clipboard
    Validate = function(key)                     -- return true to accept; runs your auth/whitelist
        local ok = pcall(function() return game:HttpGet("https://api.you/validate?key=" .. key) end)
        return key == "VIBE-123"                 -- example; do your real check here
    end,
    OnSuccess = function(key) print("unlocked", key) end,
})
```

## Mobile support

VibeUI works on touch devices as well as PC. Buttons, tabs, dropdowns,
sliders, the colorpicker, and window/widget dragging all accept touch input.
On touch devices a **floating, draggable toggle button** appears (tap to
open/close the menu, drag to reposition it) since there's no keyboard for the
menu keybind — disable with `Config.MobileToggle = false`. Sliders and the
colorpicker read the touch event's own position, so they track your finger.

## Theming

`VibeUI:CreateSettingsPage` adds a **Theming** section: a preset dropdown
(`Midnight`, `Crimson`, `Indigo`) plus a colorpicker per theme key. Changes
apply live across the whole UI. Programmatically:

```lua
-- theme keys: Background, Border, Inline, Element, "Hovered Element",
-- "Page Background", Outline, Gradient, Text, "Text Stroke",
-- "Placeholder Text", Accent
```

## Config save/load

Configs persist to `VibeUI/Configs/*.json` (executor filesystem only). The
Settings page wires up create/save/load/delete. Each flag is serialized,
including keybind mode/toggled state and colorpicker color/alpha.

## What changed from Scoot (notable fixes)

- **Popups auto-close each other** — Scoot's "close other popups" branch was
  dead code (ran after the debounce was already set); VibeUI closes them
  correctly via a shared popup registry.
- **Colorpicker alpha is preserved** — Scoot read `Color[4]` *after*
  overwriting `Color`; VibeUI captures alpha first.
- **One global input dispatcher** instead of a new `UserInputService`
  connection per slider/colorpicker/dropdown (Scoot leaked these until unload).
  Everything is owned by a `Maid` and freed on `:Unload()`.
- **Live theme registry**, fixed config-list refresh, fixed slider defaults,
  no deprecated `tick()`, graceful no-filesystem fallback.

## Not yet ported (vs. the original)

These existed in Scoot and are intentionally deferred for a follow-up pass
(they were not needed for the core and add untested surface area):

- Colorpicker **Animations** tab (rainbow / fade / linear) + sync-colorpickers
  + RGB/HEX/HSV readout and copy/paste. (Core HSV+alpha picking is complete.)
- **Sub-tabs** (nested tab bars). VibeUI organizes with Tabs + multi-section
  columns instead; the Settings tab demonstrates the layout.
- **Inventory viewer** widget.

## Tooling / verification

There is **no build step** — `VibeUI.luau` is the artifact. Roblox Luau can't
run outside the engine, so verify by:

1. (optional) `stylua` / `selene` / `luau-analyze` if installed — clean under
   the IDE Luau LSP aside from expected executor-global warnings.
2. Hosting `VibeUI.luau` and running `examples/usage.luau` in an executor:
   toggle elements, open a dropdown then a colorpicker (the first should
   auto-close), recolor via the Theming section, and save/load a config.
