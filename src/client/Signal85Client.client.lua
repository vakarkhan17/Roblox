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
local RadioEvent = remotes:WaitForChild("Radio")
local HitEvent = remotes:WaitForChild("Hit")
local SuitEvent = remotes:WaitForChild("Suit")
local CycleWeaponEvent = remotes:WaitForChild("CycleWeapon")
local PingEvent = remotes:WaitForChild("Ping")
local rifts = workspace:WaitForChild("Rifts")

local RIFT_RANGE = 12
local BLAST_RANGE = 140      -- matches CONFIG.BLAST_RANGE on the server
local BLAST_REPEAT = 0.27    -- hold-to-fire rate until the server sends the weapon's own (WeaponCooldown)
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
local sunRays = Instance.new("SunRaysEffect")
sunRays.Intensity = 0.06
sunRays.Spread = 0.8
sunRays.Parent = Lighting
-- 80s dusk sky (the Atmosphere colours the horizon; no image ids needed)
local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
sky.SunAngularSize = 18
sky.MoonAngularSize = 9
sky.StarCount = 4000
sky.CelestialBodiesShown = true
sky.Parent = Lighting

-- GRAPHICS LOW (1) / MEDIUM (2) / HIGH (3), chosen in MENU > SETTINGS. Phones start on MEDIUM.
local graphics = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) and 2 or 3
local PARTICLE_SCALE = { 0.25, 0.6, 1 }

local function scaleEmitter(fx)
	if fx:IsA("ParticleEmitter") then
		if fx:GetAttribute("BaseRate") == nil then
			fx:SetAttribute("BaseRate", fx.Rate)
		end
		fx.Rate = fx:GetAttribute("BaseRate") * PARTICLE_SCALE[graphics]
	end
end

local function applyGraphics()
	bloom.Enabled = graphics >= 2
	bloom.Intensity = graphics == 3 and 0.9 or 0.6
	sunRays.Enabled = graphics == 3
	Lighting.GlobalShadows = graphics >= 2
	for _, fx in ipairs(workspace:GetDescendants()) do
		scaleEmitter(fx)
	end
end
workspace.DescendantAdded:Connect(scaleEmitter) -- new exhaust smoke, rift particles...
player:GetAttributeChangedSignal("GraphicsQuality"):Connect(function()
	local q = player:GetAttribute("GraphicsQuality")
	if q == 1 or q == 2 or q == 3 then
		graphics = q
		applyGraphics()
	end
end)

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
	-- Chapter 5: the Undergrid leaks into Hollow Creek (red static storm over the town)
	Storm = {
		lighting = { ClockTime = 20.5, Brightness = 1.2, Ambient = Color3.fromRGB(100, 50, 60), OutdoorAmbient = Color3.fromRGB(120, 60, 70) },
		atmosphere = { Density = 0.45, Haze = 2.5, Glare = 0, Color = Color3.fromRGB(200, 70, 80), Decay = Color3.fromRGB(80, 20, 30) },
		grade = { TintColor = Color3.fromRGB(255, 200, 200), Saturation = -0.1, Contrast = 0.2, Brightness = -0.02 },
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
panel.Size = UDim2.fromOffset(280, 216)
panel.BackgroundColor3 = Color3.fromRGB(10, 8, 14)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel = 0
panel.Parent = gui
local stroke = Instance.new("UIStroke")
stroke.Color = AMBER
stroke.Thickness = 2
stroke.Parent = panel

-- shrink the left-side HUD on phones so it leaves room for the thumbstick
-- plus the HUD SIZE setting (MENU > SETTINGS: small / normal / large)
local HUD_SCALE = SMALL_SCREEN and 0.75 or 1
local HUD_SIZES = { 0.8, 1, 1.25 }
local hudScales = {}
local function hudScaleNow()
	return HUD_SCALE * (HUD_SIZES[player:GetAttribute("HudSize") or 2] or 1)
end
local function hudScale(frame)
	local s = Instance.new("UIScale")
	s.Scale = hudScaleNow()
	s.Parent = frame
	table.insert(hudScales, s)
end
hudScale(panel)

label(panel, { Text = "SIGNAL '85", TextSize = 26, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 28), TextColor3 = RED })
local modeLabel = label(panel, { Text = "MODE: PILOT", TextSize = 18, TextScaled = true, Position = UDim2.fromOffset(12, 42), Size = UDim2.new(1, -24, 0, 20) })
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

-- health bar
local healthLabel = label(panel, { Text = "HEALTH 100", TextSize = 14, Position = UDim2.fromOffset(12, 144), Size = UDim2.new(1, -24, 0, 14) })
local healthBack = Instance.new("Frame")
healthBack.Position = UDim2.fromOffset(12, 160)
healthBack.Size = UDim2.new(1, -24, 0, 10)
healthBack.BackgroundColor3 = Color3.fromRGB(40, 30, 40)
healthBack.BorderSizePixel = 0
healthBack.Parent = panel
local healthFill = Instance.new("Frame")
healthFill.Size = UDim2.fromScale(1, 1)
healthFill.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
healthFill.BorderSizePixel = 0
healthFill.Parent = healthBack

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
local lightLabel = label(panel, { Text = "LIGHT", TextSize = 18, Position = UDim2.fromOffset(12, 180), Size = UDim2.fromOffset(120, 26) })
local lightDown = button(panel, "-", { Position = UDim2.fromOffset(176, 178), Size = UDim2.fromOffset(40, 30) })
local lightUp = button(panel, "+", { Position = UDim2.fromOffset(226, 178), Size = UDim2.fromOffset(40, 30) })
local helpButton = button(panel, "?", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(32, 28) })

-- pilot level: "LV 3" by the title and a thin XP bar along the bottom of the panel (attributes from the server)
local levelLabel = label(panel, { Text = "LV 1", TextSize = 18, TextColor3 = Color3.fromRGB(120, 255, 160), TextXAlignment = Enum.TextXAlignment.Right,
	Position = UDim2.fromOffset(150, 12), Size = UDim2.fromOffset(82, 22) })
local xpBack = Instance.new("Frame")
xpBack.Position = UDim2.new(0, 0, 1, -5)
xpBack.Size = UDim2.new(1, 0, 0, 5)
xpBack.BackgroundColor3 = Color3.fromRGB(30, 40, 34)
xpBack.BorderSizePixel = 0
xpBack.Parent = panel
local xpFill = Instance.new("Frame")
xpFill.Size = UDim2.fromScale(0, 1)
xpFill.BackgroundColor3 = Color3.fromRGB(120, 255, 160)
xpFill.BorderSizePixel = 0
xpFill.Parent = xpBack
local function updateLevel()
	local level = player:GetAttribute("Level") or 1
	local need = math.max(player:GetAttribute("XPNeed") or 100, 1)
	levelLabel.Text = (player:GetAttribute("Title") and "VET " or "LV ") .. level
	TweenService:Create(xpFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp((player:GetAttribute("XP") or 0) / need, 0, 1), 1) }):Play()
end
for _, name in ipairs({ "Level", "XP", "XPNeed", "Title" }) do
	player:GetAttributeChangedSignal(name):Connect(updateLevel)
end
updateLevel()

-- weekend 2x banner (top centre)
local weekendLabel = label(gui, { Text = "2x WEEKEND: DOUBLE SCRAP + XP", TextSize = 18, TextColor3 = Color3.fromRGB(255, 214, 90),
	TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(340, 22), Visible = false })
local function updateWeekend()
	weekendLabel.Visible = ReplicatedStorage:GetAttribute("Weekend2x") == true
end
ReplicatedStorage:GetAttributeChangedSignal("Weekend2x"):Connect(updateWeekend)
updateWeekend()

