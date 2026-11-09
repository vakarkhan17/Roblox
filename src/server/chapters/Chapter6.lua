--[[
	SIGNAL '85 — Chapter 6: THE LISTENER (task 015), the Season 1 finale.
	ModuleScript in ServerScriptService.Chapters. Story: docs/STORY.md.

	The way down: Site 2 (washroom door, open in this chapter) -> the round door in the deep
	room -> the Deep Grid, a floating world far below everything (built far away in the sky,
	the HUD gives it its own dark lighting). Falling off a platform brings you back to the
	last checkpoint; dying brings you back to the Deep Grid too.
	Stages:
	  Locks      break the 3 static locks on Ricky's cage (centre platform). Hollowers, hounds, Echoes.
	  Listener   phase 1: shoot off the Listener's 4 antennas while dodging its static beams.
	  Collapse   phase 2: the platform crumbles; drive the floating road west to the tower platform
	             before it falls (COLLAPSE_TIME). The road falls away behind you.
	  Broadcast  phase 3: stand in the 3 tower rings while WHCK and Dot play the counter-signal.
	             Every occupied ring fills it faster (alone: about 90 s, three pilots: 30 s).
	  Complete   the Listener falls silent; the rift closes for good; morning in Hollow Creek.
]]

return function(api)
	local CONFIG = api.CONFIG
	local rng = api.rng
	local Players = api.Players
	local TweenService = api.TweenService
	local ReplicatedStorage = api.ReplicatedStorage
	local newPart = api.newPart

	local STATIC = Color3.fromRGB(220, 235, 255)
	local EAR = Color3.fromRGB(120, 230, 255)
	local CABLE = Color3.fromRGB(30, 30, 38)
	local PLATFORM = Color3.fromRGB(45, 42, 52)
	local RED = Color3.fromRGB(255, 60, 70)
	local GOLD = Color3.fromRGB(255, 214, 140)
	local WHCK_BLUE = Color3.fromRGB(70, 140, 255)
	local GREEN = api.colors.GREEN

	local LOCKS = 3
	local LOCK_HEALTH = 500
	local ANTENNAS = 4
	local ANTENNA_HEALTH = 450
	local COLLAPSE_TIME = 45
	local BROADCAST_GOAL = 90 -- ring-seconds (one pilot in one ring adds 1 per second)
	local MAX_ENEMIES = 10
	local SCRAP_LOCK = 30
	local SCRAP_ANTENNA = 40

	-- the Deep Grid, far away from both worlds
	local D = Vector3.new(0, 600, 3200)
	local START = D + Vector3.new(0, 0, -130)   -- the landing (you arrive here)
	local CENTER = D                             -- Ricky's cage
	local TOWER = D + Vector3.new(-330, 0, 0)    -- the broadcast platform
	local LISTENER = D + Vector3.new(0, 0, 120)  -- behind the centre platform

	local def = { title = "THE LISTENER" }

	local grid = Instance.new("Model")
	grid.Name = "DeepGrid"
	local targetFolder = Instance.new("Folder")
	targetFolder.Name = "DeepGridTargets" -- the HUD's auto-aim looks in here too
	targetFolder.Parent = workspace

	local function light(p, color, range, brightness)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = brightness
		l.Parent = p
		return l
	end

	local function block(name, size, cf, color, material, parent)
		return newPart({ Name = name, Size = size, CFrame = cf, Color = color or PLATFORM, Material = material or Enum.Material.Slate, Parent = parent or grid })
	end

	local function billboard(p, text, color, offset)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(220, 36)
		gui.StudsOffset = Vector3.new(0, offset, 0)
		gui.MaxDistance = 400
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

	---------------------------------------------------------------------------
	-- The Deep Grid
	---------------------------------------------------------------------------
	-- platforms: top surface at D.Y
	local function platform(center, sizeX, sizeZ, name)
		local p = block(name or "DeepPlatform", Vector3.new(sizeX, 4, sizeZ), CFrame.new(center - Vector3.new(0, 2, 0)), PLATFORM)
		-- glowing cracks on the edges
		for _, side in ipairs({ -1, 1 }) do
			block("DeepEdge", Vector3.new(sizeX, 0.3, 0.6), CFrame.new(center + Vector3.new(0, 0.1, side * (sizeZ / 2 - 0.3))), EAR, Enum.Material.Neon).CanCollide = false
			block("DeepEdge", Vector3.new(0.6, 0.3, sizeZ), CFrame.new(center + Vector3.new(side * (sizeX / 2 - 0.3), 0.1, 0)), EAR, Enum.Material.Neon).CanCollide = false
		end
		return p
	end

	-- a floating piece of Hollow Creek: a chunk of street with a lamp or a shopfront
	local function townChunk(center, kind)
		block("DeepChunk", Vector3.new(16, 3, 16), CFrame.new(center - Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0),
			Color3.fromRGB(40, 40, 46), Enum.Material.Asphalt)
		if kind == 1 then
			block("DeepLampPost", Vector3.new(0.6, 12, 0.6), CFrame.new(center + Vector3.new(4, 6, 4)), Color3.fromRGB(60, 60, 66), Enum.Material.Metal)
			local bulb = block("DeepLamp", Vector3.new(1.4, 1, 1.4), CFrame.new(center + Vector3.new(4, 12.5, 4)), RED, Enum.Material.Neon)
			light(bulb, RED, 30, 2)
		else
			block("DeepShop", Vector3.new(10, 9, 2), CFrame.new(center + Vector3.new(0, 4.5, -5)), Color3.fromRGB(110, 70, 60), Enum.Material.Brick)
			block("DeepShopSign", Vector3.new(6, 1.4, 0.3), CFrame.new(center + Vector3.new(0, 8, -3.9)), RED, Enum.Material.Neon)
		end
	end

	platform(START, 44, 44, "DeepLanding")
	platform(CENTER, 90, 90, "DeepCenter")
	platform(TOWER, 80, 80, "DeepTowerPlatform")
	-- the walkway from the landing to the centre (with floating town pieces along it)
	block("DeepWalkway", Vector3.new(16, 4, 66), CFrame.new(D + Vector3.new(0, -2, -77)), PLATFORM)
	for i, z in ipairs({ -120, -80, -40 }) do
		townChunk(D + Vector3.new(i % 2 == 0 and 34 or -34, rng:NextNumber(-6, 6), z), i % 2 + 1)
	end
	for _ = 1, 10 do
		local p = D + Vector3.new(rng:NextNumber(-260, 160), rng:NextNumber(-80, 60), rng:NextNumber(-220, 220))
		if (p - CENTER).Magnitude > 80 and (p - TOWER).Magnitude > 70 and (p - START).Magnitude > 50 then
			townChunk(p, rng:NextInteger(1, 2))
		end
	end
	-- humming cables and broken radio towers drifting in the dark
	for _ = 1, 16 do
		local a = D + Vector3.new(rng:NextNumber(-380, 200), rng:NextNumber(-120, 120), rng:NextNumber(-260, 260))
		local b = a + Vector3.new(rng:NextNumber(-120, 120), rng:NextNumber(-60, 60), rng:NextNumber(-120, 120))
		local len = (b - a).Magnitude
		local cable = block("DeepCable", Vector3.new(0.6, 0.6, len), CFrame.lookAt(a, b) * CFrame.new(0, 0, -len / 2), CABLE, Enum.Material.Metal)
		cable.CanCollide = false
	end
	for i = 1, 6 do
		local base = D + Vector3.new(rng:NextNumber(-360, 180), rng:NextNumber(-140, -60), rng:NextNumber(-240, 240))
		local tower = block("DeepBrokenTower", Vector3.new(2, 50, 2), CFrame.new(base) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)),
			Color3.fromRGB(150, 40, 40), Enum.Material.Metal)
		tower.CanCollide = false
		if i % 2 == 0 then
			light(tower, RED, 40, 1)
		end
	end

	-- Ricky's cage: static bars around a small platform in the centre
	local cageBars = {}
	for k = 1, 16 do
		local a = k / 16 * math.pi * 2
		local bar = block("RickyCageBar", Vector3.new(0.5, 12, 0.5), CFrame.new(CENTER + Vector3.new(math.cos(a) * 6, 6, math.sin(a) * 6)),
			STATIC, Enum.Material.Neon)
		table.insert(cageBars, bar)
	end
	local ricky = block("Ricky", Vector3.new(2, 5, 1.2), CFrame.new(CENTER + Vector3.new(0, 2.5, 0)), Color3.fromRGB(60, 90, 170), Enum.Material.SmoothPlastic)
	ricky.CanCollide = false
	block("RickyHead", Vector3.new(1.5, 1.5, 1.5), CFrame.new(CENTER + Vector3.new(0, 5.8, 0)), Color3.fromRGB(234, 192, 158), Enum.Material.SmoothPlastic).CanCollide = false
	local rickyLabel = billboard(ricky, "RICKY", WHCK_BLUE, 6)

	-- the tower platform: three broken radio towers, each with a ring to stand in
	local RING_SPOTS = {}
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		local spot = TOWER + Vector3.new(math.cos(a) * 22, 0, math.sin(a) * 22)
		table.insert(RING_SPOTS, spot)
		block("DeepRadioTower", Vector3.new(1.6, 34, 1.6), CFrame.new(spot + Vector3.new(0, 17, 0) + (spot - TOWER).Unit * 9), Color3.fromRGB(170, 40, 40), Enum.Material.Metal)
	end
	local towerGoal = block("DeepTowerGoal", Vector3.new(0.3, 30, 30), CFrame.new(TOWER + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Neon)
	towerGoal.Shape = Enum.PartType.Cylinder
	towerGoal.Transparency = 0.75
	towerGoal.CanCollide = false
	towerGoal.CanQuery = false

	grid.Parent = workspace
	workspace:SetAttribute("DeepGridCenter", D)
	workspace:SetAttribute("DeepGridHalf", Vector3.new(420, 200, 300)) -- the HUD: Deep Grid lighting + label

	---------------------------------------------------------------------------
	-- Who is in the Deep Grid; falling; respawning back down here
	---------------------------------------------------------------------------
	local function inDeepGrid(position)
		local rel = position - D
		return math.abs(rel.X + 100) < 430 and math.abs(rel.Z) < 310 and rel.Y > -400 and rel.Y < 250
	end

	local function deepTargets()
		local list = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 and not char:GetAttribute("Downed") and inDeepGrid(hrp.Position) then
				table.insert(list, { plr = plr, hrp = hrp, hum = hum })
			end
		end
		return list
	end

	local visited = {}   -- [player] = true once they came down this chapter
	local checkpoint = START

	local function teleport(plr, at, lookAt)
		local char = plr.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			char:PivotTo(CFrame.lookAt(at + Vector3.new(0, 3.5, 0), (lookAt or CENTER) + Vector3.new(0, 3.5, 0)))
			api.sparkBurst(at + Vector3.new(0, 3, 0), EAR, 20, 14, 0.4, 0.5)
		end
	end

	local function active()
		local s = ReplicatedStorage:GetAttribute("Stage")
		return ReplicatedStorage:GetAttribute("Chapter") == 6 and (s == "Locks" or s == "Listener" or s == "Collapse" or s == "Broadcast")
	end

	Players.PlayerRemoving:Connect(function(plr)
		visited[plr] = nil
	end)

	-- after dying, pilots who were already down here come back to the checkpoint
	local function hookPlayer(plr)
		plr.CharacterAdded:Connect(function(char)
			if not active() or not visited[plr] then
				return
			end
			char:WaitForChild("HumanoidRootPart", 5)
			task.wait(1.5) -- let the main script dress the character first
			if active() and plr.Character == char then
				teleport(plr, checkpoint)
				api.remotes.Notify:FireClient(plr, "BACK IN THE DEEP GRID", EAR)
			end
		end)
	end
	Players.PlayerAdded:Connect(hookPlayer)
	for _, plr in ipairs(Players:GetPlayers()) do
		hookPlayer(plr)
	end

	---------------------------------------------------------------------------
	-- Enemies down here
	---------------------------------------------------------------------------
	local function deepCount()
		local n = 0
		for _, data in pairs(api.creatures) do
			if data.deep then
				n = n + 1
			end
		end
		return n
	end

	local function deepCreature(m)
		local data = m and api.creatures[m]
		if data then
			data.deep = true
			data.targets = deepTargets
		end
	end

	local function spawnEnemy(at)
		local roll = rng:NextNumber()
		if roll < 0.25 and api.shared.spawnEcho then
			api.shared.spawnEcho(at, deepTargets)
			-- the newest Echo: mark it as a Deep Grid creature
			for m, data in pairs(api.creatures) do
				if m.Name == "Echo" and not data.deep then
					data.deep = true
				end
			end
		elseif roll < 0.5 then
			for _, m in ipairs(api.spawnHoundPack(at)) do
				deepCreature(m)
			end
		else
			deepCreature(api.spawnCreature(at))
		end
	end

	local function clearDeepCreatures()
		for m, data in pairs(api.creatures) do
			if data.deep then
				api.creatures[m] = nil
				m:Destroy()
			end
		end
	end

	-- a static beam from above: a red warning circle, then the hit
	local function beam(at, damage)
		local warn = newPart({ Name = "BeamWarning", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 14, 14), Color = RED, Material = Enum.Material.Neon,
			Transparency = 0.5, CanCollide = false, CanQuery = false, CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Parent = workspace })
		TweenService:Create(warn, TweenInfo.new(1.4), { Transparency = 0.1 }):Play()
		task.delay(1.4, function()
			warn:Destroy()
			local column = newPart({ Name = "StaticBeam", Size = Vector3.new(5, 80, 5), Position = at + Vector3.new(0, 40, 0), Color = STATIC,
				Material = Enum.Material.Neon, Transparency = 0.2, CanCollide = false, CanQuery = false, Parent = workspace })
			TweenService:Create(column, TweenInfo.new(0.5), { Transparency = 1, Size = Vector3.new(0.5, 80, 0.5) }):Play()
			api.Debris:AddItem(column, 0.6)
			api.sparkBurst(at + Vector3.new(0, 1, 0), STATIC, 30, 30, 0.5, 0.5)
			for _, t in ipairs(deepTargets()) do
				if (Vector3.new(t.hrp.Position.X - at.X, 0, t.hrp.Position.Z - at.Z)).Magnitude < 7 then
					api.hurtPlayer(t.plr, t.hum, damage)
				end
			end
		end)
	end

	---------------------------------------------------------------------------
	-- The Listener
	---------------------------------------------------------------------------
	local listener = Instance.new("Model")
	listener.Name = "TheListener"
	do
		local body = block("ListenerBody", Vector3.new(30, 70, 30), CFrame.new(LISTENER + Vector3.new(0, 10, 30)), Color3.fromRGB(14, 12, 20), Enum.Material.Slate, listener)
		block("ListenerShoulder", Vector3.new(60, 14, 22), CFrame.new(LISTENER + Vector3.new(0, 38, 30)), Color3.fromRGB(18, 16, 26), Enum.Material.Slate, listener)
		local ear = block("ListenerEar", Vector3.new(3, 46, 46), CFrame.new(LISTENER + Vector3.new(0, 30, 12)) * CFrame.Angles(0, math.rad(90), 0), EAR, Enum.Material.Neon, listener)
		ear.Shape = Enum.PartType.Cylinder
		ear.CanCollide = false
		local inner = block("ListenerEarInner", Vector3.new(3.4, 30, 30), CFrame.new(LISTENER + Vector3.new(0, 30, 11)) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(5, 5, 10), Enum.Material.Glass, listener)
		inner.Shape = Enum.PartType.Cylinder
		inner.CanCollide = false
		light(ear, EAR, 120, 4)
		-- static flickering over it
		for _ = 1, 24 do
			local s = block("ListenerStatic", Vector3.new(rng:NextNumber(1, 4), rng:NextNumber(0.3, 1), 0.3),
				CFrame.new(LISTENER + Vector3.new(rng:NextNumber(-28, 28), rng:NextNumber(0, 50), rng:NextNumber(8, 16))), STATIC, Enum.Material.Neon, listener)
			s.CanCollide = false
			TweenService:Create(s, TweenInfo.new(rng:NextNumber(0.1, 0.4), Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), { Transparency = 1 }):Play()
		end
		listener.PrimaryPart = body
	end
	listener.Parent = grid

	---------------------------------------------------------------------------
	-- Targets: the locks (stage Locks) and the antennas (stage Listener)
	---------------------------------------------------------------------------
	local targets = {} -- [model] = { center, kind }

	local function makeTarget(kind, center, health, build)
		local m = Instance.new("Model")
		m.Name = kind == "lock" and "StaticLock" or "ListenerAntenna"
		local main = build(m)
		m.PrimaryPart = main
		m:SetAttribute("Target", true)
		m:SetAttribute("Chapter", 6)
		m:SetAttribute("Health", health)
		m:SetAttribute("MaxHealth", health)
		api.addHealthBar(main, 140, kind == "lock" and 5 or 12, kind == "lock" and STATIC or RED)
		m.Parent = targetFolder
		targets[m] = { center = center, kind = kind }
		return m
	end

	local function spawnLock(index)
		local a = (index - 1) / LOCKS * math.pi * 2 + 0.5
		local center = CENTER + Vector3.new(math.cos(a) * 18, 3, math.sin(a) * 18)
		makeTarget("lock", center, LOCK_HEALTH, function(m)
			local core = block("LockCore", Vector3.new(4, 4, 4), CFrame.new(center) * CFrame.Angles(0.6, 0.6, 0), STATIC, Enum.Material.Neon, m)
			for _, offset in ipairs({ Vector3.new(0, 4, 0), Vector3.new(0, -2.6, 0) }) do
				block("LockRing", Vector3.new(0.6, 6, 6), CFrame.new(center + offset) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 60, 80), Enum.Material.Metal, m).Shape = Enum.PartType.Cylinder
			end
			-- a beam of static from the lock to the cage
			local len = (CENTER + Vector3.new(0, 6, 0) - center).Magnitude
			local link = block("LockLink", Vector3.new(0.4, 0.4, len), CFrame.lookAt(center, CENTER + Vector3.new(0, 6, 0)) * CFrame.new(0, 0, -len / 2), STATIC, Enum.Material.Neon, m)
			link.CanCollide = false
			link.CanQuery = false
			light(core, STATIC, 20, 2)
			return core
		end)
	end

	local ANTENNA_SPOTS = { Vector3.new(-26, 48, 30), Vector3.new(26, 48, 30), Vector3.new(-14, 60, 26), Vector3.new(14, 60, 26) }
	local function spawnAntenna(index)
		local center = LISTENER + ANTENNA_SPOTS[index]
		makeTarget("antenna", center + Vector3.new(0, 14, 0), ANTENNA_HEALTH, function(m)
			local mast = block("AntennaMast", Vector3.new(2.4, 28, 2.4), CFrame.new(center + Vector3.new(0, 14, 0)) * CFrame.Angles(0, 0, (index % 2 == 0 and -1 or 1) * 0.25),
				Color3.fromRGB(70, 70, 80), Enum.Material.Metal, m)
			local tip = block("AntennaTip", Vector3.new(3.4, 3.4, 3.4), CFrame.new(center + Vector3.new(0, 28, 0)), RED, Enum.Material.Neon, m)
			tip.Shape = Enum.PartType.Ball
			light(tip, RED, 30, 3)
			return mast
		end)
	end

	def.targets = function()
		local list = {}
		for m, data in pairs(targets) do
			table.insert(list, { model = m, center = data.center })
		end
		return list
	end

	local function clearTargets()
		for m in pairs(targets) do
			m:Destroy()
		end
		table.clear(targets)
	end

	local function setBossBar()
		local total = 0
		for m, data in pairs(targets) do
			if data.kind == "antenna" then
				total = total + math.max(m:GetAttribute("Health") or 0, 0)
			end
		end
		ReplicatedStorage:SetAttribute("BossHealth", total)
	end

	local startListener, startCollapse -- below
	local roundPromptEnabled -- (on) the "Descend" prompt on Site 2's round door, below

	def.damageTarget = function(model, amount, player)
		local data = targets[model]
		if model:GetAttribute("Chapter") ~= 6 or not data then
			return false
		end
		local hp = (model:GetAttribute("Health") or 0) - amount
		model:SetAttribute("Health", hp)
		api.updateHealthBar(model)
		if data.kind == "antenna" then
			setBossBar()
		end
		if hp > 0 then
			return true, false
		end
		targets[model] = nil
		api.sparkBurst(data.center, data.kind == "lock" and STATIC or RED, 70, 45, 0.9, 1)
		model:Destroy()
		local goal = ReplicatedStorage:GetAttribute("Goal") or 1
		local progress = math.min((ReplicatedStorage:GetAttribute("Progress") or 0) + 1, goal)
		ReplicatedStorage:SetAttribute("Progress", progress)
		if player then
			api.awardScrap(player, data.kind == "lock" and SCRAP_LOCK or SCRAP_ANTENNA, data.kind == "lock" and "STATIC LOCK" or "ANTENNA")
			api.track(player, "objective", 1)
		end
		api.checkpoint()
		if data.kind == "lock" then
			api.notifyAll("STATIC LOCK BROKEN [" .. progress .. "/" .. goal .. "]", STATIC)
			if progress >= goal then
				for _, bar in ipairs(cageBars) do
					bar.Transparency = 1
					bar.CanCollide = false
				end
				rickyLabel.Text = "RICKY - FREE!"
				api.notifyAll("RICKY IS FREE!", GREEN)
				api.radioLater(1, "RICKY", "I'm out! I'm OUT! Guys, behind me - it's waking up. THE LISTENER!")
				local token = api.token()
				task.delay(5, function()
					if token == api.token() and api.stageIs("Locks") then
						startListener()
					end
				end)
			end
		else
			api.notifyAll("ANTENNA DOWN [" .. progress .. "/" .. goal .. "]", RED)
			if progress >= goal then
				local token = api.token()
				task.delay(2, function()
					if token == api.token() and api.stageIs("Listener") then
						startCollapse()
					end
				end)
			elseif progress == 2 then
				api.radioLater(1, "DOT", "It can't hear as well without them! Two more antennas!")
			end
		end
		return true, true
	end

	---------------------------------------------------------------------------
	-- Stages
	---------------------------------------------------------------------------
	local road = {} -- the collapsing road segments (phase 2) and the broadcast rings

	local function startLocks(done)
		api.setStage("Locks", done, LOCKS)
		checkpoint = START
		for _, bar in ipairs(cageBars) do
			bar.Transparency = 0
			bar.CanCollide = true
		end
		rickyLabel.Text = "RICKY"
		for i = done + 1, LOCKS do
			spawnLock(i)
		end
		if done == 0 then
			api.radioLater(3, "DOT", "Ricky's walkie is still on... it's coming from UNDER Site 2. The round door in the deep room - it's open now.")
			api.radioLater(10, "DOT", "Go down. Bring him back. Please.")
		end
	end

	startListener = function()
		clearTargets()
		api.setStage("Listener", 0, ANTENNAS)
		checkpoint = START
		for i = 1, ANTENNAS do
			spawnAntenna(i)
		end
		ReplicatedStorage:SetAttribute("BossName", "THE LISTENER")
		ReplicatedStorage:SetAttribute("BossMaxHealth", ANTENNA_HEALTH * ANTENNAS)
		setBossBar()
		ReplicatedStorage:SetAttribute("BossOpen", false)
		api.notifyAll("THE LISTENER - SHOOT OFF ITS 4 ANTENNAS! DODGE THE RED CIRCLES!", RED)
		api.radioLater(2, "DR. MARSH", "...it listens through the antennas. Without them it is deaf and blind...")
		api.radioLater(8, "DOT", "That's from the tape! The antennas on its back - shoot them!")
	end

	startCollapse = function()
		local token = api.token()
		clearTargets()
		ReplicatedStorage:SetAttribute("BossMaxHealth", 0)
		ReplicatedStorage:SetAttribute("BossHealth", 0)
		api.setStage("Collapse", 0, COLLAPSE_TIME)
		local deadline = workspace:GetServerTimeNow() + COLLAPSE_TIME
		ReplicatedStorage:SetAttribute("Deadline", deadline)
		checkpoint = TOWER -- falling now drops you at the tower platform (it's a chase, not a trap)
		api.notifyAll("THE PLATFORM IS FALLING! DRIVE WEST TO THE TOWER PLATFORM!", RED)
		api.radioLater(1, "RICKY", "The road! Follow the floating road to the radio towers - CAR MODE, GO GO GO!")
		-- the floating road from the centre (west edge) to the tower platform (east edge)
		for _, p in ipairs(road) do
			p:Destroy()
		end
		table.clear(road)
		local from, to = CENTER.X - 45, TOWER.X + 40
		local count = math.floor((from - to) / 10)
		for i = 0, count - 1 do
			local x = from - 5 - i * 10
			local seg = block("DeepRoad", Vector3.new(10.4, 3, 22), CFrame.new(Vector3.new(x, D.Y - 1.5 + math.sin(i * 0.6) * 1.5, D.Z)), Color3.fromRGB(40, 40, 46), Enum.Material.Asphalt)
			block("DeepRoadLine", Vector3.new(6, 0.1, 0.6), CFrame.new(seg.Position + Vector3.new(0, 1.55, 0)), GOLD, Enum.Material.Neon).CanCollide = false
			table.insert(road, seg)
		end
		-- the centre platform and then the road fall away, chasing you west
		task.spawn(function()
			local start = os.clock()
			local fallen = 0
			while token == api.token() and api.stageIs("Collapse") do
				task.wait(0.3)
				local elapsed = os.clock() - start
				-- one segment every 0.9 s, starting after 6 s
				local shouldFall = math.floor(math.max(elapsed - 6, 0) / 0.9)
				while fallen < shouldFall and fallen < #road do
					fallen = fallen + 1
					local seg = road[fallen]
					if seg and seg.Parent then
						seg.Color = RED
						TweenService:Create(seg, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
							{ Position = seg.Position - Vector3.new(0, 120, 0), Transparency = 1 }):Play()
						api.Debris:AddItem(seg, 2.1)
					end
				end
				-- everyone on the tower platform (or time up): phase 3
				local pilots = deepTargets()
				local onTower, total = 0, #pilots
				for _, t in ipairs(pilots) do
					if (Vector3.new(t.hrp.Position.X - TOWER.X, 0, t.hrp.Position.Z - TOWER.Z)).Magnitude < 42 then
						onTower = onTower + 1
					end
				end
				ReplicatedStorage:SetAttribute("Progress", math.clamp(math.floor(elapsed), 0, COLLAPSE_TIME))
				if (total > 0 and onTower == total) or workspace:GetServerTimeNow() >= deadline then
					def.startBroadcast(0)
					return
				end
			end
		end)
	end

	def.startBroadcast = function(done)
		local token = api.token()
		clearTargets()
		ReplicatedStorage:SetAttribute("Deadline", 0)
		api.setStage("Broadcast", done, BROADCAST_GOAL)
		checkpoint = TOWER
		-- anyone left behind on the fallen road is pulled to the towers (nobody gets stuck)
		for _, t in ipairs(deepTargets()) do
			if (Vector3.new(t.hrp.Position.X - TOWER.X, 0, t.hrp.Position.Z - TOWER.Z)).Magnitude > 42 then
				teleport(t.plr, TOWER + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8)), LISTENER)
			end
		end
		-- the three rings
		local rings = {}
		for i, spot in ipairs(RING_SPOTS) do
			local ring = block("BroadcastRing", Vector3.new(0.3, 16, 16), CFrame.new(spot + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				WHCK_BLUE, Enum.Material.Neon)
			ring.Shape = Enum.PartType.Cylinder
			ring.Transparency = 0.5
			ring.CanCollide = false
			ring.CanQuery = false
			ring:SetAttribute("Ring", i)
			rings[i] = ring
			table.insert(road, ring) -- cleaned up with the road
		end
		api.notifyAll("STAND IN THE 3 BLUE RINGS - THE COUNTER-SIGNAL IS PLAYING!", WHCK_BLUE)
		api.radioLater(1, "WHCK", "This is WHCK 85.5, Hollow Creek. This next one goes out to everyone down there.")
		api.radioLater(6, "DOT", "Stand in the rings by the towers! The more rings you hold, the faster it goes!")
		task.spawn(function()
			local charge = done
			local lastLine = 0
			while token == api.token() and api.stageIs("Broadcast") do
				task.wait(0.5)
				local occupied = 0
				local pilots = deepTargets()
				for i, spot in ipairs(RING_SPOTS) do
					local held = false
					for _, t in ipairs(pilots) do
						if (Vector3.new(t.hrp.Position.X - spot.X, 0, t.hrp.Position.Z - spot.Z)).Magnitude < 8 and math.abs(t.hrp.Position.Y - spot.Y) < 10 then
							held = true
						end
					end
					rings[i].Transparency = held and 0.15 or 0.55
					if held then
						occupied = occupied + 1
					end
				end
				charge = math.min(charge + occupied * 0.5, BROADCAST_GOAL)
				ReplicatedStorage:SetAttribute("Progress", math.floor(charge))
				local pct = charge / BROADCAST_GOAL
				if pct > 0.5 and lastLine < 1 then
					lastLine = 1
					api.radioLater(0, "RICKY", "It's working! It's covering its ear - KEEP GOING!")
				elseif pct > 0.85 and lastLine < 2 then
					lastLine = 2
					api.radioLater(0, "DOT", "Almost there! Don't let go!")
				end
				if charge >= BROADCAST_GOAL then
					def.complete(true)
					return
				end
			end
		end)
	end

	---------------------------------------------------------------------------
	-- The end of Season 1
	---------------------------------------------------------------------------
	def.complete = function(announce)
		local token = api.token()
		clearTargets()
		clearDeepCreatures()
		for _, p in ipairs(road) do
			p:Destroy()
		end
		table.clear(road)
		ReplicatedStorage:SetAttribute("BossMaxHealth", 0)
		ReplicatedStorage:SetAttribute("Deadline", 0)
		api.setStage("Complete", 1, 1)
		listener.Parent = nil -- it falls silent
		if not announce then
			return
		end
		workspace:SetAttribute("Whiteout", workspace:GetServerTimeNow()) -- the HUD fades to white
		api.notifyAll("THE LISTENER IS SILENT.", STATIC)
		api.awardEveryone(CONFIG.SCRAP_CHAPTER * 3, "SEASON 1 COMPLETE")
		api.chapterCleared(6)
		task.delay(4, function()
			if token ~= api.token() then
				return
			end
			-- home: morning in Hollow Creek
			for _, plr in ipairs(Players:GetPlayers()) do
				local char = plr.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp and inDeepGrid(hrp.Position) then
					char:PivotTo(CFrame.new(Vector3.new(rng:NextNumber(-6, 6), 4, 200 + rng:NextNumber(-6, 6))))
				end
				plr:SetAttribute("Dimension", "Town")
			end
			workspace:SetAttribute("Morning", true)
			api.notifyAll("CHAPTER 6 COMPLETE — THE RIFT IS CLOSED. FOR GOOD.", GREEN)
		end)
		api.radioLater(7, "WHCK", "Good morning, Hollow Creek. It's 6 a.m. and... it's a beautiful day.")
		api.radioLater(13, "RICKY", "Best. Night. Ever. ...Can we sleep now?")
		api.radioLater(18, "DOT", "The Shiftframes are powering down in the garage. Thank you. All of you.")
		task.delay(25, function()
			if token == api.token() then
				api.notifyAll("SIGNAL '85 — SEASON 1 COMPLETE. THANK YOU FOR PLAYING!", GOLD)
			end
		end)
		task.delay(32, function()
			if token == api.token() then
				api.notifyAll("...in the garage, one Shiftframe's eyes flicker on again.", RED)
			end
		end)
	end

	-- stageState.stage = "Locks" (default) | "Listener" | "Complete" (the boss restarts from phase 1); progress = locks broken
	def.start = function(stageState)
		local stage0 = stageState.stage or "Locks"
		workspace:SetAttribute("Morning", nil)
		workspace:SetAttribute("Whiteout", nil)
		listener.Parent = grid
		table.clear(visited)
		if api.shared.openSite2 then
			api.shared.openSite2(true) -- the washroom door and the vault are open; the round door leads down
		end
		roundPromptEnabled(stage0 ~= "Complete")
		if stage0 == "Complete" then
			def.complete(false)
			workspace:SetAttribute("Morning", true)
		elseif stage0 == "Listener" or stage0 == "Collapse" or stage0 == "Broadcast" then
			for _, bar in ipairs(cageBars) do
				bar.Transparency = 1
				bar.CanCollide = false
			end
			rickyLabel.Text = "RICKY - FREE!"
			startListener()
		else
			startLocks(math.clamp(stageState.progress or 0, 0, LOCKS - 1))
		end
	end

	def.clear = function()
		clearTargets()
		clearDeepCreatures()
		for _, p in ipairs(road) do
			p:Destroy()
		end
		table.clear(road)
		roundPromptEnabled(false)
		workspace:SetAttribute("Morning", nil)
		workspace:SetAttribute("Whiteout", nil)
		-- anyone still down here goes home
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and inDeepGrid(hrp.Position) then
				char:PivotTo(CFrame.new(Vector3.new(0, 4, 200)))
			end
		end
	end

	---------------------------------------------------------------------------
	-- The round door in Site 2's deep room: "Descend"
	---------------------------------------------------------------------------
	local roundPrompt = nil
	roundPromptEnabled = function(on)
		if not roundPrompt then
			local site = workspace:FindFirstChild("Site2")
			local door = site and site:FindFirstChild("Site2RoundDoor")
			if not door then
				return
			end
			roundPrompt = Instance.new("ProximityPrompt")
			roundPrompt.Name = "DeepGridPrompt"
			roundPrompt.ActionText = "Descend"
			roundPrompt.ObjectText = "The round door"
			roundPrompt.HoldDuration = 1
			roundPrompt.MaxActivationDistance = 14
			roundPrompt.RequiresLineOfSight = false
			roundPrompt.Parent = door
			roundPrompt.Triggered:Connect(function(plr)
				if not active() then
					return
				end
				visited[plr] = true
				teleport(plr, checkpoint)
				api.remotes.Notify:FireClient(plr, "THE DEEP GRID", EAR)
			end)
		end
		roundPrompt.Enabled = on
	end

	-- falling off, enemies, beams
	task.spawn(function()
		local lastSpawn, lastBeam = 0, 0
		while true do
			task.wait(0.5)
			if active() then
				local s = ReplicatedStorage:GetAttribute("Stage")
				local pilots = deepTargets()
				for _, t in ipairs(pilots) do
					visited[t.plr] = true
					if t.hrp.Position.Y < D.Y - 50 then
						teleport(t.plr, checkpoint)
						api.hurtPlayer(t.plr, t.hum, 20)
						api.remotes.Notify:FireClient(t.plr, "THE STATIC CAUGHT YOU", RED)
					end
				end
				local now = os.clock()
				if #pilots > 0 and (s == "Locks" or s == "Listener" or s == "Broadcast") and now - lastSpawn > (s == "Broadcast" and 4 or 6)
					and deepCount() < MAX_ENEMIES then
					lastSpawn = now
					local base = s == "Broadcast" and TOWER or CENTER
					local a = rng:NextNumber(0, math.pi * 2)
					spawnEnemy(base + Vector3.new(math.cos(a) * 34, 0, math.sin(a) * 34))
				end
				if #pilots > 0 and (s == "Listener" or s == "Broadcast") and now - lastBeam > (s == "Broadcast" and 2.5 or 4) then
					lastBeam = now
					local t = pilots[rng:NextInteger(1, #pilots)]
					beam(Vector3.new(t.hrp.Position.X, D.Y, t.hrp.Position.Z), 25)
				end
			end
		end
	end)

	return def
end
