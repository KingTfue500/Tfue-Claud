--!strict
-- TerminalController (Abschnitt 9, Terminals): Vollbild-CRT-Oberflächen mit grüner/bernsteinfarbener
-- Monochrom-Schrift, Scanlines, gewölbtem Rahmen, Einschalt-Effekt (weiße Linie öffnet sich vertikal,
-- 0,3 s) und Ausschalt-Effekt (umgekehrt, mit Nachleuchten).
--   Loadout     Lobby-Spind: Kleidung + 2 Start-Items
--   Centrifuge  Phiolen einsetzen (Reihenfolge zählt)
--   Generator   Anlasser-Minispiel: im grünen Bereich klicken
-- Außerdem der CRT-Übergang beim Abstieg (Ausschalten, Teleport, Einschalten).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Trove = require(ReplicatedStorage.Shared.Trove)
local Util = require(ReplicatedStorage.Shared.Util)
local ClientState = require(script.Parent.Parent.Lib.ClientState)
local UiKit = require(script.Parent.Parent.Lib.UiKit)
local AudioController = require(script.Parent.AudioController)
local InputController = require(script.Parent.InputController)

local TerminalController = {}
TerminalController.Name = "TerminalController"

local player = Players.LocalPlayer
local GREEN = Config.Colors.CrtGreen
local AMBER = Config.Colors.CrtAmber

local gui: ScreenGui
local current: { Kind: string, Trove: Trove.Trove, Screen: Frame, Content: Frame }? = nil
local transition: Frame

----------------------------------------------------------------------
-- CRT-Effekte
----------------------------------------------------------------------
-- Einschalten: weiße Linie öffnet sich vertikal (0,3 s)
local function crtOn(screen: Frame)
	local line = UiKit.Frame(screen, "OnLine", UDim2.new(1, 0, 0, 2), UDim2.fromScale(0, 0.5), Color3.new(1, 1, 1), 0)
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.ZIndex = 60
	local cover = UiKit.Frame(screen, "Cover", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 0)
	cover.ZIndex = 59
	UiKit.Tween(line, Config.HUD.CrtOnTime, { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1 })
	UiKit.Tween(cover, Config.HUD.CrtOnTime, { BackgroundTransparency = 1 })
	task.delay(Config.HUD.CrtOnTime + 0.05, function()
		line:Destroy()
		cover:Destroy()
	end)
end

-- Ausschalten: Bild fällt auf eine weiße Linie zusammen, dann Punkt mit Nachleuchten
local function crtOff(target: Frame, done: (() -> ())?)
	local t = Config.HUD.CrtOffTime
	local cover = UiKit.Frame(target, "OffCover", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 1)
	cover.ZIndex = 61
	local line = UiKit.Frame(target, "OffLine", UDim2.new(1, 0, 1, 0), UDim2.fromScale(0, 0.5), Color3.new(1, 1, 1), 0.9)
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.ZIndex = 62
	UiKit.Tween(cover, t * 0.6, { BackgroundTransparency = 0 })
	UiKit.Tween(line, t * 0.6, { Size = UDim2.new(1, 0, 0, 2), BackgroundTransparency = 0 })
	task.delay(t * 0.6, function()
		UiKit.Tween(line, t * 0.4, { Size = UDim2.fromOffset(4, 2), Position = UDim2.new(0.5, -2, 0.5, 0) })
		task.wait(t * 0.4)
		-- Nachleuchten
		UiKit.Tween(line, 0.6, { BackgroundTransparency = 1 })
		task.wait(0.6)
		line:Destroy()
		cover:Destroy()
		if done then
			done()
		end
	end)
end

----------------------------------------------------------------------
-- Rahmen eines Terminals
----------------------------------------------------------------------
local function closeTerminal()
	local c = current
	if c == nil then
		return
	end
	current = nil
	AudioController.Play2D("UiClick", 0.6)
	crtOff(c.Screen, function()
		c.Trove:Clean()
	end)
	ClientState.SetUi("Terminal", false)
