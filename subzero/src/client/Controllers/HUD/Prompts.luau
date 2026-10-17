--!strict
-- Eigener ProximityPrompt-Stil (Style = Custom, Abschnitt 9): kleines CRT-Fenster mit
-- Tastensymbol und Halte-Fortschritt als Ring. Auf Touch-Geräten antippbar.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Trove = require(ReplicatedStorage.Shared.Trove)
local ClientState = require(script.Parent.Parent.Parent.Lib.ClientState)
local UiKit = require(script.Parent.Parent.Parent.Lib.UiKit)

local Prompts = {}

local player = Players.LocalPlayer
local GREEN = Config.Colors.CrtGreen
local active: { [ProximityPrompt]: Trove.Trove } = {}

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		return "X"
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	end
	return prompt.KeyboardKeyCode.Name
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	-- eigene Wiederbelebung nicht anzeigen
	if prompt:GetAttribute("OwnerUserId") == player.UserId then
		return
	end
	local adornee = prompt.Parent
	if adornee == nil or not (adornee:IsA("BasePart") or adornee:IsA("Attachment") or adornee:IsA("Model")) then
		return
	end
	local trove = Trove.new()
	active[prompt] = trove
	ClientState.PromptsShown += 1
	trove:Add(function()
		ClientState.PromptsShown = math.max(0, ClientState.PromptsShown - 1)
	end)

	local pg = player:WaitForChild("PlayerGui")
	local bb = Instance.new("BillboardGui")
	bb.Name = "SZPrompt"
	bb.Adornee = adornee :: Instance
	bb.Size = UDim2.fromOffset(230, 64)
	bb.StudsOffset = Vector3.new(0, 0.6, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Active = inputType == Enum.ProximityPromptInputType.Touch
	bb.Parent = pg
	trove:Add(bb)

	local win = UiKit.Frame(bb, "Window", UDim2.new(1, 0, 0, 0), UDim2.new(0, 0, 0.5, 0), Color3.fromRGB(3, 14, 7), 0.15)
	win.AnchorPoint = Vector2.new(0, 0.5)
	win.ClipsDescendants = true
	UiKit.Corner(win, 0, 6)
	UiKit.Stroke(win, Color3.fromRGB(40, 90, 50), 2, 0)
	UiKit.Scanlines(win, 3, 0.75, 26)
	-- Einschalt-Effekt: Fenster öffnet sich vertikal
	UiKit.Tween(win, Config.HUD.CrtOnTime, { Size = UDim2.new(1, 0, 1, 0) }, Enum.EasingStyle.Quad)

	local keyBox = UiKit.Frame(win, "Key", UDim2.fromOffset(48, 48), UDim2.fromOffset(8, 8), Color3.fromRGB(10, 30, 16), 0)
	UiKit.Corner(keyBox, 0, 6)
	UiKit.Stroke(keyBox, GREEN, 1, 0.3)
	local kt = UiKit.Text(keyBox, "KeyText", keyText(prompt, inputType), UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), UiKit.MonoBold, 18, GREEN)
	kt.TextScaled = false
	local ring = UiKit.Ring(keyBox, "Hold", 48, 3, GREEN)
	ring.Frame.Visible = prompt.HoldDuration > 0

	local action = UiKit.Text(win, "Action", "", UDim2.new(1, -70, 0, 26), UDim2.fromOffset(64, 8), UiKit.MonoBold, 20, GREEN)
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.TextTruncate = Enum.TextTruncate.AtEnd
	local object = UiKit.Text(win, "Object", "", UDim2.new(1, -70, 0, 18), UDim2.fromOffset(64, 34), UiKit.Label, 11, Color3.fromRGB(150, 220, 160))
	object.TextXAlignment = Enum.TextXAlignment.Left
	object.TextTruncate = Enum.TextTruncate.AtEnd

	local function refreshText()
		local txt = prompt.ActionText
		if prompt.Name == "HidePrompt" and player:GetAttribute("InLocker") == true then
			txt = "Leave"
		end
		action.Text = string.upper(txt)
		object.Text = string.upper(prompt.ObjectText)
	end
	refreshText()
	trove:Connect(prompt:GetPropertyChangedSignal("ActionText"), refreshText)
	trove:Connect(prompt:GetPropertyChangedSignal("ObjectText"), refreshText)

	-- Halte-Fortschritt
	local holdStart: number? = nil
	trove:Connect(prompt.PromptButtonHoldBegan, function()
		holdStart = os.clock()
	end)
	trove:Connect(prompt.PromptButtonHoldEnded, function()
		holdStart = nil
		ring:SetProgress(0)
	end)
	trove:Connect(prompt.Triggered, function()
		holdStart = nil
		ring:SetProgress(0)
		win.BackgroundColor3 = Color3.fromRGB(30, 90, 40)
		UiKit.Tween(win, 0.3, { BackgroundColor3 = Color3.fromRGB(3, 14, 7) })
	end)
	trove:Connect(RunService.RenderStepped, function()
		local hs = holdStart
		if hs and prompt.HoldDuration > 0 then
			ring:SetProgress((os.clock() - hs) / prompt.HoldDuration)
		end
	end)

	-- Touch: Fenster antippen = Taste halten
	if inputType == Enum.ProximityPromptInputType.Touch or UserInputService.TouchEnabled then
		local btn = Instance.new("TextButton")
		btn.Name = "Tap"
		btn.Size = UDim2.fromScale(1, 1)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.Parent = win
		trove:Connect(btn.InputBegan, function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldBegin()
			end
		end)
		trove:Connect(btn.InputEnded, function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldEnd()
			end
		end)
	end
end

local function hide(prompt: ProximityPrompt)
	local trove = active[prompt]
	if trove then
		active[prompt] = nil
		trove:Clean()
	end
end

function Prompts.Start()
	ProximityPromptService.PromptShown:Connect(show)
	ProximityPromptService.PromptHidden:Connect(hide)
end

return Prompts
