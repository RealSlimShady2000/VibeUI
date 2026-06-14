--!nonstrict
--[[
	VibeUI — a modern Roblox UI library
	A ground-up rewrite of the abandoned "Scoot UI Library" by samet.

	Distribution: single file. Load with:
		local VibeUI = loadstring(game:HttpGet("<url>/VibeUI.luau"))()

	Why --!nonstrict: this library uses executor-only globals (writefile,
	getcustomasset, cloneref, gethui, getgenv, ...). Under --!strict those read
	as "unknown global" errors. nonstrict keeps full type-checking on annotated
	code while tolerating the runtime-injected globals. All such globals are
	shimmed below and degrade gracefully when absent.

	Quick start (see examples/usage.luau for a full demo):
		local Window  = VibeUI:Window({ Title = "VibeUI", Logo = "77218680285262" })
		local Tab     = Window:Tab({ Name = "Combat" })
		local Section = Tab:Section({ Name = "Aimbot", Side = 1 })
		Section:Toggle({ Name = "Enabled", Flag = "AimbotEnabled", Callback = print })
]]

if shared.VibeUI then
	pcall(function() shared.VibeUI:Unload() end)
end

local LoadStart = os.clock()

--==============================================================================
-- Services
--==============================================================================

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

--==============================================================================
-- Executor shims (degrade gracefully off-executor)
--==============================================================================

local cloneref       = cloneref
local gethui         = gethui
local getgenv        = getgenv
local getcustomasset = getcustomasset -- sUNC standard (legacy getsynasset alias dropped)
local function httpget(url: string): string
	return game:HttpGet(url)
end

local isfile, isfolder, makefolder = isfile, isfolder, makefolder
local writefile, readfile          = writefile, readfile
local listfiles, delfile           = listfiles, delfile

local HasFileSystem = (isfile and isfolder and makefolder and writefile and readfile and listfiles) and true or false

local function GetParentGui(): Instance
	local ok, hui = pcall(function()
		if gethui then return gethui() end
		local cg = game:GetService("CoreGui")
		return cloneref and cloneref(cg) or cg
	end)
	if ok and hui then return hui end
	-- Studio / no-executor fallback
	return LocalPlayer:WaitForChild("PlayerGui")
end

--==============================================================================
-- Types
--==============================================================================

export type Theme = { [string]: Color3 }

export type WindowConfig = {
	Title: string?,
	Logo: string?,
	Size: UDim2?,
	FadeTime: number?,
	Resizable: boolean?,
	Keybind: Enum.KeyCode?,
}

export type ToggleConfig = {
	Name: string?,
	Flag: string?,
	Default: boolean?,
	Tooltip: string?,
	Callback: ((value: boolean) -> ())?,
}

export type SliderConfig = {
	Name: string?,
	Flag: string?,
	Min: number?,
	Max: number?,
	Default: number?,
	Decimals: number?,
	Suffix: string?,
	Tooltip: string?,
	Callback: ((value: number) -> ())?,
}

export type DropdownConfig = {
	Name: string?,
	Flag: string?,
	Items: { string }?,
	Default: (string | { string })?,
	Multi: boolean?,
	Search: boolean?,
	Tooltip: string?,
	Callback: ((value: any) -> ())?,
}

--==============================================================================
-- Config / presets
--==============================================================================

local Config = {
	Folder    = "VibeUI",
	FadeSpeed = 0.18,
	Tween = {
		Time      = 0.18,
		Style     = Enum.EasingStyle.Quad,
		Direction = Enum.EasingDirection.Out,
	},
	MenuKeybind  = Enum.KeyCode.RightControl,
	CustomCursor = true,
	Rounded      = false,
}

local Folders = {
	Root    = Config.Folder,
	Configs = Config.Folder .. "/Configs",
	Assets  = Config.Folder .. "/Assets",
}

local Presets: { [string]: Theme } = {
	["Midnight"] = {
		Background       = Color3.fromRGB(14, 17, 15),
		Border           = Color3.fromRGB(12, 12, 12),
		Inline           = Color3.fromRGB(20, 24, 21),
		["Hovered Element"] = Color3.fromRGB(37, 42, 45),
		["Page Background"] = Color3.fromRGB(25, 30, 26),
		Outline          = Color3.fromRGB(42, 49, 45),
		Element          = Color3.fromRGB(30, 36, 31),
		Gradient         = Color3.fromRGB(208, 208, 208),
		Text             = Color3.fromRGB(235, 235, 235),
		["Text Stroke"]  = Color3.fromRGB(0, 0, 0),
		["Placeholder Text"] = Color3.fromRGB(185, 185, 185),
		Accent           = Color3.fromRGB(202, 243, 255),
	},
	["Crimson"] = {
		Background       = Color3.fromRGB(17, 14, 15),
		Border           = Color3.fromRGB(12, 12, 12),
		Inline           = Color3.fromRGB(24, 20, 21),
		["Hovered Element"] = Color3.fromRGB(45, 37, 40),
		["Page Background"] = Color3.fromRGB(30, 25, 26),
		Outline          = Color3.fromRGB(49, 42, 44),
		Element          = Color3.fromRGB(36, 30, 31),
		Gradient         = Color3.fromRGB(208, 208, 208),
		Text             = Color3.fromRGB(235, 235, 235),
		["Text Stroke"]  = Color3.fromRGB(0, 0, 0),
		["Placeholder Text"] = Color3.fromRGB(185, 185, 185),
		Accent           = Color3.fromRGB(255, 105, 120),
	},
	["Indigo"] = {
		Background       = Color3.fromRGB(15, 15, 19),
		Border           = Color3.fromRGB(12, 12, 12),
		Inline           = Color3.fromRGB(21, 21, 27),
		["Hovered Element"] = Color3.fromRGB(40, 40, 52),
		["Page Background"] = Color3.fromRGB(26, 26, 33),
		Outline          = Color3.fromRGB(44, 44, 56),
		Element          = Color3.fromRGB(31, 31, 40),
		Gradient         = Color3.fromRGB(208, 208, 208),
		Text             = Color3.fromRGB(235, 235, 235),
		["Text Stroke"]  = Color3.fromRGB(0, 0, 0),
		["Placeholder Text"] = Color3.fromRGB(185, 185, 185),
		Accent           = Color3.fromRGB(150, 160, 255),
	},
}

--==============================================================================
-- Library skeleton (forward-declared so components can use it)
--==============================================================================

local Library = {
	Flags     = {},   -- flag -> value
	_setters  = {},   -- flag -> function(value)
	Theme     = {},   -- live theme value table (filled below)
	Colorpickers = {},
	KeyList   = nil,
}
Library.__index = Library

--==============================================================================
-- Maid — central cleanup
--==============================================================================

local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid:GiveTask(task)
	table.insert(self._tasks, task)
	return task
end

function Maid:Clean()
	local tasks = self._tasks
	self._tasks = {}
	for _, t in tasks do
		local tt = typeof(t)
		if tt == "RBXScriptConnection" then
			t:Disconnect()
		elseif tt == "Instance" then
			t:Destroy()
		elseif tt == "function" then
			pcall(t)
		elseif tt == "thread" then
			pcall(task.cancel, t)
		elseif type(t) == "table" and type(t.Clean) == "function" then
			t:Clean()
		end
	end
end

local LibMaid = Maid.new()

--==============================================================================
-- Input manager — single global dispatch (fixes connection accumulation)
--==============================================================================

local Input = {} do
	local listeners = { Began = {}, Changed = {}, Ended = {} }

	local function fire(kind, input, gpe)
		for fn in listeners[kind] do
			task.spawn(fn, input, gpe)
		end
	end

	function Input.Init()
		LibMaid:GiveTask(UserInputService.InputBegan:Connect(function(i, g) fire("Began", i, g) end))
		LibMaid:GiveTask(UserInputService.InputChanged:Connect(function(i, g) fire("Changed", i, g) end))
		LibMaid:GiveTask(UserInputService.InputEnded:Connect(function(i, g) fire("Ended", i, g) end))
	end

	--- Subscribe to a global input event. Returns a disconnect function.
	function Input.On(kind: string, fn): () -> ()
		listeners[kind][fn] = true
		return function() listeners[kind][fn] = nil end
	end

	function Input.isPrimary(input): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
	end

	function Input.isMove(input): boolean
		return input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
	end
end

--==============================================================================
-- Theme manager
--==============================================================================

local Theme = {} do
	Theme.Values   = Library.Theme
	Theme.Registry = {}

	for k, v in Presets["Midnight"] do
		Theme.Values[k] = v
	end

	function Theme.Resolve(ref)
		if type(ref) == "function" then
			return ref()
		end
		return Theme.Values[ref]
	end

	--- Register an instance property to follow a theme key (string) or function.
	function Theme.Tag(inst: Instance, map)
		for prop, ref in map do
			table.insert(Theme.Registry, { inst = inst, prop = prop, ref = ref })
			pcall(function() inst[prop] = Theme.Resolve(ref) end)
		end
	end

	--- Re-point an already-themed instance/property to a new key WITHOUT setting
	--- the value — callers animate the change with Tween.To, and a later
	--- Theme.Set on the new key will keep tracking it.
	function Theme.Retag(inst: Instance, map)
		for prop, ref in map do
			for _, entry in Theme.Registry do
				if entry.inst == inst and entry.prop == prop then
					entry.ref = ref
				end
			end
		end
	end

	--- Change a theme color live across the whole UI.
	function Theme.Set(key: string, color: Color3)
		Theme.Values[key] = color
		for i = #Theme.Registry, 1, -1 do
			local entry = Theme.Registry[i]
			local ref = entry.ref
			if ref == key or type(ref) == "function" then
				local ok = pcall(function() entry.inst[entry.prop] = Theme.Resolve(ref) end)
				if not ok then
					table.remove(Theme.Registry, i) -- prune destroyed instances
				end
			end
		end
	end

	function Theme.Load(t: Theme)
		for k, v in t do
			Theme.Set(k, v)
		end
	end
