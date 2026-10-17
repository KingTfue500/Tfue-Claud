-- Visual and audio effects: flickering lights, fear effects when the monster is near,
-- lightning, blackouts, jumpscares, escape flash, ghost apparitions and sounds.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local UI = require(script.Parent.UI)
local Controls = require(script.Parent.Controls)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Sounds = Config.Sounds

local Effects = {}

local fearGrade: ColorCorrectionEffect
local blur: BlurEffect
local heartbeat: Sound?
local blackoutUntil = 0
local shakeUntil, shakeStrength = 0, 0

----------------------------------------------------------------------------------------------------
-- Sound helpers
----------------------------------------------------------------------------------------------------

local function play2D(id: string, volume: number, pitch: number?)
	if id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 15)
end

local function loop2D(id: string, volume: number)
	if id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Looped = true
	s.Parent = SoundService
	s:Play()
	return s
end

Effects.play2D = play2D

----------------------------------------------------------------------------------------------------
-- Lights
----------------------------------------------------------------------------------------------------

type LightInfo = { part: BasePart, light: Light, base: number, transparency: number, seed: number, candle: boolean }
local lights: { [BasePart]: LightInfo } = {}

local function addLight(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local l = part:FindFirstChildWhichIsA("Light") or part:WaitForChild("PointLight", 5)
	if not l or not l:IsA("Light") then
		return
	end
	lights[part] = {
		part = part,
		light = l,
		base = part:GetAttribute("BaseBrightness") or l.Brightness,
		transparency = part.Transparency,
		seed = math.random() * 100,
		-- flames (candles, fireplaces) flicker softly; lamps and lanterns cut out now and then
		candle = part.Transparency >= 1 or (part.Material == Enum.Material.Neon and part.Size.Y < 0.5),
	}
end

local function updateLights(t: number, monsterPos: Vector3?)
	local dark = t < blackoutUntil
	for part, info in lights do
		if not part.Parent then
			lights[part] = nil
			continue
		end
		local brightness
		if dark then
			brightness = 0
		else
			local n = math.noise(t * (info.candle and 6 or 2.5), info.seed)
			brightness = info.base * (0.85 + n * 0.35)
			-- now and then an electric light cuts out for a moment
			if not info.candle and math.noise(t * 1.3, info.seed + 50) > 0.42 then
				brightness *= 0.1
			end
			-- the monster drains the light around it
			if monsterPos then
				local d = (monsterPos - part.Position).Magnitude
				if d < 28 then
					local k = 1 - d / 28
					brightness *= if math.random() < k * 0.6 then 0.05 else (1 - k * 0.5)
				end
			end
		end
		info.light.Brightness = brightness
		if part.Transparency < 1 or info.transparency < 1 then
			part.Transparency = if brightness < info.base * 0.15 then math.max(info.transparency, 0.85) else info.transparency
		end
	end
	for _, eye in CollectionService:GetTagged("PortraitEye") do
		eye.Transparency = dark and 0 or 1
	end
end

----------------------------------------------------------------------------------------------------
-- Events from the server
----------------------------------------------------------------------------------------------------

function Effects.lightning()
	local brightness = Lighting.Brightness
	local outdoor = Lighting.OutdoorAmbient
	task.spawn(function()
		for _ = 1, math.random(1, 3) do
			Lighting.Brightness = 5
			Lighting.OutdoorAmbient = Color3.fromRGB(170, 180, 220)
			UI.flash(Color3.fromRGB(200, 210, 255), 0.25, 0.85)
			task.wait(0.05 + math.random() * 0.06)
			Lighting.Brightness = brightness
			Lighting.OutdoorAmbient = outdoor
			task.wait(0.08 + math.random() * 0.15)
		end
	end)
	task.delay(0.6 + math.random() * 1.4, function()
		play2D(Sounds.Thunder, 0.9, 0.9 + math.random() * 0.2)
		shakeUntil = os.clock() + 0.8
		shakeStrength = 0.12
	end)
end

function Effects.blackout(seconds: number)
	blackoutUntil = os.clock() + seconds
	play2D(Sounds.Whisper, 0.7, 0.8)
	-- when the lights come back, everything is washed in red for a moment
	task.delay(seconds, function()
		fearGrade.TintColor = Color3.fromRGB(255, 120, 120)
		TweenService:Create(fearGrade, TweenInfo.new(1.6), { TintColor = Color3.new(1, 1, 1) }):Play()
	end)
end

function Effects.shake(position: Vector3, strength: number)
	local d = (camera.CFrame.Position - position).Magnitude
	if d < 70 then
		shakeUntil = os.clock() + 0.5
		shakeStrength = math.max(shakeStrength, strength * 0.4 * (1 - d / 70))
	end
end

function Effects.jumpscare(monster: Model?)
	Controls.frozen = true
	play2D(Sounds.Jumpscare, 2)
	UI.flash(Color3.fromRGB(160, 0, 0), 0.9, 0.2)
	blur.Size = 10
	local head = monster and monster:FindFirstChild("Head") :: BasePart?
	camera.CameraType = Enum.CameraType.Scriptable
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if head and head.Parent then
			local face = head.CFrame
			local distance = 3.2 - math.min(t * 4, 1.9)
			local pos = face.Position + face.LookVector * distance
			local jitter = CFrame.Angles((math.random() - 0.5) * 0.12, (math.random() - 0.5) * 0.12, (math.random() - 0.5) * 0.2)
			camera.CFrame = CFrame.lookAt(pos, face.Position) * jitter
		else
			camera.CFrame *= CFrame.Angles((math.random() - 0.5) * 0.05, (math.random() - 0.5) * 0.05, 0)
		end
		camera.FieldOfView = 70 - math.min(t * 50, 30)
		if t > 1.5 then
			conn:Disconnect()
			UI.static(2.2)
			UI.big("YOU WERE TAKEN", Color3.fromRGB(200, 20, 20), 2.5)
		end
	end)
