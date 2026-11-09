--[[
	SIGNAL '85  —  Sound and music (client, Phase B)
	Put this LocalScript in StarterPlayer > StarterPlayerScripts.

	Every sound is in the SOUNDS table below. They start with sounds that ship with
	Roblox itself (rbxasset://...), so the game has sound without any uploads.
	To use better ones: find a sound in Studio's Toolbox (Audio), copy its id and
	put "rbxassetid://<id>" in its line. MUSIC is empty: add music ids you are
	allowed to use (Toolbox audio made by Roblox is free to use) and it plays.

	Volume: MENU > SETTINGS > SOUND VOLUME (player attribute SoundVolume, 0-10).
	The sounds react to what the HUD already sees: your shots, hits, transform,
	the rift, Scrap, banners, prompts, level ups, getting hurt.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Signal85Remotes")

-- id, volume (0-1), pitch (1 = normal). Same id with another pitch = a different-feeling sound.
local SOUNDS = {
	shot = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.35, pitch = 1.6 },
	shotHeavy = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitch = 0.8 }, -- Scatter, Lance
	baton = { id = "rbxasset://sounds/swoosh.wav", volume = 0.6, pitch = 1.4 },
	reload = { id = "rbxasset://sounds/clickfast.wav", volume = 0.6, pitch = 0.9 },
	empty = { id = "rbxasset://sounds/clickfast.wav", volume = 0.5, pitch = 1.6 },
	hit = { id = "rbxasset://sounds/collide.wav", volume = 0.35, pitch = 1.8 },
	kill = { id = "rbxasset://sounds/collide.wav", volume = 0.6, pitch = 0.7 },
	transform = { id = "rbxasset://sounds/swoosh.wav", volume = 0.7, pitch = 0.8 },
	rift = { id = "rbxasset://sounds/swoosh.wav", volume = 0.9, pitch = 0.5 },
	scrap = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.3, pitch = 2.2 },
	notify = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.25, pitch = 1 },
	prompt = { id = "rbxasset://sounds/clickfast.wav", volume = 0.5, pitch = 1.1 },
	levelUp = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitch = 1.3 },
	hurt = { id = "rbxasset://sounds/collide.wav", volume = 0.5, pitch = 0.5 },
	ping = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45, pitch = 0.9 },
	splash = { id = "rbxasset://sounds/impact_water.mp3", volume = 0.5, pitch = 1 },
}

-- background music per place / moment: put ids here, e.g. "rbxassetid://1234567890". Empty = silence.
local MUSIC = {
	Town = "",
	Undergrid = "",
	Boss = "",        -- Mind Warden, Carrier, WHCK van, the Listener
	Storm = "",       -- Chapter 5
	DeepGrid = "",    -- Chapter 6
	Morning = "",     -- the end of Season 1
	Menu = "",
}

---------------------------------------------------------------------------
-- Groups and volume
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

-- a pool of ready-made 2D sounds
local pool = {}
for name, s in pairs(SOUNDS) do
	if s.id ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = "S85_" .. name
		sound.SoundId = s.id
		sound.Volume = s.volume
		sound.PlaybackSpeed = s.pitch or 1
		sound.SoundGroup = sfxGroup
		sound.Parent = SoundService
		pool[name] = sound
	end
end

local lastPlayed = {}
local function play(name, minGap)
	local sound = pool[name]
	if not sound then
		return
	end
	local now = os.clock()
	if minGap and lastPlayed[name] and now - lastPlayed[name] < minGap then
		return
	end
	lastPlayed[name] = now
	local copy = sound:Clone() -- clones so quick repeats overlap instead of cutting off
	copy.PlaybackSpeed = (SOUNDS[name].pitch or 1) * (0.95 + math.random() * 0.1)
	copy.Parent = SoundService
	copy:Play()
	copy.Ended:Connect(function()
		copy:Destroy()
	end)
	task.delay(5, function()
		if copy.Parent then
			copy:Destroy()
		end
	end)
end

-- a sound in the world (other players' transforms...)
local function playAt(name, part)
	local s = SOUNDS[name]
	if not s or s.id == "" or not part then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = s.id
	sound.Volume = s.volume
	sound.PlaybackSpeed = s.pitch or 1
	sound.SoundGroup = sfxGroup
	sound.RollOffMaxDistance = 150
	sound.Parent = part
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------------
-- your own shots (Signal85Client counts them in ShotCount)
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

remotes:WaitForChild("Transform").OnClientEvent:Connect(function(char, _)
	if char == player.Character then
		play("transform")
	elseif typeof(char) == "Instance" then
		playAt("transform", char:FindFirstChild("HumanoidRootPart"))
	end
end)

player:GetAttributeChangedSignal("Dimension"):Connect(function()
	play("rift")
end)

remotes:WaitForChild("Reward").OnClientEvent:Connect(function()
	play("scrap", 0.15)
end)

remotes:WaitForChild("Notify").OnClientEvent:Connect(function()
	play("notify", 0.4)
end)

remotes:WaitForChild("Ping").OnClientEvent:Connect(function()
	play("ping", 0.3)
end)

ProximityPromptService.PromptTriggered:Connect(function(_, who)
	if who == player then
		play("prompt")
	end
end)

local lastLevel = player:GetAttribute("Level")
player:GetAttributeChangedSignal("Level"):Connect(function()
	local level = player:GetAttribute("Level")
	if lastLevel and level and level > lastLevel then
		play("levelUp")
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
-- Music: follows where you are and what is happening
---------------------------------------------------------------------------
local music = Instance.new("Sound")
music.Name = "S85_Music"
music.Looped = true
music.Volume = 0.6
music.SoundGroup = musicGroup
music.Parent = SoundService
local currentTrack = nil

local function inArea(position, centerName, halfName, shiftX)
	local center, half = workspace:GetAttribute(centerName), workspace:GetAttribute(halfName)
	if not center or not half or not position then
		return false
	end
	local rel = position - center
	return math.abs(rel.X + (shiftX or 0)) < half.X + 10 and math.abs(rel.Z) < half.Z + 10 and rel.Y > -400 and rel.Y < half.Y + 50
end

local function track()
	if player:GetAttribute("MenuActive") or player:GetAttribute("IntroActive") then
		return "Menu"
	end
	local stage = ReplicatedStorage:GetAttribute("Stage")
	if stage == "Boss" or stage == "Carrier" or stage == "Van" or stage == "Listener" or stage == "Broadcast" then
		return "Boss"
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp and inArea(hrp.Position, "DeepGridCenter", "DeepGridHalf", 100) then
		return "DeepGrid"
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

RunService.Heartbeat:Connect(function()
	local name = track()
	if name == currentTrack then
		return
	end
	currentTrack = name
	local id = MUSIC[name] or ""
	if id == "" then
		music:Stop()
		return
	end
	music.SoundId = id
	music.TimePosition = 0
	music:Play()
end)
