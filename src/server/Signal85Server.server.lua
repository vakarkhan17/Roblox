--[[
	SIGNAL '85  —  Server script
	Put this Script in ServerScriptService. It builds the whole map by code,
	so you can drop it into an empty Baseplate place and press Play.

	The game:
	  * 1985, the small town of Hollow Creek. A rift has opened to THE UNDERGRID,
	    a dark mirror of the town where shadow creatures (Hollowers) roam.
	  * Every player is a SHIFTFRAME: a robot that can transform into a car.
	      Robot mode   -> slower, can fire an arm blaster.
	      Vehicle mode -> very fast, cannot shoot.
	  * Go through the rift, collect Signal Shards in the Undergrid, bring them
	    back to the radio tower console in town. Deliver enough to seal the rift.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local CONFIG = {
	UNDERGRID_OFFSET = Vector3.new(0, 0, 1500), -- where the mirror world is built
	RIFT_RANGE = 12,
	SHIFT_COOLDOWN = 2,

	ROBOT_SPEED = 18,
	ROBOT_JUMP = 50,
	VEHICLE_SPEED = 75,
	VEHICLE_JUMP = 20,
	TRANSFORM_COOLDOWN = 1.2,

	BLAST_DAMAGE = 34,
	BLAST_RANGE = 140,
	BLAST_COOLDOWN = 0.45,

	SHARDS_TO_WIN = 6,

	MAX_CREATURES = 8,
	CREATURE_SPAWN_INTERVAL = 5,
	CREATURE_HEALTH = 100,
	CREATURE_SPEED = 13,
	CREATURE_AGGRO = 160,
	CREATURE_DAMAGE = 15,
	CREATURE_HIT_COOLDOWN = 1,
}

local rng = Random.new()

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Signal85Remotes"
remotes.Parent = ReplicatedStorage

local function makeRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

local TransformEvent = makeRemote("Transform") -- client -> server (request), server -> all (fx)
local BlastEvent = makeRemote("Blast")         -- client -> server (aim point)
local ShiftEvent = makeRemote("Shift")         -- client -> server (go through rift)
local NotifyEvent = makeRemote("Notify")       -- server -> client (banner text)

ReplicatedStorage:SetAttribute("Progress", 0)
ReplicatedStorage:SetAttribute("Goal", CONFIG.SHARDS_TO_WIN)

---------------------------------------------------------------------------
-- Part helpers
---------------------------------------------------------------------------
local function newPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	for k, v in pairs(props) do
		if k ~= "Parent" and k ~= "Shape" then
			p[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

-- Unanchored, weightless, non-colliding part for armor / vehicle shells
local function shellPart(props)
	props.Anchored = false
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.Massless = true
	return newPart(props)
end

local function weld(part, target)
	local w = Instance.new("WeldConstraint")
	w.Part0 = target
	w.Part1 = part
	w.Parent = part
end

local function notifyAll(text, color)
	NotifyEvent:FireAllClients(text, color)
end

---------------------------------------------------------------------------
-- Build Hollow Creek (the normal town)
---------------------------------------------------------------------------
local BRICKS = {
	Color3.fromRGB(150, 82, 64),
	Color3.fromRGB(120, 110, 96),
	Color3.fromRGB(176, 150, 112),
	Color3.fromRGB(90, 104, 120),
}

local function buildTown()
	local town = Instance.new("Model")
	town.Name = "HollowCreek"

	newPart({ Name = "Ground", Size = Vector3.new(500, 2, 500), Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(74, 96, 58), Material = Enum.Material.Grass, Parent = town })
	newPart({ Name = "Road", Size = Vector3.new(30, 0.2, 500), Position = Vector3.new(0, 0.1, 0),
		Color = Color3.fromRGB(40, 40, 46), Material = Enum.Material.Asphalt, Parent = town })

	-- road dashes
	for z = -240, 240, 20 do
		newPart({ Name = "Road", Size = Vector3.new(0.6, 0.22, 8), Position = Vector3.new(0, 0.12, z),
			Color = Color3.fromRGB(230, 200, 80), Material = Enum.Material.SmoothPlastic, Parent = town })
	end

	-- buildings with glowing windows facing the road
	local layout = Random.new(1985)
	for i = 1, 10 do
		local side = (i % 2 == 0) and 1 or -1
		local z = -200 + math.floor((i - 1) / 2) * 90
		local h = layout:NextInteger(14, 34)
		local w = layout:NextInteger(24, 36)
		local pos = Vector3.new(side * (40 + w / 2), h / 2, z)
		newPart({ Name = "Building", Size = Vector3.new(w, h, 30), Position = pos,
			Color = BRICKS[layout:NextInteger(1, #BRICKS)], Material = Enum.Material.Brick, Parent = town })
		newPart({ Name = "Roof", Size = Vector3.new(w + 1, 1, 31), Position = pos + Vector3.new(0, h / 2 + 0.5, 0),
			Color = Color3.fromRGB(50, 50, 55), Material = Enum.Material.Slate, Parent = town })
		for row = 1, math.floor(h / 8) do
			newPart({ Name = "Window", Size = Vector3.new(0.4, 2.5, 22),
				Position = Vector3.new(pos.X - side * (w / 2 + 0.1), row * 8 - 2, z),
				Color = Color3.fromRGB(255, 214, 140), Material = Enum.Material.Neon, Parent = town })
		end
	end

	-- street lights
	for z = -220, 220, 60 do
		for _, x in ipairs({ -18, 18 }) do
			newPart({ Name = "LampPost", Size = Vector3.new(0.6, 14, 0.6), Position = Vector3.new(x, 7, z),
				Color = Color3.fromRGB(30, 30, 34), Material = Enum.Material.Metal, Parent = town })
			local lamp = newPart({ Name = "Lamp", Size = Vector3.new(1.6, 0.8, 1.6), Position = Vector3.new(x, 14.4, z),
				Color = Color3.fromRGB(255, 220, 160), Material = Enum.Material.Neon, Parent = town })
			local light = Instance.new("PointLight")
			light.Range = 28
			light.Brightness = 1.4
			light.Color = Color3.fromRGB(255, 200, 140)
			light.Parent = lamp
		end
	end

	-- radio tower at the north end of the road
	local towerBase = Vector3.new(0, 0, -238)
	for _, offset in ipairs({ Vector3.new(-4, 0, -4), Vector3.new(4, 0, -4), Vector3.new(-4, 0, 4), Vector3.new(4, 0, 4) }) do
		newPart({ Name = "TowerLeg", Size = Vector3.new(0.8, 60, 0.8), Position = towerBase + offset + Vector3.new(0, 30, 0),
			Color = Color3.fromRGB(180, 40, 40), Material = Enum.Material.Metal, Parent = town })
	end
	for y = 8, 56, 12 do
		newPart({ Name = "TowerRing", Size = Vector3.new(9, 0.6, 9), Position = towerBase + Vector3.new(0, y, 0),
			Color = Color3.fromRGB(220, 220, 220), Material = Enum.Material.Metal, Transparency = 0.2, Parent = town })
	end
	local beacon = newPart({ Name = "Beacon", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3),
		Position = towerBase + Vector3.new(0, 62, 0), Color = Color3.fromRGB(255, 40, 40),
		Material = Enum.Material.Neon, Parent = town })
	local beaconLight = Instance.new("PointLight")
	beaconLight.Range = 40
	beaconLight.Color = Color3.fromRGB(255, 60, 60)
	beaconLight.Parent = beacon

	local console = newPart({ Name = "Console", Size = Vector3.new(6, 4, 3), Position = Vector3.new(0, 2, -226),
		Color = Color3.fromRGB(60, 255, 140), Material = Enum.Material.Neon, Parent = town })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 60)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	gui.Parent = console
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Arcade
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(60, 255, 140)
	label.TextStrokeTransparency = 0
	label.Text = "SIGNAL CONSOLE\nDELIVER SHARDS HERE"
	label.Parent = gui

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "TownSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.5, 200)
	spawn.Color = Color3.fromRGB(40, 40, 46)
	spawn.Material = Enum.Material.Asphalt
	spawn.Parent = town

	town.Parent = workspace
	return town, console
end

---------------------------------------------------------------------------
-- Build the Undergrid (dark mirror of the town)
---------------------------------------------------------------------------
local function buildUndergrid(town)
	local ug = town:Clone()
	ug.Name = "Undergrid"

	local remove = {}
	for _, d in ipairs(ug:GetDescendants()) do
		if d:IsA("SpawnLocation") or d.Name == "Console" then
			table.insert(remove, d)
		end
	end
	for _, d in ipairs(remove) do
		d:Destroy()
	end

	ug:PivotTo(town:GetPivot() + CONFIG.UNDERGRID_OFFSET)

	for _, d in ipairs(ug:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Material == Enum.Material.Neon then
				d.Color = Color3.fromRGB(200, 30, 45)
			else
				d.Color = d.Color:Lerp(Color3.fromRGB(18, 22, 30), 0.75)
				if d.Name ~= "Ground" then
					d.Material = Enum.Material.Slate
				end
			end
		elseif d:IsA("PointLight") then
			d.Color = Color3.fromRGB(255, 40, 60)
			d.Brightness = 0.7
		elseif d:IsA("BillboardGui") then
			d:Destroy()
		end
	end

	-- creeping tendrils on the ground and walls
	local vine = Random.new(85)
	for _ = 1, 70 do
		local p = CONFIG.UNDERGRID_OFFSET + Vector3.new(vine:NextNumber(-230, 230), vine:NextNumber(0.3, 20), vine:NextNumber(-230, 230))
		newPart({ Name = "Tendril", Size = Vector3.new(0.6, 0.6, vine:NextNumber(8, 22)),
			CFrame = CFrame.new(p) * CFrame.Angles(vine:NextNumber(-0.6, 0.6), vine:NextNumber(0, math.pi * 2), vine:NextNumber(-0.6, 0.6)),
			Color = Color3.fromRGB(40, 18, 22), Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, Parent = ug })
	end

	-- floating spores filling the whole world
	local sporeBox = newPart({ Name = "Spores", Size = Vector3.new(500, 60, 500), Position = CONFIG.UNDERGRID_OFFSET + Vector3.new(0, 30, 0),
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = ug })
	local spores = Instance.new("ParticleEmitter")
	spores.Shape = Enum.ParticleEmitterShape.Box
	spores.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	spores.Rate = 120
	spores.Lifetime = NumberRange.new(8, 14)
	spores.Speed = NumberRange.new(0.3, 1.2)
	spores.SpreadAngle = Vector2.new(180, 180)
	spores.Size = NumberSequence.new(0.25)
	spores.LightEmission = 0.6
	spores.Color = ColorSequence.new(Color3.fromRGB(220, 220, 255))
	spores.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.3),
		NumberSequenceKeypoint.new(0.8, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	spores.Parent = sporeBox

	ug.Parent = workspace
	return ug
end

---------------------------------------------------------------------------
-- Rifts
---------------------------------------------------------------------------
local riftFolder = Instance.new("Folder")
riftFolder.Name = "Rifts"
riftFolder.Parent = workspace

local function makeRift(position, name)
	local m = Instance.new("Model")
	m.Name = name
	local ring = newPart({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 18, 18),
		CFrame = CFrame.new(position), Color = Color3.fromRGB(255, 50, 60), Material = Enum.Material.Neon,
		CanCollide = false, CanQuery = false, Parent = m })
	newPart({ Name = "Void", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 15, 15),
		CFrame = CFrame.new(position), Color = Color3.fromRGB(5, 5, 10), Material = Enum.Material.Glass,
		Transparency = 0.15, CanCollide = false, CanQuery = false, Parent = m })
	m.PrimaryPart = ring

	local light = Instance.new("PointLight")
	light.Range = 35
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 50, 70)
	light.Parent = ring

	local fx = Instance.new("ParticleEmitter")
	fx.Rate = 40
	fx.Lifetime = NumberRange.new(1, 2)
	fx.Speed = NumberRange.new(2, 6)
	fx.SpreadAngle = Vector2.new(180, 180)
	fx.Size = NumberSequence.new(0.4, 0)
	fx.LightEmission = 1
	fx.Color = ColorSequence.new(Color3.fromRGB(255, 80, 90))
	fx.Parent = ring

	m.Parent = riftFolder
	return m
end

local town, console = buildTown()
local undergrid = buildUndergrid(town)

local TOWN_RIFT_POS = Vector3.new(110, 9, 0)
local UG_RIFT_POS = TOWN_RIFT_POS + CONFIG.UNDERGRID_OFFSET
makeRift(TOWN_RIFT_POS, "TownRift")
makeRift(UG_RIFT_POS, "UndergridRift")

-- slow pulse on rifts
task.spawn(function()
	local t = 0
	while true do
		t = t + RunService.Heartbeat:Wait()
		for _, rift in ipairs(riftFolder:GetChildren()) do
			local ring = rift.PrimaryPart
			if ring then
				ring.Transparency = 0.15 + 0.15 * math.sin(t * 3)
			end
		end
	end
end)

-- find a random open spot (on ground or road, not inside a building)
local function randomOpenPoint(model, center)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	for _ = 1, 40 do
		local probe = center + Vector3.new(rng:NextNumber(-220, 220), 150, rng:NextNumber(-220, 220))
		local hit = workspace:Raycast(probe, Vector3.new(0, -300, 0), params)
		if hit and (hit.Instance.Name == "Ground" or hit.Instance.Name == "Road") then
			return Vector3.new(probe.X, center.Y, probe.Z)
		end
	end
	return center
end

---------------------------------------------------------------------------
-- Shiftframe armor (robot mode) and vehicle shell
---------------------------------------------------------------------------
local STEEL = Color3.fromRGB(70, 92, 125)
local ACCENT = Color3.fromRGB(255, 170, 40)
local GLOW = Color3.fromRGB(80, 220, 255)

local state = {} -- [player] = { mode, lastTransform, lastBlast, lastShift }

local function applyRobotArmor(char)
	local folder = Instance.new("Folder")
	folder.Name = "ShiftframeArmor"
	folder.Parent = char

	for _, p in ipairs(char:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			if p.Name == "Head" then
				local helm = shellPart({ Name = "Helmet", Size = p.Size * Vector3.new(1.25, 1.15, 1.25), CFrame = p.CFrame,
					Color = STEEL, Material = Enum.Material.DiamondPlate, Parent = folder })
				weld(helm, p)
				local visor = shellPart({ Name = "Visor", Size = Vector3.new(p.Size.X * 1.1, 0.3, 0.25),
					CFrame = p.CFrame * CFrame.new(0, 0.1, -p.Size.Z * 0.62), Color = GLOW, Material = Enum.Material.Neon, Parent = folder })
				weld(visor, p)
				local fin = shellPart({ Name = "Fin", Size = Vector3.new(0.2, 0.7, p.Size.Z * 0.9),
					CFrame = p.CFrame * CFrame.new(0, p.Size.Y * 0.65, 0), Color = ACCENT, Material = Enum.Material.Metal, Parent = folder })
				weld(fin, p)
			else
				local plate = shellPart({ Name = p.Name .. "Plate", Size = p.Size * 1.12 + Vector3.new(0.06, 0, 0.06),
					CFrame = p.CFrame, Color = STEEL, Material = Enum.Material.DiamondPlate, Parent = folder })
				weld(plate, p)

				if p.Name == "UpperTorso" or p.Name == "Torso" then
					local core = shellPart({ Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7),
						CFrame = p.CFrame * CFrame.new(0, 0.2, -p.Size.Z * 0.62), Color = GLOW, Material = Enum.Material.Neon, Parent = folder })
					weld(core, p)
					for _, side in ipairs({ -1, 1 }) do
						local pad = shellPart({ Name = "ShoulderPad", Size = Vector3.new(1.2, 0.6, 1.4),
							CFrame = p.CFrame * CFrame.new(side * (p.Size.X / 2 + 0.45), p.Size.Y / 2 - 0.1, 0) * CFrame.Angles(0, 0, side * -0.25),
							Color = ACCENT, Material = Enum.Material.Metal, Parent = folder })
						weld(pad, p)
					end
				elseif p.Name == "RightLowerArm" or p.Name == "Right Arm" then
					local cannon = shellPart({ Name = "ArmCannon", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 0.7, 0.7),
						CFrame = p.CFrame * CFrame.new(0.55, -0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
						Color = Color3.fromRGB(40, 40, 46), Material = Enum.Material.Metal, Parent = folder })
					weld(cannon, p)
				end
			end
		end
	end
end

local function setBodyHidden(char, hidden)
	for _, d in ipairs(char:GetDescendants()) do
		if (d:IsA("BasePart") or d:IsA("Decal")) and d.Name ~= "HumanoidRootPart" then
			if hidden then
				if d:GetAttribute("OrigT") == nil then
					d:SetAttribute("OrigT", d.Transparency)
				end
				d.Transparency = 1
			else
				local orig = d:GetAttribute("OrigT")
				if orig ~= nil then
					d.Transparency = orig
					d:SetAttribute("OrigT", nil)
				end
			end
		end
	end
end

local function buildVehicle(char)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then
		return
	end

	local groundOffset = 3
	if hum.RigType == Enum.HumanoidRigType.R15 then
		groundOffset = hum.HipHeight + hrp.Size.Y / 2
	end
	local base = -groundOffset

	local folder = Instance.new("Folder")
	folder.Name = "ShiftframeVehicle"
	folder.Parent = char

	local function add(props, offset)
		props.CFrame = hrp.CFrame * offset
		props.Parent = folder
		local p = shellPart(props)
		weld(p, hrp)
		return p
	end

	add({ Name = "Chassis", Size = Vector3.new(6, 1.6, 11), Color = STEEL, Material = Enum.Material.Metal }, CFrame.new(0, base + 1.9, 0))
	add({ Name = "Cabin", Size = Vector3.new(5, 1.8, 5), Color = STEEL, Material = Enum.Material.DiamondPlate }, CFrame.new(0, base + 3.5, 1))
	add({ Name = "Windshield", Size = Vector3.new(4.6, 1.5, 0.3), Color = GLOW, Material = Enum.Material.Neon, Transparency = 0.3 },
		CFrame.new(0, base + 3.5, -1.55) * CFrame.Angles(math.rad(-20), 0, 0))
	add({ Name = "Stripe", Size = Vector3.new(1.2, 0.1, 11.05), Color = ACCENT, Material = Enum.Material.SmoothPlastic }, CFrame.new(0, base + 2.72, 0))
	add({ Name = "Spoiler", Size = Vector3.new(6, 0.25, 1.2), Color = ACCENT, Material = Enum.Material.Metal }, CFrame.new(0, base + 3.4, 5.3))

	for _, x in ipairs({ -3.25, 3.25 }) do
		for _, z in ipairs({ -3.6, 3.6 }) do
			add({ Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 2.6, 2.6),
				Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.SmoothPlastic }, CFrame.new(x, base + 1.3, z))
		end
	end

	for _, x in ipairs({ -2.2, 2.2 }) do
		local head = add({ Name = "Headlight", Size = Vector3.new(1.2, 0.5, 0.2), Color = Color3.fromRGB(255, 250, 220),
			Material = Enum.Material.Neon }, CFrame.new(x, base + 2.1, -5.55))
		local beam = Instance.new("SpotLight")
		beam.Range = 45
		beam.Angle = 50
		beam.Brightness = 3
		beam.Face = Enum.NormalId.Front
		beam.Parent = head
		add({ Name = "TailLight", Size = Vector3.new(1.2, 0.5, 0.2), Color = Color3.fromRGB(255, 40, 40),
			Material = Enum.Material.Neon }, CFrame.new(x, base + 2.1, 5.55))
	end
end

local function setMode(player, mode)
	local s = state[player]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not s or not hum then
		return
	end

	if mode == "Vehicle" then
		setBodyHidden(char, true)
		buildVehicle(char)
		hum.WalkSpeed = CONFIG.VEHICLE_SPEED
		hum.UseJumpPower = true
		hum.JumpPower = CONFIG.VEHICLE_JUMP
	else
		local v = char:FindFirstChild("ShiftframeVehicle")
		if v then
			v:Destroy()
		end
		setBodyHidden(char, false)
		hum.WalkSpeed = CONFIG.ROBOT_SPEED
		hum.UseJumpPower = true
		hum.JumpPower = CONFIG.ROBOT_JUMP
	end

	s.mode = mode
	char:SetAttribute("Mode", mode)
	TransformEvent:FireAllClients(char, mode)
end

---------------------------------------------------------------------------
-- Hollowers (shadow creatures)
---------------------------------------------------------------------------
local creatureFolder = Instance.new("Folder")
creatureFolder.Name = "Creatures"
creatureFolder.Parent = workspace

local creatures = {} -- [model] = { lastHit = 0, phase = number }

local SHADOW = Color3.fromRGB(28, 22, 26)
local MAW = Color3.fromRGB(255, 40, 50)

local function updateHealthBar(m)
	local bar = m:FindFirstChild("Fill", true)
	if bar then
		local hp = math.max(m:GetAttribute("Health"), 0)
		bar.Size = UDim2.fromScale(hp / CONFIG.CREATURE_HEALTH, 1)
	end
end

local function spawnCreature()
	local spot = randomOpenPoint(undergrid, CONFIG.UNDERGRID_OFFSET)
	local m = Instance.new("Model")
	m.Name = "Hollower"

	local function add(props, cf)
		props.CFrame = cf
		props.CanCollide = false
		props.Parent = m
		return newPart(props)
	end

	local body = add({ Name = "Body", Size = Vector3.new(2.5, 5, 1.6), Color = SHADOW, Material = Enum.Material.Slate }, CFrame.new())
	local head = add({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), Color = SHADOW,
		Material = Enum.Material.Slate }, CFrame.new(0, 3.8, 0))
	add({ Name = "Maw", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1.7, 1.7), Color = MAW,
		Material = Enum.Material.Neon }, CFrame.new(0, 3.8, -1.45) * CFrame.Angles(0, math.rad(90), 0))
	for k = 1, 5 do
		local angle = k * (math.pi * 2 / 5)
		add({ Name = "Petal", Size = Vector3.new(0.9, 2.2, 0.2), Color = Color3.fromRGB(60, 30, 36), Material = Enum.Material.Slate },
			CFrame.new(0, 3.8, -1.5) * CFrame.Angles(0, 0, angle) * CFrame.new(0, 1.4, 0) * CFrame.Angles(-0.6, 0, 0))
	end
	for _, side in ipairs({ -1, 1 }) do
		add({ Name = "Arm", Size = Vector3.new(0.5, 5.5, 0.5), Color = SHADOW, Material = Enum.Material.Slate },
			CFrame.new(side * 1.8, -0.6, -0.4) * CFrame.Angles(0.3, 0, side * 0.15))
		add({ Name = "Leg", Size = Vector3.new(0.7, 3, 0.7), Color = SHADOW, Material = Enum.Material.Slate },
			CFrame.new(side * 0.7, -4, 0))
	end

	local glow = Instance.new("PointLight")
	glow.Color = MAW
	glow.Range = 12
	glow.Brightness = 2
	glow.Parent = head

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 8)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 80
	gui.Parent = head
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = MAW
	fill.BorderSizePixel = 0
	fill.Parent = back

	m.PrimaryPart = body
	m:SetAttribute("Creature", true)
	m:SetAttribute("Health", CONFIG.CREATURE_HEALTH)
	m:PivotTo(CFrame.new(spot + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	m.Parent = creatureFolder
	creatures[m] = { lastHit = 0, phase = rng:NextNumber(0, 10) }
end

local function killCreature(m)
	creatures[m] = nil
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = true
			p.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-25, 25), rng:NextNumber(15, 40), rng:NextNumber(-25, 25))
		end
	end
	Debris:AddItem(m, 3)