end

--==============================================================================
-- Tween helpers
--==============================================================================

local Tween = {} do
	local TRANS = {
		Frame          = { "BackgroundTransparency" },
		TextLabel      = { "TextTransparency", "BackgroundTransparency" },
		TextButton     = { "TextTransparency", "BackgroundTransparency" },
		TextBox        = { "TextTransparency", "BackgroundTransparency" },
		ImageLabel     = { "BackgroundTransparency", "ImageTransparency" },
		ImageButton    = { "BackgroundTransparency", "ImageTransparency" },
		ScrollingFrame = { "BackgroundTransparency", "ScrollBarImageTransparency" },
		UIStroke       = { "Transparency" },
	}

	local ShownCache = setmetatable({}, { __mode = "k" })

	local function shownValue(inst, prop)
		local t = ShownCache[inst]
		if not t then t = {}; ShownCache[inst] = t end
		if t[prop] == nil then t[prop] = inst[prop] end
		return t[prop]
	end

	local function info(timeOverride, styleOverride, dirOverride)
		return TweenInfo.new(
			timeOverride or Config.Tween.Time,
			styleOverride or Config.Tween.Style,
			dirOverride or Config.Tween.Direction
		)
	end
	Tween.Info = info

	--- Tween an instance to a goal. Returns the Tween object.
	function Tween.To(inst: Instance, goal, tweenInfo: TweenInfo?): Tween
		local t = TweenService:Create(inst, tweenInfo or info(), goal)
		t:Play()
		return t
	end

	function Tween.PropsFor(inst): { string }?
		for class, props in TRANS do
			if inst:IsA(class) then
				return props
			end
		end
		return nil
	end

	--- Fade every fade-able descendant of `root` in/out. Returns last tween.
	function Tween.Fade(root: Instance, visible: boolean, speed: number?): Tween?
		local i = info(speed or Config.FadeSpeed)
		local list = root:GetDescendants()
		table.insert(list, root)
		local last: Tween? = nil
		for _, inst in list do
			local props = Tween.PropsFor(inst)
			if not props then continue end
			for _, prop in props do
				local shown = shownValue(inst, prop)
				if visible then inst[prop] = 1 end
				last = TweenService:Create(inst, i, { [prop] = visible and shown or 1 })
				last:Play()
			end
		end
		return last
	end
end

--==============================================================================
-- Instance factory + small UI helpers
--==============================================================================

--- Create an instance. `props.ThemeTag = {Prop = "Key"|fn}` auto-registers theme.
local function Create(class: string, props, children: { Instance }?): any
	local inst = Instance.new(class)
	local themeTag = props.ThemeTag
	props.ThemeTag = nil
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		inst[k] = v
	end
	if themeTag then
		Theme.Tag(inst, themeTag)
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local GetFont -- forward-declared; resolves the loaded custom font or a fallback

local function Stroke(parent: Instance, key: string?, transparency: number?): Instance
	return Create("UIStroke", {
		Parent = parent,
		Thickness = 1,
		Transparency = transparency or 0,
		LineJoinMode = Enum.LineJoinMode.Miter,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		ThemeTag = { Color = key or "Outline" },
	})
end

local function TextStroke(parent: Instance): Instance
	return Create("UIStroke", {
		Parent = parent,
		Thickness = 1,
		Transparency = 0.6,
		LineJoinMode = Enum.LineJoinMode.Miter,
		ThemeTag = { Color = "Text Stroke" },
	})
end

local function Corner(parent: Instance, radius: number?)
	if not Config.Rounded then return end
	Create("UICorner", { Parent = parent, CornerRadius = UDim.new(0, radius or 4) })
end

local function isMouseOver(gui: Instance): boolean
	local mp = UserInputService:GetMouseLocation()
	local p, s = gui.AbsolutePosition, gui.AbsoluteSize
	return mp.X >= p.X and mp.X <= p.X + s.X and mp.Y >= p.Y and mp.Y <= p.Y + s.Y
end

local function MakeText(parent: Instance, text: string, props): TextLabel
	props = props or {}
	props.Parent = parent
	props.FontFace = props.FontFace or GetFont()
	props.Text = text
	props.TextSize = props.TextSize or 12
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.TextColor3 = props.TextColor3 or Theme.Values.Text
	props.ThemeTag = props.ThemeTag or { TextColor3 = "Text" }
	local label = Create("TextLabel", props)
	TextStroke(label)
	return label
end

--==============================================================================
-- Drag / resize
--==============================================================================

local function MakeDraggable(frame: GuiObject, handle: GuiObject?, maid)
	handle = handle or frame
	local dragging, dragStart, startPos = false, nil, nil
	maid:GiveTask((handle :: any).InputBegan:Connect(function(input)
		if Input.isPrimary(input) then
			dragging, dragStart, startPos = true, input.Position, frame.Position
			local conn
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					conn:Disconnect()
				end
			end)
		end
	end))
	maid:GiveTask(Input.On("Changed", function(input)
		if dragging and Input.isMove(input) then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end))
end

local function MakeResizable(frame: GuiObject, minSize: Vector2, maid)
	local grip = Create("TextButton", {
		Parent = frame,
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -3, 1, -3),
		Size = UDim2.fromOffset(8, 8),
		BorderSizePixel = 0,
		ZIndex = 20,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		ThemeTag = { BackgroundColor3 = "Accent" },
	})
	local resizing, startSize, startPos = false, nil, nil
	maid:GiveTask(grip.InputBegan:Connect(function(input)
		if Input.isPrimary(input) then
			resizing, startSize, startPos = true, frame.AbsoluteSize, input.Position
			local conn
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					resizing = false
					conn:Disconnect()
				end
			end)
		end
	end))
	maid:GiveTask(Input.On("Changed", function(input)
		if resizing and Input.isMove(input) then
			local delta = input.Position - startPos
			frame.Size = UDim2.fromOffset(
				math.max(minSize.X, startSize.X + delta.X),
				math.max(minSize.Y, startSize.Y + delta.Y)
			)
		end
	end))
end

--==============================================================================
-- Holders (ScreenGuis)
--==============================================================================

local Parent = GetParentGui()

local Holder = Create("ScreenGui", {
	Parent = Parent,
	Name = "\0",
	ZIndexBehavior = Enum.ZIndexBehavior.Global,
	IgnoreGuiInset = true,
	DisplayOrder = 999,
	ResetOnSpawn = false,
})
LibMaid:GiveTask(Holder)

local UnusedHolder = Create("ScreenGui", {
	Parent = Parent,
	Name = "\0",
	Enabled = false,
	ResetOnSpawn = false,
})
LibMaid:GiveTask(UnusedHolder)

