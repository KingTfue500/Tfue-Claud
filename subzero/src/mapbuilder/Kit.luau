--!strict
-- Modulares Bau-Kit (Abschnitt 13.1): Wände, Böden, Decken, Räume mit Öffnungen,
-- Türen, Lampen, Volumen, Wegpunkte. 8-Stud-Raster, keine Plastic-Materialien.
-- Läuft sowohl in Roblox als auch in Lune (Vorab-Bau der Place-Datei):
-- daher keine Dienste, kein task, kein Random, kein PivotTo.

local Kit = {}

----------------------------------------------------------------------
-- Materialien und Farben
-- MaterialKit-Attribut: Name der späteren MaterialVariant (RustSteel, SaltConcrete,
-- FrostMetal, IceSheet, GrateMetal). Existiert die Variante im MaterialService,
-- setzt der Server sie beim Start automatisch.
----------------------------------------------------------------------
Kit.Mat = {
	RustSteel = Enum.Material.CorrodedMetal,
	SaltConcrete = Enum.Material.Concrete,
	FrostMetal = Enum.Material.Metal,
	IceSheet = Enum.Material.Ice,
	GrateMetal = Enum.Material.DiamondPlate,
	Rock = Enum.Material.Slate,
	Basalt = Enum.Material.Basalt,
	Glass = Enum.Material.Glass,
	Neon = Enum.Material.Neon,
	Fabric = Enum.Material.Fabric,
	Wood = Enum.Material.WoodPlanks,
	Rubber = Enum.Material.Rubber,
	Snow = Enum.Material.Snow,
	Foil = Enum.Material.Foil,
	Glacier = Enum.Material.Glacier,
	Metal = Enum.Material.Metal,
	Asphalt = Enum.Material.Asphalt,
	Leather = Enum.Material.Leather,
	ForceField = Enum.Material.ForceField,
}

local KIT_NAME: { [Enum.Material]: string } = {
	[Enum.Material.CorrodedMetal] = "RustSteel",
	[Enum.Material.Concrete] = "SaltConcrete",
	[Enum.Material.Metal] = "FrostMetal",
	[Enum.Material.Ice] = "IceSheet",
	[Enum.Material.DiamondPlate] = "GrateMetal",
}

Kit.Col = {
	Rust = Color3.fromRGB(104, 72, 54),
	RustDark = Color3.fromRGB(70, 52, 42),
	Concrete = Color3.fromRGB(138, 136, 128),
	ConcreteDark = Color3.fromRGB(88, 88, 84),
	Floor = Color3.fromRGB(82, 82, 80),
	Frost = Color3.fromRGB(150, 165, 180),
	FrostDark = Color3.fromRGB(95, 105, 118),
	Ice = Color3.fromRGB(195, 225, 245),
	Grate = Color3.fromRGB(92, 94, 98),
	Black = Color3.fromRGB(18, 18, 20),
	Hazard = Color3.fromRGB(230, 170, 20),
	HazardDark = Color3.fromRGB(30, 28, 24),
	Rock = Color3.fromRGB(60, 58, 60),
	RockDark = Color3.fromRGB(38, 36, 38),
	Snow = Color3.fromRGB(235, 240, 248),
	White = Color3.fromRGB(225, 228, 230),
	Wood = Color3.fromRGB(110, 80, 55),
	Fabric = Color3.fromRGB(70, 75, 80),
	Pipe = Color3.fromRGB(120, 112, 100),
	Copper = Color3.fromRGB(160, 100, 60),
	Blood = Color3.fromRGB(90, 10, 14),
	Organic = Color3.fromRGB(70, 20, 30),
	Danger = Color3.fromRGB(200, 30, 25),
}

----------------------------------------------------------------------
-- Deterministischer Zufall (Lune kennt kein Random)
----------------------------------------------------------------------
export type Rng = {
	Next: (self: Rng) -> number,
	Range: (self: Rng, a: number, b: number) -> number,
	Int: (self: Rng, a: number, b: number) -> number,
}

function Kit.Rng(seed: number): Rng
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local self = {} :: Rng
	function self.Next(_s: Rng): number
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
	function self.Range(s: Rng, a: number, b: number): number
		return a + (b - a) * s:Next()
	end
	function self.Int(s: Rng, a: number, b: number): number
		return math.min(b, a + math.floor(s:Next() * (b - a + 1)))
	end
	return self
end

----------------------------------------------------------------------
-- Grundbausteine
----------------------------------------------------------------------
export type PartOpts = {
	Transparency: number?,
	Shape: Enum.PartType?,
	CanCollide: boolean?,
	CanQuery: boolean?,
	CastShadow: boolean?,
	Thermal: boolean?, -- true = ThermalBlock (Wand, blockiert Wärme)
	Surface: string?, -- Untergrund für Schritte
	Reflectance: number?,
	Class: string?, -- "Part" (Standard), "WedgePart", "CornerWedgePart", "TrussPart"
	Small: boolean?, -- kleines Prop: keine Schatten
}

