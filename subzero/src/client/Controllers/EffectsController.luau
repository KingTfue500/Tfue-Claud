--!strict
-- EffectsController (Abschnitt 5.5/10.4/13.2), alles nur lokal:
--   Atemdampf (Stoß alle 2,5 s, dichter je kälter; keiner beim Atem-Anhalten, großer Stoß beim
--   Luftschnappen), Frost-Spuren des Wesens (Pool von 40, verblassen nach 20 s), Licht bei Strom-
--   ausfall/Generator, Flackern nahe dem Wesen, max. 6 schattenwerfende Lichter, Partikel nur in
--   80 Studs, EKG-Monitore und Funkgeräte als Warnung, Frost an Lüftungsgittern, Rundumleuchten,
--   Helikopter-Rotoren, Ofen- und Reaktor-Glühen.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local ObjectPool = require(ReplicatedStorage.Shared.ObjectPool)
local Util = require(ReplicatedStorage.Shared.Util)
local AudioController = require(script.Parent.AudioController)
local ZoneController = require(script.Parent.ZoneController)

local EffectsController = {}
EffectsController.Name = "EffectsController"

local FX = Config.Effects

local function map(): Instance?
	return Workspace:FindFirstChild("Map")
end

local function creature(): Model?
	for _, c in CollectionService:GetTagged("Creature") do
		if c:IsA("Model") and c.PrimaryPart then
			return c
		end
	end
	return nil
end

local function creatureActivePos(): Vector3?
	local c = creature()
	if c and c.PrimaryPart and c:GetAttribute("AIState") ~= "Sleeping" and c:GetAttribute("InVent") ~= true then
		return c.PrimaryPart.Position
	end
	return nil
end

----------------------------------------------------------------------
-- Atemdampf
----------------------------------------------------------------------
type BreathFx = { Emitter: ParticleEmitter, Next: number, LastGasp: number }
local breaths: { [Model]: BreathFx } = {}

local ZONE_COLD: { [string]: number } = { Lobby = 0.2, Zone1 = 0.6, Zone2 = 0.8, Zone3 = 1.0, Zone4 = 0.5, Helipad = 1.0 }

local function breathFor(char: Model): BreathFx?
	local fx = breaths[char]
	if fx and fx.Emitter.Parent then
		return fx
	end
	local head = char:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return nil
	end
	local att = Instance.new("Attachment")
	att.Name = "BreathAttachment"
	att.Position = Vector3.new(0, -0.2, -0.7)
	att.Parent = head
	local e = Instance.new("ParticleEmitter")
	e.Name = "Breath"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(235, 240, 248))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1.4) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.65), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.9, 1.6)
	e.Rate = 0
	e.Speed = NumberRange.new(1.2, 2.2)
	e.SpreadAngle = Vector2.new(15, 15)
	e.Acceleration = Vector3.new(0, 0.6, 0)
	e.EmissionDirection = Enum.NormalId.Front
	e.Parent = att
	local nfx: BreathFx = { Emitter = e, Next = os.clock() + math.random() * FX.BreathInterval, LastGasp = 0 }
	breaths[char] = nfx
	return nfx
end

local function updateBreath(camPos: Vector3)
	local t = os.clock()
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local root = Util.GetRoot(p)
		if char and root and (root.Position - camPos).Magnitude < FX.ActiveRange then
			local fx = breathFor(char)
			if fx then
				local gasp = Util.NumAttr(p, "GaspAt", 0)
				if gasp ~= fx.LastGasp then
					if fx.LastGasp ~= 0 then
						fx.Emitter:Emit(18) -- großer Stoß beim Luftschnappen
					end
					fx.LastGasp = gasp
				end
				if t >= fx.Next then
					fx.Next = t + FX.BreathInterval
					local holding = p:GetAttribute("HoldingBreath") == true
					local cold = ZONE_COLD[Util.StrAttr(p, "Zone", "Lobby")] or 0.5
					if not holding and p:GetAttribute("InLocker") ~= true then
						fx.Emitter:Emit(math.floor(2 + cold * 6))
					end
				end
			end
		end
	end
	for char in breaths do
		if char.Parent == nil then
			breaths[char] = nil
		end
	end
