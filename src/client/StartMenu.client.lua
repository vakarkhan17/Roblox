--[[
	SIGNAL '85  —  Start menu, pause menu and mission briefing (client)
	Put this LocalScript in StarterPlayer > StarterPlayerScripts.

	After the intro broadcast:
	  title menu   CONTINUE (if saved) / NEW GAME / CHAPTER SELECT
	  briefing     picture cards of what to enter, collect, deliver, destroy
	               and avoid in the chapter, then START MISSION
	While playing: MENU button (key M) opens the pause menu with SAVE GAME,
	MISSION BRIEFING and CHAPTER SELECT. SAVE button (key K) saves directly.

	While a menu is open, Players.LocalPlayer has MenuActive = true;
	Signal85Client hides its HUD and ignores game input.
	The client only sends choices; the server loads saves and decides.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
player:SetAttribute("MenuActive", true) -- block the HUD from the start; the menu opens after the intro

local remotes = ReplicatedStorage:WaitForChild("Signal85Remotes")
local GetSave = remotes:WaitForChild("GetSave")
local ChooseStart = remotes:WaitForChild("ChooseStart")
local SaveGame = remotes:WaitForChild("SaveGame")
local Shop = remotes:WaitForChild("Shop")
local RewardEvent = remotes:WaitForChild("Reward")
local SettingsEvent = remotes:WaitForChild("Settings")
local ElevatorMenuEvent = remotes:WaitForChild("ElevatorMenu")
local ElevatorGoEvent = remotes:WaitForChild("ElevatorGo")

local AMBER = Color3.fromRGB(255, 214, 140)
local RED = Color3.fromRGB(255, 60, 70)
local CYAN = Color3.fromRGB(80, 220, 255)
local GREEN = Color3.fromRGB(60, 255, 140)
local YELLOW = Color3.fromRGB(255, 235, 140)
local DIM = Color3.fromRGB(120, 110, 120)
local BLACK = Color3.fromRGB(10, 8, 14)

local IS_PHONE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.zero
if viewport.X < 50 then
	viewport = IS_PHONE and Vector2.new(800, 390) or Vector2.new(1280, 720)
end
local SMALL_SCREEN = math.min(viewport.X, viewport.Y) <= 500
local CROSS = IS_PHONE and "tap RIFT" or "press E"
local FIRE = IS_PHONE and "hold BLAST" or "hold Q or the left mouse button"

---------------------------------------------------------------------------
-- UI helpers
---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "Signal85Menu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50 -- above the HUD, below the intro broadcast
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function make(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function text(parent, props)
	local l = make("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.Arcade, TextColor3 = AMBER, TextSize = 18,
		TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	}, parent)
	for k, v in pairs(props) do
		l[k] = v
	end
	return l
end

local function list(parent, padding, horizontal)
	return make("UIListLayout", {
		Padding = UDim.new(0, padding), SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
	}, parent)
end

local function pad(parent, px)
	make("UIPadding", { PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px), PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px) }, parent)
end

-- dark full-screen backdrop with a centred panel
local backdrop = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25, Visible = false, Active = true }, gui)
local panel = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.94, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = BLACK, BackgroundTransparency = 0.05, BorderSizePixel = 0,
}, backdrop)
make("UISizeConstraint", { MaxSize = Vector2.new(940, math.huge) }, panel)
make("UIStroke", { Color = AMBER, Thickness = 2 }, panel)
pad(panel, 16)
list(panel, 10)
if SMALL_SCREEN then
	make("UIScale", { Scale = 0.68 }, panel)
end

local toast = text(gui, {
	Text = "", TextSize = 22, TextColor3 = GREEN, TextStrokeTransparency = 0.3, Visible = false, ZIndex = 20,
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 160), Size = UDim2.new(0.8, 0, 0, 0),
})
local toastToken = 0
local function showToast(message, color)
	if not message or message == "" then
		return
	end
	toastToken = toastToken + 1
	local token = toastToken
	toast.Text = message
	toast.TextColor3 = color or GREEN
	toast.Visible = true
	task.delay(3, function()
		if token == toastToken then
			toast.Visible = false
		end
	end)
end

---------------------------------------------------------------------------
-- Keyboard / gamepad navigation: Up/Down (or W/S, D-pad) and Enter / A
---------------------------------------------------------------------------
local buttons = {}  -- buttons of the current screen, in order
local actions = {}  -- their click handlers, same order
local focus = 0

local function setFocus(index)
	for i, b in ipairs(buttons) do
		local stroke = b:FindFirstChildOfClass("UIStroke")
		local on = i == index
		stroke.Thickness = on and 4 or 2
		b.BackgroundColor3 = on and Color3.fromRGB(60, 40, 50) or Color3.fromRGB(30, 24, 36)
	end
	focus = index
end

