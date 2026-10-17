--!strict
-- InputController: alle Aktionen über ContextActionService mit Touch-Knöpfen und Gamepad-Belegung
-- (Abschnitt 9: Handy und Konsole).
--   Z / Y           Liegen umschalten        C / B           Ducken umschalten
--   Shift / L3      Sprinten (halten)        Linksklick / R2 Item benutzen
--   G / R1          Werfen                   F / DPad hoch   Taschenlampe
--   Rechtsklick/L2  Wärmebild-Scanner        1-4 / DPad l/r  Gürtel-Slot
--   Backspace / DPad runter  Fallenlassen    E               Interaktion (ProximityPrompt), Batterie
--   P / Start       Einstellungen

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Util = require(ReplicatedStorage.Shared.Util)
local ClientState = require(script.Parent.Parent.Lib.ClientState)

local InputController = {}
InputController.Name = "InputController"

InputController.SettingsToggled = Signal.new() :: Signal.Signal<>
InputController.SpectateCycle = Signal.new() :: Signal.Signal<number>
InputController.CloseRequested = Signal.new() :: Signal.Signal<>

local player = Players.LocalPlayer
local Pass = Enum.ContextActionResult.Pass
local Sink = Enum.ContextActionResult.Sink

local function inRound(): boolean
	return Util.GetState(player) == "Alive"
end

local function canMove(): boolean
	local st = Util.GetState(player)
	return (st == "Alive" or st == "Lobby") and not ClientState.InputBlocked()
end

local function isSpectating(): boolean
	local st = Util.GetState(player)
	return st == "Dead" or st == "Missing" or st == "Escaped"
end

