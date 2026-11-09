--[[
	SIGNAL '85  —  "First Night" tutorial (client, task 011)
	Put this LocalScript in StarterPlayer > StarterPlayerScripts.

	StartMenu sets the player attribute TutorialStart = true after START MISSION
	(first time only, or REPLAY TUTORIAL in Settings). Six short steps in Hollow
	Creek, each waiting until the player has done it:
	  move -> suit up -> shoot 3 practice targets -> car through a ring ->
	  Shock Baton up close -> follow the yellow marker to the rift.
	The practice targets and lights exist only on this player's screen.
	TutorialActive is true while it runs. The server pays the reward once
	(Meta "tutorial", "done"); SKIP sends "skip".
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Signal85Remotes")
local Meta = remotes:WaitForChild("Meta")

local IS_TOUCH = UserInputService.TouchEnabled
local IS_PHONE = IS_TOUCH and not UserInputService.KeyboardEnabled

local AMBER = Color3.fromRGB(255, 214, 140)
local CYAN = Color3.fromRGB(80, 220, 255)
local GREEN = Color3.fromRGB(60, 255, 140)
local YELLOW = Color3.fromRGB(255, 235, 140)
local PURPLE = Color3.fromRGB(190, 120, 255)
local DIM = Color3.fromRGB(150, 140, 150)

local STEPS = 6

---------------------------------------------------------------------------
-- UI: a card at the top of the screen, a SKIP button, and an arrow that
-- points at the touch button to press (phones and tablets)
---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "Signal85Tutorial"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 40 -- above the HUD, below the menu
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function make(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local card = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.new(0.9, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(10, 8, 14), BackgroundTransparency = 0.1, BorderSizePixel = 0,
}, gui)
make("UISizeConstraint", { MaxSize = Vector2.new(560, math.huge) }, card)
make("UIStroke", { Color = CYAN, Thickness = 2 }, card)
make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, card)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, card)
if IS_PHONE then
	make("UIScale", { Scale = 0.8 }, card)
end

local function text(props)
	local l = make("TextLabel", {
		BackgroundTransparency = 1, Font = Enum.Font.Arcade, TextColor3 = AMBER, TextSize = 18, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	}, card)
	for k, v in pairs(props) do
		l[k] = v
	end
	return l
end

local stepLabel = text({ Text = "", TextSize = 14, TextColor3 = DIM, LayoutOrder = 1 })
local titleLabel = text({ Text = "", TextSize = 26, TextColor3 = CYAN, LayoutOrder = 2 })
local bodyLabel = text({ Text = "", Font = Enum.Font.Code, TextSize = 17, LayoutOrder = 3 })
local progressLabel = text({ Text = "", TextSize = 16, TextColor3 = YELLOW, LayoutOrder = 4 })