-- current objective, under the panel
local objective = Instance.new("Frame")
objective.Position = UDim2.fromOffset(16, 56 + math.floor(226 * HUD_SCALE))
objective.Size = UDim2.fromOffset(280, 0)
objective.AutomaticSize = Enum.AutomaticSize.Y
objective.BackgroundColor3 = Color3.fromRGB(10, 8, 14)
objective.BackgroundTransparency = 0.25
objective.BorderSizePixel = 0
objective.Parent = gui
hudScale(objective)
local function applyHudSize()
	local scale = hudScaleNow()
	for _, s in ipairs(hudScales) do
		s.Scale = scale
	end
	objective.Position = UDim2.fromOffset(16, 56 + math.floor(226 * scale))
end
player:GetAttributeChangedSignal("HudSize"):Connect(applyHudSize)
applyHudSize()
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
local bossName = label(bossBar, {
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

-- countdown (Chapter 3 defence and race), top-center
local timerLabel = label(gui, {
	Text = "", TextSize = 30, TextColor3 = Color3.fromRGB(255, 220, 120), TextStrokeTransparency = 0.2,
	TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, SMALL_SCREEN and 104 or 122), Size = UDim2.fromOffset(400, 32), Visible = false,
})

-- walkie-talkie box (Dot and Ricky), bottom-center
local RADIO_COLORS = { DOT = Color3.fromRGB(120, 230, 255), RICKY = Color3.fromRGB(255, 170, 40), WHCK = Color3.fromRGB(255, 60, 70) }
local radioBox = Instance.new("Frame")
radioBox.AnchorPoint = Vector2.new(0.5, 1)
radioBox.Position = UDim2.new(0.5, 0, 1, SMALL_SCREEN and -16 or -48)
radioBox.Size = UDim2.new(0.6, 0, 0, 0)
radioBox.AutomaticSize = Enum.AutomaticSize.Y
radioBox.BackgroundColor3 = Color3.fromRGB(10, 8, 14)
radioBox.BackgroundTransparency = 0.15
radioBox.BorderSizePixel = 0
radioBox.Visible = false
radioBox.Parent = gui
local radioMax = Instance.new("UISizeConstraint")
radioMax.MaxSize = Vector2.new(560, math.huge)
radioMax.Parent = radioBox
local radioStroke = Instance.new("UIStroke")
radioStroke.Thickness = 2
radioStroke.Parent = radioBox
local radioPad = Instance.new("UIPadding")
radioPad.PaddingTop = UDim.new(0, 8)
radioPad.PaddingBottom = UDim.new(0, 8)
radioPad.PaddingLeft = UDim.new(0, 12)
radioPad.PaddingRight = UDim.new(0, 12)
radioPad.Parent = radioBox
local radioList = Instance.new("UIListLayout")
radioList.Padding = UDim.new(0, 4)
radioList.SortOrder = Enum.SortOrder.LayoutOrder
radioList.Parent = radioBox
local radioSpeaker = label(radioBox, { Text = "", TextSize = 16, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1 })
local radioText = label(radioBox, {
	Text = "", Font = Enum.Font.Code, TextSize = SMALL_SCREEN and 14 or 17, TextWrapped = true, LayoutOrder = 2,
	Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y,
})

local controlsHint = label(gui, {
	Text = "[G] SUIT UP/OFF   [F] ROBOT/CAR   [Q] FIRE   [R] SWAP WEAPON   [E] RIFT   [H] HELP   [-][+] LIGHT",
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
		.. "SUIT UP / SUIT OFF  Pilot (you) <-> robot. Crossing the rift suits you up.\n"
		.. "SWAP  Pulse Cannon (shoots far) <-> Shock Baton (close range, through walls)\n"
		.. "TO CAR / TO ROBOT  Robot (can shoot) <-> car (fast, no weapon)\n"
		.. "BLAST  Hold to fire (robot mode). AUTO-AIM shoots the nearest enemy (red ring) by itself.\n"
		.. "RIFT  Lights up next to the red ring. Tap it to cross.\n"
		.. "?  Show / hide this help      - / +  Darker / brighter (top-left panel)\n"
		.. "MENU / SAVE  Buttons on the right: save, mission briefing, chapter select\n"
		.. "Follow the yellow marker to your next target.")
else
	helpText(4, "CONTROLS\n"
		.. "G  Suit up / take the suit off (pilot <-> robot, in town)\n"
		.. "R  Swap weapon: Pulse Cannon (shoots far) <-> Shock Baton (close range, through walls)\n"
		.. "F  Robot (can shoot) <-> car (fast, no weapon)\n"
		.. "Q  Hold to fire with AUTO-AIM: shoots the nearest enemy (red ring), no mouse needed\n"
		.. "LEFT MOUSE  Hold to fire where you point the mouse\n"
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
local currentMode = "Pilot" -- "Pilot" (yourself), "Robot" (suited up, can shoot) or "Vehicle"
local nearRift = false

local touchPad = Instance.new("Frame")
touchPad.Name = "TouchControls"
touchPad.AnchorPoint = Vector2.new(1, 1)
-- sits above Roblox's jump button (smaller and lower on phones)
touchPad.Position = SMALL_SCREEN and UDim2.new(1, -12, 1, -105) or UDim2.new(1, -24, 1, -225)
touchPad.Size = UDim2.fromOffset(6 * 78 + 5 * 10, 78)
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

local suitButton = touchButton(0, "SUIT OFF", AMBER) -- only while suited up in town
local transformButton = touchButton(1, "SUIT UP", CYAN)
local swapButton = touchButton(2, "SWAP", Color3.fromRGB(255, 240, 120)) -- next weapon (robot mode)
local blastButton = touchButton(3, "BLAST", RED)
local riftButton = touchButton(4, "RIFT", AMBER)
local pingButton = touchButton(5, "PING", Color3.fromRGB(80, 220, 255)) -- mark a spot for your team
-- names the tutorial uses to point at them
suitButton.Name, transformButton.Name, swapButton.Name = "SuitButton", "TransformButton", "SwapButton"
blastButton.Name, riftButton.Name, pingButton.Name = "BlastButton", "RiftButton", "PingButton"

local crosshair = label(gui, {
	Text = "+", TextSize = 40, TextColor3 = RED, TextStrokeTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40), Visible = false,
})

local function refreshTouch()
	local robot = currentMode == "Robot"
	transformButton.Text = (currentMode == "Pilot" and "SUIT UP") or (robot and "TO CAR") or "TO ROBOT"
	suitButton.Visible = IS_TOUCH and currentMode ~= "Pilot" and player:GetAttribute("Dimension") ~= "Undergrid"
	swapButton.Visible = IS_TOUCH and robot
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
	if not hum or player:GetAttribute("CameraShake") == false then -- MENU > SETTINGS > CAMERA SHAKE
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

local SEAL_LABELS = {
	Shards = "RIFT SEAL", Nodes = "HIVE NODES DESTROYED", Boss = "MIND WARDEN DAMAGE", Complete = "CHAPTER COMPLETE",
	Files = "LOWBAND FILES", Relays = "RELAYS ONLINE", Carrier = "CARRIER SHUTDOWN", Race = "CODE TIMER",
}
local COUNTED = { Shards = true, Nodes = true, Files = true, Relays = true } -- stages that show "x/y"

local function refreshSeal()
	local progress = ReplicatedStorage:GetAttribute("Progress") or 0
	local goal = math.max(ReplicatedStorage:GetAttribute("Goal") or 1, 1)
	local s = stage()
	sealLabel.Text = (SEAL_LABELS[s] or "PROGRESS") .. (COUNTED[s] and ("  " .. progress .. "/" .. goal) or "")
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

	local labEnter = "Go to the LOWBAND lab in the woods west of town and " .. cross .. " at the small rift by its east door."

	chapterLabel.Text = "CHAPTER " .. chapter .. ": " .. (ReplicatedStorage:GetAttribute("ChapterTitle") or "")
	objectiveGoal.Text = ""
	if s == "Complete" and chapter == 1 then
		objectiveText.Text = "RIFT SEALED! But the signal does not stop... Chapter 2 begins soon."
	elseif s == "Complete" and chapter == 2 then
		objectiveText.Text = "THE MIND WARDEN IS GONE... but the radio tower hears something again. Chapter 3 begins soon."
	elseif s == "Complete" and chapter == 3 then
		objectiveText.Text = "THE CARRIER IS SILENT... but one pulse came from far below. Chapter 4 begins soon."
	elseif s == "Complete" and chapter == 4 then
		objectiveText.Text = "Every radio in Hollow Creek switched on by itself. The Listener knows. TO BE CONTINUED IN CHAPTER 5."
	elseif s == "Complete" and chapter == 5 then
		objectiveText.Text = "The storm is over... but RICKY was pulled into a huge rift. TO BE CONTINUED IN CHAPTER 6."
	elseif s == "Complete" then
		objectiveText.Text = "THE SIGNAL IS QUIET... FOR NOW. Explore freely."
	elseif s == "Rifts" then
		objectiveText.Text = inUndergrid and "The storm is in HOLLOW CREEK. Go back through the rift!"
			or "Close the red MINI-RIFTS in town: stand inside each red circle until it closes. More pilots = faster. Things come out of them!"
		objectiveGoal.Text = "MINI-RIFTS: " .. progress .. "/" .. goal .. " CLOSED"
	elseif s == "Van" then
		objectiveText.Text = inUndergrid and "The WHCK van needs you in HOLLOW CREEK. Go back through the rift!"
			or "DEFEND THE WHCK 85.5 VAN on Main Street until the broadcast ends. Shoot everything that goes for it!"
	elseif s == "TapeRace" then
		objectiveText.Text = player:GetAttribute("CarryingTape") and "YOU HAVE THE TAPES! Drive to the GRAND HOTEL entrance (blue ring) before time runs out. CAR MODE!"
			or "Grab the orange SIGNAL TAPES by the radio tower console and drive them to the GRAND HOTEL entrance (blue ring)."
	elseif s == "Keycards" then
		objectiveText.Text = "Find the 4 green KEYCARDS: 2 in the Grand Hotel here (room 302, the roof), 2 in its Undergrid copy "
			.. "(room 209, behind reception). Open room doors with " .. (IS_PHONE and "the prompt" or "[E]") .. "."
		objectiveGoal.Text = "KEYCARDS: " .. progress .. "/" .. goal .. " FOUND"
	elseif s == "Pylons" then
		objectiveText.Text = inUndergrid and "Site 2 is under the Grand Hotel in HOLLOW CREEK. Go back through the rift."
			or "Go down into SITE 2 (the steel door in the ground floor men's washroom of the Grand Hotel) and destroy the 4 ECHO PYLONS. "
			.. "Echoes shoot back: use the walls as cover."
		objectiveGoal.Text = "ECHO PYLONS: " .. progress .. "/" .. goal .. " DESTROYED"
	elseif s == "Tape" then
		objectiveText.Text = "The vault in Site 2 is open. Go to the DEEP ROOM at the north end and PLAY THE TAPE."
	elseif s == "Files" then
		objectiveText.Text = "Find the glowing yellow LOWBAND files in the old lab in the woods west of town (" .. progress .. "/" .. goal
			.. "). Some are only in the lab's Undergrid copy: use the small rift by the lab's east door."
		objectiveGoal.Text = "FILES: " .. progress .. "/" .. goal .. " FOUND"
	elseif s == "Relays" then
		objectiveText.Text = inUndergrid and "RESTART THE POWER RELAYS around the Undergrid lab: stand inside each glowing circle until it is full."
			or labEnter .. " Then restart the power relays."
		objectiveGoal.Text = "RELAYS: " .. progress .. "/" .. goal .. " ONLINE"
	elseif s == "Carrier" then
		objectiveText.Text = inUndergrid and "DEFEND THE CARRIER in the Undergrid lab until it shuts down. Shoot everything that comes for it!"
			or labEnter .. " The Carrier needs you!"
	elseif s == "Race" then
		objectiveText.Text = inUndergrid and "RACE! Cross back through the rift, then drive to the console under the radio tower before time runs out!"
			or "RACE! Drive to the green console under the radio tower (north end of the road) before time runs out! CAR MODE!"
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
		.. "jump over its red shockwaves (car mode takes half damage).\n"
		.. "CHAPTER 3: LOWBAND\n"
		.. "7. Find 5 LOWBAND files in the lab in the woods west of town (some only in its Undergrid copy).\n"
		.. "8. Stand in the 3 relay circles around the Undergrid lab until they are full.\n"
		.. "9. Defend the Carrier, then race its code to the radio tower console in car mode.\n"
		.. "CHAPTER 4: SITE 2\n"
		.. "10. Find 4 keycards in the Grand Hotel (2 here, 2 in its Undergrid copy), open the steel door in the "
		.. "ground floor men's washroom, destroy the 4 Echo Pylons in Site 2 and play the tape in the deep room.\n"
		.. "CHAPTER 5: STATIC STORM\n"
		.. "11. Close 5 mini-rifts in town (stand in the red circles), defend the WHCK van, then drive the signal "
		.. "tapes from the radio tower to the Grand Hotel entrance."
end

local function worldPreset()
	if player:GetAttribute("Dimension") ~= "Undergrid" then
		return workspace:GetAttribute("Storm") and "Storm" or "Town"
	end
	local s = stage()
	return (s == "Boss" or s == "Carrier") and "UndergridBoss" or "Undergrid"
end

local function refreshBoss()
	local s = stage()
	local fighting = (s == "Boss" or s == "Carrier" or s == "Van") and (ReplicatedStorage:GetAttribute("BossMaxHealth") or 0) > 0
	bossBar.Visible = fighting
	if fighting then
		bossName.Text = ReplicatedStorage:GetAttribute("BossName") or ""
		bossFill.BackgroundColor3 = (s == "Carrier" and Color3.fromRGB(255, 120, 200)) or (s == "Van" and Color3.fromRGB(70, 140, 255)) or RED
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
player:GetAttributeChangedSignal("CarryingTape"):Connect(refreshObjective) -- Chapter 5 tape race

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
-- Chapter 5 storm over the town: re-tint when it starts or ends
workspace:GetAttributeChangedSignal("Storm"):Connect(function()
	applyPreset(worldPreset(), 3)
end)
for _, name in ipairs({ "BossHealth", "BossMaxHealth", "BossOpen", "BossName" }) do
	ReplicatedStorage:GetAttributeChangedSignal(name):Connect(refreshBoss)
end

-- countdown for the Chapter 3 defence and race
RunService.Heartbeat:Connect(function()
	local deadline = ReplicatedStorage:GetAttribute("Deadline") or 0
	local s = stage()
	if deadline <= 0 or (s ~= "Carrier" and s ~= "Race" and s ~= "Van" and s ~= "TapeRace") then
		timerLabel.Visible = false
		return
	end
	local left = math.max(math.ceil(deadline - workspace:GetServerTimeNow()), 0)
	local clock = string.format("%d:%02d", left // 60, left % 60)
	timerLabel.Text = ((s == "Race" and "CODE EXPIRES IN ") or (s == "Van" and "BROADCAST ENDS IN ")
		or (s == "TapeRace" and "TAPES FAIL IN ") or "SHUTDOWN IN ") .. clock
	timerLabel.TextColor3 = left <= 10 and RED or Color3.fromRGB(255, 220, 120)
	timerLabel.Visible = true
end)

local function hookCharacter(char)
	local function refreshMode()
		local mode = char:GetAttribute("Mode") or "Pilot"
		modeLabel.Text = mode == "Robot" and ("ROBOT: " .. (player:GetAttribute("WeaponName") or "PULSE CANNON")) or ("MODE: " .. string.upper(mode))
		modeLabel.TextColor3 = (mode == "Vehicle" and CYAN) or (mode == "Pilot" and Color3.fromRGB(255, 170, 200)) or AMBER
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
-- R / SWAP changes the weapon: show its name while suited up
player:GetAttributeChangedSignal("WeaponName"):Connect(function()
	if currentMode == "Robot" then
		modeLabel.Text = "ROBOT: " .. (player:GetAttribute("WeaponName") or "PULSE CANNON")
	end
end)

TransformEvent.OnClientEvent:Connect(function(char, mode)
	if char == player.Character then
		shake(0.35, mode == "Vehicle" and 0.8 or 0.5)
		screenFlash(CYAN)
	end
end)

NotifyEvent.OnClientEvent:Connect(function(text, color)
	showBanner(text, color)
end)

-- walkie-talkie lines, one at a time, typed out
local radioQueue = {}
local radioBusy = false
local function playRadio()
	if radioBusy then
		return
	end
	radioBusy = true
	while #radioQueue > 0 do
		local msg = table.remove(radioQueue, 1)
		local color = RADIO_COLORS[msg.speaker] or AMBER
		radioSpeaker.Text = msg.speaker == "WHCK" and "WHCK 85.5 FM - LIVE" or ("RADIO CH 4 - " .. msg.speaker)
		radioSpeaker.TextColor3 = color
		radioStroke.Color = color
		radioText.Text = msg.text
		radioText.MaxVisibleGraphemes = 0
		radioBox.Visible = true
		local total = utf8.len(msg.text) or #msg.text
		local start = os.clock()
		while true do
			local shown = math.min(math.floor((os.clock() - start) / 0.025), total)
			radioText.MaxVisibleGraphemes = shown
			if shown >= total then
				break
			end
			task.wait()
		end
		task.wait(math.clamp(total * 0.04, 3, 7))
	end
	radioBox.Visible = false
	radioBusy = false
end
RadioEvent.OnClientEvent:Connect(function(speaker, text)
	table.insert(radioQueue, { speaker = tostring(speaker), text = tostring(text) })
	task.spawn(playRadio)
end)

---------------------------------------------------------------------------
-- Hit feedback: floating damage numbers and a hit marker for your own hits
---------------------------------------------------------------------------
local hitMarker = label(gui, {
	Text = "X", TextSize = 30, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(40, 40), Visible = false, ZIndex = 9,
})
local hitToken = 0

HitEvent.OnClientEvent:Connect(function(position, amount, killed)
	if typeof(position) ~= "Vector3" then
		return
	end
	-- number floating up from the hit (MENU > SETTINGS > DAMAGE NUMBERS can turn it off)
	if player:GetAttribute("DamageNumbers") ~= false then
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position + Vector3.new(math.random() * 2 - 1, 1, math.random() * 2 - 1)
	anchor.Parent = workspace
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(90, 34)
	board.AlwaysOnTop = true
	board.Adornee = anchor
	board.Parent = anchor
	local number = label(board, {
		Text = tostring(amount), TextSize = killed and 30 or 22, TextColor3 = killed and RED or Color3.fromRGB(255, 235, 140),
		TextStrokeTransparency = 0.1, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1),
	})
	TweenService:Create(anchor, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Position = anchor.Position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(number, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	game:GetService("Debris"):AddItem(anchor, 0.9)
	end

	-- hit marker where you aimed: the + on touch, the mouse on a laptop
	hitToken = hitToken + 1
	local token = hitToken
	local at = IS_TOUCH and (workspace.CurrentCamera.ViewportSize / 2) or UserInputService:GetMouseLocation()
	hitMarker.Position = UDim2.fromOffset(at.X, at.Y)
	hitMarker.TextColor3 = killed and RED or Color3.new(1, 1, 1)
	hitMarker.TextSize = killed and 40 or 28
	hitMarker.Visible = true
	task.delay(0.12, function()
		if token == hitToken then
			hitMarker.Visible = false
		end
	end)
end)

---------------------------------------------------------------------------
-- Health: HUD bar and a pulsing red screen edge below 35%
---------------------------------------------------------------------------
local lowHealth = Instance.new("Frame")
lowHealth.Size = UDim2.fromScale(1, 1)
lowHealth.BackgroundColor3 = Color3.fromRGB(200, 0, 20)
lowHealth.BorderSizePixel = 0
lowHealth.Visible = false
lowHealth.ZIndex = 0
lowHealth.Parent = gui
local lowHealthGradient = Instance.new("UIGradient") -- clear middle, red edges
lowHealthGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.18, 1), NumberSequenceKeypoint.new(0.82, 1), NumberSequenceKeypoint.new(1, 0.3),
})
lowHealthGradient.Parent = lowHealth

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		lowHealth.Visible = false
		return
	end
	local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
	healthLabel.Text = "HEALTH " .. math.ceil(hum.Health) .. " / " .. math.floor(hum.MaxHealth)
	healthFill.Size = UDim2.fromScale(ratio, 1)
	healthFill.BackgroundColor3 = ratio < 0.35 and RED or Color3.fromRGB(255, 90, 90):Lerp(Color3.fromRGB(60, 255, 140), ratio)
	local low = ratio < 0.35 and hum.Health > 0
	lowHealth.Visible = low
	if low then
		lowHealth.BackgroundTransparency = 0.55 + math.sin(os.clock() * 6) * 0.2
	end
end)

