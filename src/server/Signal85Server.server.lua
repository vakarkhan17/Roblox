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
local TweenService = game:GetService("TweenService")
local DataStoreService = game:GetService("DataStoreService")

local CONFIG = {
	UNDERGRID_OFFSET = Vector3.new(0, 0, 1500), -- where the mirror world is built
	RIFT_RANGE = 12,
	SHIFT_COOLDOWN = 2,
	RIFT_SAFE_RADIUS = 30, -- Hollowers can't enter this circle around the Undergrid rift
	RIFT_SHIELD_TIME = 5,  -- seconds of force-field shield after crossing the rift

	ROBOT_SPEED = 18,
	ROBOT_JUMP = 50,
	VEHICLE_SPEED = 75,
	VEHICLE_JUMP = 20,
	TRANSFORM_COOLDOWN = 1.2,

	-- Pulse Cannon (robot arm blaster)
	BLAST_DAMAGE = 45,
	BLAST_RANGE = 140,
	BLAST_COOLDOWN = 0.25,
	BLAST_SPLASH_RADIUS = 8,   -- enemies this close to the impact also get hit...
	BLAST_SPLASH_DAMAGE = 0.5, -- ...for this fraction of the damage

	SHARDS_TO_WIN = 6,

	MAX_CREATURES = 8,
	CREATURE_SPAWN_INTERVAL = 5,
	CREATURE_HEALTH = 100,
	CREATURE_SPEED = 13,
	CREATURE_AGGRO = 160,
	CREATURE_DAMAGE = 15,
	CREATURE_HIT_COOLDOWN = 1,

	-- chapters
	DEBUG_START_CHAPTER = 1,   -- testing: chapter the server starts in (2 = jump to Chapter 2). Normal play: 1
	DEBUG_START_STAGE = nil,   -- testing: e.g. "Boss" to jump straight to the Mind Warden. Normal play: nil
	CHAPTER_PAUSE = 8,         -- seconds between "CHAPTER 1 COMPLETE" and Chapter 2

	-- Chapter 2: Hive Nodes
	CH2_NODES = 3,
	NODE_HEALTH = 300,
	NODE_SPAWN_INTERVAL = 15,  -- each node calls a Hollower this often...
	NODE_SPAWN_RANGE = 80,     -- ...while a player is this close
	CH2_MAX_CREATURES = 12,
	CH2_CREATURE_SPAWN_INTERVAL = 3,

	-- Chapter 2: the Mind Warden
	BOSS_HEALTH = 2000,
	BOSS_HEALTH_PER_PLAYER = 0.5, -- +50% per extra player...
	BOSS_MAX_SCALED_PLAYERS = 4,  -- ...counting up to this many players
	BOSS_TELEGRAPH = 1,           -- warning glow/shake before each attack
	BOSS_OPEN_TIME = 5,           -- head open = vulnerable
	BOSS_ATTACK_PAUSE = 1.5,
	BOSS_SHOCKWAVE_DAMAGE = 30,   -- halved in vehicle mode
	BOSS_SHOCKWAVE_RADIUS = 90,
	BOSS_SHOCKWAVE_SPEED = 40,    -- studs per second
	BOSS_SUMMON_COUNT = 3,
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
local SettingsEvent = makeRemote("Settings")   -- client -> server (LIGHT level, kept for the save)

local function makeFunction(name)
	local f = Instance.new("RemoteFunction")
	f.Name = name
	f.Parent = remotes
	return f
end

local GetSaveFunction = makeFunction("GetSave")         -- client -> server: save summary for the start menu
local ChooseStartFunction = makeFunction("ChooseStart") -- client -> server: "continue" | "new" | "chapter", n | "join"
local SaveGameFunction = makeFunction("SaveGame")       -- client -> server: manual save -> ok, message

-- shared world state (see the Chapters section)
ReplicatedStorage:SetAttribute("Chapter", 1)
ReplicatedStorage:SetAttribute("ChapterTitle", "")
ReplicatedStorage:SetAttribute("Stage", "Shards")
ReplicatedStorage:SetAttribute("Progress", 0)
ReplicatedStorage:SetAttribute("Goal", CONFIG.SHARDS_TO_WIN)
ReplicatedStorage:SetAttribute("BossHealth", 0)
ReplicatedStorage:SetAttribute("BossMaxHealth", 0)
ReplicatedStorage:SetAttribute("BossOpen", false)

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

-- the area around the Undergrid rift is safe: anything inside is moved to the edge
local function outsideRiftZone(pos, extra)
	local radius = CONFIG.RIFT_SAFE_RADIUS + (extra or 0)
	local flat = Vector3.new(pos.X - UG_RIFT_POS.X, 0, pos.Z - UG_RIFT_POS.Z)
	if flat.Magnitude >= radius then
		return pos
	end
	local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(1, 0, 0)
	return Vector3.new(UG_RIFT_POS.X, pos.Y, UG_RIFT_POS.Z) + dir * radius
end

-- at: optional ground point to spawn on (default: random open spot in the Undergrid)
local function spawnCreature(at)
	local spot = outsideRiftZone(at or randomOpenPoint(undergrid, CONFIG.UNDERGRID_OFFSET), 15)
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
			table.insert(list, { plr = plr, hrp = hrp, hum = hum })
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
				newPos = outsideRiftZone(newPos) -- they wait at the edge of the safe zone
				if delta.Magnitude > 0.1 then
					m:PivotTo(CFrame.lookAt(newPos, flat) * CFrame.Angles(bob, 0, 0))
				end
				-- TakeDamage does nothing while the player has the rift shield (ForceField)
				local reach = (best.hrp.Position - m.PrimaryPart.Position).Magnitude
				if reach < 6.5 and now - data.lastHit > CONFIG.CREATURE_HIT_COOLDOWN then
					data.lastHit = now
					best.hum:TakeDamage(CONFIG.CREATURE_DAMAGE)
				end
			else
				local pos = outsideRiftZone(root)
				m:PivotTo(CFrame.new(pos) * (m.PrimaryPart.CFrame - root) * CFrame.Angles(0, dt * 0.4, 0))
			end
		else
			creatures[m] = nil
		end
	end
end)