local NotifHolder = Create("Frame", {
	Parent = Holder,
	BackgroundTransparency = 1,
	Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X,
	BorderSizePixel = 0,
})
Create("UIListLayout", {
	Parent = NotifHolder,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
Create("UIPadding", {
	Parent = NotifHolder,
	PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
	PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
})

--==============================================================================
-- Anchored popup follow loop (single RenderStepped for all popups + cursor)
--==============================================================================

local Anchors = {} -- frame -> updater fn
local OpenPopups = {} -- popup -> true (exclusive popups currently open)

local CursorBg
if Config.CustomCursor then
	CursorBg = Create("Frame", {
		Parent = Holder, BackgroundTransparency = 1, ZIndex = 9999,
		Size = UDim2.fromOffset(16, 16), Visible = false,
	})
	Create("ImageLabel", {
		Parent = CursorBg, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Image = "rbxassetid://76631660114196", ZIndex = 9999,
		ThemeTag = { ImageColor3 = "Accent" },
	})
end

LibMaid:GiveTask(RunService.RenderStepped:Connect(function()
	for _, fn in Anchors do
		fn()
	end
	if CursorBg and CursorBg.Visible then
		local m = UserInputService:GetMouseLocation()
		CursorBg.Position = UDim2.fromOffset(m.X, m.Y)
	end
end))

local function CloseAllPopups(except)
	for popup in OpenPopups do
		if popup ~= except then
			popup:SetOpen(false)
		end
	end
end

--- Generic popup attached under an anchor element. Handles fade, follow, outside-click.
local function CreatePopup(anchorTo: GuiObject, maid, exclusive: boolean?)
	local frame = Create("Frame", {
		Parent = UnusedHolder,
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(20, 24, 21),
		BorderColor3 = Color3.fromRGB(12, 12, 12),
		BorderSizePixel = 2,
		Size = UDim2.fromOffset(100, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 50,
		ThemeTag = { BackgroundColor3 = "Inline", BorderColor3 = "Border" },
	})
	Stroke(frame, "Outline")
	maid:GiveTask(frame)

	local popup = { Frame = frame, IsOpen = false }
	local debounce = false

	function popup:SetOpen(open: boolean)
		if debounce or open == self.IsOpen then return end
		self.IsOpen = open
		debounce = true

		if open then
			if exclusive ~= false then
				CloseAllPopups(self)
				OpenPopups[self] = true
			end
			frame.Visible = true
			frame.Parent = Holder
			Anchors[frame] = function()
				local ap, as = anchorTo.AbsolutePosition, anchorTo.AbsoluteSize
				frame.Position = UDim2.fromOffset(ap.X, ap.Y + as.Y + 6)
				frame.Size = UDim2.fromOffset(as.X, 0)
			end
		else
			OpenPopups[self] = nil
			Anchors[frame] = nil
		end

		local last = Tween.Fade(frame, open, Config.FadeSpeed)
		local function done()
			debounce = false
			frame.Visible = self.IsOpen
			if not self.IsOpen then frame.Parent = UnusedHolder end
		end
		if last then last.Completed:Once(done) else done() end
	end

	maid:GiveTask(Input.On("Began", function(input)
		if not popup.IsOpen or not Input.isPrimary(input) then return end
		if isMouseOver(frame) or isMouseOver(anchorTo) then return end
		popup:SetOpen(false)
	end))

	return popup
end

--==============================================================================
-- Assets + custom font
--==============================================================================

local Assets = {
	Saturation = { "saturation.png", "https://github.com/sametexe001/images/blob/main/saturation.png?raw=true" },
	Value      = { "value.png",      "https://github.com/sametexe001/images/blob/main/value.png?raw=true" },
	Hue        = { "hue.png",        "https://github.com/sametexe001/images/blob/main/horizontalhue.png?raw=true" },
	Checkers   = { "checkers.png",   "https://github.com/sametexe001/images/blob/main/checkers.png?raw=true" },
}

if HasFileSystem then
	for _, dir in Folders do
		if not isfolder(dir) then pcall(makefolder, dir) end
	end
	for _, data in Assets do
		local path = Folders.Assets .. "/" .. data[1]
		if not isfile(path) then
			pcall(function() writefile(path, httpget(data[2])) end)
		end
	end
end

function Library:GetImage(name: string): string
	local data = Assets[name]
	if not data then return "" end
	if HasFileSystem and getcustomasset then
		local path = Folders.Assets .. "/" .. data[1]
		if isfile(path) then
			local ok, id = pcall(getcustomasset, path)
			if ok then return id end
		end
	end
	return ""
end

-- Default UI font: a clean, smooth sans. Set `Library.Font` (a Font object)
-- before building the window to override.
Library.Font = Library.Font or Font.fromEnum(Enum.Font.Gotham)

-- assign the forward-declared GetFont (do NOT redeclare with `local`)
function GetFont(): Font
	return Library.Font or Font.fromEnum(Enum.Font.Gotham)
end

--==============================================================================
-- Tooltip
--==============================================================================

local Tooltip = {} do
	local frame = Create("Frame", {
		Parent = Holder, Visible = false, ZIndex = 5000,
		AutomaticSize = Enum.AutomaticSize.XY, BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(14, 17, 15),
		ThemeTag = { BackgroundColor3 = "Background", BorderColor3 = "Border" },
	})
	Stroke(frame, "Outline")
	Create("UIPadding", { Parent = frame,
		PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
	local label = Create("TextLabel", {
		Parent = frame, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY,
		FontFace = GetFont(), TextSize = 12, ZIndex = 5001,
		Text = "", TextColor3 = Color3.fromRGB(235, 235, 235),
		ThemeTag = { TextColor3 = "Text" },
	})

	local active = false
	LibMaid:GiveTask(RunService.RenderStepped:Connect(function()
		if active then
			local m = UserInputService:GetMouseLocation()
			frame.Position = UDim2.fromOffset(m.X + 14, m.Y + 2)
		end
	end))

	function Tooltip.Bind(gui: GuiObject, text: string, maid)
		maid:GiveTask(gui.MouseEnter:Connect(function()
			label.Text = text
			frame.Visible = true
			active = true
		end))
		maid:GiveTask(gui.MouseLeave:Connect(function()
			frame.Visible = false
			active = false
		end))
	end
end

--==============================================================================
-- Flags + config
--==============================================================================

function Library:NextFlag(): string
	return "flag_" .. HttpService:GenerateGUID(false)
end

function Library:SafeCall(fn, ...): boolean
	if type(fn) ~= "function" then return false end
	local ok, err = pcall(fn, ...)
	if not ok then warn("[VibeUI] callback error: " .. tostring(err)) end
	return ok
end

function Library:GetConfig(): string
	local out = {}
	for flag, value in self.Flags do
		if type(value) == "table" and value.Key then            -- keybind
			out[flag] = { Key = tostring(value.Key), Mode = value.Mode, Toggled = value.Toggled }
		elseif type(value) == "table" and value.Color then       -- colorpicker
			out[flag] = { Color = value.Color, Alpha = value.Alpha }
		else
			out[flag] = value
		end
	end
	return HttpService:JSONEncode(out)
end

function Library:LoadConfig(json: string): (boolean, string?)
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok then return false, "invalid json" end
	local ok2, err = pcall(function()
		for flag, value in decoded do
			local setter = self._setters[flag]
			if not setter then continue end
			if type(value) == "table" and value.Key then
				setter(value)
			elseif type(value) == "table" and value.Color then
				setter(value.Color, value.Alpha)
			else
				setter(value)
			end
		end
	end)
	return ok2, err
end

function Library:ListConfigs(): { string }
	local list = {}
	if not HasFileSystem then return list end
	for _, path in listfiles(Folders.Configs) do
		local name = path:match("([^/\\]+)%.json$")
		if name then table.insert(list, name) end
	end
	return list
end

function Library:SaveConfig(name: string): boolean
	if not HasFileSystem or name == "" then return false end
	return pcall(writefile, Folders.Configs .. "/" .. name .. ".json", self:GetConfig())
end

function Library:DeleteConfig(name: string): boolean
	if not HasFileSystem then return false end
	local path = Folders.Configs .. "/" .. name .. ".json"
	if isfile(path) then return pcall(delfile, path) end
	return false
end

function Library:ReadConfig(name: string): string?
	if not HasFileSystem then return nil end
	local path = Folders.Configs .. "/" .. name .. ".json"
	if isfile(path) then return readfile(path) end
	return nil
end

--==============================================================================
-- Components
--==============================================================================

local Components = {}

-- A reusable bordered element button skin (Element bg + gradient + outline)
local function ElementSkin(parent, height)
	local btn = Create("TextButton", {
		Parent = parent, Text = "", AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, height),
		BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(30, 36, 31),
		ThemeTag = { BackgroundColor3 = "Element", BorderColor3 = "Border" },
	})
	Create("UIGradient", {
		Parent = btn, Rotation = -165,
		Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(208,208,208)),
		ThemeTag = { Color = function()
			return ColorSequence.new(Color3.fromRGB(255,255,255), Theme.Values.Gradient)
		end },
	})
	Stroke(btn, "Outline")
	Corner(btn)
	return btn
end

--------------------------------------------------------------------- Toggle ---
function Components.Toggle(data)
	local maid = data.Maid
	local self = { Value = false, Flag = data.Flag }

	local row = Create("TextButton", {
		Parent = data.Parent, Text = "", AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, BorderSizePixel = 0,
	})

	local box = Create("Frame", {
		Parent = row, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(14, 14), BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(30, 36, 31),
		ThemeTag = { BackgroundColor3 = "Element", BorderColor3 = "Border" },
	})
	Stroke(box, "Outline")
	Corner(box, 3)
	local check = Create("ImageLabel", {
		Parent = box, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 2, 1, 2), BackgroundTransparency = 1, ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Fit, Image = "rbxassetid://108016671469439",
		ImageColor3 = Color3.fromRGB(0, 0, 0),
	})

	local text = MakeText(row, data.Name or "Toggle", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 22, 0.5, 0),
		Size = UDim2.new(1, -22, 0, 15), TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.X,
	})

	-- sub-elements (colorpicker/keybind) sit flush against the right edge so
	-- they never overlap the label text regardless of its width.
	local sub = Create("Frame", {
		Parent = row, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 0, 1, 0),
	})
	Create("UIListLayout", { Parent = sub, FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder })

	function self:Get() return self.Value end
	function self:SetText(t) text.Text = tostring(t) end
	function self:SetVisibility(b) row.Visible = b end

	function self:Set(value: boolean)
		self.Value = value and true or false
		Library.Flags[self.Flag] = self.Value
		if self.Value then
			Theme.Retag(box, { BackgroundColor3 = "Accent" })
			Tween.To(box, { BackgroundColor3 = Theme.Values.Accent })
			Tween.To(check, { ImageTransparency = 0, Size = UDim2.new(1, 2, 1, 2) },
				Tween.Info(nil, Enum.EasingStyle.Back))
		else
			Theme.Retag(box, { BackgroundColor3 = "Element" })
			Tween.To(box, { BackgroundColor3 = Theme.Values.Element })
			Tween.To(check, { ImageTransparency = 1, Size = UDim2.fromOffset(0, 0) },
				Tween.Info(nil, Enum.EasingStyle.Back))
		end
		if data.Callback then Library:SafeCall(data.Callback, self.Value) end
	end

	maid:GiveTask(row.MouseButton1Click:Connect(function() self:Set(not self.Value) end))
	maid:GiveTask(row.MouseEnter:Connect(function()
		if not self.Value then
			Theme.Retag(box, { BackgroundColor3 = "Hovered Element" })
			Tween.To(box, { BackgroundColor3 = Theme.Values["Hovered Element"] })
		end
	end))
	maid:GiveTask(row.MouseLeave:Connect(function()
		if not self.Value then
			Theme.Retag(box, { BackgroundColor3 = "Element" })
			Tween.To(box, { BackgroundColor3 = Theme.Values.Element })
		end
	end))

	self._sub = sub
	self:Set(data.Default and true or false)
	Library._setters[self.Flag] = function(v) self:Set(v) end
	if data.Tooltip then Tooltip.Bind(row, data.Tooltip, maid) end
	return self
end

--------------------------------------------------------------------- Button ---
function Components.Button(data)
	local maid = data.Maid
	local self = {}
	local row = Create("Frame", {
		Parent = data.Parent, BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	})
	Create("UIListLayout", { Parent = row, FillDirection = Enum.FillDirection.Horizontal,
		HorizontalFlex = Enum.UIFlexAlignment.Fill, Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder })

	function self:Add(name: string, callback)
		local btn = ElementSkin(row, 20)
		local label = MakeText(btn, name, { Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center })
		local sub = { Button = btn, Label = label }
		function sub:Press()
			Theme.Retag(btn, { BackgroundColor3 = "Accent" })
			Tween.To(btn, { BackgroundColor3 = Theme.Values.Accent })
			Library:SafeCall(callback)
			task.delay(0.12, function()
				Theme.Retag(btn, { BackgroundColor3 = "Element" })
				Tween.To(btn, { BackgroundColor3 = Theme.Values.Element })
			end)
		end
		maid:GiveTask(btn.MouseButton1Click:Connect(function() sub:Press() end))
		maid:GiveTask(btn.MouseEnter:Connect(function()
			Theme.Retag(btn, { BackgroundColor3 = "Hovered Element" })
			Tween.To(btn, { BackgroundColor3 = Theme.Values["Hovered Element"] })
		end))
		maid:GiveTask(btn.MouseLeave:Connect(function()
			Theme.Retag(btn, { BackgroundColor3 = "Element" })
			Tween.To(btn, { BackgroundColor3 = Theme.Values.Element })
		end))
		return sub
	end

	function self:SetVisibility(b) row.Visible = b end
	return self