---------------------------------------------------------------------------
-- Undergrid lightning: red flashes in the sky now and then
---------------------------------------------------------------------------
local lightningFx = Instance.new("ColorCorrectionEffect")
lightningFx.Parent = Lighting
task.spawn(function()
	while true do
		task.wait(math.random(6, 14))
		if player:GetAttribute("Dimension") == "Undergrid" and graphics >= 2 then
			for _ = 1, math.random(1, 2) do
				lightningFx.Brightness = 0.35
				lightningFx.TintColor = Color3.fromRGB(255, 150, 150)
				task.wait(0.06)
				TweenService:Create(lightningFx, TweenInfo.new(0.35), { Brightness = 0, TintColor = Color3.new(1, 1, 1) }):Play()
				task.wait(0.15)
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
-- touch aim: where the + in the middle of the screen points, locking on to
-- the target closest to it if one is within AIM_ASSIST_DEG and in range.
-- Targets: Hollowers, Hive Nodes, and the Mind Warden's weak point.
local AIM_FOLDERS = { "Creatures", "HiveNodes", "Boss", "Site2Targets" }

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

-- AUTO-AIM (MENU > SETTINGS, on by default): Q, gamepad and the touch BLAST button fire at
-- the nearest enemy by themselves, no mouse needed. Enemies in front of the camera count as
-- closer; the Mind Warden only while its head is open. The red ring shows the target.
local function autoAimOn()
	return player:GetAttribute("AutoAim") ~= false
end

local function autoTarget()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end
	local look = workspace.CurrentCamera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	flatLook = flatLook.Magnitude > 0.01 and flatLook.Unit or Vector3.new(0, 0, -1)
	local best, bestScore = nil, math.huge
	for _, folderName in ipairs(AIM_FOLDERS) do
		local folder = workspace:FindFirstChild(folderName)
		if folderName == "Boss" and not ReplicatedStorage:GetAttribute("BossOpen") then
			folder = nil -- shooting its closed head does nothing
		end
		for _, m in ipairs(folder and folder:GetChildren() or {}) do
			local p = m:IsA("Model") and (m:FindFirstChild("WeakPoint") or m.PrimaryPart)
			if p and (m:GetAttribute("Health") or 1) > 0 then
				local to = p.Position - hrp.Position
				local dist = to.Magnitude
				if dist <= BLAST_RANGE then
					local flat = Vector3.new(to.X, 0, to.Z)
					local front = flat.Magnitude > 0.1 and flat.Unit:Dot(flatLook) or 1
					local score = dist * (1.6 - front * 0.6)
					if score < bestScore then
						best, bestScore = p, score
					end
				end
			end
		end
	end
	return best
end

-- auto: fired with Q / gamepad / touch (auto-aim applies); fromTouch: aim at the + when there is no target
local function aimPoint(fromTouch, auto)
	if auto and autoAimOn() then
		local target = autoTarget()
		if target then
			return target.Position
		end
	end
	if fromTouch or auto or (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) then
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
local function startFiring(source, fromTouch, auto)
	if fireSource then
		return
	end
	fireSource = source
	while fireSource == source do
		if canAct() and currentMode == "Robot" then
			local point = aimPoint(fromTouch, auto)
			BlastEvent:FireServer(point)
			-- local only: the tutorial checks its practice targets with these
			player:SetAttribute("LastShot", point)
			player:SetAttribute("ShotCount", (player:GetAttribute("ShotCount") or 0) + 1)
		end
		-- the equipped weapon's fire rate (set by the server), plus a little slack
		local cooldown = player:GetAttribute("WeaponCooldown")
		task.wait(typeof(cooldown) == "number" and cooldown + 0.02 or BLAST_REPEAT)
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
				task.spawn(startFiring, "key", false, true) -- Q / gamepad: auto-aim
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
	elseif actionName == "S85_Suit" then
		SuitEvent:FireServer()
	elseif actionName == "S85_Swap" then
		CycleWeaponEvent:FireServer()
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
ContextActionService:BindAction("S85_Suit", onAction, false, Enum.KeyCode.G, Enum.KeyCode.ButtonB)
ContextActionService:BindAction("S85_Swap", onAction, false, Enum.KeyCode.R, Enum.KeyCode.ButtonL1)
ContextActionService:BindAction("S85_Blast", onAction, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonR2)
ContextActionService:BindAction("S85_Shift", onAction, false, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
ContextActionService:BindAction("S85_Help", onAction, false, Enum.KeyCode.H, Enum.KeyCode.ButtonSelect)
ContextActionService:BindAction("S85_LightUp", onAction, false, Enum.KeyCode.Equals, Enum.KeyCode.KeypadPlus, Enum.KeyCode.DPadUp)
ContextActionService:BindAction("S85_LightDown", onAction, false, Enum.KeyCode.Minus, Enum.KeyCode.KeypadMinus, Enum.KeyCode.DPadDown)

---------------------------------------------------------------------------
-- Ping (task 011): T / PING marks where you look for everyone in the server.
-- The server snaps it onto an enemy (red) or an item (yellow) next to it.
---------------------------------------------------------------------------
do
local function sendPing()
	if not canAct() then
		return
	end
	local cam = workspace.CurrentCamera
	local origin, dir
	if IS_PHONE or not UserInputService.MouseEnabled then
		origin, dir = cam.CFrame.Position, cam.CFrame.LookVector -- the middle of the screen
	else
		local ray = cam:ViewportPointToRay(mouse.X, mouse.Y)
		origin, dir = ray.Origin, ray.Direction
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = workspace:Raycast(origin, dir.Unit * 400, params)
	PingEvent:FireServer(hit and hit.Position or origin + dir.Unit * 120)
end

ContextActionService:BindAction("S85_Ping", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		sendPing()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.T, Enum.KeyCode.DPadLeft)
pingButton.Activated:Connect(sendPing)

local PING_LOOK = {
	enemy = { color = RED, icon = "!" },
	item = { color = Color3.fromRGB(255, 235, 140), icon = "*" },
	spot = { color = CYAN, icon = "v" },
}
PingEvent.OnClientEvent:Connect(function(position, kind, name)
	if typeof(position) ~= "Vector3" then
		return
	end
	local look = PING_LOOK[kind] or PING_LOOK.spot
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position + Vector3.new(0, 3, 0)
	anchor.Parent = workspace
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(160, 70)
	board.AlwaysOnTop = true
	board.MaxDistance = 1000
	board.Adornee = anchor
	board.Parent = anchor
	local icon = label(board, {
		Text = look.icon, TextSize = 34, TextColor3 = look.color, TextStrokeTransparency = 0.1,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 38),
	})
	label(board, {
		Text = tostring(name), Font = Enum.Font.Code, TextSize = 14, TextColor3 = look.color, TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 16),
	})
	local distance = label(board, {
		Text = "", Font = Enum.Font.Code, TextSize = 13, TextColor3 = look.color, TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 14),
	})
	local ring = Instance.new("Part") -- a glowing ring on the ground, visible in the world too
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = look.color
	ring.Transparency = 0.4
	ring.Size = Vector3.new(0.2, 6, 6)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = anchor
	local started = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local age = os.clock() - started
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			distance.Text = math.floor((hrp.Position - position).Magnitude) .. " studs"
		end
		icon.TextSize = 34 + math.sin(age * 8) * 4
		if age > 8 or not anchor.Parent then
			conn:Disconnect()
			anchor:Destroy()
		end
	end)
