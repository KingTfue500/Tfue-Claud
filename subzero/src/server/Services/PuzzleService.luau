--!strict
-- PuzzleService: alle Rätsel und Stations-Systeme (Abschnitt 7).
--   Zone 1: Sicherungen (2 aus 8 Verstecken), Sicherungskasten, Haupthebel, Panzertür (8 s, laut),
--           Not-Radiator mit Handkurbel, Notizen.
--   Zone 2: Phiolen (3 aus 6 Kryo-Schränken), Reihenfolge auf dem Whiteboard, Zentrifuge (20 s),
--           Schlüsselkarte, Kartenleser.
--   Zone 3: Diesel, Generator-Minispiel (Nadel im grünen Bereich), Heizstrahler, Lastenaufzug.
--   Zone 4: 4 Kontrollstäbe (Sync- oder Einzelmodus), Dampfventile, Dachluken, Leiterluke.
--   Extraktion: Helikopter-Einstieg.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Notes = require(ReplicatedStorage.Shared.Notes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Util = require(ReplicatedStorage.Shared.Util)
local Zones = require(ReplicatedStorage.Shared.Zones)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local MapService = require(script.Parent.MapService)
local MovementService = require(script.Parent.MovementService)
local NoiseService = require(script.Parent.NoiseService)
local StatsService = require(script.Parent.StatsService)
local TemperatureService = require(script.Parent.TemperatureService)

local PuzzleService = {}
PuzzleService.Name = "PuzzleService"

local P = Config.Puzzle

PuzzleService.DoorOpened = Signal.new() :: Signal.Signal<string>
PuzzleService.GeneratorStarted = Signal.new() :: Signal.Signal<Player>
PuzzleService.ElevatorArrived = Signal.new() :: Signal.Signal<{ Player }, number>
PuzzleService.ElevatorFinal = Signal.new() :: Signal.Signal<>
PuzzleService.RodsCompleted = Signal.new() :: Signal.Signal<>
PuzzleService.Boarded = Signal.new() :: Signal.Signal<Player>

local notify: RemoteEvent
-- Zählt bei jedem Reset hoch: verzögerte Abläufe einer alten Runde brechen dann ab
local generation = 0
local openTerminal: RemoteEvent
local rng = Random.new()

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function alive(player: Player): boolean
	return Util.GetState(player) == "Alive"
end

local function say(player: Player, text: string)
	notify:FireClient(player, text)
end

local function sayAll(text: string)
	for _, p in Util.PlayersInState({ "Alive", "Downed" }) do
		notify:FireClient(p, text)
	end
end

local function setNeon(part: BasePart?, color: Color3)
	if part then
		part.Color = color
	end
end

local function tweenTo(part: BasePart, attr: string, time: number, style: Enum.EasingStyle?)
	local cf = part:GetAttribute(attr)
	if typeof(cf) == "CFrame" then
		TweenService:Create(part, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = cf }):Play()
	end
end

local function snapTo(part: BasePart, attr: string)
	local cf = part:GetAttribute(attr)
	if typeof(cf) == "CFrame" then
		part.CFrame = cf
	end
end

local function nearPart(player: Player, part: BasePart, range: number): boolean
	local root = Util.GetRoot(player)
	return root ~= nil and (root.Position - part.Position).Magnitude <= range
end

local GREEN = Color3.fromRGB(60, 255, 90)
local RED = Color3.fromRGB(255, 40, 30)
local AMBER = Color3.fromRGB(255, 170, 20)

----------------------------------------------------------------------
-- Zustand
----------------------------------------------------------------------
type FuseSpot = { Model: Model, Prompt: ProximityPrompt, HasFuse: boolean, Searched: boolean, Point: BasePart }
local fuseSpots: { FuseSpot } = {}
local fuseBox: Model? = nil
local socketPrompts: { ProximityPrompt } = {}
local socketFilled = { false, false }
local leverPrompt: ProximityPrompt? = nil
local leverPulled = false

local radiator: Model? = nil
local radiatorUntil = 0
local radiatorSource: number? = nil
local radiatorBeacon: number? = nil

type Cabinet = { Model: Model, Prompt: ProximityPrompt, Vial: string?, Opened: boolean }
local cabinets: { Cabinet } = {}
local sequence: { string } = { "VialGreen", "VialRed", "VialBlue" }
local whiteboardLabel: TextLabel? = nil

local centrifuge: Model? = nil
local centSlots: { string } = {}
local centRunning = false
local centRunEnd = 0
local centLockUntil = 0
local centDone = false
local centScreen: TextLabel? = nil

local readerPrompt: ProximityPrompt? = nil
local keycardUsed = false

local generator: Model? = nil
local fuelPrompt: ProximityPrompt? = nil
local startPrompt: ProximityPrompt? = nil
local fueled = false
local generatorOn = false
local genBeacon: number? = nil
local genSound: Sound? = nil
local genT0 = 0
local genCenter = 0.75
local lastGenAttempt: { [Player]: number } = {}
local heaterSources: { number } = {}

type ElevatorState = "Absent" | "Arriving" | "Waiting" | "Riding" | "Returning" | "Gone"
local elevator: Model? = nil
local elevState: ElevatorState = "Absent"
local elevTimer = 0
local elevTrips = 0
local elevScreen: TextLabel? = nil

type Rod = { Model: Model, Prompt: ProximityPrompt, Down: boolean, Index: number }
local rods: { Rod } = {}
local firstRodAt = 0
local rodsDone = false

type Vent = { Model: Model, Emitter: ParticleEmitter?, Volume: BasePart?, Source: number?, Beacon: number?, Offset: number, BurstUntil: number, On: boolean }
local steamVents: { Vent } = {}

local hatchesOpen = false
local heliPrompt: ProximityPrompt? = nil

----------------------------------------------------------------------
-- Welt-Items beim Rundenstart
----------------------------------------------------------------------
local RANDOM_LOOT = { "Battery", "Battery", "Flare", "HandWarmer", "Flare", "Battery" }

