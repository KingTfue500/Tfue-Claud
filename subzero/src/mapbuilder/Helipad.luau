--!strict
-- Helikopter-Landeplatz im Schneesturm (Extraktion). Die Wartungsleiter aus Zone 4
-- endet unter der Luke am Westrand des Decks.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Mat, Col = Kit.Mat, Kit.Col

local Helipad = {}

export type Ctx = { Map: Model, Volumes: Model, Config: any, Rng: Kit.Rng }

function Helipad.Build(ctx: Ctx)
	local S: Vector3 = ctx.Config.Map.StationOrigin
	local function V(x: number, y: number, z: number): Vector3
		return S + Vector3.new(x, y, z)
	end
	local z = Kit.ZoneFolders(ctx.Map, "Helipad")
	local rng = ctx.Rng

	-- Schneeboden um die Station (mit Löchern für Luken- und Leiterschacht)
	Kit.SlabWithHoles(z.Geometry, "SnowGround", S.X + 320, S.Z + 42, S.X + 520, S.Z + 180, S.Y - 3, S.Y - 0.5, {
		{ S.X + 359, S.Z + 99, S.X + 401, S.Z + 121 },
		{ S.X + 429, S.Z + 104, S.X + 436, S.Z + 110 },
	}, Mat.Snow, Col.Snow, { Thermal = true, Surface = "Snow" })
	for _ = 1, 18 do
		local p = V(rng:Range(325, 515), -1, rng:Range(46, 176))
		local inDeck = p.X > S.X + 426 and p.X < S.X + 502 and p.Z > S.Z + 72 and p.Z < S.Z + 148
		local inHole = p.X > S.X + 352 and p.X < S.X + 408 and p.Z > S.Z + 92 and p.Z < S.Z + 128
		if not inDeck and not inHole then
			local h = rng:Range(1.5, 5)
			Kit.Part(z.Geometry, "SnowDrift", Vector3.new(rng:Range(6, 14), h, rng:Range(5, 10)), CFrame.new(p + Vector3.new(0, h / 2 - 0.5, 0)) * CFrame.Angles(0, rng:Range(0, 3), math.rad(rng:Range(-8, 8))), Mat.Snow, Col.Snow, { Small = true, Surface = "Snow" })
		end
	end

	-- Deck
	local deck = Kit.Model(z.Geometry, "HelipadDeck")
	Kit.SlabWithHoles(deck, "Deck", S.X + 430, S.Z + 76, S.X + 498, S.Z + 144, S.Y - 1, S.Y, {
		{ S.X + 430, S.Z + 105, S.X + 435, S.Z + 109 },
	}, Mat.SaltConcrete, Color3.fromRGB(70, 72, 76), { Thermal = true, Surface = "Concrete" })
	-- Markierungen (H und Kreis)
	local hc = V(468, 0.02, 110)
	Kit.Part(deck, "MarkH1", Vector3.new(2, 0.04, 14), CFrame.new(hc + Vector3.new(-4, 0, 0)), Mat.Metal, Col.Hazard, { Small = true, CanCollide = false, CanQuery = false })
	Kit.Part(deck, "MarkH2", Vector3.new(2, 0.04, 14), CFrame.new(hc + Vector3.new(4, 0, 0)), Mat.Metal, Col.Hazard, { Small = true, CanCollide = false, CanQuery = false })
	Kit.Part(deck, "MarkH3", Vector3.new(6, 0.04, 2), CFrame.new(hc), Mat.Metal, Col.Hazard, { Small = true, CanCollide = false, CanQuery = false })
	for i = 0, 23 do
		local a = math.rad(i * 15)
		Kit.Part(deck, "MarkCircle", Vector3.new(1.2, 0.04, 6), CFrame.new(hc + Vector3.new(math.cos(a) * 22, 0, math.sin(a) * 22)) * CFrame.Angles(0, -a, 0), Mat.Metal, Col.White, { Small = true, CanCollide = false, CanQuery = false })
	end
	-- Randlichter und Geländer
	for i = 0, 15 do
		local t = i / 16
		local p: Vector3
		if t < 0.25 then
			p = V(430.6 + t * 4 * 66.8, 0.3, 76.6)
		elseif t < 0.5 then
			p = V(497.4, 0.3, 76.6 + (t - 0.25) * 4 * 66.8)
		elseif t < 0.75 then
			p = V(497.4 - (t - 0.5) * 4 * 66.8, 0.3, 143.4)
		else
			p = V(430.6, 0.3, 143.4 - (t - 0.75) * 4 * 66.8)
		end
		local lamp = Kit.Part(deck, "EdgeLight", Vector3.new(0.6, 0.6, 0.6), CFrame.new(p), Mat.Neon, Color3.fromRGB(80, 160, 255), { Small = true, CanCollide = false, Shape = Enum.PartType.Ball })
		lamp:SetAttribute("Blink", true)
		if i % 4 == 0 then
			Kit.GlowLight(lamp, Color3.fromRGB(80, 160, 255), 14, 0.8)
		end
	end
	Props.Railing(deck, V(430, 0, 76.2), V(498, 0, 76.2), 3.6)
	Props.Railing(deck, V(497.8, 0, 76), V(497.8, 0, 144), 3.6)
	Props.Railing(deck, V(498, 0, 143.8), V(430, 0, 143.8), 3.6)
	Props.Railing(deck, V(430.2, 0, 144), V(430.2, 0, 76), 3.6)

	-- Helikopter
	Props.Helicopter(z.Props, CFrame.new(V(470, 0, 106)))
	-- Wartungskasten mit Luke (Austritt des Wesens)
	Kit.Box(z.Props, "ServiceBox", V(489, 0, 133), V(496, 5, 141), Mat.RustSteel, Col.FrostDark, { Thermal = true })
	Kit.Vent(z.Props, "HP_Service", Kit.Face(V(489, 2.2, 137), Vector3.new(-1, 0, 0)), "Helipad")
	-- Windsack-Mast
	Props.Pipe(z.Props, V(494, 0, 80), V(494, 12, 80), 0.4, Col.White)
	Kit.Part(z.Props, "Windsock", Vector3.new(4, 1.2, 1.2), CFrame.new(V(496, 11.5, 80)) * CFrame.Angles(0, 0, math.rad(-12)), Mat.Fabric, Color3.fromRGB(255, 120, 30), { Small = true, CanCollide = false, Shape = Enum.PartType.Cylinder })
	Kit.Sign(z.Props, Kit.Face(V(433, 3.2, 100), Vector3.new(1, 0, 0)), Vector2.new(5, 0.8), "EREBOS HELIPAD", Col.Hazard)

	-- Schneesturm
	local storm = Kit.Volume(z.Volumes, "Snowstorm", CFrame.new(V(464, 26, 110)), Vector3.new(90, 2, 90))
	local snow = Kit.Emitter(storm, "Snow", {
		Texture = Kit.Tex.Sparkle,
		Color = Color3.fromRGB(235, 240, 255),
		Size0 = 0.35,
		Size1 = 0.2,
		Transparency0 = 0.1,
		Transparency1 = 0.4,
		Lifetime = NumberRange.new(2.5, 3.5),
		Rate = 420,
		Speed = NumberRange.new(10, 16),
		Spread = Vector2.new(25, 25),
		Acceleration = Vector3.new(22, -6, 4),
		EmissionDirection = Enum.NormalId.Bottom,
		Shape = Enum.ParticleEmitterShape.Box,
	})
	snow:AddTag("AmbientEmitter")
	local gust = Kit.Emitter(storm, "Gust", {
		Color = Color3.fromRGB(205, 220, 240),
		Size0 = 8,
		Size1 = 16,
		Transparency0 = 0.82,
		Transparency1 = 1,
		Lifetime = NumberRange.new(2, 3),
		Rate = 14,
		Speed = NumberRange.new(4, 8),
		Acceleration = Vector3.new(24, -4, 0),
		EmissionDirection = Enum.NormalId.Bottom,
		Shape = Enum.ParticleEmitterShape.Box,
	})
	gust:AddTag("AmbientEmitter")
	Kit.GroundFog(z.Volumes, V(464, 1, 110), Vector3.new(70, 1, 70), Color3.fromRGB(220, 230, 245), 6)
	local sky = Kit.Volume(z.Lights, "StormSky", CFrame.new(V(464, 40, 110)), Vector3.new(1, 1, 1))
	Kit.GlowLight(sky, Color3.fromRGB(150, 175, 215), 60, 0.8)

	-- Wegpunkte, Raserei-Punkt, Volumen
	local wps = { V(440, 0, 90), V(440, 0, 130), V(458, 0, 86), V(486, 0, 92), V(486, 0, 128), V(456, 0, 134) }
	for i, p in wps do
		Kit.Waypoint(z.Waypoints, p, "Helipad", i)
	end
	Kit.Marker(z.Props, "FrenzyPoint", CFrame.new(V(450, 3, 110)), "FrenzyPoint", { Zone = "Helipad" })
	Kit.Marker(z.Props, "HeliCam", CFrame.lookAt(V(440, 14, 160), V(470, 6, 106)), "CinematicCam", { CamId = "Victory" })
	Kit.BoxVolume(ctx.Volumes, "Zone_Helipad", V(420, -3, 66), V(510, 50, 154), { ZoneId = "Helipad", Priority = 1 })
end

return Helipad
