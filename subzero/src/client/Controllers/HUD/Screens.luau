--!strict
-- Bildschirme und Meldungen: Hinweise, Status-Zeile, Zonen-Banner, Notiz-Leser (Papier oder CRT-Log),
-- Kill-Effekt (Frost wuchert, Riss, Schnitt auf Schwarz), Tod/Niederlage ("SIGNAL LOST"),
-- Sieg-Bildschirm mit Statistik, Zuschauer-Anzeige, Einstellungen, Wärmebild-Markierungen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Notes = require(ReplicatedStorage.Shared.Notes)
local Util = require(ReplicatedStorage.Shared.Util)
local ClientState = require(script.Parent.Parent.Parent.Lib.ClientState)
local Settings = require(script.Parent.Parent.Parent.Lib.Settings)
local UiKit = require(script.Parent.Parent.Parent.Lib.UiKit)

local Screens = {}

local player = Players.LocalPlayer
local GREEN = Config.Colors.CrtGreen
local AMBER = Config.Colors.CrtAmber
local ICE = Config.Colors.Ice

local hud: ScreenGui
local top: ScreenGui
local notifyHolder: Frame
local statusLabel: TextLabel
local zoneBanner: TextLabel
local hintLabel: TextLabel
local spectateLabel: TextLabel
local noteFrame: Frame?
local settingsFrame: Frame?
local overlay: Frame
local overlayText: TextLabel
local frostCover: CanvasGroup
local crack: Frame
local resultFrame: Frame?
local gear: TextButton
local louvers: Frame

local ZONE_NAMES: { [string]: string } = {
	Lobby = "LOBBY BUNKER",
	Zone1 = "HABITATION",
	Zone2 = "BIO-LABS",
	Zone3 = "CARGO BAY",
	Zone4 = "REACTOR",
	Helipad = "SURFACE - HELIPAD",
}

----------------------------------------------------------------------
-- Aufbau
----------------------------------------------------------------------
function Screens.Build(hudGui: ScreenGui, topGui: ScreenGui)
	hud = hudGui
	top = topGui
	notifyHolder = UiKit.Frame(hud, "Notify", UDim2.fromOffset(520, 200), UDim2.new(0.5, -260, 0, 70), Color3.new(0, 0, 0), 1)
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = notifyHolder
	statusLabel = UiKit.Text(hud, "Status", "", UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 30), UiKit.MonoBold, 22, AMBER)
	statusLabel.TextStrokeTransparency = 0.6
	zoneBanner = UiKit.Text(hud, "ZoneBanner", "", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0.22, 0), UiKit.Label, 30, Color3.fromRGB(220, 230, 240))
	zoneBanner.TextTransparency = 1
	zoneBanner.TextStrokeTransparency = 1
	hintLabel = UiKit.Text(hud, "Hint", "", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 1, -200), UiKit.Mono, 15, Color3.fromRGB(200, 205, 210))
	hintLabel.TextStrokeTransparency = 0.5
	spectateLabel = UiKit.Text(hud, "Spectate", "", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 1, -90), UiKit.MonoBold, 20, Color3.fromRGB(220, 220, 220))
	spectateLabel.TextStrokeTransparency = 0.4

	-- Vollbild-Ebenen
	overlay = UiKit.Frame(top, "Black", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 1)
	overlay.ZIndex = 20
	overlayText = UiKit.Text(overlay, "Text", "", UDim2.new(1, 0, 0, 80), UDim2.new(0, 0, 0.42, 0), UiKit.Label, 46, Color3.fromRGB(230, 240, 255))
	overlayText.ZIndex = 21
	overlayText.TextTransparency = 1
	frostCover = Instance.new("CanvasGroup")
	frostCover.Name = "FrostCover"
	frostCover.Size = UDim2.fromScale(1, 1)
	frostCover.BackgroundTransparency = 1
	frostCover.GroupTransparency = 1
	frostCover.ZIndex = 15
	frostCover.Parent = top
	UiKit.Frame(frostCover, "Tint", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(200, 225, 245), 0.35)
	UiKit.Vignette(frostCover, Color3.fromRGB(255, 255, 255), 0.45, 0)
	local rng = Random.new(11)
	for _ = 1, 120 do
		local c = UiKit.Frame(frostCover, "Crystal", UDim2.fromOffset(rng:NextInteger(40, 220), 2), UDim2.fromScale(rng:NextNumber(), rng:NextNumber()), Color3.new(1, 1, 1), 0.2)
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		c.Rotation = rng:NextNumber() * 180
	end
	crack = UiKit.Frame(top, "Crack", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 1)
	crack.ZIndex = 16
	crack.Visible = false
	if UiKit.ImageOrNil(crack, "CrackImage", Config.Images.CrackOverlay, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0)) == nil then
		local rc = Random.new(5)
		for _ = 1, 26 do
			local x, y = 0.5 + rc:NextNumber(-0.08, 0.08), 0.5 + rc:NextNumber(-0.08, 0.08)
			local l = UiKit.Frame(crack, "Line", UDim2.fromOffset(rc:NextInteger(200, 900), 3), UDim2.fromScale(x, y), Color3.fromRGB(240, 250, 255), 0.05)
			l.AnchorPoint = Vector2.new(0, 0.5)
			l.Rotation = rc:NextNumber() * 360
			l.ZIndex = 16
		end
	end

	-- Versteck-Spind: man sieht nur durch die Lamellen nach draußen
	louvers = UiKit.Frame(top, "Louvers", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 1)
	louvers.ZIndex = 5
	louvers.Visible = false
	local slats = 9
	for i = 0, slats - 1 do
		local y = i / slats
		local bar = UiKit.Frame(louvers, "Slat", UDim2.new(1, 0, 1 / slats, -10), UDim2.fromScale(0, y), Color3.fromRGB(18, 20, 22), 0)
		bar.ZIndex = 5
		UiKit.Gradient(bar, ColorSequence.new(Color3.fromRGB(70, 74, 80), Color3.fromRGB(14, 15, 17)), 90)
	end
	UiKit.Vignette(louvers, Color3.new(0, 0, 0), 0.25, 0)

	-- Einstellungen-Knopf (Touch)
	gear = UiKit.Button(hud, "Gear", "SET", UDim2.fromOffset(52, 30), UDim2.new(1, -64, 0, 44), Color3.fromRGB(200, 205, 210))
	gear.TextSize = 14
	gear.MouseButton1Click:Connect(function()
		Screens.ToggleSettings()
	end)
