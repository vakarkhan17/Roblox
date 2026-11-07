--[[
	SIGNAL '85  —  Story opening scene (client)
	Put this LocalScript in StarterPlayer > StarterPlayerScripts.

	A Hollow Creek family at home listens to WHCK 85.5 FM when the emergency
	broadcast cuts in; then your pilot (a copy of your own character) goes to
	the window, where a Shiftframe is waiting. "IT CHOSE YOU."

	StartMenu starts it by setting the player attribute PlayStory = true
	(after NEW GAME + YOUR PILOT, or WATCH THE STORY). When the scene ends this
	script sets PlayStory = false. While it plays, IntroActive = true:
	Signal85Client hides its HUD and ignores game input.

	Everything is built locally, far above the map, so other players never see it.
	Skip: the SKIP button, Space, Enter or gamepad A.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
player:SetAttribute("IntroSeen", true) -- tells StartMenu there is no broadcast overlay to wait for

local SOUND_ID = 0 -- optional radio static sound asset id; 0 = no sound

local CHAR_TIME = 0.025 -- typewriter speed on the TV, seconds per character

local LINES = {
	"HOLLOW CREEK, OCTOBER 1985.",
	"AT 11:52 PM THE RADIO TOWER RECEIVED A SIGNAL NOBODY SENT.",
	"MINUTES LATER, A RIFT OPENED EAST OF MAIN STREET.",
	"BEYOND IT LIES THE UNDERGRID — AND THE THINGS THAT LIVE THERE.",
	"PROJECT LOWBAND'S MACHINES HAVE WOKEN UP.",
	"THEY ARE CHOOSING PILOTS.",
	"FIND THE SIGNAL SHARDS. SEAL THE RIFT.",
}

local AMBER = Color3.fromRGB(255, 214, 140)
local RED = Color3.fromRGB(255, 60, 70)
local CYAN = Color3.fromRGB(80, 220, 255)
local SPEAKERS = {
	RADIO = Color3.fromRGB(255, 214, 140), DAD = Color3.fromRGB(120, 200, 255), MOM = Color3.fromRGB(255, 150, 200),
	BROTHER = Color3.fromRGB(150, 255, 160), WHCK = RED,
}

local ROOM = CFrame.new(0, 600, 900) -- the living room floor centre, far above the map

---------------------------------------------------------------------------
-- UI: letterbox, subtitles, captions, fade, SKIP
---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "Signal85Story"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100 -- above the HUD and the menu
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function frame(props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do
		f[k] = v
	end
	f.Parent = props.Parent or gui
	return f
end

local function label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Arcade
	l.TextColor3 = AMBER
	l.TextWrapped = true
	l.TextStrokeTransparency = 0.3
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = props.Parent or gui
	return l
end

frame({ BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.new(1, 0, 0.1, 0), ZIndex = 2 })
frame({ BackgroundColor3 = Color3.new(0, 0, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.1, 0), ZIndex = 2 })
local fade = frame({ BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, ZIndex = 5 })

local speaker = label({
	Text = "", TextSize = 20, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.88, -34), Size = UDim2.new(0.8, 0, 0, 22), ZIndex = 3,
})
local subtitle = label({
	Font = Enum.Font.Code, Text = "", TextSize = 22, TextColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0.88, 0), Size = UDim2.new(0.8, 0, 0, 30), ZIndex = 3,
})
local maxSubtitle = Instance.new("UITextSizeConstraint")
maxSubtitle.MaxTextSize = 22
maxSubtitle.Parent = subtitle
subtitle.TextScaled = true
local caption = label({
	Text = "", TextSize = 46, TextColor3 = RED, TextStrokeTransparency = 0, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.9, 0, 0, 60), ZIndex = 6, TextScaled = true,
})
local maxCaption = Instance.new("UITextSizeConstraint")
maxCaption.MaxTextSize = 46
maxCaption.Parent = caption