local function spawnItems()
	for _, marker in MapService.GetTaggedParts("ItemSpawn") do
		local id = marker:GetAttribute("ItemId")
		if id == "Random" then
			if rng:NextNumber() < 0.8 then
				InventoryService.SpawnWorldItem(RANDOM_LOOT[rng:NextInteger(1, #RANDOM_LOOT)], marker.CFrame * CFrame.Angles(0, rng:NextNumber() * 6, 0))
			end
		elseif type(id) == "string" and Config.ItemInfo[id] then
			InventoryService.SpawnWorldItem(id, marker.CFrame)
		end
	end
end

local function giveOrDrop(player: Player, id: string, at: CFrame)
	if InventoryService.GiveItem(player, { Id = id }) then
		local info = Config.ItemInfo[id]
		say(player, "FOUND: " .. (if info then info.Name else id))
	else
		InventoryService.SpawnWorldItem(id, at)
		say(player, "BELT FULL - ITEM LEFT HERE")
	end
end

----------------------------------------------------------------------
-- Notizen
----------------------------------------------------------------------
local function setupNotes()
	for _, part in MapService.GetTaggedParts("Note") do
		local id = part:GetAttribute("NoteId")
		if type(id) == "string" then
			local note = Notes[id]
			local prompt = MapService.MakePrompt(part, {
				Name = "NotePrompt",
				ActionText = "Read",
				ObjectText = if note then note.Title else "Note",
				MaxDistance = Config.Prompt.NoteMaxDistance,
			})
			prompt.Triggered:Connect(function(player: Player)
				Net.Event("OpenNote"):FireClient(player, id)
				DataService.AddLog(player, id)
			end)
		end
	end
end

----------------------------------------------------------------------
-- Zone 1: Sicherungen, Sicherungskasten, Haupthebel, Radiator
----------------------------------------------------------------------
local function updateFuseBox()
	local box = fuseBox
	if box == nil then
		return
	end
	for i = 1, 2 do
		setNeon(MapService.FindPart(box, "Socket" .. i), if socketFilled[i] then GREEN else Color3.fromRGB(120, 10, 10))
		local vis = MapService.FindPart(box, "Fuse" .. i)
		if vis then
			vis.Transparency = if socketFilled[i] then 0.3 else 1
		end
		local sp = socketPrompts[i]
		if sp then
			sp.Enabled = not socketFilled[i]
		end
	end
	if leverPrompt then
		leverPrompt.Enabled = socketFilled[1] and socketFilled[2] and not leverPulled
	end
end

local function pullMainLever()
	if leverPulled or not (socketFilled[1] and socketFilled[2]) then
		return
	end
	leverPulled = true
	local box = fuseBox :: Model
	local lever = MapService.FindPart(box, "Lever")
	if lever then
		tweenTo(lever, "DownCF", 0.4, Enum.EasingStyle.Back)
	end
	updateFuseBox()
	local door = MapService.GetDoor("Zone1to2")
	if door then
		door:SetAttribute("Locked", false)
		MapService.OpenDoor(door, P.ArmorDoorOpenTime)
		local pos = MapService.ModelPosition(door)
		NoiseService.EmitWithSound(pos, P.ArmorDoorNoise, "ArmorDoor", "ArmorDoor", nil, 2)
	end
	sayAll("MAIN POWER RESTORED - BIO-LAB DOOR OPENING")
	PuzzleService.DoorOpened:Fire("Zone1to2")
end

local function setupZone1()
	for _, model in MapService.GetTaggedModels("FuseSpot") do
		local point = MapService.FindPart(model, "Interact")
		if point then
			local name = model:GetAttribute("SpotName")
			local prompt = MapService.MakePrompt(point, {
				Name = "SearchPrompt",
				ActionText = "Search",
				ObjectText = if type(name) == "string" then name else "",
				HoldDuration = P.SearchHold,
				MaxDistance = 7,
			})
			local spot: FuseSpot = { Model = model, Prompt = prompt, HasFuse = false, Searched = false, Point = point }
			table.insert(fuseSpots, spot)
			prompt.Triggered:Connect(function(player: Player)
				if not alive(player) or spot.Searched then
					return
				end
				spot.Searched = true
				prompt.Enabled = false
				NoiseService.Emit(point.Position, 4, "Search", player)
				if spot.HasFuse then
					giveOrDrop(player, "Fuse", point.CFrame)
				else
					say(player, "NOTHING USEFUL")
				end
			end)
		end
	end
	fuseBox = MapService.GetTaggedModels("FuseBox")[1]
	local box = fuseBox
	if box then
		for i = 1, 2 do
			local inter = MapService.FindPart(box, "SocketInteract" .. i)
			if inter then
				local prompt = MapService.MakePrompt(inter, { Name = "SocketPrompt", ActionText = "Insert Fuse", ObjectText = "Socket " .. i, HoldDuration = P.FuseInsertHold, MaxDistance = 7 })
				socketPrompts[i] = prompt
				prompt.Triggered:Connect(function(player: Player)
					if not alive(player) or socketFilled[i] then
						return
					end
					if InventoryService.TakeItem(player, "Fuse") == nil then
						say(player, "YOU NEED A FUSE")
						return
					end
					socketFilled[i] = true
					NoiseService.PlaySound("UiClick", inter.Position, 1)
					updateFuseBox()
					if socketFilled[1] and socketFilled[2] then
						say(player, "BOTH FUSES IN - PULL THE MAIN LEVER")
					end
				end)
			end
		end
		local li = MapService.FindPart(box, "LeverInteract")
		if li then
			local prompt = MapService.MakePrompt(li, { Name = "LeverPrompt", ActionText = "Pull Main Lever", ObjectText = "Main Power", HoldDuration = P.MainLeverHold, MaxDistance = 7, Enabled = false })
			leverPrompt = prompt
			prompt.Triggered:Connect(function(player: Player)
				if alive(player) then
					pullMainLever()
				end
			end)
		end
	end
	-- Not-Radiator mit Handkurbel
	radiator = MapService.GetTaggedModels("Radiator")[1]
	local rad = radiator
	if rad then
		local inter = MapService.FindPart(rad, "Interact")
		local heat = MapService.FindPart(rad, "HeatCenter")
		if heat then
			radiatorSource = TemperatureService.AddSource("Radiator", heat.Position, heat, nil, false)
			radiatorBeacon = NoiseService.AddBeacon("Radiator", heat.Position, heat, nil)
		end
		if inter then
			local prompt = MapService.MakePrompt(inter, { Name = "CrankPrompt", ActionText = "Crank", ObjectText = "Emergency Radiator", HoldDuration = P.RadiatorCrankHold, MaxDistance = 7 })
			prompt.PromptButtonHoldBegan:Connect(function(player: Player)
				if alive(player) then
					NoiseService.EmitWithSound(inter.Position, P.RadiatorCrankNoise, "Crank", "RadiatorCrank", player)
				end
			end)
			prompt.Triggered:Connect(function(player: Player)
				if not alive(player) then
					return
				end
				radiatorUntil = now() + P.RadiatorRunTime
				NoiseService.Emit(inter.Position, P.RadiatorCrankNoise, "Crank", player)
				say(player, "RADIATOR RUNNING - 90 S")
			end)
		end
	end
end

local function updateRadiator()
	local rad = radiator
	if rad == nil then
		return
	end
	local on = now() < radiatorUntil
	if radiatorSource then
		TemperatureService.SetSourceActive(radiatorSource, on)
	end
	if radiatorBeacon then
		NoiseService.SetBeaconActive(radiatorBeacon, on)
	end
	setNeon(MapService.FindPart(rad, "Coil"), if on then Color3.fromRGB(255, 110, 40) else Color3.fromRGB(60, 30, 20))
	local heat = MapService.FindPart(rad, "HeatCenter")
	local glow = if heat then heat:FindFirstChild("HeatGlow") else nil
	if glow and glow:IsA("PointLight") then
		glow.Brightness = if on then 1.2 else 0
	end
end

----------------------------------------------------------------------
-- Zone 2: Phiolen, Whiteboard, Zentrifuge, Kartenleser
----------------------------------------------------------------------
local VIAL_NAMES: { [string]: string } = { VialBlue = "BLUE", VialGreen = "GREEN", VialRed = "RED" }
local VIAL_HEX: { [string]: string } = { VialBlue = "#2a5bd7", VialGreen = "#178a3a", VialRed = "#c01818" }

local function centState(): { [string]: any }
	return {
		Slots = table.clone(centSlots),
		Running = centRunning,
		RunLeft = math.max(0, centRunEnd - now()),
		LockedFor = math.max(0, centLockUntil - now()),
		Done = centDone,
	}
end

local function updateCentrifuge()
	local c = centrifuge
	if c == nil then
		return
	end
	for i = 1, 3 do
		local slot = MapService.FindPart(c, "Slot" .. i)
		local v = centSlots[i]
		setNeon(slot, if v then Config.ItemInfo[v].Color else Color3.fromRGB(40, 40, 40))
	end
	local status = MapService.FindPart(c, "StatusLight")
	local t = now()
	if centDone then
		setNeon(status, GREEN)
	elseif centRunning then
		setNeon(status, AMBER)
	elseif t < centLockUntil then
		setNeon(status, RED)
	else
		setNeon(status, Color3.fromRGB(40, 120, 40))
	end
	local scr = centScreen
	if scr then
		local lines = { "CENTRIFUGE CF-9", "" }
		for i = 1, 3 do
			local v = centSlots[i]
			table.insert(lines, string.format("SLOT %d: %s", i, if v then VIAL_NAMES[v] else "----"))
		end
		table.insert(lines, "")
		if centDone then
			table.insert(lines, "> SAMPLE KEY RELEASED")
		elseif centRunning then
			table.insert(lines, string.format("> SPINNING... %02d S", math.ceil(centRunEnd - t)))
		elseif t < centLockUntil then
			table.insert(lines, string.format("> SEQUENCE ERROR - LOCKED %02d S", math.ceil(centLockUntil - t)))
		else
			table.insert(lines, "> AWAITING SAMPLES")
		end
		scr.Text = table.concat(lines, "\n")
	end
end

local function refreshCentrifugeTerminals()
	local c = centrifuge
	if c == nil then
		return
	end
	local base = MapService.FindPart(c, "Base")
	for _, p in Players:GetPlayers() do
		if base and alive(p) and nearPart(p, base, P.CentrifugeRange + 4) then
			openTerminal:FireClient(p, "Centrifuge", centState(), true)
		end
	end
end

local function finishCentrifugeLoad(player: Player)
	local c = centrifuge :: Model
	local base = MapService.RequirePart(c, "Base")
	local correct = true
	for i = 1, 3 do
		if centSlots[i] ~= sequence[i] then
			correct = false
		end
	end
	if correct then
		centRunning = true
		centRunEnd = now() + P.CentrifugeRunTime
		sayAll("CENTRIFUGE RUNNING - HOLD OUT 20 SECONDS")
		local gen = generation
		task.spawn(function()
			while centRunning and now() < centRunEnd and gen == generation do
				NoiseService.EmitWithSound(base.Position, P.CentrifugeNoise, "Centrifuge", "CentrifugeHum", nil, 1.2)
				task.wait(P.CentrifugeNoiseInterval)
			end
			if centRunning and gen == generation then
				centRunning = false
				centDone = true
				local kp = MapService.FindPart(c, "KeycardPoint")
				InventoryService.SpawnWorldItem("Keycard", if kp then kp.CFrame else base.CFrame + Vector3.new(0, 3, 0))
				sayAll("SAMPLE KEY RELEASED")
				updateCentrifuge()
				refreshCentrifugeTerminals()
			end
		end)
	else
		-- Falsche Reihenfolge: Alarm, Phiolen werden ausgeworfen, 10 s Sperre
		NoiseService.EmitWithSound(base.Position, P.CentrifugeAlarmNoise, "Alarm", "Alarm", nil, 2)
		local eject = MapService.FindPart(c, "EjectPoint")
		for i, v in centSlots do
			local at = (if eject then eject.CFrame else base.CFrame) * CFrame.new((i - 2) * 1.5, 0, 0)
			InventoryService.SpawnWorldItem(v, at)
		end
		table.clear(centSlots)
		centLockUntil = now() + P.CentrifugeLockout
		say(player, "SEQUENCE ERROR - SAMPLES EJECTED")
	end
	updateCentrifuge()
	refreshCentrifugeTerminals()
end

local function centrifugeInput(player: Player, action: unknown, arg: unknown)
	local c = centrifuge
	if c == nil or not alive(player) or type(action) ~= "string" then
		return
	end
	local base = MapService.FindPart(c, "Base")
	if base == nil or not nearPart(player, base, P.CentrifugeRange + 4) then
		return
	end
	if action == "Insert" then
		if type(arg) ~= "string" or VIAL_NAMES[arg] == nil then
			return
		end
		if centRunning or centDone or now() < centLockUntil or #centSlots >= 3 then
			refreshCentrifugeTerminals()
			return
		end
		if InventoryService.TakeItem(player, arg) == nil then
			return
		end
		table.insert(centSlots, arg)
		NoiseService.PlaySound("UiBeep", base.Position, 0.8)
		if #centSlots >= 3 then
			finishCentrifugeLoad(player)
		else
			updateCentrifuge()
			refreshCentrifugeTerminals()
		end
	end
end

local function setupZone2()
	for _, model in MapService.GetTaggedModels("CryoCabinet") do
		local inter = MapService.FindPart(model, "Interact")
		if inter then
			local prompt = MapService.MakePrompt(inter, { Name = "CabinetPrompt", ActionText = "Search", ObjectText = "Cryo Cabinet", HoldDuration = P.SearchHold, MaxDistance = 7 })
			local cab: Cabinet = { Model = model, Prompt = prompt, Vial = nil, Opened = false }
			table.insert(cabinets, cab)
			prompt.Triggered:Connect(function(player: Player)
				if not alive(player) or cab.Opened then
					return
				end
				cab.Opened = true
				prompt.Enabled = false
				local door = MapService.FindPart(model, "Door")
				if door then
					tweenTo(door, "OpenCF", 0.5)
				end
				NoiseService.Emit(inter.Position, 5, "Cabinet", player)
				local vial = cab.Vial
				if vial then
					local point = MapService.FindPart(model, "ItemPoint")
					giveOrDrop(player, vial, if point then point.CFrame else inter.CFrame)
					cab.Vial = nil
				else
					say(player, "EMPTY")
				end
			end)
		end
	end
	local wb = MapService.GetTaggedModels("Whiteboard")[1]
	if wb then
		local board = MapService.FindPart(wb, "Board")
		local gui = if board then board:FindFirstChild("BoardGui") else nil
		local lbl = if gui then gui:FindFirstChild("Text") else nil
		if lbl and lbl:IsA("TextLabel") then
			whiteboardLabel = lbl
		end
	end
	centrifuge = MapService.GetTaggedModels("Centrifuge")[1]
	local c = centrifuge
	if c then
		local term = c:FindFirstChild("CentrifugeTerminal_PH")
		if term then
			local screen = MapService.FindPart(term, "Screen")
			local gui = if screen then screen:FindFirstChildOfClass("SurfaceGui") else nil
			local bg = if gui then gui:FindFirstChild("Background") else nil
			local lbl = if bg then bg:FindFirstChild("Text") else nil
			if lbl and lbl:IsA("TextLabel") then
				centScreen = lbl
			end
			local inter = MapService.FindPart(term, "Interact")
			if inter then
				local prompt = MapService.MakePrompt(inter, { Name = "TerminalPrompt", ActionText = "Use Terminal", ObjectText = "Centrifuge", MaxDistance = 7 })
				prompt.Triggered:Connect(function(player: Player)
					if alive(player) then
						openTerminal:FireClient(player, "Centrifuge", centState(), false)
					end
				end)
			end
		end
	end
	local reader = MapService.GetTaggedModels("KeycardReader")[1]
	if reader then
		local inter = MapService.FindPart(reader, "Interact")
		if inter then
			local prompt = MapService.MakePrompt(inter, { Name = "ReaderPrompt", ActionText = "Swipe Keycard", ObjectText = "Cargo Bay", HoldDuration = P.KeycardSwipeHold, MaxDistance = 7 })
			readerPrompt = prompt
			prompt.Triggered:Connect(function(player: Player)
				if not alive(player) or keycardUsed then
					return
				end
				if InventoryService.TakeItem(player, "Keycard") == nil then
					say(player, "ACCESS DENIED - KEYCARD REQUIRED")
					NoiseService.PlaySound("UiBeep", inter.Position, 1, 0.6)
					return
				end
				keycardUsed = true
				prompt.Enabled = false
				setNeon(MapService.FindPart(reader, "Led"), GREEN)
				local door = MapService.GetDoor("Zone2to3")
				if door then
					door:SetAttribute("Locked", false)
					MapService.OpenDoor(door, P.KeycardDoorOpenTime)
					NoiseService.EmitWithSound(MapService.ModelPosition(door), P.ArmorDoorNoise * 0.6, "ArmorDoor", "ArmorDoor", nil, 1.5)
				end
				sayAll("CARGO BAY ACCESS GRANTED")
				PuzzleService.DoorOpened:Fire("Zone2to3")
			end)
		end
	end
end

----------------------------------------------------------------------
-- Zone 3: Generator, Heizstrahler, Aufzug
----------------------------------------------------------------------
-- Nadelposition 0..1 (gleiche Formel auf dem Client)
local function needleAt(t: number): number
	return 0.5 + 0.5 * math.sin(2 * math.pi * (t - genT0) / P.GeneratorNeedlePeriod)
end

local function generatorData(): { [string]: any }
	return {
		T0 = genT0,
		Period = P.GeneratorNeedlePeriod,
		Center = genCenter,
		Width = P.GeneratorGreenWidth,
		Fueled = fueled,
		Running = generatorOn,
	}
end

local function setGeneratorVisuals(on: boolean)
	local gen = generator
	if gen == nil then
		return
	end
	setNeon(MapService.FindPart(gen, "StatusLight"), if on then GREEN elseif fueled then AMBER else Color3.fromRGB(120, 20, 20))
	local exhaust = MapService.FindPart(gen, "Exhaust")
	local smoke = if exhaust then exhaust:FindFirstChild("Smoke") else nil
	if smoke and smoke:IsA("ParticleEmitter") then
		smoke.Enabled = on
	end
	for _, heater in MapService.GetTaggedModels("Heater") do
		setNeon(MapService.FindPart(heater, "Grill"), if on then Color3.fromRGB(255, 110, 40) else Color3.fromRGB(50, 20, 10))
		local grill = MapService.FindPart(heater, "Grill")
		local light = if grill then grill:FindFirstChild("HeaterLight") else nil
		if light and light:IsA("PointLight") then
			light.Brightness = if on then 1.6 else 0
		end
	end
	for _, id in heaterSources do
		TemperatureService.SetSourceActive(id, on)
	end
	MapService.GetMap():SetAttribute("GeneratorOn", on)
	if genBeacon then
		NoiseService.SetBeaconActive(genBeacon, on)
	end
	local snd = genSound
	if snd then
		if on and snd.SoundId ~= "" then
			snd:Play()
		else
			snd:Stop()
		end
	end
end

local function setElevatorScreen(text: string)
	local s = elevScreen
	if s then
		s.Text = text
	end
end

local function startGenerator(player: Player)
	if generatorOn then
		return
	end
	generatorOn = true
	if startPrompt then
		startPrompt.Enabled = false
	end
	setGeneratorVisuals(true)
	local gen = generator :: Model
	local pos = MapService.ModelPosition(gen)
	-- 105 dB: Geräusch-Ereignis mit 250 Studs Radius
	NoiseService.Emit(pos, Config.Entity.Beacon.Generator, "Generator", nil)
	StatsService.AddDistraction(player)
	DataService.Add(player, "Distractions", 1)
	sayAll("GENERATOR ONLINE - CARGO LIFT ARRIVING IN 45 S")
	elevState = "Arriving"
	elevTimer = now() + P.ElevatorArrivalTime
	PuzzleService.GeneratorStarted:Fire(player)
end

local function generatorAttempt(player: Player, clickTime: unknown)
	local gen = generator
	if gen == nil or not alive(player) or generatorOn or not fueled then
		return
	end
	local start = MapService.FindPart(gen, "StartInteract")
	if start == nil or not nearPart(player, start, 12) then
		return
	end
	local t = now()
	if t - (lastGenAttempt[player] or 0) < P.GeneratorAttemptCooldown then
		return
	end
	lastGenAttempt[player] = t
	-- Zeitpunkt des Klicks (Server-Zeit des Clients), nur kurz in die Vergangenheit erlaubt
	local ct = if type(clickTime) == "number" then math.clamp(clickTime, t - 0.6, t + 0.05) else t
	local pos = needleAt(ct)
	local half = P.GeneratorGreenWidth / 2 + P.GeneratorTolerance
	if math.abs(pos - genCenter) <= half then
		startGenerator(player)
		openTerminal:FireClient(player, "Generator", generatorData(), true)
	else
		-- Fehlversuch: lautes Stottern
		NoiseService.EmitWithSound(start.Position, P.GeneratorStutterNoise, "GeneratorStutter", "GeneratorStutter", player, 2)
		genT0 = t
		genCenter = 0.62 + rng:NextNumber() * 0.26
		local data = generatorData()
		data.Failed = true
		openTerminal:FireClient(player, "Generator", data, true)
	end
end

local function setupZone3()
	generator = MapService.GetTaggedModels("Generator")[1]
	local gen = generator
	if gen then
		local body = MapService.FindPart(gen, "Body")
		if body then
			genBeacon = NoiseService.AddBeacon("Generator", body.Position, body, nil)
			local snd = Instance.new("Sound")
			snd.Name = "GeneratorRun"
			snd.SoundId = Config.Sounds.GeneratorRun
			snd.Looped = true
			snd.Volume = Config.SoundVolume.Generator
			snd.RollOffMaxDistance = Config.SoundVolume.GeneratorRollOff
			snd.RollOffMode = Enum.RollOffMode.InverseTapered
			snd.Parent = body
			genSound = snd
		end
		local fuel = MapService.FindPart(gen, "FuelInteract")
		if fuel then
			local prompt = MapService.MakePrompt(fuel, { Name = "FuelPrompt", ActionText = "Refuel", ObjectText = "Generator", HoldDuration = P.DieselPourHold, MaxDistance = 8 })
			fuelPrompt = prompt
			prompt.Triggered:Connect(function(player: Player)
				if not alive(player) or fueled then
					return
				end
				if InventoryService.TakeItem(player, "Diesel") == nil then
					say(player, "THE TANK IS EMPTY - FIND DIESEL")
					return
				end
				fueled = true
				prompt.Enabled = false
				if startPrompt then
					startPrompt.Enabled = true
				end
				setGeneratorVisuals(false)
				NoiseService.Emit(fuel.Position, 6, "Pour", player)
				say(player, "TANK FILLED - START THE GENERATOR")
			end)
		end
		local start = MapService.FindPart(gen, "StartInteract")
		if start then
			local prompt = MapService.MakePrompt(start, { Name = "StartPrompt", ActionText = "Start Generator", ObjectText = "GEN-2", MaxDistance = 8, Enabled = false })
			startPrompt = prompt
			prompt.Triggered:Connect(function(player: Player)
				if not alive(player) or generatorOn or not fueled then
					return
				end
				genT0 = now()
				openTerminal:FireClient(player, "Generator", generatorData(), false)
			end)
		end
	end
	for _, heater in MapService.GetTaggedModels("Heater") do
		local hc = MapService.FindPart(heater, "HeatCenter")
		if hc then
			table.insert(heaterSources, TemperatureService.AddSource("Heater", hc.Position, hc, nil, false))
		end
	end
	elevator = MapService.GetTaggedModels("Elevator")[1]
	local el = elevator
	if el then
		local scr = el:FindFirstChild("PanelScreen", true)
		local gui = if scr then scr:FindFirstChildOfClass("SurfaceGui") else nil
		local bg = if gui then gui:FindFirstChild("Background") else nil
		local lbl = if bg then bg:FindFirstChild("Text") else nil
		if lbl and lbl:IsA("TextLabel") then
			elevScreen = lbl
		end
	end
end

local function setPlatform(present: boolean)
	local el = elevator
	if el == nil then
		return
	end
	local platform = MapService.FindPart(el, "Platform")
	if platform then
		platform.Transparency = if present then 0 else 1
		platform.CanCollide = present
		platform:SetAttribute("Present", present)
	end
	local gate = MapService.FindPart(el, "Gate")
	if gate then
		tweenTo(gate, if present then "OpenCF" else "ClosedCF", 1.2)
		gate.CanCollide = not present
	end
	setNeon(MapService.FindPart(el, "StatusLight"), if present then GREEN else RED)
end

local function ridersInLift(): { Player }
	local el = elevator
	local out: { Player } = {}
	if el == nil then
		return out
	end
	local vol = MapService.FindPart(el, "RideVolume")
	if vol == nil then
		return out
	end
	for _, p in Util.PlayersInState({ "Alive", "Downed" }) do
		local r = Util.GetRoot(p)
		if r and Zones.IsInsidePart(vol, r.Position) then
			table.insert(out, p)
		end
	end
	return out
end

local function teleportToZone4(riders: { Player })
	local spawns = {}
	for _, s in MapService.GetTaggedParts("Spawn") do
		if s:GetAttribute("Zone") == "Zone4" then
			table.insert(spawns, s)
		end
	end
	for i, p in riders do
		local s = spawns[((i - 1) % math.max(1, #spawns)) + 1]
		local root = Util.GetRoot(p)
		if s and root then
			pcall(function()
				p:RequestStreamAroundAsync(s.Position, 5)
			end)
			root.Anchored = false
			MovementService.Teleport(p, s.CFrame)
		end
	end
end

local function departElevator()
	elevState = "Riding"
	elevTrips += 1
	local riders = ridersInLift()
	local el = elevator :: Model
	local gate = MapService.FindPart(el, "Gate")
	if gate then
		tweenTo(gate, "ClosedCF", 1)
		gate.CanCollide = true
	end
	local pos = MapService.ModelPosition(el)
	NoiseService.EmitWithSound(pos, 30, "Elevator", "ElevatorRumble", nil, 1.5)
	setElevatorScreen("DESCENDING")
	for _, p in riders do
		local r = Util.GetRoot(p)
		if r then
			r.Anchored = true
		end
		Net.Event("ScreenEffect"):FireClient(p, "ElevatorRide", P.ElevatorRideTime)
	end
	local gen = generation
	task.delay(P.ElevatorRideTime, function()
		if gen ~= generation then
			return
		end
		setPlatform(false)
		teleportToZone4(riders)
		if #riders > 0 then
			PuzzleService.ElevatorArrived:Fire(riders, elevTrips)
		end
		-- Wer den Aufzug verpasst hat: er kommt nach 30 s noch einmal
		local leftBehind = false
		for _, p in Util.PlayersInState({ "Alive", "Downed" }) do
			if Util.StrAttr(p, "Zone", "None") == "Zone3" and not table.find(riders, p) then
				leftBehind = true
			end
		end
		if elevTrips < P.ElevatorTrips and leftBehind then
			elevState = "Returning"
			elevTimer = now() + P.ElevatorReturnTime
			setElevatorScreen("RETURNING")
		else
			elevState = "Gone"
			setElevatorScreen("OFFLINE")
			PuzzleService.ElevatorFinal:Fire()
		end
	end)
end

local function updateElevator()
	if elevator == nil then
		return
	end
	local t = now()
	if elevState == "Absent" then
		setElevatorScreen(if fueled then "NO POWER\nSTART GEN-2" else "NO POWER")
	elseif elevState == "Arriving" or elevState == "Returning" then
		local left = math.max(0, math.ceil(elevTimer - t))
		setElevatorScreen(string.format("LIFT ARRIVING\n%02d S", left))
		if t >= elevTimer then
			elevState = "Waiting"
			elevTimer = t + P.ElevatorMaxWait
			setPlatform(true)
			NoiseService.PlaySound("ElevatorRumble", MapService.ModelPosition(elevator :: Model), 1.2)
			sayAll("CARGO LIFT HAS ARRIVED - ALL ABOARD")
		end
	elseif elevState == "Waiting" then
		local left = math.max(0, math.ceil(elevTimer - t))
		setElevatorScreen(string.format("BOARD NOW\n%02d S", left))
		-- fährt los, sobald alle lebenden Spieler darauf stehen, spätestens nach 15 s
		local living = Util.PlayersInState({ "Alive", "Downed" })
		local riders = ridersInLift()
		local allAboard = #living > 0 and #riders == #living
		if allAboard or t >= elevTimer then
			departElevator()
		end
	end
end

----------------------------------------------------------------------
-- Zone 4: Kontrollstäbe, Dampfventile, Luken
----------------------------------------------------------------------
local function setRod(rod: Rod, down: boolean)
	rod.Down = down
	local part = MapService.FindPart(rod.Model, "Rod")
	if part then
		tweenTo(part, if down then "DownCF" else "UpCF", if down then 2 else 1.2)
	end
	setNeon(MapService.FindPart(rod.Model, "Led"), if down then GREEN else RED)
	rod.Prompt.Enabled = not down and not rodsDone
end

local function steamBurstNear(pos: Vector3)
	local list = table.clone(steamVents)
	table.sort(list, function(a: Vent, b: Vent): boolean
		return (MapService.ModelPosition(a.Model) - pos).Magnitude < (MapService.ModelPosition(b.Model) - pos).Magnitude
	end)
	for i = 1, math.min(2, #list) do
		list[i].BurstUntil = now() + P.SteamBurstTime
	end
end

local function livingCount(): number
	return #Util.PlayersInState({ "Alive", "Downed" })
end

local function lowerRod(player: Player, rod: Rod)
	if rod.Down or rodsDone then
		return
	end
	setRod(rod, true)
	local pos = MapService.ModelPosition(rod.Model)
	NoiseService.Emit(pos, P.RodCrankNoise, "Rod", player)
	steamBurstNear(pos)
	NoiseService.PlaySound("Hiss", pos, 1.4)
	local downCount = 0
	for _, r in rods do
		if r.Down then
			downCount += 1
		end
	end
	local syncMode = livingCount() >= 3
	if syncMode then
		if firstRodAt == 0 then
			firstRodAt = now()
			sayAll("ROD 1 DOWN - 30 SECONDS TO DROP THE REST")
		else
			sayAll(string.format("ROD DOWN (%d/4)", downCount))
		end
	else
		-- Einzelmodus: jeder Stab rastet ein und löst einen Alarm-Impuls aus
		NoiseService.EmitWithSound(pos, P.RodAlarmNoise, "Alarm", "Alarm", nil, 2)
		sayAll(string.format("ROD LATCHED (%d/4) - ALARM!", downCount))
	end
	if downCount >= #rods and #rods > 0 then
		rodsDone = true
		firstRodAt = 0
		for _, r in rods do
			r.Prompt.Enabled = false
		end
		PuzzleService.RodsCompleted:Fire()
	end
end

local function setupZone4()
	for _, model in MapService.GetTaggedModels("ControlRod") do
		local inter = MapService.FindPart(model, "Interact")
		if inter then
			local idx = model:GetAttribute("Index")
			local prompt = MapService.MakePrompt(inter, { Name = "RodPrompt", ActionText = "Lower Rod", ObjectText = "Control Rod " .. tostring(idx), HoldDuration = P.RodCrankHold, MaxDistance = 7 })
			local rod: Rod = { Model = model, Prompt = prompt, Down = false, Index = if type(idx) == "number" then idx else 0 }
			table.insert(rods, rod)
			prompt.PromptButtonHoldBegan:Connect(function(player: Player)
				if alive(player) then
					NoiseService.EmitWithSound(inter.Position, P.RodCrankNoise, "Crank", "RadiatorCrank", player)
				end
			end)
			prompt.Triggered:Connect(function(player: Player)
				if alive(player) then
					lowerRod(player, rod)
				end
			end)
		end
	end
	for _, model in MapService.GetTaggedModels("SteamVent") do
		local nozzle = MapService.FindPart(model, "Nozzle")
		local vol = MapService.FindPart(model, "SteamVolume")
		local em = if nozzle then nozzle:FindFirstChild("Steam") else nil
		local v: Vent = {
			Model = model,
			Emitter = if em and em:IsA("ParticleEmitter") then em else nil,
			Volume = vol,
			Source = if vol then TemperatureService.AddSource("SteamVent", vol.Position, vol, nil, false) else nil,
			Beacon = if vol then NoiseService.AddBeacon("SteamVent", vol.Position, vol, nil) else nil,
			Offset = rng:NextNumber() * (P.SteamVentOn + P.SteamVentOff),
			BurstUntil = 0,
			On = false,
		}
		table.insert(steamVents, v)
	end
	local heli = MapService.GetTaggedModels("Helicopter")[1]
	if heli then
		local inter = MapService.FindPart(heli, "Interact")
		if inter then
			local prompt = MapService.MakePrompt(inter, { Name = "BoardPrompt", ActionText = "Board", ObjectText = "Helicopter", HoldDuration = P.HelicopterBoardHold, MaxDistance = 9, Enabled = false })
			heliPrompt = prompt
			prompt.Triggered:Connect(function(player: Player)
				if not alive(player) then
					return
				end
				PuzzleService.Boarded:Fire(player)
			end)
		end
	end
end

local function updateSteam()
	local t = now()
	local cycle = P.SteamVentOn + P.SteamVentOff
	for _, v in steamVents do
		local on = ((t + v.Offset) % cycle) < P.SteamVentOn or t < v.BurstUntil
		if on ~= v.On then
			v.On = on
			if v.Emitter then
				v.Emitter.Enabled = on
			end
			if v.Volume then
				TemperatureService.SetSteamActive(v.Volume, on)
			end
			if v.Source then
				TemperatureService.SetSourceActive(v.Source, on)
			end
			if v.Beacon then
				NoiseService.SetBeaconActive(v.Beacon, on)
			end
		end
	end
end

local function updateRods()
	if firstRodAt > 0 and not rodsDone and now() - firstRodAt > P.RodSyncWindow then
		firstRodAt = 0
		for _, r in rods do
			if r.Down then
				setRod(r, false)
			end
		end
		sayAll("SYNC FAILED - RODS RETRACTED")
		local first = rods[1]
		if first then
			NoiseService.PlaySound("Alarm", MapService.ModelPosition(first.Model), 1)
		end
	end
end

function PuzzleService.OpenHatches()
	if hatchesOpen then
		return
	end
	hatchesOpen = true
	MapService.GetMap():SetAttribute("HatchesOpen", true)
	for _, h in MapService.GetTaggedParts("RoofHatch") do
		tweenTo(h, "OpenCF", P.HatchCinematicTime - 1, Enum.EasingStyle.Sine)
	end
	for _, lid in MapService.GetTaggedParts("LadderHatch") do
		tweenTo(lid, "OpenCF", 1.5)
		lid.CanCollide = false
		task.delay(1.6, function()
			lid.CanCollide = true
		end)
	end
	for _, sky in MapService.GetTaggedParts("HatchSky") do
		for _, c in sky:GetChildren() do
			if c:IsA("ParticleEmitter") then
				c.Rate = 90
			elseif c:IsA("SpotLight") then
				c.Enabled = true
				c.Brightness = 2
			end
		end
	end
	for _, b in MapService.GetTagged("HatchBeam") do
		if b:IsA("Beam") then
			b.Enabled = true
		end
	end
	local heli = MapService.GetTaggedModels("Helicopter")[1]
	if heli then
		heli:SetAttribute("Rotor", 1)
	end
	if heliPrompt then
		heliPrompt.Enabled = true
	end
	local first = MapService.GetTaggedParts("RoofHatch")[1]
	if first then
		NoiseService.EmitWithSound(first.Position, 60, "Hatch", "ArmorDoor", nil, 2)
	end
end

function PuzzleService.SetHeliBoarding(enabled: boolean)
	if heliPrompt then
		heliPrompt.Enabled = enabled
	end
end

----------------------------------------------------------------------
-- Runde zurücksetzen
----------------------------------------------------------------------
function PuzzleService.Reset()
	generation += 1
	InventoryService.ClearWorldItems()
	MapService.ResetAllDoors()
	-- Sicherungen in 2 von 8 Verstecken
	local order: { number } = {}
	for i = 1, #fuseSpots do
		table.insert(order, i)
		local s = fuseSpots[i]
		s.HasFuse = false
		s.Searched = false
		s.Prompt.Enabled = true
	end
	Util.Shuffle(order, rng)
	for i = 1, math.min(P.FuseCount, #order) do
		fuseSpots[order[i]].HasFuse = true
	end
	socketFilled = { false, false }
	leverPulled = false
	local box = fuseBox
	if box then
		local lever = MapService.FindPart(box, "Lever")
		if lever then
			snapTo(lever, "UpCF")
		end
	end
	updateFuseBox()
	radiatorUntil = 0
	updateRadiator()
	-- Phiolen in 3 von 6 Schränken, Reihenfolge jede Runde anders
	local vials = { "VialBlue", "VialGreen", "VialRed" }
	local cabOrder: { number } = {}
	for i, cab in cabinets do
		table.insert(cabOrder, i)
		cab.Vial = nil
		cab.Opened = false
		cab.Prompt.Enabled = true
		local door = MapService.FindPart(cab.Model, "Door")
		if door then
			snapTo(door, "ClosedCF")
		end
	end
	Util.Shuffle(cabOrder, rng)
	for i, v in vials do
		local idx = cabOrder[i]
		if idx then
			cabinets[idx].Vial = v
		end
	end
	sequence = Util.Shuffle(table.clone(vials), rng)
	local wb = whiteboardLabel
	if wb then
		local lines = { "CENTRIFUGE LOAD ORDER:", "" }
		for i, v in sequence do
			table.insert(lines, string.format('%d.  <font color="%s">%s</font>', i, VIAL_HEX[v], VIAL_NAMES[v]))
		end
		table.insert(lines, "")
		table.insert(lines, "DO NOT DEVIATE!  - E.V.")
		wb.Text = table.concat(lines, "\n")
	end
	table.clear(centSlots)
	centRunning = false
	centDone = false
	centLockUntil = 0
	updateCentrifuge()
	keycardUsed = false
	if readerPrompt then
		readerPrompt.Enabled = true
	end
	local reader = MapService.GetTaggedModels("KeycardReader")[1]
	if reader then
		setNeon(MapService.FindPart(reader, "Led"), RED)
	end
	-- Generator und Aufzug
	fueled = false
	generatorOn = false
	if fuelPrompt then
		fuelPrompt.Enabled = true
	end
	if startPrompt then
		startPrompt.Enabled = false
	end
	setGeneratorVisuals(false)
	elevState = "Absent"
	elevTrips = 0
	setPlatform(false)
	setElevatorScreen("NO POWER")
	-- Stäbe, Luken, Helikopter
	rodsDone = false
	firstRodAt = 0
	for _, r in rods do
		setRod(r, false)
		local part = MapService.FindPart(r.Model, "Rod")
		if part then
			snapTo(part, "UpCF")
		end
	end
	hatchesOpen = false
	MapService.GetMap():SetAttribute("HatchesOpen", false)
	for _, h in MapService.GetTaggedParts("RoofHatch") do
		snapTo(h, "ClosedCF")
	end
	for _, lid in MapService.GetTaggedParts("LadderHatch") do
		snapTo(lid, "ClosedCF")
		lid.CanCollide = true
	end
	for _, sky in MapService.GetTaggedParts("HatchSky") do
		for _, c in sky:GetChildren() do
			if c:IsA("ParticleEmitter") then
				c.Rate = 0
			elseif c:IsA("SpotLight") then
				c.Enabled = false
			end
		end
	end
	for _, b in MapService.GetTagged("HatchBeam") do
		if b:IsA("Beam") then
			b.Enabled = false
		end
	end
	local heli = MapService.GetTaggedModels("Helicopter")[1]
	if heli then
		heli:SetAttribute("Rotor", 0)
	end
	if heliPrompt then
		heliPrompt.Enabled = false
	end
	-- Welt-Items neu verteilen
	spawnItems()
end

function PuzzleService.Init()
	notify = Net.Event("Notify")
	openTerminal = Net.Event("OpenTerminal")
	setupNotes()
	setupZone1()
	setupZone2()
	setupZone3()
	setupZone4()
end

function PuzzleService.Start()
	Net.Event("CentrifugeInput").OnServerEvent:Connect(centrifugeInput)
	Net.Event("GeneratorAttempt").OnServerEvent:Connect(generatorAttempt)
	Players.PlayerRemoving:Connect(function(player)
		lastGenAttempt[player] = nil
	end)
	-- Zentrifugen-Rotor drehen (sichtbar für alle)
	local angle = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local c = centrifuge
		if c and centRunning then
			local rotor = MapService.FindPart(c, "Rotor")
			local base = if rotor then rotor:GetAttribute("BaseCF") else nil
			if rotor and typeof(base) == "CFrame" then
				angle += dt * 14
				rotor.CFrame = base * CFrame.Angles(0, angle, 0)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			Util.Try("PuzzleService", function()
				updateRadiator()
				updateElevator()
				updateSteam()
				updateRods()
				if centRunning or now() < centLockUntil + 1 then
					updateCentrifuge()
				end
			end)
		end
	end)
end

return PuzzleService
