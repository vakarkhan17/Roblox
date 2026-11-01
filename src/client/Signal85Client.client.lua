--[[
	SIGNAL '85  —  Client script
	Put this LocalScript in StarterPlayer > StarterPlayerScripts.

	Controls (buttons also appear on mobile):
	  F  Transform (robot <-> vehicle)
	  Q  Blast (robot mode only, aims at your mouse / camera center)
	  E  Shift through the rift (stand next to it)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local remotes = ReplicatedStorage:WaitForChild("Signal85Remotes")
local TransformEvent = remotes:WaitForChild("Transform")
local BlastEvent = remotes:WaitForChild("Blast")
local ShiftEvent = remotes:WaitForChild("Shift")
local NotifyEvent = remotes:WaitForChild("Notify")
local SettingsEvent = remotes:WaitForChild("Settings")
local rifts = workspace:WaitForChild("Rifts")

local RIFT_RANGE = 12
local BLAST_RANGE = 140      -- matches CONFIG.BLAST_RANGE on the server
local BLAST_REPEAT = 0.27    -- hold-to-fire rate (server cooldown is 0.25)
local AIM_ASSIST_DEG = 12    -- touch aim locks on to a Hollower this close to the crosshair

-- touch screen: show on-screen buttons. Phone: also word hints for touch instead of keys
local IS_TOUCH = UserInputService.TouchEnabled
local IS_PHONE = IS_TOUCH and not UserInputService.KeyboardEnabled
local viewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.zero
if viewportSize.X < 50 then -- camera not ready yet
	viewportSize = IS_PHONE and Vector2.new(800, 390) or Vector2.new(1280, 720)
end
local SMALL_SCREEN = math.min(viewportSize.X, viewportSize.Y) <= 500

local AMBER = Color3.fromRGB(255, 214, 140)
local RED = Color3.fromRGB(255, 60, 70)
local CYAN = Color3.fromRGB(80, 220, 255)

---------------------------------------------------------------------------
-- Atmosphere: warm 1985 dusk in town, cold dead night in the Undergrid
---------------------------------------------------------------------------
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Parent = Lighting
local grade = Instance.new("ColorCorrectionEffect")
grade.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.8
bloom.Size = 30
bloom.Threshold = 0.9
bloom.Parent = Lighting

local PRESETS = {
	Town = {
		lighting = { ClockTime = 18.4, Brightness = 2, Ambient = Color3.fromRGB(90, 80, 100), OutdoorAmbient = Color3.fromRGB(130, 110, 120) },
		atmosphere = { Density = 0.3, Haze = 1.5, Glare = 0.4, Color = Color3.fromRGB(255, 190, 150), Decay = Color3.fromRGB(120, 90, 110) },
		grade = { TintColor = Color3.fromRGB(255, 238, 222), Saturation = 0.1, Contrast = 0.1, Brightness = 0 },
	},
	Undergrid = {
		lighting = { ClockTime = 0, Brightness = 0.6, Ambient = Color3.fromRGB(40, 50, 70), OutdoorAmbient = Color3.fromRGB(55, 65, 90) },
		atmosphere = { Density = 0.55, Haze = 3, Glare = 0, Color = Color3.fromRGB(60, 80, 110), Decay = Color3.fromRGB(20, 25, 40) },
		grade = { TintColor = Color3.fromRGB(175, 195, 255), Saturation = -0.5, Contrast = 0.25, Brightness = -0.03 },
	},
	-- Chapter 2 boss fight: the Undergrid turns darker and red
	UndergridBoss = {
		lighting = { ClockTime = 0, Brightness = 0.45, Ambient = Color3.fromRGB(70, 30, 36), OutdoorAmbient = Color3.fromRGB(85, 40, 46) },
		atmosphere = { Density = 0.6, Haze = 3, Glare = 0, Color = Color3.fromRGB(110, 40, 50), Decay = Color3.fromRGB(40, 10, 16) },
		grade = { TintColor = Color3.fromRGB(255, 175, 175), Saturation = -0.3, Contrast = 0.3, Brightness = -0.05 },
	},
}

-- player light setting (- / + keys or HUD buttons), applied on top of the presets
local LIGHT_MIN, LIGHT_MAX = -3, 6
local LIGHT_DEFAULT = 2
local lightLevel = LIGHT_DEFAULT
local currentPreset = "Town"

local function applyPreset(name, duration)
	currentPreset = name
	local preset = PRESETS[name]
	local lift = math.max(lightLevel, 0) * 0.07
	local function lifted(c)
		return c:Lerp(Color3.fromRGB(200, 200, 210), lift)
	end

	local lighting = table.clone(preset.lighting)
	lighting.Ambient = lifted(lighting.Ambient)
	lighting.OutdoorAmbient = lifted(lighting.OutdoorAmbient)
	lighting.ExposureCompensation = lightLevel * 0.25
	local atmo = table.clone(preset.atmosphere)
	atmo.Density = math.max(atmo.Density - math.max(lightLevel, 0) * 0.03, 0.1)
	local look = table.clone(preset.grade)
	look.Brightness = look.Brightness + lightLevel * 0.03

	local info = TweenInfo.new(duration, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, lighting):Play()
	TweenService:Create(atmosphere, info, atmo):Play()
	TweenService:Create(grade, info, look):Play()
end

---------------------------------------------------------------------------
-- HUD (retro arcade look)
---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "Signal85HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Arcade
	l.TextColor3 = AMBER
	l.TextStrokeTransparency = 0.4
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local panel = Instance.new("Frame")
panel.Position = UDim2.fromOffset(16, 56)
panel.Size = UDim2.fromOffset(280, 186)
panel.BackgroundColor3 = Color3.fromRGB(10, 8, 14)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel = 0
panel.Parent = gui
local stroke = Instance.new("UIStroke")
stroke.Color = AMBER
stroke.Thickness = 2
stroke.Parent = panel

-- shrink the left-side HUD on phones so it leaves room for the thumbstick
local HUD_SCALE = SMALL_SCREEN and 0.75 or 1
local function hudScale(frame)
	local s = Instance.new("UIScale")
	s.Scale = HUD_SCALE
	s.Parent = frame
end
hudScale(panel)

label(panel, { Text = "SIGNAL '85", TextSize = 26, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 28), TextColor3 = RED })
local modeLabel = label(panel, { Text = "MODE: ROBOT", TextSize = 18, Position = UDim2.fromOffset(12, 42), Size = UDim2.new(1, -24, 0, 20) })
local worldLabel = label(panel, { Text = "WORLD: HOLLOW CREEK", TextSize = 18, Position = UDim2.fromOffset(12, 64), Size = UDim2.new(1, -24, 0, 20) })
local carryLabel = label(panel, { Text = "SHARDS CARRIED: 0", TextSize = 18, Position = UDim2.fromOffset(12, 86), Size = UDim2.new(1, -24, 0, 20), TextColor3 = CYAN })
local sealLabel = label(panel, { Text = "RIFT SEAL", TextSize = 14, Position = UDim2.fromOffset(12, 110), Size = UDim2.new(1, -24, 0, 14) })

local barBack = Instance.new("Frame")
barBack.Position = UDim2.fromOffset(12, 128)
barBack.Size = UDim2.new(1, -24, 0, 10)
barBack.BackgroundColor3 = Color3.fromRGB(40, 30, 40)
barBack.BorderSizePixel = 0
barBack.Parent = panel
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Color3.fromRGB(60, 255, 140)
barFill.BorderSizePixel = 0
barFill.Parent = barBack

local function button(parent, text, props)
	local b = Instance.new("TextButton")
	b.Text = text
	b.Font = Enum.Font.Arcade
	b.TextSize = 20
	b.TextColor3 = AMBER
	b.BackgroundColor3 = Color3.fromRGB(30, 24, 36)
	b.BorderSizePixel = 0
	for k, v in pairs(props) do
		b[k] = v
	end
	local s = Instance.new("UIStroke")
	s.Color = AMBER
	s.Thickness = 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = b
	b.Parent = parent
	return b
end

-- light setting row
local lightLabel = label(panel, { Text = "LIGHT", TextSize = 18, Position = UDim2.fromOffset(12, 150), Size = UDim2.fromOffset(120, 26) })
local lightDown = button(panel, "-", { Position = UDim2.fromOffset(176, 148), Size = UDim2.fromOffset(40, 30) })
local lightUp = button(panel, "+", { Position = UDim2.fromOffset(226, 148), Size = UDim2.fromOffset(40, 30) })
local helpButton = button(panel, "?", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(32, 28) })