local function creatureCount()
	local count = 0
	for _ in pairs(creatures) do
		count = count + 1
	end
	return count
end

local function anyPlayerNear(position, range)
	for _, t in ipairs(playersInUndergrid()) do
		if (t.hrp.Position - position).Magnitude <= range then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------
-- Chapters
--   The world state is shared by the whole server and exposed on
--   ReplicatedStorage: Chapter, ChapterTitle, Stage ("Shards", "Nodes",
--   "Boss", "Complete"), Progress / Goal (the x / y counter of the current
--   stage) and BossHealth / BossMaxHealth / BossOpen.
--   Each chapter in CHAPTERS has a title and start(stageState); its own code
--   decides when it is won. startChapter (below) switches chapters.
---------------------------------------------------------------------------
local GREEN = Color3.fromRGB(60, 255, 140)
local WARN = Color3.fromRGB(255, 60, 70)

local chapterToken = 0      -- bumped by startChapter; loops of an old chapter see the change and stop
local transitioning = false -- between chapters: no rift shifting, no deliveries
local startChapter          -- defined at the end of this section

---------------------------------------------------------------------------
-- Saving: DataStore "Signal85Save_v1", key "player_<UserId>"
--   Every DataStore call is wrapped in pcall with retries. If DataStores are
--   unavailable (unpublished place, Studio API access off) the game still
--   runs and the start menu says saving is unavailable.
--   A player's save is only written after they picked CONTINUE / NEW GAME /
--   a chapter, so sitting in the menu never overwrites an old save.
---------------------------------------------------------------------------
local SAVE_VERSION = 1
local WRITE_GAP = 7 -- DataStores allow one write per key every 6 s

local saveStore = nil
do
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("Signal85Save_v1")
	end)
	if ok then
		saveStore = store
	else
		warn("[Save] DataStores unavailable: " .. tostring(store))
	end
end

-- [player] = { loaded, available, chosen, save, bestChapter, brightness, lastWrite, queued, lastManual, lastChoose }
local profiles = {}

local function saveKey(player)
	return "player_" .. player.UserId
end

local function withRetries(fn)
	local err
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		err = result
		if attempt < 3 then
			task.wait(attempt * 2)
		end
	end
	warn("[Save] " .. tostring(err))
	return false, err
end

local function loadProfile(player)
	local profile = {
		loaded = false, available = saveStore ~= nil, chosen = false, save = nil, bestChapter = 1, brightness = nil,
		lastWrite = 0, queued = false, lastManual = -math.huge, lastChoose = -math.huge,
		reason = saveStore == nil and "NOT PUBLISHED" or nil, -- why saving is unavailable, shown in the menu
	}
	profiles[player] = profile
	if saveStore then
		local ok, data = withRetries(function()
			return saveStore:GetAsync(saveKey(player))
		end)
		if not ok then
			profile.available = false
			local message = tostring(data)
			profile.reason = (message:find("API") or message:find("Studio") or message:find("403")) and "API ACCESS OFF" or "LOAD ERROR"
		elseif type(data) == "table" and data.version == SAVE_VERSION then
			profile.save = data
			profile.bestChapter = math.max(tonumber(data.bestChapter) or 1, 1)
			profile.brightness = tonumber(data.brightness)
			local stats = player:FindFirstChild("leaderstats")
			if stats and tonumber(data.lifetimeShards) then
				stats.Shards.Value = data.lifetimeShards
			end
		end
	end
	profile.bestChapter = math.max(profile.bestChapter, ReplicatedStorage:GetAttribute("Chapter") or 1)
	profile.loaded = true
end

-- what gets saved: the current chapter/stage, without boss HP or carried shards
local function snapshot()
	local chapter = ReplicatedStorage:GetAttribute("Chapter") or 1
	local stage = ReplicatedStorage:GetAttribute("Stage") or "Shards"
	local progress = ReplicatedStorage:GetAttribute("Progress") or 0
	if stage == "Boss" then
		progress = 0 -- a saved boss fight restarts from the beginning of the fight
	elseif chapter == 1 and stage == "Complete" then
		chapter, stage, progress = 2, "Nodes", 0 -- already on the way to Chapter 2
	end
	return chapter, stage, progress
end

local function writeSave(player)
	local profile = profiles[player]
	if not saveStore or not profile or not profile.loaded or not profile.available or not profile.chosen then
		return false
	end
	local chapter, stage, progress = snapshot()
	profile.bestChapter = math.max(profile.bestChapter, chapter)
	local stats = player:FindFirstChild("leaderstats")
	local data = {
		version = SAVE_VERSION,
		chapter = chapter,
		stage = stage,
		progress = progress,
		bestChapter = profile.bestChapter,
		lifetimeShards = stats and stats.Shards.Value or 0,
		brightness = profile.brightness or 2,
		introSeen = true,
		savedAt = os.time(),
	}
	profile.lastWrite = os.clock()
	local ok = withRetries(function()
		return saveStore:UpdateAsync(saveKey(player), function(old)
			if type(old) == "table" and tonumber(old.bestChapter) then
				data.bestChapter = math.max(data.bestChapter, old.bestChapter) -- never goes down
			end
			return data
		end)
	end)
	if ok then
		profile.save = data
	end
	return ok