end

--------------------------------------------------------------------- Slider ---
function Components.Slider(data)
	local maid = data.Maid
	local self = { Value = data.Min or 0, Flag = data.Flag }
	local minV, maxV = data.Min or 0, data.Max or 100
	local decimals, suffix = data.Decimals or 1, data.Suffix or ""

	local container = Create("Frame", { Parent = data.Parent, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28), BorderSizePixel = 0 })
	MakeText(container, data.Name or "Slider", { Size = UDim2.new(0, 0, 0, 15),
		AutomaticSize = Enum.AutomaticSize.X })
	local valueText = MakeText(container, "", { AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 0, 0, 15),
		AutomaticSize = Enum.AutomaticSize.X })

	local bar = Create("TextButton", { Parent = container, Text = "", AutoButtonColor = false,
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 10), BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(30, 36, 31),
		ThemeTag = { BackgroundColor3 = "Element", BorderColor3 = "Border" } })
	Stroke(bar, "Outline")
	Corner(bar)
	local fill = Create("Frame", { Parent = bar, Size = UDim2.fromScale(0.5, 1), BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(202, 243, 255), ThemeTag = { BackgroundColor3 = "Accent" } })

	function self:Get() return self.Value end
	function self:SetVisibility(b) container.Visible = b end

	function self:Set(value: number)
		value = math.clamp(value, minV, maxV)
		local mult = 1 / decimals
		self.Value = math.floor(value * mult + 0.5) / mult
		Library.Flags[self.Flag] = self.Value
		local alpha = (self.Value - minV) / (maxV - minV)
		Tween.To(fill, { Size = UDim2.new(alpha, 0, 1, 0) },
			Tween.Info(nil, Enum.EasingStyle.Quart))
		valueText.Text = tostring(self.Value) .. suffix
		if data.Callback then Library:SafeCall(data.Callback, self.Value) end
	end

	local sliding = false
	local function setFromMouse()
		local rel = (UserInputService:GetMouseLocation().X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
		self:Set(minV + (maxV - minV) * math.clamp(rel, 0, 1))
	end
	maid:GiveTask(bar.InputBegan:Connect(function(input)
		if Input.isPrimary(input) then
			sliding = true
			setFromMouse()
			local conn
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then sliding = false conn:Disconnect() end
			end)
		end
	end))
	maid:GiveTask(Input.On("Changed", function(input)
		if sliding and Input.isMove(input) then setFromMouse() end
	end))
	maid:GiveTask(container.MouseEnter:Connect(function()
		Theme.Retag(bar, { BackgroundColor3 = "Hovered Element" })
		Tween.To(bar, { BackgroundColor3 = Theme.Values["Hovered Element"] })
	end))
	maid:GiveTask(container.MouseLeave:Connect(function()
		Theme.Retag(bar, { BackgroundColor3 = "Element" })
		Tween.To(bar, { BackgroundColor3 = Theme.Values.Element })
	end))

	self:Set(data.Default or minV)
	Library._setters[self.Flag] = function(v) self:Set(v) end
	if data.Tooltip then Tooltip.Bind(container, data.Tooltip, maid) end
	return self
end

---------------------------------------------------------------------- Label ---
function Components.Label(data)
	local maid = data.Maid
	local self = {}
	local container = Create("Frame", { Parent = data.Parent, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20), BorderSizePixel = 0 })
	local text = MakeText(container, data.Name or "Label", { AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 15),
		TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.X })

	-- right-anchored so colorpicker/keybind sub-elements never overlap the text.
	local sub = Create("Frame", { Parent = container, BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 0, 1, 0) })
	Create("UIListLayout", { Parent = sub, FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder })

	function self:SetText(t) text.Text = tostring(t) end
	function self:SetVisibility(b) container.Visible = b end
	self._sub = sub
	if data.Tooltip then Tooltip.Bind(container, data.Tooltip, maid) end
	return self
end

------------------------------------------------------------------ Paragraph ---
function Components.Paragraph(data)
	local self = {}
	local container = Create("Frame", { Parent = data.Parent, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0 })
	Create("UIListLayout", { Parent = container, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
	MakeText(container, data.Name or "Title", { Size = UDim2.new(1, 0, 0, 15),
		TextXAlignment = Enum.TextXAlignment.Left })
	local body = MakeText(container, data.Content or "", { Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(185, 185, 185), ThemeTag = { TextColor3 = "Placeholder Text" } })
	function self:SetText(t) body.Text = tostring(t) end
	function self:SetVisibility(b) container.Visible = b end
	return self
end

-------------------------------------------------------------------- Divider ---
function Components.Divider(data)
	local container = Create("Frame", { Parent = data.Parent, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 8), BorderSizePixel = 0 })
	Create("Frame", { Parent = container, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(42, 49, 45), ThemeTag = { BackgroundColor3 = "Outline" } })
	return { SetVisibility = function(_, b) container.Visible = b end }
end

-------------------------------------------------------------------- Textbox ---
function Components.Textbox(data)
	local maid = data.Maid
	local self = { Value = "", Flag = data.Flag }
	local container = Create("Frame", { Parent = data.Parent, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40), BorderSizePixel = 0 })
	MakeText(container, data.Name or "Textbox", { Size = UDim2.new(0, 0, 0, 15),
		AutomaticSize = Enum.AutomaticSize.X })
	local bg = ElementSkin(container, 20)
	bg.AnchorPoint = Vector2.new(0, 1)
	bg.Position = UDim2.new(0, 0, 1, 0)
	local input = Create("TextBox", { Parent = bg, FontFace = GetFont(), TextSize = 12,
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClearTextOnFocus = false,
		Text = "", TextColor3 = Color3.fromRGB(235, 235, 235), TextXAlignment = Enum.TextXAlignment.Left,
		PlaceholderColor3 = Color3.fromRGB(185, 185, 185), PlaceholderText = data.Placeholder or "...",
		ClipsDescendants = true, BorderSizePixel = 0,
		ThemeTag = { TextColor3 = "Text", PlaceholderColor3 = "Placeholder Text" } })
	TextStroke(input)
	Create("UIPadding", { Parent = input, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })

	function self:Get() return self.Value end
	function self:SetVisibility(b) container.Visible = b end
	function self:Set(value)
		if data.Numeric and not tonumber(value) and #tostring(value) > 0 then
			value = self.Value
		end
		self.Value = value
		input.Text = tostring(value)
		Library.Flags[self.Flag] = value
		if data.Callback then Library:SafeCall(data.Callback, value) end
	end

	if data.Finished then
		maid:GiveTask(input.FocusLost:Connect(function(enter)
			if enter then self:Set(input.Text) end
		end))
	else
		maid:GiveTask(input:GetPropertyChangedSignal("Text"):Connect(function()
			self:Set(input.Text)
		end))
	end

	if data.Default then self:Set(data.Default) end
	Library._setters[self.Flag] = function(v) self:Set(v) end
	if data.Tooltip then Tooltip.Bind(container, data.Tooltip, maid) end
	return self
end

