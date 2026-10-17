--!strict
-- Zone 2: Bio-Labore (die Jagd beginnt, Minute 4 bis 8)
-- Dekon-Duschen mit Tropfwasser, Laborhalle mit Kryo-Tanks und Glaswänden,
-- Büro der Chef-Wissenschaftlerin (Whiteboard), Nest (Tresorraum), Zentrifugenraum.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Mat, Col = Kit.Mat, Kit.Col

local Zone2 = {}

export type Ctx = { Map: Model, Volumes: Model, Config: any, Rng: Kit.Rng }

function Zone2.Build(ctx: Ctx)
	local S: Vector3 = ctx.Config.Map.StationOrigin
	local function V(x: number, y: number, z: number): Vector3
		return S + Vector3.new(x, y, z)
	end
	local function A(x: number, y: number, zz: number, yaw: number?): CFrame
		return Kit.At(S.X + x, S.Y + y, S.Z + zz, yaw)
	end
	local z = Kit.ZoneFolders(ctx.Map, "Zone2")
	local rng = ctx.Rng
	local neon: Color3 = ctx.Config.Colors.Neon
	local tank: Color3 = ctx.Config.Colors.TankGreen

	local function lamp(x: number, y: number, zz: number, yaw: number?)
		Kit.CeilingLamp(z.Lights, V(x, y, zz), "PowerLight", "Zone2", neon, 20, 1.0, yaw)
	end
	local function itemSpawn(pos: Vector3, itemId: string)
		Kit.Marker(z.Props, "ItemSpawn", CFrame.new(pos), "ItemSpawn", { ItemId = itemId, Zone = "Zone2" })
	end

	------------------------------------------------------------------
	-- Räume
	------------------------------------------------------------------
	Kit.Room(z.Geometry, {
		Name = "Decon",
		Min = V(137, 0, -9),
		Max = V(161, 12, 9),
		Openings = {
			{ Side = "W", Center = S.Z, Width = 6, Height = 10 },
			{ Side = "E", Center = S.Z, Width = 6, Height = 10 },
		},
		WallMat = Mat.SaltConcrete,
		WallColor = Color3.fromRGB(150, 160, 160),
		FloorMat = Mat.SaltConcrete,
		FloorColor = Color3.fromRGB(110, 118, 118),
		FloorSurface = "Concrete",
	})
	Kit.Room(z.Geometry, {
		Name = "LabHall",
		Min = V(162, 0, -26),
		Max = V(226, 12, 26),
		Openings = {
			{ Side = "W", Center = S.Z, Width = 20, Height = 12 },
			{ Side = "N", Center = S.X + 181, Width = 6, Height = 10 },
			{ Side = "S", Center = S.X + 207, Width = 8, Height = 10 },
			{ Side = "E", Center = S.Z, Width = 6, Height = 10 },
		},
		WallMat = Mat.SaltConcrete,
		WallColor = Color3.fromRGB(165, 172, 170),
		FloorMat = Mat.SaltConcrete,
		FloorColor = Color3.fromRGB(120, 126, 124),
		CeilMat = Mat.FrostMetal,
		CeilColor = Col.FrostDark,
		RibColor = Col.FrostDark,
	})
	Kit.Room(z.Geometry, { Name = "ChiefOffice", Min = V(170, 0, 27), Max = V(192, 11, 45), Walls = { N = true, E = true, W = true }, WallMat = Mat.Wood, WallColor = Color3.fromRGB(95, 75, 55), WallTop = S.Y + 13 })
	Kit.Room(z.Geometry, {
		Name = "Nest",
		Min = V(192, 0, -56),
		Max = V(222, 12, -27),
		Walls = { S = true, E = true, W = true },
		WallMat = Mat.RustSteel,
		WallColor = Color3.fromRGB(70, 60, 58),
		FloorMat = Mat.IceSheet,
		FloorColor = Color3.fromRGB(80, 60, 70),
		FloorSurface = "Ice",
		Ribs = false,
	})
	Kit.Room(z.Geometry, { Name = "CentrifugeRoom", Min = V(227, 0, -13), Max = V(251, 11, 13), Walls = { N = true, S = true, E = true }, Corners = "E", WallTop = S.Y + 13, Openings = { { Side = "E", Center = S.Z, Width = 6, Height = 10 } }, WallMat = Mat.FrostMetal, WallColor = Col.Frost })

	-- Türen
	Kit.Door(z.Geometry, "Zone1to2", V(136.5, 0, 0), "Z", 6, 10, "Armor")
	Kit.Door(z.Geometry, "Office", V(181, 0, 26.5), "X", 6, 10, "Normal")
	Kit.Door(z.Geometry, "Centrifuge", V(226.5, 0, 0), "Z", 6, 10, "Normal")
	Kit.Door(z.Geometry, "Zone2to3", V(251.5, 0, 0), "Z", 6, 10, "Keycard")
	Props.KeycardReader(z.Props, Kit.Face(V(250.7, 0, -5), Vector3.new(-1, 0, 0)))
	Kit.Sign(z.Props, Kit.Face(V(250.6, 11.6, 0), Vector3.new(-1, 0, 0)), Vector2.new(6, 0.7), "CARGO BAY", Col.Hazard)
	Kit.Sign(z.Props, Kit.Face(V(137.5, 11.6, 0), Vector3.new(1, 0, 0)), Vector2.new(6, 0.7), "HABITATION", Col.Hazard)

	------------------------------------------------------------------
	-- Dekontaminations-Duschen mit kaputten Rohren
	------------------------------------------------------------------
	for i = 0, 3 do
		local x = 141 + i * 5.5
		for _, side in { -1, 1 } do
			local zz = side * 6.5
			Props.Pipe(z.Props, V(x, 12, zz), V(x, 9, zz), 0.4)
			Kit.Part(z.Props, "ShowerHead", Vector3.new(1.2, 0.3, 1.2), CFrame.new(V(x, 8.8, zz)), Mat.Metal, Col.Frost, { Small = true, CanCollide = false, Shape = Enum.PartType.Cylinder })
			Kit.Part(z.Props, "StallGlass", Vector3.new(0.15, 7, 4), CFrame.new(V(x + 2.75, 3.5, side * 7)), Mat.Glass, Col.Ice, { Transparency = 0.55, Small = true })
		end
	end
	Props.Pipe(z.Props, V(137, 11, 6.5), V(161, 11, 6.5), 0.6)
	Props.Pipe(z.Props, V(137, 11, -6.5), V(161, 11, -6.5), 0.6)
	-- Tropfstellen (sofort -1 °C und 30 s nass)
	for i, pos in { V(144.5, 0, -4.5), V(155.5, 0, 4.5) } do
		local drip = Kit.BoxVolume(z.Volumes, "DripZone_" .. i, pos + Vector3.new(-1.6, 0, -1.6), pos + Vector3.new(1.6, 9, 1.6))
		drip:AddTag("DripZone")
		Props.Pipe(z.Props, pos + Vector3.new(-3, 10.4, 0), pos + Vector3.new(0.2, 10.4, 0), 0.7, Col.Pipe)
		local broken = Kit.Part(z.Props, "BrokenPipeEnd", Vector3.new(0.6, 0.9, 0.9), CFrame.new(pos + Vector3.new(0.4, 10.4, 0)) * CFrame.Angles(0, 0, math.rad(20)), Mat.RustSteel, Col.RustDark, { Small = true, CanCollide = false, Shape = Enum.PartType.Cylinder })
		local drops = Kit.Emitter(broken, "Drips", {
			Texture = Kit.Tex.Sparkle,
			Color = Color3.fromRGB(170, 210, 255),
			Size0 = 0.18,
			Size1 = 0.12,
			Transparency0 = 0.1,
			Transparency1 = 0.3,
			Lifetime = NumberRange.new(0.6, 0.7),
			Rate = 9,
			Speed = NumberRange.new(1, 2),
			Spread = Vector2.new(8, 8),
			Acceleration = Vector3.new(0, -45, 0),
			EmissionDirection = Enum.NormalId.Bottom,
		})
		drops:AddTag("AmbientEmitter")
		Kit.Part(z.Props, "IcePuddle", Vector3.new(0.12, 4.5, 4.5), CFrame.new(pos + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)), Mat.IceSheet, Col.Ice, { Small = true, CanCollide = false, CanQuery = false, Shape = Enum.PartType.Cylinder, Transparency = 0.15 })
		Props.Icicles(z.Geometry, pos + Vector3.new(-1.5, 12, 0), 5, 1.2, 1.2, rng)
		drip:SetAttribute("SoundAnchor", true)
	end
	Kit.EmergencyLight(z.Lights, V(140, 9, 8.8), Vector3.new(0, 0, -1), "Zone2")
	Kit.EmergencyLight(z.Lights, V(158, 9, -8.8), Vector3.new(0, 0, 1), "Zone2")
	lamp(149, 11.7, 0, 90)
	Kit.GroundFog(z.Volumes, V(149, 0.8, 0), Vector3.new(20, 1, 14), Color3.fromRGB(190, 210, 210), 2)
	Props.Note(z.Props, CFrame.new(V(158, 0.05, -7.2)) * CFrame.Angles(0, math.rad(40), 0), "Z2_1", "Paper")

	------------------------------------------------------------------
	-- Laborhalle
	------------------------------------------------------------------
	-- Vereiste Glaswände trennen zwei Labor-Buchten (Gang in der Mitte)
	for _, zz in { 10, -10 } do
		for _, span in { { 166, 186 }, { 194, 222 } } do
			local len = span[2] - span[1]
			local glass = Kit.Part(z.Geometry, "GlassWall", Vector3.new(len, 9, 0.3), CFrame.new(V((span[1] + span[2]) / 2, 4.5, zz)), Mat.Glass, Col.Ice, { Transparency = 0.6 })
			glass.Reflectance = 0.05
			Kit.Part(z.Geometry, "GlassFrost", Vector3.new(len, 2.5, 0.35), CFrame.new(V((span[1] + span[2]) / 2, 1.25, zz)), Mat.IceSheet, Col.Ice, { Transparency = 0.45, Small = true, CanCollide = false })
			Kit.Part(z.Geometry, "GlassFrameTop", Vector3.new(len, 0.4, 0.5), CFrame.new(V((span[1] + span[2]) / 2, 9.2, zz)), Mat.Metal, Col.FrostDark, { Small = true })
			Kit.Part(z.Geometry, "GlassFrameBottom", Vector3.new(len, 0.3, 0.5), CFrame.new(V((span[1] + span[2]) / 2, 0.15, zz)), Mat.Metal, Col.FrostDark, { Small = true })
		end
	end
	-- Zerbrochene Kryo-Tanks
	for _, p in { V(176, 0, 18), V(206, 0, 18), V(176, 0, -18), V(214, 0, -18) } do
		Props.CryoTank(z.Props, Kit.At(p.X, p.Y, p.Z, rng:Range(0, 360)), true, tank)
	end
	Props.CryoTank(z.Props, A(191, 0, 18, 0), false, tank)
	-- Kryo-Schränke (Phiolen-Verstecke), 3 an der Nord-, 3 an der Südwand
	local cabIndex = 0
	for _, x in { 168, 192, 216 } do
		cabIndex += 1
		Props.CryoCabinet(z.Props, Kit.Face(V(x, 0, 24.7), Vector3.new(0, 0, -1)), cabIndex)
	end
	for _, x in { 168, 188, 220 } do
		cabIndex += 1
		Props.CryoCabinet(z.Props, Kit.Face(V(x, 0, -24.7), Vector3.new(0, 0, 1)), cabIndex)
	end
	-- Labortische mit Mikroskopen
	for _, p in { V(190, 0, -18), V(200, 0, -15), V(166, 0, 14), V(218, 0, 14) } do
		Props.Table(z.Props, CFrame.new(p), 5, 2.5)
		Kit.Part(z.Props, "Microscope", Vector3.new(0.8, 1.4, 0.8), CFrame.new(p + Vector3.new(1, 3.85, 0)), Mat.Metal, Col.White, { Small = true })
		Kit.Part(z.Props, "SampleRack", Vector3.new(1.4, 0.5, 0.6), CFrame.new(p + Vector3.new(-1, 3.4, 0.4)), Mat.Metal, Col.FrostDark, { Small = true })
	end
	Props.Note(z.Props, CFrame.new(V(200.5, 3.15, -15)) * CFrame.Angles(0, math.rad(-15), 0), "Z2_3", "Paper")
	itemSpawn(V(166, 3.4, 14), "Random")
	itemSpawn(V(218.5, 3.4, 14.3), "Random")
	Props.Locker(z.Props, Kit.Face(V(224.6, 0, 20), Vector3.new(-1, 0, 0)), "HideLocker_LabN", true)
	Props.Locker(z.Props, Kit.Face(V(163.4, 0, -20), Vector3.new(1, 0, 0)), "HideLocker_LabS", true)
	Props.EkgMonitor(z.Props, Kit.Face(V(222, 0, -14), Vector3.new(-1, 0, 0)))
	Kit.Vent(z.Props, "Z2_Lab", Kit.Face(V(176, 2.2, -26), Vector3.new(0, 0, 1)), "Zone2")
	for _, x in { 172, 196, 218 } do
		lamp(x, 11.7, 0, 90)
	end
	lamp(176, 11.7, 18)
	lamp(206, 11.7, -18)
	Kit.EmergencyLight(z.Lights, V(170, 9, 9.6), Vector3.new(0, 0, -1), "Zone2")
	Kit.EmergencyLight(z.Lights, V(212, 9, -9.6), Vector3.new(0, 0, 1), "Zone2")
	Kit.GroundFog(z.Volumes, V(194, 0.8, 0), Vector3.new(60, 1, 48), Color3.fromRGB(150, 210, 180), 4)
	Props.Icicles(z.Geometry, V(194, 12, 0), 20, 30, 24, rng)

	------------------------------------------------------------------
	-- Büro der Chef-Wissenschaftlerin
	------------------------------------------------------------------
	Props.Whiteboard(z.Props, Kit.Face(V(181, 0, 44.6), Vector3.new(0, 0, -1)))
	Props.Table(z.Props, A(178, 0, 35, 0), 6, 3)
	Props.Chair(z.Props, Kit.Face(V(178, 0, 37.5), Vector3.new(0, 0, -1)))
	Props.Note(z.Props, CFrame.new(V(177, 3.15, 35)), "Z2_2", "Tape")
	Props.Shelf(z.Props, Kit.Face(V(190.8, 0, 36), Vector3.new(-1, 0, 0)), 8, rng)
	Props.Locker(z.Props, Kit.Face(V(171.4, 0, 40), Vector3.new(1, 0, 0)), "HideLocker_Office", true)
	Props.Radio(z.Props, CFrame.new(V(180, 3.15, 34.5)))
	lamp(181, 10.7, 36)

	------------------------------------------------------------------
	-- Nest: aufgebrochener Tresorraum voller gefrorener Wucherungen
	------------------------------------------------------------------
	-- Tresortür-Rahmen und herausgerissene Tür
	for i = 0, 11 do
		local a = math.rad(i * 30)
		local pos = V(207 + math.cos(a) * 6, 5 + math.sin(a) * 6, -27.6)
		if pos.Y > S.Y + 0.5 then
			Kit.Part(z.Props, "VaultRing", Vector3.new(1.4, 3.4, 1.6), CFrame.new(pos) * CFrame.Angles(0, 0, a), Mat.Metal, Col.FrostDark, { Small = true })
		end
	end
	Kit.Part(z.Props, "VaultDoor", Vector3.new(1.6, 11, 11), CFrame.new(V(197, 4.2, -33)) * CFrame.Angles(0, math.rad(30), math.rad(-70)), Mat.Metal, Col.FrostDark, { Shape = Enum.PartType.Cylinder })
	for i = 1, 8 do
		local a = math.rad(i * 45)
		Kit.Part(z.Props, "VaultBolt", Vector3.new(1.4, 0.8, 0.8), CFrame.new(V(197, 4.2, -33)) * CFrame.Angles(0, math.rad(30), math.rad(-70)) * CFrame.new(0.4, math.cos(a) * 4.6, math.sin(a) * 4.6), Mat.Metal, Col.Frost, { Small = true, CanCollide = false })
	end
	-- Wucherungen an Wänden und Boden (Mitte frei für das Wesen)
	for _ = 1, 14 do
		local side = rng:Int(1, 3)
		local p: Vector3
		if side == 1 then
			p = V(rng:Range(194, 199), rng:Range(0, 9), rng:Range(-54, -30))
		elseif side == 2 then
			p = V(rng:Range(215, 220), rng:Range(0, 9), rng:Range(-54, -30))
		else
			p = V(rng:Range(196, 218), rng:Range(0, 9), rng:Range(-55, -52))
		end
		Props.Growth(z.Props, p, rng:Range(2.5, 5), rng)
	end
	for _ = 1, 6 do
		Props.Growth(z.Props, V(rng:Range(196, 218), 11, rng:Range(-54, -30)), rng:Range(2, 3.5), rng)
	end
	-- Nest-Mulde
	Kit.Part(z.Props, "NestBed", Vector3.new(1, 14, 14), CFrame.new(V(207, 0.1, -46)) * CFrame.Angles(0, 0, math.rad(90)), Mat.Glacier, Col.Organic, { Shape = Enum.PartType.Cylinder, CanCollide = false, Small = true })
	Props.BloodTrail(z.Props, V(207, 0, -29), V(205, 0, -44), rng)
	local glow = Kit.Volume(z.Lights, "NestGlow", CFrame.new(V(207, 6, -46)), Vector3.new(1, 1, 1))
	local nl = Kit.GlowLight(glow, Color3.fromRGB(90, 160, 255), 22, 0.5)
	nl.Name = "NestLight"
	glow:AddTag("NestGlow")
	Kit.GroundFog(z.Volumes, V(207, 0.8, -42), Vector3.new(26, 1, 26), Color3.fromRGB(150, 160, 190), 4)
	Kit.Marker(z.Props, "EntitySpawn", Kit.Face(V(207, 5, -46), Vector3.new(0, 0, 1)), "EntitySpawn")
	Kit.Vent(z.Props, "Z2_Nest", Kit.Face(V(222, 2.2, -38), Vector3.new(-1, 0, 0)), "Zone2")
	Kit.Sign(z.Props, Kit.Face(V(207, 11.4, -26.3), Vector3.new(0, 0, -1)), Vector2.new(6, 0.8), "VAULT B-7", Col.FrostDark, Col.White)

	------------------------------------------------------------------
	-- Zentrifugenraum
	------------------------------------------------------------------
	Props.Centrifuge(z.Props, Kit.Face(V(240, 0, -2), Vector3.new(-1, 0, 0)))
	Kit.Sign(z.Props, Kit.Face(V(240, 9.5, -12.6), Vector3.new(0, 0, 1)), Vector2.new(7, 0.9), "CENTRIFUGE CF-9", Col.Frost)
	Props.Locker(z.Props, Kit.Face(V(228.4, 0, -10), Vector3.new(1, 0, 0)), "HideLocker_Centrifuge", true)
	Props.Shelf(z.Props, Kit.Face(V(244, 0, 11.8), Vector3.new(0, 0, -1)), 6, rng)
	Kit.Vent(z.Props, "Z2_Centrifuge", Kit.Face(V(232, 2.2, 13), Vector3.new(0, 0, -1)), "Zone2")
	itemSpawn(V(244, 2.5, 11.8), "Random")
	lamp(236, 10.7, -8, 90)
	lamp(244, 10.7, 6, 90)
	Kit.EmergencyLight(z.Lights, V(250.8, 9, 6), Vector3.new(-1, 0, 0), "Zone2")

	------------------------------------------------------------------
	-- Wegpunkte, Zonen-Volumen
	------------------------------------------------------------------
	local wps = {
		V(149, 0, 0), V(170, 0, 0), V(190, 0, 0), V(214, 0, 0), V(180, 0, 18), V(200, 0, 18),
		V(172, 0, -18), V(200, 0, -21), V(181, 0, 35), V(207, 0, -34), V(207, 0, -46), V(234, 0, -8), V(234, 0, 8),
	}
	for i, p in wps do
		Kit.Waypoint(z.Waypoints, p, "Zone2", i)
	end
	Kit.BoxVolume(ctx.Volumes, "Zone_Zone2", V(136, -2, -57), V(252, 14, 46), { ZoneId = "Zone2" })
end

return Zone2
