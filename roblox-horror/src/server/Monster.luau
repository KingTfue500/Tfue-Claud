-- "The Pale": a tall, thin creature that wanders the manor, hunts by sight and sound,
-- smashes doors open and catches anyone who gets too close.
-- The server only moves it; the limbs are animated on each client (see client/Animator).

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapBuilder = require(script.Parent.MapBuilder)

local M = Config.Monster
local LEG = 4.2

local Monster = {}
Monster.__index = Monster

local function flat(v: Vector3)
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

local function buildRig(): Model
	local model = Instance.new("Model")
	model.Name = "ThePale"

	local skin = Color3.fromRGB(196, 190, 180)
	local cloth = Color3.fromRGB(18, 16, 18)

	local function part(name: string, size: Vector3, color: Color3, material: Enum.Material?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.Massless = true
		p.Parent = model
		return p
	end

	local function joint(name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = c0
		m.C1 = c1
		m.Parent = p0
		p1.CFrame = p0.CFrame * c0 * c1:Inverse()
		return m
	end

	local function attach(p0: BasePart, p1: BasePart, offset: CFrame)
		p1.CFrame = p0.CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0 = p0
		w.Part1 = p1
		w.Parent = p1
	end

	local root = part("HumanoidRootPart", Vector3.new(2.4, 2, 1.4), cloth)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	root.RootPriority = 127
	root.CFrame = CFrame.new(0, LEG + 1, 0)

	local torso = part("Torso", Vector3.new(2.3, 3.6, 1.1), cloth, Enum.Material.Fabric)
	local head = part("Head", Vector3.new(1.5, 1.9, 1.5), skin)
	local lArm = part("LeftArm", Vector3.new(0.55, 5.4, 0.55), skin)
	local rArm = part("RightArm", Vector3.new(0.55, 5.4, 0.55), skin)
	local lLeg = part("LeftLeg", Vector3.new(0.7, LEG, 0.7), cloth, Enum.Material.Fabric)
	local rLeg = part("RightLeg", Vector3.new(0.7, LEG, 0.7), cloth, Enum.Material.Fabric)

	joint("Root", root, torso, CFrame.new(0, -1, 0), CFrame.new(0, -1.8, 0))
	joint("Neck", torso, head, CFrame.new(0, 1.8, -0.25), CFrame.new(0, -1.05, 0))
	joint("LeftShoulder", torso, lArm, CFrame.new(-1.45, 1.55, 0), CFrame.new(0, 2.45, 0))
	joint("RightShoulder", torso, rArm, CFrame.new(1.45, 1.55, 0), CFrame.new(0, 2.45, 0))
	joint("LeftHip", root, lLeg, CFrame.new(-0.55, -1, 0), CFrame.new(0, LEG / 2, 0))
	joint("RightHip", root, rLeg, CFrame.new(0.55, -1, 0), CFrame.new(0, LEG / 2, 0))

	-- face: glowing eyes and a long black mouth
	for _, sx in { -1, 1 } do
		local eye = part("Eye", Vector3.new(0.32, 0.2, 0.1), Color3.fromRGB(255, 20, 20), Enum.Material.Neon)
		attach(head, eye, CFrame.new(sx * 0.33, 0.25, -0.74))
		local socket = part("Socket", Vector3.new(0.5, 0.42, 0.06), Color3.new(0, 0, 0))
		attach(head, socket, CFrame.new(sx * 0.33, 0.25, -0.73))
	end
	local mouth = part("Mouth", Vector3.new(0.9, 0.7, 0.08), Color3.new(0, 0, 0))
	attach(head, mouth, CFrame.new(0, -0.5, -0.74))
	for i = -3, 3 do
		local tooth = part("Tooth", Vector3.new(0.08, 0.2, 0.06), Color3.fromRGB(230, 225, 200))
		attach(head, tooth, CFrame.new(i * 0.12, -0.25, -0.77) * CFrame.Angles(0, 0, math.pi))
	end
	-- claws
	for _, arm in { lArm, rArm } do
		for i = -1, 1 do
			local claw = part("Claw", Vector3.new(0.08, 1.1, 0.12), Color3.fromRGB(30, 25, 25))
			attach(arm, claw, CFrame.new(i * 0.17, -3.1, -0.1) * CFrame.Angles(0.35, 0, 0))
		end
	end
	-- tattered cloak strips
	for i = -2, 2 do
		local strip = part("Rag", Vector3.new(0.4, 2.4, 0.08), cloth, Enum.Material.Fabric)
		attach(torso, strip, CFrame.new(i * 0.45, -2.6, 0.5 + math.abs(i) * 0.05) * CFrame.Angles(0.15, 0, i * 0.08))
	end

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 30, 30)
	glow.Brightness = 1.2
	glow.Range = 12
	glow.Parent = head

	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 18
	smoke.Lifetime = NumberRange.new(1.5, 2.5)
	smoke.Speed = NumberRange.new(0.5, 1.5)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(5, 5, 8))
	smoke.LightInfluence = 1
	smoke.Parent = torso

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = LEG
	humanoid.WalkSpeed = M.WanderSpeed
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model
	for _, state in { Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Seated } do
		humanoid:SetStateEnabled(state, false)
	end

	model.PrimaryPart = root
	return model
