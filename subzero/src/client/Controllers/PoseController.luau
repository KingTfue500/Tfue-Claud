--!strict
-- PoseController (Abschnitt 10.2/10.3), nur lokal berechnet:
--   Spieler: Haltung (Ducken, Liegen, am Boden), schwere Fortbewegung (RootJoint neigt sich je nach
--   Tempo bis 8° nach vorn und in Kurven zur Seite), Frieren (Zittern, Arme reiben ab "Leicht"),
--   IKControl für Kopf-Blickrichtung und den Arm mit Lampe/Fackel.
--   Wesen: langsames Pendeln (Sinus), zufällige Zuckungen einzelner Gelenke um 10-20° alle 0,5-3 s,
--   Kopf tastet in der Luft, bei der Jagd vorgebeugt und ruckartig, Arm hebt beim Zupacken.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local PoseController = {}
PoseController.Name = "PoseController"

local player = Players.LocalPlayer
local rad = math.rad

type Rig = {
	Joints: { [string]: Motor6D },
	Base: { [Motor6D]: CFrame },
	Current: { [Motor6D]: CFrame },
	LookTarget: Attachment?,
	ArmTarget: Attachment?,
	LookIK: IKControl?,
	ArmIK: IKControl?,
	Lean: number,
	Side: number,
	LastYaw: number,
}

local rigs: { [Model]: Rig } = {}

local JOINT_PARTS: { [string]: string } = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	LeftHip = "LeftUpperLeg",
	RightHip = "RightUpperLeg",
	LeftKnee = "LeftLowerLeg",
	RightKnee = "RightLowerLeg",
	LeftShoulder = "LeftUpperArm",
	RightShoulder = "RightUpperArm",
	LeftElbow = "LeftLowerArm",
	RightElbow = "RightLowerArm",
}

local function buildRig(char: Model): Rig?
	local joints: { [string]: Motor6D } = {}
	local base: { [Motor6D]: CFrame } = {}
	for jointName, partName in JOINT_PARTS do
		local part = char:FindFirstChild(partName)
		local m = if part then part:FindFirstChild(jointName) else nil
		if m and m:IsA("Motor6D") then
			joints[jointName] = m
			base[m] = m.C0
		end
	end
	if not joints.Root then
		return nil
	end
	local rig: Rig = {
		Joints = joints,
		Base = base,
		Current = {},
		LookTarget = nil,
		ArmTarget = nil,
		LookIK = nil,
		ArmIK = nil,
		Lean = 0,
		Side = 0,
		LastYaw = 0,
	}
	-- IKControl: Kopf blickt in Blickrichtung, rechter Arm zielt mit Lampe/Fackel
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	local head = char:FindFirstChild("Head")
	local upper = char:FindFirstChild("UpperTorso")
	local rua = char:FindFirstChild("RightUpperArm")
	local rhand = char:FindFirstChild("RightHand")
	if hum and root and root:IsA("BasePart") and head and upper and rua and rhand then
		local lt = Instance.new("Attachment")
		lt.Name = "SZLookTarget"
		lt.Parent = root
		local look = Instance.new("IKControl")
		look.Name = "SZLook"
		look.Type = Enum.IKControlType.LookAt
		look.ChainRoot = upper :: Instance
		look.EndEffector = head :: Instance
		look.Target = lt
		look.Weight = 0.8
		look.Parent = hum
		local at = Instance.new("Attachment")
		at.Name = "SZArmTarget"
		at.Parent = root
		local arm = Instance.new("IKControl")
		arm.Name = "SZArm"
		arm.Type = Enum.IKControlType.Position
		arm.ChainRoot = rua :: Instance
		arm.EndEffector = rhand :: Instance
		arm.Target = at
		arm.Weight = 0
		arm.Parent = hum
		rig.LookTarget = lt
		rig.ArmTarget = at
		rig.LookIK = look
		rig.ArmIK = arm
	end
	return rig
end

local function setJoint(rig: Rig, name: string, offset: CFrame, alpha: number)
	local m = rig.Joints[name]
	if not m then
		return
	end
	local target = rig.Base[m] * offset
	local cur = rig.Current[m] or rig.Base[m]
	local nextCF = cur:Lerp(target, math.clamp(alpha, 0, 1))
	rig.Current[m] = nextCF
	m.C0 = nextCF
