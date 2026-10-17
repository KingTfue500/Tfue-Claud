--!strict
-- HUD-Anzeigen (Abschnitt 9): Frost-Overlay, Temperatur-Zifferblatt mit LED-Leiste, EKG-Monitor,
-- Stamina-Leiste, Atem-Ring. Alle Werte kommen aus Spieler-Attributen.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local UiKit = require(script.Parent.Parent.Parent.Lib.UiKit)

local Gauges = {}

local player = Players.LocalPlayer
local H = Config.HUD
local ICE = Config.Colors.Ice
local WHITE = Config.Colors.HudWhite
local AMBER = Config.Colors.CrtAmber
local GREEN = Config.Colors.CrtGreen
local RED = Config.Colors.Danger

-- Frost
local frostGroup: CanvasGroup
local blur: BlurEffect
-- Zifferblatt
local dialRoot: Frame
local needle: Frame
local tempText: TextLabel
local dialStroke: UIStroke
local leds: { Frame } = {}
local ledBar: Frame
-- EKG
local ekgRoot: Frame
local ekgSegs: { Frame } = {}
local ekgSamples: { number } = {}
local ekgPhase = 0
local bpmText: TextLabel
local ekgStroke: UIStroke
-- Stamina, Atem
local staminaBar: Frame
local staminaFill: Frame
local breathRoot: Frame
local breathRing: UiKit.Ring
local breathLabel: TextLabel
local statusBadges: TextLabel

local EKG_W, EKG_H = 230, 96
local DIAL = 176

local function dialAngle(t: number): number
	-- 24 °C bei -120°, 39 °C bei +120°
	local a = (t - H.DialMin) / (H.DialMax - H.DialMin)
	return -120 + math.clamp(a, 0, 1) * 240
end