end

local function sound(id: string, parent: Instance, volume: number, looped: boolean)
	if id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Looped = looped
	s.RollOffMaxDistance = 120
	s.RollOffMinDistance = 8
	s.Parent = parent
	return s
end

function Monster.new(map, onCatch: (Player) -> ())
	local self = setmetatable({}, Monster)
	self.map = map
	self.onCatch = onCatch
	self.model = buildRig()
	self.root = self.model.HumanoidRootPart
	self.head = self.model.Head
	self.humanoid = self.model.Humanoid
	self.model:PivotTo(map.monsterSpawn)
	self.model.Parent = workspace
	self.root:SetNetworkOwner(nil)

	self.path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 9,
		AgentCanJump = false,
		WaypointSpacing = 4,
	})
	self.alive = true
	self.attacking = false
	self.state = "Sleeping"
	self.lastSeen = 0
	self.lastTargetSeen = os.clock()
	self.lastMoveCheck = os.clock()
	self.lastMovePos = self.root.Position
	self.growl = sound(Config.Sounds.MonsterGrowl, self.head, 1, true)
	self.scream = sound(Config.Sounds.MonsterScream, self.head, 2, false)
	self:setState("Sleeping")
	return self
end

function Monster:setState(state: string)
	self.state = state
	self.model:SetAttribute("State", state)
	if state == "Chase" then
		self.humanoid.WalkSpeed = M.ChaseSpeed
	elseif state == "Search" then
		self.humanoid.WalkSpeed = M.SearchSpeed
	elseif state == "Wander" then
		self.humanoid.WalkSpeed = M.WanderSpeed
	else
		self.humanoid.WalkSpeed = 0
	end
end

function Monster:wake()
	if not self.alive then
		return
	end
	self:setState("Wander")
	if self.scream then
		self.scream:Play()
	end
	if self.growl then
		self.growl:Play()
	end
	task.spawn(function()
		while self.alive do
			local ok, err = pcall(self.think, self)
			if not ok then
				warn("[Monster] " .. tostring(err))
			end
			task.wait(0.1)
		end
	end)
end

function Monster:destroy()
	self.alive = false
	self.model:Destroy()
end

-- Something made a noise here (a key was picked up, a door slammed...).
function Monster:alert(position: Vector3)
	if self.state ~= "Chase" and self.state ~= "Sleeping" then
		self.lastKnown = position
		self.lastSeen = os.clock()
	end
end

function Monster:canSee(target: Vector3): boolean
	local origin = self.head.Position
	local ignore = { self.model }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return workspace:Raycast(origin, target - origin, params) == nil
end

function Monster:findTarget()
	local myPos = self.root.Position
	local look = self.root.CFrame.LookVector
	local best, bestRoot, bestDist, bestVisible = nil, nil, math.huge, false
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if player:GetAttribute("InRound") and hum and hum.Health > 0 and hrp then
			local offset = hrp.Position - myPos
			local dist = offset.Magnitude
			local lit = char:GetAttribute("Flashlight")
			local range = lit and M.SightRangeLit or M.SightRangeDark
			local visible = false
			if dist < range then
				local dir = Vector3.new(offset.X, 0, offset.Z).Unit
				local inView = dist < 12 or math.deg(math.acos(math.clamp(dir:Dot(look), -1, 1))) <= M.FieldOfView
				-- you can't hide from it while you're within arm's reach and in plain sight
				visible = inView and self:canSee(hrp.Position)
			end
			local heard = char:GetAttribute("Sprinting") and dist < M.HearRange
			local felt = dist < 7
			if (visible or heard or felt) and dist < bestDist then
				best, bestRoot, bestDist, bestVisible = player, hrp, dist, visible
			end
		end
	end
	return best, bestRoot, bestDist, bestVisible
end

