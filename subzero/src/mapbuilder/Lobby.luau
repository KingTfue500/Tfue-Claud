--!strict
-- Zone 0: Lobby-Bunker (ca. 60 x 40). Sicherer Raum, einzige Lichtquelle ist der Ölofen.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Mat, Col = Kit.Mat, Kit.Col

local Lobby = {}

export type Ctx = { Map: Model, Volumes: Model, Config: any, Rng: Kit.Rng }

function Lobby.Build(ctx: Ctx)
	local o: Vector3 = ctx.Config.Map.LobbyOrigin
	local function V(x: number, y: number, z: number): Vector3
		return o + Vector3.new(x, y, z)
	end
	local function A(x: number, y: number, zz: number, yaw: number?): CFrame
		return Kit.At(o.X + x, o.Y + y, o.Z + zz, yaw)
	end
	local z = Kit.ZoneFolders(ctx.Map, "Zone0")
	local rng = ctx.Rng

	-- Hauptraum: Innenmaß x[-30,30], z[-20,20], Höhe 14
	Kit.Room(z.Geometry, {
		Name = "Bunker",
		Min = V(-30, 0, -20),
		Max = V(30, 14, 20),
		Openings = {
			{ Side = "N", Center = o.X, Width = 10, Height = 10, Sill = 2.5 }, -- Panzerglas-Fenster
		},
		WallMat = Mat.RustSteel,
		WallColor = Col.Rust,
		FloorMat = Mat.SaltConcrete,
		FloorColor = Col.ConcreteDark,
		CeilMat = Mat.RustSteel,
		CeilColor = Col.RustDark,
	})
	-- Untere Wandverkleidung aus Salz-Beton
	for _, seg in {
		{ V(-30, 0, 19.6), V(-6, 3.5, 20) },
		{ V(6, 0, 19.6), V(30, 3.5, 20) },
		{ V(-30, 0, -20), V(17, 3.5, -19.6) },
		{ V(-30, 0, -20), V(-29.6, 3.5, 20) },
	} do
		Kit.Box(z.Geometry, "Wainscot", seg[1], seg[2], Mat.SaltConcrete, Col.Concrete, { Thermal = true, Small = true })
	end

	------------------------------------------------------------------
	-- Rundes Panzerglas-Fenster (Achteck) mit Schneesturm dahinter
	------------------------------------------------------------------
	local wc = V(0, 7.5, 20.5) -- Fenstermitte in der Wand
	local winFolder = Kit.Model(z.Geometry, "ArmoredWindow")
	for _, s in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		-- Ecken-Keile machen aus dem Quadrat ein Achteck
		local cx = wc.X + s[1] * 3.5
		local cy = wc.Y + s[2] * 3.5
		local rot = CFrame.Angles(0, 0, math.rad(45))
		Kit.Part(winFolder, "WindowCorner", Vector3.new(4.3, 4.3, 0.9), CFrame.new(cx + s[1] * 1.5, cy + s[2] * 1.5, wc.Z) * rot, Mat.RustSteel, Col.Rust, { Thermal = true })
	end
	local glass = Kit.Part(winFolder, "ArmorGlass", Vector3.new(10, 10, 0.4), CFrame.new(wc), Mat.Glass, Color3.fromRGB(160, 190, 210), { Transparency = 0.55 })
	glass.Reflectance = 0.1
	Kit.Part(winFolder, "IceFilm", Vector3.new(9.6, 9.6, 0.05), CFrame.new(wc - Vector3.new(0, 0, 0.3)), Mat.IceSheet, Col.Ice, { Transparency = 0.82, CanCollide = false, Small = true })
	-- Fensterrahmen-Ring (8 Segmente)
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		local r = 5.6
		local pos = wc + Vector3.new(math.cos(a) * r, math.sin(a) * r, -0.6)
		Kit.Part(winFolder, "FrameRing", Vector3.new(1, 4.8, 0.8), CFrame.new(pos) * CFrame.Angles(0, 0, a), Mat.Metal, Col.FrostDark, { Small = true })
		-- Bolzen
		local bpos = wc + Vector3.new(math.cos(a) * 5.9, math.sin(a) * 5.9, -1.05)
		Kit.Ball(winFolder, "Bolt", bpos, 0.45, Mat.Metal, Col.Black, { Small = true, CanCollide = false })
	end
	-- Sturm-Kasten hinter dem Fenster
	local storm = Kit.Model(z.Geometry, "StormBackdrop")
	Kit.Box(storm, "StormFloor", V(-14, -2, 21), V(14, 1, 40), Mat.Snow, Col.Snow, { Thermal = true })
	Kit.Box(storm, "StormBack", V(-14, -2, 40), V(14, 22, 41), Mat.Rock, Color3.fromRGB(14, 18, 26), { Thermal = true })
	Kit.Box(storm, "StormLeft", V(-15, -2, 21), V(-14, 22, 41), Mat.Rock, Color3.fromRGB(14, 18, 26), { Thermal = true })
	Kit.Box(storm, "StormRight", V(14, -2, 21), V(15, 22, 41), Mat.Rock, Color3.fromRGB(14, 18, 26), { Thermal = true })
	Kit.Box(storm, "StormTop", V(-15, 22, 21), V(15, 23, 41), Mat.Rock, Color3.fromRGB(10, 12, 18), { Thermal = true })
	for i = 1, 5 do
		local x = rng:Range(-11, 11)
		local h = rng:Range(2, 7)
		Kit.Part(storm, "SnowDrift", Vector3.new(rng:Range(5, 9), h, rng:Range(4, 7)), CFrame.new(V(x, h / 2 - 0.5, rng:Range(26, 38))) * CFrame.Angles(0, rng:Range(0, 3), math.rad(rng:Range(-10, 10))), Mat.Snow, Col.Snow, { Small = true })
	end
	local stormEmit = Kit.Volume(storm, "SnowEmitter", CFrame.new(V(-12, 10, 30)), Vector3.new(2, 20, 18))
	local snow = Kit.Emitter(stormEmit, "Snow", {
		Texture = Kit.Tex.Sparkle,
		Color = Color3.fromRGB(235, 240, 255),
		Size0 = 0.25,
		Size1 = 0.15,
		Transparency0 = 0.1,
		Transparency1 = 0.6,
		Lifetime = NumberRange.new(1.2, 2),
		Rate = 140,
		Speed = NumberRange.new(18, 26),
		Spread = Vector2.new(15, 25),
		Acceleration = Vector3.new(0, -4, 0),
		EmissionDirection = Enum.NormalId.Right,
		Shape = Enum.ParticleEmitterShape.Box,
	})
	snow:AddTag("AmbientEmitter")
	local gust = Kit.Emitter(stormEmit, "Gust", {
		Color = Color3.fromRGB(200, 215, 235),
		Size0 = 4,
		Size1 = 8,
		Transparency0 = 0.8,
		Transparency1 = 1,
		Lifetime = NumberRange.new(1.5, 2.5),
		Rate = 6,
		Speed = NumberRange.new(14, 20),
		EmissionDirection = Enum.NormalId.Right,
		Shape = Enum.ParticleEmitterShape.Box,
	})
	gust:AddTag("AmbientEmitter")
	local moon = Kit.Volume(storm, "StormLight", CFrame.new(V(0, 18, 34)), Vector3.new(1, 1, 1))
	Kit.GlowLight(moon, Color3.fromRGB(120, 150, 200), 30, 0.6)

	------------------------------------------------------------------
	-- Ölofen (westliche Wand), einzige Lichtquelle
	------------------------------------------------------------------
	Props.Stove(z.Props, Kit.Face(V(-25, 0, -2), Vector3.new(1, 0, 0)), ctx.Config.Colors.StoveLight)
	Kit.Box(z.Props, "HearthPlate", V(-29.5, 0, -7), V(-21, 0.1, 3), Mat.Metal, Col.Black, { Small = true, CanCollide = false })
	Props.Bench(z.Props, Kit.Face(V(-17, 0, -8), Vector3.new(-1, 0, 0.6)), 6)
	Props.Bench(z.Props, Kit.Face(V(-17, 0, 4), Vector3.new(-1, 0, -0.6)), 6)
	Props.Chair(z.Props, Kit.Face(V(-15, 0, -2), Vector3.new(-1, 0, 0)))
	-- Holzkiste und Ölfässer neben dem Ofen
	Props.Barrel(z.Props, A(-27, 0, 8, 10), Color3.fromRGB(110, 40, 30))
	Props.Barrel(z.Props, A(-27, 0, 11.5, 70), Color3.fromRGB(110, 40, 30))

	------------------------------------------------------------------
	-- Schleuse (gelb markiert) in der Südost-Ecke: Innenmaß x[18,29], z[-19,-6]
	------------------------------------------------------------------
	local air = Kit.Model(z.Geometry, "LobbyAirlock")
	-- Nordwand der Schleuse
	Kit.Wall(air, "X", -6, -5, 17, 30, -1, 15, 0, {}, Mat.FrostMetal, Col.FrostDark)
	-- Westwand mit Tür
	Kit.Wall(air, "Z", 17, 18, -20, -6, -1, 15, 0, { { Side = "W", Center = -13, Width = 6, Height = 10 } }, Mat.FrostMetal, Col.FrostDark)
	local airDoor = Kit.Door(air, "LobbyAirlock", V(17.5, 0, -13), "Z", 6, 10, "Airlock")
	airDoor:AddTag("AirlockDoor")
	airDoor:SetAttribute("Locked", false)
	-- Gefahrenstreifen am Boden
	for i = 0, 10 do
		local x = 18.5 + i * 1.05
		Kit.Part(air, "HazardStripe", Vector3.new(0.5, 0.05, 2), CFrame.new(V(x, 0.03, -7.2)) * CFrame.Angles(0, math.rad(35), 0), Mat.Metal, Col.Hazard, { Small = true, CanCollide = false, CanQuery = false })
		Kit.Part(air, "HazardStripe", Vector3.new(0.5, 0.05, 2), CFrame.new(V(x, 0.03, -18)) * CFrame.Angles(0, math.rad(35), 0), Mat.Metal, Col.Hazard, { Small = true, CanCollide = false, CanQuery = false })
	end
	Kit.Box(air, "AirlockFloorMark", V(18, 0, -19), V(29, 0.04, -6), Mat.Metal, Color3.fromRGB(80, 70, 30), { Small = true, CanCollide = false, CanQuery = false })
	-- Abstiegs-Tor an der Ostwand (dekorativ)
	Kit.Box(air, "DescentGate", V(29.2, 0, -16), V(29.9, 11, -9), Mat.RustSteel, Col.FrostDark, { Thermal = true })
	for i = 0, 5 do
		Kit.Box(air, "GateStripe", V(29.1, 1 + i * 1.7, -16), V(29.15, 1.6 + i * 1.7, -9), Mat.Metal, if i % 2 == 0 then Col.Hazard else Col.HazardDark, { Small = true, CanCollide = false })
	end
	Kit.Sign(air, Kit.Face(V(29, 12, -12.5), Vector3.new(-1, 0, 0)), Vector2.new(6, 1), "DESCENT SHAFT", Col.Hazard)
	Kit.Sign(air, Kit.Face(V(17.2, 11.2, -13), Vector3.new(-1, 0, 0)), Vector2.new(5, 0.9), "AIRLOCK", Col.Hazard)
	-- Rundumleuchten
	Props.Beacon(air, CFrame.new(V(18.6, 12.5, -6.6)), ctx.Config.Colors.Beacon)
	Props.Beacon(air, CFrame.new(V(28.4, 12.5, -18.4)), ctx.Config.Colors.Beacon)
	Props.Beacon(z.Props, CFrame.new(V(16.4, 12.5, -4.4)), ctx.Config.Colors.Beacon)
	-- Schleusen-Volumen (wer hier steht, geht mit)
	local airVol = Kit.BoxVolume(z.Volumes, "AirlockVolume", V(18, 0, -19), V(29, 9, -6))
	airVol:AddTag("AirlockVolume")
	-- Nebel aus den Dichtungen
	local seal = Kit.Volume(air, "SealFog", CFrame.new(V(17.5, 0.5, -13)), Vector3.new(0.5, 0.5, 6))
	local sealFog = Kit.Emitter(seal, "Hiss", {
		Color = Color3.fromRGB(220, 225, 235),
		Size0 = 1,
		Size1 = 4,
		Transparency0 = 0.6,
		Transparency1 = 1,
		Lifetime = NumberRange.new(1, 2),
		Rate = 0,
		Speed = NumberRange.new(2, 5),
		Spread = Vector2.new(60, 60),
		Shape = Enum.ParticleEmitterShape.Box,
	})
	sealFog.Name = "AirlockHiss"

	------------------------------------------------------------------
	-- Abstiegs-Terminal und Notfall-Hebel (Ostwand, nördlich der Schleuse)
	------------------------------------------------------------------
	local _tm, _screen, termLabel = Props.Terminal(z.Props, Kit.Face(V(27.6, 0, 4), Vector3.new(-1, 0, 0)), "DescentTerminal", ctx.Config.Colors.CrtGreen, "EREBOS DESCENT CONTROL\n> BOOTING...")
	termLabel:SetAttribute("DescentText", true)
	_tm:AddTag("DescentTerminal")

	local lever = Kit.Model(z.Props, "EmergencyLever")
	lever:AddTag("EmergencyLever")
	local lcf = Kit.Face(V(29.4, 0, 10), Vector3.new(-1, 0, 0))
	Kit.Part(lever, "Box", Vector3.new(3, 4, 1.2), lcf * CFrame.new(0, 5, 0), Mat.Metal, Col.FrostDark, { Small = true })
	Kit.Part(lever, "Stripes", Vector3.new(3.1, 0.6, 1.25), lcf * CFrame.new(0, 7.2, 0), Mat.Metal, Col.Hazard, { Small = true, CanCollide = false })
	local handle = Kit.Part(lever, "Lever", Vector3.new(0.35, 2.4, 0.35), lcf * CFrame.new(0, 5.6, -0.9) * CFrame.Angles(math.rad(-30), 0, 0), Mat.Metal, Col.Danger, { Small = true, CanCollide = false })
	handle:SetAttribute("UpCF", handle.CFrame)
	handle:SetAttribute("DownCF", lcf * CFrame.new(0, 4.0, -0.9) * CFrame.Angles(math.rad(30), 0, 0))
	local knob = Kit.Ball(lever, "Knob", (lcf * CFrame.new(0, 6.8, -1.6)).Position, 0.6, Mat.Metal, Col.Danger, { Small = true, CanCollide = false })
	knob:SetAttribute("LeverKnob", true)
	local safety = Kit.Part(lever, "SafetyGlass", Vector3.new(2.6, 3.4, 0.15), lcf * CFrame.new(0, 5, -1.9), Mat.Glass, Color3.fromRGB(200, 230, 255), { Transparency = 0.5, CanCollide = false, Small = true })
	safety:SetAttribute("ClosedCF", safety.CFrame)
	Kit.Part(lever, "GlassFrame", Vector3.new(2.9, 3.7, 1.6), lcf * CFrame.new(0, 5, -1.25), Mat.Metal, Col.Danger, { Transparency = 0.85, CanCollide = false, Small = true })
	local li = Kit.Volume(lever, "Interact", lcf * CFrame.new(0, 5, -2.3), Vector3.new(2.6, 3.4, 0.5))
	li:SetAttribute("Interact", true)
	Kit.Sign(lever, lcf * CFrame.new(0, 8, -0.65), Vector2.new(3, 0.8), "EMERGENCY DESCENT", Col.Danger, Col.White)

	------------------------------------------------------------------
	-- Ausrüstungs-Spinde (Südwand)
	------------------------------------------------------------------
	for i = 0, 2 do
		local lk = Props.Locker(z.Props, Kit.Face(V(-10 + i * 3.2, 0, -18.6), Vector3.new(0, 0, 1)), "LoadoutLocker_" .. (i + 1), false)
		lk:AddTag("LoadoutLocker")
	end
	Kit.Sign(z.Props, Kit.Face(V(-6.8, 8, -19.5), Vector3.new(0, 0, 1)), Vector2.new(9, 1), "EQUIPMENT", Col.Hazard)
	Props.Bench(z.Props, Kit.Face(V(-6.8, 0, -14.5), Vector3.new(0, 0, 1)), 8)

	------------------------------------------------------------------
	-- Schwarzes Brett mit 3 Bestenlisten (Südwand)
	------------------------------------------------------------------
	local board = Kit.Model(z.Props, "BlackBoard")
	local bcf = Kit.Face(V(6, 0, -19.4), Vector3.new(0, 0, 1))
	Kit.Part(board, "Cork", Vector3.new(14, 6.5, 0.3), bcf * CFrame.new(0, 6.5, 0), Mat.Fabric, Color3.fromRGB(28, 26, 24), { Small = true })
	Kit.Part(board, "Frame", Vector3.new(14.6, 7.1, 0.2), bcf * CFrame.new(0, 6.5, 0.1), Mat.Wood, Col.Wood, { Small = true, CanCollide = false })
	local stats = { "Evacuations", "MinutesSurvived", "Distractions" }
	local titles = { "EVACUATIONS", "MINUTES SURVIVED", "THERMAL DISTRACTIONS" }
	for i = 1, 3 do
		local panel = Kit.Part(board, "Leaderboard_" .. stats[i], Vector3.new(4.3, 6, 0.1), bcf * CFrame.new((i - 2) * 4.55, 6.5, -0.2), Mat.Fabric, Color3.fromRGB(225, 215, 185), { Small = true, CanCollide = false })
		panel:AddTag("Leaderboard")
		panel:SetAttribute("Stat", stats[i])
		local gui = Instance.new("SurfaceGui")
		gui.Name = "BoardGui"
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(430, 600)
		gui.LightInfluence = 1
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.Parent = panel
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, -20, 0, 70)
		title.Position = UDim2.fromOffset(10, 10)
		title.BackgroundTransparency = 1
		title.FontFace = Font.fromEnum(Enum.Font.Michroma)
		title.TextColor3 = Color3.fromRGB(30, 25, 20)
		title.TextScaled = true
		title.Text = titles[i]
		title.Parent = gui
		local list = Instance.new("TextLabel")
		list.Name = "List"
		list.Size = UDim2.new(1, -30, 1, -100)
		list.Position = UDim2.fromOffset(15, 90)
		list.BackgroundTransparency = 1
		list.FontFace = Font.fromEnum(Enum.Font.RobotoMono)
		list.TextColor3 = Color3.fromRGB(40, 35, 30)
		list.TextSize = 30
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.Text = "NO DATA"
		list.Parent = gui
		-- Reißzwecke
		Kit.Ball(board, "Pin", (bcf * CFrame.new((i - 2) * 4.55, 9.3, -0.3)).Position, 0.3, Mat.Metal, Col.Danger, { Small = true, CanCollide = false })
	end
	Kit.Sign(board, bcf * CFrame.new(0, 10.4, -0.1), Vector2.new(8, 0.9), "STATION RECORDS", Col.Frost)

	------------------------------------------------------------------
	-- Übungs-Ecke (Nordwest): Puppe im Thermoanzug + Wand-Anzeige
	------------------------------------------------------------------
	Props.Dummy(z.Props, Kit.Face(V(-21, 0, 13), Vector3.new(1, 0, -0.5)))
	local disp = Kit.Part(z.Props, "TrainingDisplay", Vector3.new(0.3, 4, 7), CFrame.new(V(-29.6, 6.5, 12)), Mat.Metal, Col.Black, { Small = true })
	disp:AddTag("TrainingDisplay")
	Kit.Part(z.Props, "TrainingDisplayFrame", Vector3.new(0.4, 4.6, 7.6), CFrame.new(V(-29.75, 6.5, 12)), Mat.Metal, Col.FrostDark, { Small = true, CanCollide = false })
	local dl = Kit.Screen(disp, Enum.NormalId.Right, Vector2.new(700, 400), ctx.Config.Colors.CrtAmber, "SIG -- / RANGE --", "TrainingGui")
	dl.TextSize = 64
	dl.TextXAlignment = Enum.TextXAlignment.Center
	dl.TextYAlignment = Enum.TextYAlignment.Center
	Kit.Sign(z.Props, Kit.Face(V(-29.4, 9.4, 12), Vector3.new(1, 0, 0)), Vector2.new(6, 0.8), "THERMAL TRAINING", Col.Hazard)
	-- Bodenmarkierung
	for i = 0, 7 do
		local a = math.rad(i * 45)
		Kit.Part(z.Props, "TrainingMark", Vector3.new(1.4, 0.04, 0.4), CFrame.new(V(-21 + math.cos(a) * 6, 0.02, 13 + math.sin(a) * 6)) * CFrame.Angles(0, -a, 0), Mat.Metal, Col.Hazard, { Small = true, CanCollide = false, CanQuery = false })
	end

	------------------------------------------------------------------
	-- Ausstattung: Tisch mit Briefing, Kisten, Rohre, Kabel
	------------------------------------------------------------------
	Props.Table(z.Props, A(2, 0, 4, 0), 7, 3.5)
	Props.Chair(z.Props, Kit.Face(V(2, 0, 7.4), Vector3.new(0, 0, -1)))
	Props.Chair(z.Props, Kit.Face(V(-1, 0, 1), Vector3.new(0.3, 0, 1)), true)
	Props.Note(z.Props, CFrame.new(V(1, 3.15, 4)) * CFrame.Angles(0, math.rad(12), 0), "L1", "Clipboard")
	Props.Radio(z.Props, CFrame.new(V(4, 3.15, 3.6)) * CFrame.Angles(0, math.rad(-20), 0))
	Props.Crate(z.Props, A(12, 0, 16, 8), Vector3.new(4, 3.5, 4))
	Props.Crate(z.Props, A(16, 0, 16.5, -12), Vector3.new(3.5, 3, 3.5))
	Props.Crate(z.Props, A(13.5, 3.5, 16.2, 30), Vector3.new(2.5, 2.2, 2.5))
	Props.Shelf(z.Props, Kit.Face(V(22, 0, 18.6), Vector3.new(0, 0, -1)), 8, rng)
	for i = 0, 4 do
		Props.Pipe(z.Props, V(-30, 12.6 - i * 0.05, -16 + i * 1.4), V(30, 12.6 - i * 0.05, -16 + i * 1.4), 0.8, if i == 2 then Col.Copper else Col.Pipe)
	end
	Props.Pipe(z.Props, V(-29.2, 0, 17), V(-29.2, 14, 17), 1.1)
	Props.Icicles(z.Geometry, V(0, 14, 17), 10, 5, 2.5, rng)

	------------------------------------------------------------------
	-- Spawn und Zonen-Volumen
	------------------------------------------------------------------
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(V(-8, -0.45, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CanTouch = true
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Material = Mat.SaltConcrete
	spawn.CollisionGroup = "ThermalClear"
	spawn.Parent = z.Spawns
	for i = 0, 5 do
		local a = math.rad(i * 60)
		Kit.Marker(z.Spawns, "Spawn", Kit.Face(V(-12 + math.cos(a) * 5, 3, math.sin(a) * 5), Vector3.new(-1, 0, 0)), "Spawn", { Zone = "Lobby" })
	end
	Kit.BoxVolume(ctx.Volumes, "Zone_Lobby", V(-31, -3, -21), V(31, 24, 42), { ZoneId = "Lobby" })
end

return Lobby