end

-- auto-save soon, respecting the DataStore write gap
local function queueSave(player)
	local profile = profiles[player]
	if not profile or not profile.chosen or profile.queued then
		return
	end
	profile.queued = true
	task.delay(math.max(WRITE_GAP - (os.clock() - profile.lastWrite), 0), function()
		profile.queued = false
		if profiles[player] == profile then
			writeSave(player)
		end
	end)
end

local function checkpoint()
	for _, plr in ipairs(Players:GetPlayers()) do
		queueSave(plr)
	end
end

local function setStage(stage, progress, goal)
	ReplicatedStorage:SetAttribute("Stage", stage)
	ReplicatedStorage:SetAttribute("Goal", goal)
	ReplicatedStorage:SetAttribute("Progress", progress)
	checkpoint() -- auto-save on every stage change (and so on every chapter start)
end

local function stageIs(stage)
	return not transitioning and ReplicatedStorage:GetAttribute("Stage") == stage
end

-- ambient Hollowers: Chapter 1 shards, faster and more while Hive Nodes live, none otherwise
task.spawn(function()
	while true do
		task.wait(stageIs("Nodes") and CONFIG.CH2_CREATURE_SPAWN_INTERVAL or CONFIG.CREATURE_SPAWN_INTERVAL)
		local cap = (stageIs("Shards") and CONFIG.MAX_CREATURES) or (stageIs("Nodes") and CONFIG.CH2_MAX_CREATURES) or 0
		if creatureCount() < cap and #playersInUndergrid() > 0 then
			spawnCreature()
		end
	end
end)

---------------------------------------------------------------------------
-- Chapter 1: Signal Shards and the rift seal
---------------------------------------------------------------------------
local shardFolder = Instance.new("Folder")
shardFolder.Name = "SignalShards"
shardFolder.Parent = workspace

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
		if stageIs("Shards") then
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

local function completeChapter1()
	local token = chapterToken
	transitioning = true
	setStage("Complete", CONFIG.SHARDS_TO_WIN, CONFIG.SHARDS_TO_WIN)
	clearCreatures()
	shardFolder:ClearAllChildren()
	for _, plr in ipairs(Players:GetPlayers()) do
		sendHome(plr)
	end
	notifyAll("CHAPTER 1 COMPLETE", GREEN)
	task.wait(4)
	if token == chapterToken then
		notifyAll("THE RIFT IS SEALED... BUT THE SIGNAL DOES NOT STOP", WARN)
	end
	task.wait(math.max(CONFIG.CHAPTER_PAUSE - 4, 0))
	if token == chapterToken then
		startChapter(2)
	end
end

local consoleDebounce = {}
console.Touched:Connect(function(hit)
	local plr = Players:GetPlayerFromCharacter(hit.Parent)
	if not plr or consoleDebounce[plr] or not stageIs("Shards") then
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
		task.spawn(completeChapter1)
	end
	task.wait(1)
	consoleDebounce[plr] = nil
end)

---------------------------------------------------------------------------
-- Chapter 2, stage 1: Hive Nodes
---------------------------------------------------------------------------
local nodeFolder = Instance.new("Folder")
nodeFolder.Name = "HiveNodes"
nodeFolder.Parent = workspace

local nodes = {} -- [model] = { center, light, fill, phase, lastSpawn }
local NODE_RED = Color3.fromRGB(210, 20, 40)

local startBossStage -- defined in the boss section

-- spread nodes out: pick the candidate furthest from other nodes and the rift
local function pickNodeSpot(taken)
	local best, bestScore = nil, -1
	for _ = 1, 25 do
		local p = randomOpenPoint(undergrid, CONFIG.UNDERGRID_OFFSET)
		local score = (Vector3.new(p.X, 0, p.Z) - Vector3.new(UG_RIFT_POS.X, 0, UG_RIFT_POS.Z)).Magnitude
		for _, q in ipairs(taken) do
			score = math.min(score, (p - q).Magnitude)
		end
		if score > bestScore then
			best, bestScore = p, score
		end
	end
	return best
end

local function spawnNode(spot)
	local m = Instance.new("Model")
	m.Name = "HiveNode"
	local center = spot + Vector3.new(0, 5, 0)

	local shell = newPart({ Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.new(8, 8, 8), Position = center,
		Color = Color3.fromRGB(30, 10, 14), Material = Enum.Material.Slate, Transparency = 0.3, CanCollide = false, Parent = m })
	local core = newPart({ Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 5, 5), Position = center,
		Color = NODE_RED, Material = Enum.Material.Neon, CanCollide = false, Parent = m })
	for k = 1, 7 do
		local a = k * math.pi * 2 / 7
		local from = center + Vector3.new(math.cos(a) * 2.5, -1.5, math.sin(a) * 2.5)
		local foot = spot + Vector3.new(math.cos(a) * 10, 0.3, math.sin(a) * 10)
		local len = (foot - from).Magnitude
		newPart({ Name = "Tendril", Size = Vector3.new(0.9, 0.9, len), CFrame = CFrame.lookAt(from, foot) * CFrame.new(0, 0, -len / 2),
			Color = Color3.fromRGB(45, 14, 20), Material = Enum.Material.Slate, CanCollide = false, Parent = m })
	end

	local light = Instance.new("PointLight")
	light.Color = NODE_RED
	light.Range = 30
	light.Brightness = 3
	light.Parent = core

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 10)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.MaxDistance = 150
	gui.Parent = shell
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = NODE_RED
	fill.BorderSizePixel = 0
	fill.Parent = back

	m.PrimaryPart = core
	m:SetAttribute("Node", true)
	m:SetAttribute("Health", CONFIG.NODE_HEALTH)
	m.Parent = nodeFolder
	nodes[m] = { center = center, light = light, fill = fill, phase = rng:NextNumber(0, 10), lastSpawn = os.clock() }