-- current objective, under the panel
local objective = Instance.new("Frame")
objective.Position = UDim2.fromOffset(16, 56 + math.floor(196 * HUD_SCALE))
objective.Size = UDim2.fromOffset(280, 0)
objective.AutomaticSize = Enum.AutomaticSize.Y
objective.BackgroundColor3 = Color3.fromRGB(10, 8, 14)
objective.BackgroundTransparency = 0.25
objective.BorderSizePixel = 0
objective.Parent = gui
hudScale(objective)
local objectiveStroke = Instance.new("UIStroke")
objectiveStroke.Color = CYAN
objectiveStroke.Thickness = 2
objectiveStroke.Parent = objective
local objectivePad = Instance.new("UIPadding")
objectivePad.PaddingTop = UDim.new(0, 8)
objectivePad.PaddingBottom = UDim.new(0, 8)
objectivePad.PaddingLeft = UDim.new(0, 12)
objectivePad.PaddingRight = UDim.new(0, 12)
objectivePad.Parent = objective
local objectiveList = Instance.new("UIListLayout")
objectiveList.Padding = UDim.new(0, 4)
objectiveList.SortOrder = Enum.SortOrder.LayoutOrder
objectiveList.Parent = objective
local chapterLabel = label(objective, {
	Text = "", TextSize = 16, TextColor3 = RED, TextWrapped = true, LayoutOrder = 0,
	Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y,
})
label(objective, { Text = "OBJECTIVE", TextSize = 16, TextColor3 = CYAN, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1 })
local objectiveText = label(objective, {
	Text = "", Font = Enum.Font.Code, TextSize = 16, TextWrapped = true, LayoutOrder = 2,
	Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y,
})
local objectiveGoal = label(objective, {
	Text = "", Font = Enum.Font.Code, TextSize = 14, TextWrapped = true, TextColor3 = Color3.fromRGB(60, 255, 140), LayoutOrder = 3,
	Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y,
})