end

----------------------------------------------------------------------
-- Spieler
----------------------------------------------------------------------
local function poseCharacter(p: Player, char: Model, rig: Rig, dt: number)
	local root = char:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local a = math.min(1, dt * 10)
	local stance = Util.StrAttr(p, "Stance", "Stand")
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local t = os.clock()

	-- Vorneigung nach Tempo (bis 8°) und Seitneigung in Kurven
	local _, yaw, _ = root.CFrame:ToOrientation()
	local dyaw = yaw - rig.LastYaw
	if dyaw > math.pi then
		dyaw -= 2 * math.pi
	elseif dyaw < -math.pi then
		dyaw += 2 * math.pi
	end
	rig.LastYaw = yaw
	local leanTarget = math.clamp(speed / Config.Movement.Speed.Sprint, 0, 1) * Config.Movement.LeanMaxDeg
	rig.Lean += (leanTarget - rig.Lean) * math.min(1, dt * 5)
	local sideTarget = math.clamp(-dyaw / math.max(dt, 1 / 240) * 2, -Config.Movement.LeanMaxDeg, Config.Movement.LeanMaxDeg) * math.clamp(speed / 10, 0, 1)
	rig.Side += (sideTarget - rig.Side) * math.min(1, dt * 4)

	-- Frieren: Zittern, ab "Leicht" stärker
	local stage = Util.StrAttr(p, "HypoStage", "Normal")
	local shiver = if stage == "Mild" then 1 elseif stage == "Moderate" then 2 elseif stage == "Severe" then 3 else 0
	local sh = if shiver > 0 then math.noise(t * 22, char:GetAttribute("Seed") :: number? or 0) * rad(1.2 * shiver) else 0

	local pitch = Util.NumAttr(char, "LookPitch", 0)

	if stance == "Prone" or stance == "Downed" then
		-- flach auf den Bauch, Kopf hebt sich leicht, Arme nach vorn
		setJoint(rig, "Root", CFrame.Angles(rad(-88), 0, 0), a)
		setJoint(rig, "Waist", CFrame.Angles(rad(-2), 0, sh), a)
		setJoint(rig, "Neck", CFrame.Angles(rad(50), 0, 0), a)
		local crawl = if speed > 0.3 then math.sin(t * 6) * rad(25) else 0
		setJoint(rig, "LeftShoulder", CFrame.Angles(rad(150) + crawl, 0, 0), a)
		setJoint(rig, "RightShoulder", CFrame.Angles(rad(150) - crawl, 0, 0), a)
		setJoint(rig, "LeftHip", CFrame.Angles(crawl * 0.5, 0, 0), a)
		setJoint(rig, "RightHip", CFrame.Angles(-crawl * 0.5, 0, 0), a)
		setJoint(rig, "LeftKnee", CFrame.new(), a)
		setJoint(rig, "RightKnee", CFrame.new(), a)
		if rig.LookIK then
			rig.LookIK.Weight = 0
		end
		if rig.ArmIK then
			rig.ArmIK.Weight = 0
		end
		return
	end
	local crouch = stance == "Crouch"
	setJoint(rig, "Root", CFrame.Angles(rad(-(rig.Lean + (if crouch then 18 else 0))), 0, rad(rig.Side)), a)
	setJoint(rig, "Waist", CFrame.Angles(sh, 0, sh * 0.5), a)
	setJoint(rig, "Neck", CFrame.new(), a)
	setJoint(rig, "LeftHip", CFrame.Angles(rad(if crouch then 55 else 0), 0, 0), a)
	setJoint(rig, "RightHip", CFrame.Angles(rad(if crouch then 55 else 0), 0, 0), a)
	setJoint(rig, "LeftKnee", CFrame.Angles(rad(if crouch then -95 else 0), 0, 0), a)
	setJoint(rig, "RightKnee", CFrame.Angles(rad(if crouch then -95 else 0), 0, 0), a)
	-- Arme reiben bei Kälte im Stand
	if shiver >= 1 and speed < 1 then
		local rub = math.sin(t * 9) * rad(8)
		setJoint(rig, "LeftShoulder", CFrame.Angles(rad(45), rad(-35) + rub, 0), a)
		setJoint(rig, "RightShoulder", CFrame.Angles(rad(45), rad(35) - rub, 0), a)
	else
		setJoint(rig, "LeftShoulder", CFrame.new(), a)
		setJoint(rig, "RightShoulder", CFrame.new(), a)
	end

	-- IK: Kopf folgt dem Blick; Arm hebt Lampe oder brennende Fackel
	local look = rig.LookTarget
	if look and rig.LookIK then
		local dir = (root.CFrame * CFrame.Angles(rad(pitch), 0, 0)).LookVector
		look.WorldPosition = root.Position + Vector3.new(0, 1.5, 0) + dir * 10
		rig.LookIK.Weight = 0.8
	end
	local arm = rig.ArmTarget
	if arm and rig.ArmIK then
		local holding = p:GetAttribute("FlareLit") == true or p:GetAttribute("FlashlightOn") == true
		local dir = (root.CFrame * CFrame.Angles(rad(pitch * 0.7), 0, 0)).LookVector
		arm.WorldPosition = root.Position + Vector3.new(0, 1.2, 0) + root.CFrame.RightVector * 0.8 + dir * 2.2
		local w = rig.ArmIK.Weight
		rig.ArmIK.Weight = w + ((if holding then 1 else 0) - w) * math.min(1, dt * 6)
	end
	-- Lichtkegel der Lampe folgt dem Blick anderer Spieler
	local head = char:FindFirstChild("Head")
	local lamp = if head then head:FindFirstChild("LampAttachment") else nil
	if lamp and lamp:IsA("Attachment") and head and head:IsA("BasePart") then
		lamp.WorldCFrame = CFrame.new(head.Position) * (root.CFrame - root.Position) * CFrame.Angles(rad(pitch), 0, 0) * CFrame.new(0.4, 0, -0.6)
	end