end

local function clearNodes()
	for m in pairs(nodes) do
		m:Destroy()
	end
	table.clear(nodes)
end

local function burst(position, color, size)
	local ball = newPart({ Name = "Burst", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Position = position, Color = color,
		Material = Enum.Material.Neon, Transparency = 0.1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = workspace })
	TweenService:Create(ball, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Size = Vector3.new(size, size, size), Transparency = 1 }):Play()
	Debris:AddItem(ball, 0.8)
end

local function damageNode(m, amount)
	local data = nodes[m]
	if not data then
		return
	end
	local hp = m:GetAttribute("Health") - amount
	m:SetAttribute("Health", hp)
	data.fill.Size = UDim2.fromScale(math.max(hp, 0) / CONFIG.NODE_HEALTH, 1)
	if hp > 0 then
		return
	end

	nodes[m] = nil
	burst(data.center, NODE_RED, 30)
	m:Destroy()
	local goal = ReplicatedStorage:GetAttribute("Goal")
	local progress = math.min(ReplicatedStorage:GetAttribute("Progress") + 1, goal)
	ReplicatedStorage:SetAttribute("Progress", progress)
	notifyAll("HIVE NODE DESTROYED [" .. progress .. "/" .. goal .. "]", WARN)
	if progress >= goal then
		task.spawn(startBossStage)
	end
end

-- slow pulse, and each node calls Hollowers while players are near it
RunService.Heartbeat:Connect(function(dt)
	for m, data in pairs(nodes) do
		data.phase = data.phase + dt
		local pulse = (math.sin(data.phase * 2.5) + 1) / 2
		local core = m.PrimaryPart
		if core then
			local s = 4.6 + pulse * 1.4
			core.Size = Vector3.new(s, s, s)
		end
		data.light.Brightness = 2 + pulse * 3
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		if stageIs("Nodes") then
			local now = os.clock()
			for _, data in pairs(nodes) do
				if now - data.lastSpawn >= CONFIG.NODE_SPAWN_INTERVAL and creatureCount() < CONFIG.CH2_MAX_CREATURES
					and anyPlayerNear(data.center, CONFIG.NODE_SPAWN_RANGE) then
					data.lastSpawn = now
					local spot = data.center + Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-14, 14))
					spawnCreature(Vector3.new(spot.X, CONFIG.UNDERGRID_OFFSET.Y, spot.Z))
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Chapter 2, stage 2: the Mind Warden
--   A giant Hollower in front of the Undergrid radio tower. Attack loop:
--   shockwave (jump over it) -> summon Hollowers -> head opens (vulnerable).
--   Every attack is telegraphed by BOSS_TELEGRAPH seconds of glow and shaking.
---------------------------------------------------------------------------
local bossFolder = Instance.new("Folder")
bossFolder.Name = "Boss"
bossFolder.Parent = workspace

local BOSS_SCALE = 4
local BOSS_SPOT = CONFIG.UNDERGRID_OFFSET + Vector3.new(0, 0, -200) -- ground point south of the tower (tower at z -238)
local BOSS_HEIGHT = 5.5 * BOSS_SCALE                               -- body centre above the ground
local WEAK = Color3.fromRGB(255, 235, 140)

local boss = nil -- { model, parts, petals, maw, weak, light, yaw, open, openTarget, shake, glow, slam, alive, vulnerable, hp, maxHp }

-- petal around the maw. open 0 = folded shut over the maw, 1 = spread wide
local function petalOffset(angle, open)
	local S = BOSS_SCALE
	local tilt = -2.2 + open * 2.5
	return CFrame.new(0, 3.8 * S, -1.45 * S) * CFrame.Angles(0, 0, angle) * CFrame.new(0, 1.3 * S, 0)
		* CFrame.Angles(tilt, 0, 0) * CFrame.new(0, 1.1 * S, 0)
end