end

----------------------------------------------------------------------
-- Frost-Spuren des Wesens (Pool von 40)
----------------------------------------------------------------------
type Print = { Part: BasePart, Born: number }
local printPool: ObjectPool.Pool<Print>
local printFolder: Folder
local printDist = 0
local printLast: Vector3? = nil
local printSide = 1
local activePrints: { Print } = {}

local function makePrint(): Print
	local p = Instance.new("Part")
	p.Name = "FrostPrint"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.new(1.3, 0.05, 2.6)
	p.Material = Enum.Material.Ice
	p.Color = Color3.fromRGB(205, 235, 255)
	p.Transparency = 1
	p.Parent = printFolder
	return { Part = p, Born = 0 }
end

local function resetPrint(pr: Print)
	pr.Part.Transparency = 1
	pr.Part.CFrame = CFrame.new(0, -1000, 0)
end

local printParams = RaycastParams.new()
printParams.FilterType = Enum.RaycastFilterType.Exclude

local function updatePrints()
	local c = creature()
	local t = os.clock()
	if c and c.PrimaryPart and c:GetAttribute("InVent") ~= true and c:GetAttribute("AIState") ~= "Sleeping" then
		local pos = c.PrimaryPart.Position
		local last = printLast
		printLast = pos
		if last then
			local d = Vector3.new(pos.X - last.X, 0, pos.Z - last.Z).Magnitude
			if d < 8 then
				printDist += d
			end
			if printDist >= Config.Entity.FootprintSpacing then
				printDist = 0
				printSide = -printSide
				printParams.FilterDescendantsInstances = { c, printFolder }
				local look = c.PrimaryPart.CFrame
				local side = look.RightVector * (printSide * 0.9)
				local hit = Workspace:Raycast(pos + side, Vector3.new(0, -9, 0), printParams)
				if hit then
					local pr = printPool:Get()
					if pr then
						local flat = Vector3.new(look.LookVector.X, 0, look.LookVector.Z)
						if flat.Magnitude < 0.01 then
							flat = Vector3.new(0, 0, -1)
						end
						pr.Part.CFrame = CFrame.lookAt(hit.Position + Vector3.new(0, 0.03, 0), hit.Position + Vector3.new(0, 0.03, 0) + flat.Unit)
						pr.Part.Transparency = 0.25
						pr.Born = t
						table.insert(activePrints, pr)
					end
				end
			end
		end
	else
		printLast = nil
	end
	-- verblassen nach 20 s
	for i = #activePrints, 1, -1 do
		local pr = activePrints[i]
		local age = t - pr.Born
		local life = Config.Entity.FootprintLifetime
		if age >= life then
			table.remove(activePrints, i)
			printPool:Release(pr)
		elseif age > life * 0.6 then
			pr.Part.Transparency = 0.25 + 0.75 * ((age - life * 0.6) / (life * 0.4))
		end
	end
end

----------------------------------------------------------------------
-- Licht: Stromausfall, Generator, Flackern nahe dem Wesen
----------------------------------------------------------------------
local function lightOf(part: Instance): Light?
	for _, c in part:GetChildren() do
		if c:IsA("Light") then
			return c
		end
	end
	return nil
end

local function powerOn(group: string?): boolean
	local m = map()
	if m == nil then
		return true
	end
	if group == "Zone3" then
		return m:GetAttribute("GeneratorOn") == true
	end
	if group == "Zone4" then
		return true
	end
	local ps = m:GetAttribute("PowerState")
	return ps ~= "Off"
end

local NEON_OFF = Color3.fromRGB(35, 38, 42)

local function setLamp(part: BasePart, on: boolean, factor: number)
	local light = lightOf(part)
	local base = Util.NumAttr(part, "BaseBrightness", 1)
	if light then
		light.Enabled = on
		light.Brightness = base * factor
	end
	if part:HasTag("PowerLight") or part:HasTag("GeneratorLight") then
		local baseColor = part:GetAttribute("BaseColor")
		if on and factor > 0.3 then
			part.Material = Enum.Material.Neon
			if typeof(baseColor) == "Color3" then
				part.Color = baseColor
			end
		else
			part.Material = Enum.Material.Glass
			part.Color = NEON_OFF
		end
	end
