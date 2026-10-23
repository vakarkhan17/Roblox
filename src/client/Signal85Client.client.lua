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
local rifts = workspace:WaitForChild("Rifts")

local RIFT_RANGE = 12

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
}

local function applyPreset(name, instant)
	local preset = PRESETS[name]
	local info = TweenInfo.new(instant and 0 or 1.5, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, preset.lighting):Play()
	TweenService:Create(atmosphere, info, preset.atmosphere):Play()
	TweenService:Create(grade, info, preset.grade):Play()
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
panel.Size = UDim2.fromOffset(280, 150)
panel.BackgroundColor3 = Color3.fromRGB(10, 8, 14)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel = 0
panel.Parent = gui
local stroke = Instance.new("UIStroke")
stroke.Color = AMBER
stroke.Thickness = 2
stroke.Parent = panel

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

label(gui, {
	Text = "[F] TRANSFORM   [Q] BLAST (ROBOT)   [E] SHIFT AT RIFT",
	TextSize = 16, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16), Size = UDim2.fromOffset(600, 20),
})

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

local function refreshSeal()
	local progress = ReplicatedStorage:GetAttribute("Progress") or 0
	local goal = ReplicatedStorage:GetAttribute("Goal") or 1
	sealLabel.Text = "RIFT SEAL  " .. progress .. "/" .. goal
	TweenService:Create(barFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(progress / goal, 1) }):Play()
end

player:GetAttributeChangedSignal("Dimension"):Connect(function()
	local dim = refreshWorld()
	applyPreset(dim == "Undergrid" and "Undergrid" or "Town", false)
	screenFlash(dim == "Undergrid" and RED or AMBER)
end)
player:GetAttributeChangedSignal("Carrying"):Connect(refreshCarry)
ReplicatedStorage:GetAttributeChangedSignal("Progress"):Connect(refreshSeal)

local function hookCharacter(char)
	local function refreshMode()
		local mode = char:GetAttribute("Mode") or "Robot"
		modeLabel.Text = "MODE: " .. string.upper(mode)
		modeLabel.TextColor3 = mode == "Vehicle" and CYAN or AMBER
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
local function aimPoint()
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		local cam = workspace.CurrentCamera
		return cam.CFrame.Position + cam.CFrame.LookVector * 140
	end
	return mouse.Hit.Position
end

local function onAction(actionName, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if actionName == "S85_Transform" then
		TransformEvent:FireServer()
	elseif actionName == "S85_Blast" then
		BlastEvent:FireServer(aimPoint())
	elseif actionName == "S85_Shift" then
		ShiftEvent:FireServer()
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("S85_Transform", onAction, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
ContextActionService:BindAction("S85_Blast", onAction, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonR2)
ContextActionService:BindAction("S85_Shift", onAction, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
ContextActionService:SetTitle("S85_Transform", "SHIFT")
ContextActionService:SetTitle("S85_Blast", "BLAST")
ContextActionService:SetTitle("S85_Shift", "RIFT")

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
		prompt.Text = (player:GetAttribute("Dimension") == "Undergrid") and "[E] ESCAPE TO HOLLOW CREEK" or "[E] ENTER THE UNDERGRID"
	else
		prompt.Text = ""
	end
end)

-- initial state
applyPreset("Town", true)
refreshWorld()
refreshCarry()
refreshSeal()