end

local function damageCreature(m, amount)
	if not creatures[m] then
		return
	end
	m:SetAttribute("Health", m:GetAttribute("Health") - amount)
	updateHealthBar(m)
	if m:GetAttribute("Health") <= 0 then
		killCreature(m)
	end
end

local function clearCreatures()
	for m in pairs(creatures) do
		killCreature(m)
	end
end

local function playersInUndergrid()
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if plr:GetAttribute("Dimension") == "Undergrid" and hrp and hum and hum.Health > 0 then
			table.insert(list, { hrp = hrp, hum = hum })
		end
	end
	return list
end

-- creature brain: drift toward the nearest player in the Undergrid, passing through walls
RunService.Heartbeat:Connect(function(dt)
	local targets = playersInUndergrid()
	local now = os.clock()
	for m, data in pairs(creatures) do
		if m.Parent and m.PrimaryPart then
			local root = m.PrimaryPart.Position
			local best, bestDist = nil, CONFIG.CREATURE_AGGRO
			for _, t in ipairs(targets) do
				local d = (t.hrp.Position - root).Magnitude
				if d < bestDist then
					best, bestDist = t, d
				end
			end

			data.phase = data.phase + dt
			local bob = math.sin(data.phase * 4) * 0.02

			if best then
				local flat = Vector3.new(best.hrp.Position.X, root.Y, best.hrp.Position.Z)
				local delta = flat - root
				local newPos = root
				if delta.Magnitude > 3.5 then
					newPos = root + delta.Unit * math.min(CONFIG.CREATURE_SPEED * dt, delta.Magnitude - 3.5)
				end
				if delta.Magnitude > 0.1 then
					m:PivotTo(CFrame.lookAt(newPos, flat) * CFrame.Angles(bob, 0, 0))
				end
				if bestDist < 6.5 and now - data.lastHit > CONFIG.CREATURE_HIT_COOLDOWN then
					data.lastHit = now
					best.hum:TakeDamage(CONFIG.CREATURE_DAMAGE)
				end
			else
				m:PivotTo(m.PrimaryPart.CFrame * CFrame.Angles(0, dt * 0.4, 0))
			end
		else
			creatures[m] = nil
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(CONFIG.CREATURE_SPAWN_INTERVAL)
		local count = 0
		for _ in pairs(creatures) do
			count = count + 1
		end
		if count < CONFIG.MAX_CREATURES and #playersInUndergrid() > 0 then
			spawnCreature()
		end
	end
end)