end

local function updateLights(cpos: Vector3?)
	local m = map()
	local ps = if m then m:GetAttribute("PowerState") else "On"
	local t = os.clock()
	for _, part in CollectionService:GetTagged("PowerLight") do
		if part:IsA("BasePart") then
			local group = Util.StrAttr(part, "PowerGroup", "Zone1")
			local on = powerOn(group)
			local factor = 1
			if ps == "Flicker" and group ~= "Zone3" then
				-- Lichter flackern 3 s und sterben
				local n = math.noise(t * 14, part.Position.X * 0.1, part.Position.Z * 0.1)
				factor = if n > 0.05 then 1 else 0.05
			end
			if on and cpos and (part.Position - cpos).Magnitude < FX.FlickerRange then
				factor *= if math.random() < 0.35 then 0.1 else 1
			end
			setLamp(part, on, factor)
		end
	end
	for _, part in CollectionService:GetTagged("EmergencyLight") do
		if part:IsA("BasePart") then
			local on = ps == "Off"
			local factor = 1
			if on and cpos and (part.Position - cpos).Magnitude < FX.FlickerRange then
				factor = if math.random() < 0.4 then 0.2 else 1
			end
			setLamp(part, on, factor)
			part.Color = if on then Color3.fromRGB(255, 40, 30) else Color3.fromRGB(90, 20, 18)
			part.Material = if on then Enum.Material.Neon else Enum.Material.Glass
		end
	end
	local gen = m ~= nil and m:GetAttribute("GeneratorOn") == true
	for _, part in CollectionService:GetTagged("GeneratorLight") do
		if part:IsA("BasePart") then
			local factor = 1
			if gen and cpos and (part.Position - cpos).Magnitude < FX.FlickerRange then
				factor = if math.random() < 0.35 then 0.1 else 1
			end
			setLamp(part, gen, factor)
		end
	end
	-- Reaktor-Lampen flackern nahe dem Wesen
	for _, part in CollectionService:GetTagged("FlickerLight") do
		if part:IsA("BasePart") and not part:HasTag("PowerLight") and not part:HasTag("EmergencyLight") and not part:HasTag("GeneratorLight") then
			local light = lightOf(part)
			if light then
				local base = Util.NumAttr(part, "BaseBrightness", light.Brightness)
				local near = cpos ~= nil and (part.Position - (cpos :: Vector3)).Magnitude < FX.FlickerRange
				light.Brightness = if near and math.random() < 0.4 then base * 0.15 else base
			end
		end
	end
	-- Lichtstrahlen in den Habitations-/Labor-Fluren nur mit Strom
	for _, b in CollectionService:GetTagged("LightShaft") do
		if b:IsA("Beam") and not b:HasTag("HatchBeam") and b.Parent and b.Parent.Parent and b.Parent.Parent.Name == "Lights" then
			b.Enabled = ps == "On" and (b.Parent :: BasePart).Position.Y > -10
		end
	end
end

----------------------------------------------------------------------
-- Schattenlicht-Pool (max. 6) und Partikel-Abschaltung
----------------------------------------------------------------------
-- Fackel-Lichter (in der Hand und am Boden) flackern
local flareLights: { Light } = {}
local function flickerFlares()
	local t = os.clock()
	local base = Config.Items.Flare.LightBrightness
	for i, l in flareLights do
		if l.Parent and l.Enabled then
			l.Brightness = base * (0.7 + (math.noise(t * 11, i * 3.1) + 0.5) * 0.55)
		end
	end
end