local function spawnBoss(maxHp)
	local S = BOSS_SCALE
	local m = Instance.new("Model")
	m.Name = "MindWarden"
	local parts = {}

	local function add(props, offset)
		props.CFrame = offset
		props.CanCollide = false
		props.Parent = m
		local p = newPart(props)
		table.insert(parts, { part = p, offset = offset })
		return p
	end

	add({ Name = "Body", Size = Vector3.new(2.5, 5, 1.6) * S, Color = SHADOW, Material = Enum.Material.Slate }, CFrame.new())
	local head = add({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3) * S, Color = SHADOW,
		Material = Enum.Material.Slate }, CFrame.new(0, 3.8 * S, 0))
	local maw = add({ Name = "Maw", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1.7, 1.7) * S, Color = MAW,
		Material = Enum.Material.Neon }, CFrame.new(0, 3.8 * S, -1.45 * S) * CFrame.Angles(0, math.rad(90), 0))
	local weak = add({ Name = "WeakPoint", Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1) * S, Color = WEAK,
		Material = Enum.Material.Neon, Transparency = 0.85 }, CFrame.new(0, 3.8 * S, -1.6 * S))
	for _, side in ipairs({ -1, 1 }) do
		add({ Name = "Arm", Size = Vector3.new(0.5, 5.5, 0.5) * S, Color = SHADOW, Material = Enum.Material.Slate },
			CFrame.new(side * 1.8 * S, -0.6 * S, -0.4 * S) * CFrame.Angles(0.3, 0, side * 0.15))
		add({ Name = "Leg", Size = Vector3.new(0.7, 3, 0.7) * S, Color = SHADOW, Material = Enum.Material.Slate },
			CFrame.new(side * 0.7 * S, -4 * S, 0))
	end

	local petals = {}
	for k = 1, 6 do
		local angle = k * (math.pi * 2 / 6)
		local p = newPart({ Name = "Petal", Size = Vector3.new(1.1, 2.2, 0.25) * S, Color = Color3.fromRGB(60, 30, 36),
			Material = Enum.Material.Slate, CanCollide = false, CFrame = petalOffset(angle, 0), Parent = m })
		table.insert(petals, { part = p, angle = angle })
	end

	local light = Instance.new("PointLight")
	light.Color = MAW
	light.Range = 60
	light.Brightness = 3
	light.Parent = head

	m.PrimaryPart = parts[1].part
	m:SetAttribute("Boss", true)
	m:PivotTo(CFrame.new(BOSS_SPOT + Vector3.new(0, BOSS_HEIGHT, 0)) * CFrame.Angles(0, math.pi, 0))
	m.Parent = bossFolder

	boss = {
		model = m, parts = parts, petals = petals, maw = maw, weak = weak, light = light,
		yaw = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, 1)), -- face south, down Main Street
		open = 0, openTarget = 0, shake = 0, glow = 3, slam = 0,
		alive = true, vulnerable = false, hp = maxHp, maxHp = maxHp,
	}
end

local function clearBoss()
	if boss then
		boss.alive = false
		boss.model:Destroy()
		boss = nil
	end
	ReplicatedStorage:SetAttribute("BossHealth", 0)
	ReplicatedStorage:SetAttribute("BossOpen", false)
end

-- animate: turn toward the nearest player, petals, telegraph shake, slam dip
RunService.Heartbeat:Connect(function(dt)
	if not boss or not boss.alive then
		return
	end
	local here = BOSS_SPOT + Vector3.new(0, BOSS_HEIGHT, 0)
	local best, bestDist = nil, 300
	for _, t in ipairs(playersInUndergrid()) do
		local d = (t.hrp.Position - here).Magnitude
		if d < bestDist then
			best, bestDist = t, d
		end
	end
	if best then
		local flat = Vector3.new(best.hrp.Position.X - here.X, 0, best.hrp.Position.Z - here.Z)
		if flat.Magnitude > 1 then
			boss.yaw = boss.yaw:Lerp(CFrame.lookAt(Vector3.zero, flat), math.min(dt * 1.2, 1))
		end
	end

	boss.open = boss.open + math.clamp(boss.openTarget - boss.open, -dt * 2.5, dt * 2.5)
	boss.slam = math.max(boss.slam - dt * 3, 0)
	local jitter = Vector3.zero
	if boss.shake > 0 then
		jitter = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-1, 1)) * boss.shake
	end
	local bob = math.sin(os.clock() * 1.5) * 0.6
	local root = CFrame.new(here + jitter + Vector3.new(0, bob - boss.slam * 4, 0)) * boss.yaw

	for _, e in ipairs(boss.parts) do
		e.part.CFrame = root * e.offset
	end
	for _, petal in ipairs(boss.petals) do
		petal.part.CFrame = root * petalOffset(petal.angle, boss.open)
	end
	boss.weak.Transparency = 0.85 - boss.open * 0.85
	boss.light.Brightness = boss.glow + boss.open * 4
end)

local function bossAlive(token)
	return boss ~= nil and boss.alive and token == chapterToken
end

-- wait while the boss is alive; false if it died or the chapter changed
local function bossWait(token, seconds)
	local t = 0
	while t < seconds do
		if not bossAlive(token) then
			return false
		end
		t = t + task.wait(0.1)
	end
	return bossAlive(token)
end

local function telegraph(token, color)
	boss.shake = 0.8
	boss.glow = 9
	boss.maw.Color = color
	local ok = bossWait(token, CONFIG.BOSS_TELEGRAPH)
	if boss then
		boss.shake = 0
		boss.glow = 3
		boss.maw.Color = MAW
	end
	return ok
end

local SHOCKWAVE_SEGMENTS = 36

local function shockwave(token)
	if not telegraph(token, Color3.fromRGB(255, 130, 60)) then
		return
	end
	boss.slam = 1
	local center = Vector3.new(BOSS_SPOT.X, CONFIG.UNDERGRID_OFFSET.Y + 0.8, BOSS_SPOT.Z)
	local segments = {}
	for i = 1, SHOCKWAVE_SEGMENTS do
		segments[i] = newPart({ Name = "Shockwave", Size = Vector3.new(1.4, 1.6, 1), Position = center, Color = MAW,
			Material = Enum.Material.Neon, Transparency = 0.15, CanCollide = false, CanQuery = false, CanTouch = false, Parent = workspace })
	end

	local hit = {}
	local radius = 4
	while radius < CONFIG.BOSS_SHOCKWAVE_RADIUS and token == chapterToken do
		radius = radius + CONFIG.BOSS_SHOCKWAVE_SPEED * RunService.Heartbeat:Wait()
		local segLen = 2 * math.pi * radius / SHOCKWAVE_SEGMENTS + 0.6
		for i, p in ipairs(segments) do
			local a = i / SHOCKWAVE_SEGMENTS * math.pi * 2
			local pos = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
			p.Size = Vector3.new(1.4, 1.6, segLen)
			p.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
		end
		-- the ring only hurts players standing on the ground: jumping clears it
		for _, t in ipairs(playersInUndergrid()) do
			if not hit[t.plr] and t.hum.FloorMaterial ~= Enum.Material.Air then
				local flat = Vector3.new(t.hrp.Position.X - center.X, 0, t.hrp.Position.Z - center.Z).Magnitude
				if math.abs(flat - radius) < 2.5 then
					hit[t.plr] = true
					local s = state[t.plr]
					local vehicle = s and s.mode == "Vehicle"
					t.hum:TakeDamage(CONFIG.BOSS_SHOCKWAVE_DAMAGE * (vehicle and 0.5 or 1))
				end
			end
		end
	end
	for _, p in ipairs(segments) do
		p:Destroy()
	end
