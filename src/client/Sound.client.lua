--[[
	SIGNAL '85  —  Sound and music (client, Phase B + task 018)
	Put this LocalScript in StarterPlayer > StarterPlayerScripts.

	HOW TO CHANGE A SOUND
	Every sound is one line in the SOUNDS table below. They start with sounds that ship
	with Roblox itself (rbxasset://...), as stand-ins, so the game has sound without uploads.
	To use a better one: Studio > Toolbox > Audio, search (each line has search words),
	listen, right-click > Copy Asset ID, and put "rbxassetid://<id>" in that line's id.
	Audio published by Roblox is free to use and always works; other people's audio is often
	private and stays silent. An id of "" switches a sound off.

	MUSIC and AMBIENCE work the same way (MUSIC is empty to start with).
	Volume: MENU > SETTINGS > SOUND VOLUME (player attribute SoundVolume, 0-10).

	The script only listens to what already happens in the game (attributes, remotes, parts
	appearing), so nothing else needs to change when a sound is replaced.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Signal85Remotes")

-- id, volume (0-1), pitch (1 = normal). The comment is what to search for in the Toolbox.
local SOUNDS = {
	-- weapons
	shot = { id = "rbxassetid://127890377497804", volume = 0.35, pitch = 1 },      -- "laser shot", "blaster"
	shotHeavy = { id = "rbxassetid://101141991842638", volume = 0.5, pitch = 1 },  -- "heavy laser", "plasma cannon"
	baton = { id = "rbxassetid://9125915779", volume = 0.6, pitch = 1 },                   -- "electric zap", "taser"
	reload = { id = "rbxassetid://117963160131194", volume = 0.6, pitch = 1 },               -- "gun reload"
	empty = { id = "rbxassetid://86447624914124", volume = 0.5, pitch = 1 },                -- "empty gun click"
	hit = { id = "rbxassetid://137825769816644", volume = 0.35, pitch = 1 },                   -- "hit marker", "impact"
	kill = { id = "rbxassetid://70514426994847", volume = 0.6, pitch = 1 },                   -- "monster death", "poof"
	-- you
	transform = { id = "rbxassetid://2789428506", volume = 0.7, pitch = 1 },               -- "transformer", "mech transform"
	rift = { id = "rbxassetid://116474323965002", volume = 0.9, pitch = 1 },                    -- "portal", "teleport whoosh"
	hurt = { id = "rbxassetid://137000839835781", volume = 0.5, pitch = 1 },                   -- "hurt", "damage grunt"
	robotStep = { id = "rbxassetid://97820324060992", volume = 0.22, pitch = 1 },            -- "robot footstep", "metal step"
	engine = { id = "rbxassetid://127337768162638", volume = 0.35, pitch = 1 },           -- "car engine loop" (must loop)
	-- hotel
	doorOpen = { id = "rbxassetid://108910910692681", volume = 0.6, pitch = 1 },              -- "wooden door open", "door creak"
	doorClose = { id = "rbxassetid://8981398719", volume = 0.5, pitch = 1 },              -- "door close", "door slam"
	elevatorDing = { id = "rbxassetid://120506509943073", volume = 0.6, pitch = 1 }, -- "elevator ding"
	elevatorStuck = { id = "rbxassetid://90655312432892", volume = 0.5, pitch = 1 },             -- "error buzz", "access denied"
	-- creatures and bosses
	growl = { id = "rbxassetid://95846760088417", volume = 0.45, pitch = 1 },          -- "monster growl", "creature breathing"
	houndCrackle = { id = "rbxassetid://9117070094", volume = 0.3, pitch = 1 }, -- "electric crackle", "static"
	echoHum = { id = "rbxassetid://113645827993384", volume = 0.35, pitch = 1 },        -- "robot hum", "dark synth"
	echoShot = { id = "rbxassetid://75750368645382", volume = 0.5, pitch = 1 },             -- "enemy laser"
	bossOpen = { id = "rbxassetid://82458804337703", volume = 0.8, pitch = 1 },              -- "boss roar", "monster screech"
	bossSlam = { id = "rbxassetid://88904402864907", volume = 0.9, pitch = 1 },              -- "ground slam", "explosion"
	beamWarning = { id = "rbxassetid://9113084658", volume = 0.5, pitch = 1 }, -- "warning beep", "alarm"
	beam = { id = "rbxassetid://130715468492260", volume = 0.7, pitch = 1 },          -- "lightning strike", "energy beam"
	-- pickups and messages
	pickup = { id = "rbxassetid://126241962513719", volume = 0.45, pitch = 1 },    -- "item pickup", "collect"
	scrap = { id = "rbxassetid://73398107713829", volume = 0.3, pitch = 1 },      -- "coin", "cash"
	fanfare = { id = "rbxassetid://120682227591051", volume = 0.6, pitch = 1 },                  -- "level up", "achievement", "victory"
	alert = { id = "rbxassetid://96924810403789", volume = 0.45, pitch = 1 },                      -- "alert", "warning"
	notify = { id = "rbxassetid://90035739456316", volume = 0.25, pitch = 1 },      -- "notification"
	ping = { id = "rbxassetid://106145041472451", volume = 0.45, pitch = 1 },      -- "ping", "radar"
	prompt = { id = "rbxassetid://84766291779256", volume = 0.5, pitch = 1 },               -- "button press"
	click = { id = "rbxassetid://18772000042", volume = 0.4, pitch = 1 },                     -- "ui click", "menu click"
	-- one-shots inside the ambience
	thunder = { id = "rbxassetid://139319051979882", volume = 0.5, pitch = 1 },         -- "thunder"
	drip = { id = "rbxassetid://9120516884", volume = 0.25, pitch = 1 },             -- "water drip"
}

-- background music per place / moment, e.g. "rbxassetid://1234567890". "" = silence.
local MUSIC = {
	Town = "rbxassetid://1847209289",        -- "synthwave loop", "80s retro"
	Undergrid = "rbxassetid://8857448898",   -- "dark ambient", "horror ambience"
	Boss = "rbxassetid://9045701292",        -- "boss battle", "intense synth"  (Mind Warden, Carrier, WHCK van, the Listener)
	Storm = "rbxassetid://9048212787",       -- "tense music", "suspense"       (Chapter 5)
	Site2 = "rbxassetid://96727522170625",       -- "creepy bunker", "horror drone" (Chapter 4)
	DeepGrid = "rbxassetid://70986673915317",    -- "epic dark", "void ambience"    (Chapter 6)
	Morning = "rbxassetid://122687206439648",     -- "calm morning", "happy ending"
	Menu = "rbxassetid://9042410252",        -- "menu music", "80s title theme"
}

-- a quiet loop per place (under the music), and a random one-shot now and then
local AMBIENCE = {
	Undergrid = { id = "rbxassetid://9125615158", volume = 0.2, pitch = 1 },       -- "wind loop", "eerie wind"
	Storm = { id = "rbxassetid://130796038173607", volume = 0.3, pitch = 1, oneShot = "thunder", every = { 8, 16 } }, -- "storm wind", "static noise"
	Site2 = { id = "rbxassetid://108841455819405", volume = 0.1, pitch = 1, oneShot = "drip", every = { 3, 7 } },    -- "room tone", "bunker hum"
	DeepGrid = { id = "rbxassetid://1838762089", volume = 0.25, pitch = 1 },       -- "deep space drone", "low hum"
}

---------------------------------------------------------------------------
-- Groups, volume, play helpers
---------------------------------------------------------------------------
local sfxGroup = Instance.new("SoundGroup")
sfxGroup.Name = "Signal85SFX"
sfxGroup.Parent = SoundService
local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "Signal85Music"
musicGroup.Parent = SoundService

local function applyVolume()
	local v = math.clamp(player:GetAttribute("SoundVolume") or 8, 0, 10) / 10
	sfxGroup.Volume = v
	musicGroup.Volume = v * 0.5
end
player:GetAttributeChangedSignal("SoundVolume"):Connect(applyVolume)
applyVolume()

local lastPlayed = {}
local function ready(name, minGap)
	local s = SOUNDS[name]
	if not s or s.id == "" then
		return nil
	end
	local now = os.clock()
	if minGap and lastPlayed[name] and now - lastPlayed[name] < minGap then
		return nil
	end
	lastPlayed[name] = now
	return s
end

local function make(s, parent)
	local sound = Instance.new("Sound")
	sound.SoundId = s.id
	sound.Volume = s.volume
	sound.PlaybackSpeed = (s.pitch or 1) * (0.95 + math.random() * 0.1)
	sound.SoundGroup = sfxGroup
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 8)
	return sound
end

-- on your screen only, not in the world
local function play(name, minGap)
	local s = ready(name, minGap)
	if s then
		make(s, SoundService)
	end
end

-- in the world: at a part, or at a position
local function playAt(name, where, minGap)
	local s = ready(name, minGap)
	if not s or not where then
		return
	end
	local parent = where
	if typeof(where) == "Vector3" then
		parent = Instance.new("Attachment")
		parent.WorldPosition = where
		parent.Parent = workspace.Terrain
		Debris:AddItem(parent, 8)
	end
	local sound = make(s, parent)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 12
	sound.RollOffMaxDistance = 160
end

---------------------------------------------------------------------------
-- Weapons, hits, transform, rift, health
---------------------------------------------------------------------------
player:GetAttributeChangedSignal("ShotCount"):Connect(function()
	local weapon = player:GetAttribute("Weapon")
	if weapon == "baton" then
		play("baton", 0.1)
	elseif weapon == "scatter" or weapon == "lance" then
		play("shotHeavy", 0.08)
	else
		play("shot", 0.05)
	end
end)

player:GetAttributeChangedSignal("Reloading"):Connect(function()
	if player:GetAttribute("Reloading") then
		play("reload")
	end
end)
player:GetAttributeChangedSignal("Ammo"):Connect(function()
	if player:GetAttribute("Ammo") == 0 and (player:GetAttribute("AmmoSpare") or 0) == 0 then
		play("empty", 1)
	end
end)

remotes:WaitForChild("Hit").OnClientEvent:Connect(function(_, _, killed)
	play(killed and "kill" or "hit", 0.04)
end)

remotes:WaitForChild("Transform").OnClientEvent:Connect(function(char)
	if char == player.Character then
		play("transform")
	elseif typeof(char) == "Instance" then
		playAt("transform", char:FindFirstChild("HumanoidRootPart"))
	end
end)

player:GetAttributeChangedSignal("Dimension"):Connect(function()
	play("rift")
end)

local lastCarry = player:GetAttribute("Carrying") or 0
player:GetAttributeChangedSignal("Carrying"):Connect(function()
	local carry = player:GetAttribute("Carrying") or 0
	if carry > lastCarry then
		play("pickup")
	end
	lastCarry = carry
end)

local lastLevel = player:GetAttribute("Level")
player:GetAttributeChangedSignal("Level"):Connect(function()
	local level = player:GetAttribute("Level")
	if lastLevel and level and level > lastLevel then
		play("fanfare", 1)
	end
	lastLevel = level
end)

local function hookCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then
		return
	end
	local last = hum.Health
	hum.HealthChanged:Connect(function(health)
		if health < last - 1 then
			play("hurt", 0.3)
		end
		last = health
	end)
end
player.CharacterAdded:Connect(hookCharacter)
if player.Character then
	task.spawn(hookCharacter, player.Character)
end

---------------------------------------------------------------------------
-- Messages: the banner text tells what happened (pickups, elevator, rewards, alerts)
---------------------------------------------------------------------------
remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text)
	text = tostring(text)
	if text:find("^FLOOR ") then
		play("elevatorDing")
	elseif text:find("ELEVATOR STUCK") or text:find("NO POWER") or text:find("^LOCKED") then
		play("elevatorStuck", 0.5)
	elseif text:find("FILE FOUND") or text:find("KEYCARD") or text:find("MAGAZINE") or text:find("HAS THE TAPES") then
		play("pickup", 0.2)
	elseif text:find("^ACHIEVEMENT") or text:find("^QUEST DONE") or text:find("^LEVEL ") or text:find("COMPLETE") or text:find("UNLOCKED")
		or text:find("REVIVED") or text:find("THANK YOU") then
		play("fanfare", 1)
	elseif text:find("IS DOWN") or text:find("TOO LATE") or text:find("TOO SLOW") or text:find("OUT OF AMMO") or text:find("NOT ENOUGH")
		or text:find("AWAKENS") or text:find("FALLING") then
		play("alert", 0.5)
	else
		play("notify", 0.4)
	end
end)