function Monster:moveTo(goal: Vector3, direct: boolean?)
	if direct then
		self.waypoints = nil
		self.humanoid:MoveTo(goal)
		return
	end
	local now = os.clock()
	if not self.pathGoal or now - (self.pathTime or 0) > 0.6 or (self.pathGoal - goal).Magnitude > 5 then
		self.pathTime = now
		self.pathGoal = goal
		local ok = pcall(self.path.ComputeAsync, self.path, self.root.Position, goal)
		if ok and self.path.Status == Enum.PathStatus.Success then
			self.waypoints = self.path:GetWaypoints()
			self.wpIndex = 2
		else
			self.waypoints = nil
		end
	end
	local wps = self.waypoints
	if wps and #wps >= 2 then
		local pos = self.root.Position
		while self.wpIndex < #wps and flat(wps[self.wpIndex].Position - pos) < 3.5 do
			self.wpIndex += 1
		end
		self.humanoid:MoveTo(wps[math.min(self.wpIndex, #wps)].Position)
	else
		self.humanoid:MoveTo(goal)
	end
end

function Monster:smashDoors()
	for _, door in self.map.doors do
		if not door.isOpen and (door.panel.Position - self.root.Position).Magnitude < 7.5 then
			MapBuilder.setDoor(door, true, true)
			self.map.onDoorSmashed(door)
		end
	end
end

function Monster:pickWanderGoal()
	local now = os.clock()
	local points = self.map.patrolPoints
	local goal = points[math.random(1, #points)]
	-- If nobody has been seen for a while it drifts toward the closest survivor.
	if now - self.lastTargetSeen > 40 then
		local closest, closestDist = nil, math.huge
		for _, player in Players:GetPlayers() do
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if player:GetAttribute("InRound") and hrp then
				local d = (hrp.Position - self.root.Position).Magnitude
				if d < closestDist then
					closest, closestDist = hrp.Position, d
				end
			end
		end
		if closest then
			goal = closest + Vector3.new(math.random(-14, 14), 0, math.random(-14, 14))
		end
	end
	self.wanderGoal = goal
	self.wanderUntil = now + 25
end

function Monster:catch(player: Player, targetRoot: BasePart)
	self.attacking = true
	self:setState("Attack")
	self.humanoid:MoveTo(self.root.Position)
	local p = self.root.Position
	self.root.CFrame = CFrame.lookAt(p, Vector3.new(targetRoot.Position.X, p.Y, targetRoot.Position.Z))
	if self.onCatch then
		task.spawn(self.onCatch, player)
	end
	task.delay(2.8, function()
		if self.alive then
			self.attacking = false
			self.lastKnown = nil
			self.model:SetAttribute("TargetId", 0)
			self:setState("Wander")
		end
	end)
end

function Monster:think()
	if self.attacking or self.state == "Sleeping" then
		return
	end
	local now = os.clock()
	local target, targetRoot, dist, visible = self:findTarget()

	if target then
		if self.state ~= "Chase" and self.scream then
			self.scream:Play()
		end
		self:setState("Chase")
		self.model:SetAttribute("TargetId", target.UserId)
		self.lastKnown = targetRoot.Position
		self.lastSeen = now
		self.lastTargetSeen = now
		if dist <= M.KillRange and math.abs(targetRoot.Position.Y - self.root.Position.Y) < 7 then
			self:catch(target, targetRoot)
			return
		end
		self:moveTo(targetRoot.Position, visible and dist < 16)
	elseif self.lastKnown and now - self.lastSeen < M.SearchTime then
		self:setState("Search")
		self.model:SetAttribute("TargetId", 0)
		self:moveTo(self.lastKnown)
		if flat(self.lastKnown - self.root.Position) < 4 then
			self.lastKnown = nil
		end
	else
		if self.state ~= "Wander" then
			self:setState("Wander")
			self.wanderGoal = nil
		end
		self.model:SetAttribute("TargetId", 0)
		if not self.wanderGoal or flat(self.wanderGoal - self.root.Position) < 5 or now > self.wanderUntil then
			self:pickWanderGoal()
		end
		self:moveTo(self.wanderGoal)
	end

	self:smashDoors()

	-- unstick itself if it hasn't moved in a while
	if now - self.lastMoveCheck > 2.5 then
		if flat(self.root.Position - self.lastMovePos) < 1.5 then
			self.wanderGoal = nil
			self.pathGoal = nil
			local nudge = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
			self.humanoid:MoveTo(self.root.Position + nudge)
		end
		self.lastMoveCheck = now
		self.lastMovePos = self.root.Position
	end
end

return Monster