---------------------------------------------------------------------------
-- Signal Shards and the rift seal
---------------------------------------------------------------------------
local shardFolder = Instance.new("Folder")
shardFolder.Name = "SignalShards"
shardFolder.Parent = workspace

local roundOver = false

local function spawnShard()
	local spot = randomOpenPoint(undergrid, CONFIG.UNDERGRID_OFFSET)
	local shard = newPart({ Name = "SignalShard", Size = Vector3.new(1.4, 3, 1.4), CFrame = CFrame.new(spot + Vector3.new(0, 3, 0)),
		Color = GLOW, Material = Enum.Material.Neon, CanCollide = false, Parent = shardFolder })
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 18
	light.Brightness = 2
	light.Parent = shard

	local taken = false
	shard.Touched:Connect(function(hit)
		if taken then
			return
		end
		local plr = Players:GetPlayerFromCharacter(hit.Parent)
		if plr and plr:GetAttribute("Dimension") == "Undergrid" then
			taken = true
			shard:Destroy()
			plr:SetAttribute("Carrying", plr:GetAttribute("Carrying") + 1)
			NotifyEvent:FireClient(plr, "SIGNAL SHARD ACQUIRED - RETURN TO THE TOWER", GLOW)
		end
	end)
end

RunService.Heartbeat:Connect(function(dt)
	for _, shard in ipairs(shardFolder:GetChildren()) do
		shard.CFrame = shard.CFrame * CFrame.Angles(0, dt * 2, 0)
	end
end)

