--!strict
-- MovementService: Haltung (Stehen/Ducken/Liegen/am Boden), Sprint und Stamina, Atem anhalten,
-- Schrittgeräusche je Untergrund, Versteck-Spinde und eine einfache Tempo-Prüfung (Abschnitt 4).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Surface = require(ReplicatedStorage.Shared.Surface)
local Util = require(ReplicatedStorage.Shared.Util)
local MapService = require(script.Parent.MapService)
local NoiseService = require(script.Parent.NoiseService)

local MovementService = {}
MovementService.Name = "MovementService"

type MoveState = {
	Stance: string,
	TransitionEnd: number,
	SprintWanted: boolean,
	Sprinting: boolean,
	Stamina: number,
	LastSprint: number,
	PantUntil: number,
	Breath: number,
	Holding: boolean,
	StepTimer: number,
	Locker: Model?,
	LastPos: Vector3?,
	LastValidCF: CFrame?,
	OverSpeed: number,
	GraceUntil: number,
}

local states: { [Player]: MoveState } = {}
local baseHip: { [Player]: number } = {}
local lockerOccupant: { [Model]: Player } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function newState(): MoveState
	return {
		Stance = "Stand",
		TransitionEnd = 0,
		SprintWanted = false,
		Sprinting = false,
		Stamina = Config.Stamina.Max,
		LastSprint = 0,
		PantUntil = 0,
		Breath = Config.Breath.Max,
		Holding = false,
		StepTimer = 0,
		Locker = nil,
		LastPos = nil,
		LastValidCF = nil,
		OverSpeed = 0,
		GraceUntil = 0,
	}
end

local function getState(player: Player): MoveState
	local s = states[player]
	if s == nil then
		s = newState()
		states[player] = s
	end
	return s
end

local function canAct(player: Player): boolean
	local st = Util.GetState(player)
	return st == "Lobby" or st == "Alive"
end

local function carryingDiesel(player: Player): boolean
	for i = 1, Config.Items.BeltSlots do
		if player:GetAttribute("Slot" .. i) == "Diesel" then
			return true
		end
	end
	return false
end

local function hypoSlowed(player: Player): boolean
	local stage = Util.StrAttr(player, "HypoStage", "Normal")
	return stage == "Moderate" or stage == "Severe"
end

local function publish(player: Player, s: MoveState)
	player:SetAttribute("Stance", s.Stance)
	player:SetAttribute("Sprinting", s.Sprinting)
	player:SetAttribute("Stamina", math.floor(s.Stamina + 0.5))
	player:SetAttribute("Breath", math.floor(s.Breath + 0.5))
	player:SetAttribute("HoldingBreath", s.Holding)
	player:SetAttribute("Panting", s.PantUntil > now())
end

local function applyHumanoid(player: Player, s: MoveState)
	local hum = Util.GetHumanoid(player)
	if hum == nil then
		return
	end
	local t = now()
	local speed: number
	if s.Locker ~= nil or t < s.TransitionEnd or not (canAct(player) or Util.GetState(player) == "Downed") then
		speed = 0
	elseif s.Stance == "Downed" then
		speed = Config.Movement.Speed.Downed
	elseif s.Stance == "Prone" then
		speed = Config.Movement.Speed.Prone
	elseif s.Stance == "Crouch" then
		speed = Config.Movement.Speed.Crouch
	elseif s.Sprinting then
		speed = Config.Movement.Speed.Sprint
	else
		speed = Config.Movement.Speed.Walk
		if Util.StrAttr(player, "Clothing", "Parka") == "Overall" then
			speed *= Config.Movement.OverallSpeedFactor
		end
	end
	if s.Stance ~= "Downed" then
		if hypoSlowed(player) then
			speed *= Config.Hypo.ModerateSpeedFactor
		end
		if carryingDiesel(player) then
			speed *= Config.Movement.DieselSpeedFactor
		end
	end
	if math.abs(hum.WalkSpeed - speed) > 0.01 then
		hum.WalkSpeed = speed
	end
	local hip = (baseHip[player] or 2) * (Config.Movement.HipHeightFactor[s.Stance] or 1)
	if math.abs(hum.HipHeight - hip) > 0.01 then
		hum.HipHeight = hip
	end
end

