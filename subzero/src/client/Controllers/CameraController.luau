--!strict
-- CameraController (Abschnitt 10.1): Erste Person fest (LockFirstPerson), Kamerahöhe je Haltung
-- (liegend 1,5 Studs über dem Boden), Wippen beim Gehen, Wackeln (Jagd, Infraschall, Unterkühlung,
-- Aufzug), FOV-Wackeln ±1,5° nahe dem Wesen, Kill-Kinematik, Luken-Kamerafahrt, Zuschauer-Modus.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(ReplicatedStorage.Shared.Util)
local ClientState = require(script.Parent.Parent.Lib.ClientState)
local Settings = require(script.Parent.Parent.Lib.Settings)
local InputController = require(script.Parent.InputController)

local CameraController = {}
CameraController.Name = "CameraController"

local player = Players.LocalPlayer
local C = Config.Camera

local offsetY = 0
local bobTime = 0
local rideShakeUntil = 0
local spectateIndex = 1
local spectateTarget: Player? = nil
local lastMode: string = ""
local roll = 0
local lastYaw = 0

local function camera(): Camera
	return Workspace.CurrentCamera :: Camera
end

function CameraController.GetCreature(): Model?
	for _, c in CollectionService:GetTagged("Creature") do
		if c:IsA("Model") and c.PrimaryPart then
			return c
		end
	end
	return nil
end

-- Rauschen für natürliches Wackeln
local function shakeAngles(t: number, amp: number): CFrame
	if amp <= 0.0001 then
		return CFrame.new()
	end
	local a = amp * Settings.ShakeFactor()
	local x = math.noise(t * 9, 0.3, 1.7) * a
	local y = math.noise(0.7, t * 9, 4.1) * a
	local z = math.noise(2.3, 5.9, t * 7) * a * 0.6
	return CFrame.Angles(math.rad(x * 6), math.rad(y * 6), math.rad(z * 6))
end

local function isOut(): boolean
	local st = Util.GetState(player)
	return st == "Dead" or st == "Missing" or st == "Escaped"
end

----------------------------------------------------------------------
-- Zuschauer-Modus: zwischen überlebenden Teammitgliedern wechseln
----------------------------------------------------------------------
local function spectateCandidates(): { Player }
	local out: { Player } = {}
	for _, p in Players:GetPlayers() do
		if p ~= player then
			local st = Util.GetState(p)
			if (st == "Alive" or st == "Downed" or st == "Grabbed") and Util.GetHumanoid(p) then
				table.insert(out, p)
			end
		end
	end
	return out
end

function CameraController.GetSpectateTarget(): Player?
	return spectateTarget
end

local function applySpectate()
	local list = spectateCandidates()
	if #list == 0 then
		spectateTarget = nil
		return
	end
	spectateIndex = ((spectateIndex - 1) % #list) + 1
	spectateTarget = list[spectateIndex]
	local hum = Util.GetHumanoid(list[spectateIndex])
	if hum then
		camera().CameraSubject = hum
	end
end

local function setMode(mode: string)
	if mode == lastMode then
		return
	end
	lastMode = mode
	local cam = camera()
	if mode == "FirstPerson" then
		player.CameraMaxZoomDistance = 0.5
		player.CameraMinZoomDistance = 0.5
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		cam.CameraType = Enum.CameraType.Custom
		local hum = Util.GetHumanoid(player)
		if hum then
			cam.CameraSubject = hum
		end
		ClientState.Spectating = false
	elseif mode == "Spectate" then
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = 18
		player.CameraMinZoomDistance = 6
		cam.CameraType = Enum.CameraType.Custom
		ClientState.Spectating = true
		applySpectate()
	end
end

----------------------------------------------------------------------
-- Kinematiken
----------------------------------------------------------------------
local function killCinematic(creature: Model)
	ClientState.SetCinematic(true)
	local cam = camera()
	cam.CameraType = Enum.CameraType.Scriptable
	local hand = creature:FindFirstChild("RightHand", true)
	local grab = if hand then hand:FindFirstChild("GrabPoint") else nil
	local head = creature:FindFirstChild("Head")
	local t0 = os.clock()
	local startCF = cam.CFrame
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - t0) / C.KillTweenTime, 0, 1)
		local eased = TweenService:GetValue(a, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local target: CFrame
		if grab and grab:IsA("Attachment") and head and head:IsA("BasePart") then
			local p = grab.WorldPosition + Vector3.new(0, 1.2, 0)
			target = CFrame.lookAt(p, head.Position)
		else
			target = startCF
		end
		local shake = shakeAngles(os.clock(), 0.6)
		cam.CFrame = startCF:Lerp(target, eased) * shake
	end)
	task.delay(Config.Health.KillCinematicTime + 0.6, function()
		conn:Disconnect()
		ClientState.SetCinematic(false)
		lastMode = ""
	end)
end

local function pathCinematic(startCF: CFrame, endCF: CFrame, duration: number)
	ClientState.SetCinematic(true)
	local cam = camera()
	cam.CameraType = Enum.CameraType.Scriptable
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - t0) / duration, 0, 1)
		local eased = TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		cam.CFrame = startCF:Lerp(endCF, eased) * shakeAngles(os.clock(), 0.08)
	end)
	task.delay(duration, function()
		conn:Disconnect()
		ClientState.SetCinematic(false)
		lastMode = ""
	end)
