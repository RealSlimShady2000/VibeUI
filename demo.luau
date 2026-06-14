--!nonstrict
--[[
	VibeUI — instant demo

	Run directly from GitHub:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/RealSlimShady2000/VibeUI/main/demo.luau"))()

	Opens a fully-populated window showcasing every component.
	Press Right Ctrl to toggle the menu.
]]

local VibeUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/RealSlimShady2000/VibeUI/main/VibeUI.luau"))()

local Window = VibeUI:Window({
	Title   = "VibeUI",
	Logo    = "77218680285262",
	Size    = UDim2.fromOffset(720, 520),
	Keybind = Enum.KeyCode.RightControl,
})

local Watermark   = VibeUI:Watermark("VibeUI  •  " .. game:GetService("Players").LocalPlayer.Name)
local KeybindList = VibeUI:KeybindList()

--========================================================================= Combat
local Combat = Window:Tab({ Name = "Combat", Columns = 2 })

local Aimbot = Combat:Section({ Name = "Aimbot", Side = 1 })
Aimbot:Toggle({
	Name = "Enabled", Flag = "AimbotEnabled", Tooltip = "Master aimbot toggle",
	Callback = function(v) print("Aimbot:", v) end,
}):AddKeybind({ Flag = "AimbotKey", Default = Enum.KeyCode.E, Mode = "Hold" })

Aimbot:Slider({ Name = "FOV Radius", Flag = "AimbotFov", Min = 1, Max = 500, Default = 120, Suffix = "px" })
Aimbot:Dropdown({ Name = "Target Part", Flag = "AimbotPart",
	Items = { "Head", "Torso", "HumanoidRootPart" }, Default = "Head" })
Aimbot:Label("FOV Color"):AddColorpicker({
	Flag = "AimbotFovColor", Default = Color3.fromRGB(202, 243, 255), Alpha = 0.5 })

local Misc = Combat:Section({ Name = "Misc", Side = 2 })
Misc:Toggle({ Name = "Wall check", Flag = "WallCheck", Default = true })
Misc:Toggle({ Name = "Team check", Flag = "TeamCheck", Default = true })
Misc:Dropdown({ Name = "Hitboxes", Flag = "Hitboxes", Multi = true,
	Items = { "Head", "Torso", "Legs", "Arms" }, Default = { "Head", "Torso" } })
Misc:Divider()
Misc:Searchbox({ Name = "Weapon", Flag = "Weapon",
	Items = { "AK-47", "M4A1", "Glock", "Deagle", "AWP", "Knife", "Grenade" } })

--======================================================================== Visuals
local Visuals = Window:Tab({ Name = "Visuals", Columns = 2 })

local ESP = Visuals:Section({ Name = "ESP", Side = 1 })
ESP:Toggle({ Name = "Boxes", Flag = "EspBoxes" })
ESP:Toggle({ Name = "Names", Flag = "EspNames" })
ESP:Toggle({ Name = "Tracers", Flag = "EspTracers" })
	:AddColorpicker({ Flag = "TracerColor", Default = Color3.fromRGB(255, 80, 80) })

local World = Visuals:Section({ Name = "World", Side = 2 })
World:Slider({ Name = "Brightness", Flag = "Brightness", Min = 0, Max = 5, Default = 1, Decimals = 0.1 })
World:Textbox({ Name = "Time of day", Flag = "TimeOfDay", Placeholder = "14:30", Finished = true })
World:Paragraph({ Name = "Note", Content =
	"Paragraph elements wrap long text across multiple lines — great for descriptions, warnings or credits." })
World:Button():Add("Reset world", function() print("reset") end)

--======================================================================= Settings
VibeUI:CreateSettingsPage(Window, Watermark, KeybindList)

VibeUI:Notification("VibeUI", ("Loaded in %.3fs — press Right Ctrl to toggle"):format(VibeUI.LoadTime), 6, "success")