end

----------------------------------------------------------------------
-- Meldungen
----------------------------------------------------------------------
function Screens.Notify(text: string)
	local l = UiKit.Text(notifyHolder, "Msg", "> " .. text, UDim2.new(1, 0, 0, 26), UDim2.fromScale(0, 0), UiKit.MonoBold, 18, GREEN)
	l.BackgroundColor3 = Color3.fromRGB(2, 12, 5)
	l.BackgroundTransparency = 0.25
	l.TextTransparency = 0
	UiKit.Corner(l, 0, 4)
	task.delay(Config.HUD.NotifyTime, function()
		UiKit.Tween(l, 0.6, { TextTransparency = 1, BackgroundTransparency = 1 })
		task.wait(0.7)
		l:Destroy()
	end)
	local children = notifyHolder:GetChildren()
	local labels = 0
	for _, c in children do
		if c:IsA("TextLabel") then
			labels += 1
		end
	end
	if labels > 5 then
		for _, c in children do
			if c:IsA("TextLabel") then
				c:Destroy()
				break
			end
		end
	end
end

function Screens.ZoneBanner(zone: string)
	local name = ZONE_NAMES[zone]
	if name == nil then
		return
	end
	zoneBanner.Text = name
	zoneBanner.TextTransparency = 1
	UiKit.Tween(zoneBanner, 1, { TextTransparency = 0.1, TextStrokeTransparency = 0.6 })
	task.delay(3, function()
		if zoneBanner.Text == name then
			UiKit.Tween(zoneBanner, 1.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

----------------------------------------------------------------------
-- Notiz-Leser (Schließen mit E)
----------------------------------------------------------------------
function Screens.CloseNote()
	local f = noteFrame
	if f then
		noteFrame = nil
		f:Destroy()
		ClientState.SetUi("Note", false)
	end
end

function Screens.ShowNote(id: string)
	Screens.CloseNote()
	local note = Notes[id]
	if note == nil then
		return
	end
	ClientState.SetUi("Note", true)
	local dim = UiKit.Frame(top, "NoteReader", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 0.35)
	dim.ZIndex = 30
	noteFrame = dim
	local tape = note.Kind == "Tape"
	local page = UiKit.Frame(dim, "Page", UDim2.new(0, 560, 0.82, 0), UDim2.new(0.5, -280, 0.09, 0), if tape then Color3.fromRGB(4, 14, 7) else Color3.fromRGB(226, 214, 176), 0)
	page.ZIndex = 31
	UiKit.Corner(page, 0, if tape then 14 else 2)
	if tape then
		UiKit.Stroke(page, Color3.fromRGB(70, 70, 64), 8, 0)
		local sl = UiKit.Scanlines(page, 3, 0.7, 300)
		sl.ZIndex = 34
	else
		UiKit.Gradient(page, ColorSequence.new(Color3.fromRGB(240, 230, 196), Color3.fromRGB(196, 178, 130)), 70)
		page.Rotation = -1.2
	end
	local title = UiKit.Text(page, "Title", note.Title, UDim2.new(1, -40, 0, 34), UDim2.fromOffset(20, 16), if tape then UiKit.MonoBold else Font.fromEnum(Enum.Font.SpecialElite), 22, if tape then GREEN else Color3.fromRGB(40, 30, 20))
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 32
	local body = UiKit.Text(page, "Body", "", UDim2.new(1, -40, 1, -110), UDim2.fromOffset(20, 60), if tape then UiKit.Mono else Font.fromEnum(Enum.Font.SpecialElite), 17, if tape then GREEN else Color3.fromRGB(45, 35, 25))
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.RichText = false
	body.ZIndex = 32
	local hint = UiKit.Text(page, "Hint", "[E] CLOSE", UDim2.new(1, -40, 0, 20), UDim2.new(0, 20, 1, -34), UiKit.Label, 12, if tape then GREEN else Color3.fromRGB(90, 70, 50))
	hint.TextXAlignment = Enum.TextXAlignment.Right
	hint.ZIndex = 32
	local closeBtn = UiKit.Button(page, "Close", "X", UDim2.fromOffset(34, 30), UDim2.new(1, -44, 0, 12), if tape then GREEN else Color3.fromRGB(80, 60, 40))
	closeBtn.ZIndex = 33
	closeBtn.MouseButton1Click:Connect(Screens.CloseNote)
	if tape then
		-- CRT-Log: Schreibmaschinen-Effekt
		task.spawn(function()
			local text = note.Body
			for i = 1, #text, 3 do
				if noteFrame ~= dim then
					return
				end
				body.Text = string.sub(text, 1, i) .. "_"
				task.wait(0.012)
			end
			body.Text = text
		end)
	else
		body.Text = note.Body
	end
end

----------------------------------------------------------------------
-- Einstellungen
----------------------------------------------------------------------
function Screens.ToggleSettings()
	local f = settingsFrame
	if f then
		settingsFrame = nil
		f:Destroy()
		ClientState.SetUi("Settings", false)
		return
	end
	ClientState.SetUi("Settings", true)
	local panel = UiKit.Frame(top, "Settings", UDim2.fromOffset(440, 300), UDim2.new(0.5, -220, 0.5, -150), Color3.fromRGB(4, 14, 7), 0.05)
	panel.ZIndex = 40
	settingsFrame = panel
	UiKit.Corner(panel, 0, 10)
	UiKit.Stroke(panel, Color3.fromRGB(60, 70, 62), 6, 0)
	local title = UiKit.Text(panel, "Title", "SETTINGS", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 8), UiKit.MonoBold, 24, GREEN)
	title.ZIndex = 41
	type Row = { Key: string, Label: string, Min: number, Max: number, Step: number }
	local rows: { Row } = {
		{ Key = "MusicVolume", Label = "MUSIC", Min = 0, Max = 1, Step = 0.1 },
		{ Key = "EffectsVolume", Label = "EFFECTS", Min = 0, Max = 1, Step = 0.1 },
		{ Key = "Brightness", Label = "BRIGHTNESS", Min = -0.3, Max = 0.3, Step = 0.05 },
	}
	local y = 56
	-- Kamerawackeln reduzieren (Barrierefreiheit)
	local shakeBtn = UiKit.Button(panel, "Shake", "", UDim2.fromOffset(400, 34), UDim2.fromOffset(20, y), GREEN)
	shakeBtn.ZIndex = 41
	local function refreshShake()
		shakeBtn.Text = "REDUCE CAMERA SHAKE: " .. (if Settings.ReduceShake then "ON" else "OFF")
	end
	refreshShake()
	shakeBtn.MouseButton1Click:Connect(function()
		Settings.Set("ReduceShake", not Settings.ReduceShake)
		refreshShake()
	end)
	y += 46
	for _, row in rows do
		local key, label, mn, mx, step = row.Key, row.Label, row.Min, row.Max, row.Step
		local lbl = UiKit.Text(panel, "Label", "", UDim2.fromOffset(240, 34), UDim2.fromOffset(20, y), UiKit.Mono, 18, GREEN)
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.ZIndex = 41
		local function refresh()
			local v = (Settings :: any)[key] :: number
			lbl.Text = string.format("%s  %d%%", label, math.floor((v - mn) / (mx - mn) * 100 + 0.5))
		end
		refresh()
		local minus = UiKit.Button(panel, "Minus", "-", UDim2.fromOffset(50, 34), UDim2.fromOffset(300, y), GREEN)
		minus.ZIndex = 41
		local plus = UiKit.Button(panel, "Plus", "+", UDim2.fromOffset(50, 34), UDim2.fromOffset(360, y), GREEN)
		plus.ZIndex = 41
		minus.MouseButton1Click:Connect(function()
			Settings.Set(key, math.clamp(((Settings :: any)[key] :: number) - step, mn, mx))
			refresh()
		end)
		plus.MouseButton1Click:Connect(function()
			Settings.Set(key, math.clamp(((Settings :: any)[key] :: number) + step, mn, mx))
			refresh()
		end)
		y += 44
	end
	local close = UiKit.Button(panel, "Close", "CLOSE [P]", UDim2.fromOffset(160, 32), UDim2.new(0.5, -80, 1, -44), GREEN)
	close.ZIndex = 41
	close.MouseButton1Click:Connect(Screens.ToggleSettings)
end

function Screens.CloseAll()
	Screens.CloseNote()
	if settingsFrame then
		Screens.ToggleSettings()
	end
end

----------------------------------------------------------------------
-- Kill-Effekt, Tod, Ende
----------------------------------------------------------------------
function Screens.PlayKill()
	-- Frost wuchert in 1 s über das Bild, ein Riss zersplittert, Schnitt auf Schwarz
	frostCover.GroupTransparency = 1
	UiKit.Tween(frostCover, Config.Camera.KillFrostTime, { GroupTransparency = 0.05 })
	task.delay(Config.Camera.KillFrostTime + 0.5, function()
		crack.Visible = true
		task.wait(0.35)
		overlay.BackgroundTransparency = 0
		crack.Visible = false
		frostCover.GroupTransparency = 1
		task.wait(0.8)
		UiKit.Tween(overlay, 1.2, { BackgroundTransparency = 1 })
	end)
end

local function signalLost(text: string, keep: boolean)
	overlayText.Text = text
	overlayText.TextColor3 = Color3.fromRGB(230, 240, 255)
	UiKit.Tween(overlayText, 0.4, { TextTransparency = 0 })
	-- Glitch
	task.spawn(function()
		for _ = 1, 8 do
			overlayText.Position = UDim2.new(0, math.random(-12, 12), 0.42, math.random(-4, 4))
			task.wait(0.05)
		end
		overlayText.Position = UDim2.new(0, 0, 0.42, 0)
	end)
	if not keep then
		task.delay(2.5, function()
			UiKit.Tween(overlayText, 1, { TextTransparency = 1 })
		end)
	end
end

function Screens.ShowDeath()
	signalLost("SIGNAL LOST", false)
end

function Screens.ShowMissing()
	overlay.BackgroundTransparency = 0.3
	signalLost("LEFT BEHIND", false)
	task.delay(2.5, function()
		UiKit.Tween(overlay, 1, { BackgroundTransparency = 1 })
	end)
end

function Screens.ShowEscaped()
	Screens.Notify("YOU MADE IT ABOARD - WAITING FOR TAKEOFF")
end

local function formatTime(s: number): string
	return Util.FormatTime(s)
end

local function showResults(victory: boolean, summary: { { [string]: any } })
	if resultFrame then
		resultFrame:Destroy()
	end
	local f = UiKit.Frame(top, "Results", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), if victory then 0.25 else 0.15)
	f.ZIndex = 25
	resultFrame = f
	local title = UiKit.Text(f, "Title", if victory then "EXTRACTION SUCCESSFUL" else "SIGNAL LOST", UDim2.new(1, 0, 0, 60), UDim2.fromScale(0, 0.12), UiKit.Label, 44, if victory then Color3.fromRGB(220, 235, 255) else ICE)
	title.ZIndex = 26
	local sub = UiKit.Text(f, "Sub", if victory then "EREBOS STATION - EVACUATION REPORT" else "NO SURVIVORS EVACUATED", UDim2.new(1, 0, 0, 24), UDim2.fromScale(0, 0.2), UiKit.Mono, 18, AMBER)
	sub.ZIndex = 26
	local tbl = UiKit.Frame(f, "Table", UDim2.fromOffset(820, 300), UDim2.new(0.5, -410, 0.28, 0), Color3.fromRGB(3, 12, 6), 0.1)
	tbl.ZIndex = 26
	UiKit.Corner(tbl, 0, 8)
	UiKit.Stroke(tbl, Color3.fromRGB(60, 80, 64), 3, 0)
	local header = string.format("%-14s %9s %10s %9s %8s %9s %9s", "NAME", "SURVIVED", "LOWEST °C", "DISTRACT", "REVIVES", "DETECTED", "STATUS")
	local lines = { header, string.rep("-", #header) }
	for _, row in summary do
		table.insert(lines, string.format(
			"%-14s %9s %10.1f %9d %8d %9d %9s",
			string.sub(string.upper(tostring(row.Name)), 1, 14),
			formatTime(tonumber(row.Survived) or 0),
			tonumber(row.LowestTemp) or 0,
			tonumber(row.Distractions) or 0,
			tonumber(row.Revives) or 0,
			tonumber(row.Detected) or 0,
			if row.Escaped == true then "ESCAPED" else "LOST"
		))
	end
	local body = UiKit.Text(tbl, "Body", table.concat(lines, "\n"), UDim2.new(1, -30, 1, -30), UDim2.fromOffset(15, 15), UiKit.Mono, 17, GREEN)
	body.RichText = false
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.ZIndex = 27
	local back = UiKit.Text(f, "Back", "", UDim2.new(1, 0, 0, 24), UDim2.fromScale(0, 0.82), UiKit.Mono, 16, Color3.fromRGB(180, 190, 200))
	back.ZIndex = 26
	local seconds = if victory then Config.Round.VictoryScreenTime else Config.Round.DefeatScreenTime
	task.spawn(function()
		for s = seconds, 1, -1 do
			if resultFrame ~= f then
				return
			end
			back.Text = string.format("RETURNING TO THE LOBBY IN %d", s)
			task.wait(1)
		end
	end)
	if not victory then
		frostCover.GroupTransparency = 1
		UiKit.Tween(frostCover, 2.5, { GroupTransparency = 0.25 })
	end
end

function Screens.OnRoundState(state: string, data: any)
	if state == "Victory" or state == "Defeat" then
		if type(data) == "table" then
			showResults(state == "Victory", data)
		end
	elseif state == "Lobby" then
		if resultFrame then
			resultFrame:Destroy()
			resultFrame = nil
		end
		frostCover.GroupTransparency = 1
		overlay.BackgroundTransparency = 1
		overlayText.TextTransparency = 1
	elseif state == "Dead" then
		Screens.ShowDeath()
	elseif state == "Missing" then
		Screens.ShowMissing()
	elseif state == "Escaped" then
		Screens.ShowEscaped()
	elseif state == "Extraction" and type(data) == "table" and type(data.DepartAt) == "number" and data.DepartAt > 0 then
		Screens.Notify("HELICOPTER DEPARTS IN 30 SECONDS")
	end
end

----------------------------------------------------------------------
-- Wärmebild-Scanner: Ziele durch Wände markieren
----------------------------------------------------------------------
function Screens.ScannerResult(results: { any }, duration: number)
	local cam = Workspace.CurrentCamera
	if cam == nil then
		return
	end
	local created: { Instance } = {}
	for _, r in results do
		if type(r) == "table" then
			local kind = r.Kind
			local color = if kind == "Creature" then Color3.fromRGB(255, 40, 30) elseif kind == "Player" then Color3.fromRGB(255, 200, 60) else Color3.fromRGB(255, 120, 30)
			local target = r.Target
			if typeof(target) == "Instance" and target.Parent then
				local h = Instance.new("Highlight")
				h.Adornee = target
				h.FillColor = color
				h.OutlineColor = color
				h.FillTransparency = 0.45
				h.OutlineTransparency = 0
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.Parent = cam
				table.insert(created, h)
			elseif typeof(r.Position) == "Vector3" then
				local p = Instance.new("Part")
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.Transparency = 1
				p.Size = Vector3.new(1, 1, 1)
				p.Position = r.Position
				p.Parent = cam
				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.fromOffset(46, 46)
				bb.AlwaysOnTop = true
				bb.LightInfluence = 0
				bb.Adornee = p
				bb.Parent = p
				local blob = UiKit.Frame(bb, "Blob", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), color, 0.35)
				UiKit.Corner(blob, 1)
				UiKit.Stroke(blob, Color3.fromRGB(255, 220, 120), 2, 0.2)
				table.insert(created, p)
			end
		end
	end
	Screens.Notify("THERMAL SCAN: " .. #results .. " SIGNATURES")
	task.delay(duration, function()
		for _, inst in created do
			inst:Destroy()
		end
	end)
end

----------------------------------------------------------------------
-- Status-Zeile, Zuschauer, Hinweise (pro Frame)
----------------------------------------------------------------------
function Screens.Update(spectateTarget: Player?)
	local st = Util.GetState(player)
	local t = Workspace:GetServerTimeNow()
	local map = Workspace:FindFirstChild("Map")
	local status = ""
	if st == "Downed" then
		local left = math.max(0, math.ceil(Util.NumAttr(player, "DownedEnd", t) - t))
		status = if player:GetAttribute("Reviving") == true then string.format("BEING REVIVED...  %ds", left) else string.format("COLLAPSED - A TEAMMATE MUST HOLD [E]  %ds", left)
	elseif player:GetAttribute("Reviving") == true then
		status = "REVIVING..."
	elseif map then
		local cd = Util.NumAttr(map, "CountdownEnd", 0)
		local heli = Util.NumAttr(map, "HeliDepartAt", 0)
		if cd > t and st == "Lobby" then
			status = string.format("DESCENT IN %d - STAND IN THE YELLOW AIRLOCK", math.ceil(cd - t))
		elseif heli > t and (st == "Alive" or st == "Escaped") then
			status = string.format("HELICOPTER DEPARTS IN %d", math.ceil(heli - t))
		elseif map:GetAttribute("PowerState") == "Flicker" and st == "Alive" then
			status = "POWER FAILURE"
		end
	end
	statusLabel.Text = status
	statusLabel.TextColor3 = if st == "Downed" then ICE else AMBER

	if ClientState.Spectating then
		local name = if spectateTarget then string.upper(spectateTarget.DisplayName) else "NO SIGNAL"
		local how = if UserInputService.TouchEnabled then "TAP USE/SCAN" else "CLICK"
		spectateLabel.Text = string.format("SPECTATING: %s   [%s TO SWITCH]", name, how)
	else
		spectateLabel.Text = ""
	end

	if st == "Lobby" then
		hintLabel.Text = "Z PRONE  ·  C CROUCH  ·  SHIFT SPRINT  ·  E INTERACT  ·  P SETTINGS\nPick gear at the EQUIPMENT lockers, break the glass and pull the lever - then stand in the yellow airlock."
	else
		hintLabel.Text = ""
	end
	gear.Visible = UserInputService.TouchEnabled or st == "Lobby"
	louvers.Visible = player:GetAttribute("InLocker") == true and st == "Alive"
end

return Screens