-- keep exactly enough shards in the world to finish the goal
task.spawn(function()
	while true do
		task.wait(3)
		if not roundOver then
			local carried = 0
			for _, plr in ipairs(Players:GetPlayers()) do
				carried = carried + (plr:GetAttribute("Carrying") or 0)
			end
			local needed = CONFIG.SHARDS_TO_WIN - ReplicatedStorage:GetAttribute("Progress") - carried
			while #shardFolder:GetChildren() < needed do
				spawnShard()
			end
		end
	end
end)

local function sendHome(plr)
	local char = plr.Character
	if char and plr:GetAttribute("Dimension") == "Undergrid" then
		char:PivotTo(char:GetPivot() - CONFIG.UNDERGRID_OFFSET)
		plr:SetAttribute("Dimension", "Town")
	end
end

local function winRound()
	roundOver = true
	clearCreatures()
	shardFolder:ClearAllChildren()
	notifyAll("THE RIFT IS SEALED! HOLLOW CREEK IS SAFE... FOR NOW", Color3.fromRGB(60, 255, 140))
	for _, plr in ipairs(Players:GetPlayers()) do
		sendHome(plr)
	end
	task.wait(12)
	ReplicatedStorage:SetAttribute("Progress", 0)
	roundOver = false
	notifyAll("WARNING: THE RIFT HAS REOPENED", Color3.fromRGB(255, 50, 60))