function Kit.Folder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name)
	if f and f:IsA("Folder") then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = name
	nf.Parent = parent
	return nf
end

-- Alle Modelle der Map sind aus Teilen gebaut und damit Platzhalter für spätere Meshes:
-- Regel 4 der Spezifikation verlangt dafür "_PH" am Namensende.
function Kit.Model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = if string.sub(name, -3) == "_PH" then name else name .. "_PH"
	m.Parent = parent
	return m
end

function Kit.Part(parent: Instance, name: string, size: Vector3, cf: CFrame, material: Enum.Material, color: Color3, opts: PartOpts?): BasePart
	local o: PartOpts = opts or {}
	local p = Instance.new(o.Class or "Part") :: BasePart
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Material = material
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	if o.Transparency then
		p.Transparency = o.Transparency
	end
	if o.Shape and p:IsA("Part") then
		p.Shape = o.Shape
	end
	if o.CanCollide ~= nil then
		p.CanCollide = o.CanCollide
	end
	if o.CanQuery ~= nil then
		p.CanQuery = o.CanQuery
	end
	if o.CastShadow ~= nil then
		p.CastShadow = o.CastShadow
	elseif o.Small then
		p.CastShadow = false
	end
	if o.Reflectance then
		p.Reflectance = o.Reflectance
	end
	if o.Thermal then
		p:SetAttribute("ThermalBlock", true)
	else
		p.CollisionGroup = "ThermalClear"
	end
	if o.Surface then
		p:SetAttribute("Surface", o.Surface)
	end
	local kitName = KIT_NAME[material]
	if kitName then
		p:SetAttribute("MaterialKit", kitName)
	end
	p.Parent = parent
	return p
end

-- Achsenparallele Box aus zwei Ecken
function Kit.Box(parent: Instance, name: string, a: Vector3, b: Vector3, material: Enum.Material, color: Color3, opts: PartOpts?): BasePart
	local mn = a:Min(b)
	local mx = a:Max(b)
	local size = mx - mn
	return Kit.Part(parent, name, size, CFrame.new((mn + mx) * 0.5), material, color, opts)
end

-- Zylinder zwischen zwei Punkten (Rohre, Kabel)
function Kit.Cylinder(parent: Instance, name: string, a: Vector3, b: Vector3, diameter: number, material: Enum.Material, color: Color3, opts: PartOpts?): BasePart
	local o: PartOpts = table.clone(opts or {})
	o.Shape = Enum.PartType.Cylinder
	local len = (b - a).Magnitude
	local mid = (a + b) * 0.5
	local cf = Kit.LookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0)
	return Kit.Part(parent, name, Vector3.new(len, diameter, diameter), cf, material, color, o)
end

function Kit.Ball(parent: Instance, name: string, center: Vector3, diameter: number, material: Enum.Material, color: Color3, opts: PartOpts?): BasePart
	local o: PartOpts = table.clone(opts or {})
	o.Shape = Enum.PartType.Ball
	return Kit.Part(parent, name, Vector3.new(diameter, diameter, diameter), CFrame.new(center), material, color, o)
end

-- lookAt, das auch bei senkrechter Blickrichtung gültig bleibt
function Kit.LookAt(at: Vector3, target: Vector3): CFrame
	local dir = target - at
	if dir.Magnitude < 1e-6 then
		return CFrame.new(at)
	end
	local unit = dir.Unit
	if math.abs(unit.Y) > 0.999 then
		return CFrame.lookAt(at, target, Vector3.new(1, 0, 0))
	end
	return CFrame.lookAt(at, target)
end

function Kit.At(x: number, y: number, z: number, yawDeg: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg or 0), 0)
end

----------------------------------------------------------------------
-- Wand mit Öffnungen
-- axis "X": Wand läuft entlang X (Nord/Süd-Wand), "Z": entlang Z (Ost/West-Wand)
----------------------------------------------------------------------
export type Opening = {
	Side: string, -- "N" | "S" | "E" | "W"
	Center: number, -- Koordinate entlang der Wand (Welt)
	Width: number,
	Height: number,
	Sill: number?, -- Unterkante über Boden (Fenster), Standard 0
}