------------------------------------------------------------------- Dropdown ---
-- Unified dropdown: single/multi + optional inline search.
function Components.Dropdown(data)
	local maid = data.Maid
	local self = { Flag = data.Flag, Value = data.Multi and {} or nil, Options = {}, IsOpen = false }

	local container = Create("Frame", { Parent = data.Parent, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40), BorderSizePixel = 0 })
	MakeText(container, data.Name or "Dropdown", { Size = UDim2.new(0, 0, 0, 15),
		AutomaticSize = Enum.AutomaticSize.X })
	local box = ElementSkin(container, 20)
	box.AnchorPoint = Vector2.new(0, 1)
	box.Position = UDim2.new(0, 0, 1, 0)
	local valueText = MakeText(box, "--", { AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.new(1, -28, 0, 15),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
	local icon = Create("ImageLabel", { Parent = box, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -3, 0.5, 0), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit, Image = "rbxassetid://113229176886493",
		ImageColor3 = Color3.fromRGB(202, 243, 255), ThemeTag = { ImageColor3 = "Accent" } })

	local popup = CreatePopup(box, maid)
	Create("UIPadding", { Parent = popup.Frame, PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 6) })
	Create("UIListLayout", { Parent = popup.Frame, Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder })

	local searchInput
	if data.Search then
		local searchBg = Create("Frame", { Parent = popup.Frame, BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16), LayoutOrder = -1, BorderSizePixel = 0 })
		searchInput = Create("TextBox", { Parent = searchBg, FontFace = GetFont(), TextSize = 12,
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ClearTextOnFocus = false,
			TextColor3 = Color3.fromRGB(235, 235, 235), TextXAlignment = Enum.TextXAlignment.Left,
			PlaceholderText = "search..", PlaceholderColor3 = Color3.fromRGB(185, 185, 185), BorderSizePixel = 0,
			ThemeTag = { TextColor3 = "Text", PlaceholderColor3 = "Placeholder Text" } })
	end

	local function refreshText()
		if data.Multi then
			valueText.Text = (#self.Value > 0) and table.concat(self.Value, ", ") or "--"
		else
			valueText.Text = self.Value or "--"
		end
	end

	function self:Get() return self.Value end
	function self:SetVisibility(b) container.Visible = b end
	function self:SetOpen(b)
		popup:SetOpen(b)
		self.IsOpen = popup.IsOpen
		Tween.To(icon, { Rotation = popup.IsOpen and -90 or 0 })
	end

	local function toggleOption(opt, active)
		if active then
			Theme.Retag(opt.Button, { TextColor3 = "Accent" })
			Tween.To(opt.Button, { TextColor3 = Theme.Values.Accent })
		else
			Theme.Retag(opt.Button, { TextColor3 = "Text" })
			Tween.To(opt.Button, { TextColor3 = Theme.Values.Text })
		end
	end

	function self:Set(option)
		if data.Multi then
			if type(option) ~= "table" then return end
			self.Value = option
			for _, opt in self.Options do opt.Selected = false; toggleOption(opt, false) end
			for _, name in option do
				local opt = self.Options[name]
				if opt then opt.Selected = true; toggleOption(opt, true) end
			end
		else
			local opt = self.Options[option]
			if not opt then return end
			self.Value = option
			for name, o in self.Options do
				o.Selected = (name == option)
				toggleOption(o, o.Selected)
			end
		end
		Library.Flags[self.Flag] = self.Value
		refreshText()
		if data.Callback then Library:SafeCall(data.Callback, self.Value) end
	end

	function self:Add(name: string)
		local btn = Create("TextButton", { Parent = popup.Frame, FontFace = GetFont(), TextSize = 12,
			Text = name, AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0,
			TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 15), ZIndex = 51,
			TextColor3 = Color3.fromRGB(235, 235, 235), ThemeTag = { TextColor3 = "Text" } })
		local opt = { Button = btn, Name = name, Selected = false }
		maid:GiveTask(btn.MouseButton1Click:Connect(function()
			if data.Multi then
				local idx = table.find(self.Value, name)
				if idx then table.remove(self.Value, idx) else table.insert(self.Value, name) end
				opt.Selected = idx == nil
				toggleOption(opt, opt.Selected)
				Library.Flags[self.Flag] = self.Value
				refreshText()
				if data.Callback then Library:SafeCall(data.Callback, self.Value) end
			else
				if self.Value == name then
					self.Value = nil
					opt.Selected = false
					toggleOption(opt, false)
					Library.Flags[self.Flag] = nil
					refreshText()
					if data.Callback then Library:SafeCall(data.Callback, nil) end
				else
					self:Set(name)
				end
			end
		end))
		self.Options[name] = opt
		return opt
	end

	function self:Remove(name)
		local opt = self.Options[name]
		if opt then opt.Button:Destroy(); self.Options[name] = nil end
	end

	function self:Refresh(list)
		for name in self.Options do self:Remove(name) end
		for _, v in list do self:Add(v) end
	end

	maid:GiveTask(box.MouseButton1Click:Connect(function() self:SetOpen(not self.IsOpen) end))
	maid:GiveTask(box.MouseEnter:Connect(function()
		Theme.Retag(box, { BackgroundColor3 = "Hovered Element" })
		Tween.To(box, { BackgroundColor3 = Theme.Values["Hovered Element"] })
	end))
	maid:GiveTask(box.MouseLeave:Connect(function()
		Theme.Retag(box, { BackgroundColor3 = "Element" })
		Tween.To(box, { BackgroundColor3 = Theme.Values.Element })
	end))

	if searchInput then
		maid:GiveTask(searchInput:GetPropertyChangedSignal("Text"):Connect(function()
			local q = searchInput.Text:lower()
			for name, opt in self.Options do
				opt.Button.Visible = q == "" or (name:lower():find(q, 1, true) ~= nil)
			end
		end))
	end

	for _, v in (data.Items or {}) do self:Add(v) end
	refreshText()
	if data.Default then self:Set(data.Default) end
	Library._setters[self.Flag] = function(v) self:Set(v) end
	if data.Tooltip then Tooltip.Bind(container, data.Tooltip, maid) end
	return self
end

