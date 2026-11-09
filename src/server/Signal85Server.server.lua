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

	PILOT_SPEED = 16,          -- walking as yourself (not suited up)
	PILOT_JUMP = 50,
	ROBOT_SPEED = 18,
	ROBOT_JUMP = 50,
	VEHICLE_SPEED = 75,
	VEHICLE_JUMP = 20,
	TRANSFORM_COOLDOWN = 1.2,

	-- weapons and upgrades: see WEAPONS / UPGRADES below

	-- Scrap rewards
	SCRAP_SHARD = 10,         -- per shard delivered (to the deliverer)
	SCRAP_HOLLOWER = 2,       -- per Hollower killed (to the killer)
	SCRAP_NODE = 25,          -- per Hive Node destroyed (to the destroyer)
	SCRAP_BOSS = 200,         -- Mind Warden defeated (everyone)
	SCRAP_CHAPTER = 100,      -- chapter finished (everyone)

	SHARDS_TO_WIN = 6,

	MAX_CREATURES = 8,
	CREATURE_SPAWN_INTERVAL = 5,
	CREATURE_HEALTH = 100,
	CREATURE_SPEED = 13,
	CREATURE_AGGRO = 160,
	CREATURE_DAMAGE = 15,
	CREATURE_HIT_COOLDOWN = 1,

	-- Static Hounds (Chapter 3)
	HOUND_HEALTH = 40,
	HOUND_SPEED = 24,          -- faster than robot mode (18), slower than the car (75)
	HOUND_DAMAGE = 8,
	HOUND_HIT_COOLDOWN = 0.7,
	HOUND_PACK = 3,

	-- chapters
	DEBUG_START_CHAPTER = 1,   -- testing: chapter the server starts in (2 or 3 to jump ahead). Normal play: 1
	DEBUG_START_STAGE = nil,   -- testing: e.g. "Boss", "Relays", "Carrier". Pick that chapter in CHAPTER SELECT. Normal play: nil
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

	-- Chapter 3: LOWBAND
	CH3_FILES = 5,
	RELAY_TIME = 15,             -- seconds standing in a relay circle to restart it
	RELAY_RADIUS = 9,
	RELAY_SPAWN_INTERVAL = 7,    -- a charging relay attracts a Hollower or a Hound pack this often
	CH3_MAX_CREATURES = 14,
	CARRIER_HEALTH = 1000,
	CARRIER_DEFEND_TIME = 120,   -- seconds to protect the Carrier
	CARRIER_WAVE_INTERVAL = 12,
	CARRIER_MAX_CREATURES = 18,
	RACE_TIME = 45,              -- seconds to get the shutdown code to the radio tower console
	SCRAP_FILE = 15,
	SCRAP_RELAY = 20,
	SCRAP_HOUND = 3,

	-- reasons to come back (task 010): daily reward, quests, levels, achievements, leaderboard, codes, weekend 2x
	DEBUG_DAY_OFFSET = 0,        -- testing: pretend it is N days later (1 = tomorrow). Normal play: 0
	DEBUG_FORCE_WEEKEND = false, -- testing: weekend 2x on. Normal play: false
	DAILY_REWARDS = { 50, 75, 100, 150, 200, 300, 600 }, -- Scrap for day 1..7 of the streak (day 7 also unlocks GOLD paint)
	QUEST_XP = 60,               -- XP for each finished daily quest
	LEVEL_SCRAP = 40,            -- Scrap for reaching a level = this x the new level
	MAX_LEVEL = 50,
	LEADERBOARD_REFRESH = 120,   -- seconds
	CODES = { SIGNAL85 = 250, HOLLOWCREEK = 150 }, -- code = Scrap; each works once per player. Add more here.

	-- friends and co-op (task 011)
	TUTORIAL_SCRAP = 100,        -- for finishing the "First Night" tutorial (once)
	DOWN_TIME = 15,              -- seconds a downed player waits for a revive (only when someone else is playing)
	REVIVE_HOLD = 3,             -- seconds to hold E / tap to revive
	SCRAP_REVIVE = 15,
	PING_COOLDOWN = 2,
	FRIEND_BONUS = 0.1,          -- +10% gameplay Scrap while a Roblox friend is in the same server

	-- firepower (task 012): magazines, reload and spare ammo are per weapon (WEAPONS: mag, reserve, reload)
	AMMO_REFILL_TIME = 1200,     -- seconds between free refills (half of full ammo)...
	AMMO_REFILL_TIME_NEW = 600,  -- ...or this for pilots below level 5
	AMMO_REFILL_FRACTION = 0.5,  -- the free refill tops every gun up to this part of full
	AMMO_REFILL_PRICE = 40,      -- Scrap for a full refill of every gun you own (Garage / shop)
	AMMO_DROP_CHANCE = 0.15,     -- a defeated creature drops a spare magazine this often

	-- Robux (task 017). Create these on the Roblox website (Creator Dashboard > your game >
	-- Monetization > Passes / Developer Products) and paste their ids here. 0 = not set up yet.
	GAME_PASSES = {
		vip = 0,   -- VIP PILOT: +25% gameplay Scrap & XP, double daily reward, VIP tag
		neon = 0,  -- NEON SUIT PACK: 3 exclusive suit paints
		ammo = 0,  -- AMMO BELT: +50% spare ammo, free Pulse refill every 10 min
	},
	PRODUCTS = {
		scrap500 = 0,  -- 500 SCRAP (can be bought again)
		scrap1500 = 0, -- 1500 SCRAP
	},
}

-- Weapons (robot mode). Bought with Scrap in the shop; one is equipped.
--   damage per pellet, cooldown seconds, range studs, pellets per shot, spread degrees,
--   splash radius + splashFrac (part of the damage to enemies near the impact),
--   pierce = enemies one shot can pass through, bossMult = extra damage vs the Mind Warden
local WEAPONS = {
	pulse = { name = "PULSE CANNON", price = 0, damage = 45, cooldown = 0.25, range = 140, pellets = 1, spread = 0,
		splash = 8, splashFrac = 0.5, pierce = 1, bossMult = 1, width = 0.6, color = Color3.fromRGB(80, 220, 255),
		desc = "All-rounder. Each hit splashes enemies around it." },
	arc = { name = "ARC REPEATER", price = 400, damage = 20, cooldown = 0.1, range = 140, pellets = 1, spread = 1.5,
		splash = 0, splashFrac = 0, pierce = 1, bossMult = 1, width = 0.35, color = Color3.fromRGB(190, 120, 255),
		desc = "Very fast fire. Great for melting one target." },
	scatter = { name = "STATIC SCATTERGUN", price = 700, damage = 18, cooldown = 0.6, range = 70, pellets = 5, spread = 7,
		splash = 5, splashFrac = 0.5, pierce = 1, bossMult = 1, width = 0.4, color = Color3.fromRGB(255, 170, 40),
		desc = "5 pellets at once. Short range, clears groups." },
	lance = { name = "LOWBAND LANCE", price = 1500, damage = 140, cooldown = 1.2, range = 200, pellets = 1, spread = 0,
		splash = 0, splashFrac = 0, pierce = 4, bossMult = 1.5, width = 1, color = Color3.fromRGB(255, 80, 200),
		desc = "Slow, huge damage. Pierces 4 enemies. x1.5 vs the Mind Warden." },
}
-- the second free weapon: melee (range = reach in studs). Hits everything in front of you, through walls.
WEAPONS.baton = { name = "SHOCK BATON", price = 0, damage = 55, cooldown = 0.45, range = 11, pellets = 1, spread = 0, melee = true,
	splash = 0, splashFrac = 0, pierce = 1, bossMult = 1, width = 0, color = Color3.fromRGB(255, 240, 120),
	desc = "Free. Close range: zaps every enemy in front of you, even through walls." }
local WEAPON_ORDER = { "pulse", "baton", "arc", "scatter", "lance" }
-- firepower: shots per magazine, spare shots you can carry, reload seconds (the baton never runs out)
WEAPONS.pulse.mag, WEAPONS.pulse.reserve, WEAPONS.pulse.reload = 20, 120, 1.6
WEAPONS.arc.mag, WEAPONS.arc.reserve, WEAPONS.arc.reload = 40, 240, 1.8
WEAPONS.scatter.mag, WEAPONS.scatter.reserve, WEAPONS.scatter.reload = 6, 36, 2
WEAPONS.lance.mag, WEAPONS.lance.reserve, WEAPONS.lance.reload = 4, 20, 2.2

-- Upgrades: permanent, 3 levels each
local UPGRADES = {
	armor = { name = "ARMOR PLATING", prices = { 150, 300, 500 }, desc = "+25 max health per level." },
	turbo = { name = "TURBO", prices = { 150, 300, 500 }, desc = "+10% car speed per level." },
	shield = { name = "SHIELD CAPACITOR", prices = { 100, 200, 350 }, desc = "+2 s rift shield per level." },
	mag = { name = "BIGGER MAGAZINE", prices = { 200, 400, 700 }, desc = "+25% shots per magazine per level." },
	reload = { name = "FAST RELOAD", prices = { 150, 300, 500 }, desc = "-15% reload time per level." },
}
local UPGRADE_ORDER = { "armor", "turbo", "shield", "mag", "reload" }

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
local ShopFunction = makeFunction("Shop")               -- client -> server: "list" | "buy", id | "equip", id
local RewardEvent = makeRemote("Reward")                -- server -> client: amount, reason (Scrap popup)
local RadioEvent = makeRemote("Radio")                  -- server -> client: speaker, text (walkie-talkie box)
local HitEvent = makeRemote("Hit")                      -- server -> shooter: position, damage, killed (damage numbers)
local SuitEvent = makeRemote("Suit")                    -- client -> server: suit up / take the suit off (G)
local CycleWeaponEvent = makeRemote("CycleWeapon")      -- client -> server: swap to your next owned weapon (R)
local ElevatorMenuEvent = makeRemote("ElevatorMenu")    -- server -> client: show the floor list (current floor, floors)
local ElevatorGoEvent = makeRemote("ElevatorGo")        -- client -> server: the chosen floor
local SetLookFunction = makeFunction("SetLook")         -- client -> server: pilot look table -> ok
local MetaFunction = makeFunction("Meta")               -- client -> server: "daily" | "claim" | "quests" | "achievements" | "board" | "code", text

-- defined in the "Reasons to come back" section (task 010), used all over the game
local track     -- (player, kind, amount): lifetime counts, daily quests, achievements
local trackDoor -- (player, door): a hotel room door was opened
local hurtPlayer -- (player, humanoid, damage): damage that can put a player DOWN instead of killing them (task 011)
local PingEvent = makeRemote("Ping")                    -- client -> server: world position; server -> all: position, kind, name
-- firepower (task 012), defined in the "Firepower" section
local useAmmo, pushAmmo, dropAmmo, refillAmmo -- (player, weapon) -> may fire / (player) / (position) / (player, fraction)
local robuxShop -- (profile) -> Game Passes and Scrap packs for the shop's ROBUX tab (task 017, "Robux" section)

-- shared world state (see the Chapters section)
ReplicatedStorage:SetAttribute("Chapter", 1)
ReplicatedStorage:SetAttribute("ChapterTitle", "")
ReplicatedStorage:SetAttribute("Stage", "Shards")
ReplicatedStorage:SetAttribute("Progress", 0)
ReplicatedStorage:SetAttribute("Goal", CONFIG.SHARDS_TO_WIN)
ReplicatedStorage:SetAttribute("BossHealth", 0)
ReplicatedStorage:SetAttribute("BossMaxHealth", 0)
ReplicatedStorage:SetAttribute("BossOpen", false)
ReplicatedStorage:SetAttribute("BossName", "")  -- what the top health bar is for (the Mind Warden, the Carrier)
ReplicatedStorage:SetAttribute("Deadline", 0)   -- workspace:GetServerTimeNow() when a countdown ends, 0 = none

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

-- one-shot particle burst (sparks, smoke) at a position
local function sparkBurst(position, color, count, speed, size, lifetime)
	local holder = newPart({ Name = "Fx", Size = Vector3.one * 0.2, Position = position, Transparency = 1,
		CanCollide = false, CanQuery = false, CanTouch = false, Parent = workspace })
	local fx = Instance.new("ParticleEmitter")
	fx.Enabled = false
	fx.Color = ColorSequence.new(color)
	fx.LightEmission = 1
	fx.Speed = NumberRange.new(speed * 0.5, speed)
	fx.SpreadAngle = Vector2.new(180, 180)
	fx.Lifetime = NumberRange.new((lifetime or 0.4) * 0.6, lifetime or 0.4)
	fx.Size = NumberSequence.new(size or 0.3, 0)
	fx.Drag = 4
	fx.Parent = holder
	fx:Emit(count)
	Debris:AddItem(holder, (lifetime or 0.4) + 0.2)
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
		elseif d:IsA("PointLight") or d:IsA("SpotLight") then
			d.Color = Color3.fromRGB(255, 40, 60)
			d.Brightness = 0.7
		elseif d:IsA("BillboardGui") then
			d:Destroy()
		elseif d:IsA("TextLabel") then -- shop signs (SurfaceGuis) turn dead red
			d.TextColor3 = Color3.fromRGB(200, 30, 45)
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

---------------------------------------------------------------------------
-- Project LOWBAND lab in the woods west of town (Chapter 3). Built into the
-- town model so the Undergrid copy gets a dark mirror of it too.
---------------------------------------------------------------------------
local LAB_CENTER = Vector3.new(-170, 0, -40)
local CARRIER_OFFSET = Vector3.new(10, 0, 5) -- the Carrier machine, relative to LAB_CENTER