----------------------------------------------------------------------
-- Aufbau
----------------------------------------------------------------------
local function buildFrost(frostGui: ScreenGui)
	frostGroup = Instance.new("CanvasGroup")
	frostGroup.Name = "Frost"
	frostGroup.Size = UDim2.fromScale(1, 1)
	frostGroup.BackgroundTransparency = 1
	frostGroup.GroupTransparency = 1
	frostGroup.Parent = frostGui
	local img = UiKit.ImageOrNil(frostGroup, "FrostImage", Config.Images.FrostVignette, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	if img == nil then
		-- Platzhalter: Eis-Vignette und Kristalle aus Frames
		UiKit.Vignette(frostGroup, Color3.fromRGB(200, 230, 255), 0.32, 0.05)
		UiKit.Vignette(frostGroup, Color3.fromRGB(255, 255, 255), 0.14, 0.15)
		local rng = Random.new(7)
		for _ = 1, 70 do
			local edge = rng:NextInteger(1, 4)
			local x: number, y: number
			if edge == 1 then
				x, y = rng:NextNumber(), rng:NextNumber() * 0.18
			elseif edge == 2 then
				x, y = rng:NextNumber(), 1 - rng:NextNumber() * 0.18
			elseif edge == 3 then
				x, y = rng:NextNumber() * 0.14, rng:NextNumber()
			else
				x, y = 1 - rng:NextNumber() * 0.14, rng:NextNumber()
			end
			local len = rng:NextInteger(30, 140)
			for k = 0, 2 do
				local c = UiKit.Frame(frostGroup, "Crystal", UDim2.fromOffset(len * (1 - k * 0.3), 2), UDim2.fromScale(x, y), Color3.fromRGB(235, 248, 255), 0.25 + k * 0.15)
				c.AnchorPoint = Vector2.new(0.5, 0.5)
				c.Rotation = rng:NextNumber() * 180 + k * 60
			end
		end
	end
	blur = Instance.new("BlurEffect")
	blur.Name = "HypoBlur"
	blur.Size = 0
	blur.Parent = Workspace.CurrentCamera or Lighting
end

local function buildDial(hud: ScreenGui)
	dialRoot = UiKit.Frame(hud, "TempDial", UDim2.fromOffset(DIAL, DIAL), UDim2.new(0, 24, 1, -DIAL - 34), Color3.fromRGB(26, 26, 28), 0)
	UiKit.Corner(dialRoot, 1)
	dialStroke = UiKit.Stroke(dialRoot, Color3.fromRGB(70, 70, 74), 5, 0)
	UiKit.Gradient(dialRoot, ColorSequence.new(Color3.fromRGB(60, 60, 64), Color3.fromRGB(14, 14, 16)), 45)
	local face = UiKit.Frame(dialRoot, "Face", UDim2.new(1, -22, 1, -22), UDim2.fromOffset(11, 11), Color3.fromRGB(215, 212, 200), 0)
	UiKit.Corner(face, 1)
	UiKit.Gradient(face, ColorSequence.new(Color3.fromRGB(235, 232, 220), Color3.fromRGB(170, 165, 150)), 120)
	UiKit.ImageOrNil(face, "DialImage", Config.Images.DialFace, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	-- Skala
	local r = (DIAL - 22) / 2
	for t = H.DialMin, H.DialMax do
		local a = math.rad(dialAngle(t))
		local major = t % 4 == 0 or t == H.DialMax
		local len = if major then 12 else 7
		local holder = UiKit.Frame(face, "Tick", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), WHITE, 1)
		holder.Rotation = math.deg(a)
		local color = if t <= 26 then Color3.fromRGB(40, 110, 200) elseif t >= 37.5 then Color3.fromRGB(220, 120, 20) else Color3.fromRGB(30, 30, 30)
		UiKit.Frame(holder, "Mark", UDim2.fromOffset(if major then 3 else 2, len), UDim2.new(0.5, if major then -1 else -1, 0, 4), color, 0)
		if major then
			local lx = 0.5 + math.sin(a) * (r - 26) / (r * 2)
			local ly = 0.5 - math.cos(a) * (r - 26) / (r * 2)
			local lbl = UiKit.Text(face, "Num", tostring(t), UDim2.fromOffset(30, 16), UDim2.fromScale(lx, ly), UiKit.Mono, 13, Color3.fromRGB(30, 30, 30))
			lbl.AnchorPoint = Vector2.new(0.5, 0.5)
		end
	end
	local unit = UiKit.Text(face, "Unit", "°C  CORE", UDim2.fromOffset(80, 14), UDim2.new(0.5, -40, 0.66, 0), UiKit.Label, 10, Color3.fromRGB(40, 40, 40))
	unit.TextXAlignment = Enum.TextXAlignment.Center
	-- Zeiger
	local pivot = UiKit.Frame(face, "NeedlePivot", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), RED, 1)
	needle = pivot
	UiKit.Frame(pivot, "Needle", UDim2.new(0, 3, 0.5, -14), UDim2.new(0.5, -1, 0, 14), Color3.fromRGB(190, 25, 20), 0)
	local cap = UiKit.Frame(face, "Cap", UDim2.fromOffset(16, 16), UDim2.new(0.5, -8, 0.5, -8), Color3.fromRGB(30, 30, 30), 0)
	UiKit.Corner(cap, 1)
	-- zerkratztes Glas
	local glass = UiKit.Frame(face, "Glass", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(1, 1, 1), 0.9)
	UiKit.Corner(glass, 1)
	UiKit.Gradient(glass, ColorSequence.new(Color3.new(1, 1, 1)), 35, NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(1, 1) }))
	local rng = Random.new(3)
	for _ = 1, 7 do
		local sc = UiKit.Frame(glass, "Scratch", UDim2.fromOffset(rng:NextInteger(20, 70), 1), UDim2.fromScale(rng:NextNumber(0.15, 0.75), rng:NextNumber(0.15, 0.85)), Color3.new(1, 1, 1), 0.55)
		sc.Rotation = rng:NextNumber(-60, 60)
	end
	-- Digitalanzeige und LED-Leiste
	tempText = UiKit.Text(hud, "TempText", "37.0°C", UDim2.fromOffset(DIAL, 22), UDim2.new(0, 24, 1, -32), UiKit.MonoBold, 20, WHITE)
	ledBar = UiKit.Frame(hud, "LedBar", UDim2.fromOffset(DIAL, 10), UDim2.new(0, 24, 1, -DIAL - 50), Color3.fromRGB(10, 10, 10), 0.2)
	UiKit.Corner(ledBar, 0, 3)
	for i = 1, 15 do
		local led = UiKit.Frame(ledBar, "Led" .. i, UDim2.new(1 / 15, -2, 1, -4), UDim2.new((i - 1) / 15, 1, 0, 2), Color3.fromRGB(30, 30, 30), 0)
		UiKit.Corner(led, 0, 2)
		table.insert(leds, led)
	end
