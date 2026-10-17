--!strict
-- Props und Hero-Props aus Teilen. Konvention: cf liegt am Boden in der Mitte des
-- Objekts, die Vorderseite zeigt in Richtung cf.LookVector (lokal -Z).
-- Hero-Props sind Platzhalter für spätere Meshes und tragen deshalb _PH im Namen.

local Kit = require(script.Parent.Kit)

local Mat, Col = Kit.Mat, Kit.Col
local P = Kit.Part

local Props = {}

local SMALL: Kit.PartOpts = { Small = true }
local DECOR: Kit.PartOpts = { Small = true, CanCollide = false }

----------------------------------------------------------------------
-- Möbel
----------------------------------------------------------------------
function Props.Table(parent: Instance, cf: CFrame, w: number, d: number): Model
	local m = Kit.Model(parent, "Table")
	P(m, "Top", Vector3.new(w, 0.3, d), cf * CFrame.new(0, 3, 0), Mat.FrostMetal, Col.Frost, SMALL)
	for _, s in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		P(m, "Leg", Vector3.new(0.3, 2.85, 0.3), cf * CFrame.new(s[1] * (w / 2 - 0.3), 1.425, s[2] * (d / 2 - 0.3)), Mat.Metal, Col.FrostDark, SMALL)
	end
	return m
end

function Props.Bench(parent: Instance, cf: CFrame, w: number): Model
	local m = Kit.Model(parent, "Bench")
	P(m, "Seat", Vector3.new(w, 0.3, 1.4), cf * CFrame.new(0, 1.8, 0), Mat.Wood, Col.Wood, SMALL)
	P(m, "LegA", Vector3.new(0.3, 1.65, 1.2), cf * CFrame.new(-w / 2 + 0.4, 0.825, 0), Mat.Metal, Col.FrostDark, SMALL)
	P(m, "LegB", Vector3.new(0.3, 1.65, 1.2), cf * CFrame.new(w / 2 - 0.4, 0.825, 0), Mat.Metal, Col.FrostDark, SMALL)
	return m
end

function Props.Chair(parent: Instance, cf: CFrame, tipped: boolean?): Model
	local m = Kit.Model(parent, "Chair")
	local base = if tipped then cf * CFrame.new(0, 0.6, 0) * CFrame.Angles(math.rad(80), 0, 0) else cf
	P(m, "Seat", Vector3.new(1.6, 0.25, 1.6), base * CFrame.new(0, 1.8, 0), Mat.Fabric, Col.Fabric, SMALL)
	P(m, "Back", Vector3.new(1.6, 1.8, 0.25), base * CFrame.new(0, 2.8, 0.7), Mat.Fabric, Col.Fabric, SMALL)
	P(m, "Post", Vector3.new(0.3, 1.7, 0.3), base * CFrame.new(0, 0.85, 0), Mat.Metal, Col.FrostDark, SMALL)
	return m
end

-- Bett; gibt die Matratze zurück (Versteck "unter Matratze")
function Props.Bed(parent: Instance, cf: CFrame): (Model, BasePart)
	local m = Kit.Model(parent, "Bed")
	P(m, "Frame", Vector3.new(3.4, 0.5, 7), cf * CFrame.new(0, 1.3, 0), Mat.Metal, Col.FrostDark, SMALL)
	for _, s in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		P(m, "Leg", Vector3.new(0.3, 1.1, 0.3), cf * CFrame.new(s[1] * 1.5, 0.55, s[2] * 3.3), Mat.Metal, Col.FrostDark, SMALL)
	end
	local mattress = P(m, "Mattress", Vector3.new(3.2, 0.6, 6.6), cf * CFrame.new(0, 1.85, 0.1), Mat.Fabric, Color3.fromRGB(140, 135, 120), SMALL)
	P(m, "Pillow", Vector3.new(2.4, 0.4, 1.2), cf * CFrame.new(0, 2.3, 2.6), Mat.Fabric, Color3.fromRGB(190, 185, 170), DECOR)
	P(m, "Blanket", Vector3.new(3.3, 0.15, 3.6), cf * CFrame.new(0, 2.2, -1.2) * CFrame.Angles(0, 0, math.rad(2)), Mat.Fabric, Color3.fromRGB(70, 80, 60), DECOR)
	P(m, "Headboard", Vector3.new(3.4, 2.4, 0.3), cf * CFrame.new(0, 2.2, 3.4), Mat.Metal, Col.FrostDark, SMALL)
	return m, mattress
end

-- Spind. hide = Versteck-Spind (Spieler kann hinein).
function Props.Locker(parent: Instance, cf: CFrame, name: string?, hide: boolean?): Model
	local m = Kit.Model(parent, name or "Locker")
	local body = P(m, "Body", Vector3.new(3, 7.2, 2.6), cf * CFrame.new(0, 3.6, 0), Mat.FrostMetal, Col.FrostDark, { Thermal = false })
	body:SetAttribute("LockerBody", true)
	local door = P(m, "Door", Vector3.new(2.8, 6.8, 0.15), cf * CFrame.new(0, 3.6, -1.35), Mat.FrostMetal, Col.Frost, { Small = true })
	door:SetAttribute("ClosedCF", door.CFrame)
	door:SetAttribute("OpenCF", cf * CFrame.new(-1.4, 3.6, -1.35) * CFrame.Angles(0, math.rad(-100), 0) * CFrame.new(1.4, 0, 0))
	-- Lamellen (man sieht durch sie hinaus)
	for i = 0, 5 do
		P(m, "Louver", Vector3.new(2, 0.15, 0.12), cf * CFrame.new(0, 5.4 + i * 0.22, -1.45), Mat.Metal, Col.Black, DECOR)
	end
	P(m, "Handle", Vector3.new(0.15, 0.8, 0.2), cf * CFrame.new(1.1, 3.6, -1.5), Mat.Metal, Col.Black, DECOR)
	local interact = Kit.Volume(m, "Interact", cf * CFrame.new(0, 3.6, -1.6), Vector3.new(2.6, 4, 0.5))
	interact:SetAttribute("Interact", true)
	if hide then
		m:AddTag("HideLocker")
		-- Innenposition (Spieler steht im Spind, Blick nach vorne)
		Kit.Marker(m, "Inside", cf * CFrame.new(0, 3, 0.1), "LockerInside")
		Kit.Marker(m, "Outside", cf * CFrame.new(0, 3, -3.5), "LockerOutside")
	end
	return m
end

function Props.Cabinet(parent: Instance, cf: CFrame, name: string?): Model
	local m = Kit.Model(parent, name or "Cabinet")
	P(m, "Body", Vector3.new(4, 3.2, 2), cf * CFrame.new(0, 1.6, 0), Mat.FrostMetal, Col.Frost, SMALL)
	for i = 0, 2 do
		P(m, "Drawer", Vector3.new(3.6, 0.85, 0.12), cf * CFrame.new(0, 0.6 + i * 1, -1.02), Mat.FrostMetal, Col.FrostDark, DECOR)
		P(m, "Pull", Vector3.new(0.8, 0.15, 0.15), cf * CFrame.new(0, 0.6 + i * 1, -1.12), Mat.Metal, Col.Black, DECOR)
	end
	local interact = Kit.Volume(m, "Interact", cf * CFrame.new(0, 1.6, -1.3), Vector3.new(3.6, 3, 0.5))
	interact:SetAttribute("Interact", true)
	return m
end