end

local function summon(token)
	if not telegraph(token, Color3.fromRGB(190, 60, 255)) then
		return
	end
	for _ = 1, CONFIG.BOSS_SUMMON_COUNT do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(18, 30)
		spawnCreature(BOSS_SPOT + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
	end
	burst(BOSS_SPOT + Vector3.new(0, 3, 0), Color3.fromRGB(190, 60, 255), 40)
end

local function openHead(token)
	if not telegraph(token, WEAK) then
		return
	end
	boss.openTarget = 1
	boss.vulnerable = true
	ReplicatedStorage:SetAttribute("BossOpen", true)
	bossWait(token, CONFIG.BOSS_OPEN_TIME)
	if boss then
		boss.openTarget = 0
		boss.vulnerable = false
	end
	ReplicatedStorage:SetAttribute("BossOpen", false)
end

local function bossLoop(token)
	bossWait(token, 3)
	while bossAlive(token) do
		if #playersInUndergrid() == 0 then
			bossWait(token, 1) -- nobody to fight: wait
		else
			for _, attack in ipairs({ shockwave, summon, openHead }) do
				if not bossAlive(token) then
					break
				end
				attack(token)
				bossWait(token, CONFIG.BOSS_ATTACK_PAUSE)
			end
		end
	end
end

local function chapter2Complete(announce)
	local token = chapterToken
	setStage("Complete", 1, 1)
	clearCreatures()
	clearNodes()
	if announce then
		notifyAll("CHAPTER 2 COMPLETE — THE SIGNAL GOES QUIET", GREEN)
		task.delay(5, function()
			if token == chapterToken then
				notifyAll("TO BE CONTINUED...", Color3.fromRGB(255, 214, 140))
			end
		end)
	end
	-- Calm free roam from here: the creature loop spawns nothing in "Complete".
	-- TODO: Chapter 3 — add CHAPTERS[3] and call startChapter(3) from here once it is written.
end

local function defeatBoss()
	local m = boss.model
	boss.alive = false
	boss.vulnerable = false
	boss = nil
	ReplicatedStorage:SetAttribute("BossHealth", 0)
	ReplicatedStorage:SetAttribute("BossOpen", false)
	ReplicatedStorage:SetAttribute("Progress", ReplicatedStorage:GetAttribute("Goal"))

	-- collapse: the body falls apart
	burst(BOSS_SPOT + Vector3.new(0, BOSS_HEIGHT + 15, 0), WEAK, 70)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = true
			p.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-30, 30), rng:NextNumber(10, 45), rng:NextNumber(-30, 30))
		end
	end
	Debris:AddItem(m, 8)
	chapter2Complete(true)
end

-- returns true if the hit did damage (the head must be open)
local function damageBoss(amount)
	if not boss or not boss.alive or not boss.vulnerable then
		return false
	end
	boss.hp = math.max(boss.hp - amount, 0)
	ReplicatedStorage:SetAttribute("BossHealth", boss.hp)
	ReplicatedStorage:SetAttribute("Progress", boss.maxHp - boss.hp)
	if boss.hp <= 0 then
		defeatBoss()
	end
	return true
end