local function button(parent, label, color, onClick, order)
	local b = make("TextButton", {
		Text = label, Font = Enum.Font.Arcade, TextSize = 24, TextColor3 = color or AMBER, TextWrapped = true,
		BackgroundColor3 = Color3.fromRGB(30, 24, 36), BorderSizePixel = 0, AutoButtonColor = true,
		Size = UDim2.new(0.8, 0, 0, 58), LayoutOrder = order or 0,
	}, parent)
	make("UISizeConstraint", { MaxSize = Vector2.new(480, 58) }, b)
	make("UIStroke", { Color = color or AMBER, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	table.insert(buttons, b)
	table.insert(actions, onClick)
	local index = #buttons
	b.MouseEnter:Connect(function()
		setFocus(index)
	end)
	b.Activated:Connect(onClick)
	return b
end

-- the character screen puts the panel on the right and points the camera at your character
local sideLayout = false
local function setSideLayout(on)
	if on == sideLayout then
		return
	end
	sideLayout = on
	backdrop.BackgroundTransparency = on and 1 or 0.25
	panel.AnchorPoint = on and Vector2.new(1, 0.5) or Vector2.new(0.5, 0.5)
	panel.Position = on and UDim2.new(1, -16, 0.5, 0) or UDim2.fromScale(0.5, 0.5)
	panel.Size = on and UDim2.new(0.46, 0, 0, 0) or UDim2.new(0.94, 0, 0, 0)
	local cam = workspace.CurrentCamera
	if not on then
		cam.CameraType = Enum.CameraType.Custom
	end
end

local function clearScreen()
	for _, child in ipairs(panel:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(buttons)
	table.clear(actions)
	focus = 0
	setSideLayout(false)
end

local function onNav(_, inputState, input)
	if inputState ~= Enum.UserInputState.Begin or #buttons == 0 then
		return Enum.ContextActionResult.Sink
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.Up or key == Enum.KeyCode.W or key == Enum.KeyCode.DPadUp then
		setFocus(focus <= 1 and #buttons or focus - 1)
	elseif key == Enum.KeyCode.Down or key == Enum.KeyCode.S or key == Enum.KeyCode.DPadDown then
		setFocus(focus >= #buttons and 1 or focus + 1)
	elseif actions[focus] then
		task.spawn(actions[focus]) -- Enter / Space / gamepad A: same as clicking
	end
	return Enum.ContextActionResult.Sink
end

---------------------------------------------------------------------------
-- 3D pictures for the briefing (ViewportFrames with simple part models)
---------------------------------------------------------------------------
local function part(model, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = model
	return p
end

local SHADOW = Color3.fromRGB(28, 22, 26)
local MAW = Color3.fromRGB(255, 40, 50)

local function hollower(scale, open)
	local m = Instance.new("Model")
	local S = scale
	part(m, { Size = Vector3.new(2.5, 5, 1.6) * S, Color = SHADOW, Material = Enum.Material.Slate, CFrame = CFrame.new() })
	part(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 3 * S, Color = SHADOW, Material = Enum.Material.Slate, CFrame = CFrame.new(0, 3.8 * S, 0) })
	part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1.7, 1.7) * S, Color = MAW, Material = Enum.Material.Neon,
		CFrame = CFrame.new(0, 3.8 * S, -1.45 * S) * CFrame.Angles(0, math.rad(90), 0) })
	if open then
		part(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1 * S, Color = YELLOW, Material = Enum.Material.Neon, CFrame = CFrame.new(0, 3.8 * S, -1.6 * S) })
	end
	for k = 1, 6 do
		local a = k * math.pi * 2 / 6
		local tilt = open and 0.3 or -0.6
		part(m, { Size = Vector3.new(1, 2.2, 0.2) * S, Color = Color3.fromRGB(60, 30, 36), Material = Enum.Material.Slate,
			CFrame = CFrame.new(0, 3.8 * S, -1.45 * S) * CFrame.Angles(0, 0, a) * CFrame.new(0, 1.3 * S, 0) * CFrame.Angles(tilt, 0, 0) * CFrame.new(0, 1.1 * S, 0) })
	end
	for _, side in ipairs({ -1, 1 }) do
		part(m, { Size = Vector3.new(0.5, 5.5, 0.5) * S, Color = SHADOW, Material = Enum.Material.Slate,
			CFrame = CFrame.new(side * 1.8 * S, -0.6 * S, -0.4 * S) * CFrame.Angles(0.3, 0, side * 0.15) })
		part(m, { Size = Vector3.new(0.7, 3, 0.7) * S, Color = SHADOW, Material = Enum.Material.Slate, CFrame = CFrame.new(side * 0.7 * S, -4 * S, 0) })
	end
	return m
end

local PICTURES = {
	rift = function()
		local m = Instance.new("Model")
		part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 18, 18), Color = Color3.fromRGB(255, 50, 60), Material = Enum.Material.Neon,
			CFrame = CFrame.Angles(0, math.rad(90), 0) })
		part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 15, 15), Color = Color3.fromRGB(5, 5, 10), Material = Enum.Material.Glass,
			CFrame = CFrame.Angles(0, math.rad(90), 0) })
		return m
	end,
	shard = function()
		local m = Instance.new("Model")
		part(m, { Size = Vector3.new(1.4, 3, 1.4), Color = CYAN, Material = Enum.Material.Neon, CFrame = CFrame.Angles(0, 0, 0.2) })
		return m
	end,
	console = function()
		local m = Instance.new("Model")
		part(m, { Size = Vector3.new(6, 4, 3), Color = GREEN, Material = Enum.Material.Neon, CFrame = CFrame.new() })
		for _, x in ipairs({ -4, 4 }) do
			part(m, { Size = Vector3.new(0.6, 12, 0.6), Color = Color3.fromRGB(180, 40, 40), Material = Enum.Material.Metal, CFrame = CFrame.new(x, 4, 3) })
		end
		return m
	end,
	hollower = function()
		return hollower(1, false)
	end,
	node = function()
		local m = Instance.new("Model")
		part(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 8, Color = Color3.fromRGB(30, 10, 14), Material = Enum.Material.Slate, Transparency = 0.3, CFrame = CFrame.new() })
		part(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 5.5, Color = Color3.fromRGB(210, 20, 40), Material = Enum.Material.Neon, CFrame = CFrame.new() })
		for k = 1, 7 do
			local a = k * math.pi * 2 / 7
			local from = Vector3.new(math.cos(a) * 2.5, -1.5, math.sin(a) * 2.5)
			local foot = Vector3.new(math.cos(a) * 10, -5, math.sin(a) * 10)
			local len = (foot - from).Magnitude
			part(m, { Size = Vector3.new(0.9, 0.9, len), Color = Color3.fromRGB(45, 14, 20), Material = Enum.Material.Slate,
				CFrame = CFrame.lookAt(from, foot) * CFrame.new(0, 0, -len / 2) })
		end
		return m
	end,
	boss = function()
		return hollower(2, true)
	end,
	shockwave = function()
		local m = Instance.new("Model")
		local segments = 28
		for i = 1, segments do
			local a = i / segments * math.pi * 2
			local pos = Vector3.new(math.cos(a) * 9, 0, math.sin(a) * 9)
			part(m, { Size = Vector3.new(1.2, 1.4, 2.4), Color = MAW, Material = Enum.Material.Neon,
				CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a))) })
		end
		-- a little Shiftframe jumping over it
		part(m, { Size = Vector3.new(2, 3, 1.2), Color = Color3.fromRGB(70, 92, 125), Material = Enum.Material.DiamondPlate, CFrame = CFrame.new(9, 5, 0) })
		part(m, { Size = Vector3.new(1.6, 0.4, 0.3), Color = CYAN, Material = Enum.Material.Neon, CFrame = CFrame.new(9, 6.6, -0.7) })
		return m
	end,
	cannon = function()
		local m = Instance.new("Model")
		part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1.6, 1.6), Color = Color3.fromRGB(40, 40, 46), Material = Enum.Material.Metal, CFrame = CFrame.new() })
		part(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, Color = CYAN, Material = Enum.Material.Neon, CFrame = CFrame.new(-2.1, 0, 0) })
		part(m, { Size = Vector3.new(10, 0.5, 0.5), Color = CYAN, Material = Enum.Material.Neon, CFrame = CFrame.new(-8, 0, 0) })
		part(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 4, Color = CYAN, Material = Enum.Material.Neon, Transparency = 0.4, CFrame = CFrame.new(-14, 0, 0) })
		return m
	end,
	file = function()
		local m = Instance.new("Model")
		part(m, { Size = Vector3.new(2.4, 0.4, 1.8), Color = Color3.fromRGB(255, 220, 120), Material = Enum.Material.Neon, CFrame = CFrame.Angles(0.5, 0.3, 0) })
		part(m, { Size = Vector3.new(0.8, 0.42, 0.3), Color = Color3.fromRGB(210, 180, 110), Material = Enum.Material.SmoothPlastic,
			CFrame = CFrame.Angles(0.5, 0.3, 0) * CFrame.new(-0.6, 0, -1) })
		return m
	end,
	relay = function()
		local m = Instance.new("Model")
		part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 18, 18), Color = Color3.fromRGB(255, 220, 120), Material = Enum.Material.Neon,
			Transparency = 0.4, CFrame = CFrame.Angles(0, 0, math.rad(90)) })
		part(m, { Size = Vector3.new(2, 10, 2), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal, CFrame = CFrame.new(0, 5, 0) })
		part(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 3, Color = GREEN, Material = Enum.Material.Neon, CFrame = CFrame.new(0, 11, 0) })
		part(m, { Size = Vector3.new(2, 3, 1.2), Color = Color3.fromRGB(70, 92, 125), Material = Enum.Material.DiamondPlate, CFrame = CFrame.new(4, 1.5, 2) })
		return m
	end,
	carrier = function()
		local m = Instance.new("Model")
		part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 12, 12), Color = Color3.fromRGB(50, 52, 58), Material = Enum.Material.DiamondPlate,
			CFrame = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)) })
		part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(16, 4, 4), Color = Color3.fromRGB(70, 72, 80), Material = Enum.Material.Metal,
			CFrame = CFrame.new(0, 10, 0) * CFrame.Angles(0, 0, math.rad(90)) })
		for i, y in ipairs({ 5, 10, 15 }) do
			part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 8 - i, 8 - i), Color = Color3.fromRGB(255, 120, 200), Material = Enum.Material.Neon,
				CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)) })
		end
		part(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 6, Color = Color3.fromRGB(255, 120, 200), Material = Enum.Material.Neon, CFrame = CFrame.new(0, 19, 0) })
		return m
	end,
	hound = function()
		local m = Instance.new("Model")
		local body = Color3.fromRGB(40, 44, 54)
		local static = Color3.fromRGB(200, 230, 255)
		part(m, { Size = Vector3.new(2.4, 1.6, 4.4), Color = body, Material = Enum.Material.Slate, CFrame = CFrame.new() })
		part(m, { Size = Vector3.new(1.6, 1.4, 1.8), Color = body, Material = Enum.Material.Slate, CFrame = CFrame.new(0, 0.5, -2.8) })
		for _, side in ipairs({ -1, 1 }) do
			part(m, { Size = Vector3.new(0.35, 0.25, 0.1), Color = static, Material = Enum.Material.Neon, CFrame = CFrame.new(side * 0.45, 0.75, -3.72) })
			for _, z in ipairs({ -1.6, 1.6 }) do
				part(m, { Size = Vector3.new(0.4, 1.8, 0.4), Color = body, Material = Enum.Material.Slate, CFrame = CFrame.new(side * 0.9, -1.4, z) })
			end
		end
		for k = 1, 4 do
			part(m, { Size = Vector3.new(0.2, 1, 0.2), Color = static, Material = Enum.Material.Neon, CFrame = CFrame.new(0, 1.2, -1.6 + k * 0.8) * CFrame.Angles(0.5, 0, 0) })
		end
		return m
	end,
	-- Chapter 4
	keycard = function()
		local m = Instance.new("Model")
		part(m, { Size = Vector3.new(3.2, 0.3, 2), Color = Color3.fromRGB(120, 255, 160), Material = Enum.Material.Neon, CFrame = CFrame.Angles(0.6, 0.3, 0) })
		part(m, { Size = Vector3.new(0.9, 0.32, 0.5), Color = Color3.fromRGB(30, 30, 34), Material = Enum.Material.SmoothPlastic,
			CFrame = CFrame.Angles(0.6, 0.3, 0) * CFrame.new(-0.8, 0, -0.4) })
		return m
	end,
	door = function()
		local m = Instance.new("Model")
		part(m, { Size = Vector3.new(5, 9, 0.4), Color = Color3.fromRGB(90, 96, 104), Material = Enum.Material.DiamondPlate, CFrame = CFrame.new() })
		for i = 0, 3 do
			part(m, { Size = Vector3.new(0.7, 0.5, 0.3), Color = i < 2 and Color3.fromRGB(120, 255, 160) or RED, Material = Enum.Material.Neon,
				CFrame = CFrame.new(-1.8 + i * 1.2, 2, -0.3) })
		end
		for _, x in ipairs({ -3.6, 3.6 }) do -- broken tiles on each side
			part(m, { Size = Vector3.new(2, 9, 0.3), Color = Color3.fromRGB(225, 228, 230), Material = Enum.Material.Marble, CFrame = CFrame.new(x, 0, 0) })
		end
		return m
	end,
	pylon = function()
		local m = Instance.new("Model")
		local purple = Color3.fromRGB(170, 90, 255)
		part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 7, 7), Color = Color3.fromRGB(60, 62, 60), Material = Enum.Material.Metal,
			CFrame = CFrame.Angles(0, 0, math.rad(90)) })
		part(m, { Size = Vector3.new(2.2, 9, 2.2), Color = purple, Material = Enum.Material.Neon, CFrame = CFrame.new(0, 5, 0) })
		for k = 1, 3 do
			part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 5, 5), Color = Color3.fromRGB(70, 60, 90), Material = Enum.Material.Metal,
				CFrame = CFrame.new(0, 1.4 + k * 2.6, 0) * CFrame.Angles(0, 0, math.rad(90)) })
		end
		return m
	end,
	echo = function()
		local m = Instance.new("Model")
		local shade, purple = Color3.fromRGB(26, 20, 36), Color3.fromRGB(170, 90, 255)
		part(m, { Size = Vector3.new(2.2, 2.4, 1.2), Color = shade, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new() })
		part(m, { Size = Vector3.new(1.5, 1.4, 1.4), Color = shade, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(0, 2, 0) })
		part(m, { Size = Vector3.new(1.6, 0.3, 0.2), Color = purple, Material = Enum.Material.Neon, CFrame = CFrame.new(0, 2.1, -0.72) })
		for _, side in ipairs({ -1, 1 }) do
			part(m, { Size = Vector3.new(1, 0.5, 1.3), Color = purple, Material = Enum.Material.Neon, CFrame = CFrame.new(side * 1.5, 1.1, 0) })
			part(m, { Size = Vector3.new(0.6, 2.2, 0.6), Color = shade, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(side * 1.5, -0.3, 0) })
			part(m, { Size = Vector3.new(0.8, 2.4, 0.8), Color = shade, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(side * 0.55, -2.4, 0) })
		end
		part(m, { Size = Vector3.new(0.5, 0.5, 1.6), Color = purple, Material = Enum.Material.Neon, CFrame = CFrame.new(1.5, -1, -0.6) })
		part(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Color = purple, Material = Enum.Material.Neon, CFrame = CFrame.new(1.5, -1, -4) })
		return m
	end,
	-- Chapter 5
	minirift = function()
		local m = Instance.new("Model")
		part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 11, 11), Color = RED, Material = Enum.Material.Neon,
			CFrame = CFrame.new(0, 6.5, 0) * CFrame.Angles(0, math.rad(90), 0) })
		part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 18, 18), Color = RED, Material = Enum.Material.Neon, Transparency = 0.6,
			CFrame = CFrame.Angles(0, 0, math.rad(90)) })
		part(m, { Size = Vector3.new(2, 3, 1.2), Color = Color3.fromRGB(70, 92, 125), Material = Enum.Material.DiamondPlate, CFrame = CFrame.new(3, 1.5, 3) })
		return m
	end,
	van = function()
		local m = Instance.new("Model")
		local blue = Color3.fromRGB(70, 140, 255)
		part(m, { Size = Vector3.new(6, 5, 12), Color = Color3.fromRGB(235, 225, 200), Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(0, 3.6, 0) })
		part(m, { Size = Vector3.new(6.05, 0.8, 12.05), Color = blue, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(0, 3.2, 0) })
		part(m, { Size = Vector3.new(0.4, 6, 0.4), Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.Metal, CFrame = CFrame.new(0, 9, 3) })
		part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 4, 4), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal,
			CFrame = CFrame.new(0, 12, 3) * CFrame.Angles(0, 0, math.rad(60)) })
		part(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, Color = blue, Material = Enum.Material.Neon, CFrame = CFrame.new(0, 12.6, 3) })
		return m
	end,
	tapes = function()
		local m = Instance.new("Model")
		part(m, { Size = Vector3.new(2.4, 1.4, 1.6), Color = Color3.fromRGB(255, 170, 40), Material = Enum.Material.Neon, CFrame = CFrame.Angles(0.3, 0.4, 0) })
		for _, x in ipairs({ -0.6, 0.6 }) do
			part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 0.9, 0.9), Color = Color3.fromRGB(40, 40, 46), Material = Enum.Material.Metal,
				CFrame = CFrame.Angles(0.3, 0.4, 0) * CFrame.new(x, 0, -0.85) * CFrame.Angles(0, math.rad(90), 0) })
		end
		return m
	end,
	marker = function()
		local m = Instance.new("Model")
		part(m, { Size = Vector3.new(3, 3, 0.4), Color = YELLOW, Material = Enum.Material.Neon, CFrame = CFrame.Angles(0, 0, math.rad(45)) })
		part(m, { Size = Vector3.new(1.6, 1.6, 0.5), Color = BLACK, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.Angles(0, 0, math.rad(45)) })
		return m
	end,
}