-- boss health bar, top-center while Stage == "Boss"
local bossBar = Instance.new("Frame")
bossBar.AnchorPoint = Vector2.new(0.5, 0)
bossBar.Position = UDim2.new(0.5, 0, 0, SMALL_SCREEN and 44 or 60)
bossBar.Size = UDim2.new(0.5, 0, 0, 56)
bossBar.BackgroundTransparency = 1
bossBar.Visible = false
bossBar.Parent = gui
local bossBarMax = Instance.new("UISizeConstraint")
bossBarMax.MaxSize = Vector2.new(520, 56)
bossBarMax.Parent = bossBar
label(bossBar, {
	Text = "THE MIND WARDEN", TextSize = 20, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, 0, 0, 20),
})
local bossBack = Instance.new("Frame")
bossBack.Position = UDim2.fromOffset(0, 24)
bossBack.Size = UDim2.new(1, 0, 0, 12)
bossBack.BackgroundColor3 = Color3.fromRGB(40, 20, 26)
bossBack.BorderSizePixel = 0
bossBack.Parent = bossBar
local bossStroke = Instance.new("UIStroke")
bossStroke.Color = RED
bossStroke.Thickness = 2
bossStroke.Parent = bossBack
local bossFill = Instance.new("Frame")
bossFill.Size = UDim2.fromScale(1, 1)
bossFill.BackgroundColor3 = RED
bossFill.BorderSizePixel = 0
bossFill.Parent = bossBack
local bossOpenLabel = label(bossBar, {
	Text = "HEAD OPEN - SHOOT NOW!", TextSize = 16, TextColor3 = Color3.fromRGB(255, 235, 140), TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 16), Visible = false,
})

local controlsHint = label(gui, {
	Text = "[F] TRANSFORM   [Q] BLAST (ROBOT)   [E] SHIFT AT RIFT   [H] HELP   [-][+] LIGHT",
	TextScaled = true, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16), Size = UDim2.new(1, -32, 0, 20),
})
local hintSize = Instance.new("UITextSizeConstraint")
hintSize.MaxTextSize = 16
hintSize.Parent = controlsHint
controlsHint.Visible = not IS_PHONE -- phones get on-screen buttons instead

-- how to play
local help = Instance.new("Frame")
help.AnchorPoint = Vector2.new(0.5, 0.5)
help.Position = UDim2.fromScale(0.5, 0.5)
help.Size = UDim2.new(0.9, 0, 0, 0)
help.AutomaticSize = Enum.AutomaticSize.Y
help.BackgroundColor3 = Color3.fromRGB(10, 8, 14)
help.BackgroundTransparency = 0.08
help.BorderSizePixel = 0
help.ZIndex = 20
help.Visible = false
help.Parent = gui
local helpMax = Instance.new("UISizeConstraint")
helpMax.MaxSize = Vector2.new(620, math.huge)
helpMax.Parent = help
local helpStroke = Instance.new("UIStroke")
helpStroke.Color = AMBER
helpStroke.Thickness = 2
helpStroke.Parent = help
local helpPad = Instance.new("UIPadding")
helpPad.PaddingTop = UDim.new(0, 14)
helpPad.PaddingBottom = UDim.new(0, 14)
helpPad.PaddingLeft = UDim.new(0, 18)
helpPad.PaddingRight = UDim.new(0, 18)
helpPad.Parent = help
local helpList = Instance.new("UIListLayout")
helpList.Padding = UDim.new(0, 8)
helpList.SortOrder = Enum.SortOrder.LayoutOrder
helpList.HorizontalAlignment = Enum.HorizontalAlignment.Center
helpList.Parent = help
if SMALL_SCREEN then
	local helpScale = Instance.new("UIScale")
	helpScale.Scale = 0.72
	helpScale.Parent = help
end

local function helpText(order, text, props)
	local l = label(help, {
		Text = text, Font = Enum.Font.Code, TextSize = 16, TextWrapped = true, ZIndex = 21, LayoutOrder = order,
		Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y,
	})
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end

helpText(1, "HOW TO PLAY", { Font = Enum.Font.Arcade, TextSize = 28, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Center })
helpText(2, "A rift has opened to the Undergrid. Your team's job: bring back Signal Shards and seal it.", { TextColor3 = CYAN })
local helpSteps = helpText(3, "")
if IS_PHONE then
	helpText(4, "TOUCH CONTROLS (buttons on the right)\n"
		.. "TO CAR / TO ROBOT  Transform: robot (can shoot) <-> car (fast, no weapon)\n"
		.. "BLAST  Hold to fire at the + in the middle of the screen (robot mode). Swipe to turn the camera; it locks on to Hollowers near the +.\n"
		.. "RIFT  Lights up next to the red ring. Tap it to cross.\n"
		.. "?  Show / hide this help      - / +  Darker / brighter (top-left panel)\n"
		.. "MENU / SAVE  Buttons on the right: save, mission briefing, chapter select\n"
		.. "Follow the yellow marker to your next target.")