function Props.Shelf(parent: Instance, cf: CFrame, w: number, rng: Kit.Rng): Model
	local m = Kit.Model(parent, "Shelf")
	for i = 0, 3 do
		P(m, "Board", Vector3.new(w, 0.2, 2), cf * CFrame.new(0, 0.3 + i * 2, 0), Mat.RustSteel, Col.Rust, SMALL)
	end
	for _, sx in { -1, 1 } do
		P(m, "Post", Vector3.new(0.25, 6.6, 2), cf * CFrame.new(sx * (w / 2 - 0.1), 3.3, 0), Mat.RustSteel, Col.RustDark, SMALL)
	end
	-- Kisten und Dosen auf den Brettern
	for i = 0, 2 do
		local x = -w / 2 + 0.8
		while x < w / 2 - 0.8 do
			if rng:Next() < 0.7 then
				local s = rng:Range(0.6, 1.4)
				local c = if rng:Next() < 0.5 then Color3.fromRGB(150, 120, 80) else Color3.fromRGB(80, 90, 70)
				P(m, "Box", Vector3.new(s, s * 0.8, s), cf * CFrame.new(x, 0.4 + i * 2 + s * 0.4, rng:Range(-0.3, 0.3)), Mat.Fabric, c, DECOR)
			end
			x += 1.6
		end
	end
	return m
end

function Props.Crate(parent: Instance, cf: CFrame, size: Vector3, color: Color3?): BasePart
	local c = P(parent, "Crate", size, cf * CFrame.new(0, size.Y / 2, 0), Mat.Wood, color or Color3.fromRGB(105, 85, 60), {})
	P(parent, "CrateBand", Vector3.new(size.X + 0.1, 0.25, size.Z + 0.1), cf * CFrame.new(0, size.Y * 0.75, 0), Mat.Metal, Col.FrostDark, DECOR)
	P(parent, "CrateBand", Vector3.new(size.X + 0.1, 0.25, size.Z + 0.1), cf * CFrame.new(0, size.Y * 0.25, 0), Mat.Metal, Col.FrostDark, DECOR)
	return c
end

function Props.Barrel(parent: Instance, cf: CFrame, color: Color3?): BasePart
	return P(parent, "Barrel", Vector3.new(3.2, 2.2, 2.2), cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Mat.RustSteel, color or Color3.fromRGB(60, 80, 100), { Shape = Enum.PartType.Cylinder })
end