end)

---------------------------------------------------------------------------
-- DOWN (task 011): when a teammate can revive you, a killing hit puts you down
-- for a while instead. Your own revive prompt is hidden from you.
---------------------------------------------------------------------------
local downLabel = label(gui, {
	Text = "", TextSize = 26, TextColor3 = RED, TextStrokeTransparency = 0.1, TextXAlignment = Enum.TextXAlignment.Center,
	TextWrapped = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(560, 80),
	Visible = false, ZIndex = 12,
})
RunService.Heartbeat:Connect(function()
	local char = player.Character
	local downed = char and char:GetAttribute("Downed")
	downLabel.Visible = downed == true and gui.Enabled
	if downed then
		local left = math.max(math.ceil((char:GetAttribute("DownedUntil") or 0) - workspace:GetServerTimeNow()), 0)
		downLabel.Text = "YOU ARE DOWN!\nA TEAMMATE CAN REVIVE YOU - " .. left .. " s"
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local own = hrp and hrp:FindFirstChild("RevivePrompt")
		if own and own.Enabled then
			own.Enabled = false -- only on this screen: you can't revive yourself
		end
		lowHealth.Visible = true
	end
end)
end -- ping / DOWN

---------------------------------------------------------------------------
-- Ammo (task 012): magazine / spare under the screen centre, reload and the free refill timer
---------------------------------------------------------------------------
do
local ammoLabel = label(gui, {
	Text = "", TextSize = 22, TextColor3 = AMBER, TextStrokeTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -150), Size = UDim2.fromOffset(460, 26), Visible = false,
})
local refillLabel = label(gui, {
	Text = "", Font = Enum.Font.Code, TextSize = 15, TextColor3 = Color3.fromRGB(255, 170, 40), TextStrokeTransparency = 0.3,
	TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -128),
	Size = UDim2.fromOffset(460, 18), Visible = false,
})
local function clock(seconds)
	seconds = math.max(math.floor(seconds), 0)
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end
RunService.Heartbeat:Connect(function()
	local show = gui.Enabled and currentMode == "Robot"
	ammoLabel.Visible = show
	refillLabel.Visible = show
	if not show then
		return
	end
	local name = player:GetAttribute("WeaponName") or ""
	local ammo = player:GetAttribute("Ammo")
	local refillAt = player:GetAttribute("AmmoRefillAt")
	-- the free refill is only for the Pulse Cannon; the bought guns refill at the Garage
	local refillText = player:GetAttribute("Weapon") ~= "pulse" and "REFILL THIS GUN WITH SCRAP AT THE GARAGE / SHOP"
		or (refillAt and ("FREE HALF REFILL IN " .. clock(refillAt - os.time())) or "")
	if ammo == nil then
		ammoLabel.Text = name .. "  -  UNLIMITED"
		ammoLabel.TextColor3 = Color3.fromRGB(255, 240, 120)
		refillLabel.Text = ""
		return
	end
	local spare = player:GetAttribute("AmmoSpare") or 0
	local max = player:GetAttribute("AmmoMax") or ammo
	if player:GetAttribute("Reloading") then
		ammoLabel.Text = name .. "  RELOADING..."
		ammoLabel.TextColor3 = CYAN
	elseif ammo <= 0 and spare <= 0 then
		ammoLabel.Text = "OUT OF AMMO!  " .. (IS_TOUCH and "SWAP" or "R") .. " = SHOCK BATON, OR BUY AT THE GARAGE"
		ammoLabel.TextColor3 = RED
	else
		ammoLabel.Text = name .. "  " .. ammo .. " / " .. max .. "   SPARE " .. spare
		ammoLabel.TextColor3 = (ammo <= math.max(math.floor(max * 0.25), 1)) and RED or AMBER
	end
	refillLabel.Text = refillText
end)
end -- ammo