end

local consoleDebounce = {}
console.Touched:Connect(function(hit)
	local plr = Players:GetPlayerFromCharacter(hit.Parent)
	if not plr or consoleDebounce[plr] or roundOver then
		return
	end
	local carrying = plr:GetAttribute("Carrying") or 0
	if carrying <= 0 then
		return
	end
	consoleDebounce[plr] = true
	plr:SetAttribute("Carrying", 0)
	local progress = math.min(ReplicatedStorage:GetAttribute("Progress") + carrying, CONFIG.SHARDS_TO_WIN)
	ReplicatedStorage:SetAttribute("Progress", progress)
	local stats = plr:FindFirstChild("leaderstats")
	if stats then
		stats.Shards.Value = stats.Shards.Value + carrying
	end
	notifyAll(plr.DisplayName .. " DELIVERED " .. carrying .. " SHARD(S)  [" .. progress .. "/" .. CONFIG.SHARDS_TO_WIN .. "]", GLOW)
	if progress >= CONFIG.SHARDS_TO_WIN then
		task.spawn(winRound)
	end
	task.wait(1)
	consoleDebounce[plr] = nil
end)

---------------------------------------------------------------------------
-- Remote handlers
---------------------------------------------------------------------------
TransformEvent.OnServerEvent:Connect(function(player)
	local s = state[player]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not s or not hum or hum.Health <= 0 or not s.ready then
		return
	end
	if os.clock() - s.lastTransform < CONFIG.TRANSFORM_COOLDOWN then
		return
	end
	s.lastTransform = os.clock()
	setMode(player, s.mode == "Robot" and "Vehicle" or "Robot")
end)