end

----------------------------------------------------------------------
-- Wesen
----------------------------------------------------------------------
type Twitch = { Joint: string, Offset: CFrame, Until: number }
local creatureRig: Rig? = nil
local creatureModel: Model? = nil
local twitch: Twitch? = nil
local nextTwitch = 0
local walkPhase = 0

local function creatureJointsRig(c: Model): Rig
	local joints: { [string]: Motor6D } = {}
	local base: { [Motor6D]: CFrame } = {}
	for _, d in c:GetDescendants() do
		if d:IsA("Motor6D") then
			joints[d.Name] = d
			local b = d:GetAttribute("BaseC0")
			base[d] = if typeof(b) == "CFrame" then b else d.C0
		end
	end
	return {
		Joints = joints,
		Base = base,
		Current = {},
		LookTarget = nil,
		ArmTarget = nil,
		LookIK = nil,
		ArmIK = nil,
		Lean = 0,
		Side = 0,
		LastYaw = 0,
	}
end

local function poseCreature(c: Model, rig: Rig, dt: number)
	local root = c.PrimaryPart
	if root == nil then
		return
	end
	local t = os.clock()
	local state = Util.StrAttr(c, "AIState", "Sleeping")
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local hunting = state == "Hunt" or state == "Frenzy"
	local jerk = if hunting then 0.9 else 0.35
	local a = math.min(1, dt * (if hunting then 14 else 6))

	-- Zuckungen einzelner Gelenke (10-20°, alle 0,5-3 s)
	if t >= nextTwitch then
		nextTwitch = t + 0.5 + math.random() * 2.5
		local names = { "Neck", "LeftShoulder", "RightShoulder", "Waist", "LeftElbow", "RightElbow" }
		local deg = rad(10 + math.random() * 10) * (if math.random() < 0.5 then -1 else 1)
		local axis = math.random(1, 3)
		local off = if axis == 1 then CFrame.Angles(deg, 0, 0) elseif axis == 2 then CFrame.Angles(0, deg, 0) else CFrame.Angles(0, 0, deg)
		twitch = { Joint = names[math.random(1, #names)], Offset = off, Until = t + 0.15 + math.random() * 0.25 }
	end
	local tw = twitch
	local function tj(name: string): CFrame
		if tw and tw.Joint == name and t < tw.Until then
			return tw.Offset
		end
		return CFrame.new()
	end

	if state == "Sleeping" then
		setJoint(rig, "Waist", CFrame.Angles(rad(40), 0, 0) * tj("Waist"), a)
		setJoint(rig, "Neck", CFrame.Angles(rad(30), 0, 0) * tj("Neck"), a)
		setJoint(rig, "LeftShoulder", CFrame.Angles(rad(-20), 0, rad(10)) * tj("LeftShoulder"), a)
		setJoint(rig, "RightShoulder", CFrame.Angles(rad(-20), 0, rad(-10)) * tj("RightShoulder"), a)
		return
	end

	-- langsames Pendeln des Oberkörpers, vorgebeugt bei der Jagd
	local sway = math.sin(t * 1.3) * rad(6)
	local lean = if hunting then rad(28) else rad(8)
	setJoint(rig, "Waist", CFrame.Angles(lean + math.noise(t * 3 * jerk, 1) * rad(4), sway, sway * 0.5) * tj("Waist"), a)
	-- Kopf tastet in der Luft
	local probe = math.noise(t * 0.8, 4.2) * rad(35)
	local nod = math.noise(2.7, t * 0.9) * rad(15)
	setJoint(rig, "Neck", CFrame.Angles(nod - lean * 0.6, probe, 0) * tj("Neck"), a)

	-- Laufen: Beine und Arme schwingen
	local stride = math.clamp(speed / 12, 0, 1.4)
	walkPhase += dt * speed * 0.55
	local swing = math.sin(walkPhase) * rad(32) * stride
	setJoint(rig, "LeftHip", CFrame.Angles(swing, 0, 0), a)
	setJoint(rig, "RightHip", CFrame.Angles(-swing, 0, 0), a)
	setJoint(rig, "LeftKnee", CFrame.Angles(-math.max(0, math.sin(walkPhase + 1.2)) * rad(40) * stride, 0, 0), a)
	setJoint(rig, "RightKnee", CFrame.Angles(-math.max(0, math.sin(walkPhase + 1.2 + math.pi)) * rad(40) * stride, 0, 0), a)

	local grabAt = Util.NumAttr(c, "GrabAt", 0)
	local grabbing = Workspace:GetServerTimeNow() - grabAt < Config.Health.KillCinematicTime
	if grabbing then
		setJoint(rig, "RightShoulder", CFrame.Angles(rad(-110), 0, 0), a)
		setJoint(rig, "RightElbow", CFrame.Angles(rad(-30), 0, 0), a)
	else
		setJoint(rig, "RightShoulder", CFrame.Angles(-swing * 0.6 + (if hunting then rad(-35) else 0), 0, 0) * tj("RightShoulder"), a)
		setJoint(rig, "RightElbow", CFrame.Angles(rad(-10), 0, 0) * tj("RightElbow"), a)
	end
	setJoint(rig, "LeftShoulder", CFrame.Angles(swing * 0.6 + (if hunting then rad(-35) else 0), 0, 0) * tj("LeftShoulder"), a)
	setJoint(rig, "LeftElbow", CFrame.Angles(rad(-10), 0, 0) * tj("LeftElbow"), a)
end

function PoseController.Init() end

function PoseController.Start()
	RunService.Heartbeat:Connect(function(dt: number)
		local cam = Workspace.CurrentCamera
		if cam == nil then
			return
		end
		local camPos = cam.CFrame.Position
		for _, p in Players:GetPlayers() do
			local char = p.Character
			if char and p ~= player then
				local root = char:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") and (root.Position - camPos).Magnitude < 150 then
					local rig = rigs[char]
					if rig == nil then
						local built = buildRig(char)
						if built then
							rigs[char] = built
							char:SetAttribute("Seed", math.random() * 100)
							rig = built
						end
					end
					if rig then
						poseCharacter(p, char, rig, dt)
					end
				end
			end
		end
		for char in rigs do
			if char.Parent == nil then
				rigs[char] = nil
			end
		end
		-- Wesen
		local c: Model? = nil
		for _, inst in CollectionService:GetTagged("Creature") do
			if inst:IsA("Model") then
				c = inst
			end
		end
		if c then
			if creatureModel ~= c or creatureRig == nil then
				creatureModel = c
				creatureRig = creatureJointsRig(c)
			end
			local rig = creatureRig
			if rig and c.PrimaryPart and (c.PrimaryPart.Position - camPos).Magnitude < 160 then
				poseCreature(c, rig, dt)
			end
		end
	end)
end

return PoseController