transformButton.Activated:Connect(function()
	if canAct() then
		TransformEvent:FireServer()
	end
end)
suitButton.Activated:Connect(function()
	if canAct() then
		SuitEvent:FireServer()
	end
end)
swapButton.Activated:Connect(function()
	if canAct() then
		CycleWeaponEvent:FireServer()
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
		startFiring(input, true, true) -- touch: auto-aim, else the + in the middle
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

-- auto-aim ring: a red circle on the enemy your next shot will hit
local targetRing = Instance.new("Frame")
targetRing.AnchorPoint = Vector2.new(0.5, 0.5)
targetRing.Size = UDim2.fromOffset(52, 52)
targetRing.BackgroundTransparency = 1
targetRing.Visible = false
targetRing.Parent = gui
local ringCorner = Instance.new("UICorner")
ringCorner.CornerRadius = UDim.new(0.5, 0)
ringCorner.Parent = targetRing
local ringStroke = Instance.new("UIStroke")
ringStroke.Color = RED
ringStroke.Thickness = 3
ringStroke.Parent = targetRing

RunService.RenderStepped:Connect(function()
	local target = gui.Enabled and currentMode == "Robot" and autoAimOn() and autoTarget()
	if not target then
		targetRing.Visible = false
		return
	end
	local point, onScreen = workspace.CurrentCamera:WorldToViewportPoint(target.Position)
	local pulse = 52 + math.sin(os.clock() * 8) * 6
	targetRing.Visible = onScreen and point.Z > 0
	targetRing.Position = UDim2.fromOffset(point.X, point.Y)
	targetRing.Size = UDim2.fromOffset(pulse, pulse)
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
applyGraphics()
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
-- the rift to use from this side: the lab rift in Chapter 3, the field rift otherwise
local function riftOn(side)
	local preferLab = (ReplicatedStorage:GetAttribute("Chapter") or 1) == 3
	local rift = rifts:FindFirstChild((preferLab and "Lab" or "") .. side .. "Rift") or rifts:FindFirstChild(side .. "Rift")
	return rift and rift.PrimaryPart
end

-- nearest Chapter 3 file on this side of the rift
local function nearestFile(from, side)
	local folder = workspace:FindFirstChild("LowbandFiles")
	local best, bestDist = nil, math.huge
	for _, file in ipairs(folder and folder:GetChildren() or {}) do
		if file:GetAttribute("Dimension") == side then
			local d = (file.Position - from).Magnitude
			if d < bestDist then
				best, bestDist = file, d
			end
		end
	end
	return best
end

local function nearestRelay(from)
	local folder = workspace:FindFirstChild("Relays")
	local best, bestDist = nil, math.huge
	for _, relay in ipairs(folder and folder:GetChildren() or {}) do
		if not relay:GetAttribute("Done") and relay.PrimaryPart then
			local d = (relay.PrimaryPart.Position - from).Magnitude
			if d < bestDist then
				best, bestDist = relay.PrimaryPart, d
			end
		end
	end
	return best
end

-- Chapter 4: Site 2 lies under the town hotel (the server sets its centre and half size)
local function inSite2(position)
	local center, half = workspace:GetAttribute("Site2Center"), workspace:GetAttribute("Site2Half")
	if not center or not half then
		return false
	end
	local rel = position - center
	return math.abs(rel.X) < half.X + 2 and math.abs(rel.Z) < half.Z + 2 and rel.Y > -3 and rel.Y < half.Y + 3
end

local function currentTarget(from)
	local s = stage()
	local inUndergrid = player:GetAttribute("Dimension") == "Undergrid"
	local side = inUndergrid and "Undergrid" or "Town"
	local carrying = player:GetAttribute("Carrying") or 0
	if s == "Complete" then
		return nil
	end
	-- Chapter 4: keycards on this side of the rift, then the Site 2 door, the pylons and the tape
	if s == "Keycards" then
		local cards = workspace:FindFirstChild("Keycards")
		local best, bestDist = nil, math.huge
		for _, card in ipairs(cards and cards:GetChildren() or {}) do
			if card:IsA("BasePart") and card:GetAttribute("Dimension") == side and (card.Position - from).Magnitude < bestDist then
				best, bestDist = card, (card.Position - from).Magnitude
			end
		end
		if best then
			return best, "KEYCARD"
		end
		return riftOn(side), "RIFT - MORE KEYCARDS ON THE OTHER SIDE"
	end
	-- Chapter 5: everything happens in town
	if (s == "Rifts" or s == "Van" or s == "TapeRace") and inUndergrid then
		return riftOn("Undergrid"), "RIFT - THE STORM IS IN TOWN"
	end
	local storm = workspace:FindFirstChild("StaticStorm")
	if s == "Rifts" then
		local best, bestDist = nil, math.huge
		for _, m in ipairs(storm and storm:GetChildren() or {}) do
			if m.Name == "MiniRift" and m.PrimaryPart and (m.PrimaryPart.Position - from).Magnitude < bestDist then
				best, bestDist = m.PrimaryPart, (m.PrimaryPart.Position - from).Magnitude
			end
		end
		return best, "MINI-RIFT"
	elseif s == "Van" then
		local vanModel = storm and storm:FindFirstChild("WhckVan")
		return vanModel and vanModel.PrimaryPart, "WHCK VAN"
	elseif s == "TapeRace" then
		if player:GetAttribute("CarryingTape") then
			return storm and storm:FindFirstChild("TapeGoal"), "GRAND HOTEL - DELIVER"
		end
		local tapes = storm and storm:FindFirstChild("SignalTapes")
		if tapes and tapes.Transparency < 1 then
			return tapes, "SIGNAL TAPES"
		end
		return storm and storm:FindFirstChild("TapeGoal"), "GRAND HOTEL (TAPES ON THE WAY)"
	end
	if s == "Pylons" or s == "Tape" then
		if inUndergrid then
			return riftOn("Undergrid"), "RIFT - SITE 2 IS IN TOWN"
		end
		if not inSite2(from) then
			local entrance = workspace:FindFirstChild("Site2Entrance")
			return entrance and entrance:FindFirstChild("Site2Door"), "SITE 2 DOOR (MEN'S WASHROOM)"
		end
		if s == "Pylons" then
			return nearestIn("Site2Targets", from), "ECHO PYLON"
		end
		local site = workspace:FindFirstChild("Site2")
		return site and site:FindFirstChild("Site2Tape"), "THE TAPE (DEEP ROOM)"
	end
	if s == "Shards" and carrying > 0 then
		if inUndergrid then
			return riftOn("Undergrid"), "RIFT - GO HOME"
		end
		return findConsole(), "CONSOLE - DELIVER"
	end
	if s == "Files" then
		local file = nearestFile(from, side)
		if file then
			return file, "LOWBAND FILE"
		end
		return riftOn(side), "RIFT - MORE FILES ON THE OTHER SIDE"
	end
	if s == "Race" then
		if inUndergrid then
			return riftOn("Undergrid"), "RIFT - GO HOME"
		end
		return findConsole(), "CONSOLE - BROADCAST"
	end
	if not inUndergrid then
		return riftOn("Town"), "RIFT"
	end
	if s == "Shards" then
		return nearestIn("SignalShards", from), "SHARD"
	elseif s == "Nodes" then
		return nearestIn("HiveNodes", from), "HIVE NODE"
	elseif s == "Boss" then
		return nearestIn("Boss", from, "WeakPoint"), "MIND WARDEN"
	elseif s == "Relays" then
		return nearestRelay(from), "POWER RELAY"
	elseif s == "Carrier" then
		return nearestIn("Carrier", from), "THE CARRIER"
	end
	return nil
end

-- every place you could go now, the recommended one first (task 012). The TARGET button / Y
-- switches between them; the choice goes back to the recommended one when the stage changes.
-- (inside a do-block: Luau allows 200 locals at the top level of a script)
do
local function sortedParts(folderName, from, pick)
	local folder = workspace:FindFirstChild(folderName)
	local list = {}
	for _, child in ipairs(folder and folder:GetChildren() or {}) do
		local p = pick and pick(child) or (child:IsA("BasePart") and child) or (child:IsA("Model") and child.PrimaryPart) or nil
		if p then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		return (a.Position - from).Magnitude < (b.Position - from).Magnitude
	end)
	return list
end

local function targetOptions(from)
	local options, seen = {}, {}
	local function add(part, name)
		if part and not seen[part] then
			seen[part] = true
			table.insert(options, { part = part, name = name })
		end
	end
	local recommended, recName = currentTarget(from)
	add(recommended, recName)

	local s = stage()
	local inUndergrid = player:GetAttribute("Dimension") == "Undergrid"
	local side = inUndergrid and "Undergrid" or "Town"
	if s == "Complete" then
		return options
	end
	if inUndergrid then
		if s == "Shards" then
			for _, p in ipairs(sortedParts("SignalShards", from)) do
				add(p, "SHARD")
			end
		elseif s == "Nodes" then
			for _, p in ipairs(sortedParts("HiveNodes", from)) do
				add(p, "HIVE NODE")
			end
		elseif s == "Relays" then
			for _, p in ipairs(sortedParts("Relays", from, function(relay)
				return not relay:GetAttribute("Done") and relay.PrimaryPart or nil
			end)) do
				add(p, "POWER RELAY")
			end
		end
	end
	if s == "Keycards" then
		for _, p in ipairs(sortedParts("Keycards", from, function(card)
			return card:IsA("BasePart") and card:GetAttribute("Dimension") == side and card or nil
		end)) do
			add(p, "KEYCARD")
		end
	elseif s == "Pylons" and inSite2(from) then
		for _, p in ipairs(sortedParts("Site2Targets", from)) do
			add(p, "ECHO PYLON")
		end
	elseif s == "Rifts" and not inUndergrid then
		for _, p in ipairs(sortedParts("StaticStorm", from, function(m)
			return m.Name == "MiniRift" and m.PrimaryPart or nil
		end)) do
			add(p, "MINI-RIFT")
		end
	end
	if s == "Rifts" or s == "Van" or s == "TapeRace" then
		return options -- the town rift doesn't help in Chapter 5
	end
	if s == "Files" then
		for _, p in ipairs(sortedParts("LowbandFiles", from, function(file)
			return file:IsA("BasePart") and file:GetAttribute("Dimension") == side and file or nil
		end)) do
			add(p, "LOWBAND FILE")
		end
	end
	if s == "Shards" and not inUndergrid and (player:GetAttribute("Carrying") or 0) > 0 then
		add(findConsole(), "CONSOLE - DELIVER")
	end
	if not inSite2(from) then
		add(riftOn(side), inUndergrid and "RIFT - BACK TO TOWN" or "RIFT")
	end
	return options
end

local targetChoice = 1
local targetKey = nil -- stage + world: a change resets the choice
local targetCount = 0

local function cycleTarget()
	targetChoice = targetCount > 0 and (targetChoice % targetCount + 1) or 1
end

-- compass at the top: an arrow that turns toward the target, with plain words
local compass = Instance.new("Frame")
compass.AnchorPoint = Vector2.new(0.5, 0)
compass.Size = UDim2.fromOffset(300, 96)
compass.BackgroundTransparency = 1
compass.Visible = false
compass.Parent = gui
local compassArrow = label(compass, {
	Text = "▲", TextSize = 44, TextColor3 = YELLOW, TextStrokeTransparency = 0.1, TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(150, 24), Size = UDim2.fromOffset(48, 48),
})
local compassText = label(compass, {
	Text = "", TextSize = 18, TextColor3 = YELLOW, TextStrokeTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 20),
})
local compassHint = label(compass, {
	Text = "", Font = Enum.Font.Code, TextSize = 14, TextColor3 = YELLOW, TextStrokeTransparency = 0.3, TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 16),
})