local skipButton = Instance.new("TextButton")
skipButton.Text = "SKIP ▸"
skipButton.Font = Enum.Font.Arcade
skipButton.TextSize = 24
skipButton.TextColor3 = AMBER
skipButton.BackgroundColor3 = Color3.fromRGB(6, 5, 9)
skipButton.BackgroundTransparency = 0.2
skipButton.BorderSizePixel = 0
skipButton.AnchorPoint = Vector2.new(1, 1)
skipButton.Position = UDim2.new(1, -20, 1, -20)
skipButton.Size = UDim2.fromOffset(150, 52) -- big enough to tap on a phone
skipButton.ZIndex = 10
skipButton.Parent = gui
local skipStroke = Instance.new("UIStroke")
skipStroke.Color = AMBER
skipStroke.Thickness = 2
skipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
skipStroke.Parent = skipButton

---------------------------------------------------------------------------
-- The set: a 1985 living room, the family, the TV, and a Shiftframe outside
---------------------------------------------------------------------------
local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function at(x, y, z, ry)
	return ROOM * CFrame.new(x, y, z) * CFrame.Angles(0, ry or 0, 0)
end

-- a blocky family member, sitting (origin = seat surface) or standing (origin = floor), facing -Z
local function person(parent, origin, look, scale, seated)
	local m = Instance.new("Model")
	m.Parent = parent
	local function add(size, offset, color)
		part(m, { Size = size * scale, CFrame = origin * CFrame.new(offset * scale), Color = color })
	end
	local torsoY = seated and 1.2 or 3
	add(Vector3.new(2, 2, 1), Vector3.new(0, torsoY, 0), look.shirt)
	add(Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, torsoY + 1.6, 0), look.skin)
	add(Vector3.new(1.3, 0.45, 1.3), Vector3.new(0, torsoY + 2.25, 0.05), look.hair)
	add(Vector3.new(1.3, 0.9 + (look.longHair and 0.8 or 0), 0.35), Vector3.new(0, torsoY + 1.8 - (look.longHair and 0.4 or 0), 0.5), look.hair)
	for _, side in ipairs({ -1, 1 }) do
		add(Vector3.new(0.18, 0.18, 0.05), Vector3.new(side * 0.25, torsoY + 1.7, -0.62), Color3.fromRGB(20, 20, 20)) -- eyes
		add(Vector3.new(0.9, 2, 0.9), Vector3.new(side * 1.45, torsoY, -0.1), look.shirt) -- arms
		if seated then
			add(Vector3.new(0.9, 0.9, 2), Vector3.new(side * 0.5, 0.25, -1), look.pants) -- thighs
			add(Vector3.new(0.9, 2, 0.9), Vector3.new(side * 0.5, -0.8, -1.95), look.pants) -- shins
		else
			add(Vector3.new(0.9, 2, 0.9), Vector3.new(side * 0.5, 1, 0), look.pants)
		end
	end
	return m
end