----------------------------------------------------------------- Colorpicker ---
function Components.Colorpicker(data)
	local maid = data.Maid
	local self = {
		Flag = data.Flag, IsOpen = false,
		Hue = 0, Sat = 0, Val = 1, Alpha = data.Alpha or 0,
		Color = Color3.fromRGB(255, 255, 255), HexValue = "ffffff",
	}

	-- swatch button (placed inline, e.g. inside a Label/Toggle sub-element row)
	local swatch = Create("TextButton", { Parent = data.Parent, Text = "", AutoButtonColor = false,
		Size = UDim2.fromOffset(15, 15), BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255), ThemeTag = { BorderColor3 = "Border" } })
	Stroke(swatch, "Outline")
	Corner(swatch, 3)

	local win = Create("Frame", { Parent = UnusedHolder, Visible = false,
		Size = UDim2.fromOffset(220, 200), BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(14, 17, 15), ZIndex = 60,
		ThemeTag = { BackgroundColor3 = "Background", BorderColor3 = "Border" } })
	Stroke(win, "Outline")
	maid:GiveTask(win)
	Create("UIPadding", { Parent = win, PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })

	-- palette (saturation/value)
	local palette = Create("TextButton", { Parent = win, Text = "", AutoButtonColor = false,
		Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -28, 1, -28), BorderSizePixel = 2,
		BorderColor3 = Color3.fromRGB(12, 12, 12), BackgroundColor3 = Color3.fromRGB(255, 0, 0), ZIndex = 61 })
	local satImg = Library:GetImage("Saturation")
	local valImg = Library:GetImage("Value")
	if satImg ~= "" then
		Create("ImageLabel", { Parent = palette, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
			Image = satImg, ZIndex = 62 })
	end
	if valImg ~= "" then
		Create("ImageLabel", { Parent = palette, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
			Image = valImg, ZIndex = 63 })
	end
	local paletteDot = Create("Frame", { Parent = palette, Size = UDim2.fromOffset(4, 4), ZIndex = 64,
		BorderColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 1, BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		AnchorPoint = Vector2.new(0.5, 0.5) })

	-- hue strip
	local hue = Create("TextButton", { Parent = win, Text = "", AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 20, 1, -28),
		BorderSizePixel = 2, BorderColor3 = Color3.fromRGB(12, 12, 12), ZIndex = 61,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255) })
	Create("UIGradient", { Parent = hue, Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
		ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255,255,0)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0,255,0)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0,255,255)),
		ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0,0,255)),
		ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255,0,255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,0)),
	}) })
	local hueDot = Create("Frame", { Parent = hue, Size = UDim2.new(1, 0, 0, 2), ZIndex = 62,
		BorderColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 1, BackgroundColor3 = Color3.fromRGB(255, 255, 255) })

	-- alpha bar
	local alpha = Create("TextButton", { Parent = win, Text = "", AutoButtonColor = false,
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, -28, 0, 20),
		BorderSizePixel = 2, BorderColor3 = Color3.fromRGB(12, 12, 12), ZIndex = 61,
		BackgroundColor3 = Color3.fromRGB(255, 0, 0) })
	local checkers = Library:GetImage("Checkers")
	if checkers ~= "" then
		local c = Create("ImageLabel", { Parent = alpha, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
			ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(6, 6), Image = checkers, ZIndex = 60 })
		Create("UIGradient", { Parent = c, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.37, 0.5),
			NumberSequenceKeypoint.new(1, 0),
		}) })
	end
	local alphaDot = Create("Frame", { Parent = alpha, Size = UDim2.new(0, 2, 1, 0), ZIndex = 62,
		BorderColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 1, BackgroundColor3 = Color3.fromRGB(255, 255, 255) })

	function self:Get() return self.Color, self.Alpha end
	function self:SetVisibility(b) swatch.Visible = b end

	local function update(fromAlpha)
		self.Color = Color3.fromHSV(self.Hue, self.Sat, self.Val)
		self.HexValue = self.Color:ToHex()
		Library.Flags[self.Flag] = { Color = self.HexValue, Alpha = self.Alpha }
		Tween.To(swatch, { BackgroundColor3 = self.Color })
		palette.BackgroundColor3 = Color3.fromHSV(self.Hue, 1, 1)
		if not fromAlpha then alpha.BackgroundColor3 = self.Color end
		if data.Callback then Library:SafeCall(data.Callback, self.Color, self.Alpha) end
	end

	function self:Set(color, a)
		-- capture alpha BEFORE reassigning color (original bug #2)
		if type(color) == "table" then
			a = a or color[4]
			color = Color3.fromRGB(color[1], color[2], color[3])
		elseif type(color) == "string" then
			color = Color3.fromHex((color:gsub("#", "")))
		end
		self.Hue, self.Sat, self.Val = color:ToHSV()
		self.Alpha = a or self.Alpha or 0
		paletteDot.Position = UDim2.fromScale(self.Sat, 1 - self.Val)
		hueDot.Position = UDim2.fromScale(0, math.clamp(self.Hue, 0, 0.995))
		alphaDot.Position = UDim2.fromScale(math.clamp(self.Alpha, 0, 0.995), 0)
		update(false)
	end

	-- popup open/close via generic fade
	local debounce = false
	function self:SetOpen(open)
		if debounce or open == self.IsOpen then return end
		self.IsOpen = open
		debounce = true
		if open then
			CloseAllPopups(self)
			OpenPopups[self] = true
			win.Visible = true
			win.Parent = Holder
			Anchors[win] = function()
				local ap, as = swatch.AbsolutePosition, swatch.AbsoluteSize
				win.Position = UDim2.fromOffset(ap.X, ap.Y + as.Y + 6)
			end
		else
			OpenPopups[self] = nil
			Anchors[win] = nil
		end
		local last = Tween.Fade(win, open, Config.FadeSpeed)
		local function done()
			debounce = false
			win.Visible = self.IsOpen
			if not self.IsOpen then win.Parent = UnusedHolder end
		end
		if last then last.Completed:Once(done) else done() end
	end

	-- dragging the palette / hue / alpha
	local function bindDrag(button, onMove)
		local active = false
		maid:GiveTask(button.InputBegan:Connect(function(input)
			if Input.isPrimary(input) then
				active = true
				onMove()
				local conn
				conn = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then active = false conn:Disconnect() end
				end)
			end
		end))
		maid:GiveTask(Input.On("Changed", function(input)
			if active and Input.isMove(input) then onMove() end
		end))
	end

	bindDrag(palette, function()
		local m = UserInputService:GetMouseLocation()
		local sx = math.clamp((m.X - palette.AbsolutePosition.X) / palette.AbsoluteSize.X, 0, 1)
		local sy = math.clamp((m.Y - palette.AbsolutePosition.Y) / palette.AbsoluteSize.Y, 0, 1)
		self.Sat, self.Val = sx, 1 - sy
		paletteDot.Position = UDim2.fromScale(sx, sy)
		update(false)
	end)
	bindDrag(hue, function()
		local m = UserInputService:GetMouseLocation()
		local hy = math.clamp((m.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 1)
		self.Hue = hy
		hueDot.Position = UDim2.fromScale(0, math.min(hy, 0.995))
		update(false)
	end)
	bindDrag(alpha, function()
		local m = UserInputService:GetMouseLocation()
		local ax = math.clamp((m.X - alpha.AbsolutePosition.X) / alpha.AbsoluteSize.X, 0, 1)
		self.Alpha = ax
		alphaDot.Position = UDim2.fromScale(math.min(ax, 0.995), 0)
		update(true)
	end)

	maid:GiveTask(swatch.MouseButton1Click:Connect(function() self:SetOpen(not self.IsOpen) end))
	maid:GiveTask(Input.On("Began", function(input)
		if not self.IsOpen or not Input.isPrimary(input) then return end
		if isMouseOver(win) or isMouseOver(swatch) then return end
		self:SetOpen(false)
	end))

	self:Set(data.Default or Color3.fromRGB(255, 255, 255), data.Alpha or 0)
	Library.Colorpickers[self] = self
	Library._setters[self.Flag] = function(v, a) self:Set(v, a) end
	return self
end

-------------------------------------------------------------------- Keybind ---
local KEY_DISPLAY = {
	RightControl = "RControl", LeftControl = "LControl", RightShift = "RShift", LeftShift = "LShift",
	LeftAlt = "LAlt", RightAlt = "RAlt", Backspace = "None", Return = "Enter", Escape = "Esc",
	MouseButton1 = "MB1", MouseButton2 = "MB2", MouseButton3 = "MB3",
}

function Components.Keybind(data)
	local maid = data.Maid
	local self = { Flag = data.Flag, Key = "", Value = "None", Mode = data.Mode or "Toggle",
		Toggled = false, Picking = false, IsOpen = false }

	local keyListEntry
	if Library.KeyList then keyListEntry = Library.KeyList:Add("None", data.Name or "Keybind", self.Mode) end

	local btn = Create("TextButton", { Parent = data.Parent, FontFace = GetFont(), TextSize = 12,
		Text = "[None]", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextTransparency = 0.35,
		TextColor3 = Color3.fromRGB(235, 235, 235), ThemeTag = { TextColor3 = "Text" } })
	TextStroke(btn)

	-- mode picker popup
	local win = Create("Frame", { Parent = UnusedHolder, Visible = false, Size = UDim2.fromOffset(80, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(14, 17, 15), ZIndex = 60,
		ThemeTag = { BackgroundColor3 = "Background", BorderColor3 = "Border" } })
	Stroke(win, "Outline")
	maid:GiveTask(win)
	Create("UIListLayout", { Parent = win, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
	Create("UIPadding", { Parent = win, PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })

	local modeButtons = {}
	for _, mode in { "Toggle", "Hold", "Always" } do
		local mb = Create("TextButton", { Parent = win, FontFace = GetFont(), TextSize = 12, Text = mode,
			AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 18), BorderSizePixel = 0, ZIndex = 61,
			BackgroundColor3 = Color3.fromRGB(202, 243, 255), TextColor3 = Color3.fromRGB(235, 235, 235),
			ThemeTag = { BackgroundColor3 = "Accent", TextColor3 = "Text" } })
		TextStroke(mb)
		modeButtons[mode] = mb
		maid:GiveTask(mb.MouseButton1Click:Connect(function() self:SetMode(mode) end))
	end

	local function flagState()
		Library.Flags[self.Flag] = { Key = self.Key, Mode = self.Mode, Toggled = self.Toggled }
	end

	function self:Get() return self.Key, self.Mode, self.Toggled end
	function self:SetMode(mode)
		self.Mode = mode
		for m, mb in modeButtons do
			Tween.To(mb, { BackgroundTransparency = (m == mode) and 0 or 1 })
		end
		flagState()
		if keyListEntry then keyListEntry:SetText(self.Value, data.Name or "Keybind", self.Mode) end
		if data.Callback then Library:SafeCall(data.Callback, self.Toggled) end
	end

	local function display(key: string): string
		return KEY_DISPLAY[key] or key
	end

	function self:Set(key)
		if typeof(key) == "EnumItem" then
			local name = key.Name
			self.Key = tostring(key)
			self.Value = (name == "Backspace") and "None" or name
			btn.Text = "[" .. display(self.Value) .. "]"
			flagState()
		elseif type(key) == "table" then
			self.Key = tostring(key.Key)
			self.Value = display(tostring(key.Key):gsub("Enum.KeyCode.", ""):gsub("Enum.UserInputType.", ""))
			-- normalize value from the stored Enum string
			local clean = tostring(key.Key):gsub("Enum%.KeyCode%.", ""):gsub("Enum%.UserInputType%.", "")
			self.Value = display(clean)
			btn.Text = "[" .. self.Value .. "]"
			if key.Mode then self:SetMode(key.Mode) end
			if key.Toggled ~= nil then self.Toggled = key.Toggled end
			flagState()
		elseif type(key) == "string" and (key == "Toggle" or key == "Hold" or key == "Always") then
			self:SetMode(key)
		end
		if keyListEntry then keyListEntry:SetText(self.Value, data.Name or "Keybind", self.Mode) end
		self.Picking = false
		if data.Callback then Library:SafeCall(data.Callback, self.Toggled) end
	end

	function self:Press(state)
		if self.Mode == "Toggle" then self.Toggled = not self.Toggled
		elseif self.Mode == "Hold" then self.Toggled = state
		elseif self.Mode == "Always" then self.Toggled = true end
		flagState()
		if keyListEntry then keyListEntry:SetStatus(self.Toggled) end
		if data.Callback then Library:SafeCall(data.Callback, self.Toggled) end
	end

	local debounce = false
	function self:SetOpen(open)
		if debounce or open == self.IsOpen then return end
		self.IsOpen = open
		debounce = true
		if open then
			CloseAllPopups(self)
			OpenPopups[self] = true
			win.Visible = true; win.Parent = Holder
			Anchors[win] = function()
				local ap, as = btn.AbsolutePosition, btn.AbsoluteSize
				win.Position = UDim2.fromOffset(ap.X, ap.Y + as.Y + 6)
			end
		else
			OpenPopups[self] = nil; Anchors[win] = nil
		end
		local last = Tween.Fade(win, open, Config.FadeSpeed)
		local function done()
			debounce = false
			win.Visible = self.IsOpen
			if not self.IsOpen then win.Parent = UnusedHolder end
		end
		if last then last.Completed:Once(done) else done() end
	end

	maid:GiveTask(btn.MouseButton1Click:Connect(function()
		self.Picking = true
		btn.Text = "[...]"
		local conn
		conn = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				self:Set(input.KeyCode)
			else
				self:Set(input.UserInputType)
			end
			conn:Disconnect()
		end)
		maid:GiveTask(conn)
	end))
	maid:GiveTask(btn.MouseButton2Click:Connect(function() self:SetOpen(not self.IsOpen) end))

	maid:GiveTask(Input.On("Began", function(input)
		if self.Value == "None" then return end
		local id = (input.KeyCode ~= Enum.KeyCode.Unknown) and tostring(input.KeyCode) or tostring(input.UserInputType)
		if id == self.Key then
			if self.Mode == "Toggle" then self:Press()
			elseif self.Mode == "Hold" then self:Press(true)
			elseif self.Mode == "Always" then self:Press(true) end
		end
		if Input.isPrimary(input) and self.IsOpen and not isMouseOver(win) and not isMouseOver(btn) then
			self:SetOpen(false)
		end
	end))
	maid:GiveTask(Input.On("Ended", function(input)
		if self.Value == "None" or self.Mode ~= "Hold" then return end
		local id = (input.KeyCode ~= Enum.KeyCode.Unknown) and tostring(input.KeyCode) or tostring(input.UserInputType)
		if id == self.Key then self:Press(false) end
	end))

	self:SetMode(self.Mode)
	if data.Default then self:Set({ Key = data.Default, Mode = self.Mode }) end
	Library._setters[self.Flag] = function(v) self:Set(v) end
	return self
end

--==============================================================================
-- Window / Tab / Section
--==============================================================================

function Library:Window(data: WindowConfig?)
	data = data or {}
	if data.Keybind then Config.MenuKeybind = data.Keybind end
	local maid = Maid.new()
	LibMaid:GiveTask(maid)

	local window = {
		Maid = maid,
		Tabs = {},
		FadeTime = data.FadeTime or 0.3,
		IsOpen = false,
		CurrentTab = nil,
	}

	local size = data.Size or UDim2.fromOffset(720, 520)

	local root = Create("Frame", { Parent = Holder, Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = size,
		BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(14, 17, 15),
		ThemeTag = { BackgroundColor3 = "Background", BorderColor3 = "Border" } })
	Stroke(root, "Outline")
	Corner(root, 6)
	MakeDraggable(root, root, maid)
	if data.Resizable ~= false then MakeResizable(root, Vector2.new(560, 360), maid) end

	-- side bar
	local side = Create("Frame", { Parent = root, Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(0, 190, 1, -24), BorderColor3 = Color3.fromRGB(42, 49, 45), BorderSizePixel = 2,
		BackgroundColor3 = Color3.fromRGB(20, 24, 21), ThemeTag = { BackgroundColor3 = "Inline", BorderColor3 = "Outline" } })
	Stroke(side, "Border")
	Corner(side)

	if data.Logo and data.Logo ~= "" then
		Create("ImageLabel", { Parent = side, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(72, 72), ScaleType = Enum.ScaleType.Fit,
			Image = "rbxassetid://" .. data.Logo, ImageColor3 = Color3.fromRGB(202, 243, 255),
			ThemeTag = { ImageColor3 = "Accent" } })
	end
	MakeText(side, data.Title or "VibeUI", { AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, (data.Logo and data.Logo ~= "") and 90 or 14), Size = UDim2.new(1, -16, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Center, TextSize = 14 })

	local tabHolder = Create("Frame", { Parent = side, BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, (data.Logo and data.Logo ~= "") and 112 or 40),
		Size = UDim2.new(1, 0, 1, -((data.Logo and data.Logo ~= "") and 124 or 52)) })
	Create("UIPadding", { Parent = tabHolder, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
	Create("UIListLayout", { Parent = tabHolder, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })

	-- content area
	local content = Create("Frame", { Parent = root, BackgroundTransparency = 1,
		Position = UDim2.fromOffset(214, 12), Size = UDim2.new(1, -226, 1, -24) })

	if CursorBg then CursorBg.Visible = true end

	function window:SetOpen(open)
		self.IsOpen = open
		if open then root.Visible = true end
		local last = Tween.Fade(root, open, Config.FadeSpeed)
		local function done()
			root.Visible = self.IsOpen
			if CursorBg then CursorBg.Visible = self.IsOpen end
			UserInputService.MouseIconEnabled = (not Config.CustomCursor) or (not self.IsOpen)
		end
		if last then last.Completed:Once(done) else done() end
	end

	maid:GiveTask(Input.On("Began", function(input)
		local id = (input.KeyCode ~= Enum.KeyCode.Unknown) and input.KeyCode or input.UserInputType
		if id == Config.MenuKeybind then
			window:SetOpen(not window.IsOpen)
		end
	end))

	--------------------------------------------------------------- Tab ---
	function window:Tab(tabData)
		tabData = tabData or {}
		local tab = { Sections = { ColumnsData = {} }, Active = false, Columns = tabData.Columns or 2 }

		local btn = Create("TextButton", { Parent = tabHolder, Text = "", AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 25), BorderColor3 = Color3.fromRGB(12, 12, 12), BorderSizePixel = 2,
			BackgroundTransparency = 0.6, BackgroundColor3 = Color3.fromRGB(25, 30, 26),
			ThemeTag = { BackgroundColor3 = "Page Background", BorderColor3 = "Border" } })
		Stroke(btn, "Outline", 0.6)
		Corner(btn)
		local liner = Create("Frame", { Parent = btn, Size = UDim2.new(0, 1, 1, 0), BorderSizePixel = 0,
			BackgroundTransparency = 1, BackgroundColor3 = Color3.fromRGB(202, 243, 255),
			ThemeTag = { BackgroundColor3 = "Accent" } })
		local label = MakeText(btn, tabData.Name or "Tab", { AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.new(0, 0, 0, 15),
			TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.X })

		local page = Create("Frame", { Parent = content, BackgroundTransparency = 1, Visible = false,
			Size = UDim2.fromScale(1, 1) })
		Create("UIListLayout", { Parent = page, FillDirection = Enum.FillDirection.Horizontal,
			HorizontalFlex = Enum.UIFlexAlignment.Fill, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder })
		for i = 1, tab.Columns do
			local col = Create("ScrollingFrame", { Parent = page, BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1), ScrollBarThickness = 0, BorderSizePixel = 0,
				CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y })
			Create("UIListLayout", { Parent = col, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder })
			Create("UIPadding", { Parent = col, PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2),
				PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2) })
			tab.Sections.ColumnsData[i] = col
		end

		local switching = false
		function tab:Turn(on)
			if switching then return end
			tab.Active = on
			switching = true
			page.Visible = on
			page.Parent = on and content or UnusedHolder
			Tween.To(btn, { BackgroundTransparency = on and 0 or 0.6 })
			Tween.To(liner, { BackgroundTransparency = on and 0 or 1 })
			Tween.To(label, { Position = UDim2.new(0, on and 13 or 8, 0.5, 0) })
			if on then window.CurrentTab = tab end
			local last = Tween.Fade(page, on, window.FadeTime)
			if last then last.Completed:Once(function() switching = false end) else switching = false end
		end

		maid:GiveTask(btn.MouseButton1Click:Connect(function()
			if tab.Active then return end
			for _, t in window.Tabs do t:Turn(t == tab) end
		end))
		maid:GiveTask(btn.MouseEnter:Connect(function()
			if not tab.Active then
				Theme.Retag(btn, { BackgroundColor3 = "Hovered Element" })
				Tween.To(btn, { BackgroundColor3 = Theme.Values["Hovered Element"] })
			end
		end))
		maid:GiveTask(btn.MouseLeave:Connect(function()
			if not tab.Active then
				Theme.Retag(btn, { BackgroundColor3 = "Page Background" })
				Tween.To(btn, { BackgroundColor3 = Theme.Values["Page Background"] })
			end
		end))

		----------------------------------------------------- Section ---
		function tab:Section(secData)
			secData = secData or {}
			local section = {}
			local parentCol = tab.Sections.ColumnsData[secData.Side or 1]

			local box = Create("Frame", { Parent = parentCol, Size = UDim2.new(1, 0, 0, 25),
				BorderColor3 = Color3.fromRGB(42, 49, 45), BorderSizePixel = 2, AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Color3.fromRGB(20, 24, 21),
				ThemeTag = { BackgroundColor3 = "Inline", BorderColor3 = "Outline" } })
			Stroke(box, "Border")
			Corner(box)
			Create("Frame", { Parent = box, Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0,
				BackgroundColor3 = Color3.fromRGB(202, 243, 255), ThemeTag = { BackgroundColor3 = "Accent" } })
			MakeText(box, secData.Name or "Section", { Position = UDim2.fromOffset(8, 5), Size = UDim2.new(0, 0, 0, 15),
				AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Left })
			Create("UIPadding", { Parent = box, PaddingBottom = UDim.new(0, 8) })
			local cont = Create("Frame", { Parent = box, BackgroundTransparency = 1,
				Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y })
			Create("UIListLayout", { Parent = cont, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })

			local function withParent(cfg) cfg = cfg or {}; cfg.Parent = cont; cfg.Maid = maid; return cfg end

			function section:Toggle(c)
				c = withParent(c); c.Flag = c.Flag or Library:NextFlag()
				local t = Components.Toggle(c)
				function t:AddColorpicker(cc)
					cc = cc or {}; cc.Parent = self._sub; cc.Maid = maid; cc.Flag = cc.Flag or Library:NextFlag()
					return Components.Colorpicker(cc)
				end
				function t:AddKeybind(cc)
					cc = cc or {}; cc.Parent = self._sub; cc.Maid = maid; cc.Flag = cc.Flag or Library:NextFlag()
					cc.Name = cc.Name or c.Name
					return Components.Keybind(cc)
				end
				return t
			end
			function section:Button(c) return Components.Button(withParent(c)) end
			function section:Slider(c) c = withParent(c); c.Flag = c.Flag or Library:NextFlag(); return Components.Slider(c) end
			function section:Dropdown(c) c = withParent(c); c.Flag = c.Flag or Library:NextFlag(); return Components.Dropdown(c) end
			function section:Searchbox(c) c = withParent(c); c.Search = true; c.Flag = c.Flag or Library:NextFlag(); return Components.Dropdown(c) end
			function section:Textbox(c) c = withParent(c); c.Flag = c.Flag or Library:NextFlag(); return Components.Textbox(c) end
			function section:Paragraph(c) return Components.Paragraph(withParent(c)) end
			function section:Divider() return Components.Divider(withParent({})) end
			function section:Label(c)
				if type(c) == "string" then c = { Name = c } end
				c = withParent(c)
				local l = Components.Label(c)
				function l:AddColorpicker(cc)
					cc = cc or {}; cc.Parent = self._sub; cc.Maid = maid; cc.Flag = cc.Flag or Library:NextFlag()
					return Components.Colorpicker(cc)
				end
				function l:AddKeybind(cc)
					cc = cc or {}; cc.Parent = self._sub; cc.Maid = maid; cc.Flag = cc.Flag or Library:NextFlag()
					cc.Name = cc.Name or c.Name
					return Components.Keybind(cc)
				end
				return l
			end

			return section
		end

		if #window.Tabs == 0 then task.defer(function() tab:Turn(true) end) end
		table.insert(window.Tabs, tab)
		return tab
	end

	window:SetOpen(true)
	return setmetatable(window, Library)
