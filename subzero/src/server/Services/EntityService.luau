--!strict
-- EntityService: das Wesen (Abschnitt 5). Läuft komplett auf dem Server.
-- Sinne (5 Hz): Wärme-Strahl (360°, Wände mit ThermalBlock blockieren), Gehör (halber Radius
-- durch Wände), Wärme-Leuchtfeuer. Aufmerksamkeit 0..100 pro Spieler.
-- Zustände: Sleeping, Patrol, Investigate, Hunt, Search, Attracted, Frenzy, Retreat.
-- Entscheidungen 10 Hz, Pfadfindung, Türen aufbrechen, Spinde aufreißen, Lüftungsschacht-Netz,
-- Spannungs-Regisseur, Skalierung nach Spielerzahl.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Util = require(ReplicatedStorage.Shared.Util)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Creature = require(script.Parent.Parent.Creature)
local DataService = require(script.Parent.DataService)
local HealthService = require(script.Parent.HealthService)
local InventoryService = require(script.Parent.InventoryService)
local MapService = require(script.Parent.MapService)
local MovementService = require(script.Parent.MovementService)
local NoiseService = require(script.Parent.NoiseService)
local StatsService = require(script.Parent.StatsService)

local EntityService = {}
EntityService.Name = "EntityService"

local E = Config.Entity

type Mem = { Attention: number, LastKnown: Vector3?, LastContact: number, Seen: boolean }

local model: Model
local root: BasePart
local hum: Humanoid
local head: BasePart

local memory: { [Player]: Mem } = {}
local aiState: string = "Sleeping"
local active = false -- Runde läuft und das Wesen ist erwacht

-- Ziele und Zustandsdaten
local huntTarget: Player? = nil
local huntStart = 0
local chaseStart = 0
local investigatePos: Vector3? = nil
local investigateTarget: Player? = nil
local lastStimulus = 0
local probeUntil = 0
local searchCenter: Vector3? = nil
local searchUntil = 0
local searchPoint: Vector3? = nil
local attractedPart: BasePart? = nil
local attractedBeacon: number? = nil
local attractedUntil = 0
local attractedAngle = 0
local visitedFlares: { [number]: boolean } = {}
local frenzyUntil = 0
local frenzyPermanent = false
local frenzyFocus: Vector3? = nil
local frenzyPoint: Vector3? = nil
local patrolGoal: Vector3? = nil
local patrolWaitUntil = 0
local lastPatrolWp: BasePart? = nil
local busy = false -- Lüftungsschacht, Tür aufbrechen, Zupacken, Spind aufreißen
local travelling = false -- unterwegs zu/in einem Lüftungsschacht
-- Zählt bei jedem Reset hoch: verzögerte Abläufe einer alten Runde brechen dann ab
local generation = 0
local grabbing = false
local visitedBeacons: { [number]: number } = {}

-- Regisseur
local pressure = 0
local calm = 0
local awayUntil = 0
local nearPlayersUntil = 0

-- Skalierung
local scale = E.Scaling[4]

-- Pfadfindung
local path: Path
local waypoints: { PathWaypoint } = {}
local wpIndex = 0
local pathGoal: Vector3? = nil
local computing = false
local lastCompute = 0
local pathFails = 0
local lastProgressPos = Vector3.zero
local lastProgressTime = 0

local rayParams = RaycastParams.new()

local HIDDEN_CF = CFrame.new(0, -300, 0)

local function now(): number
	return Workspace:GetServerTimeNow()
end

----------------------------------------------------------------------
-- Hilfsfunktionen
----------------------------------------------------------------------
local function setAIState(s: string)
	if aiState ~= s then
		aiState = s
		model:SetAttribute("AIState", s)
	end
end

local function frenzyActive(): boolean
	return frenzyPermanent or now() < frenzyUntil
end

local function senseFactor(): number
	return scale.Range * (if frenzyActive() then E.FrenzySenseFactor else 1)
end

local function candidates(): { Player }
	return Util.PlayersInState({ "Alive", "Downed" })
end

local function memOf(p: Player): Mem
	local m = memory[p]
	if m == nil then
		m = { Attention = 0, LastKnown = nil, LastContact = 0, Seen = false }
		memory[p] = m
	end
	return m
end

local function headPos(): Vector3
	return head.Position
end

-- Strahl: blockieren nur Teile mit ThermalBlock = true (Wände, geschlossene Türen)
local function thermalBlocked(from: Vector3, to: Vector3): boolean
	local dir = to - from
	local exclude: { Instance } = { model }
	local items = Workspace:FindFirstChild("Items")
	if items then
		table.insert(exclude, items)
	end
	local corpses = Workspace:FindFirstChild("Corpses")
	if corpses then
		table.insert(exclude, corpses)
	end
	for _ = 1, 6 do
		rayParams.FilterDescendantsInstances = exclude
		local hit = Workspace:Raycast(from, dir, rayParams)
		if hit == nil then
			return false
		end
		if hit.Instance:GetAttribute("ThermalBlock") == true then
			return true
		end
		table.insert(exclude, hit.Instance)
	end
	return false