----------------------------------------------------------------------
-- Öffentliche Funktionen
----------------------------------------------------------------------
function MovementService.SetStance(player: Player, stance: string, instant: boolean?)
	local s = getState(player)
	if s.Stance == stance then
		return
	end
	local t = now()
	if not instant then
		local dur = 0
		if stance == "Prone" then
			dur = Config.Movement.ProneDownTime
		elseif s.Stance == "Prone" then
			dur = Config.Movement.ProneUpTime
		else
			dur = Config.Movement.CrouchTime
		end
		s.TransitionEnd = t + dur
	else
		s.TransitionEnd = 0
	end
	local wasProne = s.Stance == "Prone"
	s.Stance = stance
	if stance == "Prone" then
		-- automatisch Atem anhalten
		s.Holding = s.Breath > 5
	elseif wasProne then
		s.Holding = false
	end
	if stance ~= "Stand" then
		s.Sprinting = false
	end
	publish(player, s)
	applyHumanoid(player, s)
end

function MovementService.GetStance(player: Player): string
	return getState(player).Stance
end

function MovementService.ResetPlayer(player: Player)
	local s = newState()
	states[player] = s
	publish(player, s)
	applyHumanoid(player, s)
end

function MovementService.RefreshSpeed(player: Player)
	applyHumanoid(player, getState(player))
end

-- Teleport ohne Tempo-Prüfung-Fehlalarm
function MovementService.Teleport(player: Player, cf: CFrame)
	local s = getState(player)
	s.GraceUntil = now() + 2
	s.LastPos = nil
	local char = Util.GetCharacter(player)
	if char then
		char:PivotTo(cf)
	end
	s.LastValidCF = cf
end

----------------------------------------------------------------------
-- Versteck-Spinde
----------------------------------------------------------------------
local function lockerDoor(locker: Model): BasePart?
	return MapService.FindPart(locker, "Door")
end

local function swingDoor(locker: Model, holdOpen: number)
	local door = lockerDoor(locker)
	if door == nil then
		return
	end
	local openCF = door:GetAttribute("OpenCF")
	local closedCF = door:GetAttribute("ClosedCF")
	if typeof(openCF) ~= "CFrame" or typeof(closedCF) ~= "CFrame" then
		return
	end
	local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(door, info, { CFrame = openCF }):Play()
	task.delay(holdOpen, function()
		if door.Parent then
			TweenService:Create(door, info, { CFrame = closedCF }):Play()
		end
	end)
end

function MovementService.GetLocker(player: Player): Model?
	return getState(player).Locker
end

function MovementService.EnterLocker(player: Player, locker: Model)
	local s = getState(player)
	if not canAct(player) or s.Locker or lockerOccupant[locker] then
		return
	end
	if s.Stance == "Downed" then
		return
	end
	local inside = MapService.FindPart(locker, "Inside")
	local root = Util.GetRoot(player)
	if inside == nil or root == nil then
		return
	end
	if (root.Position - inside.Position).Magnitude > 10 then
		return
	end
	lockerOccupant[locker] = player
	s.Locker = locker
	MovementService.SetStance(player, "Stand", true)
	s.Sprinting = false
	swingDoor(locker, 0.5)
	task.delay(Config.Locker.EnterHold, function()
		if s.Locker == locker and root.Parent then
			root.Anchored = true
			MovementService.Teleport(player, inside.CFrame)
		end
	end)
	player:SetAttribute("InLocker", true)
	player:SetAttribute("LockerName", locker.Name)
	NoiseService.Emit(root.Position, 4, "Locker", player)
	applyHumanoid(player, s)
end

function MovementService.ExitLocker(player: Player, flung: boolean?)
	local s = getState(player)
	local locker = s.Locker
	if locker == nil then
		return
	end
	lockerOccupant[locker] = nil
	s.Locker = nil
	player:SetAttribute("InLocker", false)
	player:SetAttribute("LockerName", "")
	local root = Util.GetRoot(player)
	local outside = MapService.FindPart(locker, "Outside")
	if flung then
		-- Das Wesen reißt den Spind auf: Tür fliegt auf und bleibt offen
		local door = lockerDoor(locker)
		local openCF = if door then door:GetAttribute("OpenCF") else nil
		if door and typeof(openCF) == "CFrame" then
			TweenService:Create(door, TweenInfo.new(0.15, Enum.EasingStyle.Back), { CFrame = openCF }):Play()
			task.delay(4, function()
				local closedCF = door:GetAttribute("ClosedCF")
				if door.Parent and typeof(closedCF) == "CFrame" then
					TweenService:Create(door, TweenInfo.new(0.4), { CFrame = closedCF }):Play()
				end
			end)
		end
	else
		swingDoor(locker, 0.5)
	end
	if root then
		root.Anchored = false
		if outside then
			MovementService.Teleport(player, outside.CFrame)
		end
	end
	applyHumanoid(player, s)