BlastEvent.OnServerEvent:Connect(function(player, aimPoint)
	if typeof(aimPoint) ~= "Vector3" then
		return
	end
	local s = state[player]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not s or not hrp or not hum or hum.Health <= 0 or s.mode ~= "Robot" then
		return
	end
	if os.clock() - s.lastBlast < CONFIG.BLAST_COOLDOWN then
		return
	end
	s.lastBlast = os.clock()

	local origin = hrp.Position + Vector3.new(0, 1.5, 0)
	local dir = aimPoint - origin
	if dir.Magnitude < 1 then
		return
	end
	dir = dir.Unit * CONFIG.BLAST_RANGE

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local result = workspace:Raycast(origin, dir, params)
	local hitPos = result and result.Position or (origin + dir)

	if result then
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		if model and model:GetAttribute("Creature") then
			damageCreature(model, CONFIG.BLAST_DAMAGE)
		end
	end

	-- laser bolt + impact flash
	local len = (hitPos - origin).Magnitude
	local bolt = newPart({ Name = "Bolt", Size = Vector3.new(0.35, 0.35, len),
		CFrame = CFrame.lookAt(origin, hitPos) * CFrame.new(0, 0, -len / 2), Color = ACCENT,
		Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false, Parent = workspace })
	Debris:AddItem(bolt, 0.12)
	local flash = newPart({ Name = "Impact", Shape = Enum.PartType.Ball, Size = Vector3.new(2.5, 2.5, 2.5), Position = hitPos,
		Color = ACCENT, Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false, CanQuery = false,
		CanTouch = false, Parent = workspace })
	Debris:AddItem(flash, 0.15)
end)