RunService.RenderStepped:Connect(function()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local options = {}
	if hrp and gui.Enabled then
		options = targetOptions(hrp.Position)
	end
	targetCount = #options
	local key = tostring(stage()) .. "|" .. tostring(player:GetAttribute("Dimension")) .. "|" .. tostring((player:GetAttribute("Carrying") or 0) > 0)
	if key ~= targetKey then
		targetKey = key
		targetChoice = 1
	end
	if targetChoice > targetCount then
		targetChoice = 1
	end
	local option = options[targetChoice]
	if not option then
		marker.Visible = false
		compass.Visible = false
		return
	end
	local target, name = option.part, option.name

	local cam = workspace.CurrentCamera
	local point, onScreen = cam:WorldToViewportPoint(target.Position)
	local distance = math.floor((target.Position - hrp.Position).Magnitude)
	-- in the Grand Hotel: say how many floors up or down
	local floors = math.floor((target.Position.Y - hrp.Position.Y) / (workspace:GetAttribute("HotelFloorHeight") or 14) + 0.5)
	local floorHint = floors > 0 and ("  " .. floors .. (floors == 1 and " FLOOR UP" or " FLOORS UP"))
		or floors < 0 and ("  " .. -floors .. (floors == -1 and " FLOOR DOWN" or " FLOORS DOWN")) or ""

	-- the diamond on the target itself, when it's on screen
	marker.Visible = onScreen and point.Z > 0
	diamond.Visible = true
	arrow.Visible = false
	markerText.Text = name .. "  " .. distance .. "m"
	marker.Position = UDim2.fromOffset(point.X, point.Y + 16)

	-- the compass: angle between where the camera looks and where the target is (flat)
	local look = cam.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local to = target.Position - hrp.Position
	local flatTo = Vector3.new(to.X, 0, to.Z)
	local angle = 0
	if flatLook.Magnitude > 0.01 and flatTo.Magnitude > 0.5 then
		flatLook, flatTo = flatLook.Unit, flatTo.Unit
		angle = math.deg(math.atan2(flatLook:Cross(flatTo).Y, flatLook:Dot(flatTo))) -- + = to the left
	end
	compassArrow.Rotation = -angle
	local turn = (math.abs(angle) < 25 and "AHEAD") or (math.abs(angle) > 140 and "BEHIND YOU")
		or (angle > 0 and "TURN LEFT") or "TURN RIGHT"
	compassText.Text = name .. "  " .. distance .. "m  " .. turn .. floorHint
	compassHint.Text = targetCount > 1 and ("TARGET " .. targetChoice .. "/" .. targetCount .. " - " .. (IS_TOUCH and "tap TARGET" or "press Y") .. " to switch") or ""
	-- below the tutorial card while it is on screen
	compass.Position = UDim2.new(0.5, 0, 0, player:GetAttribute("TutorialActive") and 230 or 40)
	compass.Visible = true
end)