end

local function buildEkg(hud: ScreenGui)
	ekgRoot = UiKit.Frame(hud, "EKG", UDim2.fromOffset(EKG_W, EKG_H), UDim2.new(0, DIAL + 40, 1, -EKG_H - 46), Color3.fromRGB(2, 12, 5), 0.05)
	UiKit.Corner(ekgRoot, 0, 6)
	ekgStroke = UiKit.Stroke(ekgRoot, Color3.fromRGB(50, 60, 52), 3, 0)
	ekgRoot.ClipsDescendants = true
	-- Raster
	for i = 1, 7 do
		UiKit.Frame(ekgRoot, "GridV", UDim2.new(0, 1, 1, 0), UDim2.fromScale(i / 8, 0), GREEN, 0.88)
	end
	for i = 1, 3 do
		UiKit.Frame(ekgRoot, "GridH", UDim2.new(1, 0, 0, 1), UDim2.fromScale(0, i / 4), GREEN, 0.88)
	end
	for i = 1, H.EkgHistory do
		ekgSamples[i] = 0
		local seg = UiKit.Frame(ekgRoot, "Seg", UDim2.fromOffset(2, 2), UDim2.fromOffset(0, 0), GREEN, 0)
		seg.AnchorPoint = Vector2.new(0.5, 0.5)
		table.insert(ekgSegs, seg)
	end
	local title = UiKit.Text(ekgRoot, "Title", "ECG  II", UDim2.fromOffset(60, 14), UDim2.fromOffset(6, 3), UiKit.Label, 9, GREEN)
	title.TextXAlignment = Enum.TextXAlignment.Left
	bpmText = UiKit.Text(hud, "BPM", "70 BPM", UDim2.fromOffset(110, 22), UDim2.new(0, DIAL + 40, 1, -46), UiKit.MonoBold, 18, GREEN)
	bpmText.TextXAlignment = Enum.TextXAlignment.Left
	UiKit.Scanlines(ekgRoot, 3, 0.8, 36)
	-- Stamina (nur sichtbar, wenn nicht voll)
	staminaBar = UiKit.Frame(hud, "Stamina", UDim2.fromOffset(EKG_W, 6), UDim2.new(0, DIAL + 40, 1, -22), Color3.fromRGB(20, 20, 20), 0.3)
	UiKit.Corner(staminaBar, 0, 3)
	staminaFill = UiKit.Frame(staminaBar, "Fill", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), WHITE, 0.05)
	UiKit.Corner(staminaFill, 0, 3)
	statusBadges = UiKit.Text(hud, "Badges", "", UDim2.fromOffset(EKG_W, 16), UDim2.new(0, DIAL + 160, 1, -46), UiKit.Mono, 13, ICE)
	statusBadges.TextXAlignment = Enum.TextXAlignment.Left
end