local spinning = {} -- models in visible viewports, slowly turning

local function picture(parent, kind)
	local vp = make("ViewportFrame", {
		Size = UDim2.new(1, 0, 0, 110), BackgroundColor3 = Color3.fromRGB(18, 14, 24), BorderSizePixel = 0,
		Ambient = Color3.fromRGB(150, 150, 165), LightColor = Color3.fromRGB(255, 240, 220), LightDirection = Vector3.new(-1, -1, -1),
		LayoutOrder = 1,
	}, parent)
	local model = PICTURES[kind]()
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	local cam = make("Camera", { FieldOfView = 40 }, vp)
	local distance = size.Magnitude * 1.25
	local tilt = kind == "shockwave" and 0.6 or 0.15
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, distance * tilt, -distance), cf.Position)
	vp.CurrentCamera = cam
	if kind ~= "rift" and kind ~= "marker" then
		table.insert(spinning, { model = model, pivot = model:GetPivot(), center = cf.Position })
	end
	return vp
end

RunService.RenderStepped:Connect(function()
	if not backdrop.Visible then
		return
	end
	local angle = os.clock() * 0.6
	for _, s in ipairs(spinning) do
		if s.model.Parent then
			s.model:PivotTo(CFrame.new(s.center) * CFrame.Angles(0, angle, 0) * CFrame.new(-s.center) * s.pivot)
		end
	end
end)

---------------------------------------------------------------------------
-- Screens
---------------------------------------------------------------------------
local summary = nil  -- from the server: save info, chapters, bestChapter
local inGame = false -- false: title menu after the intro, true: pause menu
local showMain       -- forward declarations
local showBriefing
local showCharacter
local showRewards    -- REWARDS hub, daily reward and the Meta remote helper (REWARDS section)
local showDaily
local meta
local dailyChecked = false -- the daily reward popup shows once per session, after START MISSION