local function updateShadowPool(camPos: Vector3)
	table.clear(flareLights)
	local cands: { { Light: Light, D: number } } = {}
	local function add(l: Light, pos: Vector3)
		if l.Enabled then
			table.insert(cands, { Light = l, D = (pos - camPos).Magnitude })
		else
			l.Shadows = false
		end
	end
	for _, p in Players:GetPlayers() do
		local char = p.Character
		if char then
			for _, d in char:GetDescendants() do
				if d:IsA("SpotLight") or d:IsA("PointLight") then
					if d.Name == "FlareLight" then
						table.insert(flareLights, d)
					end
					local parent = d.Parent
					local pos = if parent and parent:IsA("Attachment") then parent.WorldPosition elseif parent and parent:IsA("BasePart") then parent.Position else camPos
					add(d, pos)
				end
			end
		end
	end
	for _, part in CollectionService:GetTagged("DynamicLight") do
		if part:IsA("BasePart") then
			local l = lightOf(part)
			if l then
				table.insert(flareLights, l)
				add(l, part.Position)
			end
		end
	end
	for _, part in CollectionService:GetTagged("StoveLight") do
		if part:IsA("BasePart") then
			local l = lightOf(part)
			if l then
				add(l, part.Position)
			end
		end
	end
	table.sort(cands, function(a, b)
		return a.D < b.D
	end)
	for i, c in cands do
		c.Light.Shadows = i <= FX.MaxShadowLights
	end
end

local function updateEmitters(camPos: Vector3)
	for _, e in CollectionService:GetTagged("AmbientEmitter") do
		if e:IsA("ParticleEmitter") then
			local parent = e.Parent
			if parent and parent:IsA("BasePart") then
				local d = (parent.Position - camPos).Magnitude - parent.Size.Magnitude / 2
				e.Enabled = d < FX.ActiveRange
			end
		end
	end
end

----------------------------------------------------------------------
-- Diegetische Warnung: EKG-Monitore, Funkgeräte; Frost an Lüftungsgittern
----------------------------------------------------------------------
local nextBeep: { [Model]: number } = {}
local function updateDiegetic(camPos: Vector3, cpos: Vector3?)
	local t = os.clock()
	for _, m in CollectionService:GetTagged("EkgMonitor") do
		if m:IsA("Model") then
			local screen = m:FindFirstChild("Screen")
			if screen and screen:IsA("BasePart") and (screen.Position - camPos).Magnitude < FX.ActiveRange then
				local prox = 0
				if cpos then
					local d = (screen.Position - cpos).Magnitude
					prox = math.clamp(1 - d / Config.Entity.DiegeticRange, 0, 1)
				end
				local interval = 1.2 - prox * 0.95 + (if prox > 0 then (math.random() - 0.5) * 0.3 * prox else 0)
				if t >= (nextBeep[m] or 0) then
					nextBeep[m] = t + math.max(0.15, interval)
					screen.Color = Color3.fromRGB(80, 255, 130)
					task.delay(0.08, function()
						screen.Color = Color3.fromRGB(20, 120, 50)
					end)
					AudioController.Play3D("EkgBeep", screen.Position, 0.4 + prox * 0.4, 1 + prox * 0.2, 40, "Effects")
				end
			end
		end
	end
	for _, m in CollectionService:GetTagged("Radio") do
		if m:IsA("Model") then
			local led = m:FindFirstChild("Led")
			if led and led:IsA("BasePart") then
				local near = cpos ~= nil and (led.Position - (cpos :: Vector3)).Magnitude < Config.Entity.DiegeticRange
				led.Color = if near and math.random() < 0.5 then Color3.fromRGB(255, 40, 30) else Color3.fromRGB(40, 255, 60)
			end
		end
	end
end

local lastScratch: { [Model]: number } = {}
local function updateVents()
	for _, v in CollectionService:GetTagged("Vent") do
		if v:IsA("Model") then
			local at = Util.NumAttr(v, "ScratchAt", 0)
			if at ~= 0 and at ~= lastScratch[v] then
				lastScratch[v] = at
				local frost = v:FindFirstChild("Frost")
				if frost and frost:IsA("BasePart") then
					-- Frost breitet sich in 2 s am Gitter aus
					TweenService:Create(frost, TweenInfo.new(Config.Entity.VentScratchTime), { Transparency = 0.25 }):Play()
					task.delay(10, function()
						TweenService:Create(frost, TweenInfo.new(4), { Transparency = 1 }):Play()
					end)
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- Bewegte Deko: Rundumleuchten, Helikopter, Ofen, Reaktor, Blinklichter
----------------------------------------------------------------------
local heliLift = 0

