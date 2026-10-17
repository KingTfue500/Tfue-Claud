--!strict
-- TemperatureService (5 Hz): Körpertemperatur, Wärmesignatur, Unterkühlungs-Stufen, Herzfrequenz.
--   dT/dt = A_Zone * K_Kleidung * K_Nass + B_Bewegung + Summe W_Quellen      (Abschnitt 3.1)
--   S = min(100, max(0, (T-30)*4) + S_Bewegung + S_Items + S_Quelle) * M_Haltung   (Abschnitt 3.3)
-- Ergebnisse als Attribute am Spieler: BodyTemp, HeatSig, SightRange, HypoStage, BPM, Zone, Wet, InSteam.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Util = require(ReplicatedStorage.Shared.Util)
local Zones = require(ReplicatedStorage.Shared.Zones)
local MapService = require(script.Parent.MapService)
local StatsService = require(script.Parent.StatsService)

local TemperatureService = {}
TemperatureService.Name = "TemperatureService"

-- Spieler erreicht 24 °C
TemperatureService.Collapsed = Signal.new() :: Signal.Signal<Player>

type Source = {
	Id: number,
	Kind: string,
	Position: Vector3,
	Part: BasePart?,
	Active: boolean,
	Owner: Player?,
}

local sources: { [number]: Source } = {}
local nextSourceId = 0
local steamVolumes: { [BasePart]: boolean } = {}
local dripZones: { BasePart } = {}
local dripCooldown: { [Player]: number } = {}
local temps: { [Player]: number } = {}
local bpms: { [Player]: number } = {}

local TRACKED_STATES = { "Lobby", "Alive", "Downed", "Grabbed" }

----------------------------------------------------------------------
-- Wärmequellen
----------------------------------------------------------------------
function TemperatureService.AddSource(kind: string, position: Vector3, part: BasePart?, owner: Player?, active: boolean?): number
	assert(Config.HeatSources[kind], "unknown heat source " .. kind)
	nextSourceId += 1
	sources[nextSourceId] = {
		Id = nextSourceId,
		Kind = kind,
		Position = position,
		Part = part,
		Active = active ~= false,
		Owner = owner,
	}
	return nextSourceId
end

function TemperatureService.SetSourceActive(id: number, active: boolean)
	local s = sources[id]
	if s then
		s.Active = active
	end
end

function TemperatureService.SetSourceKind(id: number, kind: string)
	local s = sources[id]
	if s and Config.HeatSources[kind] then
		s.Kind = kind
	end
end

function TemperatureService.RemoveSource(id: number)
	sources[id] = nil
end

-- Für den Wärmebild-Scanner: aktive Quellen
function TemperatureService.GetActiveSourcePositions(): { Vector3 }
	local out: { Vector3 } = {}
	for _, s in sources do
		if s.Active then
			table.insert(out, if s.Part and s.Part.Parent then s.Part.Position else s.Position)
		end
	end
	return out
end

function TemperatureService.SetSteamActive(volume: BasePart, active: boolean)
	if active then
		steamVolumes[volume] = true
	else
		steamVolumes[volume] = nil
	end
end

function TemperatureService.IsInSteam(pos: Vector3): boolean
	for vol in steamVolumes do
		if Zones.IsInsidePart(vol, pos) then
			return true
		end
	end
	return false
end

----------------------------------------------------------------------
-- Temperatur direkt setzen (Wiederbelebung, Injektor, Rundenstart)
----------------------------------------------------------------------
function TemperatureService.SetTemp(player: Player, t: number)
	local v = math.clamp(t, 0, Config.Temperature.Max)
	temps[player] = v
	player:SetAttribute("BodyTemp", v)
end

function TemperatureService.GetTemp(player: Player): number
	return temps[player] or Config.Temperature.Start
end

function TemperatureService.AddTemp(player: Player, delta: number)
	TemperatureService.SetTemp(player, TemperatureService.GetTemp(player) + delta)
end

function TemperatureService.ResetPlayer(player: Player)
	TemperatureService.SetTemp(player, Config.Temperature.Start)
	bpms[player] = Config.Heart.Base
	player:SetAttribute("BPM", Config.Heart.Base)
	player:SetAttribute("WetUntil", 0)
	player:SetAttribute("Wet", false)
	player:SetAttribute("HeatSig", 0)
	player:SetAttribute("SightRange", 0)
	player:SetAttribute("HypoStage", "Normal")
	player:SetAttribute("InSteam", false)
	player:SetAttribute("NearHeat", false)
end