end

function MovementService.GetLockerOccupant(locker: Model): Player?
	return lockerOccupant[locker]
end

local function setupLockers()
	for _, locker in MapService.GetTaggedModels("HideLocker") do
		local interact = MapService.FindPart(locker, "Interact")
		if interact then
			local prompt = MapService.MakePrompt(interact, { Name = "HidePrompt", ActionText = "Hide", ObjectText = "Locker", HoldDuration = Config.Locker.EnterHold, MaxDistance = 6 })
			prompt.Triggered:Connect(function(player: Player)
				local s = getState(player)
				if s.Locker == locker then
					MovementService.ExitLocker(player)
				else
					MovementService.EnterLocker(player, locker)
				end
			end)
		end
	end
end

----------------------------------------------------------------------
-- Charakter-Einrichtung
----------------------------------------------------------------------
local function setGroup(part: BasePart, char: Model)
	if part.Name == "HumanoidRootPart" and part.Parent == char then
		part.CollisionGroup = Config.CollisionGroups.Players
	else
		part.CollisionGroup = Config.CollisionGroups.Limbs
	end
end

local function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum == nil or not hum:IsA("Humanoid") then
		return
	end
	hum.BreakJointsOnDeath = false
	hum.UseJumpPower = false
	hum.JumpHeight = 0
	hum.AutoJumpEnabled = false
	hum.WalkSpeed = Config.Movement.Speed.Walk
	-- Original-HipHeight des Avatars merken (R15 berechnet sie je nach Beinlänge)
	baseHip[player] = if hum.HipHeight > 0.2 then hum.HipHeight else 2
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") then
			setGroup(d, char)
		end
	end
	char.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			setGroup(d, char)
		end
	end)
	local s = getState(player)
	s.Locker = nil
	s.LastPos = nil
	s.GraceUntil = now() + 3
	player:SetAttribute("InLocker", false)
	applyHumanoid(player, s)
end