local function buildSet()
	local set = Instance.new("Model")
	set.Name = "StorySet"
	local WOOD = Color3.fromRGB(110, 72, 44)
	local WALL = Color3.fromRGB(150, 120, 90)

	-- room: 36 wide (x), 30 deep (z), 12 high; TV wall at z = -15, window wall at x = -18
	part(set, { Size = Vector3.new(36, 0.4, 30), CFrame = at(0, -0.2, 0), Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.WoodPlanks })
	part(set, { Size = Vector3.new(36, 0.4, 30), CFrame = at(0, 12.2, 0), Color = Color3.fromRGB(200, 190, 170) })
	part(set, { Size = Vector3.new(36, 12, 0.4), CFrame = at(0, 6, -15), Color = WOOD, Material = Enum.Material.Wood })
	part(set, { Size = Vector3.new(36, 12, 0.4), CFrame = at(0, 6, 15), Color = WALL })
	part(set, { Size = Vector3.new(0.4, 12, 30), CFrame = at(18, 6, 0), Color = WALL })
	-- window wall with a 10 x 6 opening
	part(set, { Size = Vector3.new(0.4, 3, 30), CFrame = at(-18, 1.5, 0), Color = WALL })
	part(set, { Size = Vector3.new(0.4, 3, 30), CFrame = at(-18, 10.5, 0), Color = WALL })
	part(set, { Size = Vector3.new(0.4, 6, 8), CFrame = at(-18, 6, -11), Color = WALL })
	part(set, { Size = Vector3.new(0.4, 6, 12), CFrame = at(-18, 6, 9), Color = WALL })
	part(set, { Size = Vector3.new(0.2, 6, 10), CFrame = at(-18, 6, -2), Color = Color3.fromRGB(150, 170, 200), Material = Enum.Material.Glass, Transparency = 0.7 })
	for _, z in ipairs({ -8, 4 }) do -- curtains
		part(set, { Size = Vector3.new(0.3, 7, 2.5), CFrame = at(-17.6, 6, z), Color = Color3.fromRGB(140, 60, 50), Material = Enum.Material.Fabric })
	end

	-- rug, couch, armchair, coffee table, lamp
	part(set, { Size = Vector3.new(14, 0.1, 9), CFrame = at(0, 0.05, -2), Color = Color3.fromRGB(120, 40, 50), Material = Enum.Material.Fabric })
	local COUCH = Color3.fromRGB(160, 120, 60)
	part(set, { Size = Vector3.new(14, 2, 4), CFrame = at(0, 1, 5), Color = COUCH, Material = Enum.Material.Fabric })
	part(set, { Size = Vector3.new(14, 3.5, 1.2), CFrame = at(0, 2.75, 7.4), Color = COUCH, Material = Enum.Material.Fabric })
	for _, x in ipairs({ -7.5, 7.5 }) do
		part(set, { Size = Vector3.new(1.2, 3, 4.6), CFrame = at(x, 1.5, 5.3), Color = COUCH, Material = Enum.Material.Fabric })
	end
	part(set, { Size = Vector3.new(5, 2, 4.5), CFrame = at(12, 1, 1, -0.5), Color = Color3.fromRGB(90, 110, 80), Material = Enum.Material.Fabric })
	part(set, { Size = Vector3.new(6, 1.4, 3), CFrame = at(0, 0.7, 0), Color = WOOD, Material = Enum.Material.Wood })
	part(set, { Size = Vector3.new(0.3, 6, 0.3), CFrame = at(10, 3, 7), Color = Color3.fromRGB(40, 40, 40) })
	local shade = part(set, { Size = Vector3.new(2, 1.4, 2), CFrame = at(10, 6.5, 7), Color = Color3.fromRGB(255, 220, 160), Material = Enum.Material.Neon })
	local lamp = Instance.new("PointLight")
	lamp.Color = Color3.fromRGB(255, 200, 140)
	lamp.Range = 30
	lamp.Brightness = 1.6
	lamp.Shadows = true
	lamp.Parent = shade

	-- shelf with the radio, and pictures on the walls
	part(set, { Size = Vector3.new(1.5, 0.3, 8), CFrame = at(17.2, 4.5, -4), Color = WOOD })
	local radio = part(set, { Size = Vector3.new(1.4, 1.4, 3), CFrame = at(17.2, 5.35, -4), Color = Color3.fromRGB(60, 40, 30) })
	part(set, { Size = Vector3.new(0.1, 0.5, 2), CFrame = at(16.45, 5.4, -4), Color = AMBER, Material = Enum.Material.Neon })
	for i, x in ipairs({ -10, 8 }) do
		part(set, { Size = Vector3.new(3, 2.4, 0.2), CFrame = at(x, 7.5, 14.7), Color = i == 1 and Color3.fromRGB(80, 120, 160) or Color3.fromRGB(160, 120, 80) })
	end

	-- TV on a cabinet; the screen has three pages: music bars, static, emergency broadcast
	part(set, { Size = Vector3.new(9, 3, 3), CFrame = at(0, 1.5, -13.3), Color = WOOD, Material = Enum.Material.Wood })
	part(set, { Size = Vector3.new(7, 5, 3), CFrame = at(0, 5.5, -13.3), Color = Color3.fromRGB(70, 50, 36), Material = Enum.Material.Wood })
	local screen = part(set, { Size = Vector3.new(5.6, 3.8, 0.1), CFrame = at(0, 5.6, -11.75, math.pi), Color = Color3.fromRGB(10, 10, 14) })
	local screenGlow = Instance.new("SurfaceLight")
	screenGlow.Face = Enum.NormalId.Front
	screenGlow.Range = 16
	screenGlow.Brightness = 2
	screenGlow.Color = Color3.fromRGB(160, 200, 255)
	screenGlow.Parent = screen
	local tv = Instance.new("SurfaceGui")
	tv.Face = Enum.NormalId.Front
	tv.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	tv.PixelsPerStud = 80
	tv.LightInfluence = 0
	tv.Parent = screen
	local music = frame({ Parent = tv, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(16, 10, 40) })
	label({ Parent = music, Text = "WHCK 85.5 FM", TextSize = 48, Position = UDim2.fromScale(0, 0.06), Size = UDim2.new(1, 0, 0, 52), TextColor3 = Color3.fromRGB(255, 90, 160) })
	label({ Parent = music, Text = "LATE NIGHT HITS", Font = Enum.Font.Code, TextSize = 30, Position = UDim2.fromScale(0, 0.22), Size = UDim2.new(1, 0, 0, 36) })
	local bars = {}
	for i = 1, 12 do
		bars[i] = frame({ Parent = music, BackgroundColor3 = CYAN, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.08 + (i - 1) * 0.071, 0, 0.88, 0), Size = UDim2.new(0.05, 0, 0.3, 0) })
	end
	local static = frame({ Parent = tv, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Visible = false })
	local noise = {}
	for x = 0, 11 do
		for y = 0, 7 do
			table.insert(noise, frame({ Parent = static, Position = UDim2.fromScale(x / 12, y / 8), Size = UDim2.fromScale(1 / 12 + 0.002, 1 / 8 + 0.002) }))
		end
	end
	local emergency = frame({ Parent = tv, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(30, 4, 8), Visible = false })
	label({ Parent = emergency, Text = "WHCK CHANNEL 8 — EMERGENCY BROADCAST", TextSize = 30, TextColor3 = RED, Position = UDim2.fromScale(0.04, 0.05), Size = UDim2.new(0.92, 0, 0, 40) })
	local tvLine = label({ Parent = emergency, Font = Enum.Font.Code, Text = "", TextSize = 34, TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromScale(0.06, 0.3), Size = UDim2.fromScale(0.88, 0.6), TextYAlignment = Enum.TextYAlignment.Top })

	-- the family: Dad and Mom on the couch, little brother on the rug
	person(set, at(-3, 2, 4.5), { shirt = Color3.fromRGB(90, 110, 140), pants = Color3.fromRGB(70, 60, 50), skin = Color3.fromRGB(234, 192, 158), hair = Color3.fromRGB(70, 46, 30) }, 1, true)
	person(set, at(3, 2, 4.5), { shirt = Color3.fromRGB(190, 90, 120), pants = Color3.fromRGB(60, 70, 110), skin = Color3.fromRGB(234, 192, 158), hair = Color3.fromRGB(150, 70, 40), longHair = true }, 1, true)
	person(set, at(-1, 0.7, -4), { shirt = Color3.fromRGB(240, 200, 50), pants = Color3.fromRGB(40, 60, 120), skin = Color3.fromRGB(234, 192, 158), hair = Color3.fromRGB(70, 46, 30) }, 0.7, true)

	-- outside the window: ground, a red sky glow, the rift far away, and a Shiftframe waiting
	part(set, { Size = Vector3.new(120, 1, 120), CFrame = at(-80, -1, 0), Color = Color3.fromRGB(40, 60, 36), Material = Enum.Material.Grass })
	local glow = part(set, { Size = Vector3.new(2, 90, 200), CFrame = at(-140, 30, 0), Color = Color3.fromRGB(255, 40, 60), Material = Enum.Material.Neon, Transparency = 0.6 })
	part(set, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 30, 30), CFrame = at(-110, 22, -10, math.pi / 2), Color = Color3.fromRGB(255, 50, 60), Material = Enum.Material.Neon })
	local robot = Instance.new("Model")
	robot.Parent = set
	local STEEL = Color3.fromRGB(70, 92, 125)
	local function rpart(size, x, y, z, color, mat)
		return part(robot, { Size = size, CFrame = at(-34 + x, y, -2 + z, math.pi / 2), Color = color, Material = mat or Enum.Material.DiamondPlate })
	end
	rpart(Vector3.new(6, 7, 3.5), 0, 9.5, 0, STEEL)
	rpart(Vector3.new(3.4, 3, 3.4), 0, 14.6, 0, STEEL)
	rpart(Vector3.new(0.4, 0.7, 3), 1.75, 14.8, 0, CYAN, Enum.Material.Neon) -- visor, facing the house
	for _, side in ipairs({ -1, 1 }) do
		rpart(Vector3.new(2, 7, 2), 0, 9.5, side * 4.2, STEEL)
		rpart(Vector3.new(2.6, 1.4, 3), 0, 13.4, side * 4.2, Color3.fromRGB(255, 170, 40), Enum.Material.Metal)
		rpart(Vector3.new(2.2, 6, 2.2), 0, 3, side * 1.5, STEEL)
	end
	local redLight = Instance.new("PointLight")
	redLight.Color = Color3.fromRGB(255, 50, 60)
	redLight.Range = 40
	redLight.Brightness = 0
	redLight.Parent = part(set, { Size = Vector3.one, CFrame = at(-19, 7, -2), Transparency = 1 })

	set.Parent = workspace
	return {
		set = set, music = music, bars = bars, static = static, noise = noise, emergency = emergency, tvLine = tvLine,
		screenGlow = screenGlow, redLight = redLight, glow = glow, radio = radio,
	}
