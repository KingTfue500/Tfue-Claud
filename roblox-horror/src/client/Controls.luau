-- Flashlight (F), sprinting (Shift), battery and stamina, plus head bob.
-- Both actions also get on-screen buttons on mobile.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Config = require(ReplicatedStorage.Shared.Config)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Controls = {}
Controls.frozen = false
Controls.shake = 0 -- set by Effects; extra camera shake on top of the head bob

local flashlightOn = false
local battery = Config.Flashlight.BatteryMax
local stamina = Config.Player.StaminaMax
local sprintHeld = false
local sprinting = false
local exhausted = false
local bobTime = 0

local function getCharacter()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local head = char and char:FindFirstChild("Head")
	if hum and head and hum.Health > 0 then
		return char, hum, head
	end
	return nil
end

local function setFlashlight(on: boolean)
	if on and battery <= 0 then
		UI.message("The batteries are dead...", "warn")
		return
	end
	flashlightOn = on
	remotes.Flashlight:FireServer(on)
end

local function setSprinting(on: boolean)
	if sprinting ~= on then
		sprinting = on
		remotes.Sprint:FireServer(on)
	end
end

function Controls.isFlashlightOn()
	return flashlightOn
end

function Controls.reset()
	flashlightOn = false
	sprinting = false
	exhausted = false
	stamina = Config.Player.StaminaMax
	battery = math.max(battery, Config.Flashlight.BatteryMax * 0.6)
	Controls.frozen = false
end

function Controls.init()
	ContextActionService:BindAction("Flashlight", function(_, state)
		if state == Enum.UserInputState.Begin and getCharacter() and not Controls.frozen then
			setFlashlight(not flashlightOn)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonR1)
	ContextActionService:SetTitle("Flashlight", "Light")
	ContextActionService:SetPosition("Flashlight", UDim2.new(1, -170, 1, -150))

	ContextActionService:BindAction("Sprint", function(_, state)
		if state == Enum.UserInputState.Begin then
			sprintHeld = true
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			sprintHeld = false
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("Sprint", "Run")
	ContextActionService:SetPosition("Sprint", UDim2.new(1, -240, 1, -90))

	player.CharacterAdded:Connect(function()
		Controls.reset()
	end)

	RunService.RenderStepped:Connect(function(dt)
		local char, hum, head = getCharacter()
		if not char then
			return
		end

		-- battery
		if flashlightOn then
			battery -= Config.Flashlight.DrainPerSecond * dt
			if battery <= 0 then
				battery = 0
				setFlashlight(false)
				UI.message("Your flashlight flickers and dies...", "warn")
			end
		else
			battery = math.min(Config.Flashlight.BatteryMax, battery + 0.35 * dt)
		end
		UI.setBattery(battery / Config.Flashlight.BatteryMax)

		-- aim the light where the camera looks, and make it stutter when the battery is low
		local att = head:FindFirstChild("FlashlightAttachment")
		if att then
			local look = camera.CFrame.LookVector
			local cf = CFrame.lookAt(head.Position, head.Position + look) * CFrame.new(0, 0, -0.9)
			att.CFrame = head.CFrame:ToObjectSpace(cf)
			local beam = att:FindFirstChild("Flashlight")
			if beam then
				local lowBattery = battery / Config.Flashlight.BatteryMax < 0.2
				beam.Brightness = if lowBattery and math.random() < 0.08 then 0.2 else Config.Flashlight.Brightness
			end
		end

		-- sprint and stamina
		local moving = hum.MoveDirection.Magnitude > 0.1
		if stamina <= 0 then
			exhausted = true
		elseif exhausted and stamina > Config.Player.StaminaMax * 0.35 then
			exhausted = false
		end
		local wantSprint = sprintHeld and moving and not exhausted and not Controls.frozen
		setSprinting(wantSprint)
		if sprinting then
			stamina = math.max(0, stamina - Config.Player.StaminaDrain * dt)
		else
			stamina = math.min(Config.Player.StaminaMax, stamina + Config.Player.StaminaRegen * dt)
		end
		UI.setStamina(stamina / Config.Player.StaminaMax)

		if Controls.frozen then
			hum.WalkSpeed = 0
		else
			hum.WalkSpeed = sprinting and Config.Player.SprintSpeed or Config.Player.WalkSpeed
		end

		-- field of view and head bob
		local targetFov = sprinting and 80 or 70
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(1, dt * 6)
		end
		local rootPart = char.PrimaryPart
		local velocity = rootPart and rootPart.AssemblyLinearVelocity or Vector3.zero
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local bob = Vector3.zero
		if moving and speed > 1 then
			bobTime += dt * (sprinting and 13 or 8)
			local amount = sprinting and 0.22 or 0.12
			bob = Vector3.new(math.cos(bobTime) * amount, math.abs(math.sin(bobTime)) * amount, 0)
		end
		local s = Controls.shake
		local shake = Vector3.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
		hum.CameraOffset = hum.CameraOffset:Lerp(bob + shake, math.min(1, dt * 12))
	end)
end

return Controls