else
	helpText(4, "CONTROLS\n"
		.. "F  Transform: robot (can shoot) <-> car (fast, no weapon)\n"
		.. "Q or LEFT MOUSE  Hold to fire the Pulse Cannon (robot mode, aim with the mouse)\n"
		.. "E  Cross the rift (stand next to the red ring)\n"
		.. "H  Show / hide this help      - / +  Darker / brighter\n"
		.. "M  Menu (save, mission briefing, chapter select)      K  Save\n"
		.. "Follow the yellow marker to your next target.")
end
helpText(5, "Watch out: Hollowers drift through walls. If you die, the shards you carry are lost.", { TextColor3 = RED })
local helpClose = button(help, "GOT IT", { Size = UDim2.fromOffset(160, 40), ZIndex = 21, LayoutOrder = 6 })

local function setHelpVisible(visible)
	help.Visible = visible
end

---------------------------------------------------------------------------
-- Touch controls: TRANSFORM, BLAST (hold to fire), RIFT, plus a crosshair
---------------------------------------------------------------------------
local currentMode = "Robot"
local nearRift = false

local touchPad = Instance.new("Frame")
touchPad.Name = "TouchControls"
touchPad.AnchorPoint = Vector2.new(1, 1)
-- sits above Roblox's jump button (smaller and lower on phones)
touchPad.Position = SMALL_SCREEN and UDim2.new(1, -12, 1, -105) or UDim2.new(1, -24, 1, -225)
touchPad.Size = UDim2.fromOffset(3 * 78 + 2 * 10, 78)
touchPad.BackgroundTransparency = 1
touchPad.Visible = IS_TOUCH
touchPad.Parent = gui
local padList = Instance.new("UIListLayout")
padList.FillDirection = Enum.FillDirection.Horizontal
padList.HorizontalAlignment = Enum.HorizontalAlignment.Right
padList.Padding = UDim.new(0, 10)
padList.SortOrder = Enum.SortOrder.LayoutOrder
padList.Parent = touchPad

local function touchButton(order, text, color)
	local b = button(touchPad, text, {
		Size = UDim2.fromOffset(78, 78), TextScaled = true, TextWrapped = true, TextColor3 = color,
		BackgroundTransparency = 0.2, LayoutOrder = order,
	})
	local s = b:FindFirstChildOfClass("UIStroke")
	s.Color = color
	s.Thickness = 2
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = b
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = 18
	size.Parent = b
	return b
end

local transformButton = touchButton(1, "TO CAR", CYAN)
local blastButton = touchButton(2, "BLAST", RED)
local riftButton = touchButton(3, "RIFT", AMBER)

local crosshair = label(gui, {
	Text = "+", TextSize = 40, TextColor3 = RED, TextStrokeTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40), Visible = false,
})

local function refreshTouch()
	local robot = currentMode ~= "Vehicle"
	transformButton.Text = robot and "TO CAR" or "TO ROBOT"
	blastButton.TextTransparency = robot and 0 or 0.7
	blastButton.BackgroundTransparency = robot and 0.2 or 0.6
	crosshair.Visible = IS_TOUCH and robot
	riftButton.TextTransparency = nearRift and 0 or 0.7
	riftButton.BackgroundTransparency = nearRift and 0.2 or 0.6
	if nearRift then
		riftButton.Text = player:GetAttribute("Dimension") == "Undergrid" and "EXIT RIFT" or "ENTER RIFT"
	else
		riftButton.Text = "RIFT"
	end
end

local prompt = label(gui, {
	Text = "", TextSize = 24, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -90), Size = UDim2.fromOffset(500, 30),
})

local banner = label(gui, {
	Text = "", TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, TextStrokeTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.new(0.9, 0, 0, 40), TextWrapped = true,
})

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = RED
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 10
flash.Parent = gui