end

local function flatDist(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function currentZone(): string
	return Zones.GetZoneAt(root.Position)
end

-- Zone mit den meisten lebenden Spielern
local function homeZone(): string?
	local counts: { [string]: number } = {}
	local best: string? = nil
	local bestN = 0
	for _, p in candidates() do
		local z = Util.StrAttr(p, "Zone", "None")
		if Zones.Index(z) >= 1 then
			counts[z] = (counts[z] or 0) + 1
			local n = counts[z]
			if n > bestN or (n == bestN and best ~= nil and Zones.Index(z) > Zones.Index(best)) then
				best = z
				bestN = n
			end
		end
	end
	return best
end

local function waypointsIn(zone: string): { BasePart }
	local out: { BasePart } = {}
	for _, wp in MapService.GetTaggedParts("Waypoint") do
		if wp:GetAttribute("Zone") == zone then
			table.insert(out, wp)
		end
	end
	return out
end

local function ventsIn(zone: string?): { Model }
	local out: { Model } = {}
	for _, v in MapService.GetTaggedModels("Vent") do
		if zone == nil or v:GetAttribute("Zone") == zone then
			table.insert(out, v)
		end
	end
	return out
end

local function ventExit(vent: Model): BasePart?
	return MapService.FindPart(vent, "Exit")
end

local function nearestPlayerDist(pos: Vector3): number
	local best = math.huge
	for _, p in candidates() do
		local r = Util.GetRoot(p)
		if r then
			best = math.min(best, (r.Position - pos).Magnitude)
		end
	end
	return best
end

----------------------------------------------------------------------
-- Bewegung und Pfadfindung
----------------------------------------------------------------------
local function setSpeed()
	local base = E.Speed[aiState] or E.Speed.Patrol
	if aiState ~= "Retreat" and aiState ~= "Sleeping" and frenzyActive() and aiState ~= "Attracted" then
		base = E.Speed.Frenzy
	end
	hum.WalkSpeed = if busy then 0 else base * scale.Speed
end

local function stop()
	waypoints = {}
	wpIndex = 0
	pathGoal = nil
	hum:MoveTo(root.Position)
end

local function computePath(goal: Vector3)
	if computing then
		return
	end
	computing = true
	lastCompute = os.clock()
	local start = root.Position
	task.spawn(function()
		local ok = pcall(function()
			path:ComputeAsync(start, goal)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			waypoints = path:GetWaypoints()
			wpIndex = math.min(2, #waypoints)
			pathGoal = goal
			pathFails = 0
		else
			waypoints = {}
			wpIndex = 0
			pathGoal = goal
			pathFails += 1
		end
		computing = false
	end)
end

local function clearLine(to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { model }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local from = root.Position
	local hit = Workspace:Raycast(from, to - from, params)
	return hit == nil and math.abs(to.Y - from.Y) < 6
end

-- Folgt dem Pfad zum Ziel; repath: minimale Zeit zwischen Neuberechnungen
local function moveTowards(goal: Vector3, repath: number, direct: boolean?)
	if busy then
		return
	end
	if direct and (goal - root.Position).Magnitude < E.DirectChaseRange and clearLine(goal) then
		waypoints = {}
		hum:MoveTo(goal)
		return
	end
	local needNew = pathGoal == nil or (pathGoal - goal).Magnitude > 4 or (wpIndex == 0 and not computing)
	if needNew and os.clock() - lastCompute >= repath then
		computePath(goal)
	end
	local wp = waypoints[wpIndex]
	if wp then
		hum:MoveTo(wp.Position)
		if flatDist(root.Position, wp.Position) < 3 and math.abs(root.Position.Y - 5 - wp.Position.Y) < 6 then
			wpIndex += 1
		end
	end
end

local function arrived(goal: Vector3, radius: number): boolean
	return flatDist(root.Position, goal) <= radius and math.abs(root.Position.Y - goal.Y) < 10
end

-- Steckt fest? Dann neuer Pfad bzw. Rückmeldung
local function checkStuck(): boolean
	local t = os.clock()
	if (root.Position - lastProgressPos).Magnitude > E.StuckMoveEps then
		lastProgressPos = root.Position
		lastProgressTime = t
		return false
	end
	if t - lastProgressTime > E.StuckTime then
		lastProgressTime = t
		pathGoal = nil
		return true
	end
	return false
end

----------------------------------------------------------------------
-- Lüftungsschacht-Netz
----------------------------------------------------------------------
local checkDoorHook: () -> () = function() end
local function placeAt(cf: CFrame)
	-- Boden unter dem Punkt suchen, Wurzel 5 Studs darüber
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	local hit = Workspace:Raycast(cf.Position + Vector3.new(0, 2, 0), Vector3.new(0, -14, 0), params)
	local ground = if hit then hit.Position else cf.Position - Vector3.new(0, 2, 0)
	local look = cf.LookVector
	local p = ground + Vector3.new(0, 5, 0)
	model:PivotTo(CFrame.lookAt(p, p + Vector3.new(look.X, 0, look.Z)))
end

local function hide()
	model:SetAttribute("InVent", true)
	root.Anchored = true
	model:PivotTo(HIDDEN_CF)
end

local function emerge(vent: Model)
	local exit = ventExit(vent)
	if exit == nil then
		return
	end
	local gen = generation
	-- Warnung: 2 s Kratzen aus der Wand, Frost breitet sich am Gitter aus
	vent:SetAttribute("ScratchAt", now())
	local anchor = MapService.FindPart(vent, "SoundAnchor")
	NoiseService.PlaySound("VentScratch", if anchor then anchor.Position else exit.Position, 1.4, 1, 90)
	task.wait(E.VentScratchTime)
	if gen ~= generation then
		return
	end
	placeAt(exit.CFrame)
	root.Anchored = false
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	model:SetAttribute("InVent", false)
	waypoints = {}
	pathGoal = nil
	lastProgressPos = root.Position
	lastProgressTime = os.clock()
end

-- In den nächsten Schacht kriechen, hideTime warten, am Ziel-Schacht herauskommen
local function ventTravel(dest: Model, hideTime: number, after: (() -> ())?)
	if busy or travelling then
		return
	end
	busy = true
	travelling = true
	setSpeed()
	local gen = generation
	task.spawn(function()
		if model:GetAttribute("InVent") ~= true then
			-- zum nächsten erreichbaren Gitter laufen (max. 10 s), dann hineinkriechen
			local bestVent: Model? = nil
			local bestD = math.huge
			for _, v in ventsIn(currentZone()) do
				local ex = ventExit(v)
				if ex then
					local d = (ex.Position - root.Position).Magnitude
					if d < bestD then
						bestD = d
						bestVent = v
					end
				end
			end
			if bestVent and bestD < 60 then
				local ex = ventExit(bestVent) :: BasePart
				busy = false
				local t0 = os.clock()
				hum.WalkSpeed = E.Speed.Retreat * scale.Speed
				while os.clock() - t0 < 10 and not arrived(ex.Position, 4) and active do
					if not busy then
						moveTowards(ex.Position, 0.5)
						checkDoorHook()
					end
					task.wait(0.1)
					if model.Parent == nil or gen ~= generation then
						return
					end
				end
				while busy and gen == generation do
					task.wait(0.1)
				end
				if gen ~= generation then
					return
				end
				busy = true
				stop()
				task.wait(E.VentEnterTime)
				if gen ~= generation then
					return
				end
			end
			hide()
		end
		task.wait(hideTime)
		if gen ~= generation then
			return
		end
		if not active then
			busy = false
			travelling = false
			return
		end
		emerge(dest)
		if gen ~= generation then
			return
		end
		busy = false
		travelling = false
		if after then
			after()
		end
	end)
end

local function ventNearest(pos: Vector3, zone: string?): Model?
	local best: Model? = nil
	local bestD = math.huge
	for _, v in ventsIn(zone) do
		local ex = ventExit(v)
		if ex then
			local d = (ex.Position - pos).Magnitude
			if d < bestD then
				bestD = d
				best = v
			end
		end
	end
	return best
end

-- Schacht in einer Zone, der nicht direkt neben einem Spieler liegt
local function ventFor(zone: string, preferFar: boolean): Model?
	local list = ventsIn(zone)
	if #list == 0 then
		return nil
	end
	table.sort(list, function(a: Model, b: Model): boolean
		local ea, eb = ventExit(a), ventExit(b)
		local da = if ea then nearestPlayerDist(ea.Position) else 0
		local db = if eb then nearestPlayerDist(eb.Position) else 0
		return da > db
	end)
	if preferFar then
		return list[1]
	end
	-- nicht der nächstgelegene (fair), aber auch nicht der fernste
	for _, v in list do
		local ex = ventExit(v)
		if ex and nearestPlayerDist(ex.Position) > 25 then
			return v
		end
	end
	return list[1]
end

----------------------------------------------------------------------
-- Zustandswechsel
----------------------------------------------------------------------
local function startHunt(p: Player)
	if huntTarget ~= p or aiState ~= "Hunt" then
		huntTarget = p
		huntStart = now()
		chaseStart = now()
		model:SetAttribute("TargetUserId", p.UserId)
		StatsService.AddDetected(p)
		NoiseService.PlaySound("HuntScreech", root.Position, 2, 1, 220)
	end
	memOf(p).Attention = 100
	setAIState("Hunt")
end

local function startSearch(center: Vector3)
	searchCenter = center
	searchUntil = now() + E.SearchDuration
	searchPoint = nil
	huntTarget = nil
	model:SetAttribute("TargetUserId", 0)
	setAIState("Search")
end

local function startInvestigate(pos: Vector3, target: Player?)
	investigatePos = pos
	investigateTarget = target
	lastStimulus = now()
	probeUntil = 0
	if aiState ~= "Investigate" then
		setAIState("Investigate")
	end
end

local function startPatrol()
	huntTarget = nil
	investigatePos = nil
	investigateTarget = nil
	patrolGoal = nil
	model:SetAttribute("TargetUserId", 0)
	setAIState(if frenzyActive() then "Frenzy" else "Patrol")
end

local function startRetreat()
	huntTarget = nil
	model:SetAttribute("TargetUserId", 0)
	setAIState("Retreat")
	for _, m in memory do
		m.Attention = math.min(m.Attention, 20)
	end
	local zone = homeZone() or currentZone()
	local dest = ventFor(zone, true) or ventNearest(root.Position, nil)
	if dest then
		ventTravel(dest, E.RetreatDuration, function()
			startPatrol()
		end)
	else
		startPatrol()
	end
end

local function startAttracted(part: BasePart, beaconId: number, owner: Player?)
	local wasPursuing = aiState == "Hunt" or aiState == "Investigate" or (aiState == "Frenzy" and huntTarget ~= nil)
	attractedPart = part
	attractedBeacon = beaconId
	attractedUntil = now() + E.AttractedDuration
	visitedFlares[beaconId] = true
	huntTarget = nil
	model:SetAttribute("TargetUserId", 0)
	setAIState("Attracted")
	if owner and wasPursuing then
		-- Thermische Ablenkung (Bestenliste)
		StatsService.AddDistraction(owner)
		DataService.Add(owner, "Distractions", 1)
	end
end

----------------------------------------------------------------------
-- Sinne
----------------------------------------------------------------------
local function senseTick(dt: number)
	local t = now()
	local hp = headPos()
	local factor = senseFactor()
	local gainAllowed = t >= awayUntil
	for _, p in candidates() do
		local m = memOf(p)
		local r = Util.GetRoot(p)
		m.Seen = false
		if r then
			local sig = Util.NumAttr(p, "HeatSig", 0)
			local range = sig * Config.Signature.SightPerSig * factor
			local d = (r.Position - hp).Magnitude
			if range > 0 and d <= range and not thermalBlocked(hp, r.Position) then
				m.Seen = true
				m.LastKnown = r.Position
				m.LastContact = t
				if gainAllowed then
					local gain = E.AttentionHeatPerSec * (if d < E.AttentionHeatCloseRange then E.AttentionHeatCloseFactor else 1)
					m.Attention = math.min(100, m.Attention + gain * scale.Attention * dt)
				end
			end
		end
		if not m.Seen and t - m.LastContact > 0.25 then
			local decay = E.AttentionDecayPerSec * (if frenzyActive() then E.FrenzyDecayFactor else 1)
			m.Attention = math.max(0, m.Attention - decay * dt)
		end
	end
	-- Spieler, die nicht mehr in der Runde sind, vergessen
	for p in memory do
		local st = Util.GetState(p)
		if p.Parent == nil or (st ~= "Alive" and st ~= "Downed") then
			memory[p] = nil
		end
	end
end

local function onNoise(ev: Types.NoiseEvent, attention: number?)
	if not active or travelling or aiState == "Sleeping" or model:GetAttribute("InVent") == true then
		return
	end
	local hp = headPos()
	local radius = ev.Radius * senseFactor()
	local d = (ev.Position - hp).Magnitude
	if d > radius then
		return
	end
	if d > radius * E.WallNoiseFactor and thermalBlocked(hp, ev.Position + Vector3.new(0, 1, 0)) then
		return
	end
	local src = ev.Source
	if src and (Util.GetState(src) == "Alive" or Util.GetState(src) == "Downed") then
		local m = memOf(src)
		m.LastKnown = ev.Position
		m.LastContact = now()
		if now() >= awayUntil then
			local a = attention or E.AttentionNoiseEvent
			m.Attention = math.min(100, m.Attention + a * scale.Attention)
		end
	elseif src == nil then
		-- Geräusch ohne Spieler (Alarm, Generator, Tür): Ort untersuchen
		if aiState == "Patrol" or aiState == "Search" or (aiState == "Investigate" and investigateTarget == nil) then
			startInvestigate(ev.Position, nil)
		end
	end
end

local function beaconTick()
	if not active or busy or travelling or aiState == "Sleeping" or aiState == "Retreat" or grabbing then
		return
	end
	local hp = headPos()
	local t = now()
	for _, b in NoiseService.GetActiveBeacons() do
		local d = (b.Position - hp).Magnitude
		if d <= b.Radius * scale.Range then
			if b.Kind == "Flare" then
				local isGround = b.Part ~= nil and b.Part.Parent ~= nil and b.Part:IsDescendantOf(Workspace) and b.Part.Name ~= "RightHand"
				local st: string = aiState
				local canAttract = st ~= "Attracted"
				local idle = st == "Patrol" or st == "Search"
				if isGround and b.Part and not visitedFlares[b.Id] and canAttract then
					startAttracted(b.Part, b.Id, b.Owner)
					return
				elseif not isGround and idle then
					-- Fackel in der Hand: zum Träger
					startInvestigate(b.Position, b.Owner)
				end
			elseif b.Kind == "Radiator" or b.Kind == "SteamVent" then
				if aiState == "Patrol" and t - (visitedBeacons[b.Id] or 0) > 45 then
					visitedBeacons[b.Id] = t
					startInvestigate(b.Position, nil)
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- Türen und Spinde
----------------------------------------------------------------------
local doorParams = RaycastParams.new()
doorParams.FilterType = Enum.RaycastFilterType.Include

local function checkDoor()
	if busy then
		return
	end
	local panels = MapService.GetNormalDoorPanels()
	if #panels == 0 then
		return
	end
	local dir = hum.MoveDirection
	if dir.Magnitude < 0.1 then
		return
	end
	doorParams.FilterDescendantsInstances = panels
	local hit = Workspace:Raycast(root.Position, Vector3.new(dir.X, 0, dir.Z).Unit * E.DoorCheckDistance, doorParams)
	if hit == nil then
		return
	end
	local door = hit.Instance.Parent
	if door == nil or not door:IsA("Model") then
		return
	end
	if door:GetAttribute("Open") == true or door:GetAttribute("Broken") == true then
		return
	end
	-- Normale Tür in 2,5 s aufbrechen (laut)
	busy = true
	stop()
	setSpeed()
	local gen = generation
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < E.DoorBreakTime do
			NoiseService.EmitWithSound(hit.Position, E.DoorBreakNoise, "DoorBang", "DoorBang", nil, 1.5)
			task.wait(0.8)
			if gen ~= generation then
				return
			end
		end
		MapService.BreakDoor(door)
		busy = false
		pathGoal = nil
	end)
end

checkDoorHook = checkDoor

local function tryRipLocker(): boolean
	if busy then
		return false
	end
	for p, m in memory do
		if m.Attention > Config.Locker.RipOpenAttention and p:GetAttribute("InLocker") == true then
			local locker = MovementService.GetLocker(p)
			if locker then
				local lp = MapService.ModelPosition(locker)
				if flatDist(root.Position, lp) <= Config.Locker.RipOpenRange then
					busy = true
					stop()
					setSpeed()
					local gen = generation
					task.spawn(function()
						local look = Vector3.new(lp.X, root.Position.Y, lp.Z)
						root.CFrame = CFrame.lookAt(root.Position, look)
						NoiseService.EmitWithSound(lp, 30, "LockerRip", "MetalScreech", nil, 1.4)
						task.wait(Config.Locker.RipOpenTime)
						if gen ~= generation then
							return
						end
						busy = false
						if p:GetAttribute("InLocker") == true then
							MovementService.ExitLocker(p, true)
						end
						startHunt(p)
					end)
					return true
				end
			end
		end
	end
	return false
end

----------------------------------------------------------------------
-- Zupacken
----------------------------------------------------------------------
local function tryGrab()
	if busy or grabbing then
		return
	end
	if not (aiState == "Hunt" or aiState == "Frenzy") then
		return
	end
	if now() - chaseStart < E.HuntGrabGrace then
		return
	end
	for _, p in candidates() do
		local r = Util.GetRoot(p)
		if r and p:GetAttribute("InLocker") ~= true then
			local d = (r.Position - root.Position).Magnitude
			if flatDist(r.Position, root.Position) <= E.GrabRange and d <= E.GrabRange + 4 then
				grabbing = true
				busy = true
				stop()
				setSpeed()
				root.CFrame = CFrame.lookAt(root.Position, Vector3.new(r.Position.X, root.Position.Y, r.Position.Z))
				model:SetAttribute("GrabAt", now())
				HealthService.Grab(p, model)
				local gen = generation
				task.delay(Config.Health.KillCinematicTime + 0.2, function()
					if gen ~= generation then
						return
					end
					grabbing = false
					busy = false
					memory[p] = nil
					if active then
						startRetreat()
					end
				end)
				return
			end
		end
	end
end

----------------------------------------------------------------------
-- Entscheidungen (10 Hz)
----------------------------------------------------------------------
local function bestPlayer(): (Player?, number)
	local best: Player? = nil
	local bestA = -1
	for p, m in memory do
		if m.Attention > bestA then
			best = p
			bestA = m.Attention
		end
	end
	return best, bestA
end

local function patrolStep()
	local t = now()
	if patrolGoal == nil then
		if t < patrolWaitUntil then
			return
		end
		local home = homeZone()
		local zone = currentZone()
		-- Spieler in einer anderen Zone: hinkommen (Pfad oder Schacht)
		if home and home ~= zone and (Zones.Index(home) >= 4 or pathFails >= 2) then
			local dest = ventFor(home, false)
			pathFails = 0
			if dest then
				ventTravel(dest, E.VentTravelTime, nil)
				return
			end
		end
		local list = waypointsIn(home or zone)
		if #list == 0 then
			list = waypointsIn(zone)
		end
		if #list == 0 then
			return
		end
		local pick: BasePart? = nil
		if t < nearPlayersUntil then
			-- Regisseur: Patrouille in die Nähe der Spieler lenken
			local bestD = math.huge
			for _, wp in list do
				local d = nearestPlayerDist(wp.Position)
				if d < bestD and wp ~= lastPatrolWp then
					bestD = d
					pick = wp
				end
			end
		elseif t < awayUntil then
			local bestD = -1
			for _, wp in list do
				local d = nearestPlayerDist(wp.Position)
				if d > bestD and wp ~= lastPatrolWp then
					bestD = d
					pick = wp
				end
			end
		else
			for _ = 1, 6 do
				local wp = list[math.random(1, #list)]
				if wp ~= lastPatrolWp then
					pick = wp
					break
				end
			end
		end
		pick = pick or list[1]
		lastPatrolWp = pick
		patrolGoal = (pick :: BasePart).Position
		pathGoal = nil
	end
	local goal = patrolGoal :: Vector3
	moveTowards(goal, 1)
	if arrived(goal, 4) then
		patrolGoal = nil
		patrolWaitUntil = t + E.PatrolWaitMin + math.random() * (E.PatrolWaitMax - E.PatrolWaitMin)
		stop()
		if math.random() < 0.4 then
			-- "schnuppert": metallisches Resonieren
			NoiseService.PlaySound("TuningFork", root.Position, 1, 1, 80)
		end
	elseif checkStuck() or (pathFails >= 1 and not computing and #waypoints == 0) then
		patrolGoal = nil
	end
end

local function decide(dt: number)
	if not active or busy or travelling or aiState == "Sleeping" or aiState == "Retreat" then
		setSpeed()
		return
	end
	local t = now()
	local best, bestA = bestPlayer()

	-- Raserei-Überlagerung
	if frenzyActive() then
		if aiState ~= "Attracted" and aiState ~= "Frenzy" then
			setAIState("Frenzy")
		end
	elseif aiState == "Frenzy" then
		startSearch(root.Position)
	end

	if tryRipLocker() then
		return
	end

	if aiState == "Attracted" then
		local part = attractedPart
		local beaconOk = attractedBeacon ~= nil and NoiseService.GetBeacon(attractedBeacon :: number) ~= nil
		if part == nil or not beaconOk or t > attractedUntil or part.Parent == nil then
			startSearch(if part then part.Position else root.Position)
		else
			-- Spieler mit Signatur über 40 in 20 Studs -> Jagd
			for _, p in candidates() do
				local r = Util.GetRoot(p)
				if r and Util.NumAttr(p, "HeatSig", 0) > E.AttractedBreakSig and (r.Position - root.Position).Magnitude <= E.AttractedBreakRange then
					startHunt(p)
					return
				end
			end
			attractedAngle += dt * 0.9
			local c = part.Position
			local goal = c + Vector3.new(math.cos(attractedAngle) * E.AttractedOrbitRadius, 0, math.sin(attractedAngle) * E.AttractedOrbitRadius)
			moveTowards(goal, 0.6, true)
		end
	elseif aiState == "Hunt" or (aiState == "Frenzy" and best ~= nil and bestA >= E.InvestigateThreshold) then
		local target = if aiState == "Hunt" then huntTarget else best
		if target == nil or memory[target] == nil then
			startSearch(root.Position)
		else
			if aiState == "Frenzy" and huntTarget ~= target then
				huntTarget = target
				chaseStart = t
				model:SetAttribute("TargetUserId", target.UserId)
			end
			local m = memOf(target)
			if t - m.LastContact > E.HuntLoseContact then
				if aiState == "Hunt" then
					startSearch(m.LastKnown or root.Position)
				else
					huntTarget = nil
					model:SetAttribute("TargetUserId", 0)
				end
			elseif aiState == "Hunt" and t - huntStart > E.HuntMaxDuration then
				startRetreat()
			else
				local r = Util.GetRoot(target)
				local goal = if m.Seen and r then r.Position else (m.LastKnown or root.Position)
				moveTowards(goal, E.HuntRepath, true)
				if checkStuck() then
					pathGoal = nil
				end
				tryGrab()
			end
		end
	elseif aiState == "Frenzy" then
		-- kein Ziel: zur Wärmequelle bzw. zu Raserei-Punkten der Zone
		if frenzyPoint == nil or arrived(frenzyPoint :: Vector3, 5) then
			local pts: { Vector3 } = {}
			local zone = currentZone()
			for _, fp in MapService.GetTaggedParts("FrenzyPoint") do
				if fp:GetAttribute("Zone") == zone then
					table.insert(pts, fp.Position)
				end
			end
			for _, wp in waypointsIn(zone) do
				table.insert(pts, wp.Position)
			end
			if frenzyFocus and math.random() < 0.5 then
				frenzyPoint = frenzyFocus
			elseif #pts > 0 then
				frenzyPoint = pts[math.random(1, #pts)]
			end
		end
		if frenzyPoint then
			moveTowards(frenzyPoint :: Vector3, 0.8)
			if checkStuck() then
				frenzyPoint = nil
			end
		end
		local home = homeZone()
		if home and home ~= currentZone() and Zones.Index(home) >= 4 then
			local dest = ventFor(home, false)
			if dest then
				ventTravel(dest, E.VentTravelTime, nil)
			end
		end
	elseif bestA >= E.HuntThreshold and best then
		startHunt(best)
	elseif aiState == "Investigate" then
		if best and bestA >= E.InvestigateThreshold then
			local m = memOf(best)
			if m.Seen then
				lastStimulus = t
			end
			if m.LastKnown and (investigatePos == nil or (m.LastKnown - (investigatePos :: Vector3)).Magnitude > 3) and t - m.LastContact < 1 then
				startInvestigate(m.LastKnown, best)
			end
		end
		local goal = investigatePos
		if goal == nil then
			startPatrol()
		elseif probeUntil > 0 then
			-- Luft abtasten
			if t > probeUntil then
				probeUntil = 0
				investigatePos = nil
			end
		elseif arrived(goal, 4) then
			stop()
			probeUntil = t + E.InvestigateProbeTime
			NoiseService.PlaySound("TuningFork", root.Position, 1.2, 1, 90)
		else
			moveTowards(goal, 0.6)
			if checkStuck() and pathFails >= 2 then
				investigatePos = nil
			end
		end
		if t - lastStimulus > E.InvestigateGiveUp and probeUntil == 0 then
			startPatrol()
		end
	elseif aiState == "Search" then
		if best and bestA >= E.InvestigateThreshold then
			local m = memOf(best)
			startInvestigate(m.LastKnown or root.Position, best)
		elseif t > searchUntil then
			startPatrol()
		else
			local center = searchCenter or root.Position
			if searchPoint == nil or arrived(searchPoint :: Vector3, 4) or checkStuck() then
				local a = math.random() * math.pi * 2
				local r = math.random() * E.SearchRadius
				searchPoint = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				pathGoal = nil
			end
			moveTowards(searchPoint :: Vector3, 0.8)
		end
	elseif aiState == "Patrol" then
		if best and bestA >= E.InvestigateThreshold then
			local m = memOf(best)
			startInvestigate(m.LastKnown or root.Position, best)
		else
			patrolStep()
		end
	end

	checkDoor()
	setSpeed()
end

----------------------------------------------------------------------
-- Spannungs-Regisseur
----------------------------------------------------------------------
local function directorTick(dt: number)
	if not active or busy or travelling or aiState == "Sleeping" then
		return
	end
	local _, bestA = bestPlayer()
	local chasing = aiState == "Hunt" or (aiState == "Frenzy" and huntTarget ~= nil)
	if chasing then
		pressure += dt
	else
		pressure = math.max(0, pressure - dt * 0.5)
	end
	if aiState == "Patrol" and bestA < E.InvestigateThreshold then
		calm += dt
	else
		calm = 0
	end
	-- > 60 s Dauerdruck: 30 s in einen entfernten Bereich schicken
	if pressure > E.DirectorPressureLimit and not frenzyActive() then
		pressure = 0
		huntTarget = nil
		model:SetAttribute("TargetUserId", 0)
		for _, m in memory do
			m.Attention = 0
		end
		local zone = homeZone() or currentZone()
		local dest = ventFor(zone, true)
		setAIState("Patrol")
		if dest then
			ventTravel(dest, E.VentTravelTime, function()
				awayUntil = now() + E.DirectorAwayTime
			end)
		else
			awayUntil = now() + E.DirectorAwayTime
		end
	end
	-- > 90 s Ruhe: Patrouille in die Nähe der Spieler lenken
	if calm > E.DirectorCalmLimit then
		calm = 0
		nearPlayersUntil = now() + 30
		patrolGoal = nil
		local home = homeZone()
		if home and home ~= currentZone() then
			local dest = ventFor(home, false)
			if dest then
				ventTravel(dest, E.VentTravelTime, nil)
			end
		end
	end
end

----------------------------------------------------------------------
-- Öffentliche Steuerung (RoundService, PuzzleService)
----------------------------------------------------------------------
function EntityService.GetModel(): Model
	return model
end

function EntityService.GetState(): string
	return aiState
end

function EntityService.SetPlayerCount(n: number)
	scale = E.Scaling[math.clamp(n, 1, 4)]
end

function EntityService.Reset()
	generation += 1
	active = false
	busy = false
	travelling = false
	grabbing = false
	table.clear(memory)
	table.clear(visitedFlares)
	table.clear(visitedBeacons)
	huntTarget = nil
	investigatePos = nil
	attractedPart = nil
	attractedBeacon = nil
	frenzyUntil = 0
	frenzyPermanent = false
	frenzyFocus = nil
	frenzyPoint = nil
	patrolGoal = nil
	pressure = 0
	calm = 0
	awayUntil = 0
	nearPlayersUntil = 0
	pathFails = 0
	model:SetAttribute("TargetUserId", 0)
	model:SetAttribute("InVent", false)
	setAIState("Sleeping")
	local spawn = MapService.GetTaggedParts("EntitySpawn")[1]
	root.Anchored = true
	if spawn then
		model:PivotTo(spawn.CFrame)
	end
	waypoints = {}
	hum.WalkSpeed = 0
end

-- Stromausfall: Das Wesen erwacht hörbar im Nest
function EntityService.Wake()
	if aiState ~= "Sleeping" then
		return
	end
	setAIState("Patrol")
	model:SetAttribute("WakeAt", now())
	busy = true
	local gen = generation
	task.delay(E.WakeRoarDelay, function()
		if gen ~= generation then
			return
		end
		NoiseService.PlaySound("MetalScreech", root.Position, 2, 0.7, 250)
		NoiseService.PlaySound("Infrasound", root.Position, 1.5, 1, 250)
		root.Anchored = false
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		busy = false
		active = true
		lastProgressPos = root.Position
		lastProgressTime = os.clock()
	end)
end

-- Raserei (Generator 60 s, Finale dauerhaft)
function EntityService.StartFrenzy(duration: number?, focus: Vector3?, permanent: boolean?)
	if aiState == "Sleeping" then
		EntityService.Wake()
	end
	if permanent then
		frenzyPermanent = true
	else
		frenzyUntil = math.max(frenzyUntil, now() + (duration or E.GeneratorFrenzyTime))
	end
	frenzyFocus = focus
	frenzyPoint = focus
	if focus then
		local fz = Zones.GetZoneAt(focus)
		if fz ~= currentZone() and model:GetAttribute("InVent") ~= true then
			local dest = ventFor(fz, false)
			if dest then
				ventTravel(dest, E.VentTravelTime, nil)
			end
		end
	end
end

function EntityService.StopFrenzy()
	frenzyPermanent = false
	frenzyUntil = 0
end

-- Finale: das Wesen kommt in die Reaktorhöhle (dauerhafte Raserei)
function EntityService.EnterZone(zone: string, delay: number?)
	local gen = generation
	task.delay(delay or 0, function()
		if gen ~= generation or not active or grabbing then
			return
		end
		if currentZone() == zone and model:GetAttribute("InVent") ~= true then
			return
		end
		local dest = ventFor(zone, true)
		if dest then
			busy = false
			ventTravel(dest, E.VentTravelTime, nil)
		end
	end)
end

function EntityService.IsActive(): boolean
	return active
end

----------------------------------------------------------------------
function EntityService.Init()
	model = Creature.Build()
	model:AddTag("Creature")
	root = model.PrimaryPart :: BasePart
	hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	head = model:FindFirstChild("Head") :: BasePart
	local spawn = MapService.GetTaggedParts("EntitySpawn")[1]
	root.Anchored = true
	model.Parent = Workspace
	if spawn then
		model:PivotTo(spawn.CFrame)
	end
	for _, st in { Enum.HumanoidStateType.Jumping, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Swimming, Enum.HumanoidStateType.Seated } do
		hum:SetStateEnabled(st, false)
	end
	path = PathfindingService:CreatePath({
		AgentRadius = E.AgentRadius,
		AgentHeight = E.AgentHeight,
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = E.WaypointSpacing,
		Costs = { Door = 2 },
	})
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.CollisionGroup = Config.CollisionGroups.ThermalRay
	rayParams.IgnoreWater = true
	NoiseService.Emitted:Connect(onNoise)
	-- Gelandete Fackel sofort auswerten (sonst spätestens im nächsten beaconTick)
	InventoryService.FlareLanded:Connect(function()
		task.defer(function()
			pcall(beaconTick)
		end)
	end)
end

function EntityService.Start()
	local senseAcc, decideAcc, beaconAcc = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt)
		if model.Parent == nil then
			return
		end
		senseAcc += dt
		decideAcc += dt
		beaconAcc += dt
		if senseAcc >= 1 / E.SenseRate then
			local step = senseAcc
			senseAcc = 0
			if active and aiState ~= "Sleeping" and model:GetAttribute("InVent") ~= true then
				Util.Try("EntityService sense", function()
					senseTick(step)
				end)
			end
		end
		if decideAcc >= 1 / E.DecisionRate then
			local step = decideAcc
			decideAcc = 0
			Util.Try("EntityService decide", function()
				decide(step)
			end)
			Util.Try("EntityService director", function()
				directorTick(step)
			end)
		end
		if beaconAcc >= E.BeaconRefresh then
			beaconAcc = 0
			Util.Try("EntityService beacons", function()
				beaconTick()
			end)
		end
	end)
end

return EntityService