local function wallBox(parent: Instance, axis: string, f0: number, f1: number, r0: number, r1: number, y0: number, y1: number, mat: Enum.Material, color: Color3, opts: PartOpts?): BasePart?
	if r1 - r0 < 0.01 or y1 - y0 < 0.01 then
		return nil
	end
	if axis == "X" then
		return Kit.Box(parent, "Wall", Vector3.new(r0, y0, f0), Vector3.new(r1, y1, f1), mat, color, opts)
	else
		return Kit.Box(parent, "Wall", Vector3.new(f0, y0, r0), Vector3.new(f1, y1, r1), mat, color, opts)
	end
end

function Kit.Wall(parent: Instance, axis: string, f0: number, f1: number, r0: number, r1: number, y0: number, y1: number, floorY: number, openings: { Opening }, mat: Enum.Material, color: Color3)
	local ops = table.clone(openings)
	table.sort(ops, function(a: Opening, b: Opening)
		return a.Center < b.Center
	end)
	local opts: PartOpts = { Thermal = true }
	local cursor = r0
	for _, op in ops do
		local a = op.Center - op.Width / 2
		local b = op.Center + op.Width / 2
		local sill = floorY + (op.Sill or 0)
		wallBox(parent, axis, f0, f1, cursor, a, y0, y1, mat, color, opts)
		-- unter der Öffnung (Schwelle bzw. Brüstung)
		wallBox(parent, axis, f0, f1, a, b, y0, sill, mat, color, opts)
		-- Sturz über der Öffnung
		wallBox(parent, axis, f0, f1, a, b, sill + op.Height, y1, mat, color, opts)
		cursor = b
	end
	wallBox(parent, axis, f0, f1, cursor, r1, y0, y1, mat, color, opts)
end

----------------------------------------------------------------------
-- Raum: Boden, Decke, vier Wände mit Öffnungen, Rippen, Sockelleiste
----------------------------------------------------------------------
export type RoomSpec = {
	Name: string,
	Min: Vector3, -- (x0, Bodenoberkante, z0)
	Max: Vector3, -- (x1, Deckenunterkante, z1)
	Walls: { [string]: boolean }?, -- N/S/E/W, Standard alle true
	Openings: { Opening }?,
	WallMat: Enum.Material?,
	WallColor: Color3?,
	FloorMat: Enum.Material?,
	FloorColor: Color3?,
	FloorSurface: string?,
	CeilMat: Enum.Material?,
	CeilColor: Color3?,
	Ceiling: boolean?,
	Floor: boolean?,
	Thickness: number?,
	WallTop: number?, -- Oberkante der Wände (Standard: Decke + Dicke)
	Ribs: boolean?,
	Baseboard: boolean?,
	Corners: string?, -- "Both" (Standard), "None", "E", "W": an welchen Enden N/S-Wände die Ecken abdecken
	RibColor: Color3?,
}