remotes:WaitForChild("Reward").OnClientEvent:Connect(function(_, reason)
	if typeof(reason) == "string" and (reason:find("^DAILY") or reason:find("^CODE")) then
		play("fanfare", 1)
	else
		play("scrap", 0.15)
	end
end)

remotes:WaitForChild("Ping").OnClientEvent:Connect(function()
	play("ping", 0.3)
end)

ProximityPromptService.PromptTriggered:Connect(function(_, who)
	if who == player then
		play("prompt")
	end
end)

---------------------------------------------------------------------------
-- The world: hotel doors, enemy shots, boss attacks (parts appearing or changing)
---------------------------------------------------------------------------
local function hookDoor(door)
	door:GetAttributeChangedSignal("Open"):Connect(function()
		playAt(door:GetAttribute("Open") and "doorOpen" or "doorClose", door)
	end)
end

local function onDescendant(d)
	if not d:IsA("BasePart") then
		return
	end
	if d.Name == "HotelDoor" then
		hookDoor(d)
	elseif d.Name == "EchoBolt" then
		playAt("echoShot", d.Position, 0.1)
	elseif d.Name == "BeamWarning" then
		play("beamWarning", 0.3)
	elseif d.Name == "StaticBeam" then
		playAt("beam", Vector3.new(d.Position.X, d.Position.Y - 38, d.Position.Z), 0.1)
	elseif d.Name == "Shockwave" then
		play("bossSlam", 2) -- the ring is many parts: one slam per ring
	end