local function bind(name: string, touch: boolean, fn: (Enum.UserInputState) -> boolean, ...: Enum.KeyCode | Enum.UserInputType)
	ContextActionService:BindAction(name, function(_n: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
		if fn(state) then
			return Sink
		end
		return Pass
	end, touch, ...)
end

local function toggleStance(target: string)
	local cur = Util.StrAttr(player, "Stance", "Stand")
	Net.Event("RequestStance"):FireServer(if cur == target then "Stand" else target)
end

local function setupTouch()
	if not UserInputService.TouchEnabled then
		return
	end
	type Btn = { Action: string, Title: string, Pos: UDim2 }
	local layout: { Btn } = {
		{ Action = "SZ_Prone", Title = "LIE", Pos = UDim2.new(1, -95, 1, -230) },
		{ Action = "SZ_Crouch", Title = "DUCK", Pos = UDim2.new(1, -165, 1, -200) },
		{ Action = "SZ_Sprint", Title = "RUN", Pos = UDim2.new(1, -235, 1, -150) },
		{ Action = "SZ_Use", Title = "USE", Pos = UDim2.new(1, -95, 1, -160) },
		{ Action = "SZ_Throw", Title = "THROW", Pos = UDim2.new(1, -165, 1, -130) },
		{ Action = "SZ_Flashlight", Title = "LAMP", Pos = UDim2.new(1, -95, 1, -300) },
		{ Action = "SZ_Scanner", Title = "SCAN", Pos = UDim2.new(1, -165, 1, -270) },
	}
	for _, l in layout do
		ContextActionService:SetTitle(l.Action, l.Title)
		ContextActionService:SetPosition(l.Action, l.Pos)
	end
end

function InputController.Init()
	-- Während eine Oberfläche offen ist, keine ProximityPrompts (E schließt dann die Oberfläche)
	ClientState.UiChanged:Connect(function()
		game:GetService("ProximityPromptService").Enabled = not ClientState.IsUiOpen()
	end)
end

function InputController.Start()
	-- Reset-Knopf im Roblox-Menü abschalten (Tod nur durch Spielregeln)
	task.spawn(function()
		for _ = 1, 20 do
			local ok = pcall(function()
				StarterGui:SetCore("ResetButtonCallback", false)
			end)
			if ok then
				break
			end
			task.wait(0.5)
		end
	end)

	bind("SZ_Prone", true, function(state)
		if state == Enum.UserInputState.Begin and canMove() then
			toggleStance("Prone")
			return true
		end
		return false
	end, Enum.KeyCode.Z, Enum.KeyCode.ButtonY)

	bind("SZ_Crouch", true, function(state)
		if state == Enum.UserInputState.Begin and canMove() then
			toggleStance("Crouch")
			return true
		end
		return false
	end, Enum.KeyCode.C, Enum.KeyCode.ButtonB)

	bind("SZ_Sprint", true, function(state)
		if state == Enum.UserInputState.Begin then
			Net.Event("RequestSprint"):FireServer(canMove())
			return true
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			Net.Event("RequestSprint"):FireServer(false)
			return true
		end
		return false
	end, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)

	bind("SZ_Use", true, function(state)
		if state ~= Enum.UserInputState.Begin then
			return false
		end
		if isSpectating() and not ClientState.InputBlocked() then
			InputController.SpectateCycle:Fire(1)
			return true
		end
		if inRound() and not ClientState.InputBlocked() then
			Net.Event("UseItem"):FireServer()
			return true
		end
		return false
	end, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)

	bind("SZ_Scanner", true, function(state)
		if state ~= Enum.UserInputState.Begin then
			return false
		end
		if isSpectating() and not ClientState.InputBlocked() then
			InputController.SpectateCycle:Fire(-1)
			return true
		end
		if inRound() and not ClientState.InputBlocked() then
			Net.Event("UseScanner"):FireServer()
			return true
		end
		return false
	end, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)

	bind("SZ_Throw", true, function(state)
		if state == Enum.UserInputState.Begin and inRound() and not ClientState.InputBlocked() then
			local cam = Workspace.CurrentCamera
			if cam then
				Net.Event("ThrowItem"):FireServer(cam.CFrame.LookVector)
			end
			return true
		end
		return false
	end, Enum.KeyCode.G, Enum.KeyCode.ButtonR1)

	bind("SZ_Flashlight", true, function(state)
		if state == Enum.UserInputState.Begin and inRound() and not ClientState.InputBlocked() then
			Net.Event("ToggleFlashlight"):FireServer()
			return true
		end
		return false
	end, Enum.KeyCode.F, Enum.KeyCode.DPadUp)

	bind("SZ_Drop", false, function(state)
		if state == Enum.UserInputState.Begin and inRound() and not ClientState.InputBlocked() then
			Net.Event("DropItem"):FireServer()
			return true
		end
		return false
	end, Enum.KeyCode.Backspace, Enum.KeyCode.DPadDown)

	local slotKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
	for i, key in slotKeys do
		bind("SZ_Slot" .. i, false, function(state)
			if state == Enum.UserInputState.Begin and inRound() and not ClientState.InputBlocked() then
				Net.Event("SelectSlot"):FireServer(i)
				return true
			end
			return false
		end, key)
	end
	bind("SZ_SlotCycle", false, function(state)
		return state == Enum.UserInputState.Begin
	end, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight)
	-- DPad links/rechts: Slots durchschalten
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if input.KeyCode == Enum.KeyCode.DPadLeft or input.KeyCode == Enum.KeyCode.DPadRight then
			if isSpectating() then
				InputController.SpectateCycle:Fire(if input.KeyCode == Enum.KeyCode.DPadRight then 1 else -1)
			elseif inRound() and not ClientState.InputBlocked() then
				local cur = Util.NumAttr(player, "ActiveSlot", 1)
				local dir = if input.KeyCode == Enum.KeyCode.DPadRight then 1 else -1
				local nextSlot = ((cur - 1 + dir) % Config.Items.BeltSlots) + 1
				Net.Event("SelectSlot"):FireServer(nextSlot)
			end
			return
		end
		-- E schließt offene Oberflächen (Prompts sind dann clientseitig deaktiviert)
		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonB then
			if ClientState.IsUiOpen() then
				InputController.CloseRequested:Fire()
				return
			end
		end
		if processed then
			return
		end
		-- E: Batterie in die Taschenlampe (nur wenn kein Prompt sichtbar ist)
		if input.KeyCode == Enum.KeyCode.E and inRound() and ClientState.PromptsShown == 0 and not ClientState.InputBlocked() then
			local active = Util.NumAttr(player, "ActiveSlot", 1)
			if player:GetAttribute("Slot" .. active) == "Battery" then
				Net.Event("UseItem"):FireServer()
			end
		end
		if input.KeyCode == Enum.KeyCode.P or input.KeyCode == Enum.KeyCode.ButtonStart then
			InputController.SettingsToggled:Fire()
		end
	end)
	-- Mausrad: Slots wechseln
	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if processed or input.UserInputType ~= Enum.UserInputType.MouseWheel then
			return
		end
		if inRound() and not ClientState.InputBlocked() then
			local cur = Util.NumAttr(player, "ActiveSlot", 1)
			local dir = if input.Position.Z > 0 then -1 else 1
			Net.Event("SelectSlot"):FireServer(((cur - 1 + dir) % Config.Items.BeltSlots) + 1)
		end
	end)
	setupTouch()

	-- Blickrichtung (Nicken) für die Kopf-IK anderer Spieler, 10 Hz
	local lastPitch = 999
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local cam = Workspace.CurrentCamera
		if cam and Util.GetCharacter(player) then
			local pitch = math.deg(math.asin(math.clamp(cam.CFrame.LookVector.Y, -1, 1)))
			if math.abs(pitch - lastPitch) >= 2 then
				lastPitch = pitch
				Net.Unreliable("LookDir"):FireServer(pitch)
			end
		end
	end)
end

return InputController