function Kit.Room(parent: Instance, spec: RoomSpec): Model
	local model = Kit.Model(parent, spec.Name)
	local t = spec.Thickness or 1
	local mn, mx = spec.Min, spec.Max
	local floorY, ceilY = mn.Y, mx.Y
	local walls: { [string]: boolean } = spec.Walls or { N = true, S = true, E = true, W = true }
	local openings: { Opening } = spec.Openings or {}
	local wallMat = spec.WallMat or Kit.Mat.RustSteel
	local wallColor = spec.WallColor or Kit.Col.Rust
	local y0 = floorY - 1
	local y1 = spec.WallTop or (ceilY + t)

	local function opsFor(side: string): { Opening }
		local out: { Opening } = {}
		for _, o in openings do
			if o.Side == side then
				table.insert(out, o)
			end
		end
		return out
	end

	if spec.Floor ~= false then
		Kit.Box(model, "Floor", Vector3.new(mn.X, floorY - 1, mn.Z), Vector3.new(mx.X, floorY, mx.Z), spec.FloorMat or Kit.Mat.SaltConcrete, spec.FloorColor or Kit.Col.Floor, { Thermal = true, Surface = spec.FloorSurface })
	end
	if spec.Ceiling ~= false then
		Kit.Box(model, "Ceiling", Vector3.new(mn.X, ceilY, mn.Z), Vector3.new(mx.X, ceilY + t, mx.Z), spec.CeilMat or Kit.Mat.RustSteel, spec.CeilColor or Kit.Col.RustDark, { Thermal = true })
	end

	-- N/S-Wände decken die Ecken ab, E/W-Wände laufen dazwischen
	local corners = spec.Corners or "Both"
	local cx0 = if corners == "Both" or corners == "W" then mn.X - t else mn.X
	local cx1 = if corners == "Both" or corners == "E" then mx.X + t else mx.X
	if walls.N then
		Kit.Wall(model, "X", mx.Z, mx.Z + t, cx0, cx1, y0, y1, floorY, opsFor("N"), wallMat, wallColor)
	end
	if walls.S then
		Kit.Wall(model, "X", mn.Z - t, mn.Z, cx0, cx1, y0, y1, floorY, opsFor("S"), wallMat, wallColor)
	end
	if walls.E then
		Kit.Wall(model, "Z", mx.X, mx.X + t, mn.Z, mx.Z, y0, y1, floorY, opsFor("E"), wallMat, wallColor)
	end
	if walls.W then
		Kit.Wall(model, "Z", mn.X - t, mn.X, mn.Z, mx.Z, y0, y1, floorY, opsFor("W"), wallMat, wallColor)
	end

	-- Rippen (Pfeiler) alle 8 Studs an der Innenseite, nicht in Öffnungen
	if spec.Ribs ~= false then
		local ribColor = spec.RibColor or Kit.Col.RustDark
		local h = ceilY - floorY
		local function blocked(side: string, r: number): boolean
			for _, o in opsFor(side) do
				if math.abs(r - o.Center) < o.Width / 2 + 1 then
					return true
				end
			end
			return false
		end
		local function ribsAlong(side: string, fixed: number, inward: number, r0: number, r1: number, axis: string)
			local r = r0 + 4
			while r <= r1 - 3 do
				if not blocked(side, r) then
					local c: Vector3
					local size: Vector3
					if axis == "X" then
						c = Vector3.new(r, floorY + h / 2, fixed + inward * 0.2)
						size = Vector3.new(0.7, h, 0.4)
					else
						c = Vector3.new(fixed + inward * 0.2, floorY + h / 2, r)
						size = Vector3.new(0.4, h, 0.7)
					end
					Kit.Part(model, "Rib", size, CFrame.new(c), Kit.Mat.RustSteel, ribColor, { Thermal = true, Small = true })
				end
				r += 8
			end
		end
		if walls.N then
			ribsAlong("N", mx.Z, -1, mn.X, mx.X, "X")
		end
		if walls.S then
			ribsAlong("S", mn.Z, 1, mn.X, mx.X, "X")
		end
		if walls.E then
			ribsAlong("E", mx.X, -1, mn.Z, mx.Z, "Z")
		end
		if walls.W then
			ribsAlong("W", mn.X, 1, mn.Z, mx.Z, "Z")
		end
	end

	-- Sockelleiste
	if spec.Baseboard ~= false then
		local bb = Kit.Col.Black
		local function strip(side: string, axis: string, fixed: number, inward: number, r0: number, r1: number)
			local cursor = r0
			local ops = opsFor(side)
			table.sort(ops, function(a: Opening, b: Opening)
				return a.Center < b.Center
			end)
			local function seg(a: number, b: number)
				if b - a < 0.2 then
					return
				end
				if axis == "X" then
					Kit.Box(model, "Baseboard", Vector3.new(a, floorY, fixed), Vector3.new(b, floorY + 0.6, fixed + inward * 0.15), Kit.Mat.Rubber, bb, { Thermal = true, Small = true })
				else
					Kit.Box(model, "Baseboard", Vector3.new(fixed, floorY, a), Vector3.new(fixed + inward * 0.15, floorY + 0.6, b), Kit.Mat.Rubber, bb, { Thermal = true, Small = true })
				end
			end
			for _, o in ops do
				if (o.Sill or 0) <= 0 then
					seg(cursor, o.Center - o.Width / 2)
					cursor = o.Center + o.Width / 2
				end
			end
			seg(cursor, r1)
		end
		if walls.N then
			strip("N", "X", mx.Z, -1, mn.X, mx.X)
		end
		if walls.S then
			strip("S", "X", mn.Z, 1, mn.X, mx.X)
		end
		if walls.E then
			strip("E", "Z", mx.X, -1, mn.Z, mx.Z)
		end
		if walls.W then
			strip("W", "Z", mn.X, 1, mn.Z, mx.Z)
		end
	end

	return model
end