end

-- a copy of the player's own character (their pilot look), standing at the window
local function placePilot(set)
	local char = player.Character
	if not char then
		return nil
	end
	char.Archivable = true
	local ok, copy = pcall(function()
		return char:Clone()
	end)
	char.Archivable = false
	if not ok or not copy then
		return nil
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("ForceField") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	for _, name in ipairs({ "ShiftframeArmor", "ShiftframeVehicle" }) do
		local layer = copy:FindFirstChild(name)
		if layer then
			layer:Destroy() -- the pilot as themselves, no armor yet
		end
	end
	local look = copy:FindFirstChild("PilotLook")
	if look then
		for _, d in ipairs(look:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 0
			elseif d:IsA("SurfaceGui") then
				d.Enabled = true
			end
		end
	end
	local hum = copy:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	copy.Parent = set
	-- at the window, looking out (towards -X)
	copy:PivotTo(at(-15.5, 3, -2) * CFrame.Angles(0, math.pi / 2, 0))
	return copy
end

---------------------------------------------------------------------------
-- Playback
---------------------------------------------------------------------------
local playing = false
local skipped = false

local function waitOrSkip(seconds)
	local t = 0
	while t < seconds do
		if skipped then
			return false
		end
		t = t + task.wait()
	end
	return not skipped
end

local function say(who, text, seconds)
	speaker.Text = who
	speaker.TextColor3 = SPEAKERS[who] or AMBER
	subtitle.Text = text
	local ok = waitOrSkip(seconds)
	speaker.Text = ""
	subtitle.Text = ""
	return ok
end

local function shot(fromCF, toCF, seconds)
	local cam = workspace.CurrentCamera
	cam.CFrame = fromCF
	TweenService:Create(cam, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = toCF }):Play()