----------------------------------------------------------------------
-- Berechnung
----------------------------------------------------------------------
local function stageFor(t: number): string
	local H = Config.Hypo
	if t <= Config.Temperature.Collapse then
		return "Collapse"
	elseif t > H.OverheatAbove then
		return "Overheated"
	elseif t >= H.NormalAbove then
		return "Normal"
	elseif t >= H.MildAbove then
		return "Mild"
	elseif t >= H.ModerateAbove then
		return "Moderate"
	end
	return "Severe"
end
TemperatureService.StageFor = stageFor

local function sourcePos(s: Source): Vector3
	if s.Part and s.Part.Parent then
		return s.Part.Position
	end
	return s.Position
end

local function creaturePosition(): (Vector3?, boolean)
	for _, c in CollectionService:GetTagged("Creature") do
		if c:IsA("Model") and c.PrimaryPart and c:IsDescendantOf(Workspace) then
			local state = c:GetAttribute("AIState")
			local awake = state ~= "Sleeping" and c:GetAttribute("InVent") ~= true
			return c.PrimaryPart.Position, awake
		end
	end
	return nil, false
end

local function movementKey(player: Player, root: BasePart): (string, boolean)
	local stance = Util.StrAttr(player, "Stance", "Stand")
	local v = root.AssemblyLinearVelocity
	local moving = Vector3.new(v.X, 0, v.Z).Magnitude > Config.Temperature.MovingThreshold
	if player:GetAttribute("InLocker") == true then
		return "Still", false
	end
	if stance == "Downed" then
		return "Downed", moving
	elseif stance == "Prone" then
		return "Prone", moving
	elseif stance == "Crouch" then
		return "Crouch", moving
	end
	if not moving then
		return "Still", false
	end
	if player:GetAttribute("Sprinting") == true then
		return "Sprint", true
	end
	return "Walk", true
end