-- Teile mit Puls/Blink einmal sammeln (statt jedes Frame die ganze Map)
local decoParts: { BasePart } = {}
local function collectDeco()
	table.clear(decoParts)
	local m = map()
	if m == nil then
		return
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and (d:GetAttribute("Pulse") == true or d:GetAttribute("Blink") == true or d:GetAttribute("ReactorCore") == true) then
			table.insert(decoParts, d)
		end
	end
end

local function updateDecoParts()
	local t = os.clock()
	for _, d in decoParts do
		if d.Parent then
			if d:GetAttribute("Pulse") == true then
				d.Transparency = 0.35 + math.sin(t * 2 + d.Position.X) * 0.25
			elseif d:GetAttribute("Blink") == true then
				d.Transparency = if (t + d.Position.Z * 0.05) % 1.2 < 0.6 then 0 else 0.85
			else
				d.Transparency = 0.05 + math.sin(t * 1.3) * 0.05
			end
		end
	end
end

function EffectsController.Init()
	printFolder = Instance.new("Folder")
	printFolder.Name = "FrostPrints"
	printFolder.Parent = Workspace.CurrentCamera or Workspace
	printPool = ObjectPool.new(Config.Entity.FootprintPoolSize, makePrint, resetPrint, true)
end

function EffectsController.Start()
	local slow = 0
	local mid = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local cam = Workspace.CurrentCamera
		if cam == nil then
			return
		end
		local camPos = cam.CFrame.Position
		local cpos = creatureActivePos()
		updatePrints()
		updateDecoParts()
		flickerFlares()
		mid += dt
		if mid >= 0.1 then
			mid = 0
			updateLights(cpos)
			updateBreath(camPos)
			updateDiegetic(camPos, cpos)
			updateVents()
		end
		slow += dt
		if slow >= FX.EmitterCullInterval then
			slow = 0
			updateShadowPool(camPos)
			updateEmitters(camPos)
			if #decoParts == 0 then
				collectDeco()
			end
		end
		-- leichte Deko ohne Map-Durchlauf
		local t = os.clock()
		for _, dome in CollectionService:GetTagged("CountdownBeacon") do
			if dome:IsA("BasePart") and dome:GetAttribute("Spinning") == true then
				local base = dome:GetAttribute("BaseCF")
				if typeof(base) == "CFrame" then
					dome.CFrame = base * CFrame.Angles(0, t * 6, 0)
				end
			end
		end
		for _, lp in CollectionService:GetTagged("StoveLight") do
			if lp:IsA("BasePart") then
				local l = lightOf(lp)
				if l then
					local base = Util.NumAttr(lp, "BaseBrightness", 2)
					l.Brightness = base * (0.82 + math.noise(t * 6, 3.3) * 0.35)
				end
			end
		end
		for _, heli in CollectionService:GetTagged("Helicopter") do
			if heli:IsA("Model") then
				local rotor = Util.NumAttr(heli, "Rotor", 0)
				if heli:GetAttribute("Departing") == true then
					heliLift += dt
				else
					heliLift = 0
				end
				for _, name in { "Rotor", "Rotor2", "TailRotor" } do
					local p = heli:FindFirstChild(name)
					if p and p:IsA("BasePart") then
						local base = p:GetAttribute("BaseCF")
						if typeof(base) == "CFrame" then
							local spin = if name == "TailRotor" then CFrame.Angles(t * 40 * rotor, 0, 0) else CFrame.Angles(0, t * 25 * rotor, 0)
							p.CFrame = base * spin + Vector3.new(0, heliLift * heliLift * 3, 0)
						end
					end
				end
			end
		end
	end)
	-- neu gestreamte Teile berücksichtigen
	local m = map()
	if m then
		m.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") and (d:GetAttribute("Pulse") == true or d:GetAttribute("Blink") == true or d:GetAttribute("ReactorCore") == true) then
				table.insert(decoParts, d)
			end
		end)
	end
	ZoneController.ZoneChanged:Connect(function()
		collectDeco()
	end)
end

return EffectsController