local BRIEFINGS = {
	[1] = {
		goal = "Bring 6 Signal Shards from the Undergrid to the console to seal the rift.",
		cards = {
			{ "rift", "1. ENTER", RED, "The red RIFT in the field east of Main Street. Stand next to it and " .. CROSS .. "." },
			{ "shard", "2. COLLECT", CYAN, "Glowing blue SIGNAL SHARDS in the Undergrid. Touch one to pick it up." },
			{ "console", "3. DELIVER", GREEN, "Go back through the rift to the green CONSOLE under the radio tower (north end of the road)." },
			{ "hollower", "WATCH OUT", RED, "HOLLOWERS drift through walls. Shoot them in robot mode. If you die you lose the shards you carry." },
		},
	},
	[2] = {
		goal = "Destroy the Hive Nodes, then defeat the Mind Warden.",
		cards = {
			{ "node", "1. DESTROY x3", RED, "Pulsing red HIVE NODES in the Undergrid. Robot mode + BLAST. They call Hollowers when you are near." },
			{ "boss", "2. DEFEAT", YELLOW, "The MIND WARDEN by the Undergrid radio tower. Shoot it only when its head opens and glows yellow." },
			{ "shockwave", "3. JUMP", RED, "Its slam sends a red SHOCKWAVE ring. Jump over it. Car mode takes half damage." },
			{ "cannon", "YOUR WEAPON", CYAN, FIRE .. " in robot mode. Earn SCRAP and buy stronger weapons at the Garage or MENU > SHOP." },
		},
	},
	[3] = {
		goal = "Find the LOWBAND files, restart the relays, protect the Carrier, then race its code to the radio tower.",
		cards = {
			{ "file", "1. FIND x5", YELLOW, "Yellow LOWBAND FILES in the lab in the woods west of town. 2 are only in its Undergrid copy: use the small rift by the lab." },
			{ "relay", "2. HOLD x3", GREEN, "Stand in each RELAY CIRCLE around the Undergrid lab until it is full. Leaving pauses it." },
			{ "carrier", "3. DEFEND + RACE", Color3.fromRGB(255, 120, 200), "Protect THE CARRIER until it shuts down, then drive its code to the radio tower console before time runs out." },
			{ "hound", "WATCH OUT", RED, "STATIC HOUNDS hunt in packs and run faster than a robot. Shoot them, or switch to car mode to escape." },
		},
	},
	[4] = {
		goal = "Find the keycards, open Site 2 under the Grand Hotel, destroy the Echo Pylons and play the tape.",
		cards = {
			{ "keycard", "1. FIND x4", Color3.fromRGB(120, 255, 160), "Green KEYCARDS in the Grand Hotel: room 302 and the roof here; room 209 and behind reception in its Undergrid copy." },
			{ "door", "2. OPEN", AMBER, "The STEEL DOOR behind the cracked tiles in the ground floor MEN'S WASHROOM. With 4 cards it takes you down to SITE 2." },
			{ "pylon", "3. DESTROY x4", Color3.fromRGB(170, 90, 255), "The purple ECHO PYLONS in Site 2's four chambers. Then the vault opens: PLAY THE TAPE in the deep room." },
			{ "echo", "WATCH OUT", RED, "ECHOES copy Shiftframes and SHOOT BACK. Their purple bolts are slow: move sideways and use walls as cover." },
		},
	},
	[5] = {
		goal = "The Undergrid is leaking into Hollow Creek. Close the rifts, protect the broadcast, deliver the tapes.",
		cards = {
			{ "minirift", "1. CLOSE x5", RED, "Red MINI-RIFTS open all over town. Stand inside the red circle until it closes. Things come out of them!" },
			{ "van", "2. DEFEND", Color3.fromRGB(70, 140, 255), "The WHCK 85.5 VAN on Main Street broadcasts a calming signal. Keep everything away from it until it's done." },
			{ "tapes", "3. RACE", Color3.fromRGB(255, 170, 40), "Grab the SIGNAL TAPES by the radio tower console and drive them to the GRAND HOTEL entrance in car mode. Hurry!" },
			{ "hound", "WATCH OUT", RED, "This time HOLLOWERS and STATIC HOUNDS are IN TOWN. There is no safe side of the rift tonight." },
		},
	},
}

local function stageName(stage)
	return ({ Shards = "Collecting shards", Nodes = "Hive Nodes", Boss = "Mind Warden", Files = "LOWBAND files", Relays = "Power relays", Carrier = "Defend the Carrier", Complete = "Complete",
		Keycards = "Keycards", Pylons = "Echo Pylons", Tape = "The tape",
		Rifts = "Mini-rifts", Van = "Defend the van", TapeRace = "Tape race" })[stage] or tostring(stage)
end

local function timeAgo(seconds)
	seconds = math.max(seconds or 0, 0)
	if seconds < 90 then
		return "just now"
	elseif seconds < 5400 then
		return math.floor(seconds / 60) .. " min ago"
	elseif seconds < 129600 then
		return math.floor(seconds / 3600) .. " h ago"
	end
	return math.floor(seconds / 86400) .. " days ago"
end

-- why there is nothing to continue (reason comes from the server)
local function noSaveReason()
	local reason = summary and summary.reason
	if reason == "NOT PUBLISHED" then
		return "SAVING IS OFF: publish the game first (File > Publish to Roblox)."
	elseif reason == "API ACCESS OFF" then
		return "SAVING IS OFF IN STUDIO: Game Settings > Security > Enable Studio Access to API Services, then play again."
	elseif summary and not summary.available then
		return "COULD NOT LOAD YOUR SAVE - TRY AGAIN LATER."
	end
	return "NO SAVED GAME YET - press SAVE while playing."
end

local function chapterTitle(n)
	for _, c in ipairs(summary and summary.chapters or {}) do
		if c.n == n then
			return c.title
		end
	end
	return ReplicatedStorage:GetAttribute("ChapterTitle") or ""
end

local function setMenuOpen(open)
	backdrop.Visible = open
	player:SetAttribute("MenuActive", open)
	if open then
		ContextActionService:BindActionAtPriority("S85_MenuNav", onNav, false, Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.W, Enum.KeyCode.S, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadDown,
			Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	else
		ContextActionService:UnbindAction("S85_MenuNav")
		clearScreen()
		table.clear(spinning)
	end
end

local function refreshSummary()
	local ok, result = pcall(function()
		return GetSave:InvokeServer()
	end)
	summary = ok and result or { available = false, hasSave = false, bestChapter = 1, chapters = { { n = 1, title = "SEAL THE RIFT" } } }
	if summary.brightness then
		player:SetAttribute("LightLevel", summary.brightness) -- Signal85Client applies it
	end
	if summary.graphics then
		player:SetAttribute("GraphicsQuality", summary.graphics)
	end
	if summary.shake ~= nil then
		player:SetAttribute("CameraShake", summary.shake)
	end
	if summary.autoAim ~= nil then
		player:SetAttribute("AutoAim", summary.autoAim)
	end
	-- task 011 settings (Signal85Client reads them; SoundVolume is for the sounds of Phase B)
	if summary.hudSize then
		player:SetAttribute("HudSize", summary.hudSize)
	end
	if summary.damageNumbers ~= nil then
		player:SetAttribute("DamageNumbers", summary.damageNumbers)
	end
	if summary.volume then
		player:SetAttribute("SoundVolume", summary.volume)
	end
end

-- the story opening scene (IntroBroadcast plays it while PlayStory is true); then `after`
local function playStory(after)
	clearScreen()
	backdrop.Visible = false -- the menu stays "open" (MenuActive) so the HUD stays hidden
	local done
	done = player:GetAttributeChangedSignal("PlayStory"):Connect(function()
		if player:GetAttribute("PlayStory") == false then
			done:Disconnect()
			backdrop.Visible = true
			after()
		end
	end)
	player:SetAttribute("PlayStory", true)
end

local function choose(choice, n)
	local ok, result = pcall(function()
		return ChooseStart:InvokeServer(choice, n)
	end)
	if not ok or not result then
		showToast("SOMETHING WENT WRONG - TRY AGAIN", RED)
		return false
	end
	if not result.ok then
		showToast(result.message, RED)
		return false
	end
	showToast(result.message, GREEN)
	local chapter = result.chapter or ReplicatedStorage:GetAttribute("Chapter") or 1
	-- NEW GAME: (pick your pilot the first time) -> story scene -> briefing. CONTINUE: straight to the briefing.
	local function afterPilot()
		if choice == "new" then
			playStory(function()
				showBriefing(chapter)
			end)
		else
			showBriefing(chapter)
		end
	end
	if summary and summary.look == nil then
		showCharacter(afterPilot)
	else
		afterPilot()
	end
	return true
end

local function doSave()
	local ok, saved, message = pcall(function()
		return SaveGame:InvokeServer()
	end)
	if not ok then
		showToast("SAVE FAILED — TRY AGAIN", RED)
	else
		if message == "SAVING UNAVAILABLE" then
			message = noSaveReason()
		end
		showToast(message, saved and GREEN or RED)
	end
end

local function showConfirmNew()
	clearScreen()
	text(panel, { Text = "START OVER?", TextSize = 34, TextColor3 = RED, LayoutOrder = 1 })
	text(panel, { Text = "YOUR SAVE WILL BE REPLACED WHEN YOU NEXT SAVE.", TextSize = 20, LayoutOrder = 2 })
	button(panel, "YES, NEW GAME", RED, function()
		choose("new")
	end, 3)
	button(panel, "NO, GO BACK", AMBER, function()
		showMain()
	end, 4)
	setFocus(2)
end

---------------------------------------------------------------------------
-- Shop (Scrap Garage): weapons and upgrades. The server owns prices and Scrap.
---------------------------------------------------------------------------
local shopTab = "weapons"
local shopFromGarage = false -- opened at the Garage: BACK closes the menu instead of going to the pause menu
local showShop

local function shopRow(order, color, title, desc, stats, actionLabel, actionColor, onAction)
	local row = make("Frame", {
		BackgroundColor3 = Color3.fromRGB(22, 18, 28), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order,
	}, panel)
	make("UIStroke", { Color = color, Thickness = 2 }, row)
	pad(row, 8)
	make("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.new(0, 10, 1, 0) }, row)
	local info = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -210, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, row)
	list(info, 2).HorizontalAlignment = Enum.HorizontalAlignment.Left
	text(info, { Text = title, TextSize = 22, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1 })
	text(info, { Text = desc, Font = Enum.Font.Code, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2 })
	if stats then
		text(info, { Text = stats, Font = Enum.Font.Code, TextSize = 14, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 3 })
	end
	local b = button(row, actionLabel, actionColor, onAction, 0)
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, 0, 0.5, 0)
	b.Size = UDim2.fromOffset(180, 48)
	b.TextSize = 18
	return row