end

--==============================================================================
-- Watermark / KeybindList / Notifications
--==============================================================================

function Library:Watermark(text: string)
	local maid = LibMaid
	local frame = Create("Frame", { Parent = Holder, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12), AutomaticSize = Enum.AutomaticSize.XY, BorderSizePixel = 2,
		BorderColor3 = Color3.fromRGB(12, 12, 12), BackgroundColor3 = Color3.fromRGB(14, 17, 15),
		ThemeTag = { BackgroundColor3 = "Background", BorderColor3 = "Border" } })
	Stroke(frame, "Outline")
	Corner(frame)
	MakeDraggable(frame, frame, maid)
	Create("Frame", { Parent = frame, Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(202, 243, 255), ThemeTag = { BackgroundColor3 = "Accent" } })
	Create("UIPadding", { Parent = frame, PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
	local label = MakeText(frame, text, { AutomaticSize = Enum.AutomaticSize.XY,
		TextXAlignment = Enum.TextXAlignment.Left })
	return {
		SetText = function(_, t) label.Text = t end,
		SetVisibility = function(_, b) frame.Visible = b end,
	}
end

function Library:KeybindList()
	local list = {}
	Library.KeyList = list
	local frame = Create("Frame", { Parent = Holder, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 55), Size = UDim2.fromOffset(140, 32), BorderSizePixel = 2,
		AutomaticSize = Enum.AutomaticSize.Y, BorderColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundColor3 = Color3.fromRGB(14, 17, 15),
		ThemeTag = { BackgroundColor3 = "Background", BorderColor3 = "Border" } })
	Stroke(frame, "Outline")
	Corner(frame)
	MakeDraggable(frame, frame, LibMaid)
	Create("UIPadding", { Parent = frame, PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
	MakeText(frame, "Keybinds", { Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left })
	Create("Frame", { Parent = frame, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 1),
		AnchorPoint = Vector2.new(0, 0), BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(202, 243, 255),
		ThemeTag = { BackgroundColor3 = "Accent" } })
	local body = Create("Frame", { Parent = frame, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	Create("UIListLayout", { Parent = body, SortOrder = Enum.SortOrder.LayoutOrder })

	function list:Add(key, name, mode)
		local entry = MakeText(body, ("%s - %s (%s)"):format(key, name, mode), {
			Size = UDim2.new(1, 0, 0, 15), AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Left, Visible = false, TextTransparency = 1 })
		return {
			Instance = entry,
			SetText = function(_, k, n, m) entry.Text = ("%s - %s (%s)"):format(k, n, m) end,
			SetStatus = function(_, on)
				if on then entry.Visible = true; Tween.To(entry, { TextTransparency = 0 })
				else Tween.To(entry, { TextTransparency = 1 }).Completed:Once(function() entry.Visible = false end) end
			end,
		}
	end
	function list:SetVisibility(b) frame.Visible = b end
	return list
end

local NOTIF_ACCENT = {
	info    = function() return Theme.Values.Accent end,
	success = function() return Color3.fromRGB(120, 230, 150) end,
	warning = function() return Color3.fromRGB(245, 205, 110) end,
	error   = function() return Color3.fromRGB(245, 120, 120) end,
}

function Library:Notification(title: string, description: string?, duration: number?, kind: string?)
	duration = duration or 5
	local accent = (NOTIF_ACCENT[kind] or NOTIF_ACCENT.info)()

	local frame = Create("Frame", { Parent = NotifHolder, Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY, BorderSizePixel = 2, BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(12, 12, 12), BackgroundColor3 = Color3.fromRGB(14, 17, 15),
		ThemeTag = { BackgroundColor3 = "Background", BorderColor3 = "Border" } })
	local s = Stroke(frame, "Outline"); s.Transparency = 1
	Corner(frame)
	Create("UIPadding", { Parent = frame, PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
	local titleLabel = MakeText(frame, title, { AutomaticSize = Enum.AutomaticSize.XY,
		TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1 })
	local descLabel
	if description and description ~= "" then
		descLabel = MakeText(frame, description, { Position = UDim2.fromOffset(0, 15),
			AutomaticSize = Enum.AutomaticSize.XY, TextXAlignment = Enum.TextXAlignment.Left,
			TextTransparency = 1, TextColor3 = Color3.fromRGB(185, 185, 185),
			ThemeTag = { TextColor3 = "Placeholder Text" } })
	end
	local liner = Create("Frame", { Parent = frame, Position = UDim2.new(0, 0, 1, 6),
		Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, BackgroundColor3 = accent, BackgroundTransparency = 1 })

	-- fade in
	Tween.To(frame, { BackgroundTransparency = 0 })
	Tween.To(s, { Transparency = 0 })
	Tween.To(titleLabel, { TextTransparency = 0 })
	if descLabel then Tween.To(descLabel, { TextTransparency = 0.3 }) end
	liner.BackgroundTransparency = 0
	Tween.To(liner, { Size = UDim2.new(0, 0, 0, 1) }, Tween.Info(duration, Enum.EasingStyle.Linear))

	task.delay(duration + 0.1, function()
		Tween.To(frame, { BackgroundTransparency = 1 })
		Tween.To(s, { Transparency = 1 })
		Tween.To(titleLabel, { TextTransparency = 1 })
		if descLabel then Tween.To(descLabel, { TextTransparency = 1 }) end
		Tween.To(liner, { BackgroundTransparency = 1 })
		task.delay(0.4, function() frame:Destroy() end)
	end)
end

--==============================================================================
-- Settings page (Theming / Configs / Settings)
--==============================================================================

function Library:CreateSettingsPage(window, watermark, keybindList)
	local tab = window:Tab({ Name = "Settings", Columns = 2 })

	-- Theming
	local themeSection = tab:Section({ Name = "Theme presets", Side = 1 })
	local presetNames = {}
	for name in Presets do table.insert(presetNames, name) end
	themeSection:Dropdown({ Name = "Preset", Flag = "ThemePreset", Items = presetNames, Default = "Midnight",
		Callback = function(name)
			if Presets[name] then Theme.Load(Presets[name]) end
		end })

	local colorsSection = tab:Section({ Name = "Theme colors", Side = 1 })
	for key, value in Theme.Values do
		colorsSection:Label(key):AddColorpicker({
			Flag = key .. "_Theme", Default = value,
			Callback = function(color) Theme.Set(key, color) end,
		})
	end

	-- Configs
	if HasFileSystem then
		local cfgSection = tab:Section({ Name = "Configs", Side = 2 })
		local cfgName, cfgSelected
		local cfgList = cfgSection:Searchbox({ Name = "Configs", Flag = "ConfigList", Items = Library:ListConfigs(),
			Callback = function(v) cfgSelected = v end })
		cfgSection:Textbox({ Name = "Config name", Flag = "ConfigName", Placeholder = "name..",
			Callback = function(v) cfgName = v end })
		local cd = cfgSection:Button()
		cd:Add("Create", function()
			if cfgName and cfgName ~= "" then
				if Library:SaveConfig(cfgName) then
					Library:Notification("Configs", "Created '" .. cfgName .. "'", 4, "success")
					cfgList:Refresh(Library:ListConfigs())
				end
			end
		end)
		cd:Add("Delete", function()
			if cfgSelected then
				Library:DeleteConfig(cfgSelected)
				Library:Notification("Configs", "Deleted '" .. cfgSelected .. "'", 4, "warning")
				cfgList:Refresh(Library:ListConfigs())
			end
		end)
		local ls = cfgSection:Button()
		ls:Add("Load", function()
			if cfgSelected then
				local raw = Library:ReadConfig(cfgSelected)
				if raw then
					local ok, err = Library:LoadConfig(raw)
					if ok then Library:Notification("Configs", "Loaded '" .. cfgSelected .. "'", 4, "success")
					else Library:Notification("Configs", "Load failed: " .. tostring(err), 6, "error") end
				end
			end
		end)
		ls:Add("Save", function()
			if cfgSelected then
				Library:SaveConfig(cfgSelected)
				Library:Notification("Configs", "Saved '" .. cfgSelected .. "'", 4, "success")
			end
		end)
	end

	-- Settings
	local settingsSection = tab:Section({ Name = "Interface", Side = 2 })
	if watermark then
		settingsSection:Toggle({ Name = "Watermark", Flag = "ShowWatermark", Default = true,
			Callback = function(v) watermark:SetVisibility(v) end })
	end
	if keybindList then
		settingsSection:Toggle({ Name = "Keybind list", Flag = "ShowKeybinds", Default = true,
			Callback = function(v) keybindList:SetVisibility(v) end })
	end
	settingsSection:Toggle({ Name = "Custom cursor", Flag = "CustomCursor", Default = Config.CustomCursor,
		Callback = function(v)
			Config.CustomCursor = v
			if CursorBg then CursorBg.Visible = v end
			UserInputService.MouseIconEnabled = not v
		end })
	settingsSection:Slider({ Name = "Fade time", Flag = "FadeTime", Min = 0, Max = 1, Decimals = 0.01,
		Default = Config.FadeSpeed, Callback = function(v) Config.FadeSpeed = v end })
	settingsSection:Slider({ Name = "Tween time", Flag = "TweenTime", Min = 0, Max = 1, Decimals = 0.01,
		Default = Config.Tween.Time, Callback = function(v) Config.Tween.Time = v end })
	settingsSection:Dropdown({ Name = "Tween style", Flag = "TweenStyle",
		Items = { "Linear", "Quad", "Quart", "Cubic", "Sine", "Back", "Bounce", "Elastic", "Exponential" },
		Default = "Quad", Callback = function(v) Config.Tween.Style = Enum.EasingStyle[v] end })
	settingsSection:Label("Menu keybind"):AddKeybind({ Name = "Menu", Flag = "MenuKeybind",
		Default = Config.MenuKeybind, Mode = "Toggle",
		Callback = function()
			local f = Library.Flags["MenuKeybind"]
			if f and f.Key then
				local ok, enum = pcall(function() return Enum.KeyCode[(f.Key:gsub("Enum.KeyCode.", ""))] end)
				if ok then Config.MenuKeybind = enum end
			end
		end })
	settingsSection:Button():Add("Unload", function() Library:Unload() end)

	return tab
end

--==============================================================================
-- Unload
--==============================================================================

function Library:Unload()
	LibMaid:Clean()
	UserInputService.MouseIconEnabled = true
	if getgenv then getgenv().VibeUI = nil end
	shared.VibeUI = nil
end

--==============================================================================
-- Finalize
--==============================================================================

Input.Init()

if getgenv then getgenv().VibeUI = Library end
shared.VibeUI = Library

Library.LoadTime = os.clock() - LoadStart

return Library
