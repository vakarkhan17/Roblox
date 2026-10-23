--[[
	SIGNAL '85  —  Intro broadcast (client)
	Put this LocalScript in StarterPlayer > StarterPlayerScripts.

	When the player joins, plays a WHCK Channel 8 emergency broadcast that
	tells the story, then fades out to the game. Plays once per session
	(StarterPlayerScripts do not re-run on respawn).

	While it is showing, Players.LocalPlayer has the attribute
	IntroActive = true. Signal85Client hides its HUD and ignores F/Q/E.

	Skip: the SKIP button, Space, Enter or gamepad A.
]]

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
if player:GetAttribute("IntroSeen") then
	return
end
-- set first, so Signal85Client blocks input as early as possible
player:SetAttribute("IntroActive", true)
player:SetAttribute("IntroSeen", true)

local SOUND_ID = 0 -- static burst sound asset id; 0 = no sound

local CHAR_TIME = 0.03  -- typewriter speed, seconds per character
local LINE_PAUSE = 0.7  -- pause after each line
local END_HOLD = 1.6    -- pause after the last line
local STATIC_TIME = 0.9 -- "signal lost" burst
local FADE_TIME = 0.8   -- fade out to the game
local SKIP_FADE = 0.2

local LINES = {
	"HOLLOW CREEK, OCTOBER 1985.",
	"AT 11:52 PM THE RADIO TOWER RECEIVED A SIGNAL NOBODY SENT.",
	"MINUTES LATER, A RIFT OPENED EAST OF MAIN STREET.",
	"BEYOND IT LIES THE UNDERGRID — AND THE THINGS THAT LIVE THERE.",
	"PROJECT LOWBAND'S MACHINES HAVE WOKEN UP.",
	"YOU ARE A SHIFTFRAME.",
	"FIND THE SIGNAL SHARDS. SEAL THE RIFT.",
}

local AMBER = Color3.fromRGB(255, 214, 140)
local RED = Color3.fromRGB(255, 60, 70)
local BLACK = Color3.fromRGB(6, 5, 9)

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "Signal85Intro"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100 -- above Signal85HUD (0)
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local camera = workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
local bodySize = math.clamp(math.floor(math.min(viewport.Y / 24, viewport.X / 42)), 14, 30)

-- CanvasGroup so the whole broadcast fades out as one layer
local root = Instance.new("CanvasGroup")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = BLACK
root.BorderSizePixel = 0
root.Active = true -- swallow clicks/taps meant for the world
root.Parent = gui

local function frame(props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do
		f[k] = v
	end
	f.Parent = props.Parent or root
	return f
end

local function label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Arcade
	l.TextColor3 = AMBER
	l.TextStrokeTransparency = 0.6
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = props.Parent or root
	return l
end

local function maxTextSize(l, size)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = size
	c.Parent = l
end

-- header: WHCK CHANNEL 8 — EMERGENCY BROADCAST   ● LIVE
local header = frame({
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.07),
	Size = UDim2.new(0.9, 0, 0, 40), ZIndex = 2,
})
local title = label({
	Parent = header, Text = "WHCK CHANNEL 8 — EMERGENCY BROADCAST", TextColor3 = RED, TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromScale(0.8, 1),
})
maxTextSize(title, 34)
local live = label({
	Parent = header, Text = "● LIVE", TextColor3 = RED, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.18, 1),
})
maxTextSize(live, 30)
frame({ Parent = header, BackgroundColor3 = RED, Position = UDim2.new(0, 0, 1, 6), Size = UDim2.new(1, 0, 0, 2) })
local subtitle = label({
	Parent = header, Text = "85.5 FM SIMULCAST  //  HOLLOW CREEK", Font = Enum.Font.Code, TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 0, 1, 14), Size = UDim2.new(1, 0, 0, 20),
})
maxTextSize(subtitle, 18)

-- typewriter lines
local body = frame({
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromScale(0.86, 0.62), ZIndex = 2,
})
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, math.floor(bodySize * 0.5))
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = body

-- CRT: scanlines, vignette, flicker
local SCANLINES = 180
for i = 0, SCANLINES - 1 do
	frame({
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55,
		Position = UDim2.fromScale(0, i / SCANLINES), Size = UDim2.new(1, 0, 0, 1), ZIndex = 3,
	})
end