end
workspace.DescendantAdded:Connect(onDescendant)
task.spawn(function()
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name == "HotelDoor" and d:IsA("BasePart") then
			hookDoor(d)
		end
	end
end)

ReplicatedStorage:GetAttributeChangedSignal("BossOpen"):Connect(function()
	if ReplicatedStorage:GetAttribute("BossOpen") then
		play("bossOpen", 1)
	end
end)

---------------------------------------------------------------------------
-- Menu clicks (every button except the HUD's own action buttons)
---------------------------------------------------------------------------
local playerGui = player:WaitForChild("PlayerGui")
local function hookButton(b)
	if not b:IsA("GuiButton") then
		return
	end
	local screen = b:FindFirstAncestorOfClass("ScreenGui")
	if screen and screen.Name == "Signal85HUD" and b.Name ~= "RefillButton" then
		return
	end
	b.Activated:Connect(function()
		play("click", 0.05)
	end)
end
playerGui.DescendantAdded:Connect(hookButton)
for _, d in ipairs(playerGui:GetDescendants()) do
	hookButton(d)
end

---------------------------------------------------------------------------
-- Where you are: music, ambience, movement and nearby creatures
---------------------------------------------------------------------------
local function inArea(position, centerName, halfName, shiftX)
	local center, half = workspace:GetAttribute(centerName), workspace:GetAttribute(halfName)
	if not center or not half or not position then
		return false
	end
	local rel = position - center
	return math.abs(rel.X + (shiftX or 0)) < half.X + 10 and math.abs(rel.Z) < half.Z + 10 and rel.Y > -400 and rel.Y < half.Y + 50
end

local function place(hrp)
	if player:GetAttribute("MenuActive") or player:GetAttribute("IntroActive") then
		return "Menu"
	end
	if hrp and inArea(hrp.Position, "DeepGridCenter", "DeepGridHalf", 100) then
		return "DeepGrid"
	end
	if hrp then
		local center, half = workspace:GetAttribute("Site2Center"), workspace:GetAttribute("Site2Half")
		if center and half then
			local rel = hrp.Position - center
			if math.abs(rel.X) < half.X + 2 and math.abs(rel.Z) < half.Z + 2 and rel.Y > -3 and rel.Y < half.Y + 3 then
				return "Site2"
			end
		end
	end
	if player:GetAttribute("Dimension") == "Undergrid" then
		return "Undergrid"
	end
	if workspace:GetAttribute("Storm") then
		return "Storm"
	end
	if workspace:GetAttribute("Morning") then
		return "Morning"
	end
	return "Town"
end

local function loop(name, group)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.Looped = true
	sound.SoundGroup = group
	sound.Parent = SoundService
	return sound
end
local music = loop("S85_Music", musicGroup)
music.Volume = 0.6
local ambience = loop("S85_Ambience", sfxGroup)
local engine = loop("S85_Engine", sfxGroup)
engine.SoundId = SOUNDS.engine.id

local currentTrack, currentAmbience = nil, nil
local nextOneShot = 0
local nextGrowl = os.clock() + 4
local nextStep = 0

task.spawn(function()
	while true do
		task.wait(0.1)
		local now = os.clock()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local where = place(hrp)

		-- music: boss fights first, then the place
		local stage = ReplicatedStorage:GetAttribute("Stage")
		local track = where
		if where ~= "Menu" and (stage == "Boss" or stage == "Carrier" or stage == "Van" or stage == "Listener" or stage == "Broadcast") then
			track = "Boss"
		end
		if track ~= currentTrack then
			currentTrack = track
			local id = MUSIC[track] or ""
			if id == "" then
				music:Stop()
			else
				music.SoundId = id
				music.TimePosition = 0
				music:Play()
			end
		end

		-- ambience loop and its one-shots
		if where ~= currentAmbience then
			currentAmbience = where
			local a = AMBIENCE[where]
			if a and a.id ~= "" then
				ambience.SoundId = a.id
				ambience.Volume = a.volume
				ambience.PlaybackSpeed = a.pitch or 1
				ambience:Play()
			else
				ambience:Stop()
			end
			nextOneShot = now + 4
		end
		local a = AMBIENCE[where]
		if a and a.oneShot and now >= nextOneShot then
			nextOneShot = now + a.every[1] + math.random() * (a.every[2] - a.every[1])
			play(a.oneShot)
		end

		-- movement: heavy steps as a robot, an engine as a car (Roblox's own footsteps as a pilot)
		local mode = char and char:GetAttribute("Mode") or "Pilot"
		local speed = hrp and Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude or 0
		local alive = hum ~= nil and hum.Health > 0 and where ~= "Menu"
		local running = hrp and hrp:FindFirstChild("Running")
		if running and running:IsA("Sound") then
			running.Volume = mode == "Pilot" and 0.65 or 0
		end
		if alive and mode == "Vehicle" and SOUNDS.engine.id ~= "" then
			if not engine.IsPlaying then
				engine:Play()
			end
			engine.Volume = SOUNDS.engine.volume * (0.4 + math.clamp(speed / 75, 0, 1) * 0.6)
			engine.PlaybackSpeed = (SOUNDS.engine.pitch or 1) * (0.5 + math.clamp(speed / 75, 0, 1.2))
		elseif engine.IsPlaying then
			engine:Stop()
		end
		if alive and mode == "Robot" and speed > 4 and hum.FloorMaterial ~= Enum.Material.Air and now >= nextStep then
			nextStep = now + 0.36
			play("robotStep")
		end

		-- the nearest creature makes itself heard now and then
		if where ~= "Menu" and hrp and now >= nextGrowl then
			nextGrowl = now + 1
			local folder = workspace:FindFirstChild("Creatures")
			local best, bestDist = nil, 50
			for _, m in ipairs(folder and folder:GetChildren() or {}) do
				local p = m:IsA("Model") and m.PrimaryPart
				if p and (m:GetAttribute("Health") or 1) > 0 then
					local d = (p.Position - hrp.Position).Magnitude
					if d < bestDist then
						best, bestDist = m, d
					end
				end
			end
			if best then
				nextGrowl = now + 5 + math.random() * 5
				playAt((best.Name == "StaticHound" and "houndCrackle") or (best.Name == "Echo" and "echoHum") or "growl", best.PrimaryPart)
			end
		end
	end
end)
