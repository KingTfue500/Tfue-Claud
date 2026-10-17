--!strict
-- AudioController (Abschnitt 11): Schritte je Untergrund (4 Varianten, Tonhöhe ±8 %), Biometrie
-- (Herzschlag nach BPM, Zähneklappern, zittriges Atmen, Keuchen, Luftschnappen; nur eigener Spieler),
-- Wesen (Infraschall-Brummen mit Equalizer, schwere Schritte), Umgebung, Musik bei Jagd/Extraktion.
-- Pool: max. 30 gleichzeitig spielende 3D-Sounds; der älteste wird zuerst gestoppt.
-- Leere Sound-IDs in Config.Sounds (Platzhalter) werden stumm übersprungen.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ObjectPool = require(ReplicatedStorage.Shared.ObjectPool)
local Surface = require(ReplicatedStorage.Shared.Surface)
local Util = require(ReplicatedStorage.Shared.Util)
local Settings = require(script.Parent.Parent.Lib.Settings)
local ZoneController = require(script.Parent.ZoneController)

local AudioController = {}
AudioController.Name = "AudioController"

local player = Players.LocalPlayer
local SV = Config.SoundVolume

type Slot = { Part: BasePart, Sound: Sound, Started: number }
local pool: ObjectPool.Pool<Slot>
local poolFolder: Folder

local loops: { [string]: Sound } = {}
local stepState: { [Model]: { Dist: number, Last: Vector3? } } = {}
local creatureStep = { Dist = 0, Last = nil :: Vector3? }
local lastGasp = 0
local lastPant = false

local function group(name: string): SoundGroup?
	local g = SoundService:FindFirstChild(name)
	if g and g:IsA("SoundGroup") then
		return g
	end
	return nil
end