end

local function shopCall(action, id)
	local ok, result = pcall(function()
		return Shop:InvokeServer(action, id)
	end)
	if not ok or type(result) ~= "table" then
		showToast("SHOP ERROR - TRY AGAIN", RED)
		return nil
	end
	if result.message and result.message ~= "" then
		showToast(result.message, result.ok and GREEN or RED)
	end
	return result.state
end

showShop = function(state)
	state = state or shopCall("list")
	if not state then
		return
	end
	clearScreen()
	text(panel, { Text = "SCRAP GARAGE", TextSize = 34, TextColor3 = Color3.fromRGB(255, 170, 40), LayoutOrder = 1 })
	text(panel, { Text = "SCRAP: " .. state.scrap, TextSize = 24, TextColor3 = YELLOW, LayoutOrder = 2 })
	text(panel, {
		Text = "Earn Scrap: shard +10, Hollower +2, Hive Node +25, Mind Warden +200, chapter +100.",
		Font = Enum.Font.Code, TextSize = 15, TextColor3 = DIM, LayoutOrder = 3,
	})

	local tabs = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 4 }, panel)
	list(tabs, 12, true)
	for i, tab in ipairs({ { "weapons", "WEAPONS" }, { "upgrades", "UPGRADES" } }) do
		local active = shopTab == tab[1]
		local b = button(tabs, tab[2], active and YELLOW or DIM, function()
			shopTab = tab[1]
			showShop(state)
		end, i)
		b.Size = UDim2.fromOffset(200, 48)
	end

	local order = 5
	if shopTab == "weapons" then
		-- task 012: refill every gun you own (the free refill only gives half)
		if state.ammoPrice then
			local spare = player:GetAttribute("AmmoSpare")
			shopRow(order, Color3.fromRGB(255, 170, 40), "AMMO REFILL",
				"Fills every gun you own. Free ammo (drops, and half a refill every 20 min) is only for the Pulse Cannon.",
				spare and ("YOUR " .. tostring(player:GetAttribute("WeaponName") or "GUN") .. ": " .. tostring(player:GetAttribute("Ammo") or 0)
					.. " + SPARE " .. spare) or nil,
				"BUY " .. state.ammoPrice, state.scrap >= state.ammoPrice and YELLOW or DIM, function()
					showShop(shopCall("ammo"))
				end)
			order = order + 1
		end
		for _, w in ipairs(state.weapons) do
			local owned = state.owned[w.id]
			local equipped = state.weapon == w.id
			local label, color, action
			if equipped then
				label, color = "EQUIPPED", GREEN
			elseif owned then
				label, color, action = "EQUIP", CYAN, "equip"
			else
				label, color, action = "BUY " .. w.price, state.scrap >= w.price and YELLOW or DIM, "buy"
			end
			shopRow(order, w.color, w.name, w.desc, w.stats, label, color, function()
				if action then
					showShop(shopCall(action, w.id))
				end
			end)
			order = order + 1
		end
	else
		for _, u in ipairs(state.upgrades) do
			local price = u.prices[u.level + 1]
			local label = price and ("BUY " .. price) or "MAX"
			local color = price and (state.scrap >= price and YELLOW or DIM) or GREEN
			shopRow(order, CYAN, u.name .. "  " .. string.rep("■", u.level) .. string.rep("□", #u.prices - u.level), u.desc, nil, label, color, function()
				if price then
					showShop(shopCall("buy", u.id))
				end
			end)
			order = order + 1
		end
	end

	button(panel, "BACK", DIM, function()
		if shopFromGarage then
			setMenuOpen(false)
		else
			showMain()
		end
	end, order)
	setFocus(1)
end

-- YOUR PILOT: outfit, hair, hair colour, skin tone, or your own Roblox avatar.
-- Every change is sent to the server, which dresses your character; the camera faces you.
local SetLook = remotes:WaitForChild("SetLook")

showCharacter = function(onDone)
	local catalog = summary and summary.lookCatalog
	if not catalog then
		showToast("STILL LOADING - TRY AGAIN", RED)
		return
	end
	local look = table.clone(summary.look or { own = false, outfit = 1, hair = 1, hairColor = 1, skin = 2, paint = 1 })
	if look.own then
		look = { own = true, outfit = 1, hair = 1, hairColor = 1, skin = 2, paint = look.paint or 1 }
	end
	look.paint = look.paint or 1

	-- returns false when the server refused it (a locked hair or paint)
	local function send()
		local ok, accepted = pcall(function()
			return SetLook:InvokeServer(look.own and { own = true, paint = look.paint } or look)
		end)
		if ok and accepted then
			summary.look = look.own and { own = true, paint = look.paint } or table.clone(look)
		end
		return ok and accepted
	end

	local function render()
		clearScreen()
		setSideLayout(true)
		-- face the character from the front, a little to the left of the panel
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local cam = workspace.CurrentCamera
			cam.CameraType = Enum.CameraType.Scriptable
			local front = hrp.CFrame.LookVector
			local right = hrp.CFrame.RightVector
			cam.CFrame = CFrame.lookAt(hrp.Position + front * 9 + Vector3.new(0, 1.5, 0) - right * 2.5, hrp.Position + Vector3.new(0, 0.8, 0) - right * 2.5)
		end

		text(panel, { Text = "YOUR PILOT", TextSize = 32, TextColor3 = RED, LayoutOrder = 1 })
		text(panel, { Text = "Pick any look you like; change it any time in the menu. HAIR COLOR is for the (ANY COLOR) hair styles.",
			Font = Enum.Font.Code, TextSize = 15, TextColor3 = DIM, LayoutOrder = 2 })

		local order = 3
		local function chooser(title, key, names, colors)
			local row = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = order }, panel)
			order = order + 1
			list(row, 8, true)
			text(row, { Text = title, TextSize = 16, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0.3, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1 })
			local count = names and #names or #colors
			local function step(delta)
				look[key] = (look[key] - 1 + delta) % count + 1
				if key ~= "paint" then
					look.own = false -- the suit paint also works with your own Roblox avatar
				end
				local name = names and names[look[key]]
				if not send() and name and (name:find("%(LEVEL") or name:find("STREAK%)")) then
					showToast("LOCKED: " .. name, RED)
				end
				render()
			end
			local prev = button(row, "<", AMBER, function()
				step(-1)
			end, 2)
			prev.Size = UDim2.fromOffset(48, 48)
			local value = text(row, {
				Text = names and names[look[key]] or "■■■■", TextSize = 18, AutomaticSize = Enum.AutomaticSize.None,
				Size = UDim2.new(0.34, 0, 1, 0), LayoutOrder = 3, TextColor3 = colors and colors[look[key]] or AMBER,
				TextTransparency = (look.own and key ~= "paint") and 0.6 or 0,
			})
			value.TextXAlignment = Enum.TextXAlignment.Center
			local nextButton = button(row, ">", AMBER, function()
				step(1)
			end, 4)
			nextButton.Size = UDim2.fromOffset(48, 48)
		end
		chooser("OUTFIT", "outfit", catalog.outfits, nil)
		chooser("HAIR", "hair", catalog.hairs, nil)
		chooser("HAIR COLOR", "hairColor", nil, catalog.hairColors)
		chooser("SKIN TONE", "skin", nil, catalog.skins)
		if catalog.paints then
			chooser("SUIT PAINT", "paint", catalog.paints, nil)
		end

		button(panel, look.own and "USING MY ROBLOX AVATAR" or "USE MY ROBLOX AVATAR", look.own and GREEN or DIM, function()
			look.own = not look.own
			send()
			render()
		end, order)
		button(panel, "DONE", GREEN, function()
			if summary.look == nil then
				send() -- keep the default look if nothing was changed
			end
			if onDone then
				onDone()
			else
				showMain()
			end
		end, order + 1)
		setFocus(#buttons)
	end
	render()
end

-- SETTINGS: graphics, camera shake, auto-aim, HUD size, damage numbers, volume, replay tutorial
-- (Signal85Client applies them; the server saves them)
local settingsScroll = Vector2.zero
local function showSettings()
	clearScreen()
	text(panel, { Text = "SETTINGS", TextSize = 34, TextColor3 = RED, LayoutOrder = 1 })

	-- everything scrolls (it is taller than a phone screen); the scroll position is kept on each change
	local area = make("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, SMALL_SCREEN and 320 or 440), LayoutOrder = 2,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, ScrollBarImageColor3 = AMBER,
		ScrollingDirection = Enum.ScrollingDirection.Y, CanvasPosition = settingsScroll,
	}, panel)
	list(area, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	area:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		settingsScroll = area.CanvasPosition
	end)
	local order = 0
	-- a heading, a line of help, and a row of choices (the current one green)
	local function option(title, help, choices, current, pick)
		order = order + 1
		text(area, { Text = title, TextSize = 22, LayoutOrder = order })
		if help then
			order = order + 1
			text(area, { Text = help, Font = Enum.Font.Code, TextSize = 15, TextColor3 = DIM, LayoutOrder = order })
		end
		order = order + 1
		local row = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = order }, area)
		list(row, 10, true)
		for i, choice in ipairs(choices) do
			local b = button(row, choice[1], choice[2] == current and GREEN or DIM, function()
				pick(choice[2])
				showSettings()
			end, i)
			b.Size = UDim2.fromOffset(#choices > 3 and 70 or 150, 48)
		end
	end

	option("GRAPHICS", "LOW is smoothest on older phones. HIGH has sun rays, more glow and particles.",
		{ { "LOW", 1 }, { "MEDIUM", 2 }, { "HIGH", 3 } }, player:GetAttribute("GraphicsQuality") or (IS_PHONE and 2 or 3), function(q)
			player:SetAttribute("GraphicsQuality", q)
			SettingsEvent:FireServer("graphics", q)
		end)
	option("CAMERA SHAKE", nil, { { "ON", true }, { "OFF", false } }, player:GetAttribute("CameraShake") ~= false, function(on)
		player:SetAttribute("CameraShake", on)
		SettingsEvent:FireServer("shake", on)
	end)
	option("AUTO-AIM", "ON: Q / BLAST shoot the nearest enemy (red ring) by themselves - no mouse needed.",
		{ { "ON", true }, { "OFF", false } }, player:GetAttribute("AutoAim") ~= false, function(on)
			player:SetAttribute("AutoAim", on)
			SettingsEvent:FireServer("autoaim", on)
		end)
	option("HUD SIZE", "Size of the panel and objective box on the left.", { { "SMALL", 1 }, { "NORMAL", 2 }, { "LARGE", 3 } },
		player:GetAttribute("HudSize") or 2, function(size)
			player:SetAttribute("HudSize", size)
			SettingsEvent:FireServer("hud", size)
		end)
	option("DAMAGE NUMBERS", "The numbers that float up when you hit an enemy.", { { "ON", true }, { "OFF", false } },
		player:GetAttribute("DamageNumbers") ~= false, function(on)
			player:SetAttribute("DamageNumbers", on)
			SettingsEvent:FireServer("numbers", on)
		end)
	local volume = player:GetAttribute("SoundVolume") or 8
	option("SOUND VOLUME: " .. volume .. " / 10", "Music and sound effects arrive in a later update.",
		{ { "0", 0 }, { "-", math.max(volume - 1, 0) }, { "+", math.min(volume + 1, 10) }, { "10", 10 } }, -1, function(v)
			player:SetAttribute("SoundVolume", v)
			SettingsEvent:FireServer("volume", v)
		end)

	order = order + 1
	button(area, "REPLAY TUTORIAL", CYAN, function()
		if not inGame then
			showToast("START THE GAME FIRST, THEN REPLAY IT FROM HERE", RED)
		elseif player:GetAttribute("TutorialActive") then
			showToast("THE TUTORIAL IS ALREADY RUNNING", RED)
		else
			setMenuOpen(false)
			player:SetAttribute("TutorialStart", true)
		end
	end, order)

	button(panel, "BACK", DIM, function()
		settingsScroll = Vector2.zero
		showMain()
	end, 10)
	setFocus(#buttons)
end

local function showChapters()
	clearScreen()
	text(panel, { Text = "CHAPTER SELECT", TextSize = 34, TextColor3 = RED, LayoutOrder = 1 })
	text(panel, { Text = "Replay any chapter you have reached. Chapter 1 starts the game from the beginning.", Font = Enum.Font.Code, TextSize = 18, LayoutOrder = 2 })
	local best = summary and summary.bestChapter or 1
	local order = 3
	for _, c in ipairs(summary and summary.chapters or {}) do
		if c.n <= best then
			button(panel, "CHAPTER " .. c.n .. ": " .. c.title, c.n == 1 and GREEN or AMBER, function()
				choose("chapter", c.n)
			end, order)
		else
			text(panel, { Text = "CHAPTER " .. c.n .. ": LOCKED - FINISH CHAPTER " .. (c.n - 1) .. " FIRST", TextSize = 20, TextColor3 = DIM, LayoutOrder = order })
		end
		order = order + 1
	end
	button(panel, "BACK", DIM, function()
		showMain()
	end, order)
	setFocus(1)
end

showBriefing = function(chapter)
	clearScreen()
	table.clear(spinning)
	local brief = BRIEFINGS[chapter] or BRIEFINGS[1]
	text(panel, { Text = "MISSION BRIEFING", TextSize = 20, TextColor3 = AMBER, LayoutOrder = 1 })
	text(panel, { Text = "CHAPTER " .. chapter .. ": " .. chapterTitle(chapter), TextSize = 32, TextColor3 = RED, LayoutOrder = 2 })
	text(panel, { Text = brief.goal, Font = Enum.Font.Code, TextSize = 20, TextColor3 = CYAN, LayoutOrder = 3 })

	local row = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4 }, panel)
	make("UIGridLayout", {
		CellSize = UDim2.new(0.25, -9, 0, 250), CellPadding = UDim2.fromOffset(12, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	for i, card in ipairs(brief.cards) do
		local kind, title, color, body = card[1], card[2], card[3], card[4]
		local frame = make("Frame", { BackgroundColor3 = Color3.fromRGB(22, 18, 28), BorderSizePixel = 0, LayoutOrder = i }, row)
		make("UIStroke", { Color = color, Thickness = 2 }, frame)
		pad(frame, 8)
		list(frame, 6)
		picture(frame, kind)
		text(frame, { Text = title, TextSize = 20, TextColor3 = color, LayoutOrder = 2 })
		text(frame, { Text = body, Font = Enum.Font.Code, TextSize = 15, TextColor3 = AMBER, LayoutOrder = 3 })
	end

	local hint = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60), LayoutOrder = 5 }, panel)
	list(hint, 12, true)
	local markerPic = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(80, 60), LayoutOrder = 1 }, hint)
	picture(markerPic, "marker").Size = UDim2.fromScale(1, 1)
	text(hint, {
		Text = "FOLLOW THE YELLOW MARKER: it always points to your next target and shows how far it is.",
		Font = Enum.Font.Code, TextSize = 17, TextColor3 = YELLOW, AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(0.8, -92, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2,
	})

	button(panel, inGame and "BACK TO THE GAME" or "START MISSION", GREEN, function()
		inGame = true
		setMenuOpen(false)
		-- once per session: the daily reward pops up if today's box is ready
		local function checkDaily()
			if dailyChecked then
				return
			end
			dailyChecked = true
			task.spawn(function()
				local status = meta("daily")
				if status and status.ok and status.canClaim and not backdrop.Visible then
					setMenuOpen(true)
					showDaily(status, true)
				end
			end)
		end
		-- new players: the "First Night" tutorial (Tutorial script) first, then the daily reward
		if summary and summary.tutorialDone == false and not player:GetAttribute("TutorialActive") then
			summary.tutorialDone = true -- offered once per session
			local conn
			conn = player:GetAttributeChangedSignal("TutorialActive"):Connect(function()
				if player:GetAttribute("TutorialActive") == false then
					conn:Disconnect()
					checkDaily()
				end
			end)
			player:SetAttribute("TutorialStart", true)
		else
			checkDaily()
		end
	end, 6)
	setFocus(1)
end

---------------------------------------------------------------------------
-- REWARDS (task 010): daily reward, daily quests, achievements, top pilots, codes.
-- The server decides everything; these screens only show what Meta returns.
---------------------------------------------------------------------------
local Meta = remotes:WaitForChild("Meta")
local GOLD = Color3.fromRGB(255, 214, 90)
local MINT = Color3.fromRGB(120, 255, 160)

meta = function(action, arg)
	local ok, result = pcall(function()
		return Meta:InvokeServer(action, arg)
	end)
	if not ok or type(result) ~= "table" then
		showToast("SOMETHING WENT WRONG - TRY AGAIN", RED)
		return nil
	end
	if result.ok == false and result.message then
		showToast(result.message, RED)
	end
	return result
end

local function countdown(seconds)
	seconds = math.max(math.floor(seconds or 0), 0)
	return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
end

local function scrollArea(order)
	local area = make("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, SMALL_SCREEN and 300 or 380), LayoutOrder = order,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, ScrollBarImageColor3 = AMBER,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, panel)
	list(area, 6).VerticalAlignment = Enum.VerticalAlignment.Top
	pad(area, 4)
	return area
end

-- a row with a title, a line of text, an optional progress bar and a value on the right
local function infoRow(parent, order, color, title, body, right, fill)
	local row = make("Frame", {
		BackgroundColor3 = Color3.fromRGB(22, 18, 28), BorderSizePixel = 0, Size = UDim2.new(1, -14, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order,
	}, parent)
	make("UIStroke", { Color = color, Thickness = 2 }, row)
	pad(row, 8)
	local info = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -150, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, row)
	list(info, 3).HorizontalAlignment = Enum.HorizontalAlignment.Left
	text(info, { Text = title, TextSize = 19, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1 })
	if body then
		text(info, { Text = body, Font = Enum.Font.Code, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2 })
	end
	if fill then
		local back = make("Frame", { BackgroundColor3 = Color3.fromRGB(40, 30, 40), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 10), LayoutOrder = 3 }, info)
		make("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromScale(math.clamp(fill, 0, 1), 1) }, back)
	end
	if right then
		text(row, {
			Text = right, TextSize = 18, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Right, AutomaticSize = Enum.AutomaticSize.None,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(140, 44),
		})
	end
	return row
end

local function rewardsBack()
	button(panel, "BACK", DIM, function()
		showRewards()
	end, 50)
end

-- DAILY REWARD: 7 boxes, today's glows; popup = shown by itself after START MISSION
showDaily = function(status, popup)
	status = status or meta("daily")
	if not status or not status.ok then
		return
	end
	clearScreen()
	text(panel, { Text = "DAILY REWARD", TextSize = 34, TextColor3 = GOLD, LayoutOrder = 1 })
	text(panel, { Text = "Claim once a day. Miss a day and the streak starts again at Day 1. Day 7 also unlocks the GOLD suit paint.",
		Font = Enum.Font.Code, TextSize = 15, TextColor3 = DIM, LayoutOrder = 2 })
	local row = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 92), LayoutOrder = 3 }, panel)
	list(row, 6, true)
	for day = 1, 7 do
		local claimed = day < status.day or (day == status.day and not status.canClaim)
		local today = day == status.day and status.canClaim
		local color = claimed and GREEN or (today and GOLD or DIM)
		local box = make("Frame", {
			BackgroundColor3 = today and Color3.fromRGB(60, 48, 20) or Color3.fromRGB(22, 18, 28), BorderSizePixel = 0,
			Size = UDim2.new(1 / 7, -6, 1, 0), LayoutOrder = day,
		}, row)
		make("UIStroke", { Color = color, Thickness = today and 3 or 2 }, box)
		list(box, 2)
		text(box, { Text = "DAY " .. day, TextSize = 14, TextColor3 = color, LayoutOrder = 1 })
		text(box, { Text = claimed and "GOT" or tostring(status.rewards[day] or ""), TextSize = 22, TextColor3 = color, LayoutOrder = 2 })
		text(box, { Text = day == 7 and "+GOLD" or "SCRAP", Font = Enum.Font.Code, TextSize = 12, TextColor3 = color, LayoutOrder = 3 })
	end
	if status.canClaim then
		button(panel, "CLAIM DAY " .. status.day .. ": +" .. tostring(status.rewards[status.day] or 0) .. " SCRAP", GOLD, function()
			local result = meta("claim")
			if result and result.ok then
				showToast("CLAIMED! COME BACK TOMORROW FOR DAY " .. (result.day % 7 + 1), GREEN)
				showDaily(result, popup)
			end
		end, 4)
	else
		text(panel, { Text = "STREAK: " .. status.streak .. " DAY(S).  NEXT REWARD IN " .. countdown(status.secondsLeft), TextSize = 20, TextColor3 = CYAN, LayoutOrder = 4 })
	end
	if status.saving == false then
		text(panel, { Text = "Saving is off here, so the streak is not kept when you leave.", Font = Enum.Font.Code, TextSize = 14, TextColor3 = RED, LayoutOrder = 5 })
	end
	if popup then
		button(panel, "PLAY", GREEN, function()
			setMenuOpen(false)
		end, 6)
	else
		rewardsBack()
	end
	setFocus(1)