end

local function openFrame(kind: string, title: string, color: Color3): (Trove.Trove, Frame)
	if current then
		current.Trove:Clean()
		current = nil
	end
	local trove = Trove.new()
	local dim = UiKit.Frame(gui, "Terminal_" .. kind, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 0.45)
	trove:Add(dim)
	-- Gehäuse und gewölbter Bildschirm
	local bezel = UiKit.Frame(dim, "Bezel", UDim2.fromOffset(740, 520), UDim2.new(0.5, -370, 0.5, -260), Color3.fromRGB(150, 145, 128), 0)
	UiKit.Corner(bezel, 0, 26)
	UiKit.Gradient(bezel, ColorSequence.new(Color3.fromRGB(175, 170, 150), Color3.fromRGB(110, 105, 92)), 90)
	local screen = UiKit.Frame(bezel, "Screen", UDim2.new(1, -60, 1, -70), UDim2.fromOffset(30, 26), Color3.fromRGB(3, 12, 6), 0)
	screen.ClipsDescendants = true
	UiKit.Corner(screen, 0.06)
	UiKit.Stroke(screen, Color3.fromRGB(30, 30, 28), 6, 0)
	local glow = UiKit.Frame(screen, "Glow", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), color, 0.94)
	UiKit.Gradient(glow, ColorSequence.new(color), 0, NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 1) }))
	local content = UiKit.Frame(screen, "Content", UDim2.new(1, -40, 1, -40), UDim2.fromOffset(20, 20), Color3.new(0, 0, 0), 1)
	local head = UiKit.Text(content, "Title", title, UDim2.new(1, 0, 0, 30), UDim2.fromScale(0, 0), UiKit.MonoBold, 24, color)
	head.TextXAlignment = Enum.TextXAlignment.Left
	UiKit.Frame(content, "Rule", UDim2.new(1, 0, 0, 2), UDim2.fromOffset(0, 34), color, 0.4)
	local sl = UiKit.Scanlines(screen, 3, 0.72, 150)
	sl.ZIndex = 55
	UiKit.Vignette(screen, Color3.new(0, 0, 0), 0.18, 0.2)
	local brand = UiKit.Text(bezel, "Brand", "EREBOS SYSTEMS  MK-II", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 1, -36), UiKit.Label, 11, Color3.fromRGB(70, 66, 56))
	brand.TextXAlignment = Enum.TextXAlignment.Center
	local close = UiKit.Button(content, "Close", "[E] EXIT", UDim2.fromOffset(110, 28), UDim2.new(1, -110, 0, 0), color)
	trove:Connect(close.MouseButton1Click, closeTerminal)
	crtOn(screen)
	AudioController.Play2D("UiBeep", 0.6)
	current = { Kind = kind, Trove = trove, Screen = screen, Content = content }
	ClientState.SetUi("Terminal", true)
	return trove, content
end

local function line(content: Frame, name: string, text: string, y: number, color: Color3, size: number?): TextLabel
	local l = UiKit.Text(content, name, text, UDim2.new(1, 0, 0, (size or 20) + 6), UDim2.fromOffset(0, y), UiKit.Mono, size or 20, color)
	l.TextXAlignment = Enum.TextXAlignment.Left
	return l
end