-- Sound-ID aus Config (String oder Liste mit Varianten)
local function resolve(key: string): string
	local v = Config.Sounds[key]
	if type(v) == "string" then
		return v
	elseif type(v) == "table" and #v > 0 then
		local s = v[math.random(1, #v)]
		return if type(s) == "string" then s else ""
	end
	return ""
end

local function makeSlot(): Slot
	local p = Instance.new("Part")
	p.Name = "SoundSource"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Parent = poolFolder
	local s = Instance.new("Sound")
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.Parent = p
	local slot: Slot = { Part = p, Sound = s, Started = 0 }
	s.Ended:Connect(function()
		pool:Release(slot)
	end)
	return slot
end

local function resetSlot(slot: Slot)
	slot.Sound:Stop()
	slot.Sound.SoundId = ""
end

function AudioController.Play3D(key: string, position: Vector3, volume: number?, pitch: number?, rollOff: number?, groupName: string?)
	local id = resolve(key)
	if id == "" then
		return
	end
	local cam = Workspace.CurrentCamera
	local maxD = rollOff or SV.DefaultRollOff
	if cam and (cam.CFrame.Position - position).Magnitude > maxD * 1.2 then
		return
	end
	local slot = pool:Get()
	if slot == nil then
		return
	end
	slot.Part.Position = position
	local s = slot.Sound
	s.SoundId = id
	s.Volume = (volume or SV.Default)
	s.PlaybackSpeed = (pitch or 1)
	s.RollOffMaxDistance = maxD
	s.RollOffMinDistance = 6
	s.SoundGroup = group(groupName or "Effects")
	slot.Started = os.clock()
	s:Play()
end

function AudioController.Play2D(key: string, volume: number?, pitch: number?, groupName: string?)
	local id = resolve(key)
	if id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or SV.Default
	s.PlaybackSpeed = pitch or 1
	s.SoundGroup = group(groupName or "Interface")
	s.Parent = SoundService
	s.Ended:Connect(function()
		s:Destroy()
	end)
	s:Play()
	task.delay(30, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- Endlos-Schleife (2D), Lautstärke/Tempo pro Frame steuerbar
local function loop(key: string, groupName: string, parent: Instance?): Sound?
	local existing = loops[key]
	if existing then
		return existing
	end
	local id = resolve(key)
	if id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "Loop_" .. key
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = group(groupName)
	s.Parent = parent or SoundService
	s:Play()
	loops[key] = s
	return s
end

----------------------------------------------------------------------
-- Schritte
----------------------------------------------------------------------
local STEP_KEYS: { [string]: string } = {
	Grate = "StepGrate",
	Snow = "StepSnow",
	Concrete = "StepConcrete",
	Ice = "StepIce",
	Metal = "StepMetal",
}

local function stepSound(surface: string): string
	local key = STEP_KEYS[surface] or "StepConcrete"
	local v = Config.Sounds[key]
	if type(v) == "table" and #v > 0 then
		return key
	end
	return "StepFallback"
end

local function footstepsFor(char: Model, owner: Player?, dt: number)
	local root = char:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local st = stepState[char]
	if st == nil then
		st = { Dist = 0, Last = nil }
		stepState[char] = st
	end
	local pos = root.Position
	local last = st.Last
	st.Last = pos
	if last == nil then
		return
	end
	local d = Vector3.new(pos.X - last.X, 0, pos.Z - last.Z).Magnitude
	if d > 6 then
		return -- Teleport
	end
	st.Dist += d
	local stance = if owner then Util.StrAttr(owner, "Stance", "Stand") else "Stand"
	local sprint = owner ~= nil and owner:GetAttribute("Sprinting") == true
	if stance == "Prone" or stance == "Downed" then
		st.Dist = 0
		return
	end
	local stride = if sprint then 5.5 elseif stance == "Crouch" then 3.2 else 4.5
	if st.Dist >= stride then
		st.Dist = 0
		local surface = Surface.Below(pos, { char })
		local vol = SV.Footstep * (if sprint then 1.6 elseif stance == "Crouch" then 0.45 else 1)
		if surface == "Grate" then
			vol *= 1.5
		elseif surface == "Snow" then
			vol *= 0.6
		end
		local pitch = 1 + (math.random() * 2 - 1) * SV.PitchJitter
		AudioController.Play3D(stepSound(surface), pos - Vector3.new(0, 2.5, 0), vol, pitch, SV.FootstepRollOff, "Effects")
	end
end

local function creatureFootsteps(creature: Model)
	local root = creature.PrimaryPart
	if root == nil or creature:GetAttribute("InVent") == true then
		creatureStep.Last = nil
		return
	end
	local pos = root.Position
	local last = creatureStep.Last
	creatureStep.Last = pos
	if last == nil then
		return
	end
	local d = Vector3.new(pos.X - last.X, 0, pos.Z - last.Z).Magnitude
	if d > 8 then
		return
	end
	creatureStep.Dist += d
	if creatureStep.Dist >= Config.Entity.FootprintSpacing then
		creatureStep.Dist = 0
		local key = if resolve("EntityStep") ~= "" then "EntityStep" else "StepFallback"
		AudioController.Play3D(key, pos - Vector3.new(0, 5, 0), 1.2, 0.55 + math.random() * 0.1, 140, "Creature")
	end
end

----------------------------------------------------------------------
-- Pro Frame
----------------------------------------------------------------------
local function setVolume(s: Sound?, target: number, dt: number)
	if s then
		s.Volume += (target - s.Volume) * math.min(1, dt * 3)
	end
end

local function update(dt: number)
	local cam = Workspace.CurrentCamera
	if cam == nil then
		return
	end
	local camPos = cam.CFrame.Position
	-- Schritte aller Charaktere in der Nähe
	for _, p in Players:GetPlayers() do
		local char = p.Character
		if char and char.PrimaryPart and (char.PrimaryPart.Position - camPos).Magnitude < Config.Effects.ActiveRange then
			footstepsFor(char, p, dt)
		end
	end
	for char in stepState do
		if char.Parent == nil then
			stepState[char] = nil
		end
	end

	-- Wesen
	local creature: Model? = nil
	for _, c in CollectionService:GetTagged("Creature") do
		if c:IsA("Model") then
			creature = c
		end
	end
	local infraVol = 0
	local hunted = false
	if creature and creature.PrimaryPart and creature:GetAttribute("AIState") ~= "Sleeping" and creature:GetAttribute("InVent") ~= true then
		creatureFootsteps(creature)
		local d = (creature.PrimaryPart.Position - camPos).Magnitude
		if d < Config.Entity.InfrasoundRange then
			infraVol = (1 - d / Config.Entity.InfrasoundRange) * 1.6
		end
		local ai = creature:GetAttribute("AIState")
		hunted = (ai == "Hunt" or ai == "Frenzy") and creature:GetAttribute("TargetUserId") == player.UserId
	end
	local infra = loop("Infrasound", "Creature")
	setVolume(infra, infraVol, dt)

	-- Biometrie (nur eigener Spieler)
	local st = Util.GetState(player)
	local alive = st == "Alive" or st == "Downed"
	local bpm = Util.NumAttr(player, "BPM", 70)
	local heart = loop("Heartbeat", "Biometrics")
	if heart then
		heart.PlaybackSpeed = 1 + (bpm - Config.Heart.SoundBaseBpm) / 100 * Config.Heart.SoundFactor
		setVolume(heart, if alive then SV.Heartbeat * math.clamp((bpm - 60) / 80, 0.15, 1) else 0, dt)
	end
	local stage = Util.StrAttr(player, "HypoStage", "Normal")
	local cold = stage == "Mild" or stage == "Moderate" or stage == "Severe"
	setVolume(loop("TeethChatter", "Biometrics"), if alive and cold then 0.5 else 0, dt)
	setVolume(loop("ShiverBreath", "Biometrics"), if alive and (stage == "Moderate" or stage == "Severe") then 0.6 else 0, dt)
	local panting = player:GetAttribute("Panting") == true
	if panting and not lastPant then
		AudioController.Play2D("Pant", 0.9, 1, "Biometrics")
	end
	lastPant = panting
	local gasp = Util.NumAttr(player, "GaspAt", 0)
	if gasp ~= lastGasp then
		if lastGasp ~= 0 then
			AudioController.Play2D("Gasp", 1, 1, "Biometrics")
		end
		lastGasp = gasp
	end

	-- Umgebung: Wind je Zone
	local zone = ZoneController.GetZone()
	local windTarget = if zone == "Helipad" then 1.2 elseif zone == "Lobby" then 0.15 elseif zone == "Zone3" then 0.35 else 0.2
	setVolume(loop("Wind", "Ambience"), windTarget, dt)
	-- Musik: dumpfe Schläge bei der Jagd, Drone bei der Extraktion
	local map = Workspace:FindFirstChild("Map")
	local phase = if map then map:GetAttribute("Phase") else nil
	setVolume(loop("HuntPulse", "Music"), if hunted then SV.Music else 0, dt)
	setVolume(loop("ExtractionDrone", "Music"), if phase == "Extraction" then SV.Music else 0, dt)
end

local function applyGroupVolumes()
	for _, name in { "Effects", "Ambience", "Creature", "Biometrics", "Interface" } do
		local g = group(name)
		if g then
			g.Volume = Settings.EffectsVolume
		end
	end
	local m = group("Music")
	if m then
		m.Volume = Settings.MusicVolume
	end
end

function AudioController.Init()
	poolFolder = Instance.new("Folder")
	poolFolder.Name = "SoundPool"
	poolFolder.Parent = Workspace.CurrentCamera or Workspace
	pool = ObjectPool.new(Config.Performance.MaxSounds3D, makeSlot, resetSlot, true)
	-- Infraschall: Höhen weg (EqualizerSoundEffect)
	local infra = loop("Infrasound", "Creature")
	if infra then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.HighGain = -60
		eq.MidGain = -25
		eq.LowGain = 6
		eq.Parent = infra
	end
end

function AudioController.Start()
	applyGroupVolumes()
	Settings.OnChanged(function()
		applyGroupVolumes()
	end)
	Net.Event("Sound3D").OnClientEvent:Connect(function(key: unknown, position: unknown, volume: unknown, pitch: unknown, rollOff: unknown)
		if type(key) == "string" and typeof(position) == "Vector3" then
			AudioController.Play3D(
				key,
				position,
				if type(volume) == "number" then volume else nil,
				if type(pitch) == "number" then pitch else nil,
				if type(rollOff) == "number" then rollOff else nil,
				"Effects"
			)
		end
	end)
	-- Tropfgeräusche an den Tropfstellen
	task.spawn(function()
		while true do
			task.wait(Config.Puzzle.DripNoiseInterval)
			local cam = Workspace.CurrentCamera
			if cam then
				for _, drip in CollectionService:GetTagged("DripZone") do
					if drip:IsA("BasePart") and (drip.Position - cam.CFrame.Position).Magnitude < 40 then
						AudioController.Play3D("Drip", drip.Position, 0.35, 0.9 + math.random() * 0.3, 40, "Ambience")
					end
				end
				-- Knacken des Eises, zufällig
				if math.random() < 0.08 then
					AudioController.Play3D("IceCrack", cam.CFrame.Position + Vector3.new(math.random(-30, 30), 4, math.random(-30, 30)), 0.6, 0.8 + math.random() * 0.4, 80, "Ambience")
				end
			end
		end
	end)
	RunService.Heartbeat:Connect(update)
end

return AudioController
