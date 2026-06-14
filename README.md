# VibeUI

A modern, single-file Roblox UI library — a ground-up rewrite of the abandoned
*Scoot UI Library* by samet. VibeUI keeps the clean dark/cyan aesthetic but
rebuilds the internals around a proper cleanup model, a single global input
dispatcher, a live theme system, and typed, documented components.

> Heads up: VibeUI targets Roblox **script executors** (it uses `writefile`,
> `getcustomasset`, `cloneref`, `gethui`, …). When those globals are missing
> (e.g. plain Studio) it **degrades gracefully** — the UI still works; only
> filesystem features (config save/load, custom font, palette images) disable.

## Install

```lua
local VibeUI = loadstring(game:HttpGet("https://your-host/VibeUI.luau"))()
```

See [`examples/usage.luau`](examples/usage.luau) for a full demo.

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
| `VibeUI:Notification(title, desc?, duration?, kind?)` | Toast. `kind`: `"info"`/`"success"`/`"warning"`/`"error"`. |
| `VibeUI:CreateSettingsPage(window, watermark?, keybindList?)` | Adds a Theming/Configs/Interface tab. |
| `VibeUI:GetConfig()` / `:LoadConfig(json)` | Serialize / apply all flags. |
| `VibeUI:ListConfigs()` / `:SaveConfig(name)` / `:DeleteConfig(name)` / `:ReadConfig(name)` | Config files (no-ops without a filesystem). |
| `VibeUI:Unload()` | Tear everything down and disconnect all events. |
| `VibeUI.Flags` | `flag -> value` table, live. |

`WindowConfig`: `Title`, `Logo` (rbxassetid string, no prefix), `Size` (UDim2),
`FadeTime`, `Resizable`, `Keybind`.

### Window → Tab → Section
```lua
local tab     = Window:Tab({ Name = "Combat", Columns = 2 })
local section = tab:Section({ Name = "Aimbot", Side = 1 }) -- Side = column index
```

### Elements (all on `Section`)
| Element | Signature | Returns / notes |
| --- | --- | --- |
| Toggle | `:Toggle({Name, Flag, Default, Tooltip, Callback})` | `:Set/:Get/:SetText/:SetVisibility`; `:AddColorpicker{}`, `:AddKeybind{}` |
| Button | `:Button()` then `btn:Add(name, cb)` | multi-button row |
| Slider | `:Slider({Name, Flag, Min, Max, Default, Decimals, Suffix, Callback})` | `:Set/:Get` |
| Dropdown | `:Dropdown({Name, Flag, Items, Default, Multi, Search, Callback})` | `:Set/:Get/:Add/:Remove/:Refresh` |
| Searchbox | `:Searchbox({...})` | Dropdown with `Search = true` |
| Textbox | `:Textbox({Name, Flag, Default, Placeholder, Numeric, Finished, Callback})` | `:Set/:Get` |
| Label | `:Label(name)` | `:SetText`; `:AddColorpicker{}`, `:AddKeybind{}` |
| Paragraph | `:Paragraph({Name, Content})` | wrapping multi-line text |
| Divider | `:Divider()` | horizontal separator |

### Colorpicker
`:AddColorpicker({ Flag, Default = Color3, Alpha = 0..1, Callback(color, alpha) })`
on a Toggle or Label. Full HSV palette + hue + alpha. `:Get()` → `color, alpha`.

### Keybind
`:AddKeybind({ Flag, Default = Enum.KeyCode, Mode = "Toggle"|"Hold"|"Always", Callback(toggled) })`
on a Toggle or Label. Left-click to rebind, right-click for the mode menu.
`:Get()` → `key, mode, toggled`.

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
