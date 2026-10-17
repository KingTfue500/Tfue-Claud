--!strict
-- Das Wesen (Platzhalter-Modell aus Teilen, später durch ein geriggtes Skinned Mesh ersetzbar).
-- 9 Studs groß, ausgemergelt, frostschwarz, lange Arme. Gelenke als Motor6D, damit die
-- Clients es prozedural animieren können (Abschnitt 10.3).

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Creature = {}

local SKIN = Color3.fromRGB(28, 32, 40)
local SKIN_LIGHT = Color3.fromRGB(70, 82, 98)
local ICE = Color3.fromRGB(170, 215, 245)

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = true
	p.CollisionGroup = Config.CollisionGroups.Creature
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local function joint(name: string, p0: BasePart, p1: BasePart, at: Vector3): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	local world = CFrame.new(at)
	m.C0 = p0.CFrame:Inverse() * world
	m.C1 = p1.CFrame:Inverse() * world
	m:SetAttribute("BaseC0", m.C0)
	m.Parent = p0
	return m
end

local function weld(p0: BasePart, p1: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = p0
	w.Part1 = p1
	w.Parent = p1
end

-- Baut das Modell mit Füßen bei y = 0 um den Ursprung; danach per PivotTo platzieren.
function Creature.Build(): Model
	local model = Instance.new("Model")
	model.Name = "Thermophage_PH"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(3, 4, 2)
	root.CFrame = CFrame.new(0, 5, 0)
	root.Transparency = 1
	root.CanCollide = true
	root.CanTouch = false
	root.CanQuery = false
	root.CollisionGroup = Config.CollisionGroups.Creature
	root.Parent = model
	model.PrimaryPart = root

	local DARK = Enum.Material.Slate
	local pelvis = part(model, "LowerTorso", Vector3.new(2.6, 1.2, 1.6), CFrame.new(0, 4.6, 0), SKIN, DARK)
	local torso = part(model, "UpperTorso", Vector3.new(3.2, 3.2, 1.8), CFrame.new(0, 6.7, -0.3) * CFrame.Angles(math.rad(-12), 0, 0), SKIN, DARK)
	local head = part(model, "Head", Vector3.new(1.5, 2.3, 1.9), CFrame.new(0, 9.0, -1.0) * CFrame.Angles(math.rad(-20), 0, 0), SKIN, DARK)
	-- Rippen, Wirbelsäule, Eiskristalle
	for i = 0, 3 do
		local r = part(model, "Rib" .. i, Vector3.new(3.3, 0.25, 1.9), torso.CFrame * CFrame.new(0, -1 + i * 0.6, 0), SKIN_LIGHT, Enum.Material.Glacier)
		weld(torso, r)
	end
	for i = 0, 4 do
		local s = part(model, "Spine" .. i, Vector3.new(0.4, 0.9, 0.6), torso.CFrame * CFrame.new(0, -1.2 + i * 0.65, 1.0) * CFrame.Angles(math.rad(30), 0, 0), ICE, Enum.Material.Ice)
		s.Transparency = 0.15
		weld(torso, s)
	end
	for i = 1, 6 do
		local a = math.rad(i * 60)
		local c = part(model, "Crystal" .. i, Vector3.new(0.3, 1.2 + (i % 3) * 0.4, 0.3), torso.CFrame * CFrame.new(math.cos(a) * 1.3, 1.4, 0.6 + math.sin(a) * 0.3) * CFrame.Angles(math.rad(-25), 0, math.rad(math.cos(a) * 30)), ICE, Enum.Material.Ice)
		c.Transparency = 0.2
		weld(torso, c)
	end
	-- Kopf: augenlos, kalter Spalt als Maul
	local maw = part(model, "Maw", Vector3.new(1.0, 0.15, 0.2), head.CFrame * CFrame.new(0, -0.6, -0.95), ICE, Enum.Material.Neon)
	maw.Transparency = 0.2
	weld(head, maw)
	for i = -1, 1, 2 do
		local horn = part(model, "Crest", Vector3.new(0.25, 1.4, 0.25), head.CFrame * CFrame.new(i * 0.5, 1.2, 0.3) * CFrame.Angles(math.rad(-30), 0, math.rad(i * -15)), ICE, Enum.Material.Ice)
		weld(head, horn)
	end
	local headAtt = Instance.new("Attachment")
	headAtt.Name = "SenseOrigin"
	headAtt.Parent = head
	local breath = Instance.new("ParticleEmitter")
	breath.Name = "FrostBreath"
	breath.Texture = "rbxasset://textures/particles/smoke_main.dds"
	breath.Color = ColorSequence.new(Color3.fromRGB(210, 230, 255))
	breath.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.6) })
	breath.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
	breath.Lifetime = NumberRange.new(0.8, 1.4)
	breath.Rate = 3
	breath.Speed = NumberRange.new(1, 2)
	breath.EmissionDirection = Enum.NormalId.Front
	breath.Parent = maw

	-- Arme (lang, bis fast zum Boden)
	local function arm(side: number)
		local sx = side * 2.0
		local shoulder = Vector3.new(sx, 7.9, -0.5)
		local upper = part(model, (if side < 0 then "Left" else "Right") .. "UpperArm", Vector3.new(0.75, 3.4, 0.75), CFrame.new(sx, 6.2, -0.6) * CFrame.Angles(math.rad(10), 0, math.rad(side * 6)), SKIN, DARK)
		local lower = part(model, (if side < 0 then "Left" else "Right") .. "LowerArm", Vector3.new(0.6, 3.4, 0.6), CFrame.new(sx + side * 0.3, 2.9, -1.0) * CFrame.Angles(math.rad(-8), 0, math.rad(side * 3)), SKIN, DARK)
		local hand = part(model, (if side < 0 then "Left" else "Right") .. "Hand", Vector3.new(0.9, 0.9, 0.5), CFrame.new(sx + side * 0.4, 0.9, -1.3), SKIN_LIGHT, DARK)
		for f = -1, 1 do
			local claw = part(model, "Claw", Vector3.new(0.18, 1.6, 0.18), hand.CFrame * CFrame.new(f * 0.3, -1.0, -0.1) * CFrame.Angles(math.rad(-15), 0, math.rad(f * 8)), ICE, Enum.Material.Ice)
			weld(hand, claw)
		end
		joint((if side < 0 then "Left" else "Right") .. "Shoulder", torso, upper, shoulder)
		joint((if side < 0 then "Left" else "Right") .. "Elbow", upper, lower, Vector3.new(sx + side * 0.15, 4.5, -0.8))
		joint((if side < 0 then "Left" else "Right") .. "Wrist", lower, hand, Vector3.new(sx + side * 0.4, 1.3, -1.25))
		if side > 0 then
			local grab = Instance.new("Attachment")
			grab.Name = "GrabPoint"
			grab.Position = Vector3.new(0, -0.8, -0.8)
			grab.Parent = hand
		end
	end
	arm(-1)
	arm(1)

	-- Beine
	local function leg(side: number)
		local sx = side * 0.8
		local thigh = part(model, (if side < 0 then "Left" else "Right") .. "UpperLeg", Vector3.new(0.9, 2.4, 0.9), CFrame.new(sx, 3.0, 0.1) * CFrame.Angles(math.rad(-8), 0, 0), SKIN, DARK)
		local shin = part(model, (if side < 0 then "Left" else "Right") .. "LowerLeg", Vector3.new(0.7, 2.2, 0.7), CFrame.new(sx, 1.0, 0.2) * CFrame.Angles(math.rad(8), 0, 0), SKIN, DARK)
		local foot = part(model, (if side < 0 then "Left" else "Right") .. "Foot", Vector3.new(0.8, 0.3, 1.4), CFrame.new(sx, 0.15, -0.2), SKIN_LIGHT, DARK)
		joint((if side < 0 then "Left" else "Right") .. "Hip", pelvis, thigh, Vector3.new(sx, 4.2, 0))
		joint((if side < 0 then "Left" else "Right") .. "Knee", thigh, shin, Vector3.new(sx, 1.9, 0.2))
		joint((if side < 0 then "Left" else "Right") .. "Ankle", shin, foot, Vector3.new(sx, 0.2, 0.1))
	end
	leg(-1)
	leg(1)

	joint("Root", root, pelvis, Vector3.new(0, 4.6, 0))
	joint("Waist", pelvis, torso, Vector3.new(0, 5.2, 0))
	joint("Neck", torso, head, Vector3.new(0, 8.2, -0.7))

	-- Aura: flimmernde ForceField-Kugel mit Hitzeflimmer-Partikeln
	local aura = part(model, "Aura", Vector3.new(11, 11, 11), CFrame.new(0, 5.5, 0), Color3.fromRGB(150, 200, 255), Enum.Material.ForceField, Enum.PartType.Ball)
	aura.Transparency = 0.55
	aura.CastShadow = false
	weld(root, aura)
	local shimmer = Instance.new("ParticleEmitter")
	shimmer.Name = "HeatShimmer"
	shimmer.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	shimmer.Color = ColorSequence.new(Color3.fromRGB(190, 220, 255))
	shimmer.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 2.4) })
	shimmer.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.5, 0.82), NumberSequenceKeypoint.new(1, 1) })
	shimmer.Lifetime = NumberRange.new(1, 1.8)
	shimmer.Rate = 12
	shimmer.Speed = NumberRange.new(0.5, 1.5)
	shimmer.SpreadAngle = Vector2.new(180, 180)
	shimmer.LightInfluence = 0
	shimmer.Shape = Enum.ParticleEmitterShape.Sphere
	shimmer.Parent = aura
	local glow = Instance.new("PointLight")
	glow.Name = "ColdGlow"
	glow.Color = Color3.fromRGB(120, 170, 255)
	glow.Range = 10
	glow.Brightness = 0.4
	glow.Parent = torso

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = 3
	hum.WalkSpeed = 0
	hum.AutoRotate = true
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.MaxHealth = 1e9
	hum.Health = 1e9
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.UseJumpPower = true
	hum.JumpPower = 0
	hum.MaxSlopeAngle = 60
	hum.Parent = model

	model:SetAttribute("AIState", "Sleeping")
	model:SetAttribute("InVent", false)
	model:SetAttribute("TargetUserId", 0)
	return model
end

return Creature