end

----------------------------------------------------------------------
-- Pro Frame
----------------------------------------------------------------------
local function update(dt: number)
	local cam = camera()
	if ClientState.Cinematic then
		return
	end
	if isOut() then
		setMode("Spectate")
		if spectateTarget == nil or Util.GetHumanoid(spectateTarget) == nil or not table.find(spectateCandidates(), spectateTarget) then
			applySpectate()
		end
		return
	end
	setMode("FirstPerson")
	local hum = Util.GetHumanoid(player)
	local root = Util.GetRoot(player)
	if hum == nil or root == nil then
		return
	end
	if cam.CameraSubject ~= hum then
		cam.CameraSubject = hum
	end
	local t = os.clock()

	-- Kamerahöhe je Haltung (Liegen: 1,5 Studs über dem Boden)
	local stance = Util.StrAttr(player, "Stance", "Stand")
	local target = Config.Movement.CameraOffsetY[stance] or 0
	offsetY += (target - offsetY) * math.min(1, dt * 10)

	-- Wippen beim Gehen
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local bob = Vector3.zero
	if speed > 1 and hum.FloorMaterial ~= Enum.Material.Air then
		bobTime += dt * speed / 10 * C.BobFrequency * math.pi * 2
		local amp = C.BobAmplitude * math.clamp(speed / 10, 0.3, 1.8) * Settings.ShakeFactor()
		bob = Vector3.new(math.cos(bobTime * 0.5) * amp * 0.6, math.abs(math.sin(bobTime)) * amp, 0)
	end
	hum.CameraOffset = Vector3.new(0, offsetY, 0) + bob

	-- Wackeln
	local amp = 0
	local fovExtra = 0
	local creature = CameraController.GetCreature()
	if creature and creature.PrimaryPart and creature:GetAttribute("InVent") ~= true then
		local aiState = creature:GetAttribute("AIState")
		local d = (creature.PrimaryPart.Position - cam.CFrame.Position).Magnitude
		if aiState ~= "Sleeping" then
			-- Infraschall: stärker, je näher das Wesen
			if d < Config.Entity.InfrasoundRange then
				amp += C.InfrasoundShakeAmp * (1 - d / Config.Entity.InfrasoundRange)
			end
			if (aiState == "Hunt" or aiState == "Frenzy") and creature:GetAttribute("TargetUserId") == player.UserId then
				amp += C.HuntShakeAmp
			end
			if d < Config.Entity.FovWobbleRange then
				fovExtra = math.sin(t * 2.3) * Config.Entity.FovWobbleDeg * (1 - d / Config.Entity.FovWobbleRange) * Settings.ShakeFactor()
			end
		end
	end
	local stage = Util.StrAttr(player, "HypoStage", "Normal")
	if stage == "Severe" then
		amp += C.HypoShakeAmp
	end
	if t < rideShakeUntil then
		amp += 0.25
	end

	-- leichtes Neigen in Kurven
	local _, yaw, _ = cam.CFrame:ToOrientation()
	local dyaw = yaw - lastYaw
	if dyaw > math.pi then
		dyaw -= math.pi * 2
	elseif dyaw < -math.pi then
		dyaw += math.pi * 2
	end
	lastYaw = yaw
	local targetRoll = math.clamp(-dyaw / math.max(dt, 1 / 240) * 0.02, -1, 1) * math.rad(C.LeanSideDeg) * math.clamp(speed / 10, 0, 1)
	roll += (targetRoll - roll) * math.min(1, dt * 6)

	cam.FieldOfView = C.FieldOfView + fovExtra
	cam.CFrame = cam.CFrame * shakeAngles(t, amp) * CFrame.Angles(0, 0, roll * Settings.ShakeFactor())
end

function CameraController.Init() end

function CameraController.Start()
	RunService:BindToRenderStep("SubZeroCamera", Enum.RenderPriority.Camera.Value + 1, update)
	Net.Event("PlayCinematic").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Kill" and typeof(data) == "Instance" and data:IsA("Model") then
			killCinematic(data)
		elseif kind == "Hatches" and type(data) == "table" then
			local s = data.Start
			local e = data.End
			if typeof(s) == "CFrame" and typeof(e) == "CFrame" then
				pathCinematic(s, e, if type(data.Duration) == "number" then data.Duration else 5)
			end
		end
	end)
	Net.Event("ScreenEffect").OnClientEvent:Connect(function(kind: string, duration: any)
		if kind == "ElevatorRide" and type(duration) == "number" then
			rideShakeUntil = os.clock() + duration
		end
	end)
	InputController.SpectateCycle:Connect(function(dir: number)
		spectateIndex += dir
		applySpectate()
	end)
	player:GetAttributeChangedSignal("State"):Connect(function()
		lastMode = ""
	end)
	player.CharacterAdded:Connect(function()
		lastMode = ""
		offsetY = 0
	end)
end

return CameraController