local function buildBreath(hud: ScreenGui)
	breathRoot = UiKit.Frame(hud, "Breath", UDim2.fromOffset(84, 84), UDim2.new(0.5, -42, 1, -150), Color3.fromRGB(10, 14, 18), 0.35)
	UiKit.Corner(breathRoot, 1)
	breathRing = UiKit.Ring(breathRoot, "Lung", 84, 6, ICE)
	breathLabel = UiKit.Text(breathRoot, "Label", "HOLD", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), UiKit.Label, 11, ICE)
	breathRoot.Visible = false
end

function Gauges.Build(hud: ScreenGui, frostGui: ScreenGui)
	buildFrost(frostGui)
	buildDial(hud)
	buildEkg(hud)
	buildBreath(hud)
end

----------------------------------------------------------------------
-- Aktualisierung
----------------------------------------------------------------------
-- EKG-Kurve (P-QRS-T) für eine Phase 0..1
local function ekgWave(p: number): number
	if p < 0.1 then
		return math.sin(p / 0.1 * math.pi) * 0.12
	elseif p < 0.16 then
		return 0
	elseif p < 0.19 then
		return -0.15 * math.sin((p - 0.16) / 0.03 * math.pi)
	elseif p < 0.23 then
		return math.sin((p - 0.19) / 0.04 * math.pi) * 1.0
	elseif p < 0.27 then
		return -0.3 * math.sin((p - 0.23) / 0.04 * math.pi)
	elseif p < 0.42 then
		return 0
	elseif p < 0.56 then
		return math.sin((p - 0.42) / 0.14 * math.pi) * 0.22
	end
	return 0
end

local ekgAcc = 0
local function updateEkg(dt: number, bpm: number, alive: boolean)
	ekgAcc += dt
	local step = 1 / 60
	while ekgAcc >= step do
		ekgAcc -= step
		ekgPhase = (ekgPhase + step * bpm / 60) % 1
		table.remove(ekgSamples, 1)
		local v = if alive then ekgWave(ekgPhase) + (math.random() - 0.5) * 0.03 else 0
		table.insert(ekgSamples, v)
	end
	local n = #ekgSamples
	local alarm = bpm >= Config.Heart.EkgAlarmBpm
	local blinkOn = not alarm or (os.clock() * 3) % 1 < 0.6
	local color = if alarm then RED else GREEN
	for i = 1, n - 1 do
		local x1 = (i - 1) / (n - 1) * EKG_W
		local x2 = i / (n - 1) * EKG_W
		local y1 = EKG_H * 0.6 - ekgSamples[i] * EKG_H * 0.45
		local y2 = EKG_H * 0.6 - ekgSamples[i + 1] * EKG_H * 0.45
		local seg = ekgSegs[i]
		local dx, dy = x2 - x1, y2 - y1
		local len = math.sqrt(dx * dx + dy * dy)
		seg.Size = UDim2.fromOffset(len + 1, 2)
		seg.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
		seg.Rotation = math.deg(math.atan2(dy, dx))
		seg.BackgroundColor3 = color
		seg.BackgroundTransparency = if blinkOn then 0 else 0.7
	end
	ekgSegs[n].Visible = false
	bpmText.Text = string.format("%d BPM", bpm)
	bpmText.TextColor3 = if alarm and blinkOn then RED elseif alarm then Color3.fromRGB(120, 20, 20) else GREEN
	ekgStroke.Color = if alarm and blinkOn then Color3.fromRGB(140, 30, 25) else Color3.fromRGB(50, 60, 52)
end

