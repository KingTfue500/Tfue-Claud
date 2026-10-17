-- The on-screen HUD: objective, timer, messages, battery/stamina bars, vignette,
-- full-screen flashes and TV static. Everything is built in code.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UI = {}

local gui: ScreenGui
local objective: TextLabel
local timer: TextLabel
local messages: Frame
local batteryFill: Frame
local staminaFill: Frame
local flashFrame: Frame
local staticFrame: Frame
local edges: { Frame } = {}
local bigText: TextLabel

local KIND_COLORS = {
	info = Color3.fromRGB(220, 215, 205),
	key = Color3.fromRGB(255, 205, 90),
	death = Color3.fromRGB(220, 40, 40),
	danger = Color3.fromRGB(230, 70, 60),
	escape = Color3.fromRGB(120, 255, 170),
	exit = Color3.fromRGB(120, 255, 170),
	warn = Color3.fromRGB(255, 160, 70),
	whisper = Color3.fromRGB(170, 170, 185),
}

local function new(className: string, props: { [string]: any }, parent: Instance?)
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function bar(name: string, color: Color3, y: number)
	local frame = new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, y),
		Size = UDim2.fromOffset(180, 8),
		BackgroundColor3 = Color3.fromRGB(15, 15, 18),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, frame)
	local fill = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, frame)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, fill)
	new("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 0, -2),
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Font = Enum.Font.SpecialElite,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(190, 185, 175),
		Text = name,
	}, frame)
	return fill
end

function UI.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = new("ScreenGui", {
		Name = "HorrorUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)

	-- vignette: four edges fading toward the centre
	for _, data in {
		{ UDim2.fromScale(1, 0.38), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.38), UDim2.fromScale(0, 0.62), -90 },
		{ UDim2.fromScale(0.3, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.3, 1), UDim2.fromScale(0.7, 0), 180 },
	} do
		local edge = new("Frame", {
			Size = data[1],
			Position = data[2],
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
		}, gui)
		new("UIGradient", {
			Rotation = data[3],
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, edge)
		table.insert(edges, edge)
	end

	objective = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.new(0.8, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.SpecialElite,
		TextSize = 24,
		TextColor3 = Color3.fromRGB(225, 220, 210),
		TextStrokeTransparency = 0.5,
		Text = "",
	}, gui)
	timer = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.new(0.5, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.SpecialElite,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(160, 150, 140),
		TextStrokeTransparency = 0.6,
		Text = "",
	}, gui)

	messages = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.82, 0),
		Size = UDim2.new(0.9, 0, 0.3, 0),
		BackgroundTransparency = 1,
	}, gui)
	new("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, messages)

	bigText = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.9, 0.18),
		BackgroundTransparency = 1,
		Font = Enum.Font.Creepster,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(200, 20, 20),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = "",
		ZIndex = 20,
	}, gui)

	batteryFill = bar("FLASHLIGHT", Color3.fromRGB(255, 220, 150), -44)
	staminaFill = bar("STAMINA", Color3.fromRGB(170, 200, 230), -18)

	new("TextLabel", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -14),
		Size = UDim2.fromOffset(300, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.SpecialElite,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(140, 135, 125),
		Text = "[F] flashlight   [Shift] sprint",
	}, gui)

	flashFrame = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 10,
	}, gui)

	staticFrame = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 15,
	}, gui)
	for _ = 1, 90 do
		new("Frame", {
			Size = UDim2.fromScale(math.random(5, 30) / 100, math.random(1, 4) / 100),
			BorderSizePixel = 0,
			ZIndex = 16,
		}, staticFrame)
	end
end

function UI.setObjective(text: string, sub: string?)
	objective.Text = text
	timer.Text = sub or ""
end

function UI.setBattery(fraction: number)
	batteryFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	batteryFill.BackgroundColor3 = fraction < 0.2 and Color3.fromRGB(220, 60, 50) or Color3.fromRGB(255, 220, 150)
end

function UI.setStamina(fraction: number)
	staminaFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
end

function UI.setVignette(strength: number, color: Color3)
	for _, edge in edges do
		edge.BackgroundTransparency = 1 - math.clamp(strength, 0, 1)
		edge.BackgroundColor3 = color
	end
end

function UI.message(text: string, kind: string?)
	kind = kind or "info"
	local whisper = kind == "whisper"
	local label = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, whisper and 30 or 26),
		BackgroundTransparency = 1,
		Font = whisper and Enum.Font.Creepster or Enum.Font.SpecialElite,
		TextSize = whisper and 30 or 22,
		TextColor3 = KIND_COLORS[kind] or KIND_COLORS.info,
		TextStrokeTransparency = 0.4,
		TextTransparency = 1,
		Text = text,
		LayoutOrder = math.floor(os.clock() * 100),
	}, messages)
	TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	task.delay(whisper and 3.5 or 6, function()
		local fade = TweenService:Create(label, TweenInfo.new(1.2), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		label:Destroy()
	end)
	-- keep at most 5 lines on screen
	local lines = {}
	for _, child in messages:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(lines, child)
		end
	end
	table.sort(lines, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #lines - 5 do
		lines[i]:Destroy()
	end
end

function UI.big(text: string, color: Color3, duration: number)
	bigText.Text = text
	bigText.TextColor3 = color
	bigText.TextTransparency = 0
	bigText.TextStrokeTransparency = 0.3
	task.delay(duration, function()
		TweenService:Create(bigText, TweenInfo.new(1.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

function UI.flash(color: Color3, fadeTime: number, startTransparency: number?)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = startTransparency or 0
	TweenService:Create(flashFrame, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
end

-- Flickering TV static, for deaths.
function UI.static(duration: number)
	staticFrame.Visible = true
	staticFrame.BackgroundTransparency = 0
	local bars = staticFrame:GetChildren()
	local stop = os.clock() + duration
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local left = stop - os.clock()
		if left <= 0 then
			conn:Disconnect()
			staticFrame.Visible = false
			return
		end
		local fade = math.clamp(1 - left / 0.6, 0, 1) -- fade out over the last 0.6s
		staticFrame.BackgroundTransparency = fade
		for _, b in bars do
			b.Position = UDim2.fromScale(math.random() * 1.1 - 0.1, math.random())
			local v = math.random(60, 255) / 255
			b.BackgroundColor3 = Color3.new(v, v, v)
			b.BackgroundTransparency = math.max(fade, math.random() * 0.6)
		end
	end)
end

return UI