----------------------------------------------------------------------
-- Platte mit rechteckigen Löchern (Decken mit Luken, Böden mit Schächten)
-- holes: { {x0, z0, x1, z1} } in Weltkoordinaten
----------------------------------------------------------------------
function Kit.SlabWithHoles(parent: Instance, name: string, x0: number, z0: number, x1: number, z1: number, y0: number, y1: number, holes: { { number } }, mat: Enum.Material, color: Color3, opts: PartOpts?)
	type Rect = { number }
	local rects: { Rect } = { { x0, z0, x1, z1 } }
	for _, h in holes do
		local nextRects: { Rect } = {}
		for _, r in rects do
			local hx0, hz0 = math.max(h[1], r[1]), math.max(h[2], r[2])
			local hx1, hz1 = math.min(h[3], r[3]), math.min(h[4], r[4])
			if hx0 >= hx1 or hz0 >= hz1 then
				table.insert(nextRects, r)
			else
				-- in bis zu 4 Rechtecke um das Loch zerlegen
				if r[2] < hz0 then
					table.insert(nextRects, { r[1], r[2], r[3], hz0 })
				end
				if hz1 < r[4] then
					table.insert(nextRects, { r[1], hz1, r[3], r[4] })
				end
				if r[1] < hx0 then
					table.insert(nextRects, { r[1], hz0, hx0, hz1 })
				end
				if hx1 < r[3] then
					table.insert(nextRects, { hx1, hz0, r[3], hz1 })
				end
			end
		end
		rects = nextRects
	end
	for _, r in rects do
		if r[3] - r[1] > 0.01 and r[4] - r[2] > 0.01 then
			Kit.Box(parent, name, Vector3.new(r[1], y0, r[2]), Vector3.new(r[3], y1, r[4]), mat, color, opts)
		end
	end
end

-- Ordnerstruktur einer Zone (Abschnitt 13.1)
export type ZoneFolders = {
	Root: Folder,
	Geometry: Folder,
	Props: Folder,
	Lights: Folder,
	Waypoints: Folder,
	Volumes: Folder,
	Spawns: Folder,
}

function Kit.ZoneFolders(map: Instance, name: string): ZoneFolders
	local root = Kit.Folder(map, name)
	return {
		Root = root,
		Geometry = Kit.Folder(root, "Geometry"),
		Props = Kit.Folder(root, "Props"),
		Lights = Kit.Folder(root, "Lights"),
		Waypoints = Kit.Folder(root, "Waypoints"),
		Volumes = Kit.Folder(root, "Volumes"),
		Spawns = Kit.Folder(root, "Spawns"),
	}
end

function Kit.Face(pos: Vector3, dir: Vector3): CFrame
	return Kit.LookAt(pos, pos + dir)
end

----------------------------------------------------------------------
-- Türen
-- kind: "Normal" (Schiebetür, Wesen bricht sie auf), "Armor" (Panzertür, fährt hoch),
--       "Keycard" (Panzertür mit Kartenleser), "Airlock" (Lobby-Schleuse)
-- axis: Richtung, in der die Wand verläuft ("X" oder "Z")
----------------------------------------------------------------------
function Kit.Door(parent: Instance, name: string, center: Vector3, axis: string, width: number, height: number, kind: string): Model
	local model = Kit.Model(parent, "Door_" .. name)
	model:AddTag("Door")
	model:SetAttribute("DoorKind", kind)
	model:SetAttribute("Open", false)
	model:SetAttribute("Locked", kind ~= "Normal")
	model:SetAttribute("Broken", false)

	local armored = kind ~= "Normal"
	local thick = if armored then 0.8 else 0.5
	local along = if axis == "X" then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
	local rot = if axis == "X" then CFrame.new() else CFrame.Angles(0, math.rad(90), 0)

	local closed = CFrame.new(center + Vector3.new(0, height / 2, 0)) * rot
	local open: CFrame
	if armored then
		open = closed + Vector3.new(0, height - 0.6, 0)
	else
		open = closed + along * (width - 0.4)
	end

	local panelColor = if armored then Kit.Col.FrostDark else Kit.Col.Frost
	local panel = Kit.Part(model, "Panel", Vector3.new(width, height, thick), closed, Kit.Mat.FrostMetal, panelColor, { Thermal = true })
	panel:SetAttribute("ClosedCF", closed)
	panel:SetAttribute("OpenCF", open)
	model.PrimaryPart = panel

	-- Paneel-Details (geschweißt am Paneel, bewegen sich mit)
	local function detail(n: string, size: Vector3, offset: CFrame, mat: Enum.Material, color: Color3)
		local d = Kit.Part(model, n, size, closed * offset, mat, color, { Thermal = true, Small = true, CanCollide = false })
		d:SetAttribute("PanelOffset", offset)
	end
	if armored then
		-- Gefahrenstreifen
		for i = 0, 4 do
			local x = -width / 2 + 0.6 + i * (width - 1.2) / 4
			detail("Stripe", Vector3.new(0.5, 1.2, thick + 0.06), CFrame.new(x, -height / 2 + 0.8, 0) * CFrame.Angles(0, 0, math.rad(35)), Kit.Mat.Metal, Kit.Col.Hazard)
		end
		detail("Bar", Vector3.new(width - 0.6, 0.5, thick + 0.1), CFrame.new(0, 0.5, 0), Kit.Mat.RustSteel, Kit.Col.RustDark)
		detail("Bolt", Vector3.new(0.8, 0.8, thick + 0.15), CFrame.new(0, 0.5, 0), Kit.Mat.Metal, Kit.Col.Black)
	else
		detail("Window", Vector3.new(width * 0.4, height * 0.18, thick + 0.04), CFrame.new(0, height * 0.18, 0), Kit.Mat.Glass, Kit.Col.Ice)
		detail("Handle", Vector3.new(0.2, 1.2, thick + 0.3), CFrame.new(width / 2 - 0.6, -0.4, 0), Kit.Mat.Metal, Kit.Col.Black)
	end

	-- Rahmen (statisch)
	local frameColor = if armored then Kit.Col.Hazard else Kit.Col.RustDark
	local fw = 0.6
	local depth = 1.4
	local function frame(n: string, size: Vector3, pos: Vector3)
		Kit.Part(model, n, size, CFrame.new(pos) * rot, Kit.Mat.RustSteel, frameColor, { Thermal = true, Small = true })
	end
	local sideOff = along * (width / 2 + fw / 2)
	frame("FrameL", Vector3.new(fw, height, depth), center - sideOff + Vector3.new(0, height / 2, 0))
	frame("FrameR", Vector3.new(fw, height, depth), center + sideOff + Vector3.new(0, height / 2, 0))
	frame("FrameTop", Vector3.new(width + fw * 2, fw, depth), center + Vector3.new(0, height + fw / 2, 0))

	if kind == "Normal" then
		local mod = Instance.new("PathfindingModifier")
		mod.Label = "Door"
		mod.PassThrough = true
		mod.Parent = panel
	end

	-- Anker für ProximityPrompts (beide Seiten erreichbar)
	local anchor = Kit.Part(model, "PromptAnchor", Vector3.new(1, 1, 1), CFrame.new(center + Vector3.new(0, 4, 0)), Kit.Mat.Metal, Kit.Col.Black, { Transparency = 1, CanCollide = false, CanQuery = false })
	anchor.CastShadow = false
	return model