local function vignette(rotation)
	local v = frame({ BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), ZIndex = 4 })
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.2, 1),
		NumberSequenceKeypoint.new(0.8, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	g.Parent = v
end
vignette(0)
vignette(90)

local flicker = frame({ BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 })

-- "signal lost" static, built from UI cells (no image ids)
local staticLayer = frame({ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6, Visible = false })
local cells = {}
local COLS, ROWS = 24, 14
for x = 0, COLS - 1 do
	for y = 0, ROWS - 1 do
		table.insert(cells, frame({
			Parent = staticLayer, Position = UDim2.fromScale(x / COLS, y / ROWS),
			Size = UDim2.fromScale(1 / COLS + 0.002, 1 / ROWS + 0.002),
		}))
	end
end
local lost = label({
	Text = "SIGNAL LOST", TextColor3 = RED, TextScaled = true, TextStrokeTransparency = 0, ZIndex = 7, Visible = false,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.7, 0.14),
})
maxTextSize(lost, 64)

local skipButton = Instance.new("TextButton")
skipButton.Text = "SKIP ▸"
skipButton.Font = Enum.Font.Arcade
skipButton.TextSize = 24
skipButton.TextColor3 = AMBER
skipButton.BackgroundColor3 = BLACK
skipButton.BackgroundTransparency = 0.2
skipButton.BorderSizePixel = 0
skipButton.AnchorPoint = Vector2.new(1, 1)
skipButton.Position = UDim2.new(1, -20, 1, -20)
skipButton.Size = UDim2.fromOffset(150, 52) -- big enough to tap on mobile
skipButton.ZIndex = 10
skipButton.Parent = root
local skipStroke = Instance.new("UIStroke")
skipStroke.Color = AMBER
skipStroke.Thickness = 2
skipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
skipStroke.Parent = skipButton

local staticSound
if SOUND_ID ~= 0 then
	staticSound = Instance.new("Sound")
	staticSound.SoundId = "rbxassetid://" .. SOUND_ID
	staticSound.Volume = 0.6
	staticSound.Parent = gui
end

---------------------------------------------------------------------------
-- Playback
---------------------------------------------------------------------------
local skipped = false
local finished = false
local connections = {}

table.insert(connections, RunService.RenderStepped:Connect(function()
	local t = os.clock()
	live.Visible = t % 1 < 0.6
	-- subtle brightness flicker with the odd stronger dip
	flicker.BackgroundTransparency = math.random() < 0.02 and 0.9 or 0.95 + math.random() * 0.04
end))

local function finish(fadeTime)
	if finished then
		return
	end
	finished = true
	skipped = true
	ContextActionService:UnbindAction("S85_IntroSkip")
	for _, c in ipairs(connections) do
		c:Disconnect()
	end
	staticLayer.Visible = false
	lost.Visible = false
	skipButton.Visible = false
	player:SetAttribute("IntroActive", false)

	local tween = TweenService:Create(root, TweenInfo.new(fadeTime, Enum.EasingStyle.Sine), { GroupTransparency = 1 })
	tween.Completed:Connect(function()
		gui:Destroy()
	end)
	tween:Play()
end

local function skip()
	finish(SKIP_FADE)
end

skipButton.Activated:Connect(skip)
-- sink Space too, so skipping does not also make the character jump
ContextActionService:BindActionAtPriority("S85_IntroSkip", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		skip()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.ButtonA)

-- returns false if the intro was skipped while waiting
local function waitOrSkip(seconds)
	local t = 0
	while t < seconds do
		if skipped then
			return false
		end
		t += task.wait()
	end
	return not skipped
end

local function typeLine(index, text)
	if skipped then
		return false
	end
	local line = label({
		Parent = body, Text = text, Font = Enum.Font.Code, TextSize = bodySize, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y,
		MaxVisibleGraphemes = 0, LayoutOrder = index,
	})
	local total = utf8.len(text) or #text
	local start = os.clock()
	while true do
		if skipped then
			return false
		end
		local shown = math.min(math.floor((os.clock() - start) / CHAR_TIME), total)
		line.MaxVisibleGraphemes = shown
		if shown >= total then
			return true
		end
		task.wait()
	end
end

local function staticBurst()
	staticLayer.Visible = true
	lost.Visible = true
	if staticSound then
		staticSound:Play()
	end
	local start = os.clock()
	while os.clock() - start < STATIC_TIME do
		if skipped then
			return
		end
		for _, cell in ipairs(cells) do
			local v = math.random() * 0.8
			cell.BackgroundColor3 = Color3.new(v, v, v)
		end
		task.wait()
	end
end

local function play()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	for i, text in ipairs(LINES) do
		if not typeLine(i, text) then
			return
		end
		if not waitOrSkip(i == #LINES and END_HOLD or LINE_PAUSE) then
			return
		end
	end
	staticBurst()
end

task.spawn(function()
	-- always hand control back to the game, even if something errors
	local ok, err = pcall(play)
	if not ok then
		warn("[IntroBroadcast] " .. tostring(err))
	end
	finish(FADE_TIME)
end)