end

function Effects.escaped()
	play2D(Sounds.Escape, 1)
	UI.flash(Color3.new(1, 1, 1), 2.5, 0)
	UI.big("YOU ESCAPED", Color3.fromRGB(150, 255, 190), 3)
end

function Effects.notify(text: string, kind: string)
	UI.message(text, kind)
	if kind == "key" then
		play2D(Sounds.KeyPickup, 1)
	elseif kind == "whisper" then
		play2D(Sounds.Whisper, 1)
		UI.flash(Color3.new(0, 0, 0), 0.6, 0.6)
	elseif kind == "danger" then
		play2D(Sounds.MonsterScream, 0.6, 0.7)
		shakeUntil = os.clock() + 1
		shakeStrength = 0.15
	end
end

----------------------------------------------------------------------------------------------------
-- Apparitions (only you can see them)
----------------------------------------------------------------------------------------------------

local function rayParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	return params
end

local function figure(cf: CFrame, color: Color3, material: Enum.Material, transparency: number)
	local m = Instance.new("Model")
	m.Name = "Apparition"
	local function p(size: Vector3, offset: CFrame, c: Color3?, shape: Enum.PartType?)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Size = size
		part.CFrame = cf * offset
		part.Color = c or color
		part.Material = material
		part.Transparency = transparency
		if shape then
			part.Shape = shape
		end
		part.Parent = m
		return part
	end
	p(Vector3.new(1.8, 4.6, 0.9), CFrame.new(0, 2.6, 0))
	p(Vector3.new(2.6, 2, 1.2), CFrame.new(0, 0.8, 0)) -- dress
	p(Vector3.new(1.3, 1.5, 1.3), CFrame.new(0, 5.6, 0), nil, Enum.PartType.Ball)
	p(Vector3.new(1.4, 1.6, 0.4), CFrame.new(0, 5.4, 0.45), Color3.fromRGB(10, 10, 10)) -- hair
	for _, sx in { -1, 1 } do
		p(Vector3.new(0.25, 0.3, 0.05), CFrame.new(sx * 0.25, 5.7, -0.64), Color3.new(0, 0, 0))
		p(Vector3.new(0.35, 3.6, 0.35), CFrame.new(sx * 1.05, 2.8, 0))
	end
	m.Parent = workspace
	return m
end

local function fadeAndRemove(m: Model, time: number)
	for _, part in m:GetDescendants() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(time), { Transparency = 1 }):Play()
		end
	end
	Debris:AddItem(m, time + 0.1)
end

-- A pale girl stands silently behind you. Turn around and she vanishes.
local function ghostBehind()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	local back = -Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit
	local hit = workspace:Raycast(hrp.Position, back * 11, rayParams())
	local dist = hit and (hit.Distance - 1.5) or 10
	if dist < 4 then
		return
	end
	local feet = hrp.Position + back * dist - Vector3.new(0, 3, 0)
	local ghost = figure(CFrame.lookAt(feet, feet - back), Color3.fromRGB(215, 225, 235), Enum.Material.ForceField, 0.1)
	play2D(Sounds.Whisper, 0.6, 0.9)
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local toGhost = (feet + Vector3.new(0, 4, 0)) - camera.CFrame.Position
		local looking = camera.CFrame.LookVector:Dot(toGhost.Unit) > 0.75
		if looking or os.clock() - start > 7 then
			conn:Disconnect()
			if looking then
				UI.flash(Color3.new(1, 1, 1), 0.3, 0.7)
				shakeUntil = os.clock() + 0.4
				shakeStrength = 0.25
			end
			fadeAndRemove(ghost, looking and 0.15 or 1)
		end
	end)
