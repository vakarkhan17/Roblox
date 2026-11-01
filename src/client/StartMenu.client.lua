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

local function clearScreen()
	for _, child in ipairs(panel:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(buttons)
	table.clear(actions)
	focus = 0
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
			{ "cannon", "YOUR WEAPON", CYAN, "PULSE CANNON: " .. FIRE .. " in robot mode. Each hit also damages enemies around it." },
		},
	},
}

local function stageName(stage)
	return ({ Shards = "Collecting shards", Nodes = "Hive Nodes", Boss = "Mind Warden", Complete = "Complete" })[stage] or tostring(stage)
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
	showBriefing(result.chapter or ReplicatedStorage:GetAttribute("Chapter") or 1)
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
	end, 6)
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
		button(panel, "MISSION BRIEFING", AMBER, function()
			showBriefing(ReplicatedStorage:GetAttribute("Chapter") or 1)
		end, order + 2)
		if summary and summary.available then
			button(panel, "CHAPTER SELECT", AMBER, showChapters, order + 3)
		end
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
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.42, 0), Size = UDim2.fromOffset(96, 104),
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