local function buildLab(town)
	local lab = Instance.new("Model")
	lab.Name = "LowbandLab"
	local c = LAB_CENTER
	local CONCRETE = Color3.fromRGB(120, 118, 112)

	newPart({ Name = "LabFloor", Size = Vector3.new(80, 0.4, 70), Position = c + Vector3.new(0, 0.2, 0),
		Color = Color3.fromRGB(90, 90, 92), Material = Enum.Material.Concrete, Parent = lab })
	local function wall(from, to, height)
		local mid = (from + to) / 2
		local len = (to - from).Magnitude
		newPart({ Name = "LabWall", Size = Vector3.new(2, height, len + 2), CFrame = CFrame.lookAt(c + mid, c + to) + Vector3.new(0, height / 2, 0),
			Color = CONCRETE, Material = Enum.Material.Concrete, Parent = lab })
	end
	-- outer walls with doors on the east (toward town) and south sides
	wall(Vector3.new(-40, 0, -35), Vector3.new(40, 0, -35), 12)
	wall(Vector3.new(-40, 0, -35), Vector3.new(-40, 0, 35), 12)
	wall(Vector3.new(40, 0, -35), Vector3.new(40, 0, -9), 12)
	wall(Vector3.new(40, 0, 9), Vector3.new(40, 0, 35), 12)
	wall(Vector3.new(-40, 0, 35), Vector3.new(-9, 0, 35), 12)
	wall(Vector3.new(9, 0, 35), Vector3.new(40, 0, 35), 12)
	-- inside: two partitions make three rooms
	wall(Vector3.new(-12, 0, -35), Vector3.new(-12, 0, 2), 9)
	wall(Vector3.new(-40, 0, 12), Vector3.new(-22, 0, 12), 9)

	-- desks, computer banks and pipes
	local junk = Random.new(1979)
	for _ = 1, 10 do
		local p = Vector3.new(junk:NextNumber(-34, 34), 0, junk:NextNumber(-29, 29))
		if (p - CARRIER_OFFSET).Magnitude > 12 then
			newPart({ Name = "LabDesk", Size = Vector3.new(6, 3, 3), CFrame = CFrame.new(c + p + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, junk:NextNumber(0, math.pi), 0),
				Color = Color3.fromRGB(70, 74, 70), Material = Enum.Material.Metal, Parent = lab })
			newPart({ Name = "LabScreen", Size = Vector3.new(2, 1.4, 0.3), Position = c + p + Vector3.new(0, 3.8, 0),
				Color = Color3.fromRGB(60, 255, 140), Material = Enum.Material.Neon, Parent = lab })
		end
	end
	for _, z in ipairs({ -30, 30 }) do
		newPart({ Name = "LabPipe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(76, 1.4, 1.4), Position = c + Vector3.new(0, 10, z),
			Color = Color3.fromRGB(150, 90, 50), Material = Enum.Material.Metal, Parent = lab })
	end

	-- the Carrier: a tall machine with glowing rings
	local base = c + CARRIER_OFFSET
	newPart({ Name = "CarrierBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 12, 12), CFrame = CFrame.new(base + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(50, 52, 58), Material = Enum.Material.DiamondPlate, Parent = lab })
	newPart({ Name = "CarrierCoreColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(16, 4, 4), CFrame = CFrame.new(base + Vector3.new(0, 10, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(70, 72, 80), Material = Enum.Material.Metal, Parent = lab })
	for i, y in ipairs({ 5, 10, 15 }) do
		newPart({ Name = "CarrierRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 8 - i, 8 - i), CFrame = CFrame.new(base + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 120, 200), Material = Enum.Material.Neon, Parent = lab })
	end

	-- the woods around the lab
	local woods = Random.new(85)
	for _ = 1, 45 do
		local p = Vector3.new(woods:NextNumber(-240, -105), 0, woods:NextNumber(-220, 150))
		local inLab = math.abs(p.X - c.X) < 48 and math.abs(p.Z - c.Z) < 43
		local nearRift = (Vector3.new(p.X, 0, p.Z) - Vector3.new(c.X + 62, 0, c.Z)).Magnitude < 16
		if not inLab and not nearRift then
			local h = woods:NextNumber(14, 24)
			newPart({ Name = "TreeTrunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.6, 1.6), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(70, 50, 36), Material = Enum.Material.Wood, Parent = lab })
			newPart({ Name = "TreeLeaves", Shape = Enum.PartType.Ball, Size = Vector3.one * woods:NextNumber(8, 12), Position = p + Vector3.new(0, h, 0),
				Color = Color3.fromRGB(46, 72, 44), Material = Enum.Material.Grass, CanCollide = false, Parent = lab })
		end
	end

	lab.Parent = town
end

local town, console = buildTown()
buildLab(town)

---------------------------------------------------------------------------
-- Town details (built into the town model, so the Undergrid mirrors them):
-- sidewalks, curbs, power poles, mailboxes, parked cars, shop signs, puddles
---------------------------------------------------------------------------
local function decorateTown(town)
	local d = Instance.new("Model")
	d.Name = "TownDetails"
	local CONCRETE = Color3.fromRGB(150, 146, 140)

	-- sidewalks with curbs along both sides of Main Street
	for _, side in ipairs({ -1, 1 }) do
		newPart({ Name = "Sidewalk", Size = Vector3.new(8, 0.5, 500), Position = Vector3.new(side * 19, 0.25, 0),
			Color = CONCRETE, Material = Enum.Material.Concrete, Parent = d })
		newPart({ Name = "Curb", Size = Vector3.new(0.6, 0.6, 500), Position = Vector3.new(side * 15.3, 0.3, 0),
			Color = Color3.fromRGB(190, 186, 176), Material = Enum.Material.Concrete, Parent = d })
	end

	-- power poles with sagging wires on the east side
	local poles = {}
	for z = -230, 230, 46 do
		local top = Vector3.new(26, 18, z)
		newPart({ Name = "PowerPole", Size = Vector3.new(0.9, 18, 0.9), Position = Vector3.new(26, 9, z),
			Color = Color3.fromRGB(92, 70, 52), Material = Enum.Material.Wood, Parent = d })
		newPart({ Name = "PoleArm", Size = Vector3.new(5, 0.4, 0.4), Position = top - Vector3.new(0, 1, 0),
			Color = Color3.fromRGB(92, 70, 52), Material = Enum.Material.Wood, Parent = d })
		table.insert(poles, top - Vector3.new(0, 0.8, 0))
	end
	for i = 1, #poles - 1 do
		for _, dx in ipairs({ -2, 2 }) do
			local a, b = poles[i] + Vector3.new(dx, 0, 0), poles[i + 1] + Vector3.new(dx, 0, 0)
			local mid = (a + b) / 2 - Vector3.new(0, 1.2, 0) -- a little sag
			for _, seg in ipairs({ { a, mid }, { mid, b } }) do
				local len = (seg[2] - seg[1]).Magnitude
				newPart({ Name = "Wire", Size = Vector3.new(0.12, 0.12, len), CFrame = CFrame.lookAt((seg[1] + seg[2]) / 2, seg[2]),
					Color = Color3.fromRGB(20, 20, 22), Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, Parent = d })
			end
		end
	end

	-- mailboxes and fire hydrants on the sidewalks
	local props = Random.new(1985)
	for z = -210, 210, 70 do
		local side = props:NextNumber() < 0.5 and -1 or 1
		newPart({ Name = "Mailbox", Size = Vector3.new(1.6, 2.6, 1.6), Position = Vector3.new(side * 21, 1.8, z + 12),
			Color = Color3.fromRGB(40, 70, 140), Material = Enum.Material.Metal, Parent = d })
		newPart({ Name = "Hydrant", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 0.9, 0.9),
			CFrame = CFrame.new(-side * 21, 1.5, z - 18) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(200, 40, 40), Material = Enum.Material.Metal, Parent = d })
	end

	-- parked 80s cars along the curbs
	local CAR_COLORS = { Color3.fromRGB(150, 40, 40), Color3.fromRGB(210, 190, 140), Color3.fromRGB(60, 90, 130), Color3.fromRGB(90, 120, 80), Color3.fromRGB(220, 220, 215) }
	for i, z in ipairs({ -170, -95, -40, 30, 100, 140 }) do
		local side = (i % 2 == 0) and 1 or -1
		local base = Vector3.new(side * 12.3, 0, z)
		local color = CAR_COLORS[(i - 1) % #CAR_COLORS + 1]
		newPart({ Name = "ParkedCar", Size = Vector3.new(5.6, 2, 11), Position = base + Vector3.new(0, 1.6, 0), Color = color,
			Material = Enum.Material.SmoothPlastic, Parent = d })
		newPart({ Name = "ParkedCarTop", Size = Vector3.new(4.8, 1.6, 5.5), Position = base + Vector3.new(0, 3.4, 0.6), Color = color,
			Material = Enum.Material.SmoothPlastic, Parent = d })
		newPart({ Name = "ParkedCarGlass", Size = Vector3.new(4.9, 1.2, 5.6), Position = base + Vector3.new(0, 3.5, 0.6),
			Color = Color3.fromRGB(40, 50, 60), Material = Enum.Material.Glass, Transparency = 0.3, Parent = d })
		for _, wz in ipairs({ -3.6, 3.6 }) do
			for _, wx in ipairs({ -2.8, 2.8 }) do
				newPart({ Name = "ParkedCarWheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 2, 2),
					Position = base + Vector3.new(wx, 1, wz), Color = Color3.fromRGB(20, 20, 22), Material = Enum.Material.SmoothPlastic, Parent = d })
			end
		end
	end

	-- lit shop signs and awnings on the buildings facing Main Street (original names)
	local SIGNS = {
		{ "DINER", Color3.fromRGB(255, 90, 160) }, { "ARCADE", Color3.fromRGB(80, 220, 255) }, { "VIDEO", Color3.fromRGB(255, 214, 140) },
		{ "RECORDS", Color3.fromRGB(190, 120, 255) }, { "PIZZA", Color3.fromRGB(255, 120, 60) }, { "HARDWARE", Color3.fromRGB(120, 255, 160) },
		{ "BOWLING", Color3.fromRGB(255, 60, 70) }, { "LAUNDRY", Color3.fromRGB(150, 210, 255) }, { "BOOKS", Color3.fromRGB(255, 214, 140) },
		{ "MOTEL", Color3.fromRGB(255, 90, 160) },
	}
	for _, b in ipairs(town:GetChildren()) do
		if b.Name == "Building" then
			local side = b.Position.X > 0 and 1 or -1
			local front = b.Position.X - side * (b.Size.X / 2) -- the wall that faces the road
			local z = b.Position.Z
			local sign = SIGNS[(math.floor((z + 200) / 90) * 2 + (side > 0 and 1 or 0)) % #SIGNS + 1]
			local board = newPart({ Name = "ShopSign", Size = Vector3.new(0.6, 3, 14), Position = Vector3.new(front - side * 0.5, 10, z),
				Color = Color3.fromRGB(25, 22, 30), Material = Enum.Material.SmoothPlastic, Parent = d })
			local gui = Instance.new("SurfaceGui")
			gui.Face = side > 0 and Enum.NormalId.Left or Enum.NormalId.Right
			gui.LightInfluence = 0
			gui.Brightness = 2.5
			gui.Parent = board
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.Arcade
			text.TextScaled = true
			text.Text = sign[1]
			text.TextColor3 = sign[2]
			text.Parent = gui
			local glow = Instance.new("PointLight")
			glow.Color = sign[2]
			glow.Range = 16
			glow.Brightness = 1.2
			glow.Parent = board
			newPart({ Name = "Awning", Size = Vector3.new(4, 0.3, 18), CFrame = CFrame.new(front - side * 2, 6.8, z) * CFrame.Angles(0, 0, side * 0.25),
				Color = sign[2]:Lerp(Color3.new(0, 0, 0), 0.45), Material = Enum.Material.Fabric, Parent = d })
		end
	end

	-- puddles on the road that reflect the neon
	for _, p in ipairs({ Vector3.new(-6, 0, -150), Vector3.new(5, 0, -60), Vector3.new(-3, 0, 45), Vector3.new(7, 0, 130), Vector3.new(-8, 0, 185) }) do
		newPart({ Name = "Puddle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 7, 10),
			CFrame = CFrame.new(p + Vector3.new(0, 0.24, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(20, 24, 32),
			Material = Enum.Material.Glass, Reflectance = 0.35, Transparency = 0.2, CanCollide = false, CanQuery = false, Parent = d })
	end

	-- the flat Ground part stays for raycasts, but terrain grass is what you see
	local ground = town:FindFirstChild("Ground")
	if ground then
		ground.Transparency = 1
	end
	d.Parent = town
end
decorateTown(town)

---------------------------------------------------------------------------
-- The Hollow Creek Grand Hotel: 5 floors + roof, east of Main Street. Built
-- into the town model, so the Undergrid gets a dark copy of it too.
--   footprint x -56..56, z -40..40 (the entrance faces town on the west)
--   ATRIUM x -26..26, z -12..12: open from the lobby to a glass roof
--   floor 1: a wide open LOBBY (reception, sofas, plants) around the ballroom
--   floors 2-5: wide balconies around the atrium; 12 guest rooms with closed doors
--     (E to open) along the north and south sides
--   every floor: two big common washrooms (WOMEN / MEN) in the north corners
--   each wing (x beyond ±26) has an ELEVATOR against the outside wall (walk up to it:
--   "Use elevator") and one wing has the wide GRAND STAIRS up to the next floor
--     (they zig-zag: east wing from odd floors, west wing from even floors)
-- Parts named HotelLight / HotelRoomLamp / HotelWindow / HotelFlicker / HotelEmergency /
-- HotelHive are switched per chapter by setHotelTheme. Inside walls don't stop shots.
---------------------------------------------------------------------------
local HOTEL_CENTER = Vector3.new(165, 0, -160)
local HOTEL_FLOOR_H = 14
local HOTEL_FLOORS = 5
local HOTEL_HALF = Vector2.new(56, 40) -- half size (x, z)
local HOTEL_ROOMS = { -- guest room centres (local x, z) on floors 2-5
	Vector2.new(-32, -32), Vector2.new(-16, -32), Vector2.new(0, -32), Vector2.new(16, -32), Vector2.new(32, -32),
	Vector2.new(-48, 32), Vector2.new(-32, 32), Vector2.new(-16, 32), Vector2.new(0, 32), Vector2.new(16, 32), Vector2.new(32, 32), Vector2.new(48, 32),
}

local function hotelFloorY(floor) -- floor 1 = lobby, 6 = roof
	return (floor - 1) * HOTEL_FLOOR_H
end

-- a point on a hotel floor; undergrid = the dark copy
local function hotelSpot(floor, xz, undergrid)
	return HOTEL_CENTER + Vector3.new(xz.X, hotelFloorY(floor), xz.Y) + (undergrid and CONFIG.UNDERGRID_OFFSET or Vector3.zero)
end

-- the grand stairs from floor f go up in the east wing for odd floors, the west wing for even ones
local function rampSide(floor)
	return floor % 2 == 1 and 1 or -1
end

local function buildHotel(town)
	local hotel = Instance.new("Model")
	hotel.Name = "GrandHotel"
	local c = HOTEL_CENTER
	local BRICK = Color3.fromRGB(120, 60, 50)
	local WALLPAPER = Color3.fromRGB(196, 176, 140)
	local WARM = Color3.fromRGB(255, 214, 160)
	local TILE = Color3.fromRGB(225, 228, 230)
	local WOOD = Color3.fromRGB(110, 70, 40)
	local DARKWOOD = Color3.fromRGB(70, 44, 30)
	local LINEN = Color3.fromRGB(240, 236, 226)
	local BURGUNDY = Color3.fromRGB(110, 30, 40)
	local BRASS = Color3.fromRGB(220, 180, 60)

	local function box(name, size, pos, props)
		props = props or {}
		props.Name = name
		props.Size = size
		props.Position = c + pos
		props.Color = props.Color or WALLPAPER
		props.Parent = hotel
		return newPart(props)
	end
	local function light(p, color, range, brightness, enabled)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = brightness
		l.Enabled = enabled ~= false
		l.Parent = p
		return l
	end
	local function sign(p, face, text, color)
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.Parent = p
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Arcade
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = color
		l.Parent = gui
	end
	-- a wall with openings { {centre, width}, ... }; openings are 8 high with a lintel above.
	-- Hotel walls let shots through (CanQuery off): Hollowers come through walls, so can you.
	local function wall(alongX, fixed, from, to, y, h, gaps, color, material)
		local cuts = {}
		for _, g in ipairs(gaps or {}) do
			table.insert(cuts, { g[1] - g[2] / 2, g[1] + g[2] / 2 })
		end
		table.sort(cuts, function(a, b)
			return a[1] < b[1]
		end)
		local function piece(a, b, y0, height)
			if b - a < 0.05 or height <= 0 then
				return
			end
			local mid = (a + b) / 2
			local size = alongX and Vector3.new(b - a, height, 1) or Vector3.new(1, height, b - a)
			local pos = alongX and Vector3.new(mid, y0 + height / 2, fixed) or Vector3.new(fixed, y0 + height / 2, mid)
			box("HotelWall", size, pos, { Color = color, Material = material, CanQuery = false })
		end
		local x = from
		for _, cut in ipairs(cuts) do
			piece(x, cut[1], y, h)
			piece(cut[1], cut[2], y + 8, h - 8)
			x = cut[2]
		end
		piece(x, to, y, h)
	end
	local function slab(x1, x2, z1, z2, y, color, material)
		box("HotelFloor", Vector3.new(x2 - x1, 1, z2 - z1), Vector3.new((x1 + x2) / 2, y - 0.5, (z1 + z2) / 2), { Color = color, Material = material })
	end
	-- floors 2-6: everything except the atrium and the hole the grand stairs from below come up through
	local function upperFloor(floor, color, material)
		local y = hotelFloorY(floor)
		slab(-56, 56, -40, -12, y, color, material)
		slab(-56, 56, 12, 40, y, color, material)
		local hole = rampSide(floor - 1)
		for _, side in ipairs({ -1, 1 }) do
			local inner, outer = side * 26, side * 56
			local x1, x2 = math.min(inner, outer), math.max(inner, outer)
			if side == hole then
				-- the stairs hole: x ±29..41, z -4..12 (the stairs land on the balcony at z 12..20)
				local h1, h2 = math.min(side * 29, side * 41), math.max(side * 29, side * 41)
				slab(x1, h1, -12, 12, y, color, material)
				slab(h2, x2, -12, 12, y, color, material)
				slab(h1, h2, -12, -4, y, color, material)
			else
				slab(x1, x2, -12, 12, y, color, material)
			end
		end
	end
	local function plant(pos)
		box("HotelPlantPot", Vector3.new(2, 2, 2), pos + Vector3.new(0, 1, 0), { Color = Color3.fromRGB(150, 90, 60), Material = Enum.Material.Slate })
		local leaves = box("HotelPlant", Vector3.new(3.4, 3.4, 3.4), pos + Vector3.new(0, 3.6, 0), { Color = Color3.fromRGB(50, 110, 50), Material = Enum.Material.Grass })
		leaves.Shape = Enum.PartType.Ball
	end
	local function sofa(pos, facing)
		-- facing: +1 = faces +z, -1 = faces -z
		box("HotelSofa", Vector3.new(8, 1.6, 3), pos + Vector3.new(0, 0.8, 0), { Color = BURGUNDY, Material = Enum.Material.Fabric })
		box("HotelSofa", Vector3.new(8, 2.4, 0.8), pos + Vector3.new(0, 2, -facing * 1.3), { Color = BURGUNDY, Material = Enum.Material.Fabric })
		for _, x in ipairs({ -4, 4 }) do
			box("HotelSofa", Vector3.new(0.8, 2.2, 3), pos + Vector3.new(x, 1.1, 0), { Color = BURGUNDY, Material = Enum.Material.Fabric })
		end
	end

	-- a big common washroom: front = the side with the open doorway, back = the outside wall
	local function washroom(xMin, xMax, zFront, zBack, y, label)
		local cx = (xMin + xMax) / 2
		local back = zBack > zFront and 1 or -1
		box("HotelTiles", Vector3.new(xMax - xMin - 1, 0.1, math.abs(zBack - zFront) - 1), Vector3.new(cx, y + 0.05, (zFront + zBack) / 2),
			{ Color = TILE, Material = Enum.Material.Marble })
		-- four stalls along the back wall (the last one wider, accessible, with a rail)
		for i = 0, 3 do
			local sx = xMin + 2 + i * 3.4
			box("HotelToilet", Vector3.new(1.4, 1.6, 2), Vector3.new(sx + 0.2, y + 0.8, zBack - back * 1.4), { Color = Color3.new(1, 1, 1) })
			box("HotelStall", Vector3.new(0.2, 6, 4.4), Vector3.new(sx + 1.7, y + 3.5, zBack - back * 2.4), { Color = Color3.fromRGB(120, 140, 160) })
			local door = box("HotelStallDoor", Vector3.new(2.8, 5, 0.2), Vector3.new(sx, y + 3.5, zBack - back * 4.7), { Color = Color3.fromRGB(120, 140, 160) })
			door.CFrame = door.CFrame * CFrame.Angles(0, 0.5, 0)
		end
		box("HotelRail", Vector3.new(0.2, 0.2, 3), Vector3.new(xMax - 0.7, y + 3, zBack - back * 2), { Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Metal })
		-- a long counter with three sinks and a mirror wall
		box("HotelCounter", Vector3.new(1.6, 0.4, 11), Vector3.new(xMax - 1.3, y + 3, zFront + back * 7), { Color = Color3.fromRGB(60, 60, 64), Material = Enum.Material.Marble })
		for _, dz in ipairs({ 3.5, 7, 10.5 }) do
			box("HotelSink", Vector3.new(1.2, 0.3, 1.6), Vector3.new(xMax - 1.3, y + 3.3, zFront + back * dz), { Color = Color3.new(1, 1, 1) })
		end
		box("HotelMirror", Vector3.new(0.2, 3.6, 11), Vector3.new(xMax - 0.6, y + 6.2, zFront + back * 7), { Color = Color3.fromRGB(180, 200, 210),
			Material = Enum.Material.Glass, Reflectance = 0.6, Transparency = 0.1 })
		box("HotelDryer", Vector3.new(0.8, 1, 1.2), Vector3.new(xMin + 0.9, y + 4.5, zFront + back * 3), { Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Metal })
		for _, dz in ipairs({ 5, 11 }) do
			local flicker = box("HotelFlicker", Vector3.new(3, 0.2, 3), Vector3.new(cx, y + 13.3, zFront + back * dz), { Color = WARM, Material = Enum.Material.Neon })
			light(flicker, WARM, 18, 1)
		end
		local plate = box("HotelSign", Vector3.new(6, 1.2, 0.2), Vector3.new(cx, y + 9.5, zFront - back * 0.6), { Color = Color3.fromRGB(30, 30, 40) })
		sign(plate, back < 0 and Enum.NormalId.Back or Enum.NormalId.Front, label, Color3.new(1, 1, 1))
	end

	-- a standard hotel room behind a closed door (16 x 16)
	local function guestRoom(room, y, number)
		local north = room.Y < 0
		local back = north and -1 or 1           -- towards the outside wall
		local doorZ = north and -24 or 24
		local bz = room.Y + back * 4.5           -- the bed's head is at the outside wall
		box("HotelRoomCarpet", Vector3.new(15, 0.1, 15), Vector3.new(room.X, y + 0.05, room.Y), { Color = Color3.fromRGB(90, 70, 60), Material = Enum.Material.Fabric })
		-- bed: frame, mattress, duvet, two pillows, headboard
		box("HotelBed", Vector3.new(6, 1, 7.5), Vector3.new(room.X, y + 0.5, bz - back * 0.5), { Color = DARKWOOD, Material = Enum.Material.Wood })
		box("HotelMattress", Vector3.new(5.8, 0.8, 7.2), Vector3.new(room.X, y + 1.4, bz - back * 0.5), { Color = LINEN, Material = Enum.Material.Fabric })
		box("HotelDuvet", Vector3.new(6, 0.35, 4.6), Vector3.new(room.X, y + 1.95, bz - back * 1.8), { Color = BURGUNDY, Material = Enum.Material.Fabric })
		for _, dx in ipairs({ -1.4, 1.4 }) do
			box("HotelPillow", Vector3.new(2.4, 0.6, 1.2), Vector3.new(room.X + dx, y + 2.1, bz + back * 2.4), { Color = Color3.new(1, 1, 1), Material = Enum.Material.Fabric })
		end
		box("HotelHeadboard", Vector3.new(6.6, 4, 0.5), Vector3.new(room.X, y + 2, bz + back * 3.3), { Color = DARKWOOD, Material = Enum.Material.Wood })
		-- nightstands with lamps
		for _, dx in ipairs({ -4.4, 4.4 }) do
			box("HotelNightstand", Vector3.new(1.8, 2, 1.8), Vector3.new(room.X + dx, y + 1, bz + back * 2.4), { Color = WOOD, Material = Enum.Material.Wood })
			local lamp = box("HotelRoomLamp", Vector3.new(1, 1, 1), Vector3.new(room.X + dx, y + 2.9, bz + back * 2.4), { Color = WARM, Material = Enum.Material.Neon })
			light(lamp, WARM, 12, 0.8)
		end
		-- desk with a chair, dresser with a TV, wardrobe, armchair, luggage rack, painting
		box("HotelDesk", Vector3.new(4, 0.3, 2), Vector3.new(room.X - 5, y + 2.6, room.Y - back * 2), { Color = WOOD, Material = Enum.Material.Wood })
		box("HotelDeskLegs", Vector3.new(3.8, 2.5, 1.8), Vector3.new(room.X - 5, y + 1.25, room.Y - back * 2), { Color = DARKWOOD, Material = Enum.Material.Wood, Transparency = 0.5 })
		box("HotelChair", Vector3.new(1.6, 1.6, 1.6), Vector3.new(room.X - 5, y + 0.8, room.Y - back * 0.5), { Color = BURGUNDY, Material = Enum.Material.Fabric })
		box("HotelDresser", Vector3.new(4, 2.6, 1.6), Vector3.new(room.X + 5, y + 1.3, room.Y - back * 2), { Color = WOOD, Material = Enum.Material.Wood })
		box("HotelTV", Vector3.new(2.6, 2, 1.4), Vector3.new(room.X + 5, y + 3.6, room.Y - back * 2), { Color = Color3.fromRGB(40, 36, 34), Material = Enum.Material.SmoothPlastic })
		box("HotelWardrobe", Vector3.new(3.4, 7, 1.8), Vector3.new(room.X - 6, y + 3.5, room.Y - back * 5.6), { Color = DARKWOOD, Material = Enum.Material.Wood })
		box("HotelArmchair", Vector3.new(2.4, 1.8, 2.4), Vector3.new(room.X + 5.5, y + 0.9, bz), { Color = Color3.fromRGB(150, 120, 80), Material = Enum.Material.Fabric })
		box("HotelLuggageRack", Vector3.new(2.6, 1.4, 1.4), Vector3.new(room.X + 5.5, y + 0.7, room.Y - back * 5.4), { Color = BRASS, Material = Enum.Material.Metal })
		box("HotelPainting", Vector3.new(4, 2.6, 0.2), Vector3.new(room.X, y + 6.5, room.Y + back * 7.4), { Color = Color3.fromRGB(90, 120, 150) })
		box("HotelCurtain", Vector3.new(3, 7, 0.3), Vector3.new(room.X - 5.8, y + 5, room.Y + back * 7.3), { Color = BURGUNDY, Material = Enum.Material.Fabric })
		local ceiling = box("HotelLight", Vector3.new(2, 0.2, 2), Vector3.new(room.X, y + 13.3, room.Y), { Color = WARM, Material = Enum.Material.Neon })
		light(ceiling, WARM, 16, 0.9)

		-- the door: closed; "Open door" (E) swings it open for a while
		local door = box("HotelDoor", Vector3.new(4, 8, 0.4), Vector3.new(room.X, y + 4, doorZ), { Color = DARKWOOD, Material = Enum.Material.Wood, CanQuery = false })
		local knob = box("HotelDoorKnob", Vector3.new(0.4, 0.4, 0.6), Vector3.new(room.X + 1.4, y + 4, doorZ), { Color = BRASS, Material = Enum.Material.Metal, CanCollide = false })
		local knobWeld = Instance.new("WeldConstraint")
		knobWeld.Part0 = door
		knobWeld.Part1 = knob
		knobWeld.Parent = knob
		knob.Anchored = false
		knob.Massless = true
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "HotelDoorPrompt"
		prompt.ActionText = "Open door"
		prompt.ObjectText = "Room " .. number
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = door
		local plate = box("HotelSign", Vector3.new(2, 0.9, 0.2), Vector3.new(room.X, y + 9, doorZ - back * 0.6), { Color = Color3.fromRGB(60, 40, 30) })
		sign(plate, north and Enum.NormalId.Back or Enum.NormalId.Front, tostring(number), BRASS)
	end

	for f = 1, HOTEL_FLOORS do
		local y = hotelFloorY(f)
		if f == 1 then
			box("HotelFloor", Vector3.new(112, 0.4, 80), Vector3.new(0, 0, 0), { Color = Color3.fromRGB(230, 222, 205), Material = Enum.Material.Marble })
		else
			upperFloor(f, Color3.fromRGB(120, 100, 80), Enum.Material.Wood)
			-- carpet runners and glass railings around the atrium
			for _, z in ipairs({ -18, 18 }) do
				box("HotelCarpet", Vector3.new(104, 0.1, 7), Vector3.new(0, y + 0.05, z), { Color = BURGUNDY, Material = Enum.Material.Fabric })
			end
			for _, z in ipairs({ -12, 12 }) do
				box("HotelRailing", Vector3.new(52, 3.5, 0.3), Vector3.new(0, y + 1.75, z), { Color = Color3.fromRGB(180, 210, 230), Material = Enum.Material.Glass, Transparency = 0.6 })
				box("HotelRailingTop", Vector3.new(52, 0.3, 0.6), Vector3.new(0, y + 3.6, z), { Color = BRASS, Material = Enum.Material.Metal })
			end
			for _, x in ipairs({ -26, 26 }) do
				box("HotelRailing", Vector3.new(0.3, 3.5, 24), Vector3.new(x, y + 1.75, 0), { Color = Color3.fromRGB(180, 210, 230), Material = Enum.Material.Glass, Transparency = 0.6 })
				box("HotelRailingTop", Vector3.new(0.6, 0.3, 24), Vector3.new(x, y + 3.6, 0), { Color = BRASS, Material = Enum.Material.Metal })
			end
			for _, p in ipairs({ Vector3.new(-50, y, 18), Vector3.new(50, y, 18), Vector3.new(-20, y, 21), Vector3.new(20, y, 21) }) do
				plant(p)
			end
		end

		-- outside walls (big entrance on the west side of floor 1) with lit windows
		wall(true, -40, -56, 56, y, HOTEL_FLOOR_H, nil, BRICK, Enum.Material.Brick)
		wall(true, 40, -56, 56, y, HOTEL_FLOOR_H, nil, BRICK, Enum.Material.Brick)
		wall(false, 56, -40, 40, y, HOTEL_FLOOR_H, nil, BRICK, Enum.Material.Brick)
		wall(false, -56, -40, 40, y, HOTEL_FLOOR_H, f == 1 and { { 0, 16 } } or nil, BRICK, Enum.Material.Brick)
		for _, x in ipairs({ -48, -32, -16, 0, 16, 32, 48 }) do
			box("HotelWindow", Vector3.new(5, 4.5, 0.3), Vector3.new(x, y + 7.5, 40.7), { Color = WARM, Material = Enum.Material.Neon })
			box("HotelWindow", Vector3.new(5, 4.5, 0.3), Vector3.new(x, y + 7.5, -40.7), { Color = WARM, Material = Enum.Material.Neon })
		end
		for _, z in ipairs({ -30, -20, 20, 30 }) do
			box("HotelWindow", Vector3.new(0.3, 4.5, 5), Vector3.new(56.7, y + 7.5, z), { Color = WARM, Material = Enum.Material.Neon })
			box("HotelWindow", Vector3.new(0.3, 4.5, 5), Vector3.new(-56.7, y + 7.5, z), { Color = WARM, Material = Enum.Material.Neon })
		end

		-- two big common washrooms in the north corners (open doorways)
		wall(true, -24, -56, -40, y, HOTEL_FLOOR_H, { { -48, 5 } })
		wall(false, -40, -40, -24, y, HOTEL_FLOOR_H)
		washroom(-56, -40, -24, -40, y, "WOMEN")
		wall(true, -24, 40, 56, y, HOTEL_FLOOR_H, { { 48, 5 } })
		wall(false, 40, -40, -24, y, HOTEL_FLOOR_H)
		washroom(40, 56, -24, -40, y, "MEN")

		if f == 1 then
			-- the lobby: reception desk with a key wall, sofas, rugs, plants; the ballroom in the atrium
			-- reception in the south-west corner, out of the way of the front doors
			box("HotelReception", Vector3.new(16, 3.6, 3.5), Vector3.new(-44, 1.8, 28), { Color = DARKWOOD, Material = Enum.Material.Wood })
			box("HotelReceptionTop", Vector3.new(16.4, 0.3, 4), Vector3.new(-44, 3.75, 28), { Color = Color3.fromRGB(40, 30, 26), Material = Enum.Material.Marble })
			local bell = box("HotelBell", Vector3.new(0.6, 0.6, 0.6), Vector3.new(-40, 4.2, 28), { Color = BRASS, Material = Enum.Material.Metal })
			bell.Shape = Enum.PartType.Ball
			box("HotelKeyWall", Vector3.new(14, 6, 0.4), Vector3.new(-44, 6, 38.6), { Color = DARKWOOD, Material = Enum.Material.Wood })
			for row = 0, 3 do
				for col = 0, 6 do
					box("HotelKey", Vector3.new(0.4, 0.4, 0.3), Vector3.new(-49.5 + col * 1.8, 4.2 + row * 1.2, 38.3), { Color = BRASS, Material = Enum.Material.Metal, CanCollide = false })
				end
			end
			local reception = box("HotelSign", Vector3.new(10, 1.6, 0.3), Vector3.new(-44, 10, 38.3), { Color = Color3.fromRGB(30, 30, 40) })
			sign(reception, Enum.NormalId.Front, "RECEPTION", BRASS)
			for _, p in ipairs({ Vector3.new(-14, 0, -30), Vector3.new(14, 0, -30), Vector3.new(-30, 0, 30), Vector3.new(0, 0, 30), Vector3.new(30, 0, 30) }) do
				box("HotelRug", Vector3.new(14, 0.1, 10), p + Vector3.new(0, 0.25, 0), { Color = BURGUNDY, Material = Enum.Material.Fabric })
				sofa(p + Vector3.new(0, 0.2, p.Z > 0 and 3.5 or -3.5), p.Z > 0 and -1 or 1)
				box("HotelCoffeeTable", Vector3.new(4, 1.2, 2), p + Vector3.new(0, 0.8, 0), { Color = WOOD, Material = Enum.Material.Wood })
			end
			for _, p in ipairs({ Vector3.new(-52, 0, 14), Vector3.new(-52, 0, -14), Vector3.new(-24, 0, -36), Vector3.new(24, 0, -36), Vector3.new(-28, 0, 37), Vector3.new(50, 0, 36) }) do
				plant(p)
			end
			for i = 0, 7 do
				for j = 0, 5 do
					box("HotelDanceFloor", Vector3.new(3, 0.1, 3), Vector3.new(-10.5 + i * 3, 0.25, -7.5 + j * 3),
						{ Color = (i + j) % 2 == 0 and Color3.fromRGB(30, 30, 34) or Color3.fromRGB(230, 222, 205), Material = Enum.Material.Marble })
				end
			end
			box("HotelStage", Vector3.new(24, 1.5, 6), Vector3.new(0, 0.75, 16), { Color = BURGUNDY, Material = Enum.Material.Fabric })
			for _, x in ipairs({ -40, -20, 0, 20, 40 }) do
				for _, z in ipairs({ -30, 30 }) do
					local panel = box("HotelLight", Vector3.new(4, 0.2, 4), Vector3.new(x, 13.3, z), { Color = WARM, Material = Enum.Material.Neon })
					light(panel, WARM, 28, 1.1)
				end
			end
		else
			-- guest rooms along the north (between the washrooms) and the south side
			local northDoors, southDoors = {}, {}
			for _, room in ipairs(HOTEL_ROOMS) do
				table.insert(room.Y < 0 and northDoors or southDoors, { room.X, 4 })
			end
			wall(true, -24, -40, 40, y, HOTEL_FLOOR_H, northDoors, WALLPAPER)
			wall(true, 24, -56, 56, y, HOTEL_FLOOR_H, southDoors, WALLPAPER)
			for _, x in ipairs({ -24, -8, 8, 24 }) do
				wall(false, x, -40, -24, y, HOTEL_FLOOR_H)
			end
			for _, x in ipairs({ -40, -24, -8, 8, 24, 40 }) do
				wall(false, x, 24, 40, y, HOTEL_FLOOR_H)
			end
			for i, room in ipairs(HOTEL_ROOMS) do
				guestRoom(room, y, f * 100 + i)
			end
			-- wall lights between the room doors
			for _, z in ipairs({ -23.4, 23.4 }) do
				for _, x in ipairs({ -40, -24, -8, 8, 24, 40 }) do
					local sconce = box("HotelLight", Vector3.new(0.8, 1, 0.3), Vector3.new(x, y + 7, z), { Color = WARM, Material = Enum.Material.Neon, CanCollide = false })
					light(sconce, WARM, 14, 0.8)
				end
			end
		end

		-- balcony / lobby lights in the wings, red emergency lights, Hive growth
		for _, x in ipairs({ -42, 42 }) do
			for _, z in ipairs({ -16, 0, 16 }) do
				local panel = box("HotelLight", Vector3.new(3, 0.2, 3), Vector3.new(x, y + 13.3, z), { Color = WARM, Material = Enum.Material.Neon })
				light(panel, WARM, 26, 1.1)
			end
		end
		for _, x in ipairs({ -36, 0, 36 }) do
			local red = box("HotelEmergency", Vector3.new(0.8, 0.5, 0.5), Vector3.new(x, y + 12.5, -23.2), { Color = Color3.fromRGB(255, 40, 40),
				Material = Enum.Material.Neon, Transparency = 1 })
			light(red, Color3.fromRGB(255, 40, 40), 28, 1.4, false)
		end
		local hive = Random.new(f * 31)
		for _ = 1, 12 do
			local p = Vector3.new(hive:NextNumber(-52, 52), y + hive:NextNumber(0.3, 12), hive:NextNumber(-22, -13) * (hive:NextNumber() < 0.5 and 1 or -1))
			local tendril = box("HotelHive", Vector3.new(0.8, 0.8, hive:NextNumber(8, 16)), p, { Color = Color3.fromRGB(70, 14, 22),
				CanCollide = false, CanQuery = false, Transparency = 1 })
			tendril.CFrame = CFrame.new(c + p) * CFrame.Angles(hive:NextNumber(-1, 1), hive:NextNumber(0, 3), hive:NextNumber(-1, 1))
		end

		-- an elevator in each wing, against the outside wall: walk up to it -> "Use elevator"
		for _, side in ipairs({ -1, 1 }) do
			local x = side * 52
			-- cab x ±48..56, z -21..-11 (north of the front doors)
			wall(true, -21.5, side > 0 and 48 or -56, side > 0 and 56 or -48, y, HOTEL_FLOOR_H, nil, Color3.fromRGB(150, 130, 90), Enum.Material.Metal)
			wall(true, -10.5, side > 0 and 48 or -56, side > 0 and 56 or -48, y, HOTEL_FLOOR_H, nil, Color3.fromRGB(150, 130, 90), Enum.Material.Metal)
			box("HotelElevatorFloor", Vector3.new(8, 0.2, 10), Vector3.new(x, y + 0.1, -16), { Color = Color3.fromRGB(150, 130, 90), Material = Enum.Material.Metal })
			local frame = box("HotelSign", Vector3.new(0.4, 1.6, 10), Vector3.new(side * 47.8, y + 9, -16), { Color = Color3.fromRGB(30, 30, 40) })
			sign(frame, side > 0 and Enum.NormalId.Left or Enum.NormalId.Right, "ELEVATOR", Color3.fromRGB(60, 255, 140))
			local panel = box("HotelElevatorPanel", Vector3.new(0.4, 2, 1.2), Vector3.new(side * 47.8, y + 4, -9.4), { Color = Color3.fromRGB(60, 255, 140), Material = Enum.Material.Neon })
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "HotelElevator"
			prompt.ActionText = "Use elevator"
			prompt.ObjectText = "Elevator - floor " .. f
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 14
			prompt.RequiresLineOfSight = false
			prompt:SetAttribute("Floor", f)
			prompt:SetAttribute("Side", side)
			prompt.Parent = panel
		end

		-- the grand stairs: 10 wide, up to the next floor (or the roof), with a sign
		local side = rampSide(f)
		local a, b = c + Vector3.new(side * 35, y, -20), c + Vector3.new(side * 35, y + HOTEL_FLOOR_H, 12)
		newPart({ Name = "HotelStairs", Size = Vector3.new(10, 1, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = BURGUNDY, Material = Enum.Material.Fabric, Parent = hotel })
		for _, dx in ipairs({ -5.2, 5.2 }) do
			local ra, rb = a + Vector3.new(dx, 3, 0), b + Vector3.new(dx, 3, 0)
			newPart({ Name = "HotelStairRail", Size = Vector3.new(0.4, 0.4, (rb - ra).Magnitude), CFrame = CFrame.lookAt((ra + rb) / 2, rb),
				Color = BRASS, Material = Enum.Material.Metal, CanCollide = false, Parent = hotel })
		end
		local stairSign = box("HotelSign", Vector3.new(10, 1.6, 0.3), Vector3.new(side * 35, y + 6, -22.6), { Color = Color3.fromRGB(30, 30, 40) })
		sign(stairSign, Enum.NormalId.Back, f < HOTEL_FLOORS and ("STAIRS TO FLOOR " .. (f + 1) .. " ▲") or "STAIRS TO ROOF ▲", WARM)
	end

	-- the roof: glass skylight over the atrium and a big chandelier hanging down through it
	local roofY = hotelFloorY(HOTEL_FLOORS + 1)
	upperFloor(HOTEL_FLOORS + 1, Color3.fromRGB(70, 70, 74), Enum.Material.Concrete)
	box("HotelSkylight", Vector3.new(52, 0.4, 24), Vector3.new(0, roofY - 0.2, 0), { Color = Color3.fromRGB(160, 190, 220), Material = Enum.Material.Glass, Transparency = 0.55 })
	box("HotelChain", Vector3.new(0.4, 20, 0.4), Vector3.new(0, roofY - 10.4, 0), { Color = BRASS, Material = Enum.Material.Metal, CanCollide = false })
	local chandelier = box("HotelLight", Vector3.new(6, 3, 6), Vector3.new(0, roofY - 22, 0), { Color = WARM, Material = Enum.Material.Neon, CanCollide = false })
	chandelier.Shape = Enum.PartType.Ball
	light(chandelier, WARM, 70, 1.6)
	wall(true, -40, -56, 56, roofY, 3, nil, BRICK, Enum.Material.Brick)
	wall(true, 40, -56, 56, roofY, 3, nil, BRICK, Enum.Material.Brick)
	wall(false, 56, -40, 40, roofY, 3, nil, BRICK, Enum.Material.Brick)
	wall(false, -56, -40, 40, roofY, 3, nil, BRICK, Enum.Material.Brick)
	local tank = box("HotelWaterTower", Vector3.new(8, 8, 8), Vector3.new(-30, roofY + 9, 30), { Color = Color3.fromRGB(110, 80, 60), Material = Enum.Material.Wood })
	tank.Shape = Enum.PartType.Cylinder
	tank.CFrame = CFrame.new(tank.Position) * CFrame.Angles(0, 0, math.rad(90))
	for _, o in ipairs({ Vector2.new(-3, -3), Vector2.new(3, -3), Vector2.new(-3, 3), Vector2.new(3, 3) }) do
		box("HotelWaterTowerLeg", Vector3.new(0.6, 5, 0.6), Vector3.new(-30 + o.X, roofY + 2.5, 30 + o.Y), { Color = Color3.fromRGB(60, 60, 64), Material = Enum.Material.Metal })
	end
	local board = box("HotelBigSign", Vector3.new(0.6, 8, 52), Vector3.new(-56.2, roofY + 7, 0), { Color = Color3.fromRGB(25, 22, 30) })
	sign(board, Enum.NormalId.Left, "GRAND HOTEL", Color3.fromRGB(255, 90, 160))
	light(board, Color3.fromRGB(255, 90, 160), 60, 2)

	-- entrance: canopy, brass poles and a red carpet out to the street
	box("HotelCanopy", Vector3.new(10, 0.5, 20), Vector3.new(-61, 9, 0), { Color = BURGUNDY, Material = Enum.Material.Fabric })
	for _, z in ipairs({ -9, 9 }) do
		box("HotelCanopyPole", Vector3.new(0.4, 9, 0.4), Vector3.new(-65.6, 4.5, z), { Color = BRASS, Material = Enum.Material.Metal })
	end
	box("HotelEntranceCarpet", Vector3.new(14, 0.1, 6), Vector3.new(-63, 0.3, 0), { Color = BURGUNDY, Material = Enum.Material.Fabric })

	hotel.Parent = town
end
buildHotel(town)

local undergrid = buildUndergrid(town)

---------------------------------------------------------------------------
-- Terrain: grass with hills around Hollow Creek, dark rock in the Undergrid
---------------------------------------------------------------------------
local function buildTerrain()
	local terrain = workspace.Terrain
	local function world(offset, floor, hill)
		terrain:FillBlock(CFrame.new(offset + Vector3.new(0, -2, 0)), Vector3.new(500, 4, 500), floor)
		local hills = Random.new(offset.Z + 7)
		for angle = 0, math.pi * 2 - 0.01, math.pi / 9 do
			local r = 290 + hills:NextNumber(-10, 25)
			local center = offset + Vector3.new(math.cos(angle) * r, -14, math.sin(angle) * r)
			terrain:FillBall(center, hills:NextNumber(45, 70), hill)
		end
	end
	world(Vector3.zero, Enum.Material.Grass, Enum.Material.Grass)
	world(CONFIG.UNDERGRID_OFFSET, Enum.Material.Ground, Enum.Material.Slate)
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(70, 94, 54))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(28, 26, 34)) -- only used in the Undergrid
	terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(34, 30, 40))
end
buildTerrain()

---------------------------------------------------------------------------
-- Grand Hotel: keep terrain out of it, room doors, the elevators, and its look per chapter
---------------------------------------------------------------------------
for _, offset in ipairs({ Vector3.zero, CONFIG.UNDERGRID_OFFSET }) do
	workspace.Terrain:FillBlock(CFrame.new(HOTEL_CENTER + offset + Vector3.new(0, 45.5, 0)), Vector3.new(HOTEL_HALF.X * 2 + 8, 90, HOTEL_HALF.Y * 2 + 8), Enum.Material.Air)
end

local setHotelTheme -- (chapter) used by startChapter; the rest of this section is inside a do-block (200-locals limit)
do
local hotelThemed = { HotelLight = {}, HotelRoomLamp = {}, HotelWindow = {}, HotelFlicker = {}, HotelEmergency = {}, HotelHive = {} }
local hotelElevatorPrompts = {}
local elevatorRequests = {} -- [player] = { side, world, at } while their floor list is open

-- hotel-local position of a world point (works for both the town hotel and its Undergrid copy)
local function hotelLocal(position)
	local world = position.Z > HOTEL_CENTER.Z + CONFIG.UNDERGRID_OFFSET.Z / 2 and CONFIG.UNDERGRID_OFFSET or Vector3.zero
	return position - HOTEL_CENTER - world, world
end

-- room doors: "Open door" (E) swings the door into the room; it closes again after a while
local function useDoor(door, prompt)
	if door:GetAttribute("Moving") then
		return
	end
	local closed = door:GetAttribute("ClosedCFrame")
	local open = not door:GetAttribute("Open")
	local swing = hotelLocal(door.Position).Z < 0 and 1.5 or -1.5 -- into the room
	local target = open and (closed * CFrame.new(-2, 0, 0) * CFrame.Angles(0, swing, 0) * CFrame.new(2, 0, 0)) or closed
	door:SetAttribute("Moving", true)
	door:SetAttribute("Open", open)
	prompt.ActionText = open and "Close door" or "Open door"
	local tween = TweenService:Create(door, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { CFrame = target })
	tween.Completed:Connect(function()
		door:SetAttribute("Moving", false)
	end)
	tween:Play()
	if open then
		local token = (door:GetAttribute("Token") or 0) + 1
		door:SetAttribute("Token", token)
		task.delay(10, function()
			if door:GetAttribute("Open") and door:GetAttribute("Token") == token then
				useDoor(door, prompt)
			end
		end)
	end
end

-- elevators: "Use elevator" opens a floor list on the player's screen (StartMenu); the
-- choice comes back through ElevatorGo and takes the player to that floor of the same elevator
local function elevatorCab(floor, side, world)
	return HOTEL_CENTER + world + Vector3.new(side * 52, hotelFloorY(floor), -16)
end

ElevatorGoEvent.OnServerEvent:Connect(function(player, target)
	local request = elevatorRequests[player]
	elevatorRequests[player] = nil
	if not request or os.clock() - request.at > 60 or typeof(target) ~= "number" or target % 1 ~= 0
		or target < 1 or target > HOTEL_FLOORS then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	-- still standing at that elevator (on any floor)?
	local cab = elevatorCab(1, request.side, request.world)
	local flat = Vector3.new(hrp.Position.X - cab.X, 0, hrp.Position.Z - cab.Z)
	if flat.Magnitude > 16 then
		return
	end
	local dest = elevatorCab(target, request.side, request.world) + Vector3.new(0, 3.5, 0)
	char:PivotTo(CFrame.new(dest) * char:GetPivot().Rotation)
	sparkBurst(dest, Color3.fromRGB(60, 255, 140), 12, 10, 0.3, 0.4)
	track(player, "elevator", 1)
	NotifyEvent:FireClient(player, target == 1 and "FLOOR 1 - LOBBY" or ("FLOOR " .. target), Color3.fromRGB(255, 214, 140))
end)

Players.PlayerRemoving:Connect(function(player)
	elevatorRequests[player] = nil
end)

for _, model in ipairs({ town:FindFirstChild("GrandHotel"), undergrid:FindFirstChild("GrandHotel") }) do
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and hotelThemed[d.Name] then
			d:SetAttribute("BaseColor", d.Color)
			table.insert(hotelThemed[d.Name], d)
		elseif d:IsA("ProximityPrompt") and d.Name == "HotelElevator" then
			table.insert(hotelElevatorPrompts, d)
			d.Triggered:Connect(function(player)
				local stuck = d:GetAttribute("Stuck")
				if stuck then
					-- Chapter 2 / 3: the prompt stays, so players know there IS an elevator and why it's out
					NotifyEvent:FireClient(player, stuck == "hive" and "ELEVATOR STUCK - HIVE GROWTH IN THE SHAFT. TAKE THE STAIRS"
						or "ELEVATOR HAS NO POWER. TAKE THE STAIRS", Color3.fromRGB(255, 60, 70))
					return
				end
				local _, world = hotelLocal(d.Parent.Position)
				elevatorRequests[player] = { side = d:GetAttribute("Side"), world = world, at = os.clock() }
				ElevatorMenuEvent:FireClient(player, d:GetAttribute("Floor"), HOTEL_FLOORS)
			end)
		elseif d:IsA("ProximityPrompt") and d.Name == "HotelDoorPrompt" then
			local door = d.Parent
			door:SetAttribute("ClosedCFrame", door.CFrame)
			d.Triggered:Connect(function(player)
				local opening = not door:GetAttribute("Open") and not door:GetAttribute("Moving")
				useDoor(door, d)
				if opening then
					trackDoor(player, door)
				end
			end)
		end
	end
end

-- Chapter 1: lights on. Chapter 2: Hive growth, elevators stuck. Chapter 3: power out, red emergency lights.
setHotelTheme = function(chapter)
	local powerOut = chapter == 3
	local function lit(list, on)
		for _, p in ipairs(list) do
			p.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			p.Color = on and p:GetAttribute("BaseColor") or Color3.fromRGB(30, 28, 32)
			local l = p:FindFirstChildOfClass("PointLight")
			if l then
				l.Enabled = on
			end
		end
	end
	local function shown(list, on)
		for _, p in ipairs(list) do
			p.Transparency = on and 0 or 1
			local l = p:FindFirstChildOfClass("PointLight")
			if l then
				l.Enabled = on
			end
		end
	end
	lit(hotelThemed.HotelLight, not powerOut)
	lit(hotelThemed.HotelRoomLamp, not powerOut)
	lit(hotelThemed.HotelWindow, not powerOut)
	lit(hotelThemed.HotelFlicker, not powerOut)
	shown(hotelThemed.HotelEmergency, powerOut)
	shown(hotelThemed.HotelHive, chapter == 2)
	for _, prompt in ipairs(hotelElevatorPrompts) do
		-- stuck in Chapter 2, no power in Chapter 3: the prompt says so, and the panel turns red
		local stuck = (chapter == 2 and "hive") or (chapter == 3 and "power") or nil
		prompt.Enabled = true
		prompt:SetAttribute("Stuck", stuck)
		prompt.ActionText = stuck == "hive" and "Elevator stuck" or stuck == "power" and "No power" or "Use elevator"
		local panel = prompt.Parent
		if panel and panel:IsA("BasePart") then
			panel.Color = stuck and Color3.fromRGB(255, 50, 60) or Color3.fromRGB(60, 255, 140)
			panel:SetAttribute("Flicker", stuck ~= nil) -- the client flickers stuck panels
		end
	end
end
end -- hotel runtime section

-- the client uses these for the FLOOR label, the flashlight and the mirror scare
workspace:SetAttribute("HotelCenter", HOTEL_CENTER)
workspace:SetAttribute("HotelFloorHeight", HOTEL_FLOOR_H)
workspace:SetAttribute("HotelHalfSize", HOTEL_HALF)
workspace:SetAttribute("UndergridOffset", CONFIG.UNDERGRID_OFFSET)
workspace:SetAttribute("HotelScare", hotelSpot(3, Vector2.new(55.4, -31), true) + Vector3.new(0, 5, 0)) -- floor 3 men's mirror

-- Lighting: Future lighting where the script is allowed to set it (otherwise set it once in Studio:
-- Lighting > Technology = Future). The client sets the colours for each world.
do
	local Lighting = game:GetService("Lighting")
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
end

-- Scrap Garage: the shop, next to the town spawn (built after the Undergrid copy so it isn't mirrored)
local function buildGarage()
	local m = Instance.new("Model")
	m.Name = "Garage"
	local base = Vector3.new(-30, 0, 205)
	newPart({ Name = "GarageBody", Size = Vector3.new(16, 11, 20), Position = base + Vector3.new(0, 5.5, 0),
		Color = Color3.fromRGB(70, 60, 80), Material = Enum.Material.Brick, Parent = m })
	newPart({ Name = "GarageDoor", Size = Vector3.new(0.4, 8, 14), Position = base + Vector3.new(8.1, 4, 0),
		Color = Color3.fromRGB(40, 40, 46), Material = Enum.Material.DiamondPlate, Parent = m })
	newPart({ Name = "GarageSign", Size = Vector3.new(0.4, 2, 14), Position = base + Vector3.new(8.2, 9.5, 0),
		Color = Color3.fromRGB(255, 170, 40), Material = Enum.Material.Neon, Parent = m })
	local counter = newPart({ Name = "ShopCounter", Size = Vector3.new(3, 3.5, 6), Position = base + Vector3.new(11, 1.75, 0),
		Color = Color3.fromRGB(255, 214, 140), Material = Enum.Material.Neon, Parent = m })

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 120
	gui.Parent = counter
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Arcade
	label.Text = "SCRAP GARAGE\nWEAPONS + UPGRADES"
	label.TextColor3 = Color3.fromRGB(255, 170, 40)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt" -- StartMenu opens the shop when this is triggered
	prompt.ActionText = "Open shop"
	prompt.ObjectText = "Scrap Garage"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	m.Parent = workspace
end
buildGarage()

local TOWN_RIFT_POS = Vector3.new(110, 9, 0)
local UG_RIFT_POS = TOWN_RIFT_POS + CONFIG.UNDERGRID_OFFSET
local LAB_RIFT_POS = LAB_CENTER + Vector3.new(62, 9, 0) -- a second, smaller rift outside the lab's east door

-- every rift is a pair: one in town and its mirror in the Undergrid. Side = which world it sits in.
local RIFTS = {
	{ town = TOWN_RIFT_POS, name = "" },
	{ town = LAB_RIFT_POS, name = "Lab" },
}
local UG_RIFT_POSITIONS = {}
local crackFolder = Instance.new("Folder")
crackFolder.Name = "RiftCracks"
crackFolder.Parent = workspace
for _, pair in ipairs(RIFTS) do
	makeRift(pair.town, pair.name .. "TownRift"):SetAttribute("Side", "Town")
	makeRift(pair.town + CONFIG.UNDERGRID_OFFSET, pair.name .. "UndergridRift"):SetAttribute("Side", "Undergrid")
	table.insert(UG_RIFT_POSITIONS, pair.town + CONFIG.UNDERGRID_OFFSET)

	-- glowing cracks in the ground around the Undergrid side of each rift (own folder: Rifts holds only rift models)
	local ground = pair.town + CONFIG.UNDERGRID_OFFSET - Vector3.new(0, 9, 0)
	local cracks = Random.new(math.floor(pair.town.X))
	for k = 1, 9 do
		local a = k / 9 * math.pi * 2 + cracks:NextNumber(-0.2, 0.2)
		local len = cracks:NextNumber(8, 18)
		local from = ground + Vector3.new(math.cos(a) * 4, 0.05, math.sin(a) * 4)
		local to = from + Vector3.new(math.cos(a) * len, 0, math.sin(a) * len)
		newPart({ Name = "RiftCrack", Size = Vector3.new(cracks:NextNumber(0.4, 0.9), 0.1, len), CFrame = CFrame.lookAt((from + to) / 2, to),
			Color = Color3.fromRGB(255, 50, 60), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false,
			Parent = crackFolder })
	end
end

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

-- suit paints (YOUR PILOT): unlocked by pilot level, or the 7-day daily streak (gold)
local SUIT_PAINTS = {
	{ name = "STANDARD", steel = STEEL, accent = ACCENT, glow = GLOW },
	{ name = "CRIMSON", level = 5, steel = Color3.fromRGB(125, 32, 38), accent = Color3.fromRGB(225, 225, 232), glow = Color3.fromRGB(255, 96, 70) },
	{ name = "NEON TRIM", level = 10, steel = Color3.fromRGB(30, 30, 42), accent = Color3.fromRGB(255, 60, 200), glow = Color3.fromRGB(255, 60, 200) },
	{ name = "GOLD", daily = true, steel = Color3.fromRGB(205, 165, 60), accent = Color3.fromRGB(70, 46, 24), glow = Color3.fromRGB(255, 232, 150) },
	-- NEON SUIT PACK (Game Pass)
	{ name = "SYNTHWAVE", pass = "neon", steel = Color3.fromRGB(60, 20, 90), accent = Color3.fromRGB(255, 70, 190), glow = Color3.fromRGB(60, 240, 255) },
	{ name = "CHROME", pass = "neon", steel = Color3.fromRGB(200, 205, 215), accent = Color3.fromRGB(90, 95, 110), glow = Color3.fromRGB(150, 220, 255) },
	{ name = "STATIC", pass = "neon", steel = Color3.fromRGB(235, 240, 250), accent = Color3.fromRGB(30, 30, 40), glow = Color3.fromRGB(255, 255, 255) },
}
local PAINT_ROLE = {
	Helmet = "steel", Chassis = "steel", Cabin = "steel",
	Fin = "accent", ShoulderPad = "accent", Stripe = "accent", Spoiler = "accent",
	Visor = "glow", Core = "glow", Windshield = "glow",
}

-- recolour the robot armor and the car shell to the character's SuitPaint attribute
local function repaintSuit(char)
	local paint = SUIT_PAINTS[char:GetAttribute("SuitPaint") or 1] or SUIT_PAINTS[1]
	for _, folderName in ipairs({ "ShiftframeArmor", "ShiftframeVehicle" }) do
		local folder = char:FindFirstChild(folderName)
		if folder then
			for _, p in ipairs(folder:GetDescendants()) do
				if p:IsA("BasePart") then
					local role = PAINT_ROLE[p.Name] or (p.Name:sub(-5) == "Plate" and "steel")
					if role then
						p.Color = paint[role]
					end
				end
			end
		end
	end
end

local state = {} -- [player] = { mode, lastTransform, lastBlast, lastShift }

-- defined in the Saving section (profiles live there); used by kills and deliveries
local awardScrap      -- (player, amount, reason, plain)
local upgradeLevel    -- (player, id) -> 0..3
local equippedWeapon  -- (player) -> WEAPONS entry

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

---------------------------------------------------------------------------
-- Pilots: each player is a Hollow Creek teen in their own 80s look.
-- A look is { own = bool, outfit, hair, hairColor, skin } (indexes into the
-- tables below). own = true keeps the player's own Roblox avatar.
-- Looks are built from body colours + small welded parts, so no catalog ids
-- are needed. Optional: put Marketplace ids in shirtId / pantsId / hairId.
---------------------------------------------------------------------------
local SKIN_TONES = {
	Color3.fromRGB(255, 220, 190), Color3.fromRGB(234, 192, 158), Color3.fromRGB(204, 150, 110),
	Color3.fromRGB(160, 110, 75), Color3.fromRGB(120, 80, 55), Color3.fromRGB(80, 52, 38),
}
local HAIR_COLORS = {
	Color3.fromRGB(30, 26, 26), Color3.fromRGB(90, 56, 34), Color3.fromRGB(230, 196, 120),
	Color3.fromRGB(170, 70, 40), Color3.fromRGB(80, 170, 255), Color3.fromRGB(255, 110, 190),
}
-- hair: real Roblox hair items (free, made by Roblox; their colour is fixed), then block
-- styles that use HAIR COLOR. To add a hair: put its Marketplace id in HAIR_IDS and its name here.
local HAIR_STYLES = {
	"PAL HAIR", "BROWN HAIR", "SHORT FRINGE BLACK", "SHORT FRINGE BLONDE", "TOP KNOT BROWN", "TOP KNOT BLONDE", "LONG RED HAIR",
	"SPIKY (ANY COLOR)", "MOHAWK (ANY COLOR)", "CURLY (ANY COLOR)", "PONYTAIL (ANY COLOR)",
}
local HAIR_LEVEL = { ["PONYTAIL (ANY COLOR)"] = 15 } -- hair styles unlocked by pilot level
local HAIR_IDS = {
	["PAL HAIR"] = 63690008,
	["BROWN HAIR"] = 62234425,
	["SHORT FRINGE BLACK"] = 7193401217,
	["SHORT FRINGE BLONDE"] = 7193397693,
	["TOP KNOT BROWN"] = 9244060144,
	["TOP KNOT BLONDE"] = 9244057408,
	["LONG RED HAIR"] = 2956239660, -- "Belle Of Belfast Long Red Hair"
}
local HAIR_BLOCK = { ["SPIKY (ANY COLOR)"] = "SPIKY", ["MOHAWK (ANY COLOR)"] = "MOHAWK", ["CURLY (ANY COLOR)"] = "CURLY", ["PONYTAIL (ANY COLOR)"] = "PONYTAIL" }

-- torso / arms / legs colours (arms = nil: short sleeves, skin colour), plus extra parts
local PILOT_OUTFITS = {
	{ name = "VARSITY", torso = Color3.fromRGB(170, 30, 40), arms = Color3.fromRGB(235, 225, 200), legs = Color3.fromRGB(40, 50, 80),
		shoes = Color3.fromRGB(240, 240, 240), detail = "letter", shirtId = 0, pantsId = 0, hairId = 0 },
	{ name = "DENIM", torso = Color3.fromRGB(70, 100, 150), arms = Color3.fromRGB(70, 100, 150), legs = Color3.fromRGB(30, 30, 36),
		shoes = Color3.fromRGB(200, 40, 40), detail = "tee", shirtId = 0, pantsId = 0, hairId = 0 },
	{ name = "WINDBREAKER", torso = Color3.fromRGB(30, 170, 170), arms = Color3.fromRGB(240, 90, 170), legs = Color3.fromRGB(120, 120, 130),
		shoes = Color3.fromRGB(240, 240, 240), detail = "stripe", shirtId = 0, pantsId = 0, hairId = 0 },
	{ name = "SKATER", torso = Color3.fromRGB(240, 200, 50), arms = nil, legs = Color3.fromRGB(190, 160, 110),
		shoes = Color3.fromRGB(30, 30, 36), detail = "beanie", shirtId = 0, pantsId = 0, hairId = 0 },
	{ name = "ARCADE", torso = Color3.fromRGB(28, 26, 34), arms = Color3.fromRGB(28, 26, 34), legs = Color3.fromRGB(60, 90, 140),
		shoes = Color3.fromRGB(240, 240, 240), detail = "pixels", shirtId = 0, pantsId = 0, hairId = 0 },
	{ name = "AEROBICS", torso = Color3.fromRGB(255, 80, 170), arms = nil, legs = Color3.fromRGB(40, 190, 190),
		shoes = Color3.fromRGB(240, 240, 240), detail = "warmers", shirtId = 0, pantsId = 0, hairId = 0 },
}

local function validLook(look)
	if typeof(look) ~= "table" then
		return nil
	end
	local function pick(v, n)
		return (typeof(v) == "number" and v % 1 == 0 and v >= 1 and v <= n) and v or 1
	end
	if look.own == true then
		return { own = true, paint = pick(look.paint, #SUIT_PAINTS) }
	end
	return {
		own = false,
		outfit = pick(look.outfit, #PILOT_OUTFITS),
		hair = pick(look.hair, #HAIR_STYLES),
		hairColor = pick(look.hairColor, #HAIR_COLORS),
		skin = pick(look.skin, #SKIN_TONES),
		paint = pick(look.paint, #SUIT_PAINTS),
	}
end

local applyPilotLook -- (player, char, look); its helpers below are inside a do-block (200-locals limit)
do
local function bodyPart(char, r15, r6)
	return char:FindFirstChild(r15) or (r6 and char:FindFirstChild(r6))
end

-- a part welded to a body part, placed with an offset in that part's space
local function attach(folder, target, props, offset)
	props.CFrame = target.CFrame * offset
	props.Parent = folder
	local p = shellPart(props)
	weld(p, target)
	return p
end

local function buildHair(folder, head, style, color)
	local s = head.Size
	local function add(size, offset, shape)
		return attach(folder, head, { Name = "Hair", Size = size, Color = color, Material = Enum.Material.SmoothPlastic, Shape = shape },
			offset)
	end
	local capY = s.Y * 0.42
	if style == "BUZZ" then
		add(Vector3.new(s.X * 1.02, s.Y * 0.2, s.Z * 1.02), CFrame.new(0, capY, 0))
		return
	end
	if style == "CURLY" then
		add(Vector3.one * s.X * 1.45, CFrame.new(0, s.Y * 0.3, s.Z * 0.12), Enum.PartType.Ball)
		return
	end
	-- a cap of hair on top, a bit lower at the back
	add(Vector3.new(s.X * 1.06, s.Y * 0.32, s.Z * 1.06), CFrame.new(0, capY, s.Z * 0.03))
	add(Vector3.new(s.X * 1.06, s.Y * 0.45, s.Z * 0.25), CFrame.new(0, s.Y * 0.18, s.Z * 0.45))
	if style == "SPIKY" then
		for i = -2, 2 do
			add(Vector3.new(s.X * 0.2, s.Y * 0.4, s.Z * 0.2), CFrame.new(i * s.X * 0.2, capY + s.Y * 0.25, (i % 2) * s.Z * 0.15) * CFrame.Angles(0, 0, -i * 0.25))
		end
	elseif style == "LONG" then
		add(Vector3.new(s.X * 1.08, s.Y * 1.15, s.Z * 0.28), CFrame.new(0, -s.Y * 0.1, s.Z * 0.5))
		for _, side in ipairs({ -1, 1 }) do
			add(Vector3.new(s.X * 0.16, s.Y * 0.9, s.Z * 0.7), CFrame.new(side * s.X * 0.55, -s.Y * 0.05, s.Z * 0.12))
		end
	elseif style == "PONYTAIL" then
		add(Vector3.new(s.X * 0.32, s.Y * 0.9, s.Z * 0.32), CFrame.new(0, -s.Y * 0.05, s.Z * 0.72) * CFrame.Angles(0.35, 0, 0))
		add(Vector3.new(s.X * 0.36, s.Y * 0.12, s.Z * 0.36), CFrame.new(0, s.Y * 0.32, s.Z * 0.58)) -- hair tie
	elseif style == "MOHAWK" then
		add(Vector3.new(s.X * 0.24, s.Y * 0.55, s.Z * 1.1), CFrame.new(0, capY + s.Y * 0.3, 0))
	end
end

local function buildOutfitDetails(folder, char, outfit, skin)
	local torso = bodyPart(char, "UpperTorso", "Torso")
	if not torso then
		return
	end
	local t = torso.Size
	local front = -t.Z * 0.51
	if outfit.detail == "letter" then
		local patch = attach(folder, torso, { Name = "Patch", Size = Vector3.new(t.X * 0.32, t.Y * 0.36, 0.06), Color = Color3.fromRGB(235, 225, 200),
			Material = Enum.Material.Fabric }, CFrame.new(-t.X * 0.22, t.Y * 0.12, front))
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.Parent = patch
		local letter = Instance.new("TextLabel")
		letter.Size = UDim2.fromScale(1, 1)
		letter.BackgroundTransparency = 1
		letter.Font = Enum.Font.Arcade
		letter.TextScaled = true
		letter.Text = "H"
		letter.TextColor3 = outfit.torso
		letter.Parent = gui
	elseif outfit.detail == "tee" then
		attach(folder, torso, { Name = "Tee", Size = Vector3.new(t.X * 0.34, t.Y * 0.96, 0.06), Color = Color3.fromRGB(240, 240, 240),
			Material = Enum.Material.Fabric }, CFrame.new(0, 0, front))
	elseif outfit.detail == "stripe" then
		attach(folder, torso, { Name = "Stripe", Size = Vector3.new(t.X * 1.15, t.Y * 0.16, 0.06), Color = Color3.fromRGB(140, 80, 220),
			Material = Enum.Material.Fabric }, CFrame.new(0, t.Y * 0.1, front) * CFrame.Angles(0, 0, 0.35))
	elseif outfit.detail == "pixels" then
		for _, p in ipairs({ { -1, 1 }, { 1, 1 }, { 0, 0 }, { -1, -1 }, { 1, -1 }, { -2, 0 }, { 2, 0 } }) do
			attach(folder, torso, { Name = "Pixel", Size = Vector3.new(t.X * 0.09, t.Y * 0.09, 0.06), Color = Color3.fromRGB(60, 255, 140),
				Material = Enum.Material.Neon }, CFrame.new(p[1] * t.X * 0.09, t.Y * 0.1 + p[2] * t.Y * 0.09, front))
		end
	elseif outfit.detail == "warmers" then
		for _, name in ipairs({ "LeftLowerLeg", "RightLowerLeg" }) do
			local leg = char:FindFirstChild(name)
			if leg then
				attach(folder, leg, { Name = "LegWarmer", Size = leg.Size * Vector3.new(1.25, 0.7, 1.25), Color = Color3.fromRGB(255, 80, 170),
					Material = Enum.Material.Fabric }, CFrame.new(0, -leg.Size.Y * 0.1, 0))
			end
		end
		local head = char:FindFirstChild("Head")
		if head then
			attach(folder, head, { Name = "Headband", Size = Vector3.new(head.Size.X * 1.1, head.Size.Y * 0.14, head.Size.Z * 1.1),
				Color = Color3.fromRGB(255, 240, 80), Material = Enum.Material.Fabric }, CFrame.new(0, head.Size.Y * 0.22, 0))
		end
	end
	-- sneakers
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = char:FindFirstChild(name)
		if foot then
			attach(folder, foot, { Name = "Sneaker", Size = foot.Size * Vector3.new(1.15, 1.1, 1.2), Color = outfit.shoes,
				Material = Enum.Material.SmoothPlastic }, CFrame.new(0, 0, -foot.Size.Z * 0.05))
		end
	end
end

-- apply a pilot look to a character (yields: ApplyDescription)
applyPilotLook = function(player, char, look)
	local old = char:FindFirstChild("PilotLook")
	if old then
		old:Destroy()
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or not look then
		return
	end
	if look.own then
		if char:GetAttribute("PresetLook") then -- put their own avatar back
			local ok, desc = pcall(function()
				return Players:GetHumanoidDescriptionFromUserId(player.UserId)
			end)
			if ok and desc then
				pcall(function()
					hum:ApplyDescription(desc)
				end)
			end
			char:SetAttribute("PresetLook", nil)
		end
		return
	end

	local outfit = PILOT_OUTFITS[look.outfit]
	local skin = SKIN_TONES[look.skin]
	local hairName = HAIR_STYLES[look.hair]
	local hairId = outfit.hairId ~= 0 and outfit.hairId or HAIR_IDS[hairName] -- a real Roblox hair, or nil (block hair)
	local function dress(withHair)
		return pcall(function()
			local desc = hum:GetAppliedDescription()
			for _, field in ipairs({ "HatAccessory", "HairAccessory", "FaceAccessory", "NeckAccessory", "ShouldersAccessory",
				"FrontAccessory", "BackAccessory", "WaistAccessory" }) do
				desc[field] = ""
			end
			pcall(function()
				desc:SetAccessories({}, true) -- layered clothing
			end)
			desc.Shirt = outfit.shirtId
			desc.Pants = outfit.pantsId
			desc.GraphicTShirt = 0
			if withHair and hairId then
				desc.HairAccessory = tostring(hairId)
			end
			desc.HeadColor = skin
			desc.TorsoColor = outfit.torso
			desc.LeftArmColor = outfit.arms or skin
			desc.RightArmColor = outfit.arms or skin
			desc.LeftLegColor = outfit.legs
			desc.RightLegColor = outfit.legs
			hum:ApplyDescription(desc)
		end)
	end
	local ok = dress(true)
	if not ok and hairId then
		-- the hair item didn't load: dress without it and use a block hair instead
		warn("[Look] hair " .. tostring(hairId) .. " failed to load, using a block hair")
		hairId = nil
		hairName = "SHORT"
		ok = dress(false)
	end
	if not ok or not char.Parent then
		return
	end
	char:SetAttribute("PresetLook", true)

	local folder = Instance.new("Folder")
	folder.Name = "PilotLook"
	folder.Parent = char
	-- hands keep the skin colour
	for _, name in ipairs({ "LeftHand", "RightHand" }) do
		local hand = char:FindFirstChild(name)
		if hand then
			hand.Color = skin
		end
	end
	buildOutfitDetails(folder, char, outfit, skin)
	local head = char:FindFirstChild("Head")
	if head and not hairId then
		buildHair(folder, head, HAIR_BLOCK[hairName] or hairName, HAIR_COLORS[look.hairColor])
	end
	if head then
		if outfit.detail == "beanie" then
			attach(folder, head, { Name = "Beanie", Size = Vector3.new(head.Size.X * 1.12, head.Size.Y * 0.42, head.Size.Z * 1.12),
				Color = Color3.fromRGB(40, 40, 60), Material = Enum.Material.Fabric }, CFrame.new(0, head.Size.Y * 0.48, 0.02))
		end
	end
end
end -- pilot look helpers

-- which layers show: the pilot's look (hair, details) in PILOT mode, the armor in ROBOT mode
local function setLayerVisible(char, folderName, visible)
	if folderName == "PilotLook" then
		-- real hair (and hats) are accessories: hide them under the robot helmet too
		for _, acc in ipairs(char:GetChildren()) do
			local handle = acc:IsA("Accessory") and acc:FindFirstChild("Handle")
			if handle then
				handle.Transparency = visible and 0 or 1
			end
		end
	end
	local folder = char:FindFirstChild(folderName)
	if not folder then
		return
	end
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = visible and 0 or 1
		elseif d:IsA("SurfaceGui") then
			d.Enabled = visible
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
	task.defer(repaintSuit, char) -- suit paint (after the whole shell is built)

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

	-- exhaust smoke from the back
	local pipe = add({ Name = "Exhaust", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 0.5, 0.5), Color = Color3.fromRGB(60, 60, 64),
		Material = Enum.Material.Metal }, CFrame.new(1.6, base + 1.4, 5.7) * CFrame.Angles(0, math.rad(90), 0))
	local smoke = Instance.new("ParticleEmitter")
	smoke.Rate = 14
	smoke.Lifetime = NumberRange.new(0.6, 1.1)
	smoke.Speed = NumberRange.new(2, 4)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.Size = NumberSequence.new(0.4, 1.6)
	smoke.Transparency = NumberSequence.new(0.5, 1)
	smoke.Color = ColorSequence.new(Color3.fromRGB(150, 150, 160))
	smoke.EmissionDirection = Enum.NormalId.Right
	smoke.Parent = pipe
end

local function setMode(player, mode)
	local s = state[player]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not s or not hum then
		return
	end

	hum.UseJumpPower = true
	if mode == "Vehicle" then
		setBodyHidden(char, true)
		buildVehicle(char)
		hum.WalkSpeed = CONFIG.VEHICLE_SPEED * (1 + 0.1 * upgradeLevel(player, "turbo"))
		hum.JumpPower = CONFIG.VEHICLE_JUMP
	else
		local v = char:FindFirstChild("ShiftframeVehicle")
		if v then
			v:Destroy()
		end
		setBodyHidden(char, false)
		-- PILOT: you in your own look. ROBOT: the armor folds around you.
		local pilot = mode == "Pilot"
		setLayerVisible(char, "ShiftframeArmor", not pilot)
		setLayerVisible(char, "PilotLook", pilot)
		hum.WalkSpeed = pilot and CONFIG.PILOT_SPEED or CONFIG.ROBOT_SPEED
		hum.JumpPower = pilot and CONFIG.PILOT_JUMP or CONFIG.ROBOT_JUMP
	end

	s.mode = mode
	char:SetAttribute("Mode", mode)
	TransformEvent:FireAllClients(char, mode)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		sparkBurst(hrp.Position, GLOW, 40, 30, 0.5, 0.6) -- transform flash
	end
end

---------------------------------------------------------------------------
-- Hollowers (shadow creatures)
---------------------------------------------------------------------------
local creatureFolder = Instance.new("Folder")
creatureFolder.Name = "Creatures"
creatureFolder.Parent = workspace

-- [model] = { lastHit, phase, speed, damage, hitCooldown, reward }
local creatures = {}

local SHADOW = Color3.fromRGB(28, 22, 26)
local MAW = Color3.fromRGB(255, 40, 50)

-- Chapter 3: the Carrier (a BasePart) that creatures also attack, and how they damage it
local carrierTarget = nil
local damageCarrier -- defined in the Chapter 3 section

local function updateHealthBar(m)
	local bar = m:FindFirstChild("Fill", true)
	if bar then
		local hp = math.max(m:GetAttribute("Health"), 0)
		bar.Size = UDim2.fromScale(hp / (m:GetAttribute("MaxHealth") or CONFIG.CREATURE_HEALTH), 1)
	end
end

local function addHealthBar(part, width, offsetY, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(width, 8)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 80
	gui.Parent = part
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
end

-- the areas around the Undergrid rifts are safe: anything inside is moved to the edge
local function outsideRiftZone(pos, extra)
	local radius = CONFIG.RIFT_SAFE_RADIUS + (extra or 0)
	for _, rift in ipairs(UG_RIFT_POSITIONS) do
		local flat = Vector3.new(pos.X - rift.X, 0, pos.Z - rift.Z)
		if flat.Magnitude < radius then
			local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(1, 0, 0)
			pos = Vector3.new(rift.X, pos.Y, rift.Z) + dir * radius
		end
	end
	return pos
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
	addHealthBar(head, 80, 3, MAW)

	m.PrimaryPart = body
	m:SetAttribute("Creature", true)
	m:SetAttribute("Health", CONFIG.CREATURE_HEALTH)
	m:SetAttribute("MaxHealth", CONFIG.CREATURE_HEALTH)
	m:PivotTo(CFrame.new(spot + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	m.Parent = creatureFolder
	creatures[m] = {
		lastHit = 0, phase = rng:NextNumber(0, 10), speed = CONFIG.CREATURE_SPEED, damage = CONFIG.CREATURE_DAMAGE,
		hitCooldown = CONFIG.CREATURE_HIT_COOLDOWN, reward = CONFIG.SCRAP_HOLLOWER, height = 5.5,
	}
	return m
end

-- Static Hound (Chapter 3): low, fast, weak, hunts in packs. at: ground point
local HOUND_STATIC = Color3.fromRGB(200, 230, 255)

local function spawnHound(at)
	local spot = outsideRiftZone(at, 15)
	local m = Instance.new("Model")
	m.Name = "StaticHound"
	local function add(props, cf)
		props.CFrame = cf
		props.CanCollide = false
		props.Parent = m
		return newPart(props)
	end
	local body = add({ Name = "Body", Size = Vector3.new(2.4, 1.6, 4.4), Color = Color3.fromRGB(40, 44, 54), Material = Enum.Material.Slate }, CFrame.new())
	local head = add({ Name = "Head", Size = Vector3.new(1.6, 1.4, 1.8), Color = Color3.fromRGB(40, 44, 54), Material = Enum.Material.Slate },
		CFrame.new(0, 0.5, -2.8))
	for _, side in ipairs({ -1, 1 }) do
		add({ Name = "Eye", Size = Vector3.new(0.35, 0.25, 0.1), Color = HOUND_STATIC, Material = Enum.Material.Neon }, CFrame.new(side * 0.45, 0.75, -3.72))
		for _, z in ipairs({ -1.6, 1.6 }) do
			add({ Name = "Leg", Size = Vector3.new(0.4, 1.8, 0.4), Color = Color3.fromRGB(30, 32, 40), Material = Enum.Material.Slate },
				CFrame.new(side * 0.9, -1.4, z))
		end
	end
	for k = 1, 4 do -- crackling spines along the back
		add({ Name = "Spine", Size = Vector3.new(0.2, 1, 0.2), Color = HOUND_STATIC, Material = Enum.Material.Neon },
			CFrame.new(0, 1.2, -1.6 + k * 0.8) * CFrame.Angles(0.5, 0, 0))
	end
	local glow = Instance.new("PointLight")
	glow.Color = HOUND_STATIC
	glow.Range = 10
	glow.Brightness = 2
	glow.Parent = head
	addHealthBar(head, 60, 2, HOUND_STATIC)

	m.PrimaryPart = body
	m:SetAttribute("Creature", true)
	m:SetAttribute("Health", CONFIG.HOUND_HEALTH)
	m:SetAttribute("MaxHealth", CONFIG.HOUND_HEALTH)
	m:PivotTo(CFrame.new(spot + Vector3.new(0, 2.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	m.Parent = creatureFolder
	creatures[m] = {
		lastHit = 0, phase = rng:NextNumber(0, 10), speed = CONFIG.HOUND_SPEED, damage = CONFIG.HOUND_DAMAGE,
		hitCooldown = CONFIG.HOUND_HIT_COOLDOWN, reward = CONFIG.SCRAP_HOUND, height = 2.3,
	}
	return m
end

-- returns the hound models (chapter modules give them their own targets)
local function spawnHoundPack(at)
	local pack = {}
	for _ = 1, CONFIG.HOUND_PACK do
		table.insert(pack, spawnHound(at + Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5))))
	end
	return pack
end

local function killCreature(m)
	creatures[m] = nil
	if m.PrimaryPart then
		-- burst of dark smoke, then the pieces fall apart and fade away
		sparkBurst(m.PrimaryPart.Position, Color3.fromRGB(30, 20, 30), 30, 12, 2.5, 1.2)
		sparkBurst(m.PrimaryPart.Position, MAW, 14, 20, 0.4, 0.5)
	end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = true
			p.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-25, 25), rng:NextNumber(15, 40), rng:NextNumber(-25, 25))
			TweenService:Create(p, TweenInfo.new(2.5), { Transparency = 1 }):Play()
		end
	end
	Debris:AddItem(m, 3)
end

-- attacker: optional player, rewarded with Scrap for the kill
local function damageCreature(m, amount, attacker)
	local data = creatures[m]
	if not data then
		return
	end
	m:SetAttribute("Health", m:GetAttribute("Health") - amount)
	updateHealthBar(m)
	if m:GetAttribute("Health") <= 0 then
		if m.PrimaryPart then
			dropAmmo(m.PrimaryPart.Position) -- sometimes a spare magazine (task 012)
		end
		killCreature(m)
		if attacker then
			awardScrap(attacker, data.reward, m.Name == "StaticHound" and "STATIC HOUND" or "HOLLOWER")
			track(attacker, "kill", 1)
			if m.Name == "StaticHound" then
				track(attacker, "hound", 1)
			end
			if equippedWeapon(attacker).melee then
				track(attacker, "baton", 1)
			end
		end
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
		if plr:GetAttribute("Dimension") == "Undergrid" and hrp and hum and hum.Health > 0 and not char:GetAttribute("Downed") then
			table.insert(list, { plr = plr, hrp = hrp, hum = hum })
		end
	end
	return list
end

-- creature brain: drift toward the nearest player in the Undergrid (or the Carrier in
-- Chapter 3), passing through walls
RunService.Heartbeat:Connect(function(dt)
	local targets = playersInUndergrid()
	local now = os.clock()
	for m, data in pairs(creatures) do
		if m.Parent and m.PrimaryPart then
			local root = m.PrimaryPart.Position
			local best, bestDist = nil, CONFIG.CREATURE_AGGRO
			-- chapter modules can give a creature its own target list (Echoes hunt inside Site 2)
			for _, t in ipairs(data.targets and data.targets() or targets) do
				local d = (t.hrp.Position - root).Magnitude
				if d < bestDist then
					best, bestDist = t, d
				end
			end
			local goingForCarrier = false
			if carrierTarget and carrierTarget.Parent and not data.targets then
				local d = (carrierTarget.Position - root).Magnitude
				if d < bestDist + 25 then -- they prefer the Carrier unless a player is much closer
					best, bestDist, goingForCarrier = { hrp = carrierTarget }, d, true
				end
			end

			data.phase = data.phase + dt
			local bob = math.sin(data.phase * 4) * 0.02

			if best then
				local flat = Vector3.new(best.hrp.Position.X, root.Y, best.hrp.Position.Z)
				local delta = flat - root
				-- ranged creatures (Echoes) keep their distance: data.stopAt(m, target) -> studs
				local stopAt = goingForCarrier and 7 or (data.stopAt and data.stopAt(m, best)) or 3.5
				local newPos = root
				if delta.Magnitude > stopAt then
					newPos = root + delta.Unit * math.min(data.speed * dt, delta.Magnitude - stopAt)
				end
				newPos = outsideRiftZone(newPos) -- they wait at the edge of the safe zone
				-- they also drift up or down through floors and ceilings (Grand Hotel)
				if not goingForCarrier then
					local goalY = best.hrp.Position.Y - 3 + (data.height or 5.5)
					local dy = goalY - newPos.Y
					newPos = newPos + Vector3.new(0, math.clamp(dy, -data.speed * 0.6 * dt, data.speed * 0.6 * dt), 0)
				end
				if delta.Magnitude > 0.1 then
					m:PivotTo(CFrame.lookAt(newPos, Vector3.new(flat.X, newPos.Y, flat.Z)) * CFrame.Angles(bob, 0, 0))
				end
				local reach = (Vector3.new(best.hrp.Position.X, 0, best.hrp.Position.Z) - Vector3.new(newPos.X, 0, newPos.Z)).Magnitude
				if now - data.lastHit > data.hitCooldown then
					if goingForCarrier and reach < 10 then
						data.lastHit = now
						damageCarrier(data.damage)
					elseif data.attack then
						-- ranged creatures shoot: data.attack(m, target) -> true when it fired
						if data.attack(m, best) then
							data.lastHit = now
						end
					elseif not goingForCarrier and (best.hrp.Position - m.PrimaryPart.Position).Magnitude < 6.5 then
						-- TakeDamage does nothing while the player has the rift shield (ForceField)
						data.lastHit = now
						hurtPlayer(best.plr, best.hum, data.damage)
					end
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
local chapter3Complete      -- defined in the Chapter 3 section (the radio tower console calls it)

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

---------------------------------------------------------------------------
-- Scrap, weapon and upgrades of a player (stored in their profile)
---------------------------------------------------------------------------
upgradeLevel = function(player, id)
	local profile = profiles[player]
	return profile and profile.upgrades[id] or 0
end

equippedWeapon = function(player)
	local profile = profiles[player]
	return WEAPONS[profile and profile.weapon or "pulse"] or WEAPONS.pulse
end

local updateBoards -- (player) leaderboard scores, defined in the task 010 section
local addXp        -- (player, amount) defined in the task 010 section

-- pilot level from total XP: level 1 needs 100 XP, each next level 60 more
local function levelInfo(xp)
	local level, need = 1, 100
	while xp >= need and level < CONFIG.MAX_LEVEL do
		xp = xp - need
		level = level + 1
		need = 100 + 60 * (level - 1)
	end
	return level, xp, need
end

-- the "game clock" for daily resets (CONFIG.DEBUG_DAY_OFFSET moves it for testing)
local function gameTime()
	return os.time() + CONFIG.DEBUG_DAY_OFFSET * 86400
end

local function dayNumber()
	return math.floor(gameTime() / 86400) -- changes at midnight UTC
end

-- Friday, Saturday and Sunday (UTC): gameplay Scrap and XP x2
local function isWeekend()
	if CONFIG.DEBUG_FORCE_WEEKEND then
		return true
	end
	local wday = os.date("!*t", gameTime()).wday -- 1 = Sunday ... 7 = Saturday
	return wday == 1 or wday == 6 or wday == 7
end

-- leaderstats + attributes the client reads (hold-to-fire rate, weapon name, level), and armor
local function applyLoadout(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local level, into, need = levelInfo(profile.xp)
	local stats = player:FindFirstChild("leaderstats")
	if stats and stats:FindFirstChild("Scrap") then
		stats.Scrap.Value = profile.scrap
	end
	if stats and stats:FindFirstChild("Level") then
		stats.Level.Value = level
	end
	player:SetAttribute("Level", level)
	player:SetAttribute("XP", into)
	player:SetAttribute("XPNeed", need)
	player:SetAttribute("Title", level >= 20 and "VETERAN" or nil)
	pushAmmo(player) -- the equipped weapon's ammo for the HUD
	local weapon = equippedWeapon(player)
	player:SetAttribute("Weapon", profile.weapon)
	player:SetAttribute("WeaponName", weapon.name)
	player:SetAttribute("WeaponCooldown", weapon.cooldown)

	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		local maxHealth = 100 + 25 * profile.upgrades.armor
		if hum.MaxHealth ~= maxHealth then
			local gained = maxHealth - hum.MaxHealth
			hum.MaxHealth = maxHealth
			hum.Health = math.min(hum.Health + math.max(gained, 0), maxHealth)
		end
	end
end

-- plain = true: a reward from the daily / quests / achievements / codes (no 2x, no XP).
-- Otherwise it's gameplay: doubled on weekends, and it gives the same amount of XP.
awardScrap = function(player, amount, reason, plain)
	local profile = profiles[player]
	if not profile or amount <= 0 then
		return
	end
	if not plain then
		if isWeekend() then
			amount = amount * 2
			reason = reason .. " 2x"
		end
		if player:GetAttribute("FriendBonus") then
			amount = math.ceil(amount * (1 + CONFIG.FRIEND_BONUS)) -- playing with a friend (task 011)
		end
		if profile.passes.vip then
			amount = math.ceil(amount * 1.25) -- VIP PILOT Game Pass (task 017)
		end
		addXp(player, amount)
	end
	profile.scrap = profile.scrap + amount
	applyLoadout(player)
	RewardEvent:FireClient(player, amount, reason)
end

local function awardEveryone(amount, reason)
	for _, plr in ipairs(Players:GetPlayers()) do
		awardScrap(plr, amount, reason)
	end
end

-- re-dress a player who is already spawned (after choosing a look, or once the save loads)
local function refreshLook(player)
	local profile = profiles[player]
	local s = state[player]
	local char = player.Character
	if not profile or not s or not char or not s.ready then
		return
	end
	if s.mode == "Vehicle" then
		setMode(player, "Robot") -- the look is rebuilt on the body, not on the car
	end
	applyPilotLook(player, char, profile.look)
	setLayerVisible(char, "PilotLook", s.mode == "Pilot")
	char:SetAttribute("SuitPaint", profile.look and profile.look.paint or 1)
	repaintSuit(char)
end

-- the options the character select screen offers (names and colours; the server owns them)
-- level / daily-streak unlocks for the look (task 010)
local function paintUnlocked(profile, i)
	local paint = SUIT_PAINTS[i]
	if not paint then
		return false
	end
	if paint.daily then
		return profile.gold == true
	end
	if paint.pass then
		return profile.passes[paint.pass] == true -- Game Pass (task 017)
	end
	return levelInfo(profile.xp) >= (paint.level or 0)
end

local function hairUnlocked(profile, i)
	local need = HAIR_LEVEL[HAIR_STYLES[i] or ""]
	return not need or levelInfo(profile.xp) >= need
end

local function lookCatalog(profile)
	local outfits = {}
	for _, o in ipairs(PILOT_OUTFITS) do
		table.insert(outfits, o.name)
	end
	local hairs, paints = {}, {}
	for i, name in ipairs(HAIR_STYLES) do
		local need = HAIR_LEVEL[name]
		hairs[i] = (need and not (profile and hairUnlocked(profile, i))) and (name:gsub(" %(ANY COLOR%)", "") .. " (LEVEL " .. need .. ")") or name
	end
	for i, paint in ipairs(SUIT_PAINTS) do
		local open = (not paint.level and not paint.daily and not paint.pass) or (profile and paintUnlocked(profile, i))
		paints[i] = open and paint.name or (paint.name .. ((paint.daily and " (7-DAY STREAK)") or (paint.pass and " (NEON PACK)")
			or (" (LEVEL " .. tostring(paint.level) .. ")")))
	end
	return { outfits = outfits, hairs = hairs, hairColors = HAIR_COLORS, skins = SKIN_TONES, paints = paints }
end

local function loadProfile(player)
	local profile = {
		loaded = false, available = saveStore ~= nil, chosen = false, save = nil, bestChapter = 1, brightness = nil,
		lastWrite = 0, queued = false, lastManual = -math.huge, lastChoose = -math.huge,
		reason = saveStore == nil and "NOT PUBLISHED" or nil, -- why saving is unavailable, shown in the menu
		-- shop
		scrap = 0, owned = { pulse = true, baton = true }, weapon = "pulse", upgrades = { armor = 0, turbo = 0, shield = 0, mag = 0, reload = 0 },
		ammo = {}, refillAt = nil, -- task 012: [weapon id] = { mag, spare }; os.time() of the next free refill
		-- task 010: XP, daily streak, quests, achievements, lifetime counts, used codes, paint unlocks
		xp = 0, streak = 0, lastClaimDay = nil, quests = nil, achievements = {}, counts = {}, codes = {}, gold = false,
		doorFloors = {}, -- this session only: doors opened per hotel floor (ROOM SERVICE)
		-- task 011: tutorial and the new settings
		tutorialDone = false, volume = nil, hudSize = nil, damageNumbers = nil,
		-- task 017: Game Passes owned (checked with Roblox on every join, not saved) and handled receipts
		passes = {}, receipts = {},
	}
	profiles[player] = profile
	applyLoadout(player)
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
			if data.graphics == 1 or data.graphics == 2 or data.graphics == 3 then
				profile.graphics = data.graphics
			end
			if typeof(data.shake) == "boolean" then
				profile.shake = data.shake
			end
			if typeof(data.autoAim) == "boolean" then
				profile.autoAim = data.autoAim
			end
			-- task 012: ammo left per weapon (missing = full) and the next free refill
			if type(data.ammo) == "table" then
				for id, a in pairs(data.ammo) do
					local w = WEAPONS[id]
					if w and w.mag and type(a) == "table" and tonumber(a.mag) and tonumber(a.spare) then
						profile.ammo[id] = {
							mag = math.clamp(math.floor(a.mag), 0, w.mag * 2),
							spare = math.clamp(math.floor(a.spare), 0, math.floor(w.reserve * 1.5)), -- 1.5: AMMO BELT pass
						}
					end
				end
			end
			profile.refillAt = tonumber(data.refillAt)
			-- task 017: Robux purchases already handled (so a receipt is never granted twice)
			if type(data.receipts) == "table" then
				for _, id in ipairs(data.receipts) do
					if type(id) == "string" then
						profile.receipts[id] = true
					end
				end
			end
			-- task 011: anyone with a save from before the tutorial existed already knows how to play
			profile.tutorialDone = data.tutorialDone ~= false
			if tonumber(data.volume) then
				profile.volume = math.clamp(math.floor(data.volume), 0, 10)
			end
			if data.hudSize == 1 or data.hudSize == 2 or data.hudSize == 3 then
				profile.hudSize = data.hudSize
			end
			if typeof(data.damageNumbers) == "boolean" then
				profile.damageNumbers = data.damageNumbers
			end
			profile.look = validLook(data.look)
			local stats = player:FindFirstChild("leaderstats")
			if stats and tonumber(data.lifetimeShards) then
				stats.Shards.Value = data.lifetimeShards
			end

			-- shop fields (missing in older saves): keep anything earned while loading
			profile.scrap = profile.scrap + math.max(math.floor(tonumber(data.scrap) or 0), 0)
			if type(data.owned) == "table" then
				for _, id in ipairs(data.owned) do
					if WEAPONS[id] then
						profile.owned[id] = true
					end
				end
			end
			if WEAPONS[data.weapon] and profile.owned[data.weapon] then
				profile.weapon = data.weapon
			end
			if type(data.upgrades) == "table" then
				for _, id in ipairs(UPGRADE_ORDER) do
					profile.upgrades[id] = math.clamp(math.floor(tonumber(data.upgrades[id]) or 0), 0, #UPGRADES[id].prices)
				end
			end

			-- task 010 fields (missing in older saves); XP and counts earned while loading are kept
			profile.xp = profile.xp + math.max(math.floor(tonumber(data.xp) or 0), 0)
			profile.streak = math.max(math.floor(tonumber(data.streak) or 0), 0)
			profile.lastClaimDay = tonumber(data.lastClaimDay)
			profile.gold = data.gold == true
			if type(data.quests) == "table" and tonumber(data.quests.day) and type(data.quests.list) == "table" then
				profile.quests = data.quests
			end
			for _, key in ipairs({ "achievements", "codes" }) do
				if type(data[key]) == "table" then
					for _, id in ipairs(data[key]) do
						if type(id) == "string" then
							profile[key][id] = true
						end
					end
				end
			end
			if type(data.counts) == "table" then
				for kind, n in pairs(data.counts) do
					if type(kind) == "string" and tonumber(n) then
						profile.counts[kind] = (profile.counts[kind] or 0) + math.max(math.floor(n), 0)
					end
				end
			end
		end
	end
	profile.bestChapter = math.max(profile.bestChapter, ReplicatedStorage:GetAttribute("Chapter") or 1)
	profile.loaded = true
	applyLoadout(player)
	-- the first spawn may have happened before the save loaded: put the saved look on now
	local char = player.Character
	if profile.look and char and char:FindFirstChild("ShiftframeArmor") then
		task.spawn(refreshLook, player)
	end
end

-- what gets saved: the current chapter/stage, without boss HP or carried shards
local function snapshot()
	local chapter = ReplicatedStorage:GetAttribute("Chapter") or 1
	local stage = ReplicatedStorage:GetAttribute("Stage") or "Shards"
	local progress = ReplicatedStorage:GetAttribute("Progress") or 0
	if stage == "Boss" then
		progress = 0 -- a saved boss fight restarts from the beginning of the fight
	elseif stage == "Carrier" or stage == "Race" then
		stage, progress = "Carrier", 0 -- the defence (and the race after it) restart from the defence
	elseif chapter == 1 and stage == "Complete" then
		chapter, stage, progress = 2, "Nodes", 0 -- already on the way to Chapter 2
	elseif chapter == 2 and stage == "Complete" then
		chapter, stage, progress = 3, "Files", 0 -- already on the way to Chapter 3
	elseif chapter == 3 and stage == "Complete" then
		chapter, stage, progress = 4, "Keycards", 0 -- already on the way to Chapter 4
	elseif chapter == 4 and stage == "Complete" then
		chapter, stage, progress = 5, "Rifts", 0 -- already on the way to Chapter 5
	elseif chapter == 5 and stage == "Complete" then
		chapter, stage, progress = 6, "Locks", 0 -- already on the way to Chapter 6
	elseif chapter == 6 and (stage == "Listener" or stage == "Collapse" or stage == "Broadcast") then
		stage, progress = "Listener", 0 -- the final boss restarts from its first phase
	elseif stage == "Van" or stage == "TapeRace" then
		progress = 0 -- Chapter 5: the van defence and the tape race restart from their beginning
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
		graphics = profile.graphics,
		shake = profile.shake,
		autoAim = profile.autoAim,
		tutorialDone = profile.tutorialDone,
		ammo = profile.ammo,
		refillAt = profile.refillAt,
		volume = profile.volume,
		hudSize = profile.hudSize,
		damageNumbers = profile.damageNumbers,
		look = profile.look,
		introSeen = true,
		savedAt = os.time(),
		scrap = profile.scrap,
		owned = {},
		weapon = profile.weapon,
		upgrades = table.clone(profile.upgrades),
		xp = profile.xp,
		streak = profile.streak,
		lastClaimDay = profile.lastClaimDay,
		gold = profile.gold,
		quests = profile.quests,
		counts = table.clone(profile.counts),
		achievements = {},
		codes = {},
	}
	for id in pairs(profile.owned) do
		table.insert(data.owned, id)
	end
	for _, key in ipairs({ "achievements", "codes" }) do
		for id in pairs(profile[key]) do
			table.insert(data[key], id)
		end
	end
	data.receipts = {}
	for id in pairs(profile.receipts) do
		if #data.receipts < 200 then
			table.insert(data.receipts, id)
		end
	end
	updateBoards(player) -- leaderboard (OrderedDataStores), defined in the task 010 section
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

---------------------------------------------------------------------------
-- Reasons to come back (task 010): pilot level, daily reward, daily quests,
-- achievements, leaderboard, codes and weekend 2x. The server decides all of
-- it; the menu (StartMenu) asks through MetaFunction and only shows the result.
-- (inside a do-block: the script is close to Luau's 200-locals limit)
---------------------------------------------------------------------------
local chapterCleared -- (chapter) a chapter was finished: counts for everyone playing
do
local LEVEL_UNLOCKS = { [5] = "CRIMSON SUIT PAINT", [10] = "NEON TRIM SUIT PAINT", [15] = "PONYTAIL HAIR", [20] = "VETERAN TITLE" }

local QUESTS = {
	{ id = "kills", kind = "kill", goal = 15, reward = 120, text = "Defeat 15 creatures" },
	{ id = "kills40", kind = "kill", goal = 40, reward = 260, text = "Defeat 40 creatures" },
	{ id = "baton", kind = "baton", goal = 5, reward = 130, text = "Defeat 5 creatures with the Shock Baton" },
	{ id = "objective", kind = "objective", goal = 3, reward = 120, text = "Complete 3 mission goals (shards, nodes, files, relays)" },
	{ id = "doors", kind = "door", goal = 5, reward = 80, text = "Open 5 hotel room doors" },
	{ id = "elevator", kind = "elevator", goal = 2, reward = 80, text = "Ride the hotel elevator 2 times" },
	{ id = "shifts", kind = "shift", goal = 4, reward = 90, text = "Shift through the rift 4 times" },
	{ id = "transform", kind = "transform", goal = 10, reward = 70, text = "Transform 10 times" },
	{ id = "chapter", kind = "chapter", goal = 1, reward = 250, text = "Finish a chapter" },
}
local QUEST_BY_ID = {}
for _, q in ipairs(QUESTS) do
	QUEST_BY_ID[q.id] = q
end

-- count = a lifetime counter that must reach goal; or check(profile) for anything else
local ACHIEVEMENTS = {
	{ id = "first", name = "FIRST CONTACT", hint = "Defeat your first creature", count = "kill", goal = 1, reward = 50 },
	{ id = "hunter", name = "HOLLOW HUNTER", hint = "Defeat 100 creatures", count = "kill", goal = 100, reward = 300 },
	{ id = "pack", name = "PACK BREAKER", hint = "Defeat 25 Static Hounds", count = "hound", goal = 25, reward = 250 },
	{ id = "spark", name = "SPARK STICK", hint = "Defeat 25 creatures with the Shock Baton", count = "baton", goal = 25, reward = 200 },
	{ id = "walker", name = "RIFT WALKER", hint = "Shift through the rift 50 times", count = "shift", goal = 50, reward = 200 },
	{ id = "keeper", name = "SIGNAL KEEPER", hint = "Deliver 25 Signal Shards", count = "shard", goal = 25, reward = 200 },
	{ id = "goingup", name = "GOING UP", hint = "Ride a hotel elevator", count = "elevator", goal = 1, reward = 50 },
	{ id = "roomservice", name = "ROOM SERVICE", hint = "Open every room door on one hotel floor", count = "fullfloor", goal = 1, reward = 150 },
	{ id = "sealed", name = "SEALED", hint = "Finish Chapter 1", count = "chapter1", goal = 1, reward = 100 },
	{ id = "warden", name = "WARDEN BREAKER", hint = "Defeat the Mind Warden", count = "chapter2", goal = 1, reward = 250 },
	{ id = "nightshift", name = "NIGHT SHIFT", hint = "Finish Chapter 3", count = "chapter3", goal = 1, reward = 300 },
	{ id = "firstnight", name = "FIRST NIGHT", hint = "Finish the tutorial", count = "tutorial", goal = 1, reward = 50 },
	{ id = "nooneleft", name = "NO ONE LEFT BEHIND", hint = "Revive a teammate", count = "revive", goal = 1, reward = 150 },
	{ id = "untouched", name = "UNTOUCHED", hint = "Finish a chapter without dying", count = "untouched", goal = 1, reward = 300 },
	{ id = "loaded", name = "FULLY LOADED", hint = "Own every weapon", reward = 300, check = function(profile)
		for _, id in ipairs(WEAPON_ORDER) do
			if not profile.owned[id] then
				return false
			end
		end
		return true
	end },
	{ id = "roll", name = "ON A ROLL", hint = "Claim the daily reward 7 days in a row", reward = 200, check = function(profile)
		return profile.streak >= 7
	end },
	{ id = "rising", name = "RISING PILOT", hint = "Reach level 10", reward = 200, check = function(profile)
		return levelInfo(profile.xp) >= 10
	end },
	{ id = "veteran", name = "VETERAN", hint = "Reach level 20", reward = 500, check = function(profile)
		return levelInfo(profile.xp) >= 20
	end },
}

local function secondsToReset()
	return 86400 - gameTime() % 86400
end

local function checkAchievements(player)
	local profile = profiles[player]
	if not profile or not profile.loaded then
		return
	end
	for _, a in ipairs(ACHIEVEMENTS) do
		if not profile.achievements[a.id] then
			local met
			if a.check then
				met = a.check(profile)
			else
				met = (profile.counts[a.count] or 0) >= a.goal
			end
			if met then
				profile.achievements[a.id] = true
				NotifyEvent:FireClient(player, "ACHIEVEMENT: " .. a.name, Color3.fromRGB(255, 214, 90))
				awardScrap(player, a.reward, a.name, true)
				queueSave(player)
			end
		end
	end
end

addXp = function(player, amount)
	local profile = profiles[player]
	if not profile or amount <= 0 then
		return
	end
	local before = levelInfo(profile.xp)
	profile.xp = profile.xp + amount
	local after = levelInfo(profile.xp)
	applyLoadout(player)
	for level = before + 1, after do
		local unlock = LEVEL_UNLOCKS[level]
		NotifyEvent:FireClient(player, "LEVEL " .. level .. "!" .. (unlock and ("  UNLOCKED: " .. unlock) or ""), Color3.fromRGB(120, 255, 160))
		awardScrap(player, CONFIG.LEVEL_SCRAP * level, "LEVEL " .. level, true)
	end
	if after > before then
		checkAchievements(player) -- RISING PILOT / VETERAN
	end
end

-- today's 3 quests: the same for everyone (picked from the day number), never two of one kind
local function todaysQuests(profile)
	local day = dayNumber()
	if not profile.quests or profile.quests.day ~= day then
		local pick = Random.new(day)
		local pool = table.clone(QUESTS)
		local list = {}
		while #list < 3 and #pool > 0 do
			local q = table.remove(pool, pick:NextInteger(1, #pool))
			table.insert(list, { id = q.id, progress = 0, done = false })
			for i = #pool, 1, -1 do
				if pool[i].kind == q.kind then
					table.remove(pool, i)
				end
			end
		end
		profile.quests = { day = day, list = list }
	end
	return profile.quests
end

-- something happened: lifetime counts, quest progress, achievements
track = function(player, kind, amount)
	local profile = profiles[player]
	if not profile or not profile.loaded then
		return
	end
	amount = amount or 1
	profile.counts[kind] = (profile.counts[kind] or 0) + amount
	for _, q in ipairs(todaysQuests(profile).list) do
		local def = QUEST_BY_ID[q.id]
		if def and def.kind == kind and not q.done then
			q.progress = math.min(q.progress + amount, def.goal)
			if q.progress >= def.goal then
				q.done = true
				NotifyEvent:FireClient(player, "QUEST DONE: " .. string.upper(def.text), Color3.fromRGB(120, 255, 160))
				awardScrap(player, def.reward, "QUEST", true)
				addXp(player, CONFIG.QUEST_XP)
				queueSave(player)
			end
		end
	end
	checkAchievements(player)
end

-- a chapter was finished: counts for everyone playing (and UNTOUCHED if they never died in it)
chapterCleared = function(chapter)
	for _, plr in ipairs(Players:GetPlayers()) do
		local profile = profiles[plr]
		if profile and profile.chosen then
			track(plr, "chapter" .. chapter, 1)
			if not profile.diedThisChapter then
				track(plr, "untouched", 1)
			end
			track(plr, "chapter", 1)
		end
	end
end

-- a hotel room door was opened (ROOM SERVICE: all 12 rooms of one floor, this session)
trackDoor = function(player, door)
	local profile = profiles[player]
	if not profile then
		return
	end
	track(player, "door", 1)
	local floor = math.floor((door.Position.Y - HOTEL_CENTER.Y) / HOTEL_FLOOR_H) + 1
	local seen = profile.doorFloors[floor]
	if not seen then
		seen = { n = 0 }
		profile.doorFloors[floor] = seen
	end
	local key = door:GetFullName()
	if not seen[key] then
		seen[key] = true
		seen.n = seen.n + 1
		if seen.n == #HOTEL_ROOMS then
			track(player, "fullfloor", 1)
		end
	end
end

-- daily reward: which box is today's, whether it can be claimed
local function dailyStatus(profile)
	local today = dayNumber()
	local claimedToday = profile.lastClaimDay == today
	local alive = claimedToday or profile.lastClaimDay == today - 1
	local streak = alive and profile.streak or 0
	return {
		ok = true,
		canClaim = not claimedToday,
		day = claimedToday and ((streak - 1) % 7 + 1) or (streak % 7 + 1),
		streak = streak,
		rewards = CONFIG.DAILY_REWARDS,
		secondsLeft = secondsToReset(),
		saving = profile.available,
	}
end

-- leaderboard: OrderedDataStores (all servers); this server's players when they're unavailable
local boardStores = {}
pcall(function()
	boardStores.level = DataStoreService:GetOrderedDataStore("Signal85Top_Level_v1")
	boardStores.kills = DataStoreService:GetOrderedDataStore("Signal85Top_Kills_v1")
end)
local boardCache = { level = {}, kills = {}, global = false }
local nameCache = {}

updateBoards = function(player)
	local profile = profiles[player]
	if not profile or not profile.available or not boardStores.level then
		return
	end
	local key = tostring(player.UserId)
	local level, kills = levelInfo(profile.xp), profile.counts.kill or 0
	task.spawn(function()
		pcall(function()
			boardStores.level:SetAsync(key, level)
		end)
		pcall(function()
			boardStores.kills:SetAsync(key, kills)
		end)
	end)
end

local function nameOf(userId)
	if not userId then
		return "?"
	end
	if not nameCache[userId] then
		local ok, name = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		nameCache[userId] = ok and name or ("Pilot " .. userId)
	end
	return nameCache[userId]
end

local function localBoard(kind)
	local rows = {}
	for plr, profile in pairs(profiles) do
		if plr.Parent then
			table.insert(rows, { name = plr.Name, value = kind == "level" and levelInfo(profile.xp) or (profile.counts.kill or 0) })
		end
	end
	table.sort(rows, function(a, b)
		return a.value > b.value
	end)
	while #rows > 10 do
		table.remove(rows)
	end
	return rows
end

-- the TOP PILOTS board in town, by the Scrap Garage, facing the spawn
local boardText = {}
do
	local m = Instance.new("Model")
	m.Name = "TopPilotsBoard"
	local face = CFrame.lookAt(Vector3.new(-8, 8, 220), Vector3.new(0, 8, 200))
	local board = newPart({ Name = "Board", Size = Vector3.new(16, 10, 0.6), CFrame = face, Color = Color3.fromRGB(20, 18, 26),
		Material = Enum.Material.SmoothPlastic, Parent = m })
	newPart({ Name = "BoardTrim", Size = Vector3.new(16.6, 0.5, 0.8), CFrame = face * CFrame.new(0, 5.2, 0), Color = Color3.fromRGB(255, 80, 200),
		Material = Enum.Material.Neon, Parent = m })
	for _, side in ipairs({ -1, 1 }) do
		newPart({ Name = "BoardPost", Size = Vector3.new(0.6, 13, 0.6), CFrame = face * CFrame.new(side * 7.5, -1.5, 0.6),
			Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal, Parent = m })
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = board
	local function label(props)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Code
		l.TextColor3 = Color3.fromRGB(230, 230, 240)
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextYAlignment = Enum.TextYAlignment.Top
		for k, v in pairs(props) do
			l[k] = v
		end
		l.Parent = gui
		return l
	end
	label({ Text = "TOP PILOTS", Font = Enum.Font.Arcade, TextSize = 48, TextColor3 = Color3.fromRGB(255, 80, 200),
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 56) })
	boardText.level = label({ TextSize = 24, Position = UDim2.fromOffset(30, 80), Size = UDim2.fromOffset(360, 360) })
	boardText.kills = label({ TextSize = 24, Position = UDim2.fromOffset(420, 80), Size = UDim2.fromOffset(360, 360) })
	boardText.footer = label({ TextSize = 18, TextColor3 = Color3.fromRGB(150, 150, 165), TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 455), Size = UDim2.new(1, 0, 0, 30) })
	m.Parent = workspace
end

local function drawBoard()
	for _, kind in ipairs({ "level", "kills" }) do
		local lines = { kind == "level" and "HIGHEST LEVEL" or "MOST DEFEATED", "" }
		for i, row in ipairs(boardCache[kind]) do
			table.insert(lines, string.format("%2d. %-14s %s", i, row.name:sub(1, 14), (kind == "level" and "LV " or "") .. row.value))
		end
		if #boardCache[kind] == 0 then
			table.insert(lines, "  (nobody yet)")
		end
		boardText[kind].Text = table.concat(lines, "\n")
	end
	boardText.footer.Text = boardCache.global and "ALL SERVERS - UPDATES EVERY 2 MINUTES" or "THIS SERVER ONLY (ALL SERVERS ONCE THE GAME IS PUBLISHED)"
end

local function refreshBoards()
	local global = false
	for _, kind in ipairs({ "level", "kills" }) do
		local rows
		local store = boardStores[kind]
		if store then
			local ok, page = pcall(function()
				return store:GetSortedAsync(false, 10):GetCurrentPage()
			end)
			if ok and #page > 0 then
				rows = {}
				for _, entry in ipairs(page) do
					table.insert(rows, { name = nameOf(tonumber(entry.key)), value = entry.value })
				end
				global = true
			end
		end
		boardCache[kind] = rows or localBoard(kind)
	end
	boardCache.global = global
	drawBoard()
end

task.spawn(function()
	while true do
		refreshBoards()
		task.wait(boardCache.global and CONFIG.LEADERBOARD_REFRESH or 10)
	end
end)

-- weekend 2x banner (the HUD and menu read this)
task.spawn(function()
	while true do
		ReplicatedStorage:SetAttribute("Weekend2x", isWeekend())
		task.wait(30)
	end
end)

MetaFunction.OnServerInvoke = function(player, action, arg)
	local profile = profiles[player]
	if not profile or not profile.loaded then
		return { ok = false, message = "STILL LOADING - TRY AGAIN" }
	end
	if action == "tutorial" then
		-- "done" (finished: Scrap + FIRST NIGHT once) or "skip"
		if arg ~= "done" and arg ~= "skip" then
			return { ok = false, message = "BAD REQUEST" }
		end
		local first = not profile.tutorialDone
		profile.tutorialDone = true
		if arg == "done" and (profile.counts.tutorial or 0) == 0 then
			awardScrap(player, CONFIG.TUTORIAL_SCRAP, "TUTORIAL", true)
			track(player, "tutorial", 1)
		end
		if first then
			queueSave(player)
		end
		return { ok = true }
	elseif action == "daily" then
		return dailyStatus(profile)
	elseif action == "claim" then
		local status = dailyStatus(profile)
		if not status.canClaim then
			return { ok = false, message = "ALREADY CLAIMED TODAY" }
		end
		profile.streak = status.streak + 1
		profile.lastClaimDay = dayNumber()
		local vip = profile.passes.vip and 2 or 1 -- VIP PILOT: double daily reward
		awardScrap(player, (CONFIG.DAILY_REWARDS[status.day] or 50) * vip, "DAILY REWARD DAY " .. status.day .. (vip > 1 and " VIP" or ""), true)
		if status.day == 7 and not profile.gold then
			profile.gold = true
			NotifyEvent:FireClient(player, "UNLOCKED: GOLD SUIT PAINT", Color3.fromRGB(255, 214, 90))
		end
		checkAchievements(player)
		queueSave(player)
		return dailyStatus(profile)
	elseif action == "quests" then
		local rows = {}
		for _, q in ipairs(todaysQuests(profile).list) do
			local def = QUEST_BY_ID[q.id]
			if def then
				table.insert(rows, { text = def.text, progress = q.progress, goal = def.goal, done = q.done, reward = def.reward })
			end
		end
		return { ok = true, quests = rows, secondsLeft = secondsToReset(), weekend = isWeekend(), xp = CONFIG.QUEST_XP }
	elseif action == "achievements" then
		local rows, unlocked = {}, 0
		for _, a in ipairs(ACHIEVEMENTS) do
			local done = profile.achievements[a.id] == true
			unlocked = unlocked + (done and 1 or 0)
			table.insert(rows, { name = a.name, hint = a.hint, reward = a.reward, unlocked = done,
				progress = a.count and math.min(profile.counts[a.count] or 0, a.goal) or nil, goal = a.goal })
		end
		return { ok = true, achievements = rows, unlocked = unlocked }
	elseif action == "board" then
		return { ok = true, level = boardCache.level, kills = boardCache.kills, global = boardCache.global }
	elseif action == "code" then
		if profile.lastCode and os.clock() - profile.lastCode < 1 then
			return { ok = false, message = "SLOW DOWN" }
		end
		profile.lastCode = os.clock()
		if typeof(arg) ~= "string" or #arg > 40 then
			return { ok = false, message = "UNKNOWN CODE" }
		end
		local code = (string.upper(arg):gsub("%s", ""))
		local reward = CONFIG.CODES[code]
		if not reward then
			return { ok = false, message = "UNKNOWN CODE" }
		elseif profile.codes[code] then
			return { ok = false, message = "ALREADY USED" }
		end
		profile.codes[code] = true
		awardScrap(player, reward, "CODE " .. code, true)
		queueSave(player)
		return { ok = true, message = "+" .. reward .. " SCRAP" }
	end
	return { ok = false, message = "BAD REQUEST" }
end
end -- task 010 section

local function setStage(stage, progress, goal)
	ReplicatedStorage:SetAttribute("Stage", stage)
	ReplicatedStorage:SetAttribute("Goal", goal)
	ReplicatedStorage:SetAttribute("Progress", progress)
	checkpoint() -- auto-save on every stage change (and so on every chapter start)
end

local function stageIs(stage)
	return not transitioning and ReplicatedStorage:GetAttribute("Stage") == stage
end

-- ambient Hollowers: Chapter 1 shards and Chapter 3 files, faster and more while Hive Nodes live
task.spawn(function()
	while true do
		task.wait(stageIs("Nodes") and CONFIG.CH2_CREATURE_SPAWN_INTERVAL or CONFIG.CREATURE_SPAWN_INTERVAL)
		-- (Relays and Carrier spawn their own attackers)
		local cap = ((stageIs("Shards") or stageIs("Files")) and CONFIG.MAX_CREATURES)
			or (stageIs("Nodes") and CONFIG.CH2_MAX_CREATURES)
			or (stageIs("Relays") and 6)
			or 0
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

-- at: optional floor point (used for shards hidden in the Grand Hotel)
local function spawnShard(at)
	local spot = at or randomOpenPoint(undergrid, CONFIG.UNDERGRID_OFFSET)
	local shard = newPart({ Name = "SignalShard", Size = Vector3.new(1.4, 3, 1.4), CFrame = CFrame.new(spot + Vector3.new(0, 3, 0)),
		Color = GLOW, Material = Enum.Material.Neon, CanCollide = false, Parent = shardFolder })
	shard:SetAttribute("InHotel", at ~= nil)
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
				-- up to 2 shards at a time are hidden in rooms of the Undergrid Grand Hotel (floors 2-4)
				local inHotel = 0
				for _, s in ipairs(shardFolder:GetChildren()) do
					if s:GetAttribute("InHotel") then
						inHotel = inHotel + 1
					end
				end
				if inHotel < 2 then
					spawnShard(hotelSpot(rng:NextInteger(2, 4), HOTEL_ROOMS[rng:NextInteger(1, #HOTEL_ROOMS)], true))
				else
					spawnShard()
				end
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
	awardEveryone(CONFIG.SCRAP_CHAPTER, "CHAPTER 1 COMPLETE")
	chapterCleared(1)
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
	if plr and stageIs("Race") and plr:GetAttribute("Dimension") == "Town" then
		chapter3Complete(true) -- Chapter 3: the shutdown code reached the radio tower
		return
	end
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
	awardScrap(plr, CONFIG.SCRAP_SHARD * carrying, "SHARDS DELIVERED")
	track(plr, "shard", carrying)
	track(plr, "objective", carrying)
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

-- attacker: optional player, rewarded with Scrap for destroying it
local function damageNode(m, amount, attacker)
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
	if attacker then
		awardScrap(attacker, CONFIG.SCRAP_NODE, "HIVE NODE")
		track(attacker, "objective", 1)
	end
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
-- (inside a do-block to stay under Luau's 200 top-level locals; these four are used outside it)
local boss, clearBoss, chapter2Complete, damageBoss
do
local bossFolder = Instance.new("Folder")
bossFolder.Name = "Boss"
bossFolder.Parent = workspace

local BOSS_SCALE = 4
local BOSS_SPOT = CONFIG.UNDERGRID_OFFSET + Vector3.new(0, 0, -200) -- ground point south of the tower (tower at z -238)
local BOSS_HEIGHT = 5.5 * BOSS_SCALE                               -- body centre above the ground
local WEAK = Color3.fromRGB(255, 235, 140)

boss = nil -- { model, parts, petals, maw, weak, light, yaw, open, openTarget, shake, glow, slam, alive, vulnerable, hp, maxHp }

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

clearBoss = function()
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
					hurtPlayer(t.plr, t.hum, CONFIG.BOSS_SHOCKWAVE_DAMAGE * (vehicle and 0.5 or 1))
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

-- announce: false when a save is restored straight into "Complete" (go on to Chapter 3 at once)
chapter2Complete = function(announce)
	local token = chapterToken
	transitioning = true
	setStage("Complete", 1, 1)
	clearCreatures()
	clearNodes()
	if announce then
		notifyAll("CHAPTER 2 COMPLETE — THE SIGNAL GOES QUIET", GREEN)
		awardEveryone(CONFIG.SCRAP_BOSS, "MIND WARDEN DEFEATED")
		task.delay(1.5, awardEveryone, CONFIG.SCRAP_CHAPTER, "CHAPTER 2 COMPLETE")
		chapterCleared(2)
		task.delay(6, function()
			if token == chapterToken then
				notifyAll("...BUT THE TOWER IS PICKING SOMETHING UP AGAIN", WARN)
			end
		end)
	end
	task.delay(announce and CONFIG.CHAPTER_PAUSE + 4 or 0, function()
		if token == chapterToken then
			startChapter(3)
		end
	end)
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
damageBoss = function(amount)
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
	ReplicatedStorage:SetAttribute("BossName", "THE MIND WARDEN")
	ReplicatedStorage:SetAttribute("BossMaxHealth", maxHp)
	ReplicatedStorage:SetAttribute("BossHealth", maxHp)
	setStage("Boss", 0, maxHp)
	notifyAll("THE MIND WARDEN AWAKENS", WARN)
	spawnBoss(maxHp)
	task.spawn(bossLoop, chapterToken)
end
end -- Mind Warden section

---------------------------------------------------------------------------
-- Chapter 3: LOWBAND (story in docs/STORY.md)
--   Files    collect the LOWBAND files in the lab: some in town, some in its Undergrid copy
--   Relays   stand in the 3 relay circles around the Undergrid lab until each is full
--   Carrier  protect the Carrier (Undergrid lab) for CARRIER_DEFEND_TIME; if it breaks, try again
--   Race     take the shutdown code to the radio tower console within RACE_TIME; if late, try again
--   Walkie-talkie lines from Dot and Ricky go out through RadioEvent.
---------------------------------------------------------------------------
-- (most of this section is inside a do-block: Luau allows 200 locals at the top level)
local radioLater, FILES, fileFolder, relays, spawnFile, clearChapter3 -- used outside the section
local startRelays, startCarrierStage, startRace -- defined below
do
local LOWBAND_YELLOW = Color3.fromRGB(255, 220, 120)
local CARRIER_PINK = Color3.fromRGB(255, 120, 200)

local function radio(speaker, text)
	RadioEvent:FireAllClients(speaker, text)
end

-- radio lines that wait a bit, and are dropped if the chapter changed meanwhile
radioLater = function(seconds, speaker, text)
	local token = chapterToken
	task.delay(seconds, function()
		if token == chapterToken then
			radio(speaker, text)
		end
	end)
end

-- the files, in spawn order; world = which side of the rift it lies on
FILES = {
	{ offset = Vector3.new(-26, 0, -22), world = "Town" },
	{ offset = Vector3.new(22, 0, -24), world = "Undergrid" },
	{ offset = Vector3.new(-30, 0, 22), world = "Town" },
	{ pos = hotelSpot(HOTEL_FLOORS, Vector2.new(0, 32), true), world = "Undergrid" }, -- in the Grand Hotel penthouse suite (room 509)
	{ offset = Vector3.new(-4, 0, -12), world = "Town" },
}
-- what the kids say after the 1st, 2nd... file is found
local FILE_LINES = {
	{ "DOT", "File 1: 'Project LOWBAND, 1977. Goal: listen to other frequencies.'" },
	{ "RICKY", "File 2 is a map of the Undergrid! They KNEW about it!" },
	{ "DOT", "File 3 says they built you to go where people can't. Wow." },
	{ "RICKY", "File 4: 'The Carrier is listening back.' That's not creepy at all..." },
	{ "DOT", "Last file: the Carrier must be shut down slowly. It needs power from three relays on the other side." },
}

fileFolder = Instance.new("Folder")
fileFolder.Name = "LowbandFiles"
fileFolder.Parent = workspace

local relayFolder = Instance.new("Folder")
relayFolder.Name = "Relays"
relayFolder.Parent = workspace

local carrierFolder = Instance.new("Folder")
carrierFolder.Name = "Carrier"
carrierFolder.Parent = workspace

relays = {}          -- [model] = { center, charge, done, pad, top, fill, label, lastSpawn, spawns }
local carrier = nil  -- { model, core, hp, maxHp, failed }

-- Files ---------------------------------------------------------------------
local function collectFile(file, plr)
	if file:GetAttribute("Taken") or not stageIs("Files") then
		return
	end
	file:SetAttribute("Taken", true)
	file:Destroy()
	local goal = ReplicatedStorage:GetAttribute("Goal")
	local progress = math.min(ReplicatedStorage:GetAttribute("Progress") + 1, goal)
	ReplicatedStorage:SetAttribute("Progress", progress)
	notifyAll("LOWBAND FILE FOUND [" .. progress .. "/" .. goal .. "]", LOWBAND_YELLOW)
	awardScrap(plr, CONFIG.SCRAP_FILE, "LOWBAND FILE")
	track(plr, "objective", 1)
	local line = FILE_LINES[progress]
	if line then
		radio(line[1], line[2])
	end
	if progress >= goal then
		local token = chapterToken
		task.delay(5, function()
			if token == chapterToken then
				startRelays(0)
			end
		end)
	end
end

spawnFile = function(index)
	local f = FILES[index]
	local world = f.world == "Undergrid" and CONFIG.UNDERGRID_OFFSET or Vector3.zero
	local base = f.pos or (LAB_CENTER + f.offset + world) -- f.pos: a fixed spot (the hotel penthouse)
	local file = newPart({ Name = "LowbandFile", Size = Vector3.new(2.4, 0.4, 1.8), Position = base + Vector3.new(0, 3, 0),
		Color = LOWBAND_YELLOW, Material = Enum.Material.Neon, CanCollide = false, Parent = fileFolder })
	file:SetAttribute("Dimension", f.world)
	local light = Instance.new("PointLight")
	light.Color = LOWBAND_YELLOW
	light.Range = 16
	light.Brightness = 2
	light.Parent = file
	file.Touched:Connect(function(hit)
		local plr = Players:GetPlayerFromCharacter(hit.Parent)
		if plr and plr:GetAttribute("Dimension") == f.world then
			collectFile(file, plr)
		end
	end)
end

RunService.Heartbeat:Connect(function(dt)
	for _, file in ipairs(fileFolder:GetChildren()) do
		file.CFrame = file.CFrame * CFrame.Angles(0, dt * 1.5, 0)
	end
end)

-- Relays --------------------------------------------------------------------
local RELAY_OFFSETS = { Vector3.new(0, 0, -62), Vector3.new(-60, 0, 8), Vector3.new(0, 0, 60) } -- around the lab

local function setRelayLook(r)
	local color = r.done and GREEN or (r.charge > 0 and LOWBAND_YELLOW or WARN)
	r.pad.Color = color
	r.top.Color = color
	r.fill.Size = UDim2.fromScale(r.charge / CONFIG.RELAY_TIME, 1)
	r.fill.BackgroundColor3 = color
	r.label.Text = r.done and "RELAY ONLINE" or ("RELAY " .. math.floor(r.charge / CONFIG.RELAY_TIME * 100) .. "%")
end

local function spawnRelay(index, done)
	local center = LAB_CENTER + RELAY_OFFSETS[index] + CONFIG.UNDERGRID_OFFSET
	local m = Instance.new("Model")
	m.Name = "Relay"
	local pad = newPart({ Name = "Pad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, CONFIG.RELAY_RADIUS * 2, CONFIG.RELAY_RADIUS * 2),
		CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = WARN, Material = Enum.Material.Neon,
		Transparency = 0.55, CanCollide = false, CanQuery = false, Parent = m })
	newPart({ Name = "Pylon", Size = Vector3.new(2, 10, 2), Position = center + Vector3.new(0, 5, 0), Color = Color3.fromRGB(60, 60, 70),
		Material = Enum.Material.Metal, Parent = m })
	local top = newPart({ Name = "Top", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), Position = center + Vector3.new(0, 11, 0), Color = WARN,
		Material = Enum.Material.Neon, CanCollide = false, Parent = m })
	local light = Instance.new("PointLight")
	light.Range = 24
	light.Brightness = 2
	light.Parent = top

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 40)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 200
	gui.AlwaysOnTop = true
	gui.Parent = top
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 22)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Arcade
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 26)
	back.Size = UDim2.new(1, 0, 0, 10)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.Parent = back

	m.PrimaryPart = top
	m:SetAttribute("Done", done)
	m.Parent = relayFolder
	local r = { center = center, charge = done and CONFIG.RELAY_TIME or 0, done = done, pad = pad, top = top, fill = fill, label = label,
		lastSpawn = os.clock(), spawns = 0 }
	relays[m] = r
	setRelayLook(r)
end

local function clearRelays()
	for m in pairs(relays) do
		m:Destroy()
	end
	table.clear(relays)
end

local RELAY_LINES = {
	{ "RICKY", "One relay up! The lights in town are flickering - hurry!" },
	{ "RICKY", "Two down! One more!" },
	{ "DOT", "All power is back. The Carrier is waking up - protect it while it shuts down!" },
}

local function completeRelay(m, r, inside)
	r.done = true
	m:SetAttribute("Done", true)
	setRelayLook(r)
	burst(r.center + Vector3.new(0, 11, 0), GREEN, 20)
	local goal = ReplicatedStorage:GetAttribute("Goal")
	local progress = math.min(ReplicatedStorage:GetAttribute("Progress") + 1, goal)
	ReplicatedStorage:SetAttribute("Progress", progress)
	notifyAll("POWER RELAY ONLINE [" .. progress .. "/" .. goal .. "]", GREEN)
	for _, t in ipairs(inside) do
		awardScrap(t.plr, CONFIG.SCRAP_RELAY, "RELAY")
		track(t.plr, "objective", 1)
	end
	local line = RELAY_LINES[progress]
	if line then
		radio(line[1], line[2])
	end
	if progress >= goal then
		local token = chapterToken
		task.delay(5, function()
			if token == chapterToken then
				startCarrierStage()
			end
		end)
	end
end

startRelays = function(done)
	done = math.clamp(done, 0, #RELAY_OFFSETS - 1)
	fileFolder:ClearAllChildren()
	clearRelays()
	setStage("Relays", done, #RELAY_OFFSETS)
	for i = 1, #RELAY_OFFSETS do
		spawnRelay(i, i <= done)
	end
end

-- relays charge while a player stands in them, and attract creatures meanwhile
task.spawn(function()
	while true do
		local dt = task.wait(0.2)
		if stageIs("Relays") then
			local players = playersInUndergrid()
			local now = os.clock()
			for m, r in pairs(relays) do
				if not r.done then
					local inside = {}
					for _, t in ipairs(players) do
						if (Vector3.new(t.hrp.Position.X, 0, t.hrp.Position.Z) - Vector3.new(r.center.X, 0, r.center.Z)).Magnitude <= CONFIG.RELAY_RADIUS then
							table.insert(inside, t)
						end
					end
					if #inside > 0 then
						r.charge = math.min(r.charge + dt, CONFIG.RELAY_TIME)
						setRelayLook(r)
						if now - r.lastSpawn >= CONFIG.RELAY_SPAWN_INTERVAL and creatureCount() < CONFIG.CH3_MAX_CREATURES then
							r.lastSpawn = now
							r.spawns = r.spawns + 1
							local a = rng:NextNumber(0, math.pi * 2)
							local spot = r.center + Vector3.new(math.cos(a) * 30, 0, math.sin(a) * 30)
							if r.spawns % 2 == 1 then
								spawnHoundPack(spot)
							else
								spawnCreature(spot)
							end
						end
						if r.charge >= CONFIG.RELAY_TIME then
							completeRelay(m, r, inside)
						end
					end
				end
			end
		end
	end
end)

-- Carrier -------------------------------------------------------------------
local function clearCarrier()
	if carrier then
		carrier.failed = true
		carrier.model:Destroy()
		carrier = nil
	end
	carrierTarget = nil
	ReplicatedStorage:SetAttribute("BossName", "")
	ReplicatedStorage:SetAttribute("BossMaxHealth", 0)
	ReplicatedStorage:SetAttribute("BossHealth", 0)
	ReplicatedStorage:SetAttribute("Deadline", 0)
end

damageCarrier = function(amount)
	if not carrier or carrier.failed then
		return
	end
	carrier.hp = math.max(carrier.hp - amount, 0)
	ReplicatedStorage:SetAttribute("BossHealth", carrier.hp)
	if carrier.hp > 0 then
		return
	end
	-- it broke: try the defence again
	carrier.failed = true
	burst(carrier.core.Position, CARRIER_PINK, 40)
	notifyAll("THE CARRIER OVERLOADED - TRY AGAIN", WARN)
	radio("RICKY", "Noooo! Okay, okay - Dot says it can restart. Protect it this time!")
	local token = chapterToken
	task.delay(6, function()
		if token == chapterToken then
			startCarrierStage()
		end
	end)
end

startCarrierStage = function()
	fileFolder:ClearAllChildren()
	clearRelays()
	clearCarrier()
	clearCreatures()

	local m = Instance.new("Model")
	m.Name = "CarrierCore"
	local core = newPart({ Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 7, 7),
		Position = LAB_CENTER + CARRIER_OFFSET + CONFIG.UNDERGRID_OFFSET + Vector3.new(0, 10, 0), Color = CARRIER_PINK,
		Material = Enum.Material.Neon, CanCollide = false, Parent = m })
	local light = Instance.new("PointLight")
	light.Color = CARRIER_PINK
	light.Range = 40
	light.Brightness = 4
	light.Parent = core
	m.PrimaryPart = core
	m.Parent = carrierFolder

	local mine = { model = m, core = core, hp = CONFIG.CARRIER_HEALTH, maxHp = CONFIG.CARRIER_HEALTH, failed = false }
	carrier = mine
	carrierTarget = core
	ReplicatedStorage:SetAttribute("BossName", "THE CARRIER")
	ReplicatedStorage:SetAttribute("BossMaxHealth", mine.maxHp)
	ReplicatedStorage:SetAttribute("BossHealth", mine.hp)
	ReplicatedStorage:SetAttribute("Deadline", workspace:GetServerTimeNow() + CONFIG.CARRIER_DEFEND_TIME)
	setStage("Carrier", 0, CONFIG.CARRIER_DEFEND_TIME)
	notifyAll("DEFEND THE CARRIER WHILE IT SHUTS DOWN!", CARRIER_PINK)

	task.spawn(function()
		local start = os.clock()
		local lastWave = -math.huge
		local saidHalfway = false
		while carrier == mine and not mine.failed do
			task.wait(0.5)
			local elapsed = os.clock() - start
			ReplicatedStorage:SetAttribute("Progress", math.min(math.floor(elapsed), CONFIG.CARRIER_DEFEND_TIME))
			-- the core pulses faster as it powers down
			core.Size = Vector3.one * (6.5 + math.sin(elapsed * (2 + elapsed / 20)) * 0.8)
			if elapsed >= CONFIG.CARRIER_DEFEND_TIME then
				clearCarrier()
				clearCreatures()
				radio("DOT", "It printed a code! Get it to the radio tower console - in a car, FAST!")
				startRace()
				return
			end
			if not saidHalfway and elapsed >= CONFIG.CARRIER_DEFEND_TIME / 2 then
				saidHalfway = true
				radio("RICKY", "Halfway there! Don't let them break it!")
			end
			if elapsed - lastWave >= CONFIG.CARRIER_WAVE_INTERVAL then
				lastWave = elapsed
				for _ = 1, 2 do
					if creatureCount() < CONFIG.CARRIER_MAX_CREATURES then
						local a = rng:NextNumber(0, math.pi * 2)
						local r = rng:NextNumber(55, 80)
						local spot = core.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
						spawnCreature(Vector3.new(spot.X, CONFIG.UNDERGRID_OFFSET.Y, spot.Z))
					end
				end
				if creatureCount() < CONFIG.CARRIER_MAX_CREATURES then
					local a = rng:NextNumber(0, math.pi * 2)
					local spot = core.Position + Vector3.new(math.cos(a) * 70, 0, math.sin(a) * 70)
					spawnHoundPack(Vector3.new(spot.X, CONFIG.UNDERGRID_OFFSET.Y, spot.Z))
				end
			end
		end
	end)
end

-- Race ----------------------------------------------------------------------
startRace = function()
	local token = chapterToken
	setStage("Race", 0, CONFIG.RACE_TIME)
	local deadline = workspace:GetServerTimeNow() + CONFIG.RACE_TIME
	ReplicatedStorage:SetAttribute("Deadline", deadline)
	notifyAll("RACE! GET THE CODE TO THE RADIO TOWER CONSOLE!", LOWBAND_YELLOW)
	task.spawn(function()
		while token == chapterToken and stageIs("Race") and ReplicatedStorage:GetAttribute("Deadline") == deadline do
			task.wait(0.5)
			local left = deadline - workspace:GetServerTimeNow()
			ReplicatedStorage:SetAttribute("Progress", math.clamp(math.floor(CONFIG.RACE_TIME - left), 0, CONFIG.RACE_TIME))
			if left <= 0 then
				notifyAll("TOO LATE - THE CODE EXPIRED", WARN)
				radio("RICKY", "Too slow, the code expired! It's printing a new one - GO!")
				task.wait(3)
				if token == chapterToken and stageIs("Race") then
					startRace()
				end
				return
			end
		end
	end)
end

-- announce: false when a save is restored straight into "Complete"
chapter3Complete = function(announce)
	local token = chapterToken
	clearCarrier()
	clearCreatures()
	setStage("Complete", 1, 1)
	if not announce then
		return
	end
	radio("WHCK", "This is WHCK 85.5, Hollow Creek... if you can hear this - it's working!")
	notifyAll("CHAPTER 3 COMPLETE — THE CARRIER IS SILENT", GREEN)
	awardEveryone(CONFIG.SCRAP_CHAPTER, "CHAPTER 3 COMPLETE")
	chapterCleared(3)
	radioLater(7, "DOT", "...it stopped. It really stopped.")
	radioLater(13, "RICKY", "Wait. Do you hear that? One pulse... from way down below.")
	task.delay(18, function()
		if token == chapterToken then
			notifyAll("LAST FILE: 'LOWBAND WAS NOT THE FIRST. SITE 2.'", LOWBAND_YELLOW)
		end
	end)
	-- calm for a moment, then Chapter 4 (Site 2, in ServerScriptService.Chapters)
	task.delay(23 + CONFIG.CHAPTER_PAUSE, function()
		if token == chapterToken then
			startChapter(4)
		end
	end)
end

clearChapter3 = function()
	fileFolder:ClearAllChildren()
	clearRelays()
	clearCarrier()
end
end -- Chapter 3 section

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
				chapter2Complete(false) -- goes straight on to Chapter 3
			else
				local done = math.clamp(stageState.progress or 0, 0, CONFIG.CH2_NODES - 1)
				setStage("Nodes", done, CONFIG.CH2_NODES)
				local taken = {}
				-- the first two grow in the Undergrid Grand Hotel: the ballroom and the roof
				local hotelNodes = { hotelSpot(1, Vector2.new(0, 0), true), hotelSpot(HOTEL_FLOORS + 1, Vector2.new(-42, 0), true) }
				for i = 1, CONFIG.CH2_NODES - done do
					local spot = hotelNodes[i] or pickNodeSpot(taken)
					table.insert(taken, spot)
					spawnNode(spot)
				end
			end
		end,
	},
	[3] = {
		title = "LOWBAND",
		-- stageState.stage = "Files" (default) | "Relays" | "Carrier" | "Complete"; progress = files found / relays online
		start = function(stageState)
			local stage = stageState.stage or "Files"
			if stage == "Relays" then
				startRelays(stageState.progress or 0)
			elseif stage == "Carrier" or stage == "Race" then
				startCarrierStage()
			elseif stage == "Complete" then
				chapter3Complete(false)
			else
				local done = math.clamp(stageState.progress or 0, 0, CONFIG.CH3_FILES - 1)
				setStage("Files", done, CONFIG.CH3_FILES)
				for i = done + 1, CONFIG.CH3_FILES do
					spawnFile(i)
				end
				if done == 0 then
					radioLater(3, "DOT", "...is anyone there? This is Dot, on channel 4. The tower picked up the signal again - weaker, but it's back.")
					radioLater(10, "RICKY", "Ricky here. My dad says it's coming from the old LOWBAND lab in the woods west of town. Nobody's been in there since '79.")
					radioLater(17, "DOT", "Shiftframes... that's where you came from, isn't it? Find their files. Be careful.")
				end
			end
		end,
	},
	-- Chapters 4+ live in ModuleScripts (ServerScriptService.Chapters.ChapterN), loaded below
}

--[[
	Chapter modules (task 013+). Each ModuleScript "ChapterN" returns function(api) -> def:
	  def.title, def.start(stageState), def.clear()
	  optional def.damageTarget(model, amount, player) -> damaged, killed  (models with attribute Target)
	  optional def.targets() -> { { model = Model, center = Vector3 } }  (for the Shock Baton)
	They live outside this script so it stays under Luau's 200-locals limit.
]]
local chapterHooks = { damage = {}, targets = {} }
do
	local api = {
		CONFIG = CONFIG, WEAPONS = WEAPONS, rng = rng, Players = Players, ReplicatedStorage = ReplicatedStorage,
		TweenService = TweenService, Debris = Debris, RunService = RunService,
		remotes = { Notify = NotifyEvent, Radio = RadioEvent },
		newPart = newPart, sparkBurst = sparkBurst, notifyAll = notifyAll,
		radioLater = radioLater, setStage = setStage, stageIs = stageIs, checkpoint = checkpoint,
		token = function()
			return chapterToken
		end,
		setTransitioning = function(on)
			transitioning = on
		end,
		startChapter = function(n, stageState)
			startChapter(n, stageState)
		end,
		awardScrap = awardScrap, awardEveryone = awardEveryone, chapterCleared = chapterCleared, track = track,
		hurtPlayer = hurtPlayer, sendHome = sendHome, state = state, profiles = profiles,
		creatures = creatures, creatureFolder = creatureFolder, creatureCount = creatureCount, addHealthBar = addHealthBar,
		updateHealthBar = updateHealthBar,
		hasChapter = function(n)
			return CHAPTERS[n] ~= nil
		end,
		spawnCreature = spawnCreature, spawnHoundPack = spawnHoundPack, clearCreatures = clearCreatures,
		playersInUndergrid = playersInUndergrid,
		town = town, undergrid = undergrid, console = console, randomOpenPoint = randomOpenPoint,
		hotelSpot = hotelSpot, HOTEL_CENTER = HOTEL_CENTER, HOTEL_FLOORS = HOTEL_FLOORS, HOTEL_FLOOR_H = HOTEL_FLOOR_H,
		HOTEL_ROOMS = HOTEL_ROOMS, HOTEL_HALF = HOTEL_HALF,
		colors = { GREEN = GREEN, WARN = WARN, GLOW = GLOW },
		shared = {}, -- for chapter modules to share things (Chapter 4: openSite2, spawnEcho)
	}
	local folder = script.Parent:FindFirstChild("Chapters")
	for _, mod in ipairs(folder and folder:GetChildren() or {}) do
		local n = mod:IsA("ModuleScript") and tonumber(mod.Name:match("^Chapter(%d+)$"))
		if n then
			local ok, def = pcall(function()
				return require(mod)(api)
			end)
			if ok and type(def) == "table" and def.start then
				CHAPTERS[n] = def
				if def.damageTarget then
					table.insert(chapterHooks.damage, def.damageTarget)
				end
				if def.targets then
					table.insert(chapterHooks.targets, def.targets)
				end
			else
				warn("[Chapters] " .. mod.Name .. " failed to load: " .. tostring(def))
			end
		end
	end
end

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
	clearChapter3()
	for _, def in pairs(CHAPTERS) do
		if def.clear then
			def.clear() -- chapter modules (4+)
		end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		sendHome(plr)
		plr:SetAttribute("Carrying", 0)
		local profile = profiles[plr]
		if profile then
			profile.bestChapter = math.max(profile.bestChapter, chapter) -- unlocks it in CHAPTER SELECT
			profile.diedThisChapter = false -- UNTOUCHED: no deaths from here to the end of the chapter
		end
	end

	ReplicatedStorage:SetAttribute("Chapter", chapter)
	ReplicatedStorage:SetAttribute("ChapterTitle", CHAPTERS[chapter].title)
	setHotelTheme(chapter)
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
	if not s or not hum or hum.Health <= 0 or not s.ready or char:GetAttribute("Downed") then
		return
	end
	if os.clock() - s.lastTransform < CONFIG.TRANSFORM_COOLDOWN then
		return
	end
	s.lastTransform = os.clock()
	-- F: pilot -> robot -> car -> robot
	setMode(player, s.mode == "Robot" and "Vehicle" or "Robot")
	track(player, "transform", 1)
end)

-- G / SUIT: pilot <-> robot. Taking the suit off only works in Hollow Creek.
SuitEvent.OnServerEvent:Connect(function(player)
	local s = state[player]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not s or not hum or hum.Health <= 0 or not s.ready or char:GetAttribute("Downed") then
		return
	end
	if os.clock() - s.lastTransform < CONFIG.TRANSFORM_COOLDOWN then
		return
	end
	if s.mode == "Pilot" then
		s.lastTransform = os.clock()
		setMode(player, "Robot")
	elseif player:GetAttribute("Dimension") == "Town" then
		s.lastTransform = os.clock()
		setMode(player, "Pilot")
	else
		NotifyEvent:FireClient(player, "TOO DANGEROUS - STAY SUITED UP IN THE UNDERGRID", Color3.fromRGB(255, 60, 70))
	end
end)

-- damage whatever enemy a shot hit. true = damaged, "deflect" = boss head closed, nil = not an enemy.
-- The shooter gets a Hit event for the damage number and hit marker.
local function hitEnemy(model, player, weapon, amount, position)
	local damaged, killed = nil, false
	if model:GetAttribute("Creature") then
		damageCreature(model, amount, player)
		damaged, killed = true, (model:GetAttribute("Health") or 0) <= 0
	elseif model:GetAttribute("Node") then
		damageNode(model, amount, player)
		damaged, killed = true, (model:GetAttribute("Health") or 0) <= 0
	elseif model:GetAttribute("Boss") then
		amount = amount * weapon.bossMult
		damaged = damageBoss(amount) or "deflect"
		killed = damaged == true and (ReplicatedStorage:GetAttribute("BossHealth") or 0) <= 0
	elseif model:GetAttribute("Target") then
		-- objectives from the chapter modules (Echo Pylons...): their damageTarget returns damaged, killed
		for _, damage in ipairs(chapterHooks.damage) do
			local d, k = damage(model, amount, player)
			if d then
				damaged, killed = true, k == true
				break
			end
		end
	end
	if damaged == true then
		HitEvent:FireClient(player, position, math.floor(amount + 0.5), killed)
	end
	return damaged
end

-- one pellet: raycast, passing through up to weapon.pierce enemies, then splash and visuals
local function firePellet(player, char, origin, dir, weapon)
	local exclude = { char }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local start, remaining = origin, weapon.range
	local hitPos = origin + dir * weapon.range
	local hitSomething = false
	local impactColor = weapon.color
	local damaged = {}
	local hits = 0

	while remaining > 1 do
		params.FilterDescendantsInstances = exclude
		local result = workspace:Raycast(start, dir * remaining, params)
		if not result then
			hitPos = start + dir * remaining
			break
		end
		hitPos = result.Position
		hitSomething = true
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		local outcome = model and hitEnemy(model, player, weapon, weapon.damage, result.Position)
		if outcome == "deflect" then
			impactColor = Color3.fromRGB(150, 150, 160) -- the Mind Warden's head is closed
		end
		if outcome ~= true then
			break
		end
		damaged[model] = true
		hits = hits + 1
		if hits >= weapon.pierce then
			break
		end
		table.insert(exclude, model) -- pierce: keep going through this enemy
		remaining = remaining - (hitPos - start).Magnitude
		start = hitPos
	end

	-- splash: Hollowers and Hive Nodes near the impact take part of the damage
	if hitSomething and weapon.splash > 0 then
		local splash = weapon.damage * weapon.splashFrac
		for m in pairs(creatures) do
			if not damaged[m] and m.PrimaryPart and (m.PrimaryPart.Position - hitPos).Magnitude <= weapon.splash then
				damageCreature(m, splash, player)
			end
		end
		for m, data in pairs(nodes) do
			if not damaged[m] and (data.center - hitPos).Magnitude <= weapon.splash + 4 then
				damageNode(m, splash, player)
			end
		end
	end

	-- bolt + impact flash
	local len = (hitPos - origin).Magnitude
	local bolt = newPart({ Name = "Bolt", Size = Vector3.new(weapon.width, weapon.width, len),
		CFrame = CFrame.lookAt(origin, hitPos) * CFrame.new(0, 0, -len / 2), Color = weapon.color,
		Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false, Parent = workspace })
	Debris:AddItem(bolt, 0.1)
	local flash = newPart({ Name = "Impact", Shape = Enum.PartType.Ball, Size = Vector3.one * math.max(weapon.splash * 0.6, 2), Position = hitPos,
		Color = impactColor, Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false, CanQuery = false,
		CanTouch = false, Parent = workspace })
	Debris:AddItem(flash, 0.15)
	if hitSomething then
		sparkBurst(hitPos, impactColor, 10, 25, 0.35, 0.35)
	end
	-- muzzle flash at the arm
	local muzzle = newPart({ Name = "Muzzle", Shape = Enum.PartType.Ball, Size = Vector3.one * (weapon.width * 2.5 + 0.6),
		Position = origin + dir * 1.5, Color = weapon.color, Material = Enum.Material.Neon, Transparency = 0.2,
		CanCollide = false, CanQuery = false, CanTouch = false, Parent = workspace })
	Debris:AddItem(muzzle, 0.06)
end

-- Shock Baton: everything within reach in front of you takes the hit, walls or not
local function meleeStrike(player, hrp, aim, weapon)
	local flatAim = Vector3.new(aim.X, 0, aim.Z)
	local facing = flatAim.Magnitude > 0.1 and flatAim.Unit or hrp.CFrame.LookVector
	local function inFront(position, reach)
		local to = position - hrp.Position
		local flat = Vector3.new(to.X, 0, to.Z)
		return to.Magnitude <= reach and (flat.Magnitude < 2 or flat.Unit:Dot(facing) > -0.2)
	end
	for m in pairs(creatures) do
		if m.PrimaryPart and inFront(m.PrimaryPart.Position, weapon.range) then
			hitEnemy(m, player, weapon, weapon.damage, m.PrimaryPart.Position)
		end
	end
	for m, data in pairs(nodes) do
		if inFront(data.center, weapon.range + 4) then
			hitEnemy(m, player, weapon, weapon.damage, data.center)
		end
	end
	if boss and boss.alive and inFront(boss.weak.Position, weapon.range + 6) then
		hitEnemy(boss.model, player, weapon, weapon.damage, boss.weak.Position)
	end
	for _, list in ipairs(chapterHooks.targets) do -- chapter-module objectives: { { model, center } }
		for _, t in ipairs(list()) do
			if inFront(t.center, weapon.range + 4) then
				hitEnemy(t.model, player, weapon, weapon.damage, t.center)
			end
		end
	end
	-- a crackling arc in front of you
	local center = hrp.Position + facing * (weapon.range * 0.5)
	sparkBurst(center, weapon.color, 30, 25, 0.5, 0.35)
	local arc = newPart({ Name = "BatonArc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, weapon.range * 1.6, weapon.range * 1.6),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), Color = weapon.color, Material = Enum.Material.Neon,
		Transparency = 0.5, CanCollide = false, CanQuery = false, CanTouch = false, Parent = workspace })
	TweenService:Create(arc, TweenInfo.new(0.2), { Transparency = 1 }):Play()
	Debris:AddItem(arc, 0.25)
end

BlastEvent.OnServerEvent:Connect(function(player, aimPoint)
	if typeof(aimPoint) ~= "Vector3" then
		return
	end
	local s = state[player]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not s or not hrp or not hum or hum.Health <= 0 or s.mode ~= "Robot" or char:GetAttribute("Downed") then
		return
	end
	local weapon = equippedWeapon(player)
	if os.clock() - s.lastBlast < weapon.cooldown * 0.9 then -- small allowance for network jitter
		return
	end
	s.lastBlast = os.clock()

	local origin = hrp.Position + Vector3.new(0, 1.5, 0)
	local aim = aimPoint - origin
	if aim.Magnitude < 1 then
		return
	end
	if weapon.melee then
		meleeStrike(player, hrp, aim, weapon)
		return
	end
	if not useAmmo(player, weapon) then
		return -- reloading, or out of ammo
	end
	local forward = CFrame.lookAt(Vector3.zero, aim.Unit)
	for _ = 1, weapon.pellets do
		local dir = forward.LookVector
		if weapon.spread > 0 then
			local sx, sy = math.rad(rng:NextNumber(-weapon.spread, weapon.spread)), math.rad(rng:NextNumber(-weapon.spread, weapon.spread))
			dir = (forward * CFrame.Angles(sx, sy, 0)).LookVector
		end
		firePellet(player, char, origin, dir, weapon)
	end
end)

ShiftEvent.OnServerEvent:Connect(function(player)
	local s = state[player]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not s or not hrp or transitioning or char:GetAttribute("Downed") then
		return
	end
	if os.clock() - s.lastShift < CONFIG.SHIFT_COOLDOWN then
		return
	end
	local inTown = player:GetAttribute("Dimension") == "Town"
	local nearRift = false
	for _, pair in ipairs(RIFTS) do
		local riftPos = inTown and pair.town or pair.town + CONFIG.UNDERGRID_OFFSET
		if (hrp.Position - riftPos).Magnitude <= CONFIG.RIFT_RANGE + 4 then
			nearRift = true
		end
	end
	if not nearRift then
		return
	end
	s.lastShift = os.clock()
	if s.mode == "Pilot" then
		setMode(player, "Robot") -- nobody crosses into the Undergrid without the suit
	end

	local delta = inTown and CONFIG.UNDERGRID_OFFSET or -CONFIG.UNDERGRID_OFFSET
	char:PivotTo(char:GetPivot() + delta)
	player:SetAttribute("Dimension", inTown and "Undergrid" or "Town")
	track(player, "shift", 1)

	-- arrival shield: a few seconds to look around before anything can hurt you
	local oldShield = char:FindFirstChild("RiftShield")
	if oldShield then
		oldShield:Destroy()
	end
	local shield = Instance.new("ForceField")
	shield.Name = "RiftShield"
	shield.Parent = char
	local shieldTime = CONFIG.RIFT_SHIELD_TIME + 2 * upgradeLevel(player, "shield")
	Debris:AddItem(shield, shieldTime)

	if inTown then
		local stage = ReplicatedStorage:GetAttribute("Stage")
		local text = (stage == "Nodes" and "YOU ENTERED THE UNDERGRID. DESTROY THE HIVE NODES.")
			or (stage == "Boss" and "YOU ENTERED THE UNDERGRID. THE MIND WARDEN WAITS BY THE TOWER.")
			or (stage == "Files" and "YOU ENTERED THE UNDERGRID. SOME LOWBAND FILES ARE ON THIS SIDE.")
			or (stage == "Relays" and "YOU ENTERED THE UNDERGRID. RESTART THE POWER RELAYS AROUND THE LAB.")
			or (stage == "Carrier" and "YOU ENTERED THE UNDERGRID. DEFEND THE CARRIER!")
			or (stage == "Race" and "WRONG WAY! THE RADIO TOWER IS IN HOLLOW CREEK.")
			or (stage == "Complete" and "THE UNDERGRID IS QUIET... FOR NOW.")
			or (stage == "Keycards" and "YOU ENTERED THE UNDERGRID. TWO KEYCARDS ARE IN THE GRAND HOTEL ON THIS SIDE.")
			or ((stage == "Pylons" or stage == "Tape") and "SITE 2 IS UNDER THE GRAND HOTEL IN HOLLOW CREEK - NOT HERE!")
			or ((stage == "Rifts" or stage == "Van" or stage == "TapeRace") and "THE STORM IS IN HOLLOW CREEK - GO BACK THROUGH THE RIFT!")
			or ((stage == "Locks" or stage == "Listener" or stage == "Collapse" or stage == "Broadcast")
				and "THE WAY TO THE DEEP GRID IS IN SITE 2, UNDER THE GRAND HOTEL IN HOLLOW CREEK!")
			or "YOU ENTERED THE UNDERGRID. FIND THE SHARDS."
		NotifyEvent:FireClient(player, text .. "  SHIELD " .. shieldTime .. "s - THE RIFT AREA IS SAFE", Color3.fromRGB(255, 60, 70))
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
		graphics = profile and profile.graphics,
		shake = profile and profile.shake,
		autoAim = profile and profile.autoAim,
		tutorialDone = profile and profile.tutorialDone,
		volume = profile and profile.volume,
		hudSize = profile and profile.hudSize,
		damageNumbers = profile and profile.damageNumbers,
		look = profile and profile.look,
		lookCatalog = lookCatalog(profile),
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
		-- testing: keep the DEBUG_START_STAGE the server started in instead of restarting the chapter
		local debugStart = fresh and CONFIG.DEBUG_START_STAGE and chapter == CONFIG.DEBUG_START_CHAPTER
		if not debugStart then
			startChapter(chapter)
		end
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

-- Shop: the client sends an action and an item id; prices and ownership live on the server
local function shopState(profile)
	local weapons, upgrades, owned = {}, {}, {}
	for _, id in ipairs(WEAPON_ORDER) do
		local w = WEAPONS[id]
		table.insert(weapons, {
			id = id, name = w.name, price = w.price, desc = w.desc, color = w.color,
			stats = w.melee and (w.damage .. " DMG  /  " .. string.format("%.2g", 1 / w.cooldown) .. " HITS PER S  /  CLOSE RANGE, THROUGH WALLS")
				or (w.pellets > 1 and (w.pellets .. " x " .. w.damage) or tostring(w.damage)) .. " DMG  /  "
				.. string.format("%.2g", 1 / w.cooldown) .. " SHOTS PER S  /  RANGE " .. w.range
				.. (w.mag and ("  /  MAG " .. w.mag .. ", SPARE " .. w.reserve) or ""),
		})
	end
	for _, id in ipairs(UPGRADE_ORDER) do
		local u = UPGRADES[id]
		table.insert(upgrades, { id = id, name = u.name, prices = u.prices, desc = u.desc, level = profile.upgrades[id] })
	end
	for id in pairs(profile.owned) do
		owned[id] = true
	end
	return { scrap = profile.scrap, weapon = profile.weapon, owned = owned, weapons = weapons, upgrades = upgrades,
		ammoPrice = CONFIG.AMMO_REFILL_PRICE, robux = robuxShop and robuxShop(profile) or nil }
end

-- R / SWAP: switch to the next weapon you own (everyone owns the Pulse Cannon and the Shock Baton)
CycleWeaponEvent.OnServerEvent:Connect(function(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local current = table.find(WEAPON_ORDER, profile.weapon) or 1
	for step = 1, #WEAPON_ORDER do
		local id = WEAPON_ORDER[(current - 1 + step) % #WEAPON_ORDER + 1]
		if profile.owned[id] then
			if id ~= profile.weapon then
				profile.weapon = id
				applyLoadout(player)
				NotifyEvent:FireClient(player, WEAPONS[id].name, WEAPONS[id].color)
			end
			return
		end
	end
end)

ShopFunction.OnServerInvoke = function(player, action, id)
	local profile = profiles[player]
	if not profile or not profile.loaded then
		return { ok = false, message = "STILL LOADING - TRY AGAIN" }
	end
	local message = ""
	if action == "buy" and WEAPONS[id] then
		local w = WEAPONS[id]
		if profile.owned[id] then
			return { ok = false, message = "YOU ALREADY OWN IT", state = shopState(profile) }
		elseif profile.scrap < w.price then
			return { ok = false, message = "NOT ENOUGH SCRAP", state = shopState(profile) }
		end
		profile.scrap = profile.scrap - w.price
		profile.owned[id] = true
		task.defer(track, player, "buy", 1) -- FULLY LOADED
		profile.weapon = id -- equip right away
		message = "BOUGHT " .. w.name
	elseif action == "buy" and UPGRADES[id] then
		local u = UPGRADES[id]
		local level = profile.upgrades[id]
		local price = u.prices[level + 1]
		if not price then
			return { ok = false, message = "ALREADY MAXED", state = shopState(profile) }
		elseif profile.scrap < price then
			return { ok = false, message = "NOT ENOUGH SCRAP", state = shopState(profile) }
		end
		profile.scrap = profile.scrap - price
		profile.upgrades[id] = level + 1
		message = u.name .. " LEVEL " .. (level + 1)
	elseif action == "ammo" then
		-- full refill of every gun you own
		if profile.scrap < CONFIG.AMMO_REFILL_PRICE then
			return { ok = false, message = "NOT ENOUGH SCRAP", state = shopState(profile) }
		elseif not refillAmmo(player, 1) then
			return { ok = false, message = "YOUR AMMO IS ALREADY FULL", state = shopState(profile) }
		end
		profile.scrap = profile.scrap - CONFIG.AMMO_REFILL_PRICE
		message = "AMMO REFILLED"
	elseif action == "equip" and WEAPONS[id] then
		if not profile.owned[id] then
			return { ok = false, message = "BUY IT FIRST", state = shopState(profile) }
		end
		profile.weapon = id
		message = WEAPONS[id].name .. " EQUIPPED"
	elseif action ~= "list" then
		return { ok = false, message = "BAD REQUEST" }
	end
	if action ~= "list" then
		applyLoadout(player)
		queueSave(player)
	end
	return { ok = true, message = message, state = shopState(profile) }
end

-- character select: the client sends a look; the server checks it, saves it and dresses the player
SetLookFunction.OnServerInvoke = function(player, look)
	local profile = profiles[player]
	look = validLook(look)
	if not profile or not look then
		return false
	end
	if profile.lastLook and os.clock() - profile.lastLook < 0.3 then
		return false -- clicking very fast: ignore
	end
	if (look.hair and not hairUnlocked(profile, look.hair)) or not paintUnlocked(profile, look.paint) then
		return false -- not unlocked yet (pilot level / daily streak)
	end
	profile.lastLook = os.clock()
	profile.look = look
	refreshLook(player)
	queueSave(player)
	return true
end

-- client settings kept in the save: LIGHT level (a number), or ("graphics", 1..3) / ("shake", true/false)
SettingsEvent.OnServerEvent:Connect(function(player, kind, value)
	local profile = profiles[player]
	if not profile then
		return
	end
	if typeof(kind) == "number" and kind % 1 == 0 and kind >= -3 and kind <= 6 then
		profile.brightness = kind
	elseif kind == "graphics" and (value == 1 or value == 2 or value == 3) then
		profile.graphics = value
	elseif kind == "autoaim" and typeof(value) == "boolean" then
		profile.autoAim = value
	elseif kind == "shake" and typeof(value) == "boolean" then
		profile.shake = value
	elseif kind == "volume" and typeof(value) == "number" and value % 1 == 0 and value >= 0 and value <= 10 then
		profile.volume = value
	elseif kind == "hud" and (value == 1 or value == 2 or value == 3) then
		profile.hudSize = value
	elseif kind == "numbers" and typeof(value) == "boolean" then
		profile.damageNumbers = value
	end
end)

---------------------------------------------------------------------------
-- Firepower (task 012): every gun has a magazine, a reload and limited spare
-- ammo. Free ammo is only for the basic Pulse Cannon: drops from creatures and a
-- HALF refill every 20 min (10 min below level 5). The bought guns (Arc, Scatter,
-- Lance) only refill for Scrap. The Shock Baton never runs out.
---------------------------------------------------------------------------
do
local AMMO_ORANGE = Color3.fromRGB(255, 170, 40)

local function maxMag(profile, w)
	return math.floor(w.mag * (1 + 0.25 * (profile.upgrades.mag or 0)) + 0.5)
end

-- spare ammo you can carry: +50% with the AMMO BELT Game Pass (task 017)
local function reserveOf(profile, w)
	return profile.passes.ammo and math.floor(w.reserve * 1.5) or w.reserve
end

-- the ammo of one weapon (nil for the baton); a weapon nobody has fired yet is full
local function ammoOf(profile, id)
	local w = WEAPONS[id]
	if not w or w.melee or not w.mag then
		return nil
	end
	local a = profile.ammo[id]
	if not a then
		a = { mag = maxMag(profile, w), spare = reserveOf(profile, w) }
		profile.ammo[id] = a
	end
	return a, w
end

local function refillInterval(profile)
	-- the AMMO BELT pass and new pilots (below level 5) get the faster free refill
	return (profile.passes.ammo or levelInfo(profile.xp) < 5) and CONFIG.AMMO_REFILL_TIME_NEW or CONFIG.AMMO_REFILL_TIME
end

-- HUD attributes: Ammo / AmmoMax / AmmoSpare (nil = unlimited), AmmoRefillAt (os.time)
pushAmmo = function(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local a, w = ammoOf(profile, profile.weapon)
	player:SetAttribute("Ammo", a and a.mag or nil)
	player:SetAttribute("AmmoMax", a and maxMag(profile, w) or nil)
	player:SetAttribute("AmmoSpare", a and a.spare or nil)
	player:SetAttribute("AmmoRefillAt", profile.refillAt)
end

local function startReload(player, profile, a, w)
	local s = state[player]
	if not s or (s.reloadUntil and os.clock() < s.reloadUntil) or a.spare <= 0 or a.mag >= maxMag(profile, w) then
		return
	end
	local time = w.reload * (1 - 0.15 * (profile.upgrades.reload or 0))
	s.reloadUntil = os.clock() + time
	s.reloadToken = (s.reloadToken or 0) + 1
	local token = s.reloadToken
	player:SetAttribute("Reloading", true)
	task.delay(time, function()
		if state[player] ~= s or s.reloadToken ~= token then
			return
		end
		player:SetAttribute("Reloading", false)
		local take = math.min(maxMag(profile, w) - a.mag, a.spare)
		a.mag = a.mag + take
		a.spare = a.spare - take
		pushAmmo(player)
	end)
end

-- one shot: true = fire it. Reloads by itself when the magazine is empty.
useAmmo = function(player, weapon)
	if weapon.melee then
		return true
	end
	local profile = profiles[player]
	local s = state[player]
	if not profile or not s then
		return false
	end
	if s.reloadUntil and os.clock() < s.reloadUntil then
		return false
	end
	local a, w = ammoOf(profile, profile.weapon)
	if not a then
		return true
	end
	if a.mag <= 0 then
		if a.spare > 0 then
			startReload(player, profile, a, w)
		elseif not s.lastEmpty or os.clock() - s.lastEmpty > 4 then
			s.lastEmpty = os.clock()
			NotifyEvent:FireClient(player, "OUT OF AMMO! SWAP (R) TO ANOTHER WEAPON OR THE SHOCK BATON, OR BUY AMMO AT THE GARAGE"
				.. (profile.weapon == "pulse" and " (THE PULSE CANNON ALSO GETS A FREE HALF REFILL)" or ""), Color3.fromRGB(255, 60, 70))
		end
		return false
	end
	a.mag = a.mag - 1
	if a.mag <= 0 then
		startReload(player, profile, a, w)
	end
	pushAmmo(player)
	return true
end

-- top every gun you own (or only `onlyId`) up to `fraction` of full (1 = full). Returns true if anything changed.
refillAmmo = function(player, fraction, onlyId)
	local profile = profiles[player]
	if not profile then
		return false
	end
	local changed = false
	for id in pairs(profile.owned) do
		local a, w = nil, nil
		if not onlyId or id == onlyId then
			a, w = ammoOf(profile, id)
		end
		if a then
			local mm = maxMag(profile, w)
			local want = math.floor((mm + reserveOf(profile, w)) * fraction)
			local add = want - (a.mag + a.spare)
			if add > 0 then
				changed = true
				local toMag = math.min(mm - a.mag, add)
				a.mag = a.mag + toMag
				a.spare = math.min(a.spare + add - toMag, reserveOf(profile, w))
			end
		end
	end
	pushAmmo(player)
	return changed
end

-- the free refill timer (runs while you play; it keeps counting in the save)
task.spawn(function()
	while true do
		task.wait(5)
		local now = os.time()
		for plr, profile in pairs(profiles) do
			if plr.Parent and profile.loaded and profile.chosen then
				if not profile.refillAt then
					profile.refillAt = now + refillInterval(profile)
					pushAmmo(plr)
				elseif now >= profile.refillAt then
					profile.refillAt = now + refillInterval(profile)
					-- only the basic Pulse Cannon: ammo for the bought guns is bought with Scrap
					if refillAmmo(plr, CONFIG.AMMO_REFILL_FRACTION, "pulse") then
						NotifyEvent:FireClient(plr, "FREE AMMO: PULSE CANNON REFILLED TO HALF. NEED MORE? BUY A FULL REFILL AT THE GARAGE",
							AMMO_ORANGE)
					end
					pushAmmo(plr)
				end
			end
		end
	end
end)

-- ammo drops: a glowing orange box that gives a spare magazine to whoever touches it
local dropFolder = Instance.new("Folder")
dropFolder.Name = "AmmoDrops"
dropFolder.Parent = workspace

dropAmmo = function(position)
	if rng:NextNumber() > CONFIG.AMMO_DROP_CHANCE then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain, town, undergrid }
	local hit = workspace:Raycast(position, Vector3.new(0, -40, 0), params)
	local at = (hit and hit.Position or position) + Vector3.new(0, 1.2, 0)
	local box = newPart({ Name = "AmmoDrop", Size = Vector3.new(1.6, 1.2, 1.6), CFrame = CFrame.new(at) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 90)), 0),
		Color = AMMO_ORANGE, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = dropFolder })
	local light = Instance.new("PointLight")
	light.Color = AMMO_ORANGE
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = box
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 24)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.MaxDistance = 80
	gui.Parent = box
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Arcade
	label.Text = "AMMO"
	label.TextColor3 = AMMO_ORANGE
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	local taken = false
	box.Touched:Connect(function(part)
		local char = part:FindFirstAncestorOfClass("Model")
		local plr = char and Players:GetPlayerFromCharacter(char)
		local profile = plr and profiles[plr]
		if taken or not profile then
			return
		end
		-- free ammo is only for the basic Pulse Cannon (the bought guns' ammo is bought with Scrap)
		local a, w = ammoOf(profile, "pulse")
		if not a or a.spare >= reserveOf(profile, w) then
			return -- full: leave it for someone else
		end
		taken = true
		a.spare = math.min(a.spare + maxMag(profile, w), reserveOf(profile, w))
		pushAmmo(plr)
		NotifyEvent:FireClient(plr, "+1 MAGAZINE (" .. w.name .. ")", AMMO_ORANGE)
		box:Destroy()
	end)
	Debris:AddItem(box, 30)
end
end -- firepower section

---------------------------------------------------------------------------
-- Robux (task 017): Game Passes (VIP PILOT, NEON SUIT PACK, AMMO BELT) and Scrap packs.
-- Ids live in CONFIG.GAME_PASSES / CONFIG.PRODUCTS (0 = not set up yet: the shop says so).
-- Passes are checked with Roblox on every join; Scrap packs go through ProcessReceipt,
-- are saved right away, and a receipt is never granted twice.
---------------------------------------------------------------------------
do
local MarketplaceService = game:GetService("MarketplaceService")
local PASS_INFO = {
	{ key = "vip", name = "VIP PILOT", color = Color3.fromRGB(255, 214, 90),
		desc = "+25% Scrap and XP from playing, a double daily reward, and a VIP tag on your HUD." },
	{ key = "neon", name = "NEON SUIT PACK", color = Color3.fromRGB(255, 70, 190),
		desc = "3 exclusive suit paints: SYNTHWAVE, CHROME and STATIC (YOUR PILOT > SUIT PAINT)." },
	{ key = "ammo", name = "AMMO BELT", color = Color3.fromRGB(255, 170, 40),
		desc = "+50% spare ammo for every gun, and the free Pulse Cannon refill every 10 minutes." },
}
local PRODUCT_INFO = {
	{ key = "scrap500", name = "500 SCRAP", scrap = 500, color = Color3.fromRGB(255, 235, 140), desc = "Added right away. Spend it in the Garage." },
	{ key = "scrap1500", name = "1500 SCRAP", scrap = 1500, color = Color3.fromRGB(255, 235, 140), desc = "The big pack. Added right away." },
}
local passKeyById, productById = {}, {}
for key, id in pairs(CONFIG.GAME_PASSES) do
	if id ~= 0 then
		passKeyById[id] = key
	end
end
for _, p in ipairs(PRODUCT_INFO) do
	local id = CONFIG.PRODUCTS[p.key] or 0
	if id ~= 0 then
		productById[id] = p
	end
end

local priceCache = {}
local function priceOf(id, infoType)
	if id == 0 then
		return nil
	end
	if priceCache[id] == nil then
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		priceCache[id] = ok and info and info.PriceInRobux or false
	end
	return priceCache[id] or nil
end

robuxShop = function(profile)
	local passes, products = {}, {}
	for _, p in ipairs(PASS_INFO) do
		local id = CONFIG.GAME_PASSES[p.key] or 0
		table.insert(passes, { key = p.key, id = id, name = p.name, desc = p.desc, color = p.color, owned = profile.passes[p.key] == true,
			price = priceOf(id, Enum.InfoType.GamePass) })
	end
	for _, p in ipairs(PRODUCT_INFO) do
		local id = CONFIG.PRODUCTS[p.key] or 0
		table.insert(products, { key = p.key, id = id, name = p.name, desc = p.desc, color = p.color, price = priceOf(id, Enum.InfoType.Product) })
	end
	return { passes = passes, products = products }
end

local function applyPasses(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	player:SetAttribute("VIP", profile.passes.vip or nil)
	applyLoadout(player) -- also refreshes the ammo HUD (AMMO BELT)
end

local function checkPasses(player)
	local start = os.clock()
	while player.Parent and not (profiles[player] and profiles[player].loaded) and os.clock() - start < 60 do
		task.wait(0.5)
	end
	local profile = profiles[player]
	if not profile then
		return
	end
	for key, id in pairs(CONFIG.GAME_PASSES) do
		if id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
			end)
			if ok and owns then
				profile.passes[key] = true
			end
		end
	end
	applyPasses(player)
end
Players.PlayerAdded:Connect(checkPasses)
for _, plr in ipairs(Players:GetPlayers()) do
	task.spawn(checkPasses, plr)
end

-- bought a pass in this session
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local key = passKeyById[passId]
	local profile = profiles[player]
	if not purchased or not key or not profile then
		return
	end
	profile.passes[key] = true
	applyPasses(player)
	for _, p in ipairs(PASS_INFO) do
		if p.key == key then
			NotifyEvent:FireClient(player, "THANK YOU! " .. p.name .. " IS ACTIVE", p.color)
		end
	end
end)

-- Scrap packs (developer products)
MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local profile = player and profiles[player]
	if not profile or not profile.loaded then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox tries again later (e.g. when they rejoin)
	end
	if profile.receipts[info.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already given
	end
	local product = productById[info.ProductId]
	if not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if profile.available and not profile.chosen then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- still in the start menu: their save isn't written yet
	end
	profile.receipts[info.PurchaseId] = true
	awardScrap(player, product.scrap, product.name, true)
	if profile.available and not writeSave(player) then
		-- not saved: undo, Roblox will try again
		profile.receipts[info.PurchaseId] = nil
		profile.scrap = math.max(profile.scrap - product.scrap, 0)
		applyLoadout(player)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	NotifyEvent:FireClient(player, "THANK YOU! +" .. product.scrap .. " SCRAP", product.color)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
end -- Robux section

---------------------------------------------------------------------------
-- Friends and co-op (task 011): DOWN + revive, ping markers, friend bonus
---------------------------------------------------------------------------
do
local DOWN_RED = Color3.fromRGB(255, 60, 70)
local REVIVE_GREEN = Color3.fromRGB(60, 255, 140)

-- players in the game (not in a menu) who are up and could come to help
local function helpersFor(except)
	local n = 0
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if p ~= except and h and h.Health > 0 and not c:GetAttribute("Downed") and profiles[p] and profiles[p].chosen then
			n = n + 1
		end
	end
	return n
end

local function clearDown(char)
	char:SetAttribute("Downed", nil)
	char:SetAttribute("DownedUntil", nil)
	local glow = char:FindFirstChild("DownedGlow")
	if glow then
		glow:Destroy()
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local prompt = hrp and hrp:FindFirstChild("RevivePrompt")
	if prompt then
		prompt:Destroy()
	end
end

local function revive(plr, char, hum, helper)
	if not char:GetAttribute("Downed") or hum.Health <= 0 then
		return
	end
	clearDown(char)
	local s = state[plr]
	if s then
		setMode(plr, s.mode) -- puts walk speed and jump back
	end
	hum.Health = math.max(hum.MaxHealth * 0.5, 1)
	notifyAll(helper.DisplayName .. " REVIVED " .. plr.DisplayName .. "!", REVIVE_GREEN)
	awardScrap(helper, CONFIG.SCRAP_REVIVE, "REVIVE")
	track(helper, "revive", 1)
end

local function goDown(plr, char, hum)
	local s = state[plr]
	if s and s.mode == "Vehicle" then
		setMode(plr, "Robot") -- the car folds back into the robot
	end
	local token = (char:GetAttribute("DownToken") or 0) + 1
	char:SetAttribute("DownToken", token)
	char:SetAttribute("Downed", true)
	char:SetAttribute("DownedUntil", workspace:GetServerTimeNow() + CONFIG.DOWN_TIME)
	hum.Health = 1
	hum.WalkSpeed = 0
	hum.JumpPower = 0

	local glow = Instance.new("Highlight")
	glow.Name = "DownedGlow"
	glow.FillColor = DOWN_RED
	glow.FillTransparency = 0.55
	glow.OutlineColor = DOWN_RED
	glow.Parent = char

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RevivePrompt" -- Signal85Client hides it on the downed player's own screen
		prompt.ActionText = "Revive"
		prompt.ObjectText = plr.DisplayName
		prompt.HoldDuration = CONFIG.REVIVE_HOLD
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = hrp
		prompt.Triggered:Connect(function(helper)
			local hc = helper.Character
			local hh = hc and hc:FindFirstChildOfClass("Humanoid")
			if helper ~= plr and hh and hh.Health > 0 and not hc:GetAttribute("Downed") then
				revive(plr, char, hum, helper)
			end
		end)
	end
	notifyAll(plr.DisplayName .. " IS DOWN! GO TO THEM AND HOLD E (OR TAP) TO REVIVE", DOWN_RED)

	task.delay(CONFIG.DOWN_TIME, function()
		if char.Parent and char:GetAttribute("Downed") and char:GetAttribute("DownToken") == token and hum.Health > 0 then
			clearDown(char)
			hum.Health = 0 -- nobody came: respawn as usual
		end
	end)
end

-- all damage to players goes through here. Alone, you die as before; with someone else
-- playing, a hit that would kill you puts you DOWN for a while instead.
hurtPlayer = function(plr, hum, amount)
	local char = hum.Parent
	if not char or char:GetAttribute("Downed") or char:FindFirstChildOfClass("ForceField") then
		return
	end
	if hum.Health - amount > 0 or not plr or helpersFor(plr) == 0 then
		hum:TakeDamage(amount)
		return
	end
	goDown(plr, char, hum)
end

-- ping: T / PING marks a spot for everyone; snaps to an enemy or an item close to it
PingEvent.OnServerEvent:Connect(function(player, pos)
	if typeof(pos) ~= "Vector3" or pos.X ~= pos.X or pos.Y ~= pos.Y or pos.Z ~= pos.Z then
		return -- not a position (or NaN)
	end
	local s = state[player]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not s or not hrp or (hrp.Position - pos).Magnitude > 450 then
		return
	end
	if s.lastPing and os.clock() - s.lastPing < CONFIG.PING_COOLDOWN then
		return
	end
	s.lastPing = os.clock()
	local kind = "spot"
	local function near(folder, k)
		if kind ~= "spot" or not folder then
			return
		end
		for _, d in ipairs(folder:GetChildren()) do
			local at = (d:IsA("Model") and d:GetPivot().Position) or (d:IsA("BasePart") and d.Position) or nil
			if at and (at - pos).Magnitude < 10 then
				kind, pos = k, at
				return
			end
		end
	end
	near(creatureFolder, "enemy")
	near(workspace:FindFirstChild("HiveNodes"), "enemy")
	near(workspace:FindFirstChild("Boss"), "enemy")
	near(shardFolder, "item")
	near(fileFolder, "item")
	PingEvent:FireAllClients(pos, kind, player.DisplayName)
end)

-- friend bonus: +10% gameplay Scrap while a Roblox friend is in the same server
local friendCache = {}
local function areFriends(a, b)
	local key = math.min(a.UserId, b.UserId) .. ":" .. math.max(a.UserId, b.UserId)
	if friendCache[key] == nil then
		local ok, yes = pcall(function()
			return a:IsFriendsWith(b.UserId)
		end)
		if not ok then
			return false -- try again next time
		end
		friendCache[key] = yes == true
	end
	return friendCache[key]
end

local function refreshFriends()
	local list = Players:GetPlayers()
	for _, a in ipairs(list) do
		local any = false
		for _, b in ipairs(list) do
			if a ~= b and b.Parent and areFriends(a, b) then
				any = true
				break
			end
		end
		if any and not a:GetAttribute("FriendBonus") then
			NotifyEvent:FireClient(a, "FRIEND BONUS: +" .. math.floor(CONFIG.FRIEND_BONUS * 100) .. "% SCRAP WHILE YOU PLAY TOGETHER", REVIVE_GREEN)
		end
		a:SetAttribute("FriendBonus", any or nil)
	end
end
Players.PlayerAdded:Connect(function()
	task.delay(3, refreshFriends)
end)
Players.PlayerRemoving:Connect(function()
	task.delay(1, refreshFriends)
end)
end -- task 011 section

---------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------
local function onPlayerAdded(player)
	if state[player] then
		return
	end
	state[player] = { mode = "Pilot", lastTransform = 0, lastBlast = 0, lastShift = 0, ready = false }
	player:SetAttribute("Dimension", "Town")
	player:SetAttribute("Carrying", 0)

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player
	local shards = Instance.new("IntValue")
	shards.Name = "Shards"
	shards.Parent = stats
	local scrap = Instance.new("IntValue")
	scrap.Name = "Scrap"
	scrap.Parent = stats
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = 1
	level.Parent = stats
	task.spawn(loadProfile, player)

	local function onCharacterAdded(char)
		local s = state[player]
		if not s then
			return
		end
		s.mode = "Pilot" -- you spawn in town as yourself
		s.ready = false
		player:SetAttribute("Dimension", "Town")
		player:SetAttribute("Carrying", 0) -- shards are lost if you fall
		char:SetAttribute("Mode", "Pilot")

		local hum = char:WaitForChild("Humanoid")
		char:WaitForChild("HumanoidRootPart")
		local start = os.clock()
		while not player:HasAppearanceLoaded() and os.clock() - start < 5 do
			task.wait(0.1)
		end
		if char.Parent then
			local profile = profiles[player]
			applyPilotLook(player, char, profile and profile.look)
			applyRobotArmor(char)
			char:SetAttribute("SuitPaint", profile and profile.look and profile.look.paint or 1)
			repaintSuit(char)
			setLayerVisible(char, "ShiftframeArmor", false)
			hum.Died:Connect(function()
				local p = profiles[player]
				if p then
					p.diedThisChapter = true -- UNTOUCHED achievement
				end
			end)
			hum.WalkSpeed = CONFIG.PILOT_SPEED
			hum.UseJumpPower = true
			hum.JumpPower = CONFIG.PILOT_JUMP
			applyLoadout(player) -- Armor Plating max health
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
