--!strict
-- ViewmodelController (Abschnitt 10.1/10.2): eigene Arme an der Kamera. Schwingt per Feder bei
-- Mausbewegung und wippt beim Gehen. Rechte Hand: aktives Item, linke Hand: Taschenlampe (wenn an).
-- Diesel: beide Hände am Kanister. Der Lichtkegel der Lampe folgt dem Blick.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemModels = require(ReplicatedStorage.Shared.ItemModels)
local Spring = require(ReplicatedStorage.Shared.Spring)
local Util = require(ReplicatedStorage.Shared.Util)
local ClientState = require(script.Parent.Parent.Lib.ClientState)
local Settings = require(script.Parent.Parent.Lib.Settings)

local ViewmodelController = {}
ViewmodelController.Name = "ViewmodelController"

local player = Players.LocalPlayer

local rig: Model
local parts: { [string]: BasePart } = {}
local heldModels: { [string]: Model } = {}
local currentHeld: Model? = nil
local currentHeldId: string? = nil
local leftLamp: Model
local flareFx: { ParticleEmitter } = {}

local sway = Spring.new3(Vector3.zero, Config.HUD.ViewmodelSpringStiffness, Config.HUD.ViewmodelSpringDamping)
local lower = Spring.new(1, 120, 18) -- 0 = sichtbar, 1 = weggesenkt
local leftRaise = Spring.new(0, 140, 16)
local bobT = 0

local SKIN = Color3.fromRGB(205, 160, 130)

local function newPart(name: string, size: Vector3, color: Color3, material: Enum.Material): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = rig
	parts[name] = p
	return p
end

-- alle Teile verankern (Bewegung per PivotTo), Schweißnähte entfernen
local function prepModel(m: Model)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Anchored = true
		elseif d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
end

local function heldFor(id: string): Model
	local existing = heldModels[id]
	if existing then
		return existing
	end
	local m = ItemModels.Build(id)
	prepModel(m)
	heldModels[id] = m
	do
		if id == "Flare" then
			local tip = m:FindFirstChild("Tip")
			if tip and tip:IsA("BasePart") then
				local sparks = Instance.new("ParticleEmitter")
				sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				sparks.Color = ColorSequence.new(Color3.fromRGB(255, 210, 160))
				sparks.Size = NumberSequence.new(0.06)
				sparks.LightEmission = 1
				sparks.Lifetime = NumberRange.new(0.2, 0.4)
				sparks.Rate = 40
				sparks.Speed = NumberRange.new(1.5, 3)
				sparks.SpreadAngle = Vector2.new(60, 60)
				sparks.Acceleration = Vector3.new(0, -8, 0)
				sparks.Enabled = false
				sparks.Parent = tip
				local smoke = Instance.new("ParticleEmitter")
				smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
				smoke.Color = ColorSequence.new(Color3.fromRGB(255, 70, 60))
				smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1.2) })
				smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
				smoke.Lifetime = NumberRange.new(0.6, 1)
				smoke.Rate = 18
				smoke.Speed = NumberRange.new(0.5, 1)
				smoke.Acceleration = Vector3.new(0, 1.5, 0)
				smoke.Enabled = false
				smoke.Parent = tip
				table.insert(flareFx, sparks)
				table.insert(flareFx, smoke)
			end
		end
	end
	return m
end

local function sleeveColor(): Color3
	local clothing = Util.StrAttr(player, "Clothing", "Parka")
	local info = Config.ClothingInfo[clothing]
	return if info then info.Color else Color3.fromRGB(80, 80, 80)
end

local function setVisible(m: Model, visible: boolean)
	m.Parent = if visible then rig else nil
end