----------------------------------------------------------------------
-- Lobby-Spind: Kleidung und 2 Start-Items
----------------------------------------------------------------------
local function openLoadout(data: { [string]: any })
	local _trove, content = openFrame("Loadout", "EQUIPMENT LOCKER", GREEN)
	local clothing = if type(data.Clothing) == "string" then data.Clothing else Config.Items.DefaultClothing
	local items = {
		if type(data.Item1) == "string" then data.Item1 else Config.Items.DefaultLoadout[1],
		if type(data.Item2) == "string" then data.Item2 else Config.Items.DefaultLoadout[2],
	}
	local choices = Config.Items.LoadoutChoices
	line(content, "ClothHead", "CLOTHING", 50, GREEN, 18)
	local clothBtns: { [string]: TextButton } = {}
	local clothDesc = line(content, "ClothDesc", "", 120, Color3.fromRGB(150, 220, 160), 16)
	local itemLabels: { TextLabel } = {}
	local status = line(content, "Status", "", 360, AMBER, 18)

	local function refresh()
		for id, b in clothBtns do
			b.BackgroundColor3 = if id == clothing then Color3.fromRGB(30, 90, 40) else Color3.fromRGB(6, 16, 9)
		end
		local info = Config.ClothingInfo[clothing]
		clothDesc.Text = if info then info.Desc else ""
		for i, l in itemLabels do
			local info2 = Config.ItemInfo[items[i]]
			l.Text = string.format("SLOT %d:  %s", i, if info2 then info2.Name else items[i])
		end
		local valid = not (items[1] == items[2] and items[1] ~= "Flare")
		status.Text = if valid then "" else "ONLY FLARES MAY BE TAKEN TWICE"
	end

	for i, id in Config.Items.ClothingChoices do
		local info = Config.ClothingInfo[id]
		local b = UiKit.Button(content, "Cloth_" .. id, if info then info.Name else id, UDim2.fromOffset(220, 34), UDim2.fromOffset((i - 1) * 240, 78), GREEN)
		clothBtns[id] = b
		b.MouseButton1Click:Connect(function()
			clothing = id
			AudioController.Play2D("UiClick", 0.5)
			refresh()
		end)
	end
	line(content, "ItemsHead", "STARTING GEAR (2)", 160, GREEN, 18)
	for i = 1, 2 do
		local y = 190 + (i - 1) * 50
		local lbl = line(content, "Item" .. i, "", y, GREEN, 20)
		lbl.Size = UDim2.new(0, 360, 0, 30)
		table.insert(itemLabels, lbl)
		local prev = UiKit.Button(content, "Prev" .. i, "<", UDim2.fromOffset(40, 30), UDim2.fromOffset(380, y), GREEN)
		local nxt = UiKit.Button(content, "Next" .. i, ">", UDim2.fromOffset(40, 30), UDim2.fromOffset(430, y), GREEN)
		local function cycle(dir: number)
			local idx = table.find(choices, items[i]) or 1
			idx = ((idx - 1 + dir) % #choices) + 1
			items[i] = choices[idx]
			AudioController.Play2D("UiClick", 0.5)
			refresh()
		end
		prev.MouseButton1Click:Connect(function()
			cycle(-1)
		end)
		nxt.MouseButton1Click:Connect(function()
			cycle(1)
		end)
	end
	line(content, "Hint", "Remaining 2 belt slots are for items you find.", 300, Color3.fromRGB(120, 190, 130), 15)
	local confirm = UiKit.Button(content, "Confirm", "[ CONFIRM ]", UDim2.fromOffset(200, 36), UDim2.new(0, 0, 1, -40), GREEN)
	confirm.MouseButton1Click:Connect(function()
		if items[1] == items[2] and items[1] ~= "Flare" then
			return
		end
		Net.Event("ChooseLoadout"):FireServer(clothing, items[1], items[2])
		closeTerminal()
	end)
	refresh()
end

----------------------------------------------------------------------
-- Zentrifuge
----------------------------------------------------------------------
local VIAL_ORDER = { "VialBlue", "VialGreen", "VialRed" }
local centLabels: { TextLabel } = {}
local centButtons: { TextButton } = {}
local centStatus: TextLabel? = nil

local function refreshCentrifuge(data: { [string]: any })
	local slots = if type(data.Slots) == "table" then data.Slots else {}
	for i, l in centLabels do
		local v = slots[i]
		local info = if type(v) == "string" then Config.ItemInfo[v] else nil
		l.Text = string.format("SLOT %d:  %s", i, if info then info.Name else "-- EMPTY --")
	end
	local s = centStatus
	if s then
		if data.Done == true then
			s.Text = "> SAMPLE KEY RELEASED - TAKE THE KEYCARD"
		elseif data.Running == true then
			s.Text = string.format("> SPINNING... %d S - HOLD OUT", math.ceil(tonumber(data.RunLeft) or 0))
		elseif (tonumber(data.LockedFor) or 0) > 0 then
			s.Text = string.format("> SEQUENCE ERROR - LOCKED %d S", math.ceil(tonumber(data.LockedFor) or 0))
		else
			s.Text = "> LOAD SAMPLES IN THE CORRECT ORDER"
		end
	end
	for _, b in centButtons do
		local id = b:GetAttribute("Vial")
		local has = false
		for i = 1, Config.Items.BeltSlots do
			if player:GetAttribute("Slot" .. i) == id then
				has = true
			end
		end
		b.Visible = has and data.Running ~= true and data.Done ~= true
	end
end

local function openCentrifuge(data: { [string]: any })
	local trove, content = openFrame("Centrifuge", "CENTRIFUGE CF-9", GREEN)
	table.clear(centLabels)
	table.clear(centButtons)
	for i = 1, 3 do
		table.insert(centLabels, line(content, "Slot" .. i, "", 50 + (i - 1) * 32, GREEN, 20))
	end
	centStatus = line(content, "Status", "", 160, AMBER, 18)
	line(content, "BeltHead", "SAMPLES IN YOUR BELT:", 210, GREEN, 18)
	for i, id in VIAL_ORDER do
		local info = Config.ItemInfo[id]
		local b = UiKit.Button(content, "Insert_" .. id, "INSERT " .. (if info then info.Name else id), UDim2.fromOffset(300, 34), UDim2.fromOffset(0, 240 + (i - 1) * 42), if info then info.Color else GREEN)
		b:SetAttribute("Vial", id)
		table.insert(centButtons, b)
		b.MouseButton1Click:Connect(function()
			Net.Event("CentrifugeInput"):FireServer("Insert", id)
			AudioController.Play2D("UiBeep", 0.6)
		end)
	end
	refreshCentrifuge(data)
	-- Belt-Änderungen live zeigen
	for i = 1, Config.Items.BeltSlots do
		trove:Connect(player:GetAttributeChangedSignal("Slot" .. i), function()
			refreshCentrifuge(data)
		end)
	end
end

----------------------------------------------------------------------
-- Generator: Nadel pendelt, im grünen Bereich klicken
----------------------------------------------------------------------
local genData: { [string]: any } = {}
local genResult: TextLabel? = nil

local function needle(t: number): number
	local t0 = tonumber(genData.T0) or 0
	local period = tonumber(genData.Period) or Config.Puzzle.GeneratorNeedlePeriod
	return 0.5 + 0.5 * math.sin(2 * math.pi * (t - t0) / period)
end

local function openGenerator(data: { [string]: any })
	genData = data
	local trove, content = openFrame("Generator", "GEN-2 STARTER", AMBER)
	line(content, "Info", "ENGAGE THE STARTER WHILE THE NEEDLE IS IN THE GREEN BAND.", 48, AMBER, 16)
	local gauge = UiKit.Frame(content, "Gauge", UDim2.new(1, 0, 0, 70), UDim2.fromOffset(0, 110), Color3.fromRGB(20, 14, 4), 0)
	UiKit.Stroke(gauge, AMBER, 2, 0.2)
	local green = UiKit.Frame(gauge, "Green", UDim2.fromScale(0.16, 1), UDim2.fromScale(0.7, 0), Color3.fromRGB(60, 200, 80), 0.25)
	local needleBar = UiKit.Frame(gauge, "Needle", UDim2.new(0, 4, 1, 10), UDim2.new(0, 0, 0, -5), Color3.fromRGB(255, 60, 40), 0)
	needleBar.AnchorPoint = Vector2.new(0.5, 0)
	for i = 0, 10 do
		UiKit.Frame(gauge, "Tick", UDim2.new(0, 1, 0, 10), UDim2.new(i / 10, 0, 1, -10), AMBER, 0.3)
	end
	genResult = line(content, "Result", "", 200, AMBER, 22)
	local engage = UiKit.Button(content, "Engage", "[ ENGAGE STARTER ]  CLICK / SPACE", UDim2.fromOffset(420, 44), UDim2.fromOffset(0, 250), AMBER)
	engage.TextSize = 20
	local function attempt()
		Net.Event("GeneratorAttempt"):FireServer(Workspace:GetServerTimeNow())
		AudioController.Play2D("UiClick", 0.8)
	end
	trove:Connect(engage.MouseButton1Click, attempt)
	trove:Connect(game:GetService("UserInputService").InputBegan, function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			attempt()
		end
	end)
	trove:Connect(RunService.RenderStepped, function()
		local center = tonumber(genData.Center) or 0.75
		local width = tonumber(genData.Width) or 0.16
		green.Position = UDim2.fromScale(center - width / 2, 0)
		green.Size = UDim2.fromScale(width, 1)
		needleBar.Position = UDim2.new(needle(Workspace:GetServerTimeNow()), 0, 0, -5)
		if genData.Running == true then
			needleBar.Position = UDim2.new(center, 0, 0, -5)
		end
	end)
end

local function refreshGenerator(data: { [string]: any })
	genData = data
	local r = genResult
	if r then
		if data.Running == true then
			r.Text = "> GENERATOR ONLINE"
			r.TextColor3 = Color3.fromRGB(90, 255, 110)
			task.delay(1.2, function()
				if current and current.Kind == "Generator" then
					closeTerminal()
				end
			end)
		elseif data.Failed == true then
			r.Text = "> BACKFIRE! TRY AGAIN"
			r.TextColor3 = Color3.fromRGB(255, 70, 50)
		end
	end
end

----------------------------------------------------------------------
-- Abstieg: CRT aus, Teleport, CRT an
----------------------------------------------------------------------
local function onRoundState(state: string)
	if state == "Transition" then
		closeTerminal()
		transition.Visible = true
		transition.BackgroundTransparency = 1
		crtOff(transition, function()
			transition.BackgroundTransparency = 0
		end)
	elseif state == "Zone1" or state == "Lobby" then
		if transition.Visible then
			transition.BackgroundTransparency = 1
			crtOn(transition)
			task.delay(Config.HUD.CrtOnTime + 0.1, function()
				transition.Visible = false
			end)
		end
	end
end

function TerminalController.Init()
	gui = UiKit.Screen("SubZeroTerminal", 25)
	transition = UiKit.Frame(gui, "Transition", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 1)
	transition.ZIndex = 80
	transition.Visible = false
end

function TerminalController.Start()
	Net.Event("OpenTerminal").OnClientEvent:Connect(function(kind: unknown, data: unknown, refresh: unknown)
		if type(kind) ~= "string" or type(data) ~= "table" then
			return
		end
		local d = data :: { [string]: any }
		local isRefresh = refresh == true
		if kind == "Loadout" then
			openLoadout(d)
		elseif kind == "Centrifuge" then
			if isRefresh then
				if current and current.Kind == "Centrifuge" then
					refreshCentrifuge(d)
				end
			else
				openCentrifuge(d)
			end
		elseif kind == "Generator" then
			if isRefresh then
				if current and current.Kind == "Generator" then
					refreshGenerator(d)
				end
			else
				openGenerator(d)
			end
		end
	end)
	Net.Event("RoundStateChanged").OnClientEvent:Connect(function(state: unknown)
		if type(state) == "string" then
			onRoundState(state)
		end
	end)
	InputController.CloseRequested:Connect(closeTerminal)
	-- Terminal schließen, wenn der Spieler stirbt oder weggeht
	player:GetAttributeChangedSignal("State"):Connect(function()
		local st = Util.GetState(player)
		if st ~= "Alive" and st ~= "Lobby" then
			closeTerminal()
		end
	end)
end

return TerminalController
