--!nonstrict
--[[
	VibeUI — usage / demo

	In an executor you would normally load the library straight from a URL:

		local VibeUI = loadstring(game:HttpGet("https://your-host/VibeUI.luau"))()

	For local testing, point this at your hosted copy, or paste VibeUI.luau
	above this script in the same execution.
]]

local VibeUI = loadstring(game:HttpGet("https://your-host/VibeUI.luau"))()

--==============================================================================
-- Window + global UI
--==============================================================================

local Window = VibeUI:Window({
	Title    = "VibeUI",
	Logo     = "77218680285262",   -- optional rbxassetid (no prefix)
	Size     = UDim2.fromOffset(720, 520),
	FadeTime = 0.3,
	Keybind  = Enum.KeyCode.RightControl,
})

local Watermark   = VibeUI:Watermark("VibeUI | " .. game:GetService("Players").LocalPlayer.Name)
local KeybindList = VibeUI:KeybindList()

--==============================================================================
-- Combat tab
--==============================================================================

local Combat = Window:Tab({ Name = "Combat", Columns = 2 })

local Aimbot = Combat:Section({ Name = "Aimbot", Side = 1 })

Aimbot:Toggle({
	Name = "Enabled",
	Flag = "AimbotEnabled",
	Default = false,
	Tooltip = "Master toggle for the aimbot",
	Callback = function(value) print("Aimbot:", value) end,
}):AddKeybind({
	Flag = "AimbotKey",
	Default = Enum.KeyCode.E,
	Mode = "Hold",
})

Aimbot:Slider({
	Name = "FOV Radius",
	Flag = "AimbotFov",
	Min = 1, Max = 500, Default = 120, Decimals = 1, Suffix = "px",
	Callback = function(v) print("FOV:", v) end,
})

Aimbot:Dropdown({
	Name = "Target Part",
	Flag = "AimbotPart",
	Items = { "Head", "Torso", "HumanoidRootPart" },
	Default = "Head",
	Callback = function(v) print("Part:", v) end,
})

Aimbot:Label("FOV Color"):AddColorpicker({
	Flag = "AimbotFovColor",
	Default = Color3.fromRGB(202, 243, 255),
	Alpha = 0.5,
	Callback = function(color, alpha) print("Color:", color, alpha) end,
})

local Misc = Combat:Section({ Name = "Misc", Side = 2 })

Misc:Toggle({ Name = "Wall check",  Flag = "WallCheck",  Default = true })
Misc:Toggle({ Name = "Team check",  Flag = "TeamCheck",  Default = true })
Misc:Dropdown({
	Name = "Hitboxes",
	Flag = "Hitboxes",
	Multi = true,
	Items = { "Head", "Torso", "Legs", "Arms" },
	Default = { "Head", "Torso" },
})
Misc:Divider()
Misc:Searchbox({
	Name = "Weapon",
	Flag = "Weapon",
	Items = { "AK-47", "M4A1", "Glock", "Deagle", "AWP", "Knife", "Grenade" },
	Callback = function(v) print("Weapon:", v) end,
})

--==============================================================================
-- Visuals tab
--==============================================================================

local Visuals = Window:Tab({ Name = "Visuals", Columns = 2 })

local ESP = Visuals:Section({ Name = "ESP", Side = 1 })
ESP:Toggle({ Name = "Boxes", Flag = "EspBoxes" })
ESP:Toggle({ Name = "Names", Flag = "EspNames" })
ESP:Toggle({ Name = "Tracers", Flag = "EspTracers" })
	:AddColorpicker({ Flag = "TracerColor", Default = Color3.fromRGB(255, 80, 80) })

local World = Visuals:Section({ Name = "World", Side = 2 })
World:Slider({ Name = "Brightness", Flag = "Brightness", Min = 0, Max = 5, Default = 1, Decimals = 0.1 })
World:Textbox({ Name = "Time of day", Flag = "TimeOfDay", Placeholder = "14:30", Finished = true,
	Callback = function(v) print("Time:", v) end })
World:Paragraph({ Name = "Note", Content = "Paragraph elements wrap long text across multiple lines and are great for descriptions or warnings." })

--==============================================================================
-- Settings (theming / configs / interface) — provided by the library
--==============================================================================

VibeUI:CreateSettingsPage(Window, Watermark, KeybindList)

VibeUI:Notification("Loaded", ("VibeUI loaded in %.3fs"):format(VibeUI.LoadTime), 5, "success")