function Props.Microwave(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Microwave")
	P(m, "Body", Vector3.new(2, 1.2, 1.4), cf * CFrame.new(0, 0.6, 0), Mat.Metal, Col.White, SMALL)
	P(m, "Window", Vector3.new(1.2, 0.8, 0.05), cf * CFrame.new(-0.25, 0.6, -0.72), Mat.Glass, Col.Black, DECOR)
	P(m, "Panel", Vector3.new(0.5, 0.9, 0.05), cf * CFrame.new(0.65, 0.6, -0.72), Mat.Metal, Col.FrostDark, DECOR)
	local interact = Kit.Volume(m, "Interact", cf * CFrame.new(0, 0.6, -0.9), Vector3.new(2, 1.2, 0.4))
	interact:SetAttribute("Interact", true)
	return m
end

function Props.Toolbox(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Toolbox")
	P(m, "Body", Vector3.new(2.2, 1, 1), cf * CFrame.new(0, 0.5, 0), Mat.Metal, Color3.fromRGB(170, 40, 30), SMALL)
	P(m, "Lid", Vector3.new(2.25, 0.2, 1.05), cf * CFrame.new(0, 1.05, 0), Mat.Metal, Color3.fromRGB(150, 35, 25), DECOR)
	P(m, "Handle", Vector3.new(1.2, 0.15, 0.15), cf * CFrame.new(0, 1.35, 0), Mat.Metal, Col.Black, DECOR)
	local interact = Kit.Volume(m, "Interact", cf * CFrame.new(0, 0.8, 0), Vector3.new(2.2, 1.6, 1.4))
	interact:SetAttribute("Interact", true)
	return m
end

-- Notiz / Klemmbrett / Tonband auf einer Fläche
function Props.Note(parent: Instance, cf: CFrame, noteId: string, kind: string): BasePart
	local part: BasePart
	if kind == "Tape" then
		part = P(parent, "Note_" .. noteId, Vector3.new(1.2, 0.5, 0.8), cf * CFrame.new(0, 0.25, 0), Mat.Metal, Color3.fromRGB(40, 40, 42), SMALL)
		P(parent, "Reel", Vector3.new(0.1, 0.45, 0.45), cf * CFrame.new(-0.3, 0.52, 0) * CFrame.Angles(0, 0, math.rad(90)), Mat.Metal, Col.Frost, { Small = true, CanCollide = false, Shape = Enum.PartType.Cylinder })
		P(parent, "Reel", Vector3.new(0.1, 0.45, 0.45), cf * CFrame.new(0.3, 0.52, 0) * CFrame.Angles(0, 0, math.rad(90)), Mat.Metal, Col.Frost, { Small = true, CanCollide = false, Shape = Enum.PartType.Cylinder })
	elseif kind == "Clipboard" then
		part = P(parent, "Note_" .. noteId, Vector3.new(1.3, 0.08, 1.8), cf * CFrame.new(0, 0.04, 0), Mat.Wood, Color3.fromRGB(150, 110, 70), SMALL)
		P(parent, "Paper", Vector3.new(1.15, 0.02, 1.5), cf * CFrame.new(0, 0.09, 0.05), Mat.Fabric, Color3.fromRGB(225, 215, 185), DECOR)
		P(parent, "Clip", Vector3.new(0.5, 0.12, 0.2), cf * CFrame.new(0, 0.12, -0.8), Mat.Metal, Col.Frost, DECOR)
	else
		part = P(parent, "Note_" .. noteId, Vector3.new(1.1, 0.03, 1.5), cf * CFrame.new(0, 0.015, 0) * CFrame.Angles(0, math.rad(8), 0), Mat.Fabric, Color3.fromRGB(225, 212, 175), DECOR)
	end
	part:AddTag("Note")
	part:SetAttribute("NoteId", noteId)
	return part
end

function Props.Pipe(parent: Instance, a: Vector3, b: Vector3, d: number, color: Color3?): BasePart
	return Kit.Cylinder(parent, "Pipe", a, b, d, Mat.RustSteel, color or Col.Pipe, DECOR)
end

-- Geländer zwischen zwei Punkten (am Boden)
function Props.Railing(parent: Instance, a: Vector3, b: Vector3, height: number?): Model
	local m = Kit.Model(parent, "Railing")
	local h = height or 3.5
	local len = (b - a).Magnitude
	local dir = (b - a).Unit
	local cf = CFrame.lookAt(a, b)
	P(m, "Top", Vector3.new(0.25, 0.25, len), cf * CFrame.new(0, h, -len / 2), Mat.Metal, Col.Hazard, SMALL)
	P(m, "Mid", Vector3.new(0.18, 0.18, len), cf * CFrame.new(0, h / 2, -len / 2), Mat.Metal, Col.FrostDark, DECOR)
	-- unsichtbare Kollision, damit niemand herunterfällt
	P(m, "Guard", Vector3.new(0.4, h, len), cf * CFrame.new(0, h / 2, -len / 2), Mat.Glass, Col.White, { Transparency = 1, Small = true })
	local n = math.max(1, math.floor(len / 4))
	for i = 0, n do
		local pos = a + dir * (len * i / n)
		P(m, "Post", Vector3.new(0.25, h, 0.25), CFrame.new(pos + Vector3.new(0, h / 2, 0)), Mat.Metal, Col.FrostDark, DECOR)
	end
	return m
end

-- Treppe als begehbare Rampe (WedgePart) mit Stufen-Optik und Geländer.
-- bottom: Fußpunkt Mitte unten, dir: horizontale Laufrichtung (Einheitsvektor), rise: Höhe, run: Länge
function Props.Stairs(parent: Instance, bottom: Vector3, dir: Vector3, rise: number, run: number, width: number): Model
	local m = Kit.Model(parent, "Stairs")
	local top = bottom + dir * run + Vector3.new(0, rise, 0)
	local mid = (bottom + top) * 0.5
	-- WedgePart: die schräge Fläche steigt von vorne (-Z, niedrig) nach hinten (+Z, hoch).
	-- Darum zeigt der LookVector entgegen der Laufrichtung.
	local look = CFrame.lookAt(Vector3.new(mid.X, bottom.Y + rise / 2, mid.Z), Vector3.new(mid.X, bottom.Y + rise / 2, mid.Z) - dir)
	local ramp = P(m, "Ramp", Vector3.new(width, rise, run), look, Mat.GrateMetal, Col.Grate, { Class = "WedgePart", Surface = "Grate" })
	ramp:SetAttribute("Surface", "Grate")
	local steps = math.max(2, math.floor(rise / 0.8))
	for i = 1, steps do
		local t = (i - 0.5) / steps
		local pos = bottom + dir * (run * t) + Vector3.new(0, rise * t + 0.02, 0)
		P(m, "StepLip", Vector3.new(width, 0.1, 0.25), CFrame.lookAt(pos, pos + dir), Mat.Metal, Col.Hazard, DECOR)
	end
	local side = dir:Cross(Vector3.new(0, 1, 0)).Unit
	for _, s in { -1, 1 } do
		local off = side * (s * (width / 2 - 0.1))
		local a = bottom + off + Vector3.new(0, 3.5, 0)
		local b = top + off + Vector3.new(0, 3.5, 0)
		Kit.Cylinder(m, "Handrail", a, b, 0.25, Mat.Metal, Col.Hazard, DECOR)
	end
	return m
end

-- Leiter (TrussPart = kletterbar)
function Props.Ladder(parent: Instance, base: Vector3, height: number, facing: Vector3): BasePart
	local cf = CFrame.lookAt(base + Vector3.new(0, height / 2, 0), base + Vector3.new(0, height / 2, 0) + facing)
	local truss = P(parent, "Ladder", Vector3.new(2, height, 2), cf, Mat.Metal, Col.Hazard, { Class = "TrussPart" })
	return truss
end

----------------------------------------------------------------------
-- Hero-Props
----------------------------------------------------------------------
-- Ölofen (Lobby): flackerndes oranges PointLight, Glut, Rauchrohr
function Props.Stove(parent: Instance, cf: CFrame, lightColor: Color3): Model
	local m = Kit.Model(parent, "OilStove_PH")
	m:AddTag("LobbyStove")
	local body = P(m, "Body", Vector3.new(4.5, 3.6, 3.6), cf * CFrame.new(0, 2.2, 0), Mat.RustSteel, Color3.fromRGB(45, 40, 38), {})
	body:SetAttribute("HeatKind", "Stove")
	P(m, "Base", Vector3.new(5, 0.6, 4), cf * CFrame.new(0, 0.3, 0), Mat.Metal, Col.Black, SMALL)
	P(m, "Top", Vector3.new(4.8, 0.4, 3.9), cf * CFrame.new(0, 4.2, 0), Mat.Metal, Color3.fromRGB(35, 32, 30), SMALL)
	P(m, "Door", Vector3.new(2.4, 1.6, 0.2), cf * CFrame.new(0, 2.1, -1.85), Mat.Metal, Col.Black, DECOR)
	local window = P(m, "FireWindow", Vector3.new(2, 1.1, 0.1), cf * CFrame.new(0, 2.1, -1.97), Mat.Neon, Color3.fromRGB(255, 120, 30), DECOR)
	window:SetAttribute("Flicker", true)
	local glow = P(m, "Glow", Vector3.new(1.8, 0.9, 1.2), cf * CFrame.new(0, 2.0, -1.1), Mat.Neon, Color3.fromRGB(255, 90, 20), DECOR)
	glow.Transparency = 0.2
	local lightPart = Kit.Volume(m, "LightSource", cf * CFrame.new(0, 2.4, -3), Vector3.new(0.5, 0.5, 0.5))
	local light = Kit.GlowLight(lightPart, lightColor, 32, 2.2, true)
	light.Name = "StoveLight"
	lightPart:AddTag("StoveLight")
	lightPart:SetAttribute("BaseBrightness", 2.2)
	-- Rauchrohr
	Kit.Cylinder(m, "Flue", cf * Vector3.new(0, 4.4, 0.8), cf * Vector3.new(0, 13.5, 0.8), 1.2, Mat.RustSteel, Color3.fromRGB(50, 45, 42), DECOR)
	-- Glut-Funken
	Kit.Emitter(window, "Embers", {
		Texture = Kit.Tex.Sparkle,
		Color = Color3.fromRGB(255, 140, 40),
		Size0 = 0.15,
		Size1 = 0.05,
		Transparency0 = 0,
		Transparency1 = 1,
		Lifetime = NumberRange.new(0.6, 1.2),
		Rate = 6,
		Speed = NumberRange.new(1, 2),
		Spread = Vector2.new(30, 30),
		Acceleration = Vector3.new(0, 2, 0),
		LightEmission = 1,
		EmissionDirection = Enum.NormalId.Front,
	})
	return m
end

-- CRT-Terminal (Pult mit gewölbtem Bildschirm). Gibt Modell und Bildschirm-Teil zurück.
function Props.Terminal(parent: Instance, cf: CFrame, name: string, color: Color3, text: string): (Model, BasePart, TextLabel)
	local m = Kit.Model(parent, name)
	P(m, "Desk", Vector3.new(4, 3, 2.4), cf * CFrame.new(0, 1.5, 0), Mat.FrostMetal, Col.FrostDark, SMALL)
	P(m, "Keyboard", Vector3.new(2.6, 0.2, 0.9), cf * CFrame.new(0, 3.1, -0.6) * CFrame.Angles(math.rad(8), 0, 0), Mat.Metal, Color3.fromRGB(150, 145, 130), DECOR)
	P(m, "Case", Vector3.new(3, 2.6, 2.4), cf * CFrame.new(0, 4.5, 0.3), Mat.Metal, Color3.fromRGB(165, 160, 140), SMALL)
	P(m, "Bezel", Vector3.new(2.9, 2.5, 0.2), cf * CFrame.new(0, 4.5, -0.95), Mat.Metal, Color3.fromRGB(120, 115, 100), DECOR)
	local screen = P(m, "Screen", Vector3.new(2.3, 1.8, 0.1), cf * CFrame.new(0, 4.6, -1.06), Mat.Glass, Color3.fromRGB(10, 25, 15), DECOR)
	local label = Kit.Screen(screen, Enum.NormalId.Front, Vector2.new(460, 360), color, text)
	local glowPart = Kit.Volume(m, "ScreenGlow", cf * CFrame.new(0, 4.6, -1.8), Vector3.new(0.3, 0.3, 0.3))
	local l = Kit.GlowLight(glowPart, color, 8, 0.6)
	l.Name = "ScreenLight"
	local interact = Kit.Volume(m, "Interact", cf * CFrame.new(0, 3.5, -1.4), Vector3.new(3, 2, 0.6))
	interact:SetAttribute("Interact", true)
	return m, screen, label
end

-- Heizkörper mit Handkurbel (Not-Radiator, Kantine)
function Props.Radiator(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Radiator_PH")
	m:AddTag("Radiator")
	local body = P(m, "Body", Vector3.new(6, 3.5, 1), cf * CFrame.new(0, 2.25, 0), Mat.RustSteel, Color3.fromRGB(120, 100, 85), {})
	body:SetAttribute("HeatKind", "Radiator")
	for i = -5, 5 do
		P(m, "Fin", Vector3.new(0.25, 3.3, 1.3), cf * CFrame.new(i * 0.5, 2.25, 0), Mat.RustSteel, Color3.fromRGB(110, 90, 75), DECOR)
	end
	local coil = P(m, "Coil", Vector3.new(5.4, 0.3, 0.2), cf * CFrame.new(0, 3.6, -0.6), Mat.Neon, Color3.fromRGB(60, 30, 20), DECOR)
	coil:SetAttribute("Glow", true)
	P(m, "CrankBox", Vector3.new(1.4, 1.4, 1.2), cf * CFrame.new(3.8, 2.4, 0), Mat.Metal, Col.FrostDark, SMALL)
	local crank = P(m, "Crank", Vector3.new(0.25, 1.6, 0.25), cf * CFrame.new(3.8, 2.4, -0.8), Mat.Metal, Col.Hazard, DECOR)
	crank:SetAttribute("BaseCF", crank.CFrame)
	local interact = Kit.Volume(m, "Interact", cf * CFrame.new(3.8, 2.6, -1.2), Vector3.new(1.6, 2, 0.6))
	interact:SetAttribute("Interact", true)
	local heatPos = Kit.Volume(m, "HeatCenter", cf * CFrame.new(0, 2, -2), Vector3.new(1, 1, 1))
	local l = Kit.GlowLight(heatPos, Color3.fromRGB(255, 120, 50), 10, 0)
	l.Name = "HeatGlow"
	return m
end

-- Sicherungskasten mit 2 Sockeln und Haupthebel
function Props.FuseBox(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "FuseBox_PH")
	m:AddTag("FuseBox")
	P(m, "Box", Vector3.new(5, 6, 1.2), cf * CFrame.new(0, 4, 0), Mat.FrostMetal, Col.FrostDark, SMALL)
	P(m, "Label", Vector3.new(4, 0.8, 0.1), cf * CFrame.new(0, 6.5, -0.65), Mat.Metal, Col.Hazard, DECOR)
	for i = 1, 2 do
		local x = (i - 1.5) * 2
		P(m, "SocketFrame" .. i, Vector3.new(1.4, 2.2, 0.3), cf * CFrame.new(x, 4.2, -0.7), Mat.Metal, Col.Black, DECOR)
		local ind = P(m, "Socket" .. i, Vector3.new(0.6, 0.6, 0.1), cf * CFrame.new(x, 5.6, -0.72), Mat.Neon, Color3.fromRGB(120, 10, 10), DECOR)
		ind:SetAttribute("Indicator", true)
		local fuse = P(m, "Fuse" .. i, Vector3.new(0.3, 1.4, 0.3), cf * CFrame.new(x, 4.2, -0.9), Mat.Glass, Color3.fromRGB(220, 230, 240), { Small = true, CanCollide = false, Transparency = 1 })
		fuse:SetAttribute("FuseVisual", true)
		local interact = Kit.Volume(m, "SocketInteract" .. i, cf * CFrame.new(x, 4.2, -1.1), Vector3.new(1.4, 2.2, 0.4))
		interact:SetAttribute("Socket", i)
	end
	-- Haupthebel rechts daneben
	P(m, "LeverBase", Vector3.new(1.4, 2.4, 1), cf * CFrame.new(4, 3.4, 0), Mat.Metal, Col.RustDark, SMALL)
	local lever = P(m, "Lever", Vector3.new(0.3, 2.2, 0.3), cf * CFrame.new(4, 4.2, -0.6) * CFrame.Angles(math.rad(-35), 0, 0), Mat.Metal, Col.Hazard, DECOR)
	lever:SetAttribute("UpCF", lever.CFrame)
	lever:SetAttribute("DownCF", cf * CFrame.new(4, 2.6, -0.6) * CFrame.Angles(math.rad(35), 0, 0))
	local li = Kit.Volume(m, "LeverInteract", cf * CFrame.new(4, 3.6, -1.1), Vector3.new(1.4, 2.4, 0.4))
	li:SetAttribute("Interact", true)
	return m
end

-- EKG-Monitor (piept schneller, wenn das Wesen nah ist)
function Props.EkgMonitor(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "EkgMonitor")
	m:AddTag("EkgMonitor")
	P(m, "Stand", Vector3.new(0.3, 4, 0.3), cf * CFrame.new(0, 2, 0), Mat.Metal, Col.FrostDark, SMALL)
	P(m, "Case", Vector3.new(2, 1.5, 1.2), cf * CFrame.new(0, 4.6, 0), Mat.Metal, Color3.fromRGB(170, 170, 160), SMALL)
	local screen = P(m, "Screen", Vector3.new(1.6, 1.1, 0.05), cf * CFrame.new(0, 4.6, -0.62), Mat.Neon, Color3.fromRGB(20, 120, 50), DECOR)
	screen:SetAttribute("EkgScreen", true)
	local l = Kit.GlowLight(screen, Color3.fromRGB(60, 255, 120), 6, 0.4)
	l.Name = "EkgLight"
	return m
end

-- Funkgerät (diegetische Warnung)
function Props.Radio(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Radio")
	m:AddTag("Radio")
	P(m, "Body", Vector3.new(1.8, 1, 0.8), cf * CFrame.new(0, 0.5, 0), Mat.Metal, Color3.fromRGB(70, 75, 60), SMALL)
	P(m, "Antenna", Vector3.new(0.08, 1.6, 0.08), cf * CFrame.new(0.7, 1.6, 0) * CFrame.Angles(0, 0, math.rad(-15)), Mat.Metal, Col.Black, DECOR)
	local led = P(m, "Led", Vector3.new(0.15, 0.15, 0.05), cf * CFrame.new(-0.6, 0.7, -0.42), Mat.Neon, Color3.fromRGB(40, 255, 60), DECOR)
	led:SetAttribute("RadioLed", true)
	return m
end

-- Kryo-Tank (zerbrochen, grün leuchtende Flüssigkeit)
function Props.CryoTank(parent: Instance, cf: CFrame, broken: boolean, color: Color3): Model
	local m = Kit.Model(parent, "CryoTank_PH")
	P(m, "Base", Vector3.new(4.4, 1, 4.4), cf * CFrame.new(0, 0.5, 0), Mat.Metal, Col.FrostDark, {})
	P(m, "Cap", Vector3.new(4.4, 1, 4.4), cf * CFrame.new(0, 9.5, 0), Mat.Metal, Col.FrostDark, {})
	local fluidH = if broken then 2.5 else 7
	local fluid = P(m, "Fluid", Vector3.new(fluidH, 3.4, 3.4), cf * CFrame.new(0, 1 + fluidH / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Mat.Neon, color, { Shape = Enum.PartType.Cylinder, Small = true, CanCollide = false })
	fluid.Transparency = 0.35
	local glass = P(m, "Glass", Vector3.new(8, 4, 4), cf * CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)), Mat.Glass, Col.Ice, { Shape = Enum.PartType.Cylinder })
	glass.Transparency = if broken then 0.85 else 0.65
	if broken then
		glass.CanCollide = true
		-- Scherben am Boden
		for i = 1, 6 do
			local a = math.rad(i * 60)
			P(m, "Shard", Vector3.new(0.9, 0.08, 0.6), cf * CFrame.new(math.cos(a) * 3.2, 0.06, math.sin(a) * 3.2) * CFrame.Angles(0, a, 0), Mat.Glass, Col.Ice, DECOR)
		end
		local puddle = P(m, "Puddle", Vector3.new(0.1, 7, 7), cf * CFrame.new(0, 0.05, -1) * CFrame.Angles(0, 0, math.rad(90)), Mat.Neon, color, { Shape = Enum.PartType.Cylinder, Small = true, CanCollide = false })
		puddle.Transparency = 0.6
	end
	for _, a in { 0, 90, 180, 270 } do
		P(m, "Strut", Vector3.new(0.4, 8, 0.4), cf * CFrame.Angles(0, math.rad(a), 0) * CFrame.new(2.1, 5, 0), Mat.Metal, Col.FrostDark, DECOR)
	end
	local light = Kit.GlowLight(fluid, color, 16, 1.2)
	light.Name = "TankLight"
	return m
end

-- Kryo-Schrank (Phiolen-Versteck)
function Props.CryoCabinet(parent: Instance, cf: CFrame, index: number): Model
	local m = Kit.Model(parent, "CryoCabinet_" .. index)
	m:AddTag("CryoCabinet")
	m:SetAttribute("Index", index)
	P(m, "Body", Vector3.new(3, 5, 2.2), cf * CFrame.new(0, 2.5, 0), Mat.FrostMetal, Col.Frost, {})
	local door = P(m, "Door", Vector3.new(2.7, 4.6, 0.15), cf * CFrame.new(0, 2.6, -1.15), Mat.Glass, Col.Ice, { Small = true })
	door.Transparency = 0.4
	door:SetAttribute("ClosedCF", door.CFrame)
	door:SetAttribute("OpenCF", cf * CFrame.new(-1.35, 2.6, -1.15) * CFrame.Angles(0, math.rad(-95), 0) * CFrame.new(1.35, 0, 0))
	P(m, "Frost", Vector3.new(2.5, 4.4, 0.05), cf * CFrame.new(0, 2.6, -1.25), Mat.IceSheet, Col.Ice, { Small = true, CanCollide = false, Transparency = 0.55 })
	for i = 0, 2 do
		P(m, "Rack", Vector3.new(2.6, 0.12, 1.8), cf * CFrame.new(0, 1 + i * 1.4, 0), Mat.Metal, Col.FrostDark, DECOR)
	end
	local led = P(m, "Led", Vector3.new(0.3, 0.2, 0.05), cf * CFrame.new(1, 4.8, -1.15), Mat.Neon, Color3.fromRGB(60, 160, 255), DECOR)
	led:SetAttribute("CabinetLed", true)
	local interact = Kit.Volume(m, "Interact", cf * CFrame.new(0, 2.6, -1.5), Vector3.new(2.8, 4, 0.5))
	interact:SetAttribute("Interact", true)
	Kit.Marker(m, "ItemPoint", cf * CFrame.new(0, 2.5, -0.2), "CabinetItemPoint")
	return m
end

-- Whiteboard im Büro der Chef-Wissenschaftlerin (zeigt die Phiolen-Reihenfolge)
function Props.Whiteboard(parent: Instance, cf: CFrame): (Model, TextLabel)
	local m = Kit.Model(parent, "Whiteboard")
	m:AddTag("Whiteboard")
	P(m, "Frame", Vector3.new(8.4, 4.4, 0.3), cf * CFrame.new(0, 5.5, 0), Mat.Metal, Col.FrostDark, SMALL)
	local board = P(m, "Board", Vector3.new(8, 4, 0.1), cf * CFrame.new(0, 5.5, -0.2), Mat.Foil, Color3.fromRGB(235, 238, 240), DECOR)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(800, 400)
	gui.LightInfluence = 1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, -40, 1, -40)
	label.Position = UDim2.fromOffset(20, 20)
	label.BackgroundTransparency = 1
	label.FontFace = Font.fromEnum(Enum.Font.PermanentMarker)
	label.TextColor3 = Color3.fromRGB(30, 40, 120)
	label.TextSize = 40
	label.TextWrapped = true
	label.RichText = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = "CENTRIFUGE LOAD ORDER:\n???"
	label.Parent = gui
	P(m, "Tray", Vector3.new(6, 0.2, 0.5), cf * CFrame.new(0, 3.2, -0.3), Mat.Metal, Col.FrostDark, DECOR)
	return m, label
end

-- Zentrifuge mit 3 Einsätzen und Terminal
function Props.Centrifuge(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Centrifuge_PH")
	m:AddTag("Centrifuge")
	P(m, "Base", Vector3.new(7, 2.4, 7), cf * CFrame.new(0, 1.2, 0), Mat.FrostMetal, Col.Frost, {})
	P(m, "Housing", Vector3.new(2.4, 6.4, 6.4), cf * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Mat.FrostMetal, Col.FrostDark, { Shape = Enum.PartType.Cylinder })
	local lid = P(m, "Lid", Vector3.new(0.4, 6, 6), cf * CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)), Mat.Glass, Col.Ice, { Shape = Enum.PartType.Cylinder, Small = true })
	lid.Transparency = 0.5
	local rotor = P(m, "Rotor", Vector3.new(0.4, 5, 0.6), cf * CFrame.new(0, 4.6, 0), Mat.Metal, Col.Black, DECOR)
	rotor:SetAttribute("BaseCF", rotor.CFrame)
	for i = 1, 3 do
		local a = math.rad((i - 1) * 120)
		local slot = P(m, "Slot" .. i, Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(math.cos(a) * 1.8, 4.9, math.sin(a) * 1.8), Mat.Neon, Color3.fromRGB(40, 40, 40), DECOR)
		slot:SetAttribute("SlotIndex", i)
	end
	local status = P(m, "StatusLight", Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(0, 7, 0), Mat.Neon, Color3.fromRGB(40, 120, 40), { Small = true, CanCollide = false, Shape = Enum.PartType.Ball })
	status:SetAttribute("Status", true)
	local _t, screen, _l = Props.Terminal(m, cf * CFrame.new(-6.5, 0, -1), "CentrifugeTerminal", Color3.fromRGB(80, 255, 120), "CENTRIFUGE CF-9\n> AWAITING SAMPLES")
	screen:SetAttribute("CentrifugeScreen", true)
	Kit.Marker(m, "KeycardPoint", cf * CFrame.new(3.6, 2.6, -2.6), "KeycardPoint")
	Kit.Marker(m, "EjectPoint", cf * CFrame.new(0, 1, -4.5), "CentrifugeEject")
	return m
end

-- Kartenleser neben einer Panzertür
function Props.KeycardReader(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "KeycardReader")
	m:AddTag("KeycardReader")
	P(m, "Body", Vector3.new(1.2, 1.8, 0.4), cf * CFrame.new(0, 4.5, 0), Mat.Metal, Col.FrostDark, SMALL)
	local led = P(m, "Led", Vector3.new(0.8, 0.25, 0.1), cf * CFrame.new(0, 5.1, -0.22), Mat.Neon, Color3.fromRGB(255, 30, 30), DECOR)
	led:SetAttribute("ReaderLed", true)
	P(m, "Slot", Vector3.new(0.8, 0.1, 0.12), cf * CFrame.new(0, 4.3, -0.22), Mat.Metal, Col.Black, DECOR)
	local interact = Kit.Volume(m, "Interact", cf * CFrame.new(0, 4.5, -0.5), Vector3.new(1.4, 2, 0.5))
	interact:SetAttribute("Interact", true)
	return m
end

-- Schiffscontainer
function Props.Container(parent: Instance, cf: CFrame, color: Color3, open: boolean?): Model
	local m = Kit.Model(parent, "Container")
	local L, W, H = 24, 8, 8.5
	P(m, "Floor", Vector3.new(W, 0.5, L), cf * CFrame.new(0, 0.25, 0), Mat.RustSteel, color, { Thermal = true })
	P(m, "Roof", Vector3.new(W, 0.5, L), cf * CFrame.new(0, H - 0.25, 0), Mat.RustSteel, color, { Thermal = true })
	P(m, "SideA", Vector3.new(0.4, H, L), cf * CFrame.new(-W / 2 + 0.2, H / 2, 0), Mat.RustSteel, color, { Thermal = true })
	P(m, "SideB", Vector3.new(0.4, H, L), cf * CFrame.new(W / 2 - 0.2, H / 2, 0), Mat.RustSteel, color, { Thermal = true })
	P(m, "Back", Vector3.new(W, H, 0.4), cf * CFrame.new(0, H / 2, L / 2 - 0.2), Mat.RustSteel, color, { Thermal = true })
	if not open then
		P(m, "Front", Vector3.new(W, H, 0.4), cf * CFrame.new(0, H / 2, -L / 2 + 0.2), Mat.RustSteel, color, { Thermal = true })
	else
		P(m, "DoorL", Vector3.new(W / 2, H - 0.6, 0.3), cf * CFrame.new(-W / 2 - 1.8, H / 2, -L / 2 - 1.9) * CFrame.Angles(0, math.rad(-80), 0), Mat.RustSteel, color, {})
	end
	for i = -5, 5 do
		P(m, "Rib", Vector3.new(W + 0.2, H - 0.4, 0.25), cf * CFrame.new(0, H / 2, i * 2.1), Mat.RustSteel, color:Lerp(Color3.new(0, 0, 0), 0.25), DECOR)
	end
	return m
end

-- Gabelstapler
function Props.Forklift(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Forklift_PH")
	local y = Color3.fromRGB(200, 150, 30)
	P(m, "Body", Vector3.new(4, 3, 6), cf * CFrame.new(0, 2.2, 0), Mat.Metal, y, {})
	P(m, "Counterweight", Vector3.new(4, 2.4, 1.5), cf * CFrame.new(0, 2.2, 3.4), Mat.Metal, Col.Black, {})
	P(m, "Seat", Vector3.new(1.6, 0.4, 1.4), cf * CFrame.new(0, 3.9, 0.8), Mat.Leather, Col.Black, DECOR)
	for _, s in { -1, 1 } do
		P(m, "CagePost", Vector3.new(0.25, 4, 0.25), cf * CFrame.new(s * 1.8, 5.7, -0.5), Mat.Metal, Col.Black, DECOR)
		P(m, "CagePostB", Vector3.new(0.25, 4, 0.25), cf * CFrame.new(s * 1.8, 5.7, 2), Mat.Metal, Col.Black, DECOR)
		P(m, "Mast", Vector3.new(0.4, 9, 0.5), cf * CFrame.new(s * 1.3, 4.5, -3.2), Mat.Metal, Col.FrostDark, SMALL)
		P(m, "Fork", Vector3.new(0.4, 0.25, 4), cf * CFrame.new(s * 1, 0.6, -5.2), Mat.Metal, Col.FrostDark, SMALL)
		for _, z in { -1.8, 2 } do
			P(m, "Wheel", Vector3.new(0.9, 2, 2), cf * CFrame.new(s * 2.1, 1, z) * CFrame.Angles(0, 0, 0), Mat.Rubber, Col.Black, { Shape = Enum.PartType.Cylinder, Small = true })
		end
	end
	P(m, "CageTop", Vector3.new(3.9, 0.25, 2.8), cf * CFrame.new(0, 7.7, 0.75), Mat.Metal, Col.Black, DECOR)
	return m
end

-- Diesel-Generator (Zone 3) mit Interaktions-Punkten
function Props.Generator(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Generator_PH")
	m:AddTag("Generator")
	local body = P(m, "Body", Vector3.new(10, 6, 5), cf * CFrame.new(0, 3.5, 0), Mat.RustSteel, Color3.fromRGB(70, 90, 60), {})
	body:SetAttribute("HeatKind", "Generator")
	P(m, "Skid", Vector3.new(11, 0.6, 6), cf * CFrame.new(0, 0.3, 0), Mat.Metal, Col.Black, SMALL)
	P(m, "Engine", Vector3.new(4, 3, 4.6), cf * CFrame.new(-2, 7.6, 0), Mat.Metal, Color3.fromRGB(55, 70, 48), SMALL)
	P(m, "Tank", Vector3.new(5, 2.2, 2.2), cf * CFrame.new(2.5, 7.2, 0) * CFrame.Angles(0, 0, 0), Mat.Metal, Color3.fromRGB(150, 40, 30), { Shape = Enum.PartType.Cylinder, Small = true })
	local exhaust = P(m, "Exhaust", Vector3.new(0.9, 5, 0.9), cf * CFrame.new(-3.5, 10.5, 1.5), Mat.RustSteel, Col.RustDark, DECOR)
	Kit.Emitter(exhaust, "Smoke", {
		Color = Color3.fromRGB(40, 40, 40),
		Size0 = 1,
		Size1 = 5,
		Transparency0 = 0.4,
		Transparency1 = 1,
		Lifetime = NumberRange.new(2, 3),
		Rate = 10,
		Speed = NumberRange.new(4, 6),
		Spread = Vector2.new(10, 10),
		Enabled = false,
	})
	for i = -2, 2 do
		P(m, "Vent", Vector3.new(0.3, 4, 0.1), cf * CFrame.new(i * 0.9 + 1, 3.5, -2.55), Mat.Metal, Col.Black, DECOR)
	end
	-- Einfüllstutzen
	P(m, "FuelCap", Vector3.new(0.8, 0.6, 0.8), cf * CFrame.new(4.4, 8.5, 0), Mat.Metal, Col.Hazard, DECOR)
	local fuelInteract = Kit.Volume(m, "FuelInteract", cf * CFrame.new(5.5, 4, 0), Vector3.new(1, 3, 3))
	fuelInteract:SetAttribute("Interact", true)
	-- Anlasser mit Zeiger-Anzeige
	P(m, "Panel", Vector3.new(3, 2.4, 0.3), cf * CFrame.new(-1, 4.5, -2.65), Mat.Metal, Col.FrostDark, DECOR)
	local gauge = P(m, "Gauge", Vector3.new(1.6, 1.6, 0.1), cf * CFrame.new(-1.6, 4.7, -2.85), Mat.Foil, Col.White, DECOR)
	gauge:SetAttribute("Gauge", true)
	local needle = P(m, "Needle", Vector3.new(0.08, 0.7, 0.05), cf * CFrame.new(-1.6, 5.0, -2.92), Mat.Metal, Col.Danger, DECOR)
	needle:SetAttribute("BaseCF", cf * CFrame.new(-1.6, 4.7, -2.92))
	local startInteract = Kit.Volume(m, "StartInteract", cf * CFrame.new(-1, 4.5, -3.2), Vector3.new(3, 2.4, 0.5))
	startInteract:SetAttribute("Interact", true)
	local status = P(m, "StatusLight", Vector3.new(0.5, 0.5, 0.5), cf * CFrame.new(0.5, 5.3, -2.85), Mat.Neon, Color3.fromRGB(120, 20, 20), { Small = true, CanCollide = false, Shape = Enum.PartType.Ball })
	status:SetAttribute("Status", true)
	return m
end

-- Heizstrahler (Zone 3, an mit Generator)
function Props.Heater(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Heater_PH")
	m:AddTag("Heater")
	P(m, "Stand", Vector3.new(0.4, 6, 0.4), cf * CFrame.new(0, 3, 0), Mat.Metal, Col.FrostDark, SMALL)
	P(m, "Foot", Vector3.new(3, 0.3, 3), cf * CFrame.new(0, 0.15, 0), Mat.Metal, Col.Black, SMALL)
	P(m, "Head", Vector3.new(3.2, 2.2, 1.2), cf * CFrame.new(0, 6.6, 0) * CFrame.Angles(math.rad(-20), 0, 0), Mat.Metal, Col.RustDark, SMALL)
	local grill = P(m, "Grill", Vector3.new(2.8, 1.8, 0.1), cf * CFrame.new(0, 6.4, -0.65) * CFrame.Angles(math.rad(-20), 0, 0), Mat.Neon, Color3.fromRGB(50, 20, 10), DECOR)
	grill:SetAttribute("Glow", true)
	local heat = Kit.Volume(m, "HeatCenter", cf * CFrame.new(0, 3, -2), Vector3.new(1, 1, 1))
	heat:SetAttribute("HeatKind", "Heater")
	local l = Kit.GlowLight(grill, Color3.fromRGB(255, 120, 40), 18, 0)
	l.Name = "HeaterLight"
	return m
end

-- Flutlicht (Zone 3, an mit Generator)
function Props.Floodlight(parent: Instance, cf: CFrame): BasePart
	P(parent, "FloodHousing", Vector3.new(3, 2, 1.4), cf, Mat.Metal, Col.Black, DECOR)
	local lens = P(parent, "FloodLens", Vector3.new(2.6, 1.6, 0.1), cf * CFrame.new(0, 0, -0.72), Mat.Glass, Color3.fromRGB(60, 50, 40), DECOR)
	local s = Instance.new("SpotLight")
	s.Angle = 75
	s.Range = 60
	s.Brightness = 0
	s.Color = Color3.fromRGB(255, 200, 150)
	s.Face = Enum.NormalId.Front
	s.Shadows = false
	s.Enabled = false
	s.Parent = lens
	lens:SetAttribute("BaseBrightness", 2.5)
	lens:AddTag("GeneratorLight")
	return lens
end

-- Reaktorkern (Zone 4)
function Props.ReactorCore(parent: Instance, center: Vector3, color: Color3): Model
	local m = Kit.Model(parent, "ReactorCore_PH")
	local cf = CFrame.new(center)
	local up = CFrame.Angles(0, 0, math.rad(90))
	P(m, "Pedestal", Vector3.new(4, 16, 16), cf * CFrame.new(0, 2, 0) * up, Mat.Metal, Col.FrostDark, { Shape = Enum.PartType.Cylinder, Thermal = true })
	local core = P(m, "Core", Vector3.new(28, 9, 9), cf * CFrame.new(0, 18, 0) * up, Mat.Neon, color, { Shape = Enum.PartType.Cylinder })
	core:SetAttribute("ReactorCore", true)
	P(m, "Shell", Vector3.new(30, 11, 11), cf * CFrame.new(0, 18, 0) * up, Mat.Glass, Color3.fromRGB(255, 200, 160), { Shape = Enum.PartType.Cylinder, Transparency = 0.7 })
	for i = 0, 5 do
		local a = math.rad(i * 60)
		P(m, "Rib", Vector3.new(1, 30, 1), cf * CFrame.new(math.cos(a) * 5.8, 18, math.sin(a) * 5.8), Mat.Metal, Col.Black, SMALL)
	end
	for i = 0, 3 do
		P(m, "Ring", Vector3.new(1, 13, 13), cf * CFrame.new(0, 6 + i * 8, 0) * up, Mat.Metal, Col.RustDark, { Shape = Enum.PartType.Cylinder, Small = true })
	end
	local light = Kit.GlowLight(core, color, 60, 3, false)
	light.Name = "CoreLight"
	Kit.Emitter(core, "Heat", {
		Texture = Kit.Tex.Sparkle,
		Color = Color3.fromRGB(255, 160, 80),
		Size0 = 0.4,
		Size1 = 0.1,
		Transparency0 = 0.2,
		Transparency1 = 1,
		Lifetime = NumberRange.new(1, 2),
		Rate = 15,
		Speed = NumberRange.new(2, 4),
		Spread = Vector2.new(180, 180),
		LightEmission = 1,
	})
	return m
end

-- Kontrollstab mit Kurbel
function Props.ControlRod(parent: Instance, cf: CFrame, index: number): Model
	local m = Kit.Model(parent, "ControlRod_" .. index)
	m:AddTag("ControlRod")
	m:SetAttribute("Index", index)
	P(m, "Housing", Vector3.new(4, 3, 4), cf * CFrame.new(0, 1.5, 0), Mat.Metal, Col.FrostDark, {})
	local rod = P(m, "Rod", Vector3.new(14, 1.6, 1.6), cf * CFrame.new(0, 10, 0) * CFrame.Angles(0, 0, math.rad(90)), Mat.Metal, Col.Hazard, { Shape = Enum.PartType.Cylinder, Small = true })
	rod:SetAttribute("UpCF", rod.CFrame)
	rod:SetAttribute("DownCF", cf * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(90)))
	P(m, "Guide", Vector3.new(0.4, 16, 0.4), cf * CFrame.new(1.4, 9, 1.4), Mat.Metal, Col.Black, DECOR)
	P(m, "GuideB", Vector3.new(0.4, 16, 0.4), cf * CFrame.new(-1.4, 9, 1.4), Mat.Metal, Col.Black, DECOR)
	local crank = P(m, "Crank", Vector3.new(0.3, 2, 0.3), cf * CFrame.new(0, 2.6, -2.4), Mat.Metal, Col.Hazard, DECOR)
	crank:SetAttribute("BaseCF", crank.CFrame)
	local led = P(m, "Led", Vector3.new(0.6, 0.6, 0.1), cf * CFrame.new(0, 2.2, -2.05), Mat.Neon, Color3.fromRGB(255, 30, 30), DECOR)
	led:SetAttribute("RodLed", true)
	local interact = Kit.Volume(m, "Interact", cf * CFrame.new(0, 2.6, -2.8), Vector3.new(2.4, 2.4, 0.6))
	interact:SetAttribute("Interact", true)
	Kit.Sign(m, cf * CFrame.new(0, 4, -2.05), Vector2.new(2.6, 0.7), "ROD " .. index)
	return m
end

-- Dampfventil (Zone 4): cf = Düsenposition, LookVector = Dampfrichtung.
-- Rohr läuft nach hinten in die Wand / den Boden. Dampf-Volumen liegt vor der Düse.
function Props.SteamVent(parent: Instance, cf: CFrame, index: number): Model
	local m = Kit.Model(parent, "SteamVent_" .. index)
	m:AddTag("SteamVent")
	m:SetAttribute("Index", index)
	Kit.Cylinder(m, "Pipe", (cf * CFrame.new(0, 0, 3.5)).Position, (cf * CFrame.new(0, 0, 0.3)).Position, 1.4, Mat.RustSteel, Col.Pipe, SMALL)
	P(m, "Wheel", Vector3.new(0.2, 1.6, 1.6), cf * CFrame.new(0, 1.1, 1.6) * CFrame.Angles(0, 0, math.rad(90)), Mat.Metal, Col.Danger, { Shape = Enum.PartType.Cylinder, Small = true, CanCollide = false })
	local nozzle = P(m, "Nozzle", Vector3.new(1.0, 1.0, 0.6), cf, Mat.Metal, Col.Black, DECOR)
	Kit.Emitter(nozzle, "Steam", {
		Color = Color3.fromRGB(240, 240, 245),
		Size0 = 2,
		Size1 = 9,
		Transparency0 = 0.35,
		Transparency1 = 1,
		Lifetime = NumberRange.new(1.5, 2.5),
		Rate = 30,
		Speed = NumberRange.new(6, 10),
		Spread = Vector2.new(20, 20),
		Drag = 1.2,
		Enabled = false,
		EmissionDirection = Enum.NormalId.Front,
	})
	local vol = Kit.Volume(m, "SteamVolume", cf * CFrame.new(0, 0, -5), Vector3.new(9, 10, 10))
	vol:SetAttribute("SteamVolume", true)
	vol:SetAttribute("HeatKind", "SteamVent")
	return m
end

-- Gelbe Rundumleuchte
function Props.Beacon(parent: Instance, cf: CFrame, color: Color3): BasePart
	P(parent, "BeaconBase", Vector3.new(1.2, 0.5, 1.2), cf, Mat.Metal, Col.Black, DECOR)
	local dome = P(parent, "BeaconDome", Vector3.new(1, 1, 1), cf * CFrame.new(0, 0.7, 0), Mat.Glass, color, { Small = true, CanCollide = false, Shape = Enum.PartType.Ball, Transparency = 0.3 })
	local s = Instance.new("SpotLight")
	s.Color = color
	s.Range = 28
	s.Angle = 45
	s.Brightness = 0
	s.Face = Enum.NormalId.Front
	s.Enabled = false
	s.Parent = dome
	dome:AddTag("CountdownBeacon")
	dome:SetAttribute("BaseCF", dome.CFrame)
	return dome
end

-- Trainings-Puppe im Thermoanzug
function Props.Dummy(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "TrainingDummy_PH")
	m:AddTag("TrainingDummy")
	local suit = Color3.fromRGB(200, 90, 30)
	P(m, "Stand", Vector3.new(2.4, 0.4, 2.4), cf * CFrame.new(0, 0.2, 0), Mat.Metal, Col.Black, SMALL)
	P(m, "Pole", Vector3.new(0.3, 2, 0.3), cf * CFrame.new(0, 1.4, 0), Mat.Metal, Col.FrostDark, SMALL)
	P(m, "Legs", Vector3.new(1.8, 2.2, 1), cf * CFrame.new(0, 3.3, 0), Mat.Fabric, suit, SMALL)
	P(m, "Torso", Vector3.new(2.2, 2.4, 1.2), cf * CFrame.new(0, 5.6, 0), Mat.Fabric, suit, SMALL)
	P(m, "ArmL", Vector3.new(0.8, 2.4, 0.8), cf * CFrame.new(-1.5, 5.4, 0), Mat.Fabric, suit, SMALL)
	P(m, "ArmR", Vector3.new(0.8, 2.4, 0.8), cf * CFrame.new(1.5, 5.4, 0), Mat.Fabric, suit, SMALL)
	P(m, "Hood", Vector3.new(1.5, 1.5, 1.5), cf * CFrame.new(0, 7.5, 0), Mat.Fabric, suit, { Small = true, Shape = Enum.PartType.Ball })
	P(m, "Visor", Vector3.new(1.1, 0.6, 0.2), cf * CFrame.new(0, 7.5, -0.7), Mat.Glass, Col.Black, DECOR)
	-- Wärmesignatur-Leuchtstreifen
	P(m, "SigStrip", Vector3.new(2.25, 0.3, 1.25), cf * CFrame.new(0, 5.6, 0), Mat.Neon, Color3.fromRGB(255, 120, 40), DECOR)
	return m
end

-- Helikopter
function Props.Helicopter(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Helicopter_PH")
	m:AddTag("Helicopter")
	local body = Color3.fromRGB(60, 70, 60)
	P(m, "Cabin", Vector3.new(8, 7, 16), cf * CFrame.new(0, 5.5, 0), Mat.Metal, body, { Thermal = true })
	P(m, "Nose", Vector3.new(7.6, 5, 4), cf * CFrame.new(0, 4.8, -9.5), Mat.Glass, Color3.fromRGB(40, 60, 70), { Transparency = 0.3 })
	P(m, "Tail", Vector3.new(2, 2.2, 18), cf * CFrame.new(0, 7.5, 16), Mat.Metal, body, {})
	P(m, "Fin", Vector3.new(0.4, 5, 3), cf * CFrame.new(0, 9.5, 24), Mat.Metal, body, SMALL)
	P(m, "Engine", Vector3.new(5, 2.4, 8), cf * CFrame.new(0, 10.2, 1), Mat.Metal, Color3.fromRGB(45, 50, 45), SMALL)
	P(m, "Mast", Vector3.new(0.8, 2, 0.8), cf * CFrame.new(0, 12.2, 0), Mat.Metal, Col.Black, SMALL)
	local rotor = P(m, "Rotor", Vector3.new(44, 0.25, 1.4), cf * CFrame.new(0, 13.3, 0), Mat.Metal, Col.Black, DECOR)
	rotor:SetAttribute("BaseCF", rotor.CFrame)
	local rotor2 = P(m, "Rotor2", Vector3.new(1.4, 0.25, 44), cf * CFrame.new(0, 13.3, 0), Mat.Metal, Col.Black, DECOR)
	rotor2:SetAttribute("BaseCF", rotor2.CFrame)
	local tailRotor = P(m, "TailRotor", Vector3.new(0.2, 6, 0.8), cf * CFrame.new(1.2, 9, 24), Mat.Metal, Col.Black, DECOR)
	tailRotor:SetAttribute("BaseCF", tailRotor.CFrame)
	for _, s in { -1, 1 } do
		P(m, "Skid", Vector3.new(0.5, 0.5, 16), cf * CFrame.new(s * 3.6, 0.25, -1), Mat.Metal, Col.Black, SMALL)
		P(m, "SkidStrut", Vector3.new(0.4, 2.2, 0.4), cf * CFrame.new(s * 3.6, 1.4, -4), Mat.Metal, Col.Black, DECOR)
		P(m, "SkidStrutB", Vector3.new(0.4, 2.2, 0.4), cf * CFrame.new(s * 3.6, 1.4, 3), Mat.Metal, Col.Black, DECOR)
	end
	local door = P(m, "DoorOpening", Vector3.new(0.2, 5, 5), cf * CFrame.new(-4.1, 5, 0), Mat.Metal, Col.Black, DECOR)
	door:SetAttribute("HeliDoor", true)
	local interact = Kit.Volume(m, "Interact", cf * CFrame.new(-5, 4.5, 0), Vector3.new(1.5, 4, 5))
	interact:SetAttribute("Interact", true)
	local light = P(m, "Searchlight", Vector3.new(1, 1, 1), cf * CFrame.new(0, 2.4, -10), Mat.Neon, Color3.fromRGB(255, 250, 230), { Small = true, CanCollide = false, Shape = Enum.PartType.Ball })
	local sl = Instance.new("SpotLight")
	sl.Range = 60
	sl.Angle = 40
	sl.Brightness = 3
	sl.Face = Enum.NormalId.Front
	sl.Parent = light
	local nav = P(m, "NavLight", Vector3.new(0.5, 0.5, 0.5), cf * CFrame.new(0, 10, 25), Mat.Neon, Color3.fromRGB(255, 20, 20), { Small = true, CanCollide = false, Shape = Enum.PartType.Ball })
	nav:SetAttribute("Blink", true)
	Kit.Marker(m, "SeatPoint", cf * CFrame.new(0, 3.5, 2), "HeliSeat")
	return m
end

-- Organische, gefrorene Wucherungen (Nest)
function Props.Growth(parent: Instance, center: Vector3, size: number, rng: Kit.Rng)
	local base = CFrame.new(center) * CFrame.Angles(rng:Range(-0.4, 0.4), rng:Range(0, math.pi * 2), rng:Range(-0.4, 0.4))
	Kit.Ball(parent, "Growth", base.Position, size, Mat.Glacier, Col.Organic, { Small = true })
	for i = 1, 4 do
		local off = Vector3.new(rng:Range(-1, 1), rng:Range(-0.2, 1), rng:Range(-1, 1)) * size * 0.45
		local s = size * rng:Range(0.35, 0.6)
		local b = Kit.Ball(parent, "Nodule", base.Position + off, s, if i % 2 == 0 then Mat.Glacier else Mat.IceSheet, if i % 2 == 0 then Col.Organic else Color3.fromRGB(150, 60, 70), DECOR)
		b.Transparency = if i % 2 == 0 then 0 else 0.25
	end
	local vein = Kit.Ball(parent, "Vein", base.Position + Vector3.new(0, size * 0.2, 0), size * 0.3, Mat.Neon, Color3.fromRGB(120, 200, 255), DECOR)
	vein.Transparency = 0.4
	vein:SetAttribute("Pulse", true)
end

-- Gefrorene Blutspur am Boden
function Props.BloodTrail(parent: Instance, a: Vector3, b: Vector3, rng: Kit.Rng)
	local dir = b - a
	local n = math.max(2, math.floor(dir.Magnitude / 1.6))
	for i = 0, n do
		local p = a + dir * (i / n) + Vector3.new(rng:Range(-0.4, 0.4), 0.03, rng:Range(-0.4, 0.4))
		local s = rng:Range(0.4, 1.2)
		Kit.Part(parent, "FrozenBlood", Vector3.new(0.05, s, s * rng:Range(0.7, 1.4)), CFrame.new(p) * CFrame.Angles(0, rng:Range(0, 6.28), math.rad(90)), Mat.IceSheet, Col.Blood, { Small = true, CanCollide = false, CanQuery = false, Shape = Enum.PartType.Cylinder })
	end
end

-- Eiszapfen an der Decke
function Props.Icicles(parent: Instance, origin: Vector3, count: number, spreadX: number, spreadZ: number, rng: Kit.Rng)
	for _ = 1, count do
		local p = origin + Vector3.new(rng:Range(-spreadX, spreadX), 0, rng:Range(-spreadZ, spreadZ))
		local len = rng:Range(0.8, 2.6)
		local cf = CFrame.new(p - Vector3.new(0, len / 2, 0)) * CFrame.Angles(math.rad(180), 0, 0)
		Kit.Part(parent, "Icicle", Vector3.new(0.35, len, 0.35), cf, Mat.IceSheet, Col.Ice, { Small = true, CanCollide = false, Class = "WedgePart", Transparency = 0.2 })
	end
end

return Props