----------------------------------------------------------------------
-- Takt (10 Hz)
----------------------------------------------------------------------
local function tick(player: Player, s: MoveState, dt: number)
	local t = now()
	local root = Util.GetRoot(player)
	local hum = Util.GetHumanoid(player)
	if root == nil or hum == nil then
		return
	end
	local state = Util.GetState(player)
	local v = root.AssemblyLinearVelocity
	local hspeed = Vector3.new(v.X, 0, v.Z).Magnitude
	local moving = hspeed > 1 and hum.MoveDirection.Magnitude > 0.05
	local SC = Config.Stamina

	-- Sprint
	local canSprint = canAct(player)
		and s.Locker == nil
		and s.Stance == "Stand"
		and t >= s.TransitionEnd
		and Util.StrAttr(player, "HypoStage", "Normal") ~= "Severe"
		and not carryingDiesel(player)
	if s.Sprinting then
		if not (canSprint and s.SprintWanted and s.Stamina > 0) then
			s.Sprinting = false
		end
	elseif canSprint and s.SprintWanted and s.Stamina >= SC.MinToStartSprint and moving then
		s.Sprinting = true
	end

	-- Stamina
	if s.Sprinting and moving then
		local cost = SC.SprintCost
		if Util.StrAttr(player, "Clothing", "Parka") == "Parka" then
			cost *= SC.ParkaSprintCostFactor
		end
		s.Stamina -= cost * dt
		s.LastSprint = t
		if s.Stamina <= 0 then
			s.Stamina = 0
			s.Sprinting = false
			s.PantUntil = t + SC.PantDuration
			NoiseService.Emit(root.Position, SC.PantNoiseRadius, "Pant", player)
		end
	elseif t - s.LastSprint >= SC.RegenDelay then
		local rate = SC.RegenRate
		if hypoSlowed(player) then
			rate *= Config.Hypo.ModerateStaminaRegenFactor
		end
		s.Stamina = math.min(SC.Max, s.Stamina + rate * dt)
	end

	-- Atem (nur liegend angehalten)
	local BC = Config.Breath
	if s.Stance == "Prone" and state ~= "Downed" then
		if s.Holding then
			s.Breath -= BC.Max / BC.HoldDuration * dt
			if s.Breath <= 0 then
				s.Breath = 0
				s.Holding = false
				player:SetAttribute("GaspAt", t)
				NoiseService.Emit(root.Position, BC.GaspNoiseRadius, "Gasp", player)
			end
		else
			s.Breath = math.min(BC.Max, s.Breath + BC.Max / BC.RefillDuration * dt)
			if s.Breath >= BC.Max then
				s.Holding = true
			end
		end
	else
		s.Holding = false
		s.Breath = math.min(BC.Max, s.Breath + BC.Max / BC.RefillDuration * dt)
	end

	-- Schritte als Geräusch-Ereignisse
	if moving and s.Locker == nil then
		local key = if s.Stance == "Downed" then "Downed" elseif s.Stance ~= "Stand" then s.Stance elseif s.Sprinting then "Sprint" else "Walk"
		s.StepTimer += dt
		local interval = Config.Movement.StepInterval[key] or 0.5
		if s.StepTimer >= interval then
			s.StepTimer = 0
			local radius = Config.Movement.NoiseRadius[key] or 0
			if radius > 0 then
				local char = Util.GetCharacter(player)
				local surface = Surface.Below(root.Position, if char then { char } else {})
				if surface == "Grate" then
					radius *= Config.Movement.GrateNoiseFactor
				elseif surface == "Snow" then
					radius *= Config.Movement.SnowNoiseFactor
				end
				NoiseService.Emit(root.Position, radius, "Step" .. key, player, Config.Entity.AttentionStep[key] or 0)
			end
		end
	else
		s.StepTimer = 0
	end

	-- Tempo-Prüfung (horizontal)
	if s.Locker == nil and not root.Anchored then
		local pos = root.Position
		if s.LastPos and t > s.GraceUntil then
			local d = Vector3.new(pos.X - s.LastPos.X, 0, pos.Z - s.LastPos.Z).Magnitude
			local allowed = (hum.WalkSpeed * Config.Movement.SpeedCheckTolerance + 2) * dt
			if d > allowed then
				s.OverSpeed += dt
				if s.OverSpeed > Config.Movement.SpeedCheckGrace and s.LastValidCF then
					MovementService.Teleport(player, s.LastValidCF)
					s.OverSpeed = 0
				end
			else
				s.OverSpeed = math.max(0, s.OverSpeed - dt)
				if s.OverSpeed == 0 then
					s.LastValidCF = root.CFrame
				end
			end
		end
		s.LastPos = pos
	end

	publish(player, s)
	applyHumanoid(player, s)
end

function MovementService.Init()
	setupLockers()
end

function MovementService.Start()
	local reqStance = Net.Event("RequestStance")
	reqStance.OnServerEvent:Connect(function(player: Player, stance: unknown)
		if type(stance) ~= "string" then
			return
		end
		if stance ~= "Stand" and stance ~= "Crouch" and stance ~= "Prone" then
			return
		end
		local s = getState(player)
		if not canAct(player) or s.Locker ~= nil or s.Stance == "Downed" then
			return
		end
		if now() < s.TransitionEnd then
			return
		end
		MovementService.SetStance(player, stance)
	end)
	Net.Event("RequestSprint").OnServerEvent:Connect(function(player: Player, wanted: unknown)
		if type(wanted) ~= "boolean" then
			return
		end
		getState(player).SprintWanted = wanted
	end)
	Net.Event("ExitLocker").OnServerEvent:Connect(function(player: Player)
		MovementService.ExitLocker(player)
	end)
	Net.Unreliable("LookDir").OnServerEvent:Connect(function(player: Player, pitch: unknown)
		if type(pitch) ~= "number" or pitch ~= pitch then
			return
		end
		local char = Util.GetCharacter(player)
		if char then
			local p = math.clamp(math.floor(pitch / 2 + 0.5) * 2, -80, 80)
			if char:GetAttribute("LookPitch") ~= p then
				char:SetAttribute("LookPitch", p)
			end
		end
	end)

	local function onPlayer(player: Player)
		states[player] = newState()
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
		publish(player, getState(player))
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		local s = states[player]
		if s and s.Locker then
			lockerOccupant[s.Locker] = nil
		end
		states[player] = nil
		baseHip[player] = nil
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		local step = acc
		acc = 0
		for player, s in states do
			if player.Parent then
				Util.Try("MovementService", function()
					tick(player, s, step)
				end)
			end
		end
	end)
end

return MovementService