local bannerToken = 0
local function showBanner(text, color)
	bannerToken = bannerToken + 1
	local token = bannerToken
	banner.Text = text
	banner.TextColor3 = color or AMBER
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.3
	task.delay(3.5, function()
		if token == bannerToken then
			TweenService:Create(banner, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function screenFlash(color)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.2
	TweenService:Create(flash, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
end

---------------------------------------------------------------------------
-- Camera shake (used on transform)
---------------------------------------------------------------------------
local function shake(duration, strength)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local t = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		t = t + dt
		if t >= duration or not hum.Parent then
			hum.CameraOffset = Vector3.zero
			conn:Disconnect()
			return
		end
		local s = strength * (1 - t / duration)
		hum.CameraOffset = Vector3.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
	end)
end

---------------------------------------------------------------------------
-- State -> HUD
---------------------------------------------------------------------------
local function refreshWorld()
	local dim = player:GetAttribute("Dimension") or "Town"
	worldLabel.Text = dim == "Undergrid" and "WORLD: THE UNDERGRID" or "WORLD: HOLLOW CREEK"
	worldLabel.TextColor3 = dim == "Undergrid" and RED or AMBER
	return dim
end

local function refreshCarry()
	carryLabel.Text = "SHARDS CARRIED: " .. tostring(player:GetAttribute("Carrying") or 0)
end

local function stage()
	return ReplicatedStorage:GetAttribute("Stage") or "Shards"
end

local SEAL_LABELS = { Shards = "RIFT SEAL", Nodes = "HIVE NODES DESTROYED", Boss = "MIND WARDEN DAMAGE", Complete = "CHAPTER COMPLETE" }

local function refreshSeal()
	local progress = ReplicatedStorage:GetAttribute("Progress") or 0
	local goal = math.max(ReplicatedStorage:GetAttribute("Goal") or 1, 1)
	local s = stage()
	sealLabel.Text = (SEAL_LABELS[s] or "PROGRESS") .. ((s == "Shards" or s == "Nodes") and ("  " .. progress .. "/" .. goal) or "")
	TweenService:Create(barFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(math.clamp(progress / goal, 0, 1), 1) }):Play()
end

local function refreshObjective()
	local progress = ReplicatedStorage:GetAttribute("Progress") or 0
	local goal = ReplicatedStorage:GetAttribute("Goal") or 1
	local chapter = ReplicatedStorage:GetAttribute("Chapter") or 1
	local s = stage()
	local inUndergrid = player:GetAttribute("Dimension") == "Undergrid"
	local carrying = player:GetAttribute("Carrying") or 0
	local cross = IS_PHONE and "tap RIFT" or "press [E]"
	local enter = "Go to the red rift in the field east of Main Street and " .. cross .. " to enter the Undergrid."

	chapterLabel.Text = "CHAPTER " .. chapter .. ": " .. (ReplicatedStorage:GetAttribute("ChapterTitle") or "")
	objectiveGoal.Text = ""
	if s == "Complete" and chapter == 1 then
		objectiveText.Text = "RIFT SEALED! But the signal does not stop... Chapter 2 begins soon."
	elseif s == "Complete" then
		objectiveText.Text = "THE SIGNAL IS QUIET... FOR NOW. Explore freely."
	elseif s == "Nodes" then
		objectiveText.Text = inUndergrid and "DESTROY THE HIVE NODES IN THE UNDERGRID (" .. progress .. "/" .. goal .. "). ROBOT MODE + BLAST."
			or enter .. " Then destroy the Hive Nodes."
		objectiveGoal.Text = "HIVE NODES: " .. progress .. "/" .. goal .. " DESTROYED"
	elseif s == "Boss" then
		objectiveText.Text = inUndergrid and "DEFEAT THE MIND WARDEN BY THE RADIO TOWER. SHOOT IT WHEN ITS HEAD OPENS. JUMP OVER SHOCKWAVES."
			or enter .. " The Mind Warden waits by the radio tower."
	elseif carrying > 0 and inUndergrid then
		objectiveText.Text = "You have shards! Go back to the red rift and " .. cross .. " to return to Hollow Creek."
	elseif carrying > 0 then
		objectiveText.Text = "Deliver your shards: drive to the green console under the radio tower (north end of the road)."
	elseif inUndergrid then
		objectiveText.Text = "Find the glowing blue Signal Shards and touch them to pick them up."
	else
		objectiveText.Text = enter
	end
	if s == "Shards" then
		objectiveGoal.Text = "TEAM GOAL: " .. progress .. "/" .. goal .. " SHARDS DELIVERED"
	end
	objectiveGoal.Visible = objectiveGoal.Text ~= ""

	local crossStep = IS_PHONE and "Tap RIFT" or "Press E"
	helpSteps.Text = "CHAPTER 1: SEAL THE RIFT\n"
		.. "1. Go to the red rift in the field east of Main Street. " .. crossStep .. " to cross into the Undergrid.\n"
		.. "2. Find the glowing blue Signal Shards and touch them to pick them up.\n"
		.. "3. Go back to the rift and " .. string.lower(crossStep) .. " to return to Hollow Creek.\n"
		.. "4. Drive the shards to the green console under the radio tower (north end of the road). Deliver 6 as a team.\n"
		.. "CHAPTER 2: THE SOURCE\n"
		.. "5. Destroy the 3 pulsing red Hive Nodes in the Undergrid (robot mode + BLAST).\n"
		.. "6. Defeat the Mind Warden by the Undergrid radio tower: shoot it only while its head is open, "
		.. "jump over its red shockwaves (car mode takes half damage)."
end

local function worldPreset()
	if player:GetAttribute("Dimension") ~= "Undergrid" then
		return "Town"
	end
	return stage() == "Boss" and "UndergridBoss" or "Undergrid"
end

local function refreshBoss()
	local fighting = stage() == "Boss"
	bossBar.Visible = fighting
	if fighting then
		local hp = ReplicatedStorage:GetAttribute("BossHealth") or 0
		local maxHp = math.max(ReplicatedStorage:GetAttribute("BossMaxHealth") or 1, 1)
		TweenService:Create(bossFill, TweenInfo.new(0.2), { Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1) }):Play()
		bossOpenLabel.Visible = ReplicatedStorage:GetAttribute("BossOpen") == true
	end