local shownTemp = 37
function Gauges.Update(dt: number, visible: boolean)
	local T = Util.NumAttr(player, "BodyTemp", 37)
	local stage = Util.StrAttr(player, "HypoStage", "Normal")
	local st = Util.GetState(player)
	local alive = st == "Alive" or st == "Downed" or st == "Lobby" or st == "Grabbed"

	dialRoot.Visible = visible
	tempText.Visible = visible
	ekgRoot.Visible = visible
	bpmText.Visible = visible
	statusBadges.Visible = visible
	ledBar.Visible = visible

	-- Frost: Transparenz 1 bei 34 °C, 0 bei 26 °C; Unschärfe ab 28 °C bis 12 bei 24 °C
	local frostAlpha = if alive and st ~= "Lobby" then Util.InverseLerp(H.FrostStart, H.FrostFull, T) else 0
	frostGroup.GroupTransparency = 1 - frostAlpha
	local blurA = if alive and st ~= "Lobby" then Util.InverseLerp(H.BlurStart, Config.Temperature.Collapse, T) else 0
	blur.Size = blurA * H.BlurMax
	if T < H.BlurStart and alive then
		local j = 3 * blurA + 1
		frostGroup.Position = UDim2.fromOffset((math.random() - 0.5) * j, (math.random() - 0.5) * j)
	else
		frostGroup.Position = UDim2.fromOffset(0, 0)
	end

	-- Zifferblatt
	shownTemp += (T - shownTemp) * math.min(1, dt * 4)
	needle.Rotation = dialAngle(shownTemp)
	tempText.Text = string.format("%.1f°C", T)
	local col: Color3
	if stage == "Overheated" then
		col = AMBER
		dialStroke.Color = Color3.fromRGB(255, 140, 20):Lerp(Color3.fromRGB(120, 60, 10), (math.sin(os.clock() * 5) + 1) / 2)
	elseif T < Config.Hypo.NormalAbove then
		col = ICE
		dialStroke.Color = Color3.fromRGB(70, 110, 150)
	else
		col = WHITE
		dialStroke.Color = Color3.fromRGB(70, 70, 74)
	end
	tempText.TextColor3 = col
	local lit = math.floor(Util.InverseLerp(H.DialMin, H.DialMax, T) * #leds + 0.5)
	for i, led in leds do
		local segT = H.DialMin + (i - 0.5) / #leds * (H.DialMax - H.DialMin)
		local on = i <= lit
		local c = if segT >= Config.Hypo.OverheatAbove then AMBER elseif segT < Config.Hypo.NormalAbove then ICE else WHITE
		led.BackgroundColor3 = if on then c else Color3.fromRGB(28, 28, 30)
	end

	-- EKG
	local bpm = Util.NumAttr(player, "BPM", 70)
	updateEkg(dt, bpm, alive)

	-- Stamina
	local stamina = Util.NumAttr(player, "Stamina", 100)
	staminaBar.Visible = visible and stamina < Config.Stamina.Max - 0.5
	staminaFill.Size = UDim2.fromScale(math.clamp(stamina / Config.Stamina.Max, 0, 1), 1)
	staminaFill.BackgroundColor3 = if player:GetAttribute("Panting") == true then RED else WHITE

	-- Atem-Ring (nur liegend)
	local prone = Util.StrAttr(player, "Stance", "Stand") == "Prone" and st ~= "Downed"
	breathRoot.Visible = visible and prone
	if prone then
		local b = Util.NumAttr(player, "Breath", 100) / Config.Breath.Max
		breathRing:SetProgress(b)
		local holding = player:GetAttribute("HoldingBreath") == true
		breathRing:SetColor(if holding then ICE else AMBER)
		breathLabel.Text = if holding then "HOLD" else "BREATHE"
		breathLabel.TextColor3 = if holding then ICE else AMBER
	end

	-- Status-Abzeichen
	local badges: { string } = {}
	if player:GetAttribute("Wet") == true then
		table.insert(badges, "SOAKED")
	end
	if player:GetAttribute("InSteam") == true then
		table.insert(badges, "STEAM COVER")
	end
	if Util.NumAttr(player, "HandWarmerUntil", 0) > Workspace:GetServerTimeNow() then
		table.insert(badges, "WARMER")
	end
	if stage == "Overheated" then
		table.insert(badges, "OVERHEATED")
	elseif stage == "Mild" or stage == "Moderate" or stage == "Severe" then
		table.insert(badges, string.upper(stage) .. " HYPOTHERMIA")
	end
	statusBadges.Text = table.concat(badges, "  ")
end

return Gauges
