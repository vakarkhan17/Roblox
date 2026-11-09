--[[
	SIGNAL '85 — Chapter 4: SITE 2 (task 013). ModuleScript in ServerScriptService.Chapters.
	Story: docs/STORY.md. The main server script requires it and passes `api`.

	Stages:
	  Keycards  find 4 keycards: 2 in the town Grand Hotel, 2 in its Undergrid copy.
	            The steel door behind the cracked tiles of the floor 1 men's washroom has 4 slots.
	  Pylons    the door opens: Site 2, LOWBAND's 1958 tunnels under the hotel (built 120 studs
	            below it; the door and the exit teleport you). Destroy the 4 Echo Pylons.
	            They call Echoes: shadow Shiftframes that keep their distance and shoot.
	  Tape      the vault opens. Play Dr. Helen Marsh's 1962 tape in the deep room.
	  Complete  every radio in Hollow Creek switches on... (Chapter 5 follows when it exists)
]]

return function(api)
	local CONFIG = api.CONFIG
	local rng = api.rng
	local Players = api.Players
	local TweenService = api.TweenService
	local newPart = api.newPart

	local CYAN = Color3.fromRGB(80, 220, 255)
	local ECHO_PURPLE = Color3.fromRGB(170, 90, 255)
	local CARD_GREEN = Color3.fromRGB(120, 255, 160)
	local SITE_YELLOW = Color3.fromRGB(255, 220, 120)
	local RED = Color3.fromRGB(255, 60, 70)
	local CONCRETE = Color3.fromRGB(110, 112, 108)
	local DARK = Color3.fromRGB(60, 62, 60)

	local KEYCARDS = 4
	local PYLONS = 4
	local PYLON_HEALTH = 450
	local ECHO_HEALTH = 110
	local ECHO_MAX = 6
	local SCRAP_CARD = 20
	local SCRAP_PYLON = 40

	-- Site 2 sits 120 studs under the town hotel; floor at C.Y, x -60..60, z -50..50, 14 high
	local C = api.HOTEL_CENTER + Vector3.new(0, -120, 0)
	local HALF_X, HALF_Z, HEIGHT = 60, 50, 14

	-- the washroom door: floor 1 men's washroom, inner (west) wall at hotel-local x 40, z -33
	local DOOR_POS = api.hotelSpot(1, Vector2.new(40.7, -33), false)

	local def = { title = "SITE 2" }

	---------------------------------------------------------------------------
	-- Site 2 map
	---------------------------------------------------------------------------
	local site = Instance.new("Model")
	site.Name = "Site2"

	local function box(name, size, pos, props)
		props = props or {}
		props.Name = name
		props.Size = size
		props.Position = C + pos
		props.Color = props.Color or CONCRETE
		props.Material = props.Material or Enum.Material.Concrete
		props.Parent = site
		return newPart(props)
	end

	local function light(p, color, range, brightness)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = brightness
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

	-- a wall from a to b along X (at z = fixed) or along Z (at x = fixed), with doorways { {centre, width} }
	local function wall(alongX, fixed, a, b, gaps)
		local cuts = {}
		for _, g in ipairs(gaps or {}) do
			table.insert(cuts, { g[1] - g[2] / 2, g[1] + g[2] / 2 })
		end
		table.sort(cuts, function(p, q)
			return p[1] < q[1]
		end)
		local function piece(from, to, y0, h)
			if to - from < 0.05 then
				return
			end
			local mid = (from + to) / 2
			box("Site2Wall", alongX and Vector3.new(to - from, h, 1) or Vector3.new(1, h, to - from),
				alongX and Vector3.new(mid, y0 + h / 2, fixed) or Vector3.new(fixed, y0 + h / 2, mid))
		end
		local x = a
		for _, cut in ipairs(cuts) do
			piece(x, cut[1], 0, HEIGHT)
			piece(cut[1], cut[2], 9, HEIGHT - 9) -- lintel over the doorway
			x = cut[2]
		end
		piece(x, b, 0, HEIGHT)
	end

	local function lamp(x, z, flicker)
		local p = box(flicker and "HotelFlicker" or "Site2Lamp", Vector3.new(4, 0.3, 1), Vector3.new(x, HEIGHT - 0.4, z),
			{ Color = Color3.fromRGB(255, 225, 170), Material = Enum.Material.Neon })
		light(p, Color3.fromRGB(255, 220, 170), 26, 1.3)
	end

	-- a 1950s reel-to-reel computer cabinet against a wall; facing = the direction its front looks
	local function computer(x, z, facing)
		local front = facing * 1.05
		local alongX = math.abs(facing.Z) > 0.5
		local size = alongX and Vector3.new(4, 7, 2) or Vector3.new(2, 7, 4)
		box("Site2Computer", size, Vector3.new(x, 3.5, z), { Color = Color3.fromRGB(150, 150, 140), Material = Enum.Material.Metal })
		for _, dy in ipairs({ 5, 2.5 }) do
			for _, side in ipairs({ -0.9, 0.9 }) do
				local offset = alongX and Vector3.new(side, dy, 0) or Vector3.new(0, dy, side)
				local reel = box("Site2Reel", Vector3.new(0.2, 1.4, 1.4), Vector3.new(x, 0, z) + offset + front, { Color = DARK, Material = Enum.Material.Metal })
				reel.Shape = Enum.PartType.Cylinder
				reel.CFrame = CFrame.lookAt(reel.Position, reel.Position + facing) * CFrame.Angles(0, math.rad(90), 0)
			end
		end
		local blink = box("Site2Blink", Vector3.new(0.3, 0.3, 0.3), Vector3.new(x, 1.2, z) + front, { Color = rng:NextNumber() < 0.5 and RED or CARD_GREEN,
			Material = Enum.Material.Neon })
		blink.CanCollide = false
	end

	local function desk(x, z)
		box("Site2Desk", Vector3.new(5, 0.4, 3), Vector3.new(x, 3, z), { Color = Color3.fromRGB(90, 80, 60), Material = Enum.Material.Wood })
		for _, dx in ipairs({ -2.2, 2.2 }) do
			box("Site2DeskLeg", Vector3.new(0.4, 3, 2.6), Vector3.new(x + dx, 1.5, z), { Color = DARK, Material = Enum.Material.Metal })
		end
		box("Site2Papers", Vector3.new(1.2, 0.1, 0.9), Vector3.new(x - 1, 3.25, z), { Color = Color3.fromRGB(235, 230, 210), Material = Enum.Material.Fabric })
	end

	local function cabinet(x, z)
		box("Site2Cabinet", Vector3.new(2, 5, 2), Vector3.new(x, 2.5, z), { Color = Color3.fromRGB(100, 110, 100), Material = Enum.Material.Metal })
	end

	-- floor, ceiling, outer walls
	box("Site2Floor", Vector3.new(HALF_X * 2 + 2, 1, HALF_Z * 2 + 2), Vector3.new(0, -0.5, 0), { Color = Color3.fromRGB(80, 82, 78) })
	box("Site2Ceiling", Vector3.new(HALF_X * 2 + 2, 1, HALF_Z * 2 + 2), Vector3.new(0, HEIGHT + 0.5, 0), { Color = DARK })
	wall(true, -HALF_Z, -HALF_X, HALF_X)
	wall(true, HALF_Z, -HALF_X, HALF_X)
	wall(false, -HALF_X, -HALF_Z, HALF_Z)
	wall(false, HALF_X, -HALF_Z, HALF_Z)
	-- the central hall (x -14..14) and its doorways into the four chambers
	wall(false, -14, -HALF_Z, HALF_Z, { { -26, 8 }, { 26, 8 } })
	wall(false, 14, -HALF_Z, HALF_Z, { { -26, 8 }, { 26, 8 } })
	-- each wing splits into a south and a north chamber
	wall(true, 0, -HALF_X, -14, { { -46, 8 } })
	wall(true, 0, 14, HALF_X, { { 46, 8 } })
	-- the deep room at the north end of the hall, behind the vault door
	wall(true, 34, -14, 14, { { 0, 8 } })
	local vault = box("Site2Vault", Vector3.new(8, 9, 1.2), Vector3.new(0, 4.5, 34), { Color = Color3.fromRGB(70, 74, 80), Material = Enum.Material.DiamondPlate })
	local vaultSign = box("Site2Sign", Vector3.new(8, 1.4, 0.2), Vector3.new(0, 10.4, 33.3), { Color = Color3.fromRGB(30, 30, 30) })
	sign(vaultSign, Enum.NormalId.Front, "VAULT - SEALED", RED)

	-- entry stairs (south end): the way back up to the hotel
	for i = 0, 4 do -- steps going up into the south wall
		local h = 5 - i
		box("Site2Step", Vector3.new(8, h, 1.2), Vector3.new(0, h / 2, -48.9 + i * 1.2), { Color = CONCRETE })
	end
	local exitPart = box("Site2Exit", Vector3.new(4, 1.2, 0.3), Vector3.new(0, 7, -49.3), { Color = CARD_GREEN, Material = Enum.Material.Neon })
	sign(exitPart, Enum.NormalId.Back, "EXIT - HOTEL", Color3.new(0, 0, 0))
	exitPart.Position = C + Vector3.new(0, 7, -49.2)
	local hallSign = box("Site2Sign", Vector3.new(14, 2.4, 0.3), Vector3.new(0, 10.5, -30), { Color = Color3.fromRGB(30, 30, 30) })
	sign(hallSign, Enum.NormalId.Front, "PROJECT LOWBAND - SITE 2 - 1958", SITE_YELLOW) -- seen when you arrive
	sign(hallSign, Enum.NormalId.Back, "AUTHORIZED PERSONNEL ONLY", RED)
	-- warning stripes and pipes
	for _, z in ipairs({ -40, -10, 20 }) do
		box("Site2Stripe", Vector3.new(27, 0.05, 1), Vector3.new(0, 0.03, z), { Color = Color3.fromRGB(230, 190, 40), Material = Enum.Material.SmoothPlastic })
	end
	for _, x in ipairs({ -12, 12 }) do
		local pipe = box("Site2Pipe", Vector3.new(1, 1, HALF_Z * 2 - 2), Vector3.new(x, HEIGHT - 1.5, 0), { Color = Color3.fromRGB(120, 90, 60), Material = Enum.Material.Metal })
		pipe.Shape = Enum.PartType.Cylinder
		pipe.CFrame = CFrame.new(pipe.Position) * CFrame.Angles(0, math.rad(90), 0)
	end
	for _, z in ipairs({ -40, -14, 14 }) do
		box("Site2Pillar", Vector3.new(2.2, HEIGHT, 2.2), Vector3.new(-7, HEIGHT / 2, z), { Color = DARK })
		box("Site2Pillar", Vector3.new(2.2, HEIGHT, 2.2), Vector3.new(7, HEIGHT / 2, z), { Color = DARK })
	end

	-- lights: the hall, each chamber, the deep room (some flicker: the HUD flickers "HotelFlicker" lamps)
	lamp(0, -40, false)
	lamp(0, -14, true)
	lamp(0, 14, false)
	lamp(0, 44, true)
	for _, x in ipairs({ -37, 37 }) do
		for _, z in ipairs({ -33, -17, 17, 33 }) do
			lamp(x, z, rng:NextNumber() < 0.35)
		end
	end

	-- chamber furniture: computers on the outer walls, desks and cabinets
	local CHAMBERS = { Vector2.new(-37, -25), Vector2.new(-37, 25), Vector2.new(37, -25), Vector2.new(37, 25) }
	for _, ch in ipairs(CHAMBERS) do
		local outer = ch.X > 0 and 1 or -1
		for _, dz in ipairs({ -12, -6, 6, 12 }) do
			computer(ch.X + outer * 21.5, ch.Y + dz, Vector3.new(-outer, 0, 0))
		end
		desk(ch.X - outer * 12, ch.Y + 10)
		cabinet(ch.X - outer * 18, ch.Y - 14)
	end
	-- the south-east chamber is flooded
	box("Site2Water", Vector3.new(45, 0.6, 48), Vector3.new(37, 0.3, -25), { Color = Color3.fromRGB(40, 80, 110), Material = Enum.Material.Glass,
		Transparency = 0.45, CanCollide = false, CanQuery = false })

	-- the deep room: the tape machine and the round door they "knocked" on
	desk(0, 42)
	local tape = box("Site2Tape", Vector3.new(3, 1.6, 1.6), Vector3.new(0, 4, 42), { Color = Color3.fromRGB(170, 160, 140), Material = Enum.Material.Metal })
	for _, dx in ipairs({ -0.7, 0.7 }) do
		local reel = box("Site2TapeReel", Vector3.new(0.2, 1, 1), Vector3.new(dx, 4.3, 41.1), { Color = DARK, Material = Enum.Material.Metal })
		reel.Shape = Enum.PartType.Cylinder
		reel.CFrame = CFrame.new(reel.Position) * CFrame.Angles(0, math.rad(90), 0)
	end
	local tapePrompt = Instance.new("ProximityPrompt")
	tapePrompt.Name = "Site2TapePrompt"
	tapePrompt.ActionText = "Play the tape"
	tapePrompt.ObjectText = "Reel-to-reel, 1962"
	tapePrompt.HoldDuration = 1
	tapePrompt.MaxActivationDistance = 12
	tapePrompt.RequiresLineOfSight = false
	tapePrompt.Enabled = false
	tapePrompt.Parent = tape
	local bigDoor = box("Site2RoundDoor", Vector3.new(1, 11, 11), Vector3.new(0, 6.5, 49.2), { Color = Color3.fromRGB(50, 46, 52), Material = Enum.Material.DiamondPlate })
	bigDoor.Shape = Enum.PartType.Cylinder
	bigDoor.CFrame = CFrame.new(bigDoor.Position) * CFrame.Angles(0, math.rad(90), 0)
	local doorGlow = box("Site2DoorGlow", Vector3.new(0.3, 12, 12), Vector3.new(0, 6.5, 48.6), { Color = RED, Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false })
	doorGlow.Shape = Enum.PartType.Cylinder
	doorGlow.CFrame = CFrame.new(doorGlow.Position) * CFrame.Angles(0, math.rad(90), 0)
	light(doorGlow, RED, 24, 2)

	local exitPrompt = Instance.new("ProximityPrompt")
	exitPrompt.Name = "Site2ExitPrompt"
	exitPrompt.ActionText = "Go up to the hotel"
	exitPrompt.ObjectText = "Site 2 stairs"
	exitPrompt.HoldDuration = 0
	exitPrompt.MaxActivationDistance = 12
	exitPrompt.RequiresLineOfSight = false
	exitPrompt.Parent = exitPart

	site.Parent = workspace
	workspace:SetAttribute("Site2Center", C)
	workspace:SetAttribute("Site2Half", Vector3.new(HALF_X, HEIGHT, HALF_Z)) -- the HUD: flashlight, camera, "SITE 2" label

	---------------------------------------------------------------------------
	-- The washroom: cracked tiles hiding a steel door with four card slots
	---------------------------------------------------------------------------
	local entrance = Instance.new("Model")
	entrance.Name = "Site2Entrance"
	local steel = newPart({ Name = "Site2Door", Size = Vector3.new(0.4, 9, 5), Position = DOOR_POS + Vector3.new(0, 4.5, 0),
		Color = Color3.fromRGB(90, 96, 104), Material = Enum.Material.DiamondPlate, Parent = entrance })
	local slots = {}
	for i = 1, KEYCARDS do
		slots[i] = newPart({ Name = "Site2Slot", Size = Vector3.new(0.2, 0.5, 0.7), Position = DOOR_POS + Vector3.new(0.25, 6.5, -1.8 + (i - 1) * 1.2),
			Color = RED, Material = Enum.Material.Neon, CanCollide = false, Parent = entrance })
	end
	local doorPrompt = Instance.new("ProximityPrompt")
	doorPrompt.Name = "Site2DoorPrompt"
	doorPrompt.ActionText = "Enter Site 2"
	doorPrompt.ObjectText = "Steel door"
	doorPrompt.HoldDuration = 0.5
	doorPrompt.MaxActivationDistance = 10
	doorPrompt.RequiresLineOfSight = false
	doorPrompt.Enabled = false
	doorPrompt.Parent = steel
	-- the tiles in front of it: whole in other chapters, broken in Chapter 4
	local tiles = newPart({ Name = "Site2Tiles", Size = Vector3.new(0.3, 10, 6), Position = DOOR_POS + Vector3.new(0.35, 5, 0),
		Color = Color3.fromRGB(225, 228, 230), Material = Enum.Material.Marble, Parent = entrance })
	local cracks = {}
	for i = 1, 5 do
		cracks[i] = newPart({ Name = "Site2Crack", Size = Vector3.new(0.05, rng:NextNumber(1.5, 3.5), 0.12),
			CFrame = CFrame.new(DOOR_POS + Vector3.new(0.52, rng:NextNumber(2, 8), rng:NextNumber(-2.4, 2.4))) * CFrame.Angles(rng:NextNumber(-0.8, 0.8), 0, 0),
			Color = Color3.fromRGB(70, 70, 74), CanCollide = false, Parent = entrance })
	end
	local rubble = {}
	entrance.Parent = workspace

	local function setTiles(broken)
		tiles.Transparency = broken and 1 or 0
		tiles.CanCollide = not broken
		for _, c in ipairs(cracks) do
			c.Transparency = broken and 1 or 0
		end
		for _, r in ipairs(rubble) do
			r:Destroy()
		end
		table.clear(rubble)
		if broken then
			for _ = 1, 9 do
				table.insert(rubble, newPart({ Name = "Site2Rubble", Size = Vector3.new(rng:NextNumber(0.6, 1.4), 0.2, rng:NextNumber(0.6, 1.4)),
					CFrame = CFrame.new(DOOR_POS + Vector3.new(rng:NextNumber(1, 4), 0.1, rng:NextNumber(-3, 3))) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
					Color = Color3.fromRGB(225, 228, 230), Material = Enum.Material.Marble, CanCollide = false, Parent = entrance }))
			end
		end
	end
	setTiles(false)

	local function setSlots(found)
		for i, s in ipairs(slots) do
			s.Color = i <= found and CARD_GREEN or RED
		end
	end

	---------------------------------------------------------------------------
	-- Who is in Site 2
	---------------------------------------------------------------------------
	local function inSite2(position)
		local rel = position - C
		return math.abs(rel.X) < HALF_X + 2 and math.abs(rel.Z) < HALF_Z + 2 and rel.Y > -3 and rel.Y < HEIGHT + 3
	end

	local function playersInSite2()
		local list = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 and not char:GetAttribute("Downed") and inSite2(hrp.Position) then
				table.insert(list, { plr = plr, hrp = hrp, hum = hum })
			end
		end
		return list
	end

	local function teleport(plr, cframe)
		local char = plr.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			char:PivotTo(cframe)
			api.sparkBurst(cframe.Position, CYAN, 16, 12, 0.3, 0.4)
		end
	end

	exitPrompt.Triggered:Connect(function(plr)
		teleport(plr, CFrame.lookAt(DOOR_POS + Vector3.new(4, 3.5, 0), DOOR_POS + Vector3.new(10, 3.5, 0)))
		api.remotes.Notify:FireClient(plr, "BACK IN THE GRAND HOTEL", SITE_YELLOW)
	end)

	---------------------------------------------------------------------------
	-- Keycards
	---------------------------------------------------------------------------
	local cardFolder = Instance.new("Folder")
	cardFolder.Name = "Keycards"
	cardFolder.Parent = workspace

	local CARD_SPOTS = {
		{ pos = api.hotelSpot(3, api.HOTEL_ROOMS[2], false), world = "Town", where = "room 302" },
		{ pos = api.hotelSpot(api.HOTEL_FLOORS + 1, Vector2.new(10, -30), false), world = "Town", where = "the roof" },
		{ pos = api.hotelSpot(2, api.HOTEL_ROOMS[9], true), world = "Undergrid", where = "room 209 (Undergrid)" },
		{ pos = api.hotelSpot(1, Vector2.new(-44, 34), true), world = "Undergrid", where = "the manager's desk (Undergrid)" },
	}
	local CARD_LINES = {
		{ "RICKY", "One down! The card says 'SITE 2 - LEVEL A'. Three more slots on that door." },
		{ "DOT", "That's two. The manager's name is on this one... the hotel really was LOWBAND's." },
		{ "RICKY", "Three! Last one - check the hotel on the other side of the rift." },
		{ "DOT", "All four! The door is opening... be careful down there." },
	}

	local function spawnCard(index)
		local spot = CARD_SPOTS[index]
		local card = newPart({ Name = "Keycard", Size = Vector3.new(1.6, 0.15, 1), CFrame = CFrame.new(spot.pos + Vector3.new(0, 3, 0)),
			Color = CARD_GREEN, Material = Enum.Material.Neon, CanCollide = false, Parent = cardFolder })
		card:SetAttribute("Dimension", spot.world)
		card:SetAttribute("Index", index)
		light(card, CARD_GREEN, 14, 2)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(110, 26)
		gui.StudsOffset = Vector3.new(0, 1.6, 0)
		gui.MaxDistance = 60
		gui.Parent = card
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Arcade
		l.Text = "KEYCARD"
		l.TextColor3 = CARD_GREEN
		l.TextScaled = true
		l.TextStrokeTransparency = 0.3
		l.Parent = gui
		TweenService:Create(card, TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{ CFrame = card.CFrame * CFrame.Angles(0, math.pi, 0) }):Play()
		card.Touched:Connect(function(part)
			local char = part:FindFirstAncestorOfClass("Model")
			local plr = char and Players:GetPlayerFromCharacter(char)
			if not plr or card:GetAttribute("Taken") or not api.stageIs("Keycards") then
				return
			end
			card:SetAttribute("Taken", true)
			card:Destroy()
			local goal = api.ReplicatedStorage:GetAttribute("Goal") or KEYCARDS
			local progress = math.min((api.ReplicatedStorage:GetAttribute("Progress") or 0) + 1, goal)
			api.ReplicatedStorage:SetAttribute("Progress", progress)
			setSlots(progress)
			api.notifyAll(plr.DisplayName .. " FOUND A KEYCARD [" .. progress .. "/" .. goal .. "]", CARD_GREEN)
			api.awardScrap(plr, SCRAP_CARD, "KEYCARD")
			api.track(plr, "objective", 1)
			local line = CARD_LINES[progress]
			if line then
				api.radioLater(1, line[1], line[2])
			end
			api.checkpoint()
			if progress >= goal then
				task.delay(2, function()
					if api.stageIs("Keycards") then
						def.startPylons(0)
					end
				end)
			end
		end)
	end

	---------------------------------------------------------------------------
	-- Echo Pylons and the Echoes they call
	---------------------------------------------------------------------------
	local pylonFolder = Instance.new("Folder")
	pylonFolder.Name = "Site2Targets" -- the HUD's auto-aim looks in here too
	pylonFolder.Parent = workspace
	local pylons = {} -- [model] = { center, lastCall }

	local function echoCount()
		local n = 0
		for m in pairs(api.creatures) do
			if m.Name == "Echo" then
				n = n + 1
			end
		end
		return n
	end

	local siteParams = RaycastParams.new()
	siteParams.FilterType = Enum.RaycastFilterType.Include
	siteParams.FilterDescendantsInstances = { site }

	local function canSee(from, to)
		local dir = to - from
		return workspace:Raycast(from, dir, siteParams) == nil
	end

	local function spawnEcho(at)
		local m = Instance.new("Model")
		m.Name = "Echo"
		local SHADE = Color3.fromRGB(26, 20, 36)
		local function add(props, cf)
			props.CFrame = cf
			props.CanCollide = false
			props.Material = props.Material or Enum.Material.SmoothPlastic
			props.Transparency = props.Transparency or 0.2
			props.Parent = m
			return newPart(props)
		end
		-- a shadow copy of a Shiftframe: helmet with a visor, shoulder pads, an arm cannon
		local torso = add({ Name = "Torso", Size = Vector3.new(2.2, 2.4, 1.2), Color = SHADE }, CFrame.new())
		local head = add({ Name = "Head", Size = Vector3.new(1.5, 1.4, 1.4), Color = SHADE }, CFrame.new(0, 2, 0))
		add({ Name = "Visor", Size = Vector3.new(1.6, 0.3, 0.2), Color = ECHO_PURPLE, Material = Enum.Material.Neon, Transparency = 0 }, CFrame.new(0, 2.1, -0.72))
		for _, side in ipairs({ -1, 1 }) do
			add({ Name = "Pad", Size = Vector3.new(1, 0.5, 1.3), Color = ECHO_PURPLE, Material = Enum.Material.Neon, Transparency = 0.4 },
				CFrame.new(side * 1.5, 1.1, 0) * CFrame.Angles(0, 0, side * -0.25))
			add({ Name = "Arm", Size = Vector3.new(0.6, 2.2, 0.6), Color = SHADE }, CFrame.new(side * 1.5, -0.3, 0))
			add({ Name = "Leg", Size = Vector3.new(0.8, 2.4, 0.8), Color = SHADE }, CFrame.new(side * 0.55, -2.4, 0))
		end
		add({ Name = "Cannon", Size = Vector3.new(0.5, 0.5, 1.6), Color = ECHO_PURPLE, Material = Enum.Material.Neon, Transparency = 0 }, CFrame.new(1.5, -1, -0.6))
		light(head, ECHO_PURPLE, 12, 2)
		api.addHealthBar(head, 70, 2.4, ECHO_PURPLE)
		m.PrimaryPart = torso
		m:SetAttribute("Creature", true)
		m:SetAttribute("Health", ECHO_HEALTH)
		m:SetAttribute("MaxHealth", ECHO_HEALTH)
		m:PivotTo(CFrame.new(at + Vector3.new(0, 3.4, 0)))
		m.Parent = api.creatureFolder
		api.sparkBurst(at + Vector3.new(0, 3, 0), ECHO_PURPLE, 24, 14, 0.4, 0.5)

		api.creatures[m] = {
			lastHit = 0, phase = rng:NextNumber(0, 10), speed = 11, damage = 12, hitCooldown = 1.8, reward = 4, height = 3.4,
			targets = playersInSite2,
			-- keep about 24 studs away while it can see you; come closer when a wall is in the way
			stopAt = function(model, t)
				return (model.PrimaryPart and canSee(model.PrimaryPart.Position, t.hrp.Position)) and 24 or 4
			end,
			-- a slow purple bolt you can dodge
			attack = function(model, t)
				local from = model.PrimaryPart and model.PrimaryPart.Position
				if not from or (t.hrp.Position - from).Magnitude > 80 or not canSee(from, t.hrp.Position) then
					return false
				end
				local target = t.hrp.Position
				local bolt = newPart({ Name = "EchoBolt", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Position = from,
					Color = ECHO_PURPLE, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false, Parent = workspace })
				local time = (target - from).Magnitude / 70
				TweenService:Create(bolt, TweenInfo.new(time, Enum.EasingStyle.Linear), { Position = target }):Play()
				task.delay(time, function()
					bolt:Destroy()
					if t.hrp.Parent and (t.hrp.Position - target).Magnitude < 4.5 then
						api.hurtPlayer(t.plr, t.hum, 12)
					end
					api.sparkBurst(target, ECHO_PURPLE, 10, 15, 0.3, 0.3)
				end)
				return true
			end,
		}
	end

	local function spawnPylon(index)
		local ch = CHAMBERS[index]
		local center = C + Vector3.new(ch.X, 0, ch.Y)
		local m = Instance.new("Model")
		m.Name = "EchoPylon"
		local function add(props, cf)
			props.CFrame = cf
			props.Parent = m
			return newPart(props)
		end
		add({ Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 7, 7), Color = DARK, Material = Enum.Material.Metal },
			CFrame.new(center + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)))
		local column = add({ Name = "Column", Size = Vector3.new(2.2, 9, 2.2), Color = ECHO_PURPLE, Material = Enum.Material.Neon },
			CFrame.new(center + Vector3.new(0, 5.6, 0)))
		for k = 1, 3 do
			add({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 5, 5), Color = Color3.fromRGB(70, 60, 90),
				Material = Enum.Material.Metal, CanCollide = false }, CFrame.new(center + Vector3.new(0, 2 + k * 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90)))
		end
		add({ Name = "Antenna", Size = Vector3.new(0.3, 3, 0.3), Color = DARK, Material = Enum.Material.Metal }, CFrame.new(center + Vector3.new(0, 11.6, 0)))
		light(column, ECHO_PURPLE, 26, 2.5)
		api.addHealthBar(column, 140, 6.5, ECHO_PURPLE)
		m.PrimaryPart = column
		m:SetAttribute("Target", true)
		m:SetAttribute("Chapter", 4)
		m:SetAttribute("Health", PYLON_HEALTH)
		m:SetAttribute("MaxHealth", PYLON_HEALTH)
		m:SetAttribute("Index", index)
		m.Parent = pylonFolder
		pylons[m] = { center = center + Vector3.new(0, 5, 0), lastCall = os.clock() - 6 }
		TweenService:Create(column, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.35 }):Play()
	end

	def.targets = function()
		local list = {}
		for m, data in pairs(pylons) do
			table.insert(list, { model = m, center = data.center })
		end
		return list
	end

	local function openVault(open)
		vault.Transparency = open and 1 or 0
		vault.CanCollide = not open
		vault.CanQuery = not open
	end

	local chapter4Complete -- below

	def.damageTarget = function(model, amount, player)
		if model:GetAttribute("Chapter") ~= 4 or not pylons[model] then
			return false
		end
		local hp = (model:GetAttribute("Health") or 0) - amount
		model:SetAttribute("Health", hp)
		api.updateHealthBar(model)
		if hp > 0 then
			return true, false
		end
		local data = pylons[model]
		pylons[model] = nil
		api.sparkBurst(data.center, ECHO_PURPLE, 60, 40, 0.8, 0.9)
		model:Destroy()
		local goal = api.ReplicatedStorage:GetAttribute("Goal") or PYLONS
		local progress = math.min((api.ReplicatedStorage:GetAttribute("Progress") or 0) + 1, goal)
		api.ReplicatedStorage:SetAttribute("Progress", progress)
		api.notifyAll("ECHO PYLON DESTROYED [" .. progress .. "/" .. goal .. "]", ECHO_PURPLE)
		if player then
			api.awardScrap(player, SCRAP_PYLON, "ECHO PYLON")
			api.track(player, "objective", 1)
		end
		api.checkpoint()
		if progress >= goal then
			def.startTape()
		elseif progress == 2 then
			api.radioLater(1, "DOT", "Two pylons left. The Echoes are copying you - same moves, same guns. Stay behind cover.")
		end
		return true, true
	end

	---------------------------------------------------------------------------
	-- Stages
	---------------------------------------------------------------------------
	def.startPylons = function(done)
		api.setStage("Pylons", done, PYLONS)
		setTiles(true)
		setSlots(KEYCARDS)
		doorPrompt.Enabled = true
		doorPrompt.ActionText = "Enter Site 2"
		openVault(false)
		for m in pairs(pylons) do
			m:Destroy()
		end
		table.clear(pylons)
		for i = done + 1, PYLONS do
			spawnPylon(i)
		end
		api.notifyAll("THE STEEL DOOR IS OPEN - GO DOWN INTO SITE 2", SITE_YELLOW)
		if done == 0 then
			api.radioLater(3, "DOT", "Site 2... four machines down there are still recording the signal. Echo Pylons, the files call them.")
			api.radioLater(10, "RICKY", "Something is moving down there. Something that looks like... you?")
		end
	end

	def.startTape = function()
		api.setStage("Tape", 0, 1)
		setTiles(true)
		setSlots(KEYCARDS)
		doorPrompt.Enabled = true
		doorPrompt.ActionText = "Enter Site 2"
		openVault(true)
		tapePrompt.Enabled = true
		api.notifyAll("THE VAULT IS OPEN - PLAY THE TAPE IN THE DEEP ROOM", SITE_YELLOW)
		api.radioLater(2, "RICKY", "The vault door just slid open! There's a tape machine in there.")
	end

	tapePrompt.Triggered:Connect(function(plr)
		if not api.stageIs("Tape") or not tapePrompt.Enabled then
			return
		end
		tapePrompt.Enabled = false
		api.notifyAll(plr.DisplayName .. " PRESSED PLAY...", SITE_YELLOW)
		api.radioLater(1, "DR. MARSH", "Site 2 log. October 1962. Dr. Helen Marsh.")
		api.radioLater(6, "DR. MARSH", "We didn't open the door. We only knocked.")
		api.radioLater(11, "DR. MARSH", "Something on the other side has been answering ever since.")
		api.radioLater(16, "DR. MARSH", "We call it... the Listener.")
		local token = api.token()
		task.delay(21, function()
			if token == api.token() and api.stageIs("Tape") then
				chapter4Complete(true)
			end
		end)
	end)

	doorPrompt.Triggered:Connect(function(plr)
		local stage = api.ReplicatedStorage:GetAttribute("Stage")
		if api.ReplicatedStorage:GetAttribute("Chapter") ~= 4 then
			return
		end
		if stage == "Keycards" then
			api.remotes.Notify:FireClient(plr, "LOCKED - " .. tostring(api.ReplicatedStorage:GetAttribute("Progress") or 0) .. " / "
				.. KEYCARDS .. " KEYCARDS. TWO ARE IN THIS HOTEL, TWO IN ITS UNDERGRID COPY", RED)
			return
		end
		teleport(plr, CFrame.lookAt(C + Vector3.new(0, 3.5, -44), C + Vector3.new(0, 3.5, 0)))
		api.remotes.Notify:FireClient(plr, "SITE 2 - PROJECT LOWBAND, 1958", SITE_YELLOW)
	end)

	-- announce: false when a save is restored straight into "Complete"
	chapter4Complete = function(announce)
		local token = api.token()
		api.clearCreatures()
		api.setStage("Complete", 1, 1)
		if not announce then
			return
		end
		api.notifyAll("CHAPTER 4 COMPLETE — SITE 2", api.colors.GREEN)
		api.awardEveryone(CONFIG.SCRAP_CHAPTER, "CHAPTER 4 COMPLETE")
		api.chapterCleared(4)
		task.delay(4, function()
			if token == api.token() then
				api.notifyAll("EVERY RADIO IN HOLLOW CREEK SWITCHES ON BY ITSELF...", RED)
			end
		end)
		api.radioLater(7, "DOT", "Guys... every radio in my house just turned on. All of them. At once.")
		api.radioLater(13, "RICKY", "Same here. It's not music. It's... breathing?")
		api.radioLater(19, "DOT", "It heard the tape. It knows we found Site 2.")
		task.delay(25, function()
			if token ~= api.token() then
				return
			end
			if api.hasChapter(5) then
				task.delay(CONFIG.CHAPTER_PAUSE, function()
					if token == api.token() then
						api.startChapter(5)
					end
				end)
			else
				api.notifyAll("TO BE CONTINUED IN CHAPTER 5", Color3.fromRGB(255, 214, 140))
			end
		end)
	end

	-- stageState.stage = "Keycards" (default) | "Pylons" | "Tape" | "Complete"; progress = cards found / pylons destroyed
	def.start = function(stageState)
		local stage = stageState.stage or "Keycards"
		setTiles(true) -- Ricky broke the tiles: the steel door is visible from the start of Chapter 4
		if stage == "Pylons" then
			def.startPylons(math.clamp(stageState.progress or 0, 0, PYLONS - 1))
		elseif stage == "Tape" then
			def.startTape()
		elseif stage == "Complete" then
			setSlots(KEYCARDS)
			doorPrompt.Enabled = true
			doorPrompt.ActionText = "Enter Site 2"
			openVault(true)
			chapter4Complete(false)
		else
			local done = math.clamp(stageState.progress or 0, 0, KEYCARDS - 1)
			api.setStage("Keycards", done, KEYCARDS)
			setSlots(done)
			doorPrompt.Enabled = true -- says it's locked, so players know where the door is
			doorPrompt.ActionText = "Locked"
			for i = done + 1, KEYCARDS do
				spawnCard(i)
			end
			if done == 0 then
				api.radioLater(3, "DOT", "The last file said 'Site 2'. I checked the town records: the Grand Hotel was built in 1958... by LOWBAND.")
				api.radioLater(10, "RICKY", "I'm in the men's washroom on the ground floor. The tiles are cracked - there's a STEEL DOOR behind them!")
				api.radioLater(17, "DOT", "Four card slots. The keycards must still be in the hotel - two on this side, two on the other.")
			end
		end
	end

	-- reset for any chapter: the tiles go back, the door locks, everything spawned is removed
	def.clear = function()
		cardFolder:ClearAllChildren()
		for m in pairs(pylons) do
			m:Destroy()
		end
		table.clear(pylons)
		setTiles(false)
		setSlots(0)
		doorPrompt.Enabled = false
		tapePrompt.Enabled = false
		openVault(false)
	end

	-- Hollowers in the Undergrid hotel while you look for cards; Echoes from the pylons
	task.spawn(function()
		while true do
			task.wait(5)
			if api.stageIs("Keycards") then
				if api.creatureCount() < CONFIG.MAX_CREATURES and #api.playersInUndergrid() > 0 then
					local floor = rng:NextInteger(1, api.HOTEL_FLOORS)
					api.spawnCreature(api.hotelSpot(floor, Vector2.new(rng:NextNumber(-48, 48), rng:NextNumber(-34, 34)), true))
				end
			elseif api.stageIs("Pylons") then
				local inside = playersInSite2()
				local now = os.clock()
				for m, data in pairs(pylons) do
					if m.Parent and echoCount() < ECHO_MAX and now - data.lastCall > 10 then
						for _, t in ipairs(inside) do
							if (t.hrp.Position - data.center).Magnitude < 70 then
								data.lastCall = now
								spawnEcho(data.center + Vector3.new(rng:NextNumber(-6, 6), -5, rng:NextNumber(-6, 6)))
								break
							end
						end
					end
				end
			end
		end
	end)

	return def
end
