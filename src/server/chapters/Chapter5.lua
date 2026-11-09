--[[
	SIGNAL '85 — Chapter 5: STATIC STORM (task 014). ModuleScript in ServerScriptService.Chapters.
	Story: docs/STORY.md. The main server script requires it and passes `api`.

	The Undergrid leaks into Hollow Creek: a red storm (workspace attribute Storm = true,
	the HUD tints the town), and for the first time the creatures come out IN TOWN.
	Stages:
	  Rifts     close 5 mini-rifts in town: stand in the circle until it closes. Open rifts
	            let out Hollowers and Static Hounds.
	  Van       defend the WHCK 85.5 van on Main Street for VAN_TIME seconds while the DJ
	            broadcasts a calming signal. If the van is destroyed, the defence restarts.
	  TapeRace  pick up the signal tapes at the radio tower and drive them to the Grand Hotel
	            entrance before TAPE_TIME runs out. The road cracks behind you.
	  Complete  the storm calms... and a huge rift swallows Ricky. (Chapter 6 follows when it exists)
]]

return function(api)
	local CONFIG = api.CONFIG
	local rng = api.rng
	local Players = api.Players
	local TweenService = api.TweenService
	local ReplicatedStorage = api.ReplicatedStorage
	local newPart = api.newPart

	local RIFT_RED = Color3.fromRGB(255, 50, 60)
	local VAN_CREAM = Color3.fromRGB(235, 225, 200)
	local WHCK_BLUE = Color3.fromRGB(70, 140, 255)
	local TAPE_ORANGE = Color3.fromRGB(255, 170, 40)
	local GREEN = api.colors.GREEN

	local RIFTS = 5
	local CLOSE_TIME = 10      -- seconds of standing in a mini-rift's circle (faster with more pilots)
	local CLOSE_RADIUS = 9
	local TOWN_MAX = 12        -- creatures in town at once
	local VAN_HEALTH = 1200
	local VAN_TIME = 120
	local VAN_MAX = 14
	local TAPE_TIME = 50
	local SCRAP_RIFT = 25

	local HOTEL_DOOR = api.HOTEL_CENTER + Vector3.new(-66, 0, 0) -- the red carpet in front of the Grand Hotel
	local TAPE_SPOT = api.console.Position + Vector3.new(10, -2, 6) -- next to the radio tower console
	local VAN_SPOT = Vector3.new(9, 0, 20)                        -- Main Street
	local RICKY_SPOT = Vector3.new(-30, 0, -150)                  -- where Ricky watches the town from

	local def = { title = "STATIC STORM" }
	local folder = Instance.new("Folder")
	folder.Name = "StaticStorm"
	folder.Parent = workspace

	local function stage()
		return ReplicatedStorage:GetAttribute("Stage")
	end

	local function light(p, color, range, brightness)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = brightness
		l.Parent = p
		return l
	end

	local function billboard(p, text, color, offset)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(200, 36)
		gui.StudsOffset = Vector3.new(0, offset, 0)
		gui.MaxDistance = 250
		gui.AlwaysOnTop = true
		gui.Parent = p
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Arcade
		l.Text = text
		l.TextColor3 = color
		l.TextScaled = true
		l.TextStrokeTransparency = 0.2
		l.Parent = gui
		return l
	end

	local function ground(pos)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { api.town, workspace.Terrain }
		local hit = workspace:Raycast(Vector3.new(pos.X, 80, pos.Z), Vector3.new(0, -160, 0), params)
		return hit and hit.Position or Vector3.new(pos.X, 0, pos.Z)
	end

	-- true when the spot is open ground or road (not a roof or a building)
	local function isOpen(pos)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { api.town }
		local hit = workspace:Raycast(Vector3.new(pos.X, 150, pos.Z), Vector3.new(0, -300, 0), params)
		return hit ~= nil and (hit.Instance.Name == "Ground" or hit.Instance.Name == "Road")
	end

	---------------------------------------------------------------------------
	-- Creatures in town: they hunt pilots in Hollow Creek (and the van while it broadcasts)
	---------------------------------------------------------------------------
	local van = nil -- { model, core, hp }

	local function townTargets()
		local list = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 and not char:GetAttribute("Downed") and plr:GetAttribute("Dimension") == "Town" then
				table.insert(list, { plr = plr, hrp = hrp, hum = hum })
			end
		end
		if van and van.hp > 0 and van.core.Parent then
			table.insert(list, { hrp = van.core, van = true })
		end
		return list
	end

	local function damageVan(amount)
		if not van or van.hp <= 0 then
			return
		end
		van.hp = math.max(van.hp - amount, 0)
		ReplicatedStorage:SetAttribute("BossHealth", van.hp)
		api.sparkBurst(van.core.Position + Vector3.new(rng:NextNumber(-3, 3), 2, rng:NextNumber(-5, 5)), RIFT_RED, 8, 12, 0.3, 0.3)
	end

	-- turn a freshly spawned Hollower / hound into a town hunter
	local function townCreature(m)
		local data = m and api.creatures[m]
		if not data then
			return
		end
		data.storm = true
		data.targets = townTargets
		data.stopAt = function(_, t)
			return t.van and 7 or 3.5
		end
		data.attack = function(model, t)
			local pos = model.PrimaryPart and model.PrimaryPart.Position
			if not pos then
				return false
			end
			if t.van then
				local flat = Vector3.new(t.hrp.Position.X - pos.X, 0, t.hrp.Position.Z - pos.Z).Magnitude
				if flat < 10 then
					damageVan(data.damage)
					return true
				end
				return false
			end
			if (t.hrp.Position - pos).Magnitude < 6.5 then
				api.hurtPlayer(t.plr, t.hum, data.damage)
				return true
			end
			return false
		end
	end

	local function stormCount()
		local n = 0
		for _, data in pairs(api.creatures) do
			if data.storm then
				n = n + 1
			end
		end
		return n
	end

	local function spawnTownCreature(at, houndChance)
		if rng:NextNumber() < (houndChance or 0.3) then
			for _, m in ipairs(api.spawnHoundPack(at)) do
				townCreature(m)
			end
		else
			townCreature(api.spawnCreature(at))
		end
	end

	---------------------------------------------------------------------------
	-- Storm: the town turns red (the HUD reads workspace.Storm), tendrils on the shops
	---------------------------------------------------------------------------
	local tendrils = {}
	local function setStorm(on)
		workspace:SetAttribute("Storm", on or nil)
		for _, t in ipairs(tendrils) do
			t:Destroy()
		end
		table.clear(tendrils)
		if not on then
			return
		end
		for _ = 1, 26 do
			local at = ground(api.randomOpenPoint(api.town, Vector3.zero))
			local len = rng:NextNumber(6, 14)
			local t = newPart({ Name = "StormTendril", Size = Vector3.new(0.8, len, 0.8), Color = Color3.fromRGB(20, 12, 18),
				Material = Enum.Material.Slate, CanCollide = false, CanQuery = false,
				CFrame = CFrame.new(at + Vector3.new(0, len / 2 - 0.5, 0)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6), rng:NextNumber(-0.5, 0.5)),
				Parent = folder })
			table.insert(tendrils, t)
		end
	end

	---------------------------------------------------------------------------
	-- Stage 1: mini-rifts
	---------------------------------------------------------------------------
	local rifts = {} -- [model] = { center, charge, label, ring, lastSpawn }

	local function spawnMiniRift(at)
		at = ground(at)
		local m = Instance.new("Model")
		m.Name = "MiniRift"
		local ring = newPart({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 11, 11), Color = RIFT_RED,
			Material = Enum.Material.Neon, CanCollide = false, CFrame = CFrame.new(at + Vector3.new(0, 6.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Parent = m })
		newPart({ Name = "Void", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 9, 9), Color = Color3.fromRGB(8, 4, 10),
			Material = Enum.Material.Glass, Transparency = 0.15, CanCollide = false, CanQuery = false, CFrame = ring.CFrame, Parent = m })
		local circle = newPart({ Name = "CloseZone", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, CLOSE_RADIUS * 2, CLOSE_RADIUS * 2),
			Color = RIFT_RED, Material = Enum.Material.Neon, Transparency = 0.7, CanCollide = false, CanQuery = false,
			CFrame = CFrame.new(at + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)), Parent = m })
		light(ring, RIFT_RED, 30, 3)
		local fx = Instance.new("ParticleEmitter")
		fx.Color = ColorSequence.new(RIFT_RED)
		fx.LightEmission = 1
		fx.Rate = 18
		fx.Lifetime = NumberRange.new(0.6, 1.2)
		fx.Speed = NumberRange.new(4, 9)
		fx.SpreadAngle = Vector2.new(180, 180)
		fx.Size = NumberSequence.new(0.4, 0)
		fx.Parent = ring
		local label = billboard(ring, "STAND HERE TO CLOSE", RIFT_RED, 8)
		m.PrimaryPart = ring
		m.Parent = folder
		rifts[m] = { center = at, charge = 0, label = label, ring = ring, circle = circle, lastSpawn = os.clock() }
	end

	-- 5 spots: in front of the hotel, by the radio tower, and three open spots around town
	local function riftSpots()
		local spots = {}
		for _, s in ipairs({ HOTEL_DOOR + Vector3.new(-24, 0, 14), api.console.Position + Vector3.new(30, 0, 22) }) do
			if isOpen(s) then
				table.insert(spots, s)
			end
		end
		local tries = 0
		while #spots < RIFTS do
			tries = tries + 1
			local p = api.randomOpenPoint(api.town, Vector3.zero)
			local ok = Vector3.new(p.X, 0, p.Z).Magnitude < 200
			for _, s in ipairs(spots) do
				if (Vector3.new(p.X, 0, p.Z) - Vector3.new(s.X, 0, s.Z)).Magnitude < 60 and tries < 200 then
					ok = false -- spread them out (unless we can't find room)
				end
			end
			if ok then
				table.insert(spots, p)
			end
		end
		return spots
	end

	local startVan -- below

	local function closeRift(m, data, inside)
		rifts[m] = nil
		api.sparkBurst(data.center + Vector3.new(0, 6, 0), RIFT_RED, 60, 35, 0.7, 0.8)
		m:Destroy()
		local goal = ReplicatedStorage:GetAttribute("Goal") or RIFTS
		local progress = math.min((ReplicatedStorage:GetAttribute("Progress") or 0) + 1, goal)
		ReplicatedStorage:SetAttribute("Progress", progress)
		api.notifyAll("MINI-RIFT CLOSED [" .. progress .. "/" .. goal .. "]", GREEN)
		for _, t in ipairs(inside) do
			api.awardScrap(t.plr, SCRAP_RIFT, "RIFT CLOSED")
			api.track(t.plr, "objective", 1)
		end
		api.checkpoint()
		local lines = {
			[1] = { "RICKY", "One closed! There are more - the yellow marker shows the next one." },
			[3] = { "DOT", "Three down. The storm is getting weaker... I think." },
			[4] = { "RICKY", "Last one! Then the radio station wants to try something." },
		}
		local line = lines[progress]
		if line then
			api.radioLater(1, line[1], line[2])
		end
		if progress >= goal then
			task.delay(3, function()
				if api.stageIs("Rifts") then
					startVan()
				end
			end)
		end
	end

	---------------------------------------------------------------------------
	-- Stage 2: the WHCK van
	---------------------------------------------------------------------------
	local function buildVan()
		local m = Instance.new("Model")
		m.Name = "WhckVan"
		local base = ground(VAN_SPOT)
		local function add(props, offset)
			props.CFrame = CFrame.new(base) * offset
			props.Parent = m
			return newPart(props)
		end
		local core = add({ Name = "Body", Size = Vector3.new(6, 5, 12), Color = VAN_CREAM, Material = Enum.Material.SmoothPlastic }, CFrame.new(0, 3.6, 0))
		add({ Name = "Stripe", Size = Vector3.new(6.05, 0.8, 12.05), Color = WHCK_BLUE, Material = Enum.Material.SmoothPlastic }, CFrame.new(0, 3.2, 0))
		add({ Name = "Windshield", Size = Vector3.new(5.4, 2, 0.2), Color = Color3.fromRGB(40, 60, 80), Material = Enum.Material.Glass, Transparency = 0.3 },
			CFrame.new(0, 4.8, -6.05))
		for _, x in ipairs({ -3, 3 }) do
			for _, z in ipairs({ -4, 4 }) do
				add({ Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 2.4, 2.4), Color = Color3.fromRGB(25, 25, 28) },
					CFrame.new(x, 1.2, z))
			end
		end
		add({ Name = "Mast", Size = Vector3.new(0.4, 6, 0.4), Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.Metal }, CFrame.new(0, 9, 3))
		local dish = add({ Name = "Dish", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 4, 4), Color = Color3.fromRGB(200, 200, 210),
			Material = Enum.Material.Metal }, CFrame.new(0, 12, 3) * CFrame.Angles(0, 0, math.rad(60)))
		local beacon = add({ Name = "Beacon", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, Color = WHCK_BLUE, Material = Enum.Material.Neon,
			CanCollide = false }, CFrame.new(0, 12.6, 3))
		light(beacon, WHCK_BLUE, 40, 3)
		local signPart = add({ Name = "Sign", Size = Vector3.new(0.2, 2, 8), Color = Color3.fromRGB(20, 20, 30) }, CFrame.new(3.1, 4.4, 0))
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Right
		gui.LightInfluence = 0
		gui.Parent = signPart
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Arcade
		l.TextScaled = true
		l.Text = "WHCK 85.5 FM"
		l.TextColor3 = WHCK_BLUE
		l.Parent = gui
		-- a soft blue ring: the calming signal
		local wave = add({ Name = "Wave", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 20, 20), Color = WHCK_BLUE, Material = Enum.Material.Neon,
			Transparency = 0.7, CanCollide = false, CanQuery = false }, CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)))
		TweenService:Create(wave, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1),
			{ Size = Vector3.new(0.2, 60, 60), Transparency = 1 }):Play()
		TweenService:Create(dish, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{ CFrame = dish.CFrame * CFrame.Angles(0, math.pi * 2 - 0.01, 0) }):Play()
		m.PrimaryPart = core
		m.Parent = folder
		return m, core
	end

	local function removeVan()
		if van and van.model then
			van.model:Destroy()
		end
		van = nil
		ReplicatedStorage:SetAttribute("BossMaxHealth", 0)
		ReplicatedStorage:SetAttribute("BossHealth", 0)
	end

	local function clearStormCreatures()
		for m, data in pairs(api.creatures) do
			if data.storm then
				api.creatures[m] = nil
				m:Destroy()
			end
		end
	end

	local startTapeRace -- below

	startVan = function()
		local token = api.token()
		clearStormCreatures()
		removeVan()
		local model, core = buildVan()
		van = { model = model, core = core, hp = VAN_HEALTH }
		api.setStage("Van", 0, VAN_TIME)
		local deadline = workspace:GetServerTimeNow() + VAN_TIME
		ReplicatedStorage:SetAttribute("Deadline", deadline)
		ReplicatedStorage:SetAttribute("BossName", "WHCK 85.5 VAN")
		ReplicatedStorage:SetAttribute("BossMaxHealth", VAN_HEALTH)
		ReplicatedStorage:SetAttribute("BossHealth", VAN_HEALTH)
		ReplicatedStorage:SetAttribute("BossOpen", false)
		api.notifyAll("DEFEND THE WHCK VAN ON MAIN STREET!", WHCK_BLUE)
		api.radioLater(1, "WHCK", "This is WHCK 85.5 coming to you LIVE from Main Street... if anything's out there, this one's for you.")
		api.radioLater(6, "DOT", "They're broadcasting a calming signal! Keep those things away from the van!")
		task.spawn(function()
			local lastWave = 0
			while token == api.token() and api.stageIs("Van") and van and van.model == model do
				task.wait(0.5)
				local now = workspace:GetServerTimeNow()
				ReplicatedStorage:SetAttribute("Progress", math.clamp(math.floor(VAN_TIME - (deadline - now)), 0, VAN_TIME))
				if van.hp <= 0 then
					api.notifyAll("THE VAN IS DOWN! THE BROADCAST STOPPED - TRY AGAIN", RIFT_RED)
					api.radioLater(0.5, "WHCK", "We lost the signal... we're rebooting the transmitter, hold on!")
					task.wait(5)
					if token == api.token() and api.stageIs("Van") then
						startVan()
					end
					return
				end
				if now >= deadline then
					clearStormCreatures()
					removeVan()
					api.notifyAll("THE BROADCAST WORKED - THE STORM IS FADING!", GREEN)
					api.awardEveryone(40, "VAN SAVED")
					task.wait(2)
					if token == api.token() then
						startTapeRace()
					end
					return
				end
				-- a wave every 8 s from around the van, more as the broadcast goes on
				if os.clock() - lastWave > 8 and stormCount() < VAN_MAX then
					lastWave = os.clock()
					local count = 2 + math.floor((VAN_TIME - (deadline - now)) / 40)
					for _ = 1, count do
						local a = rng:NextNumber(0, math.pi * 2)
						spawnTownCreature(VAN_SPOT + Vector3.new(math.cos(a) * 60, 0, math.sin(a) * 60), 0.35)
					end
				end
			end
		end)
	end

	---------------------------------------------------------------------------
	-- Stage 3: the tape race from the radio tower to the Grand Hotel
	---------------------------------------------------------------------------
	local tape, goalRing = nil, nil
	local carrier = nil -- the player holding the tapes

	local function dropTapes(reason)
		if carrier then
			carrier:SetAttribute("CarryingTape", nil)
		end
		carrier = nil
		ReplicatedStorage:SetAttribute("Deadline", 0)
		if reason then
			api.notifyAll(reason, RIFT_RED)
		end
		if tape then
			tape.Transparency = 0
			tape:SetAttribute("Taken", false)
		end
	end

	local chapter5Complete -- below

	startTapeRace = function()
		local token = api.token()
		api.setStage("TapeRace", 0, TAPE_TIME)
		ReplicatedStorage:SetAttribute("Deadline", 0)
		if tape then
			tape:Destroy()
		end
		if goalRing then
			goalRing:Destroy()
		end
		carrier = nil
		tape = newPart({ Name = "SignalTapes", Size = Vector3.new(2.4, 1.4, 1.6), CFrame = CFrame.new(ground(TAPE_SPOT) + Vector3.new(0, 1.5, 0)),
			Color = TAPE_ORANGE, Material = Enum.Material.Neon, CanCollide = false, Parent = folder })
		light(tape, TAPE_ORANGE, 18, 2)
		billboard(tape, "SIGNAL TAPES", TAPE_ORANGE, 3)
		local g = ground(HOTEL_DOOR)
		goalRing = newPart({ Name = "TapeGoal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 16, 16), Color = WHCK_BLUE,
			Material = Enum.Material.Neon, Transparency = 0.4, CanCollide = false, CanQuery = false,
			CFrame = CFrame.new(g + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Parent = folder })
		billboard(goalRing, "DELIVER THE TAPES HERE", WHCK_BLUE, 6)
		api.notifyAll("GET THE SIGNAL TAPES FROM THE RADIO TOWER TO THE GRAND HOTEL!", TAPE_ORANGE)
		api.radioLater(1, "WHCK", "We need the master tapes at the hotel - the big antenna on its roof can carry the signal across the whole town!")
		api.radioLater(7, "RICKY", "The tapes are by the radio tower console. Grab them and DRIVE. The road's cracking up!")

		tape.Touched:Connect(function(part)
			local char = part:FindFirstAncestorOfClass("Model")
			local plr = char and Players:GetPlayerFromCharacter(char)
			if not plr or carrier or tape:GetAttribute("Taken") or not api.stageIs("TapeRace") then
				return
			end
			tape:SetAttribute("Taken", true)
			tape.Transparency = 1
			carrier = plr
			plr:SetAttribute("CarryingTape", true)
			ReplicatedStorage:SetAttribute("Deadline", workspace:GetServerTimeNow() + TAPE_TIME)
			api.notifyAll(plr.DisplayName .. " HAS THE TAPES - GET TO THE HOTEL!", TAPE_ORANGE)
		end)

		task.spawn(function()
			while token == api.token() and api.stageIs("TapeRace") do
				task.wait(0.35)
				local deadline = ReplicatedStorage:GetAttribute("Deadline") or 0
				if carrier then
					local char = carrier.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					local now = workspace:GetServerTimeNow()
					ReplicatedStorage:SetAttribute("Progress", math.clamp(math.floor(TAPE_TIME - (deadline - now)), 0, TAPE_TIME))
					if not carrier.Parent or not hrp or not hum or hum.Health <= 0 or char:GetAttribute("Downed") then
						dropTapes("THE TAPES WERE DROPPED - THEY'RE BACK AT THE RADIO TOWER")
					elseif deadline > 0 and now >= deadline then
						dropTapes("TOO SLOW - THE TAPES DEMAGNETIZED IN THE STORM. GET A FRESH SET AT THE TOWER!")
					elseif (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(HOTEL_DOOR.X, 0, HOTEL_DOOR.Z)).Magnitude < 10 then
						local who = carrier
						dropTapes(nil)
						api.awardScrap(who, 60, "TAPES DELIVERED")
						api.track(who, "objective", 1)
						chapter5Complete(true)
						return
					else
						-- the road cracks behind the carrier
						local back = hrp.Position - hrp.CFrame.LookVector * 8
						local crack = newPart({ Name = "RoadCrack", Size = Vector3.new(rng:NextNumber(1, 2.5), 0.15, rng:NextNumber(5, 9)),
							CFrame = CFrame.new(ground(back) + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
							Color = RIFT_RED, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = folder })
						api.Debris:AddItem(crack, 6)
					end
				end
				-- some hounds chase the tapes
				if carrier and stormCount() < 6 and rng:NextNumber() < 0.08 then
					local c = carrier.Character and carrier.Character:FindFirstChild("HumanoidRootPart")
					if c then
						local a = rng:NextNumber(0, math.pi * 2)
						for _, m in ipairs(api.spawnHoundPack(ground(c.Position + Vector3.new(math.cos(a) * 50, 0, math.sin(a) * 50)))) do
							townCreature(m)
						end
					end
				end
			end
		end)
	end

	---------------------------------------------------------------------------
	-- Complete: the storm calms... and Ricky is taken
	---------------------------------------------------------------------------
	local bigRift = nil
	local function openBigRift()
		if bigRift then
			bigRift:Destroy()
		end
		local at = ground(isOpen(RICKY_SPOT) and RICKY_SPOT or Vector3.new(0, 0, RICKY_SPOT.Z))
		bigRift = Instance.new("Model")
		bigRift.Name = "RickyRift"
		local ring = newPart({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 4, 4), Color = RIFT_RED, Material = Enum.Material.Neon,
			CanCollide = false, CFrame = CFrame.new(at + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Parent = bigRift })
		newPart({ Name = "Void", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, 3, 3), Color = Color3.fromRGB(5, 2, 8), Material = Enum.Material.Glass,
			CanCollide = false, CanQuery = false, CFrame = ring.CFrame, Parent = bigRift })
		light(ring, RIFT_RED, 60, 4)
		bigRift.Parent = folder
		-- it opens wide on the ground
		TweenService:Create(ring, TweenInfo.new(3, Enum.EasingStyle.Quad), { Size = Vector3.new(1.2, 40, 40) }):Play()
		TweenService:Create(bigRift.Void, TweenInfo.new(3, Enum.EasingStyle.Quad), { Size = Vector3.new(1.3, 36, 36) }):Play()
		api.sparkBurst(at + Vector3.new(0, 2, 0), RIFT_RED, 120, 60, 1.2, 1.5)
	end

	chapter5Complete = function(announce)
		local token = api.token()
		clearStormCreatures()
		removeVan()
		ReplicatedStorage:SetAttribute("Deadline", 0)
		if tape then
			tape:Destroy()
			tape = nil
		end
		if goalRing then
			goalRing:Destroy()
			goalRing = nil
		end
		api.setStage("Complete", 1, 1)
		setStorm(false)
		openBigRift()
		if not announce then
			return
		end
		api.notifyAll("CHAPTER 5 COMPLETE — THE STORM IS OVER", GREEN)
		api.awardEveryone(CONFIG.SCRAP_CHAPTER, "CHAPTER 5 COMPLETE")
		api.chapterCleared(5)
		api.radioLater(3, "WHCK", "...and that's the storm passing, Hollow Creek. Stay tuned. Stay safe.")
		api.radioLater(9, "RICKY", "We did it! The sky's normal again! I can see the whole town from up he-")
		task.delay(12, function()
			if token == api.token() then
				api.notifyAll("A HUGE RIFT OPENS UNDER RICKY!", RIFT_RED)
			end
		end)
		api.radioLater(13, "DOT", "RICKY? RICKY, ANSWER ME!")
		api.radioLater(19, "RICKY", "...guys? I can see it. It's so big...")
		task.delay(26, function()
			if token ~= api.token() then
				return
			end
			if api.hasChapter(6) then
				task.delay(CONFIG.CHAPTER_PAUSE, function()
					if token == api.token() then
						api.startChapter(6)
					end
				end)
			else
				api.notifyAll("TO BE CONTINUED IN CHAPTER 6", Color3.fromRGB(255, 214, 140))
			end
		end)
	end

	---------------------------------------------------------------------------
	-- Start / clear
	---------------------------------------------------------------------------
	-- stageState.stage = "Rifts" (default) | "Van" | "TapeRace" | "Complete"; progress = rifts closed
	def.start = function(stageState)
		local stage0 = stageState.stage or "Rifts"
		if stage0 == "Complete" then
			chapter5Complete(false)
			return
		end
		setStorm(true)
		if stage0 == "Van" then
			startVan()
		elseif stage0 == "TapeRace" then
			startTapeRace()
		else
			local done = math.clamp(stageState.progress or 0, 0, RIFTS - 1)
			api.setStage("Rifts", done, RIFTS)
			local spots = riftSpots()
			for i = done + 1, RIFTS do
				spawnMiniRift(spots[i])
			end
			if done == 0 then
				api.radioLater(3, "DOT", "Something's wrong with the sky. It's RED. And there's static... everywhere.")
				api.radioLater(9, "RICKY", "Little rifts are opening all over town - right on Main Street! Things are coming out!")
				api.radioLater(15, "DOT", "Stand inside each one until it closes. You can do it on this side - no need to cross over!")
			end
		end
	end

	def.clear = function()
		for m in pairs(rifts) do
			m:Destroy()
		end
		table.clear(rifts)
		clearStormCreatures()
		removeVan()
		if tape then
			tape:Destroy()
			tape = nil
		end
		if goalRing then
			goalRing:Destroy()
			goalRing = nil
		end
		if carrier then
			carrier:SetAttribute("CarryingTape", nil)
		end
		carrier = nil
		if bigRift then
			bigRift:Destroy()
			bigRift = nil
		end
		setStorm(false)
	end

	-- the mini-rifts: closing them, and what comes out of them
	task.spawn(function()
		while true do
			task.wait(0.5)
			if stage() == "Rifts" and api.stageIs("Rifts") then
				local pilots = townTargets()
				for m, data in pairs(rifts) do
					if m.Parent then
						local inside = {}
						local near = false
						for _, t in ipairs(pilots) do
							if not t.van then
								local flat = Vector3.new(t.hrp.Position.X - data.center.X, 0, t.hrp.Position.Z - data.center.Z).Magnitude
								if flat < CLOSE_RADIUS and math.abs(t.hrp.Position.Y - data.center.Y) < 10 then
									table.insert(inside, t)
								end
								if flat < 120 then
									near = true
								end
							end
						end
						if #inside > 0 then
							data.charge = data.charge + 0.5 * (1 + 0.5 * (#inside - 1))
						else
							data.charge = math.max(data.charge - 0.25, 0)
						end
						local pct = math.clamp(data.charge / CLOSE_TIME, 0, 1)
						data.label.Text = #inside > 0 and ("CLOSING " .. math.floor(pct * 100) .. "%") or (pct > 0 and ("CLOSING " .. math.floor(pct * 100) .. "% - STAY IN!") or "STAND HERE TO CLOSE")
						data.ring.Size = Vector3.new(0.6, 11 - pct * 8, 11 - pct * 8)
						data.circle.Transparency = #inside > 0 and 0.45 or 0.7
						if data.charge >= CLOSE_TIME then
							closeRift(m, data, inside)
						elseif near and os.clock() - data.lastSpawn > 7 and stormCount() < TOWN_MAX then
							data.lastSpawn = os.clock()
							spawnTownCreature(data.center + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4)), 0.25)
						end
					end
				end
			end
		end
	end)

	return def
end