startBossStage = function()
	clearNodes()
	clearBoss()
	local count = math.clamp(#Players:GetPlayers(), 1, CONFIG.BOSS_MAX_SCALED_PLAYERS)
	local maxHp = math.floor(CONFIG.BOSS_HEALTH * (1 + CONFIG.BOSS_HEALTH_PER_PLAYER * (count - 1)))
	ReplicatedStorage:SetAttribute("BossMaxHealth", maxHp)
	ReplicatedStorage:SetAttribute("BossHealth", maxHp)
	setStage("Boss", 0, maxHp)
	notifyAll("THE MIND WARDEN AWAKENS", WARN)
	spawnBoss(maxHp)
	task.spawn(bossLoop, chapterToken)
end

---------------------------------------------------------------------------
-- Chapter table and startChapter
---------------------------------------------------------------------------
local CHAPTERS = {
	[1] = {
		title = "SEAL THE RIFT",
		-- stageState.progress = shards already delivered
		start = function(stageState)
			local done = math.clamp(stageState.progress or 0, 0, CONFIG.SHARDS_TO_WIN - 1)
			setStage("Shards", done, CONFIG.SHARDS_TO_WIN)
		end,
	},
	[2] = {
		title = "THE SOURCE",
		-- stageState.stage = "Nodes" (default) | "Boss" | "Complete"; progress = nodes already destroyed
		start = function(stageState)
			local stage = stageState.stage or "Nodes"
			if stage == "Boss" then
				startBossStage() -- the boss always starts fresh
			elseif stage == "Complete" then
				chapter2Complete(false)
			else
				local done = math.clamp(stageState.progress or 0, 0, CONFIG.CH2_NODES - 1)
				setStage("Nodes", done, CONFIG.CH2_NODES)
				local taken = {}
				for _ = 1, CONFIG.CH2_NODES - done do
					local spot = pickNodeSpot(taken)
					table.insert(taken, spot)
					spawnNode(spot)
				end
			end
		end,
	},
	-- TODO: Chapter 3
}

--[[
	startChapter(n, stageState)
	Resets the shared world and starts chapter n: clears creatures, shards,
	Hive Nodes and the boss, sends everyone home to town, shows the
	"CHAPTER n: TITLE" banner, then runs CHAPTERS[n].start.
	  n           chapter number (unknown numbers fall back to 1)
	  stageState  optional, to resume mid-chapter: { stage = "...", progress = number }
	              nil starts the chapter from the beginning.
	Used at server start, between chapters, and by save/continue (task 003).
]]
startChapter = function(n, stageState)
	local chapter = CHAPTERS[n] and n or 1
	chapterToken = chapterToken + 1
	transitioning = false
	clearCreatures()
	shardFolder:ClearAllChildren()
	clearNodes()
	clearBoss()
	for _, plr in ipairs(Players:GetPlayers()) do
		sendHome(plr)
		plr:SetAttribute("Carrying", 0)
		local profile = profiles[plr]
		if profile then
			profile.bestChapter = math.max(profile.bestChapter, chapter) -- unlocks it in CHAPTER SELECT
		end
	end

	ReplicatedStorage:SetAttribute("Chapter", chapter)
	ReplicatedStorage:SetAttribute("ChapterTitle", CHAPTERS[chapter].title)
	notifyAll("CHAPTER " .. chapter .. ": " .. CHAPTERS[chapter].title, Color3.fromRGB(255, 214, 140))
	CHAPTERS[chapter].start(stageState or {})
end

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

	local impactColor = GLOW
	local direct = nil
	if result then
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		if model and model:GetAttribute("Creature") then
			direct = model
			damageCreature(model, CONFIG.BLAST_DAMAGE)
		elseif model and model:GetAttribute("Node") then
			direct = model
			damageNode(model, CONFIG.BLAST_DAMAGE)
		elseif model and model:GetAttribute("Boss") then
			if not damageBoss(CONFIG.BLAST_DAMAGE) then
				impactColor = Color3.fromRGB(150, 150, 160) -- deflected: head is closed
			end
		end

		-- splash: Hollowers and Hive Nodes near the impact take part of the damage
		local splash = CONFIG.BLAST_DAMAGE * CONFIG.BLAST_SPLASH_DAMAGE
		for m in pairs(creatures) do
			if m ~= direct and m.PrimaryPart and (m.PrimaryPart.Position - hitPos).Magnitude <= CONFIG.BLAST_SPLASH_RADIUS then
				damageCreature(m, splash)
			end
		end
		for m, data in pairs(nodes) do
			if m ~= direct and (data.center - hitPos).Magnitude <= CONFIG.BLAST_SPLASH_RADIUS + 4 then
				damageNode(m, splash)
			end
		end
	end

	-- pulse bolt + impact flash
	local len = (hitPos - origin).Magnitude
	local bolt = newPart({ Name = "Bolt", Size = Vector3.new(0.6, 0.6, len),
		CFrame = CFrame.lookAt(origin, hitPos) * CFrame.new(0, 0, -len / 2), Color = GLOW,
		Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false, Parent = workspace })
	Debris:AddItem(bolt, 0.1)
	local flash = newPart({ Name = "Impact", Shape = Enum.PartType.Ball, Size = Vector3.one * CONFIG.BLAST_SPLASH_RADIUS * 0.6, Position = hitPos,
		Color = impactColor, Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false, CanQuery = false,
		CanTouch = false, Parent = workspace })
	Debris:AddItem(flash, 0.15)
end)

ShiftEvent.OnServerEvent:Connect(function(player)
	local s = state[player]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not s or not hrp or transitioning then
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

	-- arrival shield: a few seconds to look around before anything can hurt you
	local oldShield = char:FindFirstChild("RiftShield")
	if oldShield then
		oldShield:Destroy()
	end
	local shield = Instance.new("ForceField")
	shield.Name = "RiftShield"
	shield.Parent = char
	Debris:AddItem(shield, CONFIG.RIFT_SHIELD_TIME)

	if inTown then
		local stage = ReplicatedStorage:GetAttribute("Stage")
		local text = (stage == "Nodes" and "YOU ENTERED THE UNDERGRID. DESTROY THE HIVE NODES.")
			or (stage == "Boss" and "YOU ENTERED THE UNDERGRID. THE MIND WARDEN WAITS BY THE TOWER.")
			or (stage == "Complete" and "THE UNDERGRID IS QUIET... FOR NOW.")
			or "YOU ENTERED THE UNDERGRID. FIND THE SHARDS."
		NotifyEvent:FireClient(player, text .. "  SHIELD " .. CONFIG.RIFT_SHIELD_TIME .. "s - THE RIFT AREA IS SAFE", Color3.fromRGB(255, 60, 70))
	else
		NotifyEvent:FireClient(player, "BACK IN HOLLOW CREEK", Color3.fromRGB(255, 214, 140))
	end
end)

---------------------------------------------------------------------------
-- Start menu and saving remotes
--   The client only ever sends a choice; the server loads the save and
--   decides. The chapter state is shared by the whole server:
--     * fresh world (nobody chose yet, no progress): the first CONTINUE /
--       NEW GAME / chapter choice sets it up
--     * game already running: CONTINUE and NEW GAME just join it
--     * CHAPTER SELECT (replay an unlocked chapter) works on a fresh world or
--       when you are alone on the server
---------------------------------------------------------------------------
local worldChosen = false