end

local function showQuests()
	local data = meta("quests")
	if not data or not data.ok then
		return
	end
	clearScreen()
	text(panel, { Text = "DAILY QUESTS", TextSize = 34, TextColor3 = MINT, LayoutOrder = 1 })
	text(panel, { Text = "3 new quests every day (in " .. countdown(data.secondsLeft) .. "). Each one also gives +" .. tostring(data.xp) .. " XP.",
		Font = Enum.Font.Code, TextSize = 15, TextColor3 = DIM, LayoutOrder = 2 })
	for i, q in ipairs(data.quests) do
		infoRow(panel, 2 + i, q.done and GREEN or AMBER, (q.done and "DONE: " or "") .. string.upper(q.text),
			q.progress .. " / " .. q.goal, "+" .. q.reward .. " SCRAP", q.progress / math.max(q.goal, 1))
	end
	rewardsBack()
	setFocus(1)
end

local function showAchievements()
	local data = meta("achievements")
	if not data or not data.ok then
		return
	end
	clearScreen()
	text(panel, { Text = "ACHIEVEMENTS  " .. data.unlocked .. " / " .. #data.achievements, TextSize = 30, TextColor3 = GOLD, LayoutOrder = 1 })
	local area = scrollArea(2)
	for i, a in ipairs(data.achievements) do
		local body = a.hint .. ((not a.unlocked and a.progress and a.goal > 1) and ("   " .. a.progress .. " / " .. a.goal) or "")
		infoRow(area, i, a.unlocked and GOLD or DIM, a.name, body, a.unlocked and "UNLOCKED" or ("+" .. a.reward .. " SCRAP"),
			(not a.unlocked and a.progress and a.goal > 1) and (a.progress / a.goal) or nil)
	end
	rewardsBack()
	setFocus(1)
end

local boardTab = "level"
local function showBoard(data)
	data = data or meta("board")
	if not data or not data.ok then
		return
	end
	clearScreen()
	text(panel, { Text = "TOP PILOTS", TextSize = 34, TextColor3 = Color3.fromRGB(255, 80, 200), LayoutOrder = 1 })
	local tabs = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 2 }, panel)
	list(tabs, 12, true)
	for i, tab in ipairs({ { "level", "HIGHEST LEVEL" }, { "kills", "MOST DEFEATED" } }) do
		local b = button(tabs, tab[2], boardTab == tab[1] and YELLOW or DIM, function()
			boardTab = tab[1]
			showBoard(data)
		end, i)
		b.Size = UDim2.fromOffset(230, 48)
	end
	local area = scrollArea(3)
	local rows = data[boardTab] or {}
	for i, row in ipairs(rows) do
		local me = row.name == player.Name
		infoRow(area, i, me and GOLD or (i <= 3 and YELLOW or AMBER), i .. ".  " .. row.name, nil,
			(boardTab == "level" and "LV " or "") .. tostring(row.value))
	end
	if #rows == 0 then
		text(area, { Text = "Nobody yet - play to get on the board!", Font = Enum.Font.Code, TextSize = 16, LayoutOrder = 1 })
	end
	text(panel, { Text = data.global and "ALL SERVERS - updates every 2 minutes" or "THIS SERVER ONLY (all servers once the game is published)",
		Font = Enum.Font.Code, TextSize = 14, TextColor3 = DIM, LayoutOrder = 4 })
	rewardsBack()
	setFocus(1)
