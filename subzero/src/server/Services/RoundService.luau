--!strict
-- RoundService: Lobby, Countdown, Zonen-Fortschritt, Stromausfall, Extraktion, Sieg/Niederlage
-- (Abschnitt 8). Max. 6 Spieler pro Server, max. 4 pro Runde; wer nicht in der Schleuse steht,
-- wartet in der Lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(ReplicatedStorage.Shared.Util)
local Zones = require(ReplicatedStorage.Shared.Zones)
local DataService = require(script.Parent.DataService)
local EntityService = require(script.Parent.EntityService)
local HealthService = require(script.Parent.HealthService)
local InventoryService = require(script.Parent.InventoryService)
local MapService = require(script.Parent.MapService)
local MovementService = require(script.Parent.MovementService)
local NoiseService = require(script.Parent.NoiseService)
local PuzzleService = require(script.Parent.PuzzleService)
local StatsService = require(script.Parent.StatsService)
local TemperatureService = require(script.Parent.TemperatureService)

local RoundService = {}
RoundService.Name = "RoundService"

local R = Config.Round

type LeverStage = "Glass" | "Lever" | "Countdown" | "Locked"

local phase = "Lobby"
local participants: { Player } = {}
local roundActive = false
local outageAt = 0
local outageDone = false
local countdownEnd = 0
local leverStage: LeverStage = "Glass"
local leverPrompt: ProximityPrompt? = nil
local heliDepartAt = 0
local heliDeparted = false
local entityFollowed = false
local ending = false

local stateEvent: RemoteEvent
local cinematicEvent: RemoteEvent

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function setPhase(p: string)
	phase = p
	MapService.GetMap():SetAttribute("Phase", p)
end

local function sendState(players: { Player }, state: string, data: any?)
	for _, p in players do
		if p.Parent then
			stateEvent:FireClient(p, state, data)
		end
	end
end

local function isParticipant(p: Player): boolean
	return table.find(participants, p) ~= nil
end

local function spawnMarkers(zone: string): { BasePart }
	local out: { BasePart } = {}
	for _, s in MapService.GetTaggedParts("Spawn") do
		if s:GetAttribute("Zone") == zone then
			table.insert(out, s)
		end
	end
	return out
end