-- TARGET (Y / D-pad right / touch) and CAMERA (C / touch): small buttons above the touch pad
local smallPad = Instance.new("Frame")
smallPad.AnchorPoint = Vector2.new(1, 1)
smallPad.Position = touchPad.Position - UDim2.fromOffset(0, 86)
smallPad.Size = UDim2.fromOffset(2 * 96 + 10, 44)
smallPad.BackgroundTransparency = 1
smallPad.Visible = IS_TOUCH
smallPad.Parent = gui
local smallList = Instance.new("UIListLayout")
smallList.FillDirection = Enum.FillDirection.Horizontal
smallList.HorizontalAlignment = Enum.HorizontalAlignment.Right
smallList.Padding = UDim.new(0, 10)
smallList.SortOrder = Enum.SortOrder.LayoutOrder
smallList.Parent = smallPad
local function smallButton(order, text, color)
	local b = button(smallPad, text, { Size = UDim2.fromOffset(96, 44), TextSize = 16, TextColor3 = color, BackgroundTransparency = 0.2, LayoutOrder = order })
	b:FindFirstChildOfClass("UIStroke").Color = color
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = b
	return b
end
local cameraButton = smallButton(1, "CAMERA", AMBER)
local targetButton = smallButton(2, "TARGET", YELLOW)
cameraButton.Name, targetButton.Name = "CameraButton", "TargetButton"