end

-- A black shape darts across the room in front of you.
local function shadowRunner()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	local params = rayParams()
	local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit
	local hit = workspace:Raycast(hrp.Position, forward * 22, params)
	local dist = hit and (hit.Distance - 2) or 20
	if dist < 9 then
		return
	end
	local center = hrp.Position + forward * dist
	local right = forward:Cross(Vector3.yAxis)
	local leftHit = workspace:Raycast(center, -right * 10, params)
	local rightHit = workspace:Raycast(center, right * 10, params)
	local a = center - right * ((leftHit and leftHit.Distance or 10) - 1.2)
	local b = center + right * ((rightHit and rightHit.Distance or 10) - 1.2)
	if (a - b).Magnitude < 5 then
		return
	end
	local function at(pos: Vector3)
		return CFrame.lookAt(pos - Vector3.new(0, 3, 0), pos - Vector3.new(0, 3, 0) + (b - a))
	end
	local shadow = figure(at(a), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, 0.05)
	local value = Instance.new("CFrameValue")
	value.Value = at(a)
	value.Changed:Connect(function(cf)
		shadow:PivotTo(cf)
	end)
	local tween = TweenService:Create(value, TweenInfo.new(0.55, Enum.EasingStyle.Linear), { Value = at(b) })
	tween:Play()
	tween.Completed:Connect(function()
		value:Destroy()
		shadow:Destroy()
	end)
end

----------------------------------------------------------------------------------------------------

function Effects.init()
	fearGrade = Instance.new("ColorCorrectionEffect")
	fearGrade.Name = "Fear"
	fearGrade.Parent = Lighting
	blur = Instance.new("BlurEffect")
	blur.Size = 0
	blur.Parent = Lighting

	loop2D(Sounds.Ambience, 0.5)
	heartbeat = loop2D(Sounds.Heartbeat, 0)

	for _, part in CollectionService:GetTagged("FlickerLight") do
		task.spawn(addLight, part)
	end
	CollectionService:GetInstanceAddedSignal("FlickerLight"):Connect(function(part)
		task.spawn(addLight, part)
	end)

	player.CharacterAdded:Connect(function()
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		blur.Size = 0
	end)

	-- random apparitions while you're inside the round
	task.spawn(function()
		while true do
			task.wait(math.random(35, 75))
			if player:GetAttribute("InRound") and not Controls.frozen then
				if math.random() < 0.5 then
					ghostBehind()
				else
					shadowRunner()
				end
			end
		end
	end)

	local fear = 0
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local monster = workspace:FindFirstChild("ThePale")
		local monsterRoot = monster and monster:FindFirstChild("HumanoidRootPart") :: BasePart?
		local monsterPos = monsterRoot and monsterRoot.Position

		updateLights(t, monsterPos)

		-- fear rises as the monster gets close, and spikes when it is hunting you
		local target = 0
		if monsterPos and player:GetAttribute("InRound") then
			local d = (monsterPos - camera.CFrame.Position).Magnitude
			target = math.clamp(1 - (d - 8) / 55, 0, 1)
			if monster:GetAttribute("TargetId") == player.UserId then
				target = math.max(target, 0.65)
			end
		end
		fear += (target - fear) * math.min(1, dt * 3)

		local pulse = 0.5 + 0.5 * math.sin(t * (4 + fear * 8))
		UI.setVignette(0.45 + fear * 0.45 + pulse * fear * 0.1, Color3.new(0, 0, 0):Lerp(Color3.fromRGB(90, 0, 0), fear))
		fearGrade.Saturation = -fear * 0.6
		fearGrade.Contrast = fear * 0.25
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			blur.Size = fear > 0.7 and (fear - 0.7) * 12 * pulse or 0
		end
		if heartbeat then
			heartbeat.Volume = fear * 1.5
			heartbeat.PlaybackSpeed = 0.9 + fear * 0.6
		end

		local shake = fear * 0.12
		if t < shakeUntil then
			shake += shakeStrength
		else
			shakeStrength = 0
		end
		Controls.shake = shake
	end)
end

return Effects