----------------------------------------------------------------------
-- Lobby: Charaktere, Hebel, Schleuse, Terminal, Übungs-Ecke
----------------------------------------------------------------------
local function placeInLobby(player: Player)
	local spawns = spawnMarkers("Lobby")
	if #spawns > 0 then
		local s = spawns[math.random(1, #spawns)]
		MovementService.Teleport(player, s.CFrame)
	end
end

local function loadIntoLobby(player: Player)
	if player.Parent == nil then
		return
	end
	player:SetAttribute("State", "Lobby")
	TemperatureService.ResetPlayer(player)
	HealthService.ResetPlayer(player)
	InventoryService.ResetPlayer(player)
	MovementService.ResetPlayer(player)
	local ok = pcall(function()
		player:LoadCharacterAsync()
	end)
	if not ok then
		-- Fallback für ältere Clients/Engine-Versionen
		local ok2, err2 = pcall(function()
			(player :: any):LoadCharacter()
		end)
		if not ok2 then
			warn("[RoundService] LoadCharacter failed: " .. tostring(err2))
		end
	end
end

local function lever(): Model?
	return MapService.GetTaggedModels("EmergencyLever")[1]
end

local function airlockDoor(): Model?
	return MapService.GetTaggedModels("AirlockDoor")[1]
end

local function setBeacons(on: boolean)
	for _, dome in MapService.GetTaggedParts("CountdownBeacon") do
		dome:SetAttribute("Spinning", on)
		local spot = dome:FindFirstChildOfClass("SpotLight")
		if spot then
			spot.Enabled = on
			spot.Brightness = if on then 6 else 0
		end
		dome.Material = if on then Enum.Material.Neon else Enum.Material.Glass
	end
end

local function resetLever()
	leverStage = "Glass"
	local lv = lever()
	if lv then
		local glass = MapService.FindPart(lv, "SafetyGlass")
		if glass then
			glass.Transparency = 0.5
			local cf = glass:GetAttribute("ClosedCF")
			if typeof(cf) == "CFrame" then
				glass.CFrame = cf
			end
		end
		local handle = MapService.FindPart(lv, "Lever")
		if handle then
			local up = handle:GetAttribute("UpCF")
			if typeof(up) == "CFrame" then
				handle.CFrame = up
			end
		end
	end
	if leverPrompt then
		leverPrompt.ActionText = "Break Glass"
		leverPrompt.HoldDuration = 0
		leverPrompt.Enabled = not roundActive
	end
	setBeacons(false)
	countdownEnd = 0
	MapService.GetMap():SetAttribute("CountdownEnd", 0)
end

local function playersInAirlock(): { Player }
	local out: { Player } = {}
	local vol = MapService.GetTaggedParts("AirlockVolume")[1]
	if not vol then
		return out
	end
	for _, p in Players:GetPlayers() do
		if Util.GetState(p) == "Lobby" then
			local r = Util.GetRoot(p)
			if r and Zones.IsInsidePart(vol, r.Position) then
				table.insert(out, p)
			end
		end
	end
	return out
end

local startRound: (players: { Player }) -> ()

local function beginCountdown()
	if roundActive or leverStage ~= "Lever" then
		return
	end
	leverStage = "Countdown"
	if leverPrompt then
		leverPrompt.Enabled = false
	end
	local lv = lever()
	if lv then
		local handle = MapService.FindPart(lv, "Lever")
		if handle then
			local down = handle:GetAttribute("DownCF")
			if typeof(down) == "CFrame" then
				TweenService:Create(handle, TweenInfo.new(0.35, Enum.EasingStyle.Back), { CFrame = down }):Play()
			end
		end
	end
	setPhase("Countdown")
	setBeacons(true)
	countdownEnd = now() + R.CountdownTime
	MapService.GetMap():SetAttribute("CountdownEnd", countdownEnd)
	NoiseService.PlaySound("Alarm", MapService.ModelPosition(lv or MapService.GetMap()), 1, 1, 80)
	task.delay(R.CountdownTime, function()
		local group = playersInAirlock()
		table.sort(group, function(a: Player, b: Player): boolean
			return a.UserId < b.UserId
		end)
		while #group > R.MaxPlayersPerRound do
			table.remove(group)
		end
		if #group == 0 then
			setPhase("Lobby")
			resetLever()
			return
		end
		-- Schleuse schließt mit pneumatischem Zischen
		local door = airlockDoor()
		if door then
			MapService.CloseDoor(door, R.AirlockCloseTime)
			NoiseService.PlaySound("Hiss", MapService.ModelPosition(door), 1.2)
			local seal = door.Parent and door.Parent:FindFirstChild("SealFog")
			local hiss = if seal then seal:FindFirstChild("AirlockHiss") else nil
			if hiss and hiss:IsA("ParticleEmitter") then
				hiss:Emit(40)
			end
		end
		task.wait(R.AirlockCloseTime)
		startRound(group)
	end)
end

local function setupLobby()
	local lv = lever()
	if lv then
		local inter = MapService.FindPart(lv, "Interact")
		if inter then
			local prompt = MapService.MakePrompt(inter, { Name = "LeverPrompt", ActionText = "Break Glass", ObjectText = "Emergency Descent", MaxDistance = 7 })
			leverPrompt = prompt
			prompt.Triggered:Connect(function(player: Player)
				if roundActive or Util.GetState(player) ~= "Lobby" then
					return
				end
				if leverStage == "Glass" then
					-- Erst E drücken = Glas zerbricht
					leverStage = "Lever"
					local glass = MapService.FindPart(lv, "SafetyGlass")
					if glass then
						glass.Transparency = 1
						NoiseService.PlaySound("GlassBreak", glass.Position, 1)
					end
					prompt.ActionText = "Pull Lever"
					prompt.HoldDuration = R.LeverHoldTime
				elseif leverStage == "Lever" then
					-- dann E 1,5 s halten = Hebel
					beginCountdown()
				end
			end)
		end
	end
	for _, locker in MapService.GetTaggedModels("LoadoutLocker") do
		local inter = MapService.FindPart(locker, "Interact")
		if inter then
			local prompt = MapService.MakePrompt(inter, { Name = "LoadoutPrompt", ActionText = "Equipment", ObjectText = "Locker", MaxDistance = 7 })
			prompt.Triggered:Connect(function(player: Player)
				if Util.GetState(player) == "Lobby" then
					Net.Event("OpenTerminal"):FireClient(player, "Loadout", {
						Clothing = Util.StrAttr(player, "Clothing", Config.Items.DefaultClothing),
						Item1 = Util.StrAttr(player, "LoadoutItem1", Config.Items.DefaultLoadout[1]),
						Item2 = Util.StrAttr(player, "LoadoutItem2", Config.Items.DefaultLoadout[2]),
					}, false)
				end
			end)
		end
	end
end

local function updateDescentTerminal()
	local term = MapService.GetTaggedModels("DescentTerminal")[1]
	if not term then
		return
	end
	local screen = MapService.FindPart(term, "Screen")
	local gui = if screen then screen:FindFirstChildOfClass("SurfaceGui") else nil
	local bg = if gui then gui:FindFirstChild("Background") else nil
	local label = if bg then bg:FindFirstChild("Text") else nil
	if label == nil or not label:IsA("TextLabel") then
		return
	end
	local inAirlock = playersInAirlock()
	local lines = { "EREBOS DESCENT CONTROL", "--------------------------" }
	for _, p in Players:GetPlayers() do
		local st = Util.GetState(p)
		local status: string
		if st == "Lobby" then
			status = if table.find(inAirlock, p) then "IN AIRLOCK" else "STANDBY"
		elseif st == "Escaped" then
			status = "EVACUATED"
		elseif st == "Dead" then
			status = "NO SIGNAL"
		elseif st == "Missing" then
			status = "MISSING"
		else
			status = "IN STATION"
		end
		table.insert(lines, string.format("%-14s %s", string.sub(string.upper(p.DisplayName), 1, 14), status))
	end
	table.insert(lines, "")
	if roundActive then
		table.insert(lines, "> DESCENT IN PROGRESS")
	elseif countdownEnd > 0 then
		table.insert(lines, string.format("> DESCENT IN %02d S", math.max(0, math.ceil(countdownEnd - now()))))
	elseif leverStage == "Lever" then
		table.insert(lines, "> LEVER UNLOCKED - HOLD TO PULL")
	else
		table.insert(lines, "> READY: " .. #inAirlock .. "/" .. R.MaxPlayersPerRound .. " IN AIRLOCK")
	end
	label.Text = table.concat(lines, "\n")
end

local function updateTrainingDisplay()
	local disp = MapService.GetTaggedParts("TrainingDisplay")[1]
	if not disp then
		return
	end
	local gui = disp:FindFirstChildOfClass("SurfaceGui")
	local bg = if gui then gui:FindFirstChild("Background") else nil
	local label = if bg then bg:FindFirstChild("Text") else nil
	if label == nil or not label:IsA("TextLabel") then
		return
	end
	local best: Player? = nil
	local bestD = Config.HUD.TrainingDisplayRange
	for _, p in Players:GetPlayers() do
		if Util.GetState(p) == "Lobby" then
			local r = Util.GetRoot(p)
			if r then
				local d = (r.Position - disp.Position).Magnitude
				if d < bestD then
					bestD = d
					best = p
				end
			end
		end
	end
	if best then
		label.Text = string.format("SIG %d / RANGE %d", Util.NumAttr(best, "HeatSig", 0), Util.NumAttr(best, "SightRange", 0))
	else
		label.Text = "SIG -- / RANGE --"
	end
end

----------------------------------------------------------------------
-- Runde
----------------------------------------------------------------------
local function powerOutage()
	if outageDone or not roundActive then
		return
	end
	outageDone = true
	local map = MapService.GetMap()
	map:SetAttribute("PowerState", "Flicker")
	task.delay(R.PowerFlickerTime, function()
		if roundActive then
			map:SetAttribute("PowerState", "Off")
			EntityService.Wake()
		end
	end)
end

startRound = function(group: { Player })
	roundActive = true
	ending = false
	participants = table.clone(group)
	outageDone = false
	heliDepartAt = 0
	heliDeparted = false
	entityFollowed = false
	setPhase("Transition")
	leverStage = "Locked"
	if leverPrompt then
		leverPrompt.Enabled = false
	end
	sendState(participants, "Transition", nil)
	-- Station vorbereiten
	PuzzleService.Reset()
	EntityService.Reset()
	EntityService.SetPlayerCount(#participants)
	HealthService.ClearCorpses()
	local map = MapService.GetMap()
	map:SetAttribute("PowerState", "On")
	map:SetAttribute("HeliDepartAt", 0)
	task.wait(R.TransitionBlackTime)
	StatsService.StartRound(participants)
	local spawns = spawnMarkers("Zone1")
	for i, p in participants do
		if p.Parent then
			p:SetAttribute("State", "Alive")
			HealthService.ResetPlayer(p)
			TemperatureService.ResetPlayer(p)
			MovementService.ResetPlayer(p)
			InventoryService.ApplyLoadout(p)
			local s = spawns[((i - 1) % math.max(1, #spawns)) + 1]
			if s then
				pcall(function()
					p:RequestStreamAroundAsync(s.Position, 5)
				end)
				MovementService.Teleport(p, s.CFrame)
			end
		end
	end
	outageAt = now() + R.PowerOutageTime
	setPhase("Zone1")
	sendState(participants, "Zone1", nil)
	-- Lobby-Schleuse wieder öffnen (für die Wartenden)
	task.delay(3, function()
		local door = airlockDoor()
		if door then
			MapService.OpenDoor(door, 1)
		end
		setBeacons(false)
		countdownEnd = 0
		map:SetAttribute("CountdownEnd", 0)
	end)
end

local function finishPlayer(p: Player)
	StatsService.Finish(p, false)
	DataService.Add(p, "MinutesSurvived", StatsService.SurvivalTime(p) / 60)
end

local function returnToLobby()
	local list = table.clone(participants)
	participants = {}
	roundActive = false
	ending = false
	EntityService.Reset()
	HealthService.ClearCorpses()
	-- Station zurücksetzen (bricht laufende Abläufe der alten Runde ab)
	PuzzleService.Reset()
	local map = MapService.GetMap()
	map:SetAttribute("PowerState", "On")
	map:SetAttribute("HeliDepartAt", 0)
	setPhase("Lobby")
	resetLever()
	local door = airlockDoor()
	if door then
		MapService.OpenDoor(door, 1)
	end
	for _, p in list do
		if p.Parent then
			loadIntoLobby(p)
			sendState({ p }, "Lobby", nil)
		end
	end
end

local function endRound(victory: boolean)
	if ending then
		return
	end
	ending = true
	for _, p in participants do
		local st = Util.GetState(p)
		if st == "Alive" or st == "Downed" or st == "Grabbed" then
			p:SetAttribute("State", "Missing")
			finishPlayer(p)
		end
	end
	local summary = StatsService.Summary()
	setPhase(if victory then "Victory" else "Defeat")
	sendState(participants, if victory then "Victory" else "Defeat", summary)
	EntityService.Reset()
	task.delay(if victory then R.VictoryScreenTime else R.DefeatScreenTime, returnToLobby)
end

local function departHelicopter()
	if heliDeparted then
		return
	end
	heliDeparted = true
	PuzzleService.SetHeliBoarding(false)
	local heli = MapService.GetTaggedModels("Helicopter")[1]
	if heli then
		heli:SetAttribute("Departing", true)
		NoiseService.PlaySound("Helicopter", MapService.ModelPosition(heli), 2, 1, 300)
	end
	local escaped = Util.PlayersInState({ "Escaped" })
	local any = false
	for _, p in escaped do
		if isParticipant(p) then
			any = true
		end
	end
	endRound(any)
end

local function onBoarded(player: Player)
	if not roundActive or Util.GetState(player) ~= "Alive" or heliDeparted then
		return
	end
	player:SetAttribute("State", "Escaped")
	StatsService.Finish(player, true)
	DataService.Add(player, "Evacuations", 1)
	DataService.Add(player, "MinutesSurvived", StatsService.SurvivalTime(player) / 60)
	InventoryService.TakeAll(player)
	local heli = MapService.GetTaggedModels("Helicopter")[1]
	local seat = if heli then MapService.FindPart(heli, "SeatPoint") else nil
	local root = Util.GetRoot(player)
	if seat and root then
		MovementService.Teleport(player, seat.CFrame)
		root.Anchored = true
	end
	sendState({ player }, "Escaped", nil)
end

local function missingAfterLift()
	-- Nach der letzten Fahrt: wer nicht in Zone 4 ist, gilt als vermisst
	for _, p in participants do
		local st = Util.GetState(p)
		if (st == "Alive" or st == "Downed") and Util.StrAttr(p, "Zone", "None") ~= "Zone4" then
			p:SetAttribute("State", "Missing")
			finishPlayer(p)
			local char = Util.GetCharacter(p)
			if char then
				p.Character = nil
				char:Destroy()
			end
			sendState({ p }, "Missing", nil)
		end
	end
end

local function checkEnd()
	if not roundActive or ending then
		return
	end
	-- Spieler, die das Spiel verlassen haben, entfernen
	for i = #participants, 1, -1 do
		if participants[i].Parent == nil then
			table.remove(participants, i)
		end
	end
	local living, escaped = 0, 0
	for _, p in participants do
		local st = Util.GetState(p)
		if st == "Alive" or st == "Downed" or st == "Grabbed" then
			living += 1
		elseif st == "Escaped" then
			escaped += 1
		end
	end
	if living == 0 then
		if escaped > 0 then
			departHelicopter()
		else
			endRound(false)
		end
	end
end

local function roundTick()
	local t = now()
	if not roundActive or ending then
		return
	end
	-- Stromausfall bei Minute 4
	if not outageDone and t >= outageAt then
		powerOutage()
	end
	-- Extraktion: Helikopter wartet 30 s ab dem ersten Spieler auf dem Landeplatz
	if phase == "Extraction" and not heliDeparted then
		if heliDepartAt == 0 then
			for _, p in Util.PlayersInState({ "Alive", "Downed" }) do
				if Util.StrAttr(p, "Zone", "None") == "Helipad" then
					heliDepartAt = t + Config.Puzzle.HelicopterWait
					MapService.GetMap():SetAttribute("HeliDepartAt", heliDepartAt)
					sendState(participants, "Extraction", { DepartAt = heliDepartAt })
					break
				end
			end
		else
			if not entityFollowed and t >= heliDepartAt - Config.Puzzle.HelicopterWait + Config.Puzzle.EntityFollowDelay then
				entityFollowed = true
				EntityService.EnterZone("Helipad", 0)
			end
			if t >= heliDepartAt then
				departHelicopter()
			end
		end
	end
	checkEnd()
end

----------------------------------------------------------------------
function RoundService.GetPhase(): string
	return phase
end

function RoundService.Init()
	stateEvent = Net.Event("RoundStateChanged")
	cinematicEvent = Net.Event("PlayCinematic")
	setupLobby()
end

function RoundService.Start()
	setPhase("Lobby")
	resetLever()
	local door = airlockDoor()
	if door then
		MapService.OpenDoor(door, 0.5)
	end

	PuzzleService.DoorOpened:Connect(function(name: string)
		if name == "Zone1to2" then
			powerOutage()
			setPhase("Zone2")
			sendState(participants, "Zone2", nil)
		elseif name == "Zone2to3" then
			setPhase("Zone3")
			sendState(participants, "Zone3", nil)
		end
	end)
	PuzzleService.GeneratorStarted:Connect(function(_player: Player)
		local gen = MapService.GetTaggedModels("Generator")[1]
		EntityService.StartFrenzy(Config.Entity.GeneratorFrenzyTime, if gen then MapService.ModelPosition(gen) else nil, false)
	end)
	PuzzleService.ElevatorArrived:Connect(function(_riders: { Player }, trip: number)
		if trip == 1 or phase ~= "Zone4" then
			setPhase("Zone4")
			sendState(participants, "Zone4", nil)
			local core = MapService.GetTaggedParts("FrenzyPoint")
			local focus: Vector3? = nil
			for _, fp in core do
				if fp:GetAttribute("Zone") == "Zone4" then
					focus = fp.Position
					break
				end
			end
			-- Das Wesen ist in Zone 4 die ganze Zeit in Raserei
			EntityService.StartFrenzy(nil, focus, true)
			EntityService.EnterZone("Zone4", 4)
		end
	end)
	PuzzleService.ElevatorFinal:Connect(missingAfterLift)
	PuzzleService.RodsCompleted:Connect(function()
		setPhase("Extraction")
		PuzzleService.OpenHatches()
		-- 5-s-Kamerafahrt zu den Dachluken
		local startCF: CFrame? = nil
		local endCF: CFrame? = nil
		for _, cam in MapService.GetTaggedParts("CinematicCam") do
			local id = cam:GetAttribute("CamId")
			if id == "HatchStart" then
				startCF = cam.CFrame
			elseif id == "HatchEnd" then
				endCF = cam.CFrame
			end
		end
		for _, p in participants do
			if Util.GetState(p) == "Alive" or Util.GetState(p) == "Downed" then
				cinematicEvent:FireClient(p, "Hatches", { Start = startCF, End = endCF, Duration = Config.Puzzle.HatchCinematicTime })
			end
		end
		sendState(participants, "Extraction", { DepartAt = 0 })
	end)
	PuzzleService.Boarded:Connect(onBoarded)
	HealthService.PlayerDied:Connect(function(player: Player, _cause: string)
		if isParticipant(player) then
			sendState({ player }, "Dead", nil)
		end
		task.defer(checkEnd)
	end)

	local function onPlayer(player: Player)
		if #Players:GetPlayers() > R.MaxPlayersPerServer then
			player:Kick("Server full (max " .. R.MaxPlayersPerServer .. " players)")
			return
		end
		player:SetAttribute("State", "Lobby")
		player.CharacterAdded:Connect(function(_char)
			if Util.GetState(player) == "Lobby" then
				task.defer(placeInLobby, player)
			end
		end)
		loadIntoLobby(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		local idx = table.find(participants, player)
		if idx then
			finishPlayer(player)
			table.remove(participants, idx)
			StatsService.Remove(player)
			task.defer(checkEnd)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(R.LobbyTerminalRefresh)
			Util.Try("RoundService", function()
				roundTick()
				updateDescentTerminal()
				updateTrainingDisplay()
			end)
		end
	end)
end

return RoundService
