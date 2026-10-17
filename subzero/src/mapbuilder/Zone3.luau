--!strict
-- Zone 3: Cargo Bay und Werkstatt (Hochgefahr, Minute 8 bis 12)
-- Offene Halle ca. 120 x 80, drei Ebenen Gerüst aus Metallgittern, Container,
-- Gabelstapler, Generator mit Heizstrahlern, Lastenaufzug zum Reaktor.
-- Kein Licht außer der eigenen Lampe, bis der Generator läuft.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Mat, Col = Kit.Mat, Kit.Col

local Zone3 = {}

export type Ctx = { Map: Model, Volumes: Model, Config: any, Rng: Kit.Rng }

function Zone3.Build(ctx: Ctx)
	local S: Vector3 = ctx.Config.Map.StationOrigin
	local function V(x: number, y: number, z: number): Vector3
		return S + Vector3.new(x, y, z)
	end
	local function A(x: number, y: number, zz: number, yaw: number?): CFrame
		return Kit.At(S.X + x, S.Y + y, S.Z + zz, yaw)
	end
	local z = Kit.ZoneFolders(ctx.Map, "Zone3")
	local rng = ctx.Rng
	local GRATE: Kit.PartOpts = { Surface = "Grate" }

	local function itemSpawn(pos: Vector3, itemId: string)
		Kit.Marker(z.Props, "ItemSpawn", CFrame.new(pos), "ItemSpawn", { ItemId = itemId, Zone = "Zone3" })
	end
	-- Lampen, die erst mit dem Generator angehen
	local function genLamp(x: number, y: number, zz: number, yaw: number?)
		local tube = Kit.CeilingLamp(z.Lights, V(x, y, zz), "GeneratorLight", "Zone3", Color3.fromRGB(255, 200, 150), 34, 1.6, yaw)
		local light = tube:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = false
		end
		tube.Color = Color3.fromRGB(40, 36, 30)
		tube.Material = Mat.Glass
		tube:RemoveTag("PowerLight")
	end

	------------------------------------------------------------------
	-- Räume
	------------------------------------------------------------------
	Kit.Room(z.Geometry, {
		Name = "Connector",
		Min = V(252, 0, -4),
		Max = V(268, 11, 4),
		Walls = { N = true, S = true },
		Corners = "None",
		WallTop = S.Y + 13,
		WallMat = Mat.FrostMetal,
		WallColor = Col.FrostDark,
	})
	Kit.Room(z.Geometry, {
		Name = "CargoHall",
		Min = V(269, 0, -40),
		Max = V(389, 40, 40),
		Openings = {
			{ Side = "W", Center = S.Z, Width = 8, Height = 10 },
			{ Side = "N", Center = S.X + 305, Width = 6, Height = 10 },
		},
		WallMat = Mat.RustSteel,
		WallColor = Col.Rust,
		FloorMat = Mat.SaltConcrete,
		FloorColor = Color3.fromRGB(70, 70, 68),
		FloorSurface = "Concrete",
		CeilColor = Color3.fromRGB(40, 32, 28),
	})
	Kit.Room(z.Geometry, { Name = "Workshop", Min = V(290, 0, 41), Max = V(320, 11, 61), Walls = { N = true, E = true, W = true }, WallTop = S.Y + 13, WallMat = Mat.RustSteel, WallColor = Col.RustDark })
	Kit.Door(z.Geometry, "Workshop", V(305, 0, 40.5), "X", 6, 10, "Normal")
	Kit.Sign(z.Props, Kit.Face(V(305, 10.8, 39.6), Vector3.new(0, 0, -1)), Vector2.new(5, 0.7), "WORKSHOP")
	Kit.EmergencyLight(z.Lights, V(260, 9, 3.8), Vector3.new(0, 0, -1), "Zone3")

	-- Dachträger
	for x = 277, 381, 16 do
		Kit.Box(z.Geometry, "RoofBeam", V(x - 0.6, 37.5, -40), V(x + 0.6, 40, 40), Mat.RustSteel, Col.RustDark, { Thermal = true, Small = true })
	end
	-- Bodenmarkierungen
	for i = 0, 10 do
		Kit.Part(z.Props, "FloorLine", Vector3.new(4, 0.04, 0.4), CFrame.new(V(276 + i * 10, 0.02, 0)), Mat.Metal, Col.Hazard, { Small = true, CanCollide = false, CanQuery = false })
	end

	------------------------------------------------------------------
	-- Gerüst: drei Ebenen aus Metallgittern an der Südwand (laut!)
	------------------------------------------------------------------
	local scaffold = Kit.Model(z.Geometry, "Scaffold")
	local levels = { 12, 22, 32 }
	for li, y in levels do
		Kit.Box(scaffold, "Deck" .. li, V(280, y - 0.5, -40), V(360, y, -30), Mat.GrateMetal, Col.Grate, GRATE)
		-- Geländer an der Vorderkante, Lücken für die Treppenabsätze
		local gaps: { { number } } = if li == 1 then { { 302, 308 }, { 314, 320 } } elseif li == 2 then { { 335, 341 } } else { { 356, 360 } }
		local cursor = 280
		for _, g in gaps do
			if g[1] > cursor then
				Props.Railing(scaffold, V(cursor, y, -30.3), V(g[1], y, -30.3))
			end
			cursor = g[2]
		end
		if cursor < 360 then
			Props.Railing(scaffold, V(cursor, y, -30.3), V(360, y, -30.3))
		end
		Props.Railing(scaffold, V(280.3, y, -40), V(280.3, y, -30.3))
		Props.Railing(scaffold, V(359.7, y, -40), V(359.7, y, -30.3))
	end
	for x = 280, 360, 16 do
		Kit.Box(scaffold, "Column", V(x - 0.4, 0, -31), V(x + 0.4, 32, -30.2), Mat.RustSteel, Col.Hazard, {})
		Kit.Box(scaffold, "ColumnBack", V(x - 0.4, 0, -40), V(x + 0.4, 32, -39.2), Mat.RustSteel, Col.RustDark, {})
	end
	-- Treppenabsätze und Rampen (keine Überschneidungen, damit auch das Wesen hochkommt)
	local landings = { { 302, 308, 12 }, { 314, 320, 12 }, { 335, 341, 22 }, { 356, 362, 32 } }
	for _, l in landings do
		Kit.Box(scaffold, "Landing", V(l[1], l[3] - 0.5, -30), V(l[2], l[3], -24), Mat.GrateMetal, Col.Grate, GRATE)
		Kit.Box(scaffold, "LandingPost", V(l[1], 0, -24.6), V(l[1] + 0.6, l[3] - 0.5, -24), Mat.RustSteel, Col.Hazard, {})
		Kit.Box(scaffold, "LandingPost", V(l[2] - 0.6, 0, -24.6), V(l[2], l[3] - 0.5, -24), Mat.RustSteel, Col.Hazard, {})
		Props.Railing(scaffold, V(l[1], l[3], -24.2), V(l[2], l[3], -24.2))
	end
	Props.Railing(scaffold, V(361.8, 32, -30), V(361.8, 32, -24.2))
	Props.Railing(scaffold, V(360, 32, -30.3), V(362, 32, -30.3))
	Props.Stairs(scaffold, V(284, 0, -27), Vector3.new(1, 0, 0), 12, 18, 6)
	Props.Stairs(scaffold, V(320, 12, -27), Vector3.new(1, 0, 0), 10, 15, 6)
	Props.Stairs(scaffold, V(341, 22, -27), Vector3.new(1, 0, 0), 10, 15, 6)
	for _, x in { 326, 333, 347, 354 } do
		local y = if x < 340 then 12 + (x - 320) / 15 * 10 else 22 + (x - 341) / 15 * 10
		Kit.Box(scaffold, "RampPost", V(x - 0.3, 0, -27.3), V(x + 0.3, y - 0.3, -26.7), Mat.RustSteel, Col.RustDark, {})
	end
	Kit.Sign(scaffold, Kit.Face(V(320, 34.5, -30.2), Vector3.new(0, 0, 1)), Vector2.new(8, 1), "LEVEL 3 - STORAGE", Col.Hazard)

	------------------------------------------------------------------
	-- Container, Gabelstapler, Kisten
	------------------------------------------------------------------
	Props.Container(z.Props, A(296, 0, 16, 0), Color3.fromRGB(150, 50, 35), false)
	Props.Container(z.Props, A(296, 8.5, 16, 0), Color3.fromRGB(40, 80, 120), false)
	Props.Container(z.Props, A(318, 0, 14, 0), Color3.fromRGB(60, 100, 60), true)
	Props.Container(z.Props, A(345, 0, 2, 90), Color3.fromRGB(170, 120, 40), false)
	Props.Forklift(z.Props, Kit.Face(V(334, 0, 28), Vector3.new(-1, 0, 0.3)))
	for _ = 1, 10 do
		local zz = if rng:Next() < 0.5 then rng:Range(-20, -8) else rng:Range(8, 30)
		local p = V(rng:Range(274, 288), 0, zz)
		Props.Crate(z.Props, Kit.At(p.X, 0, p.Z, rng:Range(0, 90)), Vector3.new(rng:Range(3, 5), rng:Range(2.5, 4), rng:Range(3, 5)))
	end
	for _ = 1, 6 do
		Props.Barrel(z.Props, A(rng:Range(350, 365), 0, rng:Range(16, 34), rng:Range(0, 180)))
	end
	Props.Locker(z.Props, Kit.Face(V(270.4, 0, -18), Vector3.new(1, 0, 0)), "HideLocker_HallW", true)
	Props.Locker(z.Props, Kit.Face(V(326, 0, 4), Vector3.new(0, 0, -1)), "HideLocker_Container", true)
	Props.Note(z.Props, CFrame.new(V(347, 8.55, 2)) * CFrame.Angles(0, math.rad(15), 0), "Z3_2", "Clipboard")
	itemSpawn(V(300, 32.6, -35), "Random")
	itemSpawn(V(318, 1.0, 22), "Random")
	itemSpawn(V(276, 1.0, 34), "Random")
	Kit.GroundFog(z.Volumes, V(329, 0.8, 0), Vector3.new(110, 1, 70), Color3.fromRGB(120, 125, 135), 8)
	Props.Icicles(z.Geometry, V(329, 37.5, 0), 26, 55, 36, rng)

	------------------------------------------------------------------
	-- Generator, Heizstrahler, Flutlichter
	------------------------------------------------------------------
	Props.Generator(z.Props, Kit.Face(V(375, 0, -12), Vector3.new(-1, 0, 0)))
	Kit.Sign(z.Props, Kit.Face(V(375, 9.5, -17.6), Vector3.new(0, 0, 1)), Vector2.new(5, 0.7), "GEN-2 DIESEL", Col.Hazard)
	local genCenter = V(368, 0, -10)
	for _, p in { V(358, 0, -2), V(380, 0, 4), V(362, 0, -24) } do
		local dir = Vector3.new(genCenter.X - p.X, 0, genCenter.Z - p.Z).Unit
		Props.Heater(z.Props, Kit.Face(p, dir))
	end
	for _, f in {
		{ V(388.4, 30, -20), Vector3.new(-1, -0.6, 0) },
		{ V(388.4, 30, 20), Vector3.new(-1, -0.6, 0) },
		{ V(269.6, 30, -20), Vector3.new(1, -0.6, 0) },
		{ V(269.6, 30, 20), Vector3.new(1, -0.6, 0) },
		{ V(300, 30, 39.4), Vector3.new(0, -0.6, -1) },
		{ V(350, 30, 39.4), Vector3.new(0, -0.6, -1) },
	} do
		Props.Floodlight(z.Lights, CFrame.lookAt(f[1], f[1] + f[2]))
	end
	for _, x in { 300, 330, 360 } do
		genLamp(x, 39.6, 10, 90)
	end
	Kit.Marker(z.Props, "FrenzyPoint", CFrame.new(V(366, 3, -4)), "FrenzyPoint", { Zone = "Zone3" })

	------------------------------------------------------------------
	-- Lastenaufzug (Nordost-Ecke)
	------------------------------------------------------------------
	local elev = Kit.Model(z.Props, "CargoElevator_PH")
	elev:AddTag("Elevator")
	-- Käfig aus Gitter (Westseite geschlossen, Südseite mit Tor)
	Kit.Box(elev, "CageWest", V(372, 0, 24), V(372.4, 10, 40), Mat.GrateMetal, Col.Grate, { Transparency = 0.25 })
	Kit.Box(elev, "CageSouthA", V(372, 0, 23.6), V(377, 10, 24), Mat.GrateMetal, Col.Grate, { Transparency = 0.25 })
	Kit.Box(elev, "CageSouthB", V(383, 0, 23.6), V(389, 10, 24), Mat.GrateMetal, Col.Grate, { Transparency = 0.25 })
	Kit.Box(elev, "CageTop", V(372, 10, 23.6), V(389, 10.8, 40), Mat.RustSteel, Col.Hazard, { Thermal = true })
	Kit.Box(elev, "GateHeader", V(377, 10, 23.4), V(383, 11.5, 24.2), Mat.Metal, Col.Hazard, { Small = true })
	local gate = Kit.Box(elev, "Gate", V(377, 0.2, 23.7), V(383, 9.8, 23.9), Mat.GrateMetal, Col.Hazard, { Transparency = 0.15 })
	gate:SetAttribute("ClosedCF", gate.CFrame)
	gate:SetAttribute("OpenCF", gate.CFrame + Vector3.new(0, 9.4, 0))
	local platform = Kit.Box(elev, "Platform", V(372.4, 0, 24), V(389, 0.35, 40), Mat.GrateMetal, Col.Grate, { Surface = "Grate", Transparency = 1, CanCollide = false })
	platform:SetAttribute("Present", false)
	Kit.Box(elev, "ShaftDark", V(372.6, 0, 24.2), V(388.8, 0.05, 39.8), Mat.Metal, Col.Black, { Small = true, CanCollide = false, CanQuery = false })
	local ride = Kit.BoxVolume(elev, "RideVolume", V(372.4, 0, 24), V(389, 9, 40))
	ride:SetAttribute("ElevatorRide", true)
	-- Bedienfeld
	local panel = Kit.Part(elev, "CallPanel", Vector3.new(1.4, 2.4, 0.6), CFrame.new(V(370, 4.5, 23.2)), Mat.Metal, Col.FrostDark, { Small = true })
	local st = Kit.Part(elev, "StatusLight", Vector3.new(0.6, 0.6, 0.6), panel.CFrame * CFrame.new(0, 0.6, -0.35), Mat.Neon, Color3.fromRGB(150, 20, 20), { Small = true, CanCollide = false, Shape = Enum.PartType.Ball })
	st:SetAttribute("Status", true)
	local scr = Kit.Part(elev, "PanelScreen", Vector3.new(1.1, 0.8, 0.05), panel.CFrame * CFrame.new(0, -0.4, -0.32), Mat.Glass, Col.Black, { Small = true, CanCollide = false })
	local lbl = Kit.Screen(scr, Enum.NormalId.Front, Vector2.new(220, 160), ctx.Config.Colors.CrtAmber, "NO POWER", "ElevatorScreen")
	lbl.TextSize = 30
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	lbl.TextYAlignment = Enum.TextYAlignment.Center
	Kit.Sign(elev, Kit.Face(V(380, 12.2, 23.2), Vector3.new(0, 0, -1)), Vector2.new(8, 1), "CARGO LIFT - REACTOR", Col.Hazard)
	-- Maschinerie über dem Käfig
	Kit.Box(elev, "Winch", V(376, 10.8, 30), V(385, 14, 36), Mat.RustSteel, Col.RustDark, { Thermal = true })
	for _, x in { 373, 388 } do
		Props.Pipe(elev, V(x, 10.8, 25), V(x, 40, 25), 0.5, Col.Black)
		Props.Pipe(elev, V(x, 10.8, 39), V(x, 40, 39), 0.5, Col.Black)
	end
	genLamp(380, 10.4, 32, 0)

	------------------------------------------------------------------
	-- Werkstatt (Diesel-Kanister)
	------------------------------------------------------------------
	Kit.Box(z.Props, "Workbench", V(296, 0, 57), V(314, 3.2, 60), Mat.Wood, Col.Wood, {})
	Kit.Box(z.Props, "WorkbenchTop", V(295.8, 3.2, 56.8), V(314.2, 3.45, 60.2), Mat.Metal, Col.FrostDark, { Small = true })
	itemSpawn(V(306, 4.4, 58.5), "Diesel")
	Kit.Part(z.Props, "Vise", Vector3.new(1, 0.8, 1.2), CFrame.new(V(298, 3.85, 58)), Mat.Metal, Col.Danger, { Small = true })
	Props.Toolbox(z.Props, A(311, 3.45, 58.5, 10))
	Kit.Box(z.Props, "ToolWall", V(296, 4, 60.6), V(314, 9, 61), Mat.Wood, Color3.fromRGB(80, 60, 45), { Small = true })
	for i = 0, 7 do
		Kit.Part(z.Props, "Tool", Vector3.new(0.3, rng:Range(1, 2.4), 0.2), CFrame.new(V(297.5 + i * 2.1, 6.5, 60.4)) * CFrame.Angles(0, 0, math.rad(rng:Range(-15, 15))), Mat.Metal, Col.FrostDark, { Small = true, CanCollide = false })
	end
	Props.Shelf(z.Props, Kit.Face(V(318.8, 0, 50), Vector3.new(-1, 0, 0)), 8, rng)
	for _, p in { V(293, 0, 44), V(295.5, 0, 43.4), V(293.2, 0, 47) } do
		Props.Barrel(z.Props, Kit.At(p.X, 0, p.Z, rng:Range(0, 180)), Color3.fromRGB(150, 35, 30))
	end
	Props.Note(z.Props, CFrame.new(V(301, 3.5, 58.2)) * CFrame.Angles(0, math.rad(-10), 0), "Z3_1", "Paper")
	Props.Locker(z.Props, Kit.Face(V(291.4, 0, 54), Vector3.new(1, 0, 0)), "HideLocker_Workshop", true)
	Kit.EmergencyLight(z.Lights, V(305, 9.4, 60.6), Vector3.new(0, 0, -1), "Zone3")
	Kit.Vent(z.Props, "Z3_Workshop", Kit.Face(V(320, 2.2, 43.5), Vector3.new(-1, 0, 0)), "Zone3")

	-- Lüftungsschächte in der Halle
	Kit.Vent(z.Props, "Z3_HallW", Kit.Face(V(269, 2.2, 22), Vector3.new(1, 0, 0)), "Zone3")
	Kit.Vent(z.Props, "Z3_HallS", Kit.Face(V(372, 2.2, -40), Vector3.new(0, 0, 1)), "Zone3")
	Kit.Vent(z.Props, "Z3_HallE", Kit.Face(V(389, 2.2, -30), Vector3.new(-1, 0, 0)), "Zone3")

	------------------------------------------------------------------
	-- Wegpunkte, Volumen
	------------------------------------------------------------------
	local wps = {
		V(260, 0, 0), V(280, 0, 0), V(300, 0, -14), V(322, 0, -20), V(350, 0, -16), V(366, 0, -30),
		V(366, 0, 10), V(358, 0, 24), V(334, 0, 36), V(305, 0, 34), V(282, 0, 26), V(305, 0, 50),
		V(300, 12, -35), V(340, 22, -35), V(320, 32, -35),
	}
	for i, p in wps do
		Kit.Waypoint(z.Waypoints, p, "Zone3", i)
	end
	Kit.BoxVolume(ctx.Volumes, "Zone_Zone3", V(252, -2, -42), V(391, 42, 62), { ZoneId = "Zone3" })
end

return Zone3