local function tickPlayer(player: Player, dt: number, now: number, creaturePos: Vector3?, creatureAwake: boolean)
	local state = Util.GetState(player)
	local root = Util.GetRoot(player)
	if root == nil then
		return
	end
	local pos = root.Position
	local zone = Zones.GetZoneAt(pos)
	player:SetAttribute("Zone", zone)

	local T = temps[player] or Config.Temperature.Start
	local moveKey, _moving = movementKey(player, root)

	-- Tropfwasser: sofort -1 °C und 30 s nass
	for _, drip in dripZones do
		if Zones.IsInsidePart(drip, pos) and now >= (dripCooldown[player] or 0) then
			dripCooldown[player] = now + Config.Temperature.WetRetriggerCooldown
			T -= Config.Temperature.WetHitDamage
			player:SetAttribute("WetUntil", now + Config.Temperature.WetDuration)
			break
		end
	end
	local wet = Util.NumAttr(player, "WetUntil", 0) > now
	player:SetAttribute("Wet", wet)

	-- Dampf
	local inSteam = TemperatureService.IsInSteam(pos)
	player:SetAttribute("InSteam", inSteam)

	-- Wärmequellen
	local W = 0
	local nearSource = false
	for _, s in sources do
		if s.Active then
			local cfg = Config.HeatSources[s.Kind]
			local d = (sourcePos(s) - pos).Magnitude
			if d <= cfg.Radius then
				local f = if cfg.Falloff then math.clamp(1 - d / cfg.Radius, 0, 1) else 1
				W += cfg.Rate * f
				-- die eigene Fackel in der Hand zählt nicht als "an einer Wärmequelle stehen"
				if not (s.Kind == "FlareHand" and s.Owner == player) then
					nearSource = true
				end
			end
		end
	end
	local warmerActive = Util.NumAttr(player, "HandWarmerUntil", 0) > now
	if warmerActive then
		W += Config.Temperature.HandWarmerRate
	end
	player:SetAttribute("NearHeat", nearSource)

	-- Temperatur
	if state ~= "Downed" and state ~= "Grabbed" then
		local A = Config.Temperature.ZoneRate[zone] or Config.Temperature.ZoneRate.None
		local aTerm: number
		if zone == "Lobby" then
			-- Lobby wärmt nur bis 37 °C auf
			aTerm = if T < Config.Temperature.LobbyTarget then math.min(A, (Config.Temperature.LobbyTarget - T) / dt) else 0
		elseif A < 0 then
			local K = 1
			if Util.StrAttr(player, "Clothing", "Parka") == "Parka" then
				K *= Config.Temperature.ParkaLossFactor
			end
			if wet then
				K *= Config.Temperature.WetLossFactor
			end
			aTerm = A * K
		else
			aTerm = A
		end
		local B = Config.Temperature.Movement[moveKey] or 0
		T += (aTerm + B + W) * dt
		T = math.min(T, Config.Temperature.Max)
		if state == "Lobby" then
			T = math.max(T, Config.Temperature.Collapse + 0.5)
		end
	end
	temps[player] = T
	player:SetAttribute("BodyTemp", math.floor(T * 100 + 0.5) / 100)
	local stage = stageFor(T)
	player:SetAttribute("HypoStage", stage)
	if state == "Alive" then
		StatsService.RecordTemp(player, T)
		if T <= Config.Temperature.Collapse then
			TemperatureService.Collapsed:Fire(player)
		end
	end

	-- Wärmesignatur
	local SC = Config.Signature
	local sMove = SC.Movement[moveKey] or 0
	local sItems = 0
	if player:GetAttribute("FlashlightOn") == true then
		sItems += SC.Items.FlashlightOn
	end
	if warmerActive then
		sItems += SC.Items.HandWarmer
	end
	if player:GetAttribute("FlareLit") == true then
		sItems += SC.Items.FlareInHand
	end
	if Util.NumAttr(player, "ScanPingUntil", 0) > now then
		sItems += SC.Items.ScannerPing
	end
	if stage == "Overheated" then
		sItems += SC.Items.Overheated
	end
	if Util.NumAttr(player, "InjectorUntil", 0) > now then
		sItems += SC.Items.Injector
	end
	if player:GetAttribute("Reviving") == true then
		sItems += SC.Items.Revive
	end
	local sSource = if nearSource then SC.SourceBonus else 0
	local stance = Util.StrAttr(player, "Stance", "Stand")
	local M: number
	if player:GetAttribute("InLocker") == true then
		M = SC.Posture.Locker
	elseif state == "Downed" or stance == "Downed" then
		M = SC.Posture.Downed
	elseif stance == "Prone" then
		M = if player:GetAttribute("HoldingBreath") == true then SC.Posture.ProneHolding else SC.Posture.ProneBreathing
	elseif stance == "Crouch" then
		M = SC.Posture.Crouch
	else
		M = SC.Posture.Normal
	end
	if inSteam then
		M *= SC.Posture.Steam
	end
	local S = math.min(SC.Max, math.max(0, (T - SC.TempBase) * SC.TempFactor) + sMove + sItems + sSource) * M
	S = math.clamp(S, 0, SC.Max)
	player:SetAttribute("HeatSig", math.floor(S + 0.5))
	player:SetAttribute("SightRange", math.floor(S * SC.SightPerSig + 0.5))

	-- Herzfrequenz (Abschnitt 4.4)
	local HC = Config.Heart
	local target = HC.Base
	if moveKey == "Sprint" then
		target += HC.Sprint
	end
	if creaturePos and creatureAwake then
		local d = (creaturePos - pos).Magnitude
		if d < HC.EntityRange then
			target += HC.EntityMax * (1 - d / HC.EntityRange)
		end
	end
	if stage == "Moderate" then
		target += HC.HypoModerate
	elseif stage == "Severe" or stage == "Collapse" then
		target += HC.HypoSevere
	end
	local bpm = bpms[player] or HC.Base
	bpm += (target - bpm) * math.min(1, dt / HC.SmoothTime)
	bpm = math.clamp(bpm, HC.Min, HC.Max)
	bpms[player] = bpm
	player:SetAttribute("BPM", math.floor(bpm + 0.5))
end

function TemperatureService.Init()
	for _, p in MapService.GetTaggedParts("DripZone") do
		table.insert(dripZones, p)
	end
	-- Lobby-Ofen: dauerhaft aktive Wärmequelle
	for _, stove in MapService.GetTaggedModels("LobbyStove") do
		local body = MapService.FindPart(stove, "Body")
		if body then
			TemperatureService.AddSource("Stove", body.Position, body, nil, true)
		end
	end
end

function TemperatureService.Start()
	Players.PlayerAdded:Connect(function(player)
		TemperatureService.ResetPlayer(player)
	end)
	for _, player in Players:GetPlayers() do
		TemperatureService.ResetPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		temps[player] = nil
		bpms[player] = nil
		dripCooldown[player] = nil
	end)
	task.spawn(function()
		local interval = 1 / Config.Temperature.TickRate
		local last = os.clock()
		while true do
			task.wait(interval)
			local t = os.clock()
			local dt = math.min(t - last, 0.5)
			last = t
			local now = Workspace:GetServerTimeNow()
			local cpos, awake = creaturePosition()
			for _, player in Util.PlayersInState(TRACKED_STATES) do
				Util.Try("TemperatureService", function()
					tickPlayer(player, dt, now, cpos, awake)
				end)
			end
		end
	end)
end

return TemperatureService
