--!nonstrict
--[[
	VibeUI — instant demo

	Run directly from GitHub:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/RealSlimShady2000/VibeUI/main/demo.luau"))()

	Opens a fully-populated window showcasing every component.
	Press Right Ctrl to toggle the menu.
]]

-- cache-bust the library fetch so the demo always pulls the latest VibeUI
local VibeUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/RealSlimShady2000/VibeUI/main/VibeUI.luau?v=" .. tostring(tick())))()

local Window = VibeUI:Window({
	Title   = "VibeUI",
	Logo    = "77218680285262",
	Size    = UDim2.fromOffset(720, 520),
	Keybind = Enum.KeyCode.RightControl,
	Layout  = "Side", -- try "Top" for a horizontal tab bar; minimize/maximize live in the title bar
})

local Watermark   = VibeUI:Watermark("VibeUI  •  " .. game:GetService("Players").LocalPlayer.Name)
local KeybindList = VibeUI:KeybindList()
-- Discord-style profile card (auto-fills from the local player; all fields optional)
local Profile     = VibeUI:UserProfile({ Status = "Vibing" })
-- scrolling news ticker across the top of the screen
local Ticker      = VibeUI:Ticker({
	Tag = "NEWS", Side = "Top", Speed = 80,
	Messages = {
		"Welcome to VibeUI!",
		"Now with a news ticker, scrollable dropdowns & a Discord-style profile.",
		"Drag the floating button on mobile to open the menu.",
		"github.com/RealSlimShady2000/VibeUI",
	},
})

--========================================================================= Combat
local Combat = Window:Tab({ Name = "Combat", Columns = 2 })

local Aimbot = Combat:Section({ Name = "Aimbot", Side = 1 })
Aimbot:Toggle({
	Name = "Enabled", Flag = "AimbotEnabled", Info = "Master aimbot toggle", InfoType = "tip",
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

-- optional inventory browser, toggled from here
local Inventory = VibeUI:InventoryViewer()
Inventory:SetPlayer(game:GetService("Players").LocalPlayer)
Inventory:SetHealth(100)
Inventory:SetDistance(0)
Inventory:AddTool("Sword")
Inventory:AddTool("Potion")
Inventory:SetVisibility(false)
Misc:Toggle({ Name = "Inventory browser", Flag = "ShowInventory", Default = false,
	Callback = function(v) Inventory:SetVisibility(v) end })
Misc:Toggle({ Name = "Risky feature", Flag = "Risky", Info = "May get you banned", InfoType = "warning" })
Misc:Button():Add("Message box", function()
	VibeUI:MessageBox({ Title = "Confirm", Text = "Run this risky action?",
		Confirm = function() VibeUI:Notification({ Title = "Done", Type = "success", Duration = 3 }) end,
		Cancel = function() end })
end)
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

-- Toast notifications: one button per type
local Notifs = Visuals:Section({ Name = "Notifications", Side = 1 })
local row1 = Notifs:Button()
row1:Add("Info", function()
	VibeUI:Notification({ Title = "Info", Description = "Just so you know.", Type = "info", Duration = 4 })
end)
row1:Add("Success", function()
	VibeUI:Notification({ Title = "Success", Description = "Operation completed.", Type = "success", Duration = 4 })
end)
local row2 = Notifs:Button()
row2:Add("Warning", function()
	VibeUI:Notification({ Title = "Warning", Description = "Something needs attention.", Type = "warning", Duration = 4 })
end)
row2:Add("Error", function()
	VibeUI:Notification({ Title = "Error", Description = "That did not work — try again.", Type = "error", Duration = 5 })
end)

--======================================================================= Settings
VibeUI:CreateSettingsPage(Window, Watermark, KeybindList)

VibeUI:Notification("VibeUI", ("Loaded in %.3fs — press Right Ctrl to toggle"):format(VibeUI.LoadTime), 6, "success")