end

local function refreshLight()
	local sign = lightLevel > 0 and "+" or ""
	lightLabel.Text = "LIGHT " .. sign .. lightLevel
	lightDown.AutoButtonColor = lightLevel > LIGHT_MIN
	lightUp.AutoButtonColor = lightLevel < LIGHT_MAX
	lightDown.TextTransparency = lightLevel > LIGHT_MIN and 0 or 0.6
	lightUp.TextTransparency = lightLevel < LIGHT_MAX and 0 or 0.6
end

local function setLight(level)
	level = math.clamp(math.floor(level), LIGHT_MIN, LIGHT_MAX)
	if level ~= lightLevel then
		lightLevel = level
		applyPreset(currentPreset, 0.25)
		refreshLight()
		player:SetAttribute("LightLevel", level)
		SettingsEvent:FireServer(level) -- kept in the save
	end
end

local function changeLight(delta)
	setLight(lightLevel + delta)
end

-- the saved LIGHT setting arrives through StartMenu
player:GetAttributeChangedSignal("LightLevel"):Connect(function()
	local level = player:GetAttribute("LightLevel")
	if typeof(level) == "number" then
		setLight(level)
	end
end)

lightDown.Activated:Connect(function()
	changeLight(-1)
end)
lightUp.Activated:Connect(function()
	changeLight(1)
end)
helpButton.Activated:Connect(function()
	setHelpVisible(not help.Visible)
end)
helpClose.Activated:Connect(function()
	setHelpVisible(false)
end)

player:GetAttributeChangedSignal("Dimension"):Connect(function()
	local dim = refreshWorld()
	applyPreset(worldPreset(), 1.5)
	screenFlash(dim == "Undergrid" and RED or AMBER)
	refreshObjective()
	refreshTouch()
end)
player:GetAttributeChangedSignal("Carrying"):Connect(function()
	refreshCarry()
	refreshObjective()
end)

-- hide the HUD while the intro broadcast is playing
-- (and while the start / pause menu is open)
local function refreshIntro()
	gui.Enabled = not player:GetAttribute("IntroActive") and not player:GetAttribute("MenuActive")
end
player:GetAttributeChangedSignal("MenuActive"):Connect(refreshIntro)
player:GetAttributeChangedSignal("IntroActive"):Connect(refreshIntro)
refreshIntro()
ReplicatedStorage:GetAttributeChangedSignal("Progress"):Connect(function()
	refreshSeal()
	refreshObjective()
end)
ReplicatedStorage:GetAttributeChangedSignal("Goal"):Connect(function()
	refreshSeal()
	refreshObjective()
end)
for _, name in ipairs({ "Chapter", "ChapterTitle" }) do
	ReplicatedStorage:GetAttributeChangedSignal(name):Connect(refreshObjective)
end
ReplicatedStorage:GetAttributeChangedSignal("Stage"):Connect(function()
	refreshSeal()
	refreshObjective()
	refreshBoss()
	if player:GetAttribute("Dimension") == "Undergrid" then
		applyPreset(worldPreset(), 2)
	end
end)
for _, name in ipairs({ "BossHealth", "BossMaxHealth", "BossOpen" }) do
	ReplicatedStorage:GetAttributeChangedSignal(name):Connect(refreshBoss)
end

local function hookCharacter(char)
	local function refreshMode()
		local mode = char:GetAttribute("Mode") or "Robot"
		modeLabel.Text = "MODE: " .. string.upper(mode)
		modeLabel.TextColor3 = mode == "Vehicle" and CYAN or AMBER
		currentMode = mode
		refreshTouch()
	end
	char:GetAttributeChangedSignal("Mode"):Connect(refreshMode)
	refreshMode()
end
player.CharacterAdded:Connect(hookCharacter)
if player.Character then
	hookCharacter(player.Character)
end

TransformEvent.OnClientEvent:Connect(function(char, mode)
	if char == player.Character then
		shake(0.35, mode == "Vehicle" and 0.8 or 0.5)
		screenFlash(CYAN)
	end
end)

NotifyEvent.OnClientEvent:Connect(function(text, color)
	showBanner(text, color)
end)

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
-- touch aim: where the + in the middle of the screen points, locking on to
-- the target closest to it if one is within AIM_ASSIST_DEG and in range.
-- Targets: Hollowers, Hive Nodes, and the Mind Warden's weak point.
local AIM_FOLDERS = { "Creatures", "HiveNodes", "Boss" }