end

----------------------------------------------------------------------
-- Lampen
----------------------------------------------------------------------
-- Deckenlampe: Neonröhre + PointLight; Tag bestimmt, wann sie leuchtet
function Kit.CeilingLamp(parent: Instance, pos: Vector3, tag: string, group: string, color: Color3, range: number, brightness: number, yawDeg: number?): BasePart
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg or 0), 0)
	Kit.Part(parent, "LampHousing", Vector3.new(4.4, 0.35, 1.1), cf * CFrame.new(0, 0.1, 0), Kit.Mat.Metal, Kit.Col.FrostDark, { Small = true, CanCollide = false })
	local tube = Kit.Part(parent, "LampTube", Vector3.new(4, 0.25, 0.6), cf * CFrame.new(0, -0.15, 0), Kit.Mat.Neon, color, { Small = true, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = tube
	tube:SetAttribute("BaseBrightness", brightness)
	tube:SetAttribute("BaseColor", color)
	tube:SetAttribute("PowerGroup", group)
	tube:AddTag(tag)
	tube:AddTag("FlickerLight")
	return tube
end

-- Rote Notbeleuchtung (an nach Stromausfall, nur in Fluren)
function Kit.EmergencyLight(parent: Instance, pos: Vector3, normal: Vector3, group: string): BasePart
	local cf = CFrame.lookAt(pos, pos + normal)
	Kit.Part(parent, "EmergencyCage", Vector3.new(1.2, 0.8, 0.5), cf * CFrame.new(0, 0, 0.1), Kit.Mat.Metal, Kit.Col.Black, { Small = true, CanCollide = false })
	local bulb = Kit.Part(parent, "EmergencyBulb", Vector3.new(0.9, 0.5, 0.3), cf * CFrame.new(0, 0, -0.2), Kit.Mat.Glass, Color3.fromRGB(90, 20, 18), { Small = true, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 30, 20)
	light.Range = 14
	light.Brightness = 0.6
	light.Enabled = false
	light.Shadows = false
	light.Parent = bulb
	bulb:SetAttribute("BaseBrightness", 0.6)
	bulb:SetAttribute("PowerGroup", group)
	bulb:AddTag("EmergencyLight")
	bulb:AddTag("FlickerLight")
	return bulb
end

-- Einfache Punktlichtquelle (Tanks, Reaktor, Ofen)
function Kit.GlowLight(part: BasePart, color: Color3, range: number, brightness: number, shadows: boolean?): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows == true
	l.Parent = part
	return l
end

----------------------------------------------------------------------
-- Volumen, Wegpunkte, Spawns, Lüftungsschächte
----------------------------------------------------------------------
function Kit.Volume(parent: Instance, name: string, cf: CFrame, size: Vector3, attrs: { [string]: any }?): BasePart
	local p = Kit.Part(parent, name, size, cf, Kit.Mat.Glass, Color3.fromRGB(255, 255, 255), {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	if attrs then
		for k, v in attrs do
			p:SetAttribute(k, v)
		end
	end
	return p
end

function Kit.BoxVolume(parent: Instance, name: string, a: Vector3, b: Vector3, attrs: { [string]: any }?): BasePart
	local mn = a:Min(b)
	local mx = a:Max(b)
	return Kit.Volume(parent, name, CFrame.new((mn + mx) * 0.5), mx - mn, attrs)
end

function Kit.Marker(parent: Instance, name: string, cf: CFrame, tag: string, attrs: { [string]: any }?): BasePart
	local p = Kit.Volume(parent, name, cf, Vector3.new(1, 1, 1), attrs)
	p:AddTag(tag)
	return p
end

function Kit.Waypoint(parent: Instance, pos: Vector3, zone: string, index: number): BasePart
	return Kit.Marker(parent, string.format("WP_%s_%02d", zone, index), CFrame.new(pos + Vector3.new(0, 1, 0)), "Waypoint", { Zone = zone, Index = index })
end

-- Lüftungsschacht-Gitter an der Wand. cf: Position auf der Wandfläche, LookVector zeigt in den Raum.
function Kit.Vent(parent: Instance, id: string, cf: CFrame, zone: string): Model
	local m = Kit.Model(parent, "Vent_" .. id)
	m:AddTag("Vent")
	m:SetAttribute("VentId", id)
	m:SetAttribute("Zone", zone)
	Kit.Part(m, "Frame", Vector3.new(4, 4, 0.6), cf * CFrame.new(0, 0, -0.1), Kit.Mat.RustSteel, Kit.Col.RustDark, { Thermal = true, Small = true })
	Kit.Part(m, "Hole", Vector3.new(3.4, 3.4, 0.3), cf * CFrame.new(0, 0, 0.1), Kit.Mat.Metal, Kit.Col.Black, { Thermal = true, Small = true })
	for i = -1, 1 do
		Kit.Part(m, "Slat", Vector3.new(3.4, 0.25, 0.3), cf * CFrame.new(0, i * 0.9, -0.3) * CFrame.Angles(math.rad(-25), 0, 0), Kit.Mat.FrostMetal, Kit.Col.Frost, { Small = true })
	end
	local frost = Kit.Part(m, "Frost", Vector3.new(4.4, 4.4, 0.1), cf * CFrame.new(0, 0, -0.5), Kit.Mat.IceSheet, Kit.Col.Ice, { Transparency = 1, CanCollide = false, CanQuery = false, Small = true })
	frost:SetAttribute("FrostOverlay", true)
	-- Austrittspunkt für das Wesen (am Boden, 4 Studs vor dem Gitter)
	local exitPos = (cf * CFrame.new(0, 0, -4)).Position
	Kit.Marker(m, "Exit", CFrame.lookAt(exitPos, exitPos + cf.LookVector), "VentExit", { VentId = id })
	local snd = Kit.Volume(m, "SoundAnchor", cf, Vector3.new(1, 1, 1))
	snd.Name = "SoundAnchor"
	return m
end

----------------------------------------------------------------------
-- Bildschirme (SurfaceGui mit Textfeld) – Text wird vom Server/Client gesetzt
----------------------------------------------------------------------
function Kit.Screen(part: BasePart, face: Enum.NormalId, canvas: Vector2, color: Color3, text: string, name: string?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = name or "Screen"
	gui.Face = face
	gui.CanvasSize = canvas
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.ResetOnSpawn = false
	gui.Parent = part
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(4, 10, 6)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, -40, 1, -40)
	label.Position = UDim2.fromOffset(20, 20)
	label.BackgroundTransparency = 1
	label.FontFace = Font.fromEnum(Enum.Font.RobotoMono)
	label.TextColor3 = color
	label.TextSize = 28
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.RichText = true
	label.Text = text
	label.Parent = bg
	-- Scanlines (Platzhalter aus Frames)
	local lines = Instance.new("Frame")
	lines.Name = "Scanlines"
	lines.Size = UDim2.fromScale(1, 1)
	lines.BackgroundTransparency = 1
	lines.Parent = bg
	local step = 6
	local count = math.floor(canvas.Y / step)
	for i = 0, count do
		local l = Instance.new("Frame")
		l.BorderSizePixel = 0
		l.BackgroundColor3 = Color3.new(0, 0, 0)
		l.BackgroundTransparency = 0.75
		l.Size = UDim2.new(1, 0, 0, 2)
		l.Position = UDim2.fromOffset(0, i * step)
		l.Parent = lines
	end
	return label
end

-- Beschriftungsschild (Michroma, Geräte-Beschriftung)
function Kit.Sign(parent: Instance, cf: CFrame, size: Vector2, text: string, color: Color3?, textColor: Color3?): BasePart
	local plate = Kit.Part(parent, "Sign", Vector3.new(size.X, size.Y, 0.15), cf, Kit.Mat.Metal, color or Kit.Col.Hazard, { Small = true, CanCollide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(size.X * 50, size.Y * 50)
	gui.LightInfluence = 1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.Parent = plate
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.fromEnum(Enum.Font.Michroma)
	label.TextScaled = true
	label.TextColor3 = textColor or Kit.Col.Black
	label.Text = text
	label.Parent = gui
	return plate
end

----------------------------------------------------------------------
-- Partikel
----------------------------------------------------------------------
export type EmitterSpec = {
	Texture: string?,
	Color: Color3?,
	Color2: Color3?,
	Size0: number?,
	Size1: number?,
	Transparency0: number?,
	Transparency1: number?,
	Lifetime: NumberRange?,
	Rate: number?,
	Speed: NumberRange?,
	Spread: Vector2?,
	Acceleration: Vector3?,
	Drag: number?,
	Rotation: NumberRange?,
	RotSpeed: NumberRange?,
	LightEmission: number?,
	Enabled: boolean?,
	EmissionDirection: Enum.NormalId?,
	LockedToPart: boolean?,
	Shape: Enum.ParticleEmitterShape?,
	ShapeStyle: Enum.ParticleEmitterShapeStyle?,
}

Kit.Tex = {
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
}

function Kit.Emitter(parent: Instance, name: string, spec: EmitterSpec): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = spec.Texture or Kit.Tex.Smoke
	local c1 = spec.Color or Color3.new(1, 1, 1)
	local c2 = spec.Color2 or c1
	e.Color = ColorSequence.new(c1, c2)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, spec.Size0 or 1),
		NumberSequenceKeypoint.new(1, spec.Size1 or spec.Size0 or 1),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, spec.Transparency0 or 0.5),
		NumberSequenceKeypoint.new(1, spec.Transparency1 or 1),
	})
	e.Lifetime = spec.Lifetime or NumberRange.new(1, 2)
	e.Rate = spec.Rate or 5
	e.Speed = spec.Speed or NumberRange.new(1, 2)
	e.SpreadAngle = spec.Spread or Vector2.new(10, 10)
	e.Acceleration = spec.Acceleration or Vector3.new(0, 0, 0)
	e.Drag = spec.Drag or 0
	e.Rotation = spec.Rotation or NumberRange.new(0, 360)
	e.RotSpeed = spec.RotSpeed or NumberRange.new(-20, 20)
	e.LightEmission = spec.LightEmission or 0
	e.Enabled = spec.Enabled ~= false
	e.EmissionDirection = spec.EmissionDirection or Enum.NormalId.Top
	e.LockedToPart = spec.LockedToPart == true
	if spec.Shape then
		e.Shape = spec.Shape
	end
	if spec.ShapeStyle then
		e.ShapeStyle = spec.ShapeStyle
	end
	e.Parent = parent
	return e
end

-- Bodennebel (große, langsame Rauchpartikel)
function Kit.GroundFog(parent: Instance, center: Vector3, size: Vector3, color: Color3, rate: number?): BasePart
	local p = Kit.Volume(parent, "GroundFog", CFrame.new(center), size)
	local e = Kit.Emitter(p, "Fog", {
		Color = color,
		Size0 = 7,
		Size1 = 12,
		Transparency0 = 0.82,
		Transparency1 = 1,
		Lifetime = NumberRange.new(8, 12),
		Rate = rate or 2,
		Speed = NumberRange.new(0.3, 0.8),
		Spread = Vector2.new(180, 10),
		RotSpeed = NumberRange.new(-6, 6),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	e:AddTag("AmbientEmitter")
	return p
end

-- Lichtstrahl per Beam mit Nebel-Textur
function Kit.LightShaft(parent: Instance, top: Vector3, bottom: Vector3, width0: number, width1: number, color: Color3): Beam
	local p = Kit.Volume(parent, "LightShaft", CFrame.new(top), Vector3.new(1, 1, 1))
	local a0 = Instance.new("Attachment")
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = bottom - top
	a1.Parent = p
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Width0 = width0
	b.Width1 = width1
	b.Texture = Kit.Tex.Smoke
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureSpeed = 0.05
	b.Color = ColorSequence.new(color)
	b.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.82),
		NumberSequenceKeypoint.new(1, 1),
	})
	b.LightEmission = 0.6
	b.FaceCamera = true
	b.Segments = 1
	b.Parent = p
	b:AddTag("LightShaft")
	return b
end

return Kit
