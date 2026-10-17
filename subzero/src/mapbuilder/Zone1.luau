--!strict
-- Zone 1: Habitation (Tutorial, Minute 0 bis 4)
-- Schleuse 01 (Spawn), Hauptflur, Kantine, MedBay, Schlafquartiere, Lager, Sicherungsraum.
-- Koordinaten relativ zum Stations-Ursprung.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Mat, Col = Kit.Mat, Kit.Col

local Zone1 = {}

export type Ctx = { Map: Model, Volumes: Model, Config: any, Rng: Kit.Rng }

function Zone1.Build(ctx: Ctx)
	local S: Vector3 = ctx.Config.Map.StationOrigin
	local function V(x: number, y: number, z: number): Vector3
		return S + Vector3.new(x, y, z)
	end
	local function A(x: number, y: number, zz: number, yaw: number?): CFrame
		return Kit.At(S.X + x, S.Y + y, S.Z + zz, yaw)
	end
	local z = Kit.ZoneFolders(ctx.Map, "Zone1")
	local rng = ctx.Rng
	local neon: Color3 = ctx.Config.Colors.Neon

	local function lamp(x: number, y: number, zz: number, yaw: number?)
		Kit.CeilingLamp(z.Lights, V(x, y, zz), "PowerLight", "Zone1", neon, 20, 1.1, yaw)
	end
	local fuseSpotId = 0
	local function fuseSpot(model: Model, name: string)
		fuseSpotId += 1
		model:AddTag("FuseSpot")
		model:SetAttribute("SpotId", fuseSpotId)
		model:SetAttribute("SpotName", name)
	end
	local function itemSpawn(pos: Vector3, itemId: string)
		Kit.Marker(z.Props, "ItemSpawn", CFrame.new(pos), "ItemSpawn", { ItemId = itemId, Zone = "Zone1" })
	end

	------------------------------------------------------------------
	-- Räume
	------------------------------------------------------------------
	-- Schleuse 01 (Spawn)
	Kit.Room(z.Geometry, {
		Name = "Airlock01",
		Min = V(0, 0, -10),
		Max = V(23, 12, 10),
		Openings = { { Side = "E", Center = S.Z, Width = 6, Height = 10 } },
		WallMat = Mat.FrostMetal,
		WallColor = Col.FrostDark,
		FloorMat = Mat.GrateMetal,
		FloorColor = Col.Grate,
		FloorSurface = "Grate",
	})
	-- Hauptflur 8 breit, 11 hoch
	Kit.Room(z.Geometry, {
		Name = "MainCorridor",
		Min = V(24, 0, -4),
		Max = V(136, 11, 4),
		Walls = { N = true, S = true },
		Corners = "None",
		WallTop = S.Y + 13,
		Openings = {
			{ Side = "N", Center = S.X + 48, Width = 6, Height = 10 },
			{ Side = "N", Center = S.X + 88, Width = 6, Height = 10 },
			{ Side = "S", Center = S.X + 46, Width = 6, Height = 10 },
			{ Side = "S", Center = S.X + 80, Width = 6, Height = 10 },
			{ Side = "S", Center = S.X + 114, Width = 6, Height = 10 },
		},
		WallMat = Mat.RustSteel,
		WallColor = Col.Rust,
		FloorMat = Mat.SaltConcrete,
		FloorColor = Col.Floor,
		FloorSurface = "Concrete",
	})
	Kit.Room(z.Geometry, { Name = "Canteen", Min = V(32, 0, 5), Max = V(64, 12, 31), Walls = { N = true, E = true, W = true }, WallMat = Mat.SaltConcrete, WallColor = Col.Concrete })
	Kit.Room(z.Geometry, { Name = "Bunks", Min = V(72, 0, 5), Max = V(104, 12, 31), Walls = { N = true, E = true, W = true }, WallMat = Mat.RustSteel, WallColor = Col.Rust })
	Kit.Room(z.Geometry, { Name = "MedBay", Min = V(32, 0, -31), Max = V(60, 12, -5), Walls = { S = true, E = true, W = true }, WallMat = Mat.SaltConcrete, WallColor = Color3.fromRGB(170, 175, 172), FloorColor = Color3.fromRGB(120, 125, 122) })
	Kit.Room(z.Geometry, { Name = "Storage", Min = V(68, 0, -25), Max = V(92, 12, -5), Walls = { S = true, E = true, W = true } })
	Kit.Room(z.Geometry, { Name = "FuseRoom", Min = V(100, 0, -25), Max = V(128, 12, -5), Walls = { S = true, E = true, W = true }, WallMat = Mat.FrostMetal, WallColor = Col.FrostDark })

	-- Türen (normal: Wesen bricht sie auf)
	Kit.Door(z.Geometry, "Canteen", V(48, 0, 4.5), "X", 6, 10, "Normal")
	Kit.Door(z.Geometry, "Bunks", V(88, 0, 4.5), "X", 6, 10, "Normal")
	Kit.Door(z.Geometry, "MedBay", V(46, 0, -4.5), "X", 6, 10, "Normal")
	Kit.Door(z.Geometry, "Storage", V(80, 0, -4.5), "X", 6, 10, "Normal")
	Kit.Door(z.Geometry, "FuseRoom", V(114, 0, -4.5), "X", 6, 10, "Normal")

	-- Raum-Schilder über den Türen (Flurseite)
	Kit.Sign(z.Props, Kit.Face(V(48, 10.6, 3.9), Vector3.new(0, 0, -1)), Vector2.new(5, 0.7), "CANTEEN")
	Kit.Sign(z.Props, Kit.Face(V(88, 10.6, 3.9), Vector3.new(0, 0, -1)), Vector2.new(5, 0.7), "BUNKS")
	Kit.Sign(z.Props, Kit.Face(V(46, 10.6, -3.9), Vector3.new(0, 0, 1)), Vector2.new(5, 0.7), "MEDBAY")
	Kit.Sign(z.Props, Kit.Face(V(80, 10.6, -3.9), Vector3.new(0, 0, 1)), Vector2.new(5, 0.7), "STORAGE")
	Kit.Sign(z.Props, Kit.Face(V(114, 10.6, -3.9), Vector3.new(0, 0, 1)), Vector2.new(5, 0.7), "FUSE ROOM", Col.Danger, Col.White)
	Kit.Sign(z.Props, Kit.Face(V(135.6, 11.6, 0), Vector3.new(-1, 0, 0)), Vector2.new(6, 0.7), "BIO-LABS", Col.Hazard)

	------------------------------------------------------------------
	-- Schleuse 01
	------------------------------------------------------------------
	-- Äußere Luke (versiegelt), Nebel quillt aus den Dichtungen
	local hatch = Kit.Model(z.Props, "OuterHatch")
	Kit.Box(hatch, "HatchPlate", V(0, 0, -5), V(0.6, 10, 5), Mat.RustSteel, Col.FrostDark, { Thermal = true })
	for i = 0, 7 do
		local a = math.rad(i * 45)
		Kit.Part(hatch, "HatchBolt", Vector3.new(0.4, 0.8, 0.8), CFrame.new(V(0.8, 5 + math.sin(a) * 3.8, math.cos(a) * 3.8)), Mat.Metal, Col.Black, { Small = true })
	end
	Kit.Part(hatch, "HatchWheel", Vector3.new(0.3, 3.4, 3.4), CFrame.new(V(1, 5, 0)), Mat.Metal, Col.Danger, { Small = true, Shape = Enum.PartType.Cylinder })
	for _, zz in { -5.2, 5.2 } do
		local seal = Kit.Volume(hatch, "Seal", CFrame.new(V(0.8, 5, zz)), Vector3.new(0.3, 10, 0.3))
		local e = Kit.Emitter(seal, "SealFog", {
			Color = Color3.fromRGB(225, 232, 240),
			Size0 = 1,
			Size1 = 5,
			Transparency0 = 0.75,
			Transparency1 = 1,
			Lifetime = NumberRange.new(3, 5),
			Rate = 3,
			Speed = NumberRange.new(0.6, 1.4),
			Spread = Vector2.new(40, 40),
			Acceleration = Vector3.new(0.4, -0.3, 0),
			EmissionDirection = Enum.NormalId.Right,
			Shape = Enum.ParticleEmitterShape.Box,
		})
		e:AddTag("AmbientEmitter")
	end
	Kit.GroundFog(z.Volumes, V(8, 0.8, 0), Vector3.new(14, 1, 16), Color3.fromRGB(200, 210, 225), 2)
	Kit.Sign(z.Props, Kit.Face(V(22.6, 10.8, -4.5), Vector3.new(-1, 0, 0)), Vector2.new(5, 0.8), "AIRLOCK 01", Col.Hazard)
	Props.Bench(z.Props, Kit.Face(V(12, 0, -8.6), Vector3.new(0, 0, 1)), 8)
	Props.Note(z.Props, CFrame.new(V(10.5, 1.95, -8.6)) * CFrame.Angles(0, math.rad(-8), 0), "Z1_1", "Clipboard")
	itemSpawn(V(14, 2.4, -8.6), "Random")
	local airLocker = Props.Locker(z.Props, Kit.Face(V(6, 0, 8.6), Vector3.new(0, 0, -1)), "AirlockLocker", false)
	fuseSpot(airLocker, "Airlock locker")
	Props.Locker(z.Props, Kit.Face(V(9.2, 0, 8.6), Vector3.new(0, 0, -1)), "AirlockLocker2", false)
	Props.Locker(z.Props, Kit.Face(V(12.4, 0, 8.6), Vector3.new(0, 0, -1)), "AirlockLocker3", false)
	for i = 0, 9 do
		Kit.Part(z.Props, "HazardStripe", Vector3.new(0.6, 0.05, 2.4), CFrame.new(V(20.6, 0.03, -4.6 + i * 1.02)) * CFrame.Angles(0, math.rad(40), 0), Mat.Metal, Col.Hazard, { Small = true, CanCollide = false, CanQuery = false })
	end
	lamp(8, 11.7, 0, 90)
	lamp(17, 11.7, 0, 90)
	for i = 0, 3 do
		Kit.Marker(z.Spawns, "Spawn", Kit.Face(V(9 + (i % 2) * 5, 3, -3 + (i // 2) * 6), Vector3.new(1, 0, 0)), "Spawn", { Zone = "Zone1" })
	end

	------------------------------------------------------------------
	-- Hauptflur
	------------------------------------------------------------------
	for x = 30, 130, 14 do
		lamp(x, 10.7, 0, 0)
	end
	for i, x in { 36, 58, 80, 102, 124 } do
		local side = if i % 2 == 0 then 1 else -1
		Kit.EmergencyLight(z.Lights, V(x, 9.4, side * 3.8), Vector3.new(0, 0, -side), "Zone1")
	end
	-- Rohre und Kabelpritsche unter der Decke
	Props.Pipe(z.Props, V(24, 10.2, 3.2), V(136, 10.2, 3.2), 0.9)
	Props.Pipe(z.Props, V(24, 9.4, 3.4), V(136, 9.4, 3.4), 0.5, Col.Copper)
	Props.Pipe(z.Props, V(24, 10.3, -3.3), V(136, 10.3, -3.3), 0.7)
	Kit.Box(z.Props, "CableTray", V(24, 9.9, -2.9), V(136, 10.0, -1.9), Mat.GrateMetal, Col.Grate, { Small = true, CanCollide = false })
	-- Frost-Flecken am Boden
	for _ = 1, 9 do
		local x = rng:Range(28, 132)
		Kit.Part(z.Props, "FrostPatch", Vector3.new(0.05, rng:Range(2, 5), rng:Range(2, 4)), CFrame.new(V(x, 0.03, rng:Range(-2.5, 2.5))) * CFrame.Angles(0, rng:Range(0, 6), math.rad(90)), Mat.IceSheet, Col.Ice, { Small = true, CanCollide = false, CanQuery = false, Shape = Enum.PartType.Cylinder, Transparency = 0.3 })
	end
	Props.Icicles(z.Geometry, V(80, 11, 0), 14, 54, 3, rng)
	Kit.LightShaft(z.Lights, V(58, 10.4, 0), V(58, 0.5, 0), 3, 6, neon)
	Kit.LightShaft(z.Lights, V(100, 10.4, 0), V(100, 0.5, 0), 3, 6, neon)
	Kit.Vent(z.Props, "Z1_Corridor", Kit.Face(V(96, 2.2, -4), Vector3.new(0, 0, 1)), "Zone1")

	------------------------------------------------------------------
	-- Kantine
	------------------------------------------------------------------
	for i = 0, 2 do
		local zz = 11 + i * 6
		Props.Table(z.Props, A(48, 0, zz, 0), 10, 3)
		Props.Bench(z.Props, A(48, 0, zz - 2.4, 0), 9)
		Props.Bench(z.Props, A(48, 0, zz + 2.4, 0), 9)
	end
	Props.Chair(z.Props, A(56, 0, 9, 40), true)
	Props.Radio(z.Props, CFrame.new(V(46, 3.15, 17)) * CFrame.Angles(0, math.rad(25), 0))
	-- Theke an der Westwand
	Kit.Box(z.Props, "Counter", V(32, 0, 9), V(35, 3.2, 27), Mat.FrostMetal, Col.Frost, { Small = true })
	Kit.Box(z.Props, "CounterTop", V(31.9, 3.2, 8.9), V(35.4, 3.45, 27.1), Mat.Metal, Col.FrostDark, { Small = true })
	local micro = Props.Microwave(z.Props, Kit.Face(V(33.5, 3.45, 12), Vector3.new(1, 0, 0)))
	fuseSpot(micro, "Microwave")
	local drawer = Props.Cabinet(z.Props, Kit.Face(V(38, 0, 29.8), Vector3.new(0, 0, -1)), "CanteenDrawer")
	fuseSpot(drawer, "Canteen drawer")
	Props.Note(z.Props, CFrame.new(V(33.6, 3.45, 17)) * CFrame.Angles(0, math.rad(80), 0), "Z1_2", "Clipboard")
	-- Not-Radiator mit Handkurbel (Nordwand)
	Props.Radiator(z.Props, Kit.Face(V(48, 0, 30.4), Vector3.new(0, 0, -1)))
	Kit.Sign(z.Props, Kit.Face(V(48, 5.8, 30.8), Vector3.new(0, 0, -1)), Vector2.new(5, 0.7), "EMERGENCY HEAT", Col.Danger, Col.White)
	Props.Locker(z.Props, Kit.Face(V(62.4, 0, 27), Vector3.new(-1, 0, 0)), "HideLocker_Canteen", true)
	Kit.Vent(z.Props, "Z1_Canteen", Kit.Face(V(64, 2.2, 14), Vector3.new(-1, 0, 0)), "Zone1")
	itemSpawn(V(52, 3.4, 17), "Random")
	lamp(40, 11.7, 12)
	lamp(56, 11.7, 12)
	lamp(40, 11.7, 24)
	lamp(56, 11.7, 24)

	------------------------------------------------------------------
	-- Schlafquartiere
	------------------------------------------------------------------
	local mattressSpot: BasePart? = nil
	for i = 0, 2 do
		local zz = 12 + i * 7.5
		local _b1, m1 = Props.Bed(z.Props, Kit.Face(V(76.5, 0, zz), Vector3.new(1, 0, 0)))
		local _b2, _m2 = Props.Bed(z.Props, Kit.Face(V(99.5, 0, zz), Vector3.new(-1, 0, 0)))
		if i == 1 then
			mattressSpot = m1
		end
	end
	if mattressSpot then
		local spot = Kit.Model(z.Props, "MattressSpot")
		local inter = Kit.Volume(spot, "Interact", mattressSpot.CFrame, Vector3.new(3, 1.2, 6.6))
		inter:SetAttribute("Interact", true)
		fuseSpot(spot, "Under the mattress")
	end
	local bunkLocker = Props.Locker(z.Props, Kit.Face(V(82, 0, 29.6), Vector3.new(0, 0, -1)), "BunkLocker", false)
	fuseSpot(bunkLocker, "Bunk locker")
	Props.Locker(z.Props, Kit.Face(V(85.2, 0, 29.6), Vector3.new(0, 0, -1)), "HideLocker_Bunks1", true)
	Props.Locker(z.Props, Kit.Face(V(91, 0, 29.6), Vector3.new(0, 0, -1)), "HideLocker_Bunks2", true)
	Props.Locker(z.Props, Kit.Face(V(94.2, 0, 29.6), Vector3.new(0, 0, -1)), "BunkLocker2", false)
	Props.Note(z.Props, CFrame.new(V(99.5, 2.5, 19.5)) * CFrame.Angles(0, math.rad(30), 0), "Z1_4", "Paper")
	itemSpawn(V(76.5, 2.6, 27), "Random")
	lamp(80, 11.7, 18)
	lamp(96, 11.7, 18)

	------------------------------------------------------------------
	-- MedBay
	------------------------------------------------------------------
	for i = 0, 2 do
		local x = 38 + i * 8
		Props.Bed(z.Props, Kit.Face(V(x, 0, -26), Vector3.new(0, 0, 1)))
		Props.EkgMonitor(z.Props, Kit.Face(V(x + 2.6, 0, -29), Vector3.new(0, 0, 1)))
		-- Vorhang
		Kit.Part(z.Props, "Curtain", Vector3.new(0.1, 7, 6), CFrame.new(V(x + 4, 4.5, -26)), Mat.Fabric, Color3.fromRGB(150, 170, 160), { Small = true, CanCollide = false, Transparency = 0.15 })
	end
	local medDrawer = Props.Cabinet(z.Props, Kit.Face(V(58.8, 0, -14), Vector3.new(-1, 0, 0)), "MedDrawer")
	fuseSpot(medDrawer, "Medical drawer")
	-- Wagen mit Wärme-Injektor
	Props.Table(z.Props, A(40, 0, -12, 0), 4, 2.4)
	itemSpawn(V(40, 3.4, -12), "Injector")
	Props.Note(z.Props, CFrame.new(V(41.4, 3.15, -11.6)), "Z1_3", "Tape")
	Props.BloodTrail(z.Props, V(36, 0, -8), V(54, 0, -22), rng)
	Props.BloodTrail(z.Props, V(46, 0, -5.5), V(44, 0, -14), rng)
	Props.Locker(z.Props, Kit.Face(V(33.4, 0, -8), Vector3.new(1, 0, 0)), "HideLocker_MedBay", true)
	Kit.Vent(z.Props, "Z1_MedBay", Kit.Face(V(32, 2.2, -20), Vector3.new(1, 0, 0)), "Zone1")
	lamp(40, 11.7, -18)
	lamp(53, 11.7, -18)
	Kit.Sign(z.Props, Kit.Face(V(46, 8, -30.6), Vector3.new(0, 0, 1)), Vector2.new(6, 1), "MEDICAL", Color3.fromRGB(240, 240, 240), Col.Danger)

	------------------------------------------------------------------
	-- Lager
	------------------------------------------------------------------
	Props.Shelf(z.Props, Kit.Face(V(72, 0, -23.8), Vector3.new(0, 0, 1)), 7, rng)
	Props.Shelf(z.Props, Kit.Face(V(80, 0, -23.8), Vector3.new(0, 0, 1)), 7, rng)
	Props.Shelf(z.Props, Kit.Face(V(90.8, 0, -15), Vector3.new(-1, 0, 0)), 8, rng)
	Props.Crate(z.Props, A(73, 0, -12, 10), Vector3.new(4, 3, 4))
	Props.Crate(z.Props, A(73.5, 3, -12.2, 25), Vector3.new(2.6, 2, 2.6))
	local toolbox = Props.Toolbox(z.Props, A(84, 0, -11, -15))
	fuseSpot(toolbox, "Toolbox")
	local storCab = Props.Cabinet(z.Props, Kit.Face(V(69.2, 0, -18), Vector3.new(1, 0, 0)), "StorageCabinet")
	fuseSpot(storCab, "Storage cabinet")
	Props.Locker(z.Props, Kit.Face(V(88, 0, -6.4), Vector3.new(0, 0, -1)), "HideLocker_Storage", true)
	itemSpawn(V(80, 2.5, -23.8), "Random")
	lamp(80, 11.7, -15)

	------------------------------------------------------------------
	-- Sicherungsraum
	------------------------------------------------------------------
	Props.FuseBox(z.Props, Kit.Face(V(112, 0, -24.4), Vector3.new(0, 0, 1)))
	Kit.Sign(z.Props, Kit.Face(V(112, 8.6, -24.7), Vector3.new(0, 0, 1)), Vector2.new(6, 0.9), "MAIN POWER", Col.Danger, Col.White)
	for i = 0, 3 do
		Props.Pipe(z.Props, V(110 + i * 0.6, 7, -24.6), V(110 + i * 0.6, 12, -24.6), 0.3, Col.Black)
	end
	for i = 0, 2 do
		Kit.Box(z.Props, "Panel", V(101, 0, -22 + i * 5), V(102.5, 6, -18 + i * 5), Mat.FrostMetal, Col.FrostDark, { Small = true })
		Kit.Part(z.Props, "PanelLed", Vector3.new(0.1, 0.3, 0.3), CFrame.new(V(102.55, 5, -20 + i * 5)), Mat.Neon, Color3.fromRGB(255, 60, 40), { Small = true, CanCollide = false })
	end
	Kit.EmergencyLight(z.Lights, V(127.8, 9, -15), Vector3.new(-1, 0, 0), "Zone1")
	lamp(114, 11.7, -15)

	------------------------------------------------------------------
	-- Wegpunkte für das Wesen
	------------------------------------------------------------------
	local wps = {
		V(12, 0, 0), V(30, 0, 0), V(48, 0, 0), V(66, 0, 0), V(88, 0, 0), V(106, 0, 0), V(126, 0, 0),
		V(48, 0, 9), V(42, 0, 24), V(88, 0, 18), V(46, 0, -16), V(80, 0, -16), V(114, 0, -14),
	}
	for i, p in wps do
		Kit.Waypoint(z.Waypoints, p, "Zone1", i)
	end

	-- Zonen-Volumen
	Kit.BoxVolume(ctx.Volumes, "Zone_Zone1", V(-1, -2, -33), V(136, 14, 33), { ZoneId = "Zone1" })
end

return Zone1