local function crosshairAim()
	local cam = workspace.CurrentCamera
	local camPos = cam.CFrame.Position
	local look = cam.CFrame.LookVector
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")

	if hrp then
		local best, bestDot = nil, math.cos(math.rad(AIM_ASSIST_DEG))
		for _, folderName in ipairs(AIM_FOLDERS) do
			local folder = workspace:FindFirstChild(folderName)
			for _, m in ipairs(folder and folder:GetChildren() or {}) do
				local p = m:IsA("Model") and (m:FindFirstChild("WeakPoint") or m.PrimaryPart)
				if p and (p.Position - hrp.Position).Magnitude <= BLAST_RANGE then
					local dot = (p.Position - camPos).Unit:Dot(look)
					if dot > bestDot then
						best, bestDot = p, dot
					end
				end
			end
		end
		if best then
			return best.Position
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local result = workspace:Raycast(camPos, look * 400, params)
	return result and result.Position or camPos + look * 400
end

local function aimPoint(fromTouch)
	if fromTouch or (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) then
		return crosshairAim()
	end
	return mouse.Hit.Position
end

local function canAct()
	-- IntroActive: set by IntroBroadcast. MenuActive: set by StartMenu
	return not player:GetAttribute("IntroActive") and not player:GetAttribute("MenuActive")
end

-- hold to keep firing: Q / gamepad R2, the left mouse button, or the touch BLAST button
local fireSource = nil -- whatever is holding the trigger right now
local function startFiring(source, fromTouch)
	if fireSource then
		return
	end
	fireSource = source
	while fireSource == source do
		if canAct() and currentMode ~= "Vehicle" then
			BlastEvent:FireServer(aimPoint(fromTouch))
		end
		task.wait(BLAST_REPEAT)
	end
end
local function stopFiring(source)
	if fireSource == source then
		fireSource = nil
	end
end

local function onAction(actionName, inputState)
	if actionName == "S85_Blast" then
		if inputState == Enum.UserInputState.Begin then
			if canAct() then
				task.spawn(startFiring, "key", false)
			end
		else
			stopFiring("key")
		end
		return Enum.ContextActionResult.Sink
	end
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if not canAct() then
		return Enum.ContextActionResult.Sink
	end
	if actionName == "S85_Transform" then
		TransformEvent:FireServer()
	elseif actionName == "S85_Shift" then
		ShiftEvent:FireServer()
	elseif actionName == "S85_Help" then
		setHelpVisible(not help.Visible)
	elseif actionName == "S85_LightUp" then
		changeLight(1)
	elseif actionName == "S85_LightDown" then
		changeLight(-1)
	end
	return Enum.ContextActionResult.Sink
end

-- keyboard / gamepad only: touch screens use the HUD's own buttons below
ContextActionService:BindAction("S85_Transform", onAction, false, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
ContextActionService:BindAction("S85_Blast", onAction, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonR2)
ContextActionService:BindAction("S85_Shift", onAction, false, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
ContextActionService:BindAction("S85_Help", onAction, false, Enum.KeyCode.H, Enum.KeyCode.ButtonSelect)
ContextActionService:BindAction("S85_LightUp", onAction, false, Enum.KeyCode.Equals, Enum.KeyCode.KeypadPlus, Enum.KeyCode.DPadUp)
ContextActionService:BindAction("S85_LightDown", onAction, false, Enum.KeyCode.Minus, Enum.KeyCode.KeypadMinus, Enum.KeyCode.DPadDown)

transformButton.Activated:Connect(function()
	if canAct() then
		TransformEvent:FireServer()
	end
end)
riftButton.Activated:Connect(function()
	if canAct() then
		ShiftEvent:FireServer()
	end
end)

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end
-- touch BLAST button: hold to fire at the crosshair
blastButton.InputBegan:Connect(function(input)
	if isPress(input) and canAct() then
		startFiring(input, true)
	end
end)
-- laptop: hold the left mouse button to fire at the mouse (clicks on buttons don't count)
UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not processed and not IS_PHONE and canAct() then
		startFiring("mouse", false)
	end
end)
-- listen globally so a finger sliding off the button still stops firing
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		stopFiring("mouse")
	end
	if typeof(fireSource) == "Instance" and isPress(input)
		and (input == fireSource or input.UserInputType == Enum.UserInputType.MouseButton1) then
		stopFiring(fireSource)
	end
end)

---------------------------------------------------------------------------
-- Rift prompt
---------------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local near = false
	if hrp then
		for _, rift in ipairs(rifts:GetChildren()) do
			if rift.PrimaryPart and (rift.PrimaryPart.Position - hrp.Position).Magnitude < RIFT_RANGE + 4 then
				near = true
			end
		end
	end
	if near then
		local key = IS_PHONE and "TAP RIFT: " or "[E] "
		prompt.Text = key .. ((player:GetAttribute("Dimension") == "Undergrid") and "ESCAPE TO HOLLOW CREEK" or "ENTER THE UNDERGRID")
	else
		prompt.Text = ""
	end
	if near ~= nearRift then
		nearRift = near
		refreshTouch()
	end
end)