ShiftEvent.OnServerEvent:Connect(function(player)
	local s = state[player]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not s or not hrp or roundOver then
		return
	end
	if os.clock() - s.lastShift < CONFIG.SHIFT_COOLDOWN then
		return
	end
	local inTown = player:GetAttribute("Dimension") == "Town"
	local riftPos = inTown and TOWN_RIFT_POS or UG_RIFT_POS
	if (hrp.Position - riftPos).Magnitude > CONFIG.RIFT_RANGE + 4 then
		return
	end
	s.lastShift = os.clock()

	local delta = inTown and CONFIG.UNDERGRID_OFFSET or -CONFIG.UNDERGRID_OFFSET
	char:PivotTo(char:GetPivot() + delta)
	player:SetAttribute("Dimension", inTown and "Undergrid" or "Town")
	if inTown then
		NotifyEvent:FireClient(player, "YOU ENTERED THE UNDERGRID. FIND THE SHARDS.", Color3.fromRGB(255, 60, 70))
	else
		NotifyEvent:FireClient(player, "BACK IN HOLLOW CREEK", Color3.fromRGB(255, 214, 140))
	end
end)

---------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	state[player] = { mode = "Robot", lastTransform = 0, lastBlast = 0, lastShift = 0, ready = false }
	player:SetAttribute("Dimension", "Town")
	player:SetAttribute("Carrying", 0)

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player
	local shards = Instance.new("IntValue")
	shards.Name = "Shards"
	shards.Parent = stats

	player.CharacterAdded:Connect(function(char)
		local s = state[player]
		if not s then
			return
		end
		s.mode = "Robot"
		s.ready = false
		player:SetAttribute("Dimension", "Town")
		player:SetAttribute("Carrying", 0) -- shards are lost if you fall
		char:SetAttribute("Mode", "Robot")

		local hum = char:WaitForChild("Humanoid")
		char:WaitForChild("HumanoidRootPart")
		local start = os.clock()
		while not player:HasAppearanceLoaded() and os.clock() - start < 5 do
			task.wait(0.1)
		end
		if char.Parent then
			applyRobotArmor(char)
			hum.WalkSpeed = CONFIG.ROBOT_SPEED
			hum.UseJumpPower = true
			hum.JumpPower = CONFIG.ROBOT_JUMP
			s.ready = true
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
	consoleDebounce[player] = nil
end)