local function worldIsFresh()
	return not worldChosen and not transitioning and (ReplicatedStorage:GetAttribute("Progress") or 0) == 0
end

local function waitForProfile(player)
	local start = os.clock()
	while os.clock() - start < 15 do
		local profile = profiles[player]
		if profile and profile.loaded then
			return profile
		end
		task.wait(0.2)
	end
	return nil
end

local function chapterList()
	local list = {}
	for n, chapter in ipairs(CHAPTERS) do
		table.insert(list, { n = n, title = chapter.title })
	end
	return list
end

GetSaveFunction.OnServerInvoke = function(player)
	local profile = waitForProfile(player)
	local summary = {
		available = profile ~= nil and profile.available,
		reason = profile and profile.reason or (profile == nil and "LOAD ERROR" or nil),
		hasSave = false,
		bestChapter = profile and profile.bestChapter or 1,
		brightness = profile and profile.brightness,
		fresh = worldIsFresh(),
		currentChapter = ReplicatedStorage:GetAttribute("Chapter"),
		chapters = chapterList(),
		now = os.time(),
	}
	local save = profile and profile.save
	if save then
		summary.hasSave = true
		summary.chapter = save.chapter
		summary.title = CHAPTERS[save.chapter] and CHAPTERS[save.chapter].title or "?"
		summary.stage = save.stage
		summary.progress = save.progress
		summary.savedAt = save.savedAt
	end
	return summary
end

ChooseStartFunction.OnServerInvoke = function(player, choice, n)
	if choice ~= "continue" and choice ~= "new" and choice ~= "chapter" and choice ~= "join" then
		return { ok = false, message = "BAD REQUEST" }
	end
	local profile = waitForProfile(player)
	if not profile then
		return { ok = false, message = "STILL LOADING - TRY AGAIN" }
	end
	if os.clock() - profile.lastChoose < 2 then
		return { ok = false, message = "PLEASE WAIT" }
	end
	profile.lastChoose = os.clock()

	local fresh = worldIsFresh()
	local joining = "JOINING YOUR CREW IN CHAPTER " .. tostring(ReplicatedStorage:GetAttribute("Chapter"))
	local message

	if choice == "chapter" then
		local chapter = tonumber(n)
		if not chapter or chapter % 1 ~= 0 or not CHAPTERS[chapter] or chapter > profile.bestChapter then
			return { ok = false, message = "THAT CHAPTER IS LOCKED" }
		end
		if not fresh and #Players:GetPlayers() > 1 then
			return { ok = false, message = "CHAPTER SELECT ONLY WORKS WHEN YOU PLAY SOLO" }
		end
		profile.chosen = true
		startChapter(chapter)
		message = "CHAPTER " .. chapter .. ": " .. CHAPTERS[chapter].title
	elseif choice == "continue" and profile.save and fresh then
		profile.chosen = true
		local save = profile.save
		startChapter(save.chapter, { stage = save.stage, progress = save.progress })
		message = "CONTINUING CHAPTER " .. tostring(ReplicatedStorage:GetAttribute("Chapter"))
	elseif (choice == "new" or choice == "continue") and fresh then
		profile.chosen = true
		startChapter(1)
		message = "NEW GAME"
	else
		profile.chosen = true -- "join", or a game is already running
		message = choice == "join" and "" or joining
	end
	worldChosen = true
	return { ok = true, message = message, chapter = ReplicatedStorage:GetAttribute("Chapter") }
end

SaveGameFunction.OnServerInvoke = function(player)
	local profile = profiles[player]
	if not profile or not profile.loaded then
		return false, "SAVE FAILED — TRY AGAIN"
	end
	if not profile.available then
		return false, "SAVING UNAVAILABLE"
	end
	local wait = 15 - (os.clock() - profile.lastManual)
	if wait > 0 then
		return false, "YOU CAN SAVE AGAIN IN " .. math.ceil(wait) .. " S"
	end
	profile.lastManual = os.clock()
	profile.chosen = true
	if writeSave(player) then
		return true, "GAME SAVED"
	end
	return false, "SAVE FAILED — TRY AGAIN"
end

SettingsEvent.OnServerEvent:Connect(function(player, brightness)
	local profile = profiles[player]
	if profile and typeof(brightness) == "number" and brightness % 1 == 0 and brightness >= -3 and brightness <= 6 then
		profile.brightness = brightness
	end
end)

---------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------
local function onPlayerAdded(player)
	if state[player] then
		return
	end
	state[player] = { mode = "Robot", lastTransform = 0, lastBlast = 0, lastShift = 0, ready = false }
	player:SetAttribute("Dimension", "Town")
	player:SetAttribute("Carrying", 0)

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player
	local shards = Instance.new("IntValue")
	shards.Name = "Shards"
	shards.Parent = stats
	task.spawn(loadProfile, player)

	local function onCharacterAdded(char)
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
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- players who joined while the map was still being built
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
	consoleDebounce[player] = nil
	writeSave(player) -- auto-save on leave (skipped if they never left the start menu)
	profiles[player] = nil
end)

-- server shutting down: save everyone, waiting up to 25 s
game:BindToClose(function()
	local pending = 0
	for _, plr in ipairs(Players:GetPlayers()) do
		pending = pending + 1
		task.spawn(function()
			writeSave(plr)
			pending = pending - 1
		end)
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 25 do
		task.wait(0.2)
	end
end)

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
local debugStage = CONFIG.DEBUG_START_STAGE
startChapter(CONFIG.DEBUG_START_CHAPTER, debugStage and { stage = debugStage } or nil)