end

-- the REWARDS hub (title menu, and the REWARDS button while playing)
showRewards = function()
	clearScreen()
	text(panel, { Text = "REWARDS", TextSize = 34, TextColor3 = GOLD, LayoutOrder = 1 })
	text(panel, {
		Text = "PILOT LEVEL " .. tostring(player:GetAttribute("Level") or 1) .. (player:GetAttribute("Title") and " - VETERAN" or "")
			.. "    XP " .. tostring(player:GetAttribute("XP") or 0) .. " / " .. tostring(player:GetAttribute("XPNeed") or 100),
		TextSize = 18, TextColor3 = MINT, LayoutOrder = 2,
	})
	if ReplicatedStorage:GetAttribute("Weekend2x") then
		text(panel, { Text = "2x WEEKEND: double Scrap and XP until Sunday night (UTC)!", Font = Enum.Font.Code, TextSize = 16, TextColor3 = GOLD, LayoutOrder = 3 })
	end
	button(panel, "DAILY REWARD", GOLD, function()
		showDaily(nil, false)
	end, 4)
	button(panel, "DAILY QUESTS", MINT, showQuests, 5)
	button(panel, "ACHIEVEMENTS", GOLD, showAchievements, 6)
	button(panel, "TOP PILOTS", Color3.fromRGB(255, 80, 200), function()
		showBoard(nil)
	end, 7)
	-- Roblox's own invite window (only works in a published game). Friends in the same server: +10% Scrap.
	button(panel, player:GetAttribute("FriendBonus") and "INVITE FRIENDS (BONUS ON: +10%)" or "INVITE FRIENDS: +10% SCRAP TOGETHER", CYAN, function()
		local SocialService = game:GetService("SocialService")
		local ok, can = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and can then
			pcall(function()
				SocialService:PromptGameInvite(player)
			end)
		else
			showToast("INVITES WORK ONCE THE GAME IS PUBLISHED (NOT IN STUDIO)", RED)
		end
	end, 8)

	local codeRow = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 9 }, panel)
	list(codeRow, 10, true)
	local box = make("TextBox", {
		PlaceholderText = "ENTER A CODE", Text = "", ClearTextOnFocus = false, Font = Enum.Font.Arcade, TextSize = 20,
		TextColor3 = AMBER, PlaceholderColor3 = DIM, BackgroundColor3 = Color3.fromRGB(30, 24, 36), BorderSizePixel = 0,
		Size = UDim2.fromOffset(260, 48), LayoutOrder = 1,
	}, codeRow)
	make("UIStroke", { Color = DIM, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
	local redeem = button(codeRow, "REDEEM", CYAN, function()
		local result = meta("code", box.Text)
		if result and result.ok then
			showToast("CODE ACCEPTED: " .. result.message, GREEN)
			box.Text = ""
		end
	end, 2)
	redeem.Size = UDim2.fromOffset(160, 48)

	button(panel, "BACK", DIM, function()
		if inGame then
			setMenuOpen(false)
		else
			showMain()
		end
	end, 10)
	setFocus(1)
end

showMain = function()
	clearScreen()
	text(panel, { Text = "SIGNAL '85", TextSize = SMALL_SCREEN and 48 or 60, TextColor3 = RED, LayoutOrder = 1 })
	text(panel, { Text = inGame and "PAUSED" or "HOLLOW CREEK, OCTOBER 1985", TextSize = 18, LayoutOrder = 2 })

	local order = 3
	local hasSave = summary and summary.hasSave
	if hasSave then
		text(panel, {
			Text = "SAVED: CHAPTER " .. summary.chapter .. ": " .. summary.title .. " — " .. stageName(summary.stage)
				.. "  (" .. timeAgo((summary.now or 0) - (summary.savedAt or 0)) .. ")",
			Font = Enum.Font.Code, TextSize = 18, TextColor3 = CYAN, LayoutOrder = order,
		})
	else
		text(panel, { Text = noSaveReason(), Font = Enum.Font.Code, TextSize = 18, TextColor3 = RED, LayoutOrder = order })
	end
	order = order + 1

	if inGame then
		button(panel, "RESUME", GREEN, function()
			setMenuOpen(false)
		end, order)
		button(panel, "SAVE GAME", CYAN, doSave, order + 1)
		button(panel, "SHOP", Color3.fromRGB(255, 170, 40), function()
			shopFromGarage = false
			showShop()
		end, order + 2)
		button(panel, "MISSION BRIEFING", AMBER, function()
			showBriefing(ReplicatedStorage:GetAttribute("Chapter") or 1)
		end, order + 3)
		if summary and summary.available then
			button(panel, "CHAPTER SELECT", AMBER, showChapters, order + 4)
		end
		button(panel, "YOUR PILOT", Color3.fromRGB(255, 170, 200), function()
			showCharacter(nil)
		end, order + 5)
		button(panel, "WATCH THE STORY", AMBER, function()
			playStory(showMain)
		end, order + 6)
		button(panel, "SETTINGS", DIM, showSettings, order + 7)
	else
		-- both choices are always shown; CONTINUE explains itself when there is no save
		local continue = button(panel, hasSave and "CONTINUE SAVED GAME" or "CONTINUE (NO SAVE)", hasSave and GREEN or DIM, function()
			if hasSave then
				choose("continue")
			else
				showToast(noSaveReason(), RED)
			end
		end, order)
		if not hasSave then
			continue.TextTransparency = 0.4
		end
		button(panel, "NEW GAME - START FROM CHAPTER 1", hasSave and AMBER or GREEN, function()
			if hasSave then
				showConfirmNew()
			else
				choose("new")
			end
		end, order + 1)
		if summary and summary.available and (summary.bestChapter or 1) > 1 then
			button(panel, "CHAPTER SELECT", AMBER, showChapters, order + 2)
		end
		button(panel, "REWARDS + QUESTS", GOLD, function()
			showRewards()
		end, order + 3)
		button(panel, "YOUR PILOT", Color3.fromRGB(255, 170, 200), function()
			showCharacter(nil)
		end, order + 4)
		button(panel, "WATCH THE STORY", AMBER, function()
			playStory(showMain)
		end, order + 5)
		button(panel, "SETTINGS", DIM, showSettings, order + 6)
	end
	setFocus((inGame or hasSave) and 1 or 2)
end

local function openPause()
	if backdrop.Visible or not inGame or player:GetAttribute("IntroActive") then
		return
	end
	setMenuOpen(true)
	showMain()
	task.spawn(function()
		refreshSummary() -- picks up the latest save time and unlocked chapters
		if backdrop.Visible and inGame then
			showMain()
		end
	end)
end

---------------------------------------------------------------------------
-- MENU / SAVE buttons while playing (keys M / K)
---------------------------------------------------------------------------
local corner = make("Frame", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.42, 0), Size = UDim2.fromOffset(96, 160),
	BackgroundTransparency = 1, Visible = false,
}, gui)
list(corner, 8)
local function cornerButton(label, color, onClick, order)
	local b = make("TextButton", {
		Text = label, Font = Enum.Font.Arcade, TextSize = 20, TextColor3 = color, BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.2, BorderSizePixel = 0, Size = UDim2.fromOffset(96, 48), LayoutOrder = order,
	}, corner)
	make("UIStroke", { Color = color, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	b.Activated:Connect(onClick)
	return b
end
cornerButton(IS_PHONE and "MENU" or "MENU [M]", AMBER, openPause, 1)
cornerButton(IS_PHONE and "SAVE" or "SAVE [K]", CYAN, function()
	if inGame and not backdrop.Visible then
		doSave()
	end
end, 2)
cornerButton("REWARDS", GOLD, function()
	if inGame and not backdrop.Visible and not player:GetAttribute("IntroActive") then
		setMenuOpen(true)
		showRewards()
	end
end, 3)

ContextActionService:BindAction("S85_Menu", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		if backdrop.Visible and inGame then
			setMenuOpen(false)
		else
			openPause()
		end
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.M)
ContextActionService:BindAction("S85_Save", function(_, inputState)
	if inputState == Enum.UserInputState.Begin and inGame and not backdrop.Visible and not player:GetAttribute("IntroActive") then
		doSave()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.K)

RunService.Heartbeat:Connect(function()
	corner.Visible = inGame and not backdrop.Visible and not player:GetAttribute("IntroActive")
end)

-- Grand Hotel elevator: "Use elevator" (E / tap) -> pick a floor
ElevatorMenuEvent.OnClientEvent:Connect(function(currentFloor, floors)
	if not inGame or backdrop.Visible then
		return
	end
	setMenuOpen(true)
	clearScreen()
	text(panel, { Text = "ELEVATOR", TextSize = 34, TextColor3 = GREEN, LayoutOrder = 1 })
	text(panel, { Text = "You are on floor " .. tostring(currentFloor) .. ". Where to?", Font = Enum.Font.Code, TextSize = 18, LayoutOrder = 2 })
	for floor = 1, floors do
		local here = floor == currentFloor
		local label = floor == 1 and "FLOOR 1 - LOBBY" or ("FLOOR " .. floor)
		button(panel, here and (label .. " (YOU ARE HERE)") or label, here and DIM or AMBER, function()
			if not here then
				ElevatorGoEvent:FireServer(floor)
			end
			setMenuOpen(false)
		end, 2 + floor)
	end
	button(panel, "CANCEL", DIM, function()
		setMenuOpen(false)
	end, 3 + floors)
	setFocus(currentFloor == 1 and 2 or 1)
end)

-- the Scrap Garage counter in town opens the shop
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, who)
	if prompt.Name == "ShopPrompt" and who == player and inGame and not backdrop.Visible then
		setMenuOpen(true)
		shopFromGarage = true
		showShop()
	end
end)

-- "+10 SCRAP" popups that float up on the right
RewardEvent.OnClientEvent:Connect(function(amount, reason)
	local popup = text(gui, {
		Text = "+" .. tostring(amount) .. " SCRAP" .. (reason and ("  " .. reason) or ""), TextSize = 20, TextColor3 = YELLOW,
		TextStrokeTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Right, AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 0.42, -64), Size = UDim2.fromOffset(360, 24), ZIndex = 15,
	})
	local tween = TweenService:Create(popup, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(1, -12, 0.42, -130), TextTransparency = 1, TextStrokeTransparency = 1,
	})
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
	tween:Play()
end)

---------------------------------------------------------------------------
-- Start: wait for the intro broadcast, then the title menu
---------------------------------------------------------------------------
local waited = os.clock()
while (player:GetAttribute("IntroSeen") == nil and os.clock() - waited < 3) or player:GetAttribute("IntroActive") do
	task.wait(0.1)
end

setMenuOpen(true)
clearScreen()
text(panel, { Text = "SIGNAL '85", TextSize = 60, TextColor3 = RED, LayoutOrder = 1 })
text(panel, { Text = "LOADING...", TextSize = 20, LayoutOrder = 2 })
refreshSummary()
showMain()
