--!strict
-- Zone 4: Reaktor (Finale, Minute 12 bis 15)
-- Runde Höhle (Innenradius 54, also gut 100 Durchmesser), Reaktorkern in der Mitte,
-- Laufstege über einem Abgrund (Sturz = tot), Dampfventile, 4 Kontrollstäbe in den Ecken,
-- Dachluken über dem Kern, Wartungsleiter zum Landeplatz.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Mat, Col = Kit.Mat, Kit.Col

local Zone4 = {}

export type Ctx = { Map: Model, Volumes: Model, Config: any, Rng: Kit.Rng }

function Zone4.Build(ctx: Ctx)
	local S: Vector3 = ctx.Config.Map.StationOrigin
	local function V(x: number, y: number, z: number): Vector3
		return S + Vector3.new(x, y, z)
	end
	local z = Kit.ZoneFolders(ctx.Map, "Zone4")
	local rng = ctx.Rng
	local reactor: Color3 = ctx.Config.Colors.Reactor

	local CX, CY, CZ = 380, -60, 110 -- Höhlenmitte (Laufsteg-Ebene)
	local R_WALL = 54
	-- Punkt auf einem Kreis um die Höhlenmitte (Winkel in Grad, von +X Richtung +Z)
	local function P(r: number, deg: number, y: number): Vector3
		local a = math.rad(deg)
		return V(CX + math.cos(a) * r, y, CZ + math.sin(a) * r)
	end
	local function tangent(deg: number): Vector3
		local a = math.rad(deg)
		return Vector3.new(-math.sin(a), 0, math.cos(a))
	end
	local function radial(deg: number): Vector3
		local a = math.rad(deg)
		return Vector3.new(math.cos(a), 0, math.sin(a))
	end
	local GRATE: Kit.PartOpts = { Surface = "Grate" }
	local function reactorLamp(pos: Vector3, range: number, brightness: number)
		local p = Kit.Part(z.Lights, "ReactorLamp", Vector3.new(1, 0.6, 1), CFrame.new(pos), Mat.Neon, Color3.fromRGB(255, 120, 60), { Small = true, CanCollide = false, Shape = Enum.PartType.Ball })
		local l = Kit.GlowLight(p, Color3.fromRGB(255, 120, 60), range, brightness)
		l.Name = "ReactorLight"
		p:AddTag("FlickerLight")
		p:SetAttribute("BaseBrightness", brightness)
		p:SetAttribute("PowerGroup", "Zone4")
	end

	------------------------------------------------------------------
	-- Aufzug unten, Tunnel
	------------------------------------------------------------------
	Kit.Room(z.Geometry, {
		Name = "ElevatorBottom",
		Min = V(372, -60, 23),
		Max = V(389, -48, 40),
		Openings = { { Side = "N", Center = S.X + 380, Width = 8, Height = 11 } },
		WallMat = Mat.RustSteel,
		WallColor = Col.RustDark,
		FloorMat = Mat.GrateMetal,
		FloorColor = Col.Grate,
		FloorSurface = "Grate",
	})
	Kit.Room(z.Geometry, {
		Name = "ReactorTunnel",
		Min = V(376, -60, 41),
		Max = V(384, -49, 53),
		Walls = { E = true, W = true },
		WallMat = Mat.Rock,
		WallColor = Col.Rock,
		FloorMat = Mat.SaltConcrete,
		FloorColor = Col.ConcreteDark,
		Ribs = true,
	})
	Kit.Sign(z.Props, Kit.Face(V(380, -50.6, 40.6), Vector3.new(0, 0, 1)), Vector2.new(6, 0.8), "REACTOR ACCESS", Col.Danger, Col.White)
	reactorLamp(V(380, -48.8, 31), 18, 0.8)
	reactorLamp(V(380, -49.8, 47), 14, 0.6)
	for i = 0, 3 do
		Kit.Marker(z.Spawns, "Spawn", Kit.Face(V(377 + (i % 2) * 6, -57, 28 + (i // 2) * 6), Vector3.new(0, 0, 1)), "Spawn", { Zone = "Zone4" })
	end
	Kit.Vent(z.Props, "Z4_Bottom", Kit.Face(V(372, -57.8, 32), Vector3.new(1, 0, 0)), "Zone4")

	------------------------------------------------------------------
	-- Höhlenwand (36 Segmente), Decke mit Luken, Abgrund
	------------------------------------------------------------------
	local cave = Kit.Model(z.Geometry, "CaveShell")
	local yBottom, yTop = -142, -17
	for k = 0, 35 do
		local deg = k * 10
		if deg == 270 then
			-- Segment mit Tunnelöffnung (achsenparallel)
			Kit.Wall(cave, "X", S.Z + CZ - 57, S.Z + CZ - 54, S.X + CX - 5.1, S.X + CX + 5.1, S.Y + yBottom, S.Y + yTop, S.Y + CY, {
				{ Side = "S", Center = S.X + CX, Width = 8, Height = 11 },
			}, Mat.Rock, Col.Rock)
		else
			local c = P(R_WALL + 1.5, deg, (yBottom + yTop) / 2)
			local cf = CFrame.lookAt(c, c + radial(deg))
			Kit.Part(cave, "CaveWall", Vector3.new(10.2, yTop - yBottom, 3), cf, Mat.Rock, if k % 3 == 0 then Col.RockDark else Col.Rock, { Thermal = true })
		end
		-- Eisadern
		if k % 4 == 1 then
			local c2 = P(R_WALL - 0.1, deg, rng:Range(-80, -30))
			Kit.Part(cave, "IceVein", Vector3.new(rng:Range(2, 5), rng:Range(10, 30), 0.3), CFrame.lookAt(c2, c2 + radial(deg)) * CFrame.Angles(0, 0, math.rad(rng:Range(-30, 30))), Mat.IceSheet, Col.Ice, { Small = true, CanCollide = false, Transparency = 0.2 })
		end
	end
	-- Decke mit Dachluken-Öffnung (Mitte) und Leiterschacht (Osten)
	Kit.SlabWithHoles(cave, "CaveCeiling", S.X + 324, S.Z + 54, S.X + 436, S.Z + 166, S.Y - 20, S.Y - 17, {
		{ S.X + 370, S.Z + 100, S.X + 390, S.Z + 120 },
		{ S.X + 430, S.Z + 105, S.X + 435, S.Z + 109 },
	}, Mat.Rock, Col.RockDark, { Thermal = true })
	Props.Icicles(cave, V(CX - 30, -20, CZ), 16, 10, 14, rng)
	Props.Icicles(cave, V(CX + 25, -20, CZ - 20), 16, 12, 12, rng)
	Props.Icicles(cave, V(CX, -20, CZ + 32), 16, 14, 8, rng)
	-- Abgrund mit rotem Glühen in der Tiefe
	Kit.Box(cave, "AbyssFloor", V(324, -145, 54), V(436, -142, 166), Mat.Basalt, Color3.fromRGB(25, 15, 12), { Thermal = true })
	for i = 0, 2 do
		local g = Kit.Volume(z.Lights, "AbyssGlow", CFrame.new(P(25, i * 120 + 30, -135)), Vector3.new(1, 1, 1))
		Kit.GlowLight(g, Color3.fromRGB(255, 60, 20), 45, 1.2)
	end
	local rise = Kit.Volume(z.Volumes, "AbyssSteam", CFrame.new(V(CX, -120, CZ)), Vector3.new(90, 2, 90))
	local riseE = Kit.Emitter(rise, "Rising", {
		Color = Color3.fromRGB(255, 170, 130),
		Color2 = Color3.fromRGB(200, 200, 210),
		Size0 = 8,
		Size1 = 16,
		Transparency0 = 0.85,
		Transparency1 = 1,
		Lifetime = NumberRange.new(8, 12),
		Rate = 6,
		Speed = NumberRange.new(3, 6),
		Spread = Vector2.new(10, 10),
		Shape = Enum.ParticleEmitterShape.Box,
	})
	riseE:AddTag("AmbientEmitter")

	------------------------------------------------------------------
	-- Dachluken und Schacht zum Himmel
	------------------------------------------------------------------
	local hatchM = Kit.Model(z.Geometry, "RoofHatches")
	for i, span in { { 370, 380, -10 }, { 380, 390, 10 } } do
		local h = Kit.Box(hatchM, "Hatch" .. i, V(span[1], -17, 100), V(span[2], -15.8, 120), Mat.RustSteel, Col.FrostDark, { Thermal = true })
		h:AddTag("RoofHatch")
		h:SetAttribute("ClosedCF", h.CFrame)
		h:SetAttribute("OpenCF", h.CFrame + Vector3.new(span[3], 0, 0))
		for j = 0, 3 do
			Kit.Part(hatchM, "HatchStripe", Vector3.new(9.6, 0.05, 1), h.CFrame * CFrame.new(0, -0.62, -7.5 + j * 5), Mat.Metal, Col.Hazard, { Small = true, CanCollide = false })
		end
	end
	for _, w in {
		{ V(358, -17, 98), V(359, -0.5, 122) },
		{ V(401, -17, 98), V(402, -0.5, 122) },
		{ V(359, -17, 98), V(401, -0.5, 99) },
		{ V(359, -17, 121), V(401, -0.5, 122) },
	} do
		Kit.Box(hatchM, "HatchShaft", w[1], w[2], Mat.Rock, Col.RockDark, { Thermal = true })
	end
	local sky = Kit.Volume(hatchM, "HatchSky", CFrame.new(V(CX, -1, CZ)), Vector3.new(20, 1, 20))
	sky:AddTag("HatchSky")
	Kit.Emitter(sky, "SnowFall", {
		Texture = Kit.Tex.Sparkle,
		Color = Color3.fromRGB(235, 240, 255),
		Size0 = 0.3,
		Size1 = 0.2,
		Transparency0 = 0.1,
		Transparency1 = 0.5,
		Lifetime = NumberRange.new(4, 6),
		Rate = 0,
		Speed = NumberRange.new(10, 16),
		Spread = Vector2.new(20, 20),
		EmissionDirection = Enum.NormalId.Bottom,
		Shape = Enum.ParticleEmitterShape.Box,
	})
	local moon = Instance.new("SpotLight")
	moon.Name = "SkyLight"
	moon.Face = Enum.NormalId.Bottom
	moon.Angle = 50
	moon.Range = 60
	moon.Brightness = 0
	moon.Color = Color3.fromRGB(160, 190, 230)
	moon.Enabled = false
	moon.Parent = sky
	local hatchBeam = Kit.LightShaft(hatchM, V(CX, -16, CZ), V(CX, -60, CZ), 18, 26, Color3.fromRGB(170, 200, 240))
	hatchBeam.Enabled = false
	hatchBeam:AddTag("HatchBeam")
	Kit.Marker(z.Props, "HatchCamStart", CFrame.lookAt(P(30, 200, -48), V(CX, -30, CZ)), "CinematicCam", { CamId = "HatchStart" })
	Kit.Marker(z.Props, "HatchCamEnd", CFrame.lookAt(V(CX - 4, -36, CZ - 14), V(CX, -10, CZ)), "CinematicCam", { CamId = "HatchEnd" })

	------------------------------------------------------------------
	-- Laufstege: Ring (Radius 40..46), 4 Speichen, Kernplattform
	------------------------------------------------------------------
	local walk = Kit.Model(z.Geometry, "Walkways")
	for k = 0, 23 do
		local deg = k * 15
		local top = CY - (if k % 2 == 0 then 0 else 0.02)
		local c = P(43, deg, top - 0.5)
		Kit.Part(walk, "Ring", Vector3.new(11.6, 1, 6), CFrame.lookAt(c, c + radial(deg)), Mat.GrateMetal, Col.Grate, GRATE)
	end
	for _, deg in { 0, 90, 180, 270 } do
		local c = P(26, deg, CY - 0.04 - 0.5)
		Kit.Part(walk, "Spoke", Vector3.new(6, 1, 29), CFrame.lookAt(c, c + radial(deg)), Mat.GrateMetal, Col.Grate, GRATE)
		for _, side in { -1, 1 } do
			local off = tangent(deg) * (side * 2.9)
			Props.Railing(walk, P(12.3, deg, CY) + off, P(39.8, deg, CY) + off)
		end
	end
	Kit.Part(walk, "CorePlatform", Vector3.new(1, 24, 24), CFrame.new(V(CX, CY - 0.08 - 0.5, CZ)) * CFrame.Angles(0, 0, math.rad(90)), Mat.GrateMetal, Col.Grate, { Shape = Enum.PartType.Cylinder, Surface = "Grate" })
	-- Kerngeländer zwischen den Speichen
	for q = 0, 3 do
		local base = q * 90
		local angles = { base + 16, base + 32, base + 48, base + 64, base + 74 }
		for i = 1, #angles - 1 do
			Props.Railing(walk, P(11.7, angles[i], CY), P(11.7, angles[i + 1], CY), 3.2)
		end
	end
	-- Ring-Geländer (innen und außen), mit Lücken für Speichen und Plattformen
	local outerGap: { [number]: number } = { [45] = 4.2, [135] = 4.2, [225] = 4.2, [315] = 4.2, [270] = 4.2, [0] = 99 }
	local innerGap: { [number]: number } = { [0] = 3.2, [90] = 3.2, [180] = 3.2, [270] = 3.2 }
	for k = 0, 23 do
		local deg = k * 15
		local function rail(r: number, gap: number?)
			local t = tangent(deg)
			local c = P(r, deg, CY)
			if gap == nil then
				Props.Railing(walk, c - t * 5.8, c + t * 5.8)
			elseif gap < 5.8 then
				Props.Railing(walk, c - t * 5.8, c - t * gap)
				Props.Railing(walk, c + t * gap, c + t * 5.8)
			end
		end
		rail(40.2, innerGap[deg])
		rail(45.8, outerGap[deg])
	end
	-- Tunnel-Anschluss
	Kit.Box(walk, "TunnelBridge", V(376, CY - 1.1, 56), V(384, CY - 0.1, 66), Mat.GrateMetal, Col.Grate, GRATE)
	Props.Railing(walk, V(376.2, CY, 56), V(376.2, CY, 64.5))
	Props.Railing(walk, V(383.8, CY, 56), V(383.8, CY, 64.5))
	-- Leiter-Plattform (Osten)
	Kit.Box(walk, "LadderPlatform", V(425, CY - 1.06, 104), V(434, CY - 0.06, 116), Mat.GrateMetal, Col.Grate, GRATE)
	Props.Railing(walk, V(425.5, CY, 104.2), V(434, CY, 104.2))
	Props.Railing(walk, V(425.5, CY, 115.8), V(434, CY, 115.8))

	------------------------------------------------------------------
	-- Reaktorkern, Kontrollstäbe, Dampfventile
	------------------------------------------------------------------
	Props.ReactorCore(z.Props, V(CX, CY - 0.08, CZ), reactor)
	for i, deg in { 45, 135, 225, 315 } do
		local c = P(50, deg, CY - 0.56)
		Kit.Part(walk, "RodPlatform", Vector3.new(8, 1, 8), CFrame.lookAt(c, c + radial(deg)), Mat.GrateMetal, Col.Grate, GRATE)
		for _, side in { -1, 1 } do
			local off = tangent(deg) * (side * 3.8)
			Props.Railing(walk, P(46.2, deg, CY) + off, P(53.8, deg, CY) + off)
		end
		local rc = P(50, deg, CY - 0.06)
		Props.ControlRod(z.Props, CFrame.lookAt(rc, rc - radial(deg)), i)
		reactorLamp(P(53.2, deg, CY + 8), 16, 0.9)
	end
	local ventIndex = 0
	for k = 0, 7 do
		local deg = 22.5 + k * 45
		ventIndex += 1
		local pos = P(R_WALL - 0.6, deg, CY + 2.5)
		Props.SteamVent(z.Props, CFrame.lookAt(pos, pos - radial(deg)), ventIndex)
	end
	for q = 0, 3 do
		ventIndex += 1
		local pos = P(9, 45 + q * 90, CY + 0.3)
		Props.SteamVent(z.Props, CFrame.new(pos) * CFrame.Angles(math.rad(90), 0, 0), ventIndex)
	end
	for k = 0, 5 do
		reactorLamp(P(R_WALL - 0.5, 60 * k + 30, CY + 14), 22, 0.7)
	end

	------------------------------------------------------------------
	-- Wartungsleiter zum Landeplatz (mit Luke oben)
	------------------------------------------------------------------
	Props.Ladder(z.Props, V(433, CY, 107), 63, Vector3.new(-1, 0, 0))
	for _, w in {
		{ V(429, -17, 104), V(430, -0.5, 110) },
		{ V(435, -17, 104), V(436, -0.5, 110) },
		{ V(430, -17, 104), V(435, -0.5, 105) },
		{ V(430, -17, 109), V(435, -0.5, 110) },
	} do
		Kit.Box(z.Geometry, "LadderShaft", w[1], w[2], Mat.RustSteel, Col.RustDark, { Thermal = true })
	end
	local lid = Kit.Box(z.Geometry, "LadderHatch", V(430, -1.1, 105), V(435, -0.5, 109), Mat.RustSteel, Col.Hazard, { Thermal = true })
	lid:AddTag("LadderHatch")
	lid:SetAttribute("ClosedCF", lid.CFrame)
	lid:SetAttribute("OpenCF", CFrame.new(V(439.6, 0.3, 107)))
	Kit.Sign(z.Props, Kit.Face(V(433.4, CY + 9, 112), Vector3.new(-1, 0, 0)), Vector2.new(5, 0.8), "SURFACE ACCESS", Col.Hazard)
	Kit.Vent(z.Props, "Z4_Ladder", Kit.Face(V(434, CY + 2.2, 113.5), Vector3.new(-1, 0, 0)), "Zone4")
	Props.Note(z.Props, CFrame.new(V(427, CY, 113)) * CFrame.Angles(0, math.rad(20), 0), "Z4_2", "Paper")
	Props.Note(z.Props, CFrame.new(V(383, CY - 0.1, 62)), "Z4_1", "Tape")
	Kit.Marker(z.Props, "ItemSpawn", CFrame.new(V(386, -59, 36)), "ItemSpawn", { ItemId = "Random", Zone = "Zone4" })
	Kit.Marker(z.Props, "ItemSpawn", CFrame.new(P(43, 150, CY + 1)), "ItemSpawn", { ItemId = "Random", Zone = "Zone4" })

	------------------------------------------------------------------
	-- Wegpunkte, Raserei-Punkte, Volumen
	------------------------------------------------------------------
	local wps: { Vector3 } = { V(380, CY, 32), V(380, CY, 48), V(380, CY, 62) }
	for k = 0, 7 do
		table.insert(wps, P(43, 22.5 + k * 45, CY))
	end
	for _, deg in { 0, 90, 180, 270 } do
		table.insert(wps, P(20, deg, CY))
	end
	for _, deg in { 45, 135, 225, 315 } do
		table.insert(wps, P(49, deg, CY))
	end
	table.insert(wps, V(429, CY, 110))
	for i, p in wps do
		Kit.Waypoint(z.Waypoints, p, "Zone4", i)
	end
	for _, deg in { 0, 90, 180, 270 } do
		Kit.Marker(z.Props, "FrenzyPoint", CFrame.new(P(30, deg, CY + 3)), "FrenzyPoint", { Zone = "Zone4" })
	end
	Kit.BoxVolume(ctx.Volumes, "Zone_Zone4", V(318, -150, 20), V(442, -3, 170), { ZoneId = "Zone4" })
end

return Zone4