end

local function look(from, to)
	return CFrame.lookAt((ROOM * CFrame.new(from)).Position, (ROOM * CFrame.new(to)).Position)
end

local function fadeTo(transparency, seconds)
	TweenService:Create(fade, TweenInfo.new(seconds), { BackgroundTransparency = transparency }):Play()
	return waitOrSkip(seconds)
end

local function play(refs)
	local heartbeat = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for i, bar in ipairs(refs.bars) do
			bar.Size = UDim2.new(0.05, 0, 0.12 + 0.45 * math.abs(math.sin(t * (2 + i * 0.37) + i)), 0)
		end
		if refs.static.Visible then
			for _, cell in ipairs(refs.noise) do
				local v = math.random()
				cell.BackgroundColor3 = Color3.new(v, v, v)
			end
		end
	end)

	-- 1. a quiet night at home
	shot(look(Vector3.new(14, 8, 13), Vector3.new(-2, 3, -6)), look(Vector3.new(10, 7, 12), Vector3.new(-2, 3, -8)), 9)
	if not fadeTo(1, 1) then return heartbeat end
	if not say("RADIO", "WHCK 85.5 FM, late night hits... the request line is open, Hollow Creek.", 3.5) then return heartbeat end
	if not say("DAD", "Turn it up, I love this one.", 2.5) then return heartbeat end

	-- 2. static, then the emergency broadcast
	shot(look(Vector3.new(0, 6, 2), Vector3.new(0, 5.6, -12)), look(Vector3.new(0, 5.7, -4), Vector3.new(0, 5.6, -12)), 3)
	refs.music.Visible = false
	refs.static.Visible = true
	refs.screenGlow.Color = Color3.new(1, 1, 1)
	if SOUND_ID ~= 0 then
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. SOUND_ID
		s.Parent = gui
		s:Play()
	end
	if not say("RADIO", "*kssshhhhh*", 1.4) then return heartbeat end
	refs.static.Visible = false
	refs.emergency.Visible = true
	refs.screenGlow.Color = RED
	refs.redLight.Brightness = 2.5
	for _, line in ipairs(LINES) do
		refs.tvLine.Text = line
		refs.tvLine.MaxVisibleGraphemes = 0
		local total = utf8.len(line) or #line
		local start = os.clock()
		while true do
			if skipped then
				return heartbeat
			end
			local shown = math.min(math.floor((os.clock() - start) / CHAR_TIME), total)
			refs.tvLine.MaxVisibleGraphemes = shown
			if shown >= total then
				break
			end
			task.wait()
		end
		if not waitOrSkip(1) then return heartbeat end
	end

	-- 3. the family reacts
	shot(look(Vector3.new(-1, 5, -8), Vector3.new(0, 3.5, 5)), look(Vector3.new(1, 4.5, -7), Vector3.new(0, 3.5, 5)), 7)
	if not say("DAD", "What was that?", 2) then return heartbeat end
	if not say("MOM", "Kids... stay away from the window.", 2.4) then return heartbeat end
	if not say("BROTHER", "What's that red light?", 2.2) then return heartbeat end

	-- 4. your pilot at the window, a Shiftframe outside
	shot(look(Vector3.new(-8, 6, 6), Vector3.new(-30, 8, -2)), look(Vector3.new(-11, 6.5, 2), Vector3.new(-34, 12, -2)), 5)
	if not waitOrSkip(2.5) then return heartbeat end
	caption.Text = "IT CHOSE YOU."
	caption.TextColor3 = CYAN
	if not waitOrSkip(2.5) then return heartbeat end
	caption.Text = ""

	-- 5. title card
	if not fadeTo(0, 0.8) then return heartbeat end
	local chapter = ReplicatedStorage:GetAttribute("Chapter") or 1
	caption.TextColor3 = RED
	caption.Text = "CHAPTER " .. chapter .. ": " .. (ReplicatedStorage:GetAttribute("ChapterTitle") or "")
	waitOrSkip(2.2)
	return heartbeat