local function build()
	rig = Instance.new("Model")
	rig.Name = "Viewmodel"
	newPart("RightSleeve", Vector3.new(0.55, 0.55, 2.2), sleeveColor(), Enum.Material.Fabric)
	newPart("RightHand", Vector3.new(0.45, 0.4, 0.55), SKIN, Enum.Material.Fabric)
	newPart("LeftSleeve", Vector3.new(0.55, 0.55, 2.2), sleeveColor(), Enum.Material.Fabric)
	newPart("LeftHand", Vector3.new(0.45, 0.4, 0.55), SKIN, Enum.Material.Fabric)
	newPart("RightCuff", Vector3.new(0.6, 0.6, 0.2), Color3.fromRGB(40, 40, 40), Enum.Material.Fabric)
	newPart("LeftCuff", Vector3.new(0.6, 0.6, 0.2), Color3.fromRGB(40, 40, 40), Enum.Material.Fabric)
	leftLamp = ItemModels.Build("Flashlight")
	prepModel(leftLamp)
end

local function place(name: string, cf: CFrame)
	local p = parts[name]
	if p then
		p.CFrame = cf
	end
end

local function pivot(m: Model, cf: CFrame)
	if m.PrimaryPart then
		m:PivotTo(cf)
	end
end

local function update(dt: number)
	local cam = Workspace.CurrentCamera
	if cam == nil then
		return
	end
	if rig.Parent ~= cam then
		rig.Parent = cam
	end
	local st = Util.GetState(player)
	local hum = Util.GetHumanoid(player)
	local root = Util.GetRoot(player)
	local hidden = ClientState.Cinematic or (st ~= "Alive" and st ~= "Lobby") or hum == nil or root == nil or player:GetAttribute("InLocker") == true
	lower.Target = if hidden then 1 else 0
	local low = lower:Step(dt)
	if low > 0.97 and hidden then
		for _, p in parts do
			p.Transparency = 1
		end
		if currentHeld then
			setVisible(currentHeld, false)
		end
		setVisible(leftLamp, false)
		return
	end
	for _, p in parts do
		p.Transparency = 0
	end
	local sc = sleeveColor()
	parts.RightSleeve.Color = sc
	parts.LeftSleeve.Color = sc

	-- Feder-Schwingen bei Mausbewegung
	local delta = UserInputService:GetMouseDelta()
	sway.Target = Vector3.new(math.clamp(-delta.X * 0.004, -0.25, 0.25), math.clamp(delta.Y * 0.004, -0.25, 0.25), 0)
	local s = sway:Step(dt)
	sway.Target = Vector3.zero

	-- Wippen beim Gehen
	local speed = 0
	if root then
		local v = root.AssemblyLinearVelocity
		speed = Vector3.new(v.X, 0, v.Z).Magnitude
	end
	if speed > 1 then
		bobT += dt * speed * 0.9
	end
	local bobAmp = math.clamp(speed / 10, 0, 1.8) * 0.05 * Settings.ShakeFactor()
	local bob = CFrame.new(math.cos(bobT * 0.5) * bobAmp, math.abs(math.sin(bobT)) * bobAmp, 0)

	-- Unterkühlung "Mittel": Lampe wackelt
	local stage = Util.StrAttr(player, "HypoStage", "Normal")
	local tremble = 0
	if stage == "Moderate" then
		tremble = 0.012
	elseif stage == "Severe" then
		tremble = 0.025
	end
	local tt = os.clock()
	local trembleCF = CFrame.Angles(math.noise(tt * 8, 1) * tremble * 6, math.noise(2, tt * 8) * tremble * 6, 0)

	local base = cam.CFrame * CFrame.Angles(s.Y, s.X, s.X * 0.6) * bob * CFrame.new(0, -low * 2.5, 0) * trembleCF

	-- aktives Item (rechte Hand)
	local active = Util.NumAttr(player, "ActiveSlot", 1)
	local id = player:GetAttribute("Slot" .. active)
	local itemId = if type(id) == "string" and id ~= "" then id else nil
	local twoHanded = itemId ~= nil and Config.ItemInfo[itemId] ~= nil and Config.ItemInfo[itemId].TwoHanded
	if itemId ~= currentHeldId then
		if currentHeld then
			setVisible(currentHeld, false)
		end
		currentHeldId = itemId
		currentHeld = if itemId then heldFor(itemId) else nil
	end

	local rightHandCF: CFrame
	local leftHandCF: CFrame
	if twoHanded then
		rightHandCF = base * CFrame.new(0.55, -1.5, -1.6)
		leftHandCF = base * CFrame.new(-0.55, -1.5, -1.6)
	else
		rightHandCF = base * CFrame.new(1.0, -1.05, -1.9) * CFrame.Angles(math.rad(4), math.rad(6), 0)
		local lampOn = player:GetAttribute("FlashlightOn") == true
		leftRaise.Target = if lampOn then 1 else 0
		local lr = leftRaise:Step(dt)
		leftHandCF = base * CFrame.new(-1.0, -1.05 - (1 - lr) * 2.2, -1.9) * CFrame.Angles(0, math.rad(-6), 0)
		setVisible(leftLamp, lr > 0.05)
		pivot(leftLamp, leftHandCF * CFrame.new(0, 0.25, -0.35) * CFrame.Angles(0, math.rad(90), 0))
	end
	if twoHanded then
		setVisible(leftLamp, false)
	end
	place("RightHand", rightHandCF)
	place("RightSleeve", rightHandCF * CFrame.new(0.05, -0.05, 1.3))
	place("RightCuff", rightHandCF * CFrame.new(0.05, -0.05, 0.3))
	place("LeftHand", leftHandCF)
	place("LeftSleeve", leftHandCF * CFrame.new(-0.05, -0.05, 1.3))
	place("LeftCuff", leftHandCF * CFrame.new(-0.05, -0.05, 0.3))

	if currentHeld then
		setVisible(currentHeld, true)
		local grip: CFrame
		if itemId == "Diesel" then
			grip = base * CFrame.new(0, -2.1, -1.8)
		elseif itemId == "Flashlight" then
			grip = rightHandCF * CFrame.new(0, 0.25, -0.35) * CFrame.Angles(0, math.rad(90), 0)
		elseif itemId == "Flare" then
			grip = rightHandCF * CFrame.new(0, 0.55, -0.2)
		elseif itemId == "Scanner" then
			grip = rightHandCF * CFrame.new(-0.2, 0.35, -0.5) * CFrame.Angles(math.rad(25), 0, 0)
		else
			grip = rightHandCF * CFrame.new(0, 0.25, -0.35)
		end
		pivot(currentHeld, grip)
	end
	local lit = player:GetAttribute("FlareLit") == true
	for _, fx in flareFx do
		fx.Enabled = lit and itemId == "Flare"
	end
	local lens = leftLamp:FindFirstChild("Lens")
	if lens and lens:IsA("BasePart") then
		lens.Material = if player:GetAttribute("FlashlightOn") == true then Enum.Material.Neon else Enum.Material.Glass
	end
	if currentHeldId == "Flashlight" and currentHeld then
		local l2 = currentHeld:FindFirstChild("Lens")
		if l2 and l2:IsA("BasePart") then
			l2.Material = if player:GetAttribute("FlashlightOn") == true then Enum.Material.Neon else Enum.Material.Glass
		end
	end

	-- Lichtkegel der Lampe (am Kopf des eigenen Charakters) folgt der Kamera
	local char = Util.GetCharacter(player)
	local head = if char then char:FindFirstChild("Head") else nil
	local att = if head then head:FindFirstChild("LampAttachment") else nil
	if att and att:IsA("Attachment") then
		att.WorldCFrame = cam.CFrame * CFrame.new(0.5, -0.4, -0.5)
	end
end

function ViewmodelController.Init()
	build()
end

function ViewmodelController.Start()
	RunService:BindToRenderStep("SubZeroViewmodel", Enum.RenderPriority.Camera.Value + 2, update)
end

return ViewmodelController