local skipButton = make("TextButton", {
	Text = "SKIP TUTORIAL", Font = Enum.Font.Arcade, TextSize = 16, TextColor3 = DIM, BackgroundColor3 = Color3.fromRGB(30, 24, 36),
	BorderSizePixel = 0, Size = UDim2.fromOffset(170, 34), LayoutOrder = 5,
}, card)
make("UIStroke", { Color = DIM, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, skipButton)

local arrow = make("TextLabel", {
	BackgroundTransparency = 1, Font = Enum.Font.Arcade, Text = "▼", TextSize = 40, TextColor3 = YELLOW, TextStrokeTransparency = 0.1,
	AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(50, 44), Visible = false,
}, gui)

local pointAt = nil -- name of the touch button to point at (Signal85HUD > TouchControls)

RunService.RenderStepped:Connect(function()
	local button = nil
	if pointAt and IS_TOUCH and gui.Enabled then
		local hud = player.PlayerGui:FindFirstChild("Signal85HUD")
		local pad = hud and hud:FindFirstChild("TouchControls", true)
		button = pad and pad:FindFirstChild(pointAt)
	end
	if button and button.Visible and button.AbsoluteSize.X > 0 then
		local bounce = math.sin(os.clock() * 6) * 6
		arrow.Position = UDim2.fromOffset(button.AbsolutePosition.X + button.AbsoluteSize.X / 2, button.AbsolutePosition.Y - 4 + bounce)
		arrow.Visible = true
	else
		arrow.Visible = false
	end
	-- the menu (pause, shop...) covers the card
	gui.Enabled = player:GetAttribute("TutorialActive") == true and not player:GetAttribute("MenuActive")
end)

local function show(step, title, body, button)
	stepLabel.Text = "FIRST NIGHT  -  STEP " .. step .. " / " .. STEPS
	titleLabel.Text = title
	bodyLabel.Text = body
	progressLabel.Text = ""
	pointAt = button
end

---------------------------------------------------------------------------
-- World helpers (everything here exists only on this player's screen)
---------------------------------------------------------------------------
local props = {} -- parts to remove at the end

local function hrpOf()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart"), char
end

local function ground(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
	return hit and hit.Position or Vector3.new(pos.X, 0, pos.Z)
end

-- a spot in front of the player: dist studs ahead, side studs to the right
local function ahead(dist, side)
	local hrp = hrpOf()
	if not hrp then
		return Vector3.zero
	end
	local look = hrp.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
	local right = Vector3.new(-flat.Z, 0, flat.X)
	return ground(hrp.Position + flat * dist + right * (side or 0))
end

local function part(p)
	local x = Instance.new("Part")
	x.Anchored = true
	x.CanCollide = false
	x.CanQuery = false
	x.CanTouch = false
	x.CastShadow = false
	x.Material = Enum.Material.Neon
	for k, v in pairs(p) do
		x[k] = v
	end
	x.Parent = workspace
	table.insert(props, x)
	return x
end

-- a tall glowing column with a ring: "go here"
local function beacon(at, color, radius)
	radius = radius or 4
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, radius * 2, radius * 2), Color = color, Transparency = 0.3,
		CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(40, 1.2, 1.2), Color = color, Transparency = 0.6,
		CFrame = CFrame.new(at + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
end

-- a hovering practice target (a purple Hollower-shaped hologram) inside the Creatures folder,
-- so the HUD's auto-aim finds it too
local function practiceTarget(at)
	local m = Instance.new("Model")
	m.Name = "PracticeTarget"
	local core = part({ Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 3.4, 3.4), Color = PURPLE, Transparency = 0.15,
		Position = at + Vector3.new(0, 4.5, 0) })
	part({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 5, 5), Color = PURPLE, Transparency = 0.5,
		CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)) }).Parent = m
	core.Parent = m
	m.PrimaryPart = core
	m:SetAttribute("Health", 1)
	m.Parent = workspace:FindFirstChild("Creatures") or workspace
	table.insert(props, m)
	return m
end

local function pop(m)
	local core = m.PrimaryPart
	m:SetAttribute("Health", 0)
	if core then
		TweenService:Create(core, TweenInfo.new(0.25), { Size = core.Size * 2, Transparency = 1 }):Play()
	end
	task.delay(0.3, function()
		m:Destroy()
	end)
end

-- did the last shot hit this target? Close to the aim point, roughly in the aim direction,
-- or (Shock Baton) right in front of you
local function shotHits(m, point)
	local hrp = hrpOf()
	local core = m.PrimaryPart
	if not hrp or not core or (m:GetAttribute("Health") or 0) <= 0 then
		return false
	end
	local toTarget = core.Position - hrp.Position
	if (point - core.Position).Magnitude < 6 then
		return true
	end
	if player:GetAttribute("Weapon") == "baton" then
		return toTarget.Magnitude < 13
	end
	local toPoint = point - hrp.Position
	return toTarget.Magnitude < 140 and toPoint.Magnitude > 0.1 and toTarget.Unit:Dot(toPoint.Unit) > math.cos(math.rad(10))
end

local function mode()
	local _, char = hrpOf()
	return char and char:GetAttribute("Mode") or "Pilot"
end

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

---------------------------------------------------------------------------
-- The steps
---------------------------------------------------------------------------
local running = false
local skipped = false

local function waitFor(check)
	while not skipped do
		if check() then
			return true
		end
		task.wait(0.1)
	end
	return false
end

local function cleanup()
	for _, p in ipairs(props) do
		if p.Parent then
			p:Destroy()
		end
	end
	table.clear(props)
	pointAt = nil
end