end

local function finish(set, heartbeat)
	ContextActionService:UnbindAction("S85_StorySkip")
	if heartbeat then
		heartbeat:Disconnect()
	end
	if set then
		set:Destroy()
	end
	caption.Text = ""
	speaker.Text = ""
	subtitle.Text = ""
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		cam.CameraSubject = hum
	end
	gui.Enabled = false
	playing = false
	player:SetAttribute("IntroActive", false)
	player:SetAttribute("PlayStory", false)
end

local function start()
	if playing then
		return
	end
	playing = true
	skipped = false
	player:SetAttribute("IntroActive", true)
	fade.BackgroundTransparency = 0
	gui.Enabled = true

	ContextActionService:BindActionAtPriority("S85_StorySkip", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			skipped = true
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.ButtonA)

	local refs, heartbeat
	local ok, err = pcall(function()
		refs = buildSet()
		placePilot(refs.set)
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		heartbeat = play(refs)
	end)
	if not ok then
		warn("[Story] " .. tostring(err))
	end
	-- always hand control back, even if something errored
	finish(refs and refs.set, heartbeat)
end

skipButton.Activated:Connect(function()
	skipped = true
end)

player:GetAttributeChangedSignal("PlayStory"):Connect(function()
	if player:GetAttribute("PlayStory") == true then
		task.spawn(start)
	end
end)