-- initial state
applyPreset("Town", 0)
refreshWorld()
refreshCarry()
refreshSeal()
refreshObjective()
refreshBoss()
refreshLight()
refreshTouch()
-- (HOW TO PLAY no longer opens by itself: StartMenu shows the picture briefing instead)

---------------------------------------------------------------------------
-- Target marker: a yellow diamond on the next target, with the distance.
-- When the target is off-screen it sticks to the screen edge as an arrow.
---------------------------------------------------------------------------
local YELLOW = Color3.fromRGB(255, 235, 140)

local marker = Instance.new("Frame")
marker.AnchorPoint = Vector2.new(0.5, 0.5)
marker.Size = UDim2.fromOffset(150, 70)
marker.BackgroundTransparency = 1
marker.Visible = false
marker.Parent = gui
local diamond = Instance.new("Frame")
diamond.AnchorPoint = Vector2.new(0.5, 0.5)
diamond.Position = UDim2.fromOffset(75, 18)
diamond.Size = UDim2.fromOffset(22, 22)
diamond.Rotation = 45
diamond.BackgroundTransparency = 1
diamond.Parent = marker
local diamondStroke = Instance.new("UIStroke")
diamondStroke.Color = YELLOW
diamondStroke.Thickness = 3
diamondStroke.Parent = diamond
local arrow = label(marker, {
	Text = "▲", TextSize = 34, TextColor3 = YELLOW, TextStrokeTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(75, 18), Size = UDim2.fromOffset(40, 40),
})
local markerText = label(marker, {
	Text = "", Font = Enum.Font.Code, TextSize = 15, TextColor3 = YELLOW, TextStrokeTransparency = 0.2,
	TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 30), TextWrapped = true,
})

local townConsole = nil -- the green console in town (the Undergrid copy has none)
local function findConsole()
	if not (townConsole and townConsole.Parent) then
		townConsole = workspace:FindFirstChild("Console", true)
	end
	return townConsole
end

local function nearestIn(folderName, from, usePart)
	local folder = workspace:FindFirstChild(folderName)
	local best, bestDist = nil, math.huge
	for _, child in ipairs(folder and folder:GetChildren() or {}) do
		local p = child:IsA("BasePart") and child or (child:IsA("Model") and (usePart and child:FindFirstChild(usePart) or child.PrimaryPart))
		if p then
			local d = (p.Position - from).Magnitude
			if d < bestDist then
				best, bestDist = p, d
			end
		end
	end
	return best
end

-- the next thing to go to, following the same logic as the objective box
local function currentTarget(from)
	local s = stage()
	local inUndergrid = player:GetAttribute("Dimension") == "Undergrid"
	local carrying = player:GetAttribute("Carrying") or 0
	local townRift = rifts:FindFirstChild("TownRift")
	local ugRift = rifts:FindFirstChild("UndergridRift")
	if s == "Complete" then
		return nil
	end
	if s == "Shards" and carrying > 0 then
		if inUndergrid then
			return ugRift and ugRift.PrimaryPart, "RIFT - GO HOME"
		end
		return findConsole(), "CONSOLE - DELIVER"
	end
	if not inUndergrid then
		return townRift and townRift.PrimaryPart, "RIFT"
	end
	if s == "Shards" then
		return nearestIn("SignalShards", from), "SHARD"
	elseif s == "Nodes" then
		return nearestIn("HiveNodes", from), "HIVE NODE"
	elseif s == "Boss" then
		return nearestIn("Boss", from, "WeakPoint"), "MIND WARDEN"
	end
	return nil
end

RunService.RenderStepped:Connect(function()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local target, name = nil, nil
	if hrp and gui.Enabled then
		target, name = currentTarget(hrp.Position)
	end
	if not target then
		marker.Visible = false
		return
	end

	local cam = workspace.CurrentCamera
	local size = cam.ViewportSize
	local point, onScreen = cam:WorldToViewportPoint(target.Position)
	local distance = math.floor((target.Position - hrp.Position).Magnitude)
	markerText.Text = name .. "  " .. distance .. "m"
	marker.Visible = true

	if onScreen and point.Z > 0 then
		diamond.Visible = true
		arrow.Visible = false
		marker.Position = UDim2.fromOffset(point.X, point.Y + 16)
	else
		-- off-screen: pin to the edge, pointing the way to turn
		local center = size / 2
		local dir = Vector2.new(point.X, point.Y) - center
		if point.Z < 0 then
			dir = -dir
		end
		if dir.Magnitude < 1 then
			dir = Vector2.new(0, 1)
		end
		local margin = Vector2.new(80, 70)
		local scale = math.min((center.X - margin.X) / math.max(math.abs(dir.X), 1e-3), (center.Y - margin.Y) / math.max(math.abs(dir.Y), 1e-3))
		local pos = center + dir * scale
		diamond.Visible = false
		arrow.Visible = true
		arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) + 90
		marker.Position = UDim2.fromOffset(pos.X, pos.Y + 16)
	end
end)