local function run()
	running = true
	skipped = false
	player:SetAttribute("TutorialActive", true)

	-- 1. move
	local spot = ahead(26, 0)
	beacon(spot, CYAN)
	show(1, "WALK", IS_TOUCH and "Drag the thumbstick on the left of the screen to walk to the blue light."
		or "Use W A S D (or the arrow keys) to walk to the blue light.", nil)
	waitFor(function()
		local hrp = hrpOf()
		return hrp ~= nil and flatDistance(hrp.Position, spot) < 6
	end)
	cleanup()

	-- 2. suit up
	if not skipped then
		show(2, "SUIT UP", IS_TOUCH and "Tap SUIT UP. Your Shiftframe robot armor folds around you."
			or "Press G (or F). Your Shiftframe robot armor folds around you.", "TransformButton")
		waitFor(function()
			return mode() == "Robot"
		end)
	end

	-- 3. shoot three practice targets
	if not skipped then
		local targets = { practiceTarget(ahead(30, -10)), practiceTarget(ahead(36, 0)), practiceTarget(ahead(30, 10)) }
		local left = #targets
		show(3, "SHOOT", IS_TOUCH and "Hold BLAST. Auto-aim picks the closest target (the red ring) - no aiming needed."
			or "Hold Q to fire with auto-aim (the red ring), or point with the mouse and hold the left button.", "BlastButton")
		progressLabel.Text = "TARGETS: 0 / 3"
		local conn = player:GetAttributeChangedSignal("ShotCount"):Connect(function()
			local point = player:GetAttribute("LastShot")
			if typeof(point) ~= "Vector3" then
				return
			end
			for _, m in ipairs(targets) do
				if m.Parent and shotHits(m, point) then
					pop(m)
					left = left - 1
					progressLabel.Text = "TARGETS: " .. (3 - left) .. " / 3"
					break
				end
			end
		end)
		waitFor(function()
			if mode() ~= "Robot" then
				progressLabel.Text = IS_TOUCH and "You can only shoot as a robot: tap TO ROBOT." or "You can only shoot as a robot: press F."
			end
			return left <= 0
		end)
		conn:Disconnect()
		cleanup()
	end

	-- 4. car through a ring
	if not skipped then
		local ring = ahead(70, 0)
		beacon(ring, GREEN, 9)
		show(4, "BECOME A CAR", IS_TOUCH and "Tap TO CAR, then drive through the green ring. Cars are fast but can't shoot."
			or "Press F to become a car, then drive through the green ring. Cars are fast but can't shoot.", "TransformButton")
		waitFor(function()
			local hrp = hrpOf()
			return hrp ~= nil and mode() == "Vehicle" and flatDistance(hrp.Position, ring) < 10
		end)
		cleanup()
	end

	-- 5. Shock Baton up close
	if not skipped then
		local target = practiceTarget(ahead(16, 0))
		local hit = false
		show(5, "SHOCK BATON", IS_TOUCH and "Tap TO ROBOT, then SWAP until you hold the SHOCK BATON. Walk up to the target and tap BLAST."
			or "Press F for robot, then R until you hold the SHOCK BATON. Walk up to the target and press Q.", "SwapButton")
		local conn = player:GetAttributeChangedSignal("ShotCount"):Connect(function()
			local point = player:GetAttribute("LastShot")
			if typeof(point) == "Vector3" and player:GetAttribute("Weapon") == "baton" and shotHits(target, point) then
				hit = true
				pop(target)
			end
		end)
		waitFor(function()
			if mode() == "Robot" then
				pointAt = player:GetAttribute("Weapon") == "baton" and "BlastButton" or "SwapButton"
			else
				pointAt = "TransformButton"
			end
			progressLabel.Text = "HOLDING: " .. tostring(player:GetAttribute("WeaponName") or "?")
			return hit
		end)
		conn:Disconnect()
		cleanup()
	end

	-- 6. follow the yellow marker to the rift
	if not skipped then
		show(6, "FOLLOW THE MARKER", "The YELLOW MARKER always points to your next goal and shows how far it is. Follow it to the red RIFT."
			.. (IS_TOUCH and "" or " (Tip: R swaps back to the Pulse Cannon for long range.)"), nil)
		local rifts = workspace:FindFirstChild("Rifts")
		waitFor(function()
			local hrp = hrpOf()
			if not hrp or not rifts then
				return rifts == nil
			end
			for _, rift in ipairs(rifts:GetChildren()) do
				if rift.PrimaryPart and (rift.PrimaryPart.Position - hrp.Position).Magnitude < 35 then
					return true
				end
			end
			return false
		end)
	end

	cleanup()
	pcall(function()
		Meta:InvokeServer("tutorial", skipped and "skip" or "done")
	end)
	if not skipped then
		show(STEPS, "TUTORIAL COMPLETE!", "Now cross the rift (" .. (IS_TOUCH and "tap ENTER RIFT" or "press E")
			.. ") and collect the Signal Shards. Good luck, pilot.", nil)
		progressLabel.Text = "+100 SCRAP"
		skipButton.Visible = false
		task.wait(5)
		skipButton.Visible = true
	end
	running = false
	player:SetAttribute("TutorialActive", false)
	player:SetAttribute("TutorialStart", false)
end

skipButton.Activated:Connect(function()
	skipped = true
end)

player:GetAttributeChangedSignal("TutorialStart"):Connect(function()
	if player:GetAttribute("TutorialStart") == true and not running then
		task.spawn(run)
	end
end)