-- swing the camera behind your character (keeps the zoom)
local function recenterCamera()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not hrp or not canAct() then
		return
	end
	local focus = hrp.Position + Vector3.new(0, 1.5, 0)
	local dist = math.clamp((cam.CFrame.Position - cam.Focus.Position).Magnitude, 6, 40)
	local look = hrp.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
	cam.CFrame = CFrame.lookAt(focus - flat * dist + Vector3.new(0, dist * 0.35, 0), focus)
end

cameraButton.Activated:Connect(recenterCamera)
targetButton.Activated:Connect(function()
	if canAct() then
		cycleTarget()
	end
end)
ContextActionService:BindAction("S85_Target", function(_, inputState)
	if inputState == Enum.UserInputState.Begin and canAct() then
		cycleTarget()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Y, Enum.KeyCode.DPadRight)
ContextActionService:BindAction("S85_Camera", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		recenterCamera()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.C)
end -- compass / TARGET / CAMERA

---------------------------------------------------------------------------
-- Grand Hotel: FLOOR label, a shoulder flashlight indoors, flickering
-- washroom lights, and a mirror scare on floor 3 (Undergrid, Chapter 1)
---------------------------------------------------------------------------
local flashlight = Instance.new("SpotLight")
flashlight.Name = "PilotFlashlight"
flashlight.Range = 45
flashlight.Angle = 55
flashlight.Brightness = 2.2
flashlight.Color = Color3.fromRGB(255, 245, 225)
flashlight.Shadows = true
flashlight.Enabled = false

-- which hotel floor you are on (nil = outside)
local function hotelFloor(position)
	local center = workspace:GetAttribute("HotelCenter")
	local floorHeight = workspace:GetAttribute("HotelFloorHeight") or 14
	if not center then
		return nil
	end
	if player:GetAttribute("Dimension") == "Undergrid" then
		center = center + (workspace:GetAttribute("UndergridOffset") or Vector3.zero)
	end
	local rel = position - center
	local half = workspace:GetAttribute("HotelHalfSize") or Vector2.new(48, 36)
	if math.abs(rel.X) > half.X or math.abs(rel.Z) > half.Y or rel.Y < -2 or rel.Y > floorHeight * 6 + 2 then
		return nil
	end
	return math.clamp(math.floor(rel.Y / floorHeight) + 1, 1, 6)
end

local scared = false
local function mirrorScare()
	scared = true
	local spot = workspace:GetAttribute("HotelScare")
	if not spot then
		return
	end
	-- a shadow figure "in" the mirror for a moment, then gone
	local ghost = Instance.new("Model")
	local function add(size, offset, color, shape)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Size = size
		p.Shape = shape or Enum.PartType.Block
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 0.15
		p.CFrame = CFrame.new(spot + offset)
		p.Parent = ghost
	end
	add(Vector3.new(0.5, 5, 2.4), Vector3.new(-1, -2.5, 0), Color3.fromRGB(28, 22, 26))
	add(Vector3.new(2.6, 2.6, 2.6), Vector3.new(-1, 0.8, 0), Color3.fromRGB(28, 22, 26), Enum.PartType.Ball)
	add(Vector3.new(0.3, 1.2, 1.2), Vector3.new(-0.2, 0.8, 0), Color3.fromRGB(255, 40, 50), Enum.PartType.Ball)
	ghost.Parent = workspace
	screenFlash(RED)
	shake(0.4, 0.6)
	task.delay(0.7, function()
		ghost:Destroy()
	end)
end

local lastFloor = nil
local indoorCamera = false
local INDOOR_ZOOM = 16
local outdoorZoom = player.CameraMaxZoomDistance
RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local head = char and char:FindFirstChild("Head")
	if not hrp then
		return
	end
	local floor = hotelFloor(hrp.Position)
	if not floor and inSite2(hrp.Position) then
		floor = 0 -- Site 2, under the hotel (Chapter 4): indoors, like a hotel floor
	end

	-- the panel's WORLD line shows the hotel floor
	if floor ~= lastFloor then
		lastFloor = floor
		if floor == 0 then
			worldLabel.Text = "SITE 2 - LOWBAND, 1958"
		elseif floor then
			worldLabel.Text = (floor == 6 and "GRAND HOTEL - ROOF") or ("GRAND HOTEL - FLOOR " .. floor)
		else
			refreshWorld()
		end
	end

	-- indoors (task 012): walls between the camera and you turn see-through instead of pushing
	-- the camera into your face, and the camera stays closer so it fits in the rooms
	local inside = floor ~= nil and floor < 6
	if inside ~= indoorCamera then
		indoorCamera = inside
		pcall(function()
			player.DevCameraOcclusionMode = inside and Enum.DevCameraOcclusionMode.Invisicam or Enum.DevCameraOcclusionMode.Zoom
			player.CameraMaxZoomDistance = inside and INDOOR_ZOOM or outdoorZoom
		end)
	end

	-- flashlight on your shoulder while inside
	if head and flashlight.Parent ~= head then
		flashlight.Parent = head
	end
	flashlight.Enabled = floor ~= nil and floor < 6

	-- floor 3 washroom mirror, Undergrid side, Chapter 1 only, once
	local spot = workspace:GetAttribute("HotelScare")
	if not scared and spot and floor == 3 and player:GetAttribute("Dimension") == "Undergrid"
		and (ReplicatedStorage:GetAttribute("Chapter") or 1) == 1 and (hrp.Position - spot).Magnitude < 9 then
		mirrorScare()
	end
end)

-- washroom lights flicker now and then (only while the hotel has power)
task.spawn(function()
	local flickers, lastScan = {}, -math.huge
	while true do
		task.wait(0.15)
		if os.clock() - lastScan > 10 then -- find the washroom lights again now and then (cheap enough)
			lastScan = os.clock()
			flickers = {}
			for _, d in ipairs(workspace:GetDescendants()) do
				if (d.Name == "HotelFlicker" or d.Name == "HotelElevatorPanel") and d:IsA("BasePart") then
					table.insert(flickers, d)
				end
			end
		end
		if graphics >= 2 then
			for _, p in ipairs(flickers) do
				if p.Name == "HotelElevatorPanel" then
					-- stuck elevators (Chapter 2 / 3): the red panel flickers; working ones stay lit
					p.Transparency = (p:GetAttribute("Flicker") and math.random() < 0.3) and 0.7 or 0
				elseif p.Parent and p.Material == Enum.Material.Neon then
					local l = p:FindFirstChildOfClass("PointLight")
					local off = math.random() < 0.08
					p.Transparency = off and 0.8 or 0
					if l then
						l.Brightness = off and 0.1 or 1
					end
				end
			end
		end
	end
end)
