-- Builds the whole map out of parts and terrain when the server starts:
-- a lobby chapel, a foggy graveyard, the manor (six rooms + hallway) and the back garden with the exit gate.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local Y0 = 0.5 -- top of the manor floor
local WALL_H = 16
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local C = {
	WoodDark = Color3.fromRGB(36, 24, 18),
	Wood = Color3.fromRGB(64, 42, 28),
	WoodLight = Color3.fromRGB(92, 64, 42),
	Wallpaper = Color3.fromRGB(58, 40, 47),
	Brick = Color3.fromRGB(56, 50, 48),
	Stone = Color3.fromRGB(72, 70, 68),
	StoneDark = Color3.fromRGB(44, 44, 46),
	Iron = Color3.fromRGB(26, 26, 28),
	Blood = Color3.fromRGB(96, 6, 6),
	Flame = Color3.fromRGB(255, 150, 60),
	Bone = Color3.fromRGB(205, 198, 180),
	Pale = Color3.fromRGB(215, 212, 205),
	Fabric = Color3.fromRGB(72, 16, 22),
	Gold = Color3.fromRGB(205, 160, 60),
	Black = Color3.fromRGB(10, 10, 12),
}

local BOOK_COLORS = {
	Color3.fromRGB(90, 20, 20),
	Color3.fromRGB(30, 50, 35),
	Color3.fromRGB(40, 35, 70),
	Color3.fromRGB(80, 60, 30),
	Color3.fromRGB(50, 40, 35),
	Color3.fromRGB(25, 25, 30),
}

local rng = Random.new(666)
local root: Folder -- everything gets parented here
local map -- the table returned by build()

----------------------------------------------------------------------------------------------------
-- Part helpers
----------------------------------------------------------------------------------------------------

local function box(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, parent: Instance?, props: { [string]: any }?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent or root
	return p
end

local function ball(diameter: number, pos: Vector3, color: Color3, material: Enum.Material?, parent: Instance?)
	local p = box(Vector3.one * diameter, CFrame.new(pos), color, material, parent)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Vertical cylinder standing on `bottom`.
local function cyl(diameter: number, height: number, bottom: Vector3, color: Color3, material: Enum.Material?, parent: Instance?)
	local p = box(
		Vector3.new(height, diameter, diameter),
		CFrame.new(bottom + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material,
		parent
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function folder(name: string, parent: Instance?)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or root
	return f
end

local function model(name: string, parent: Instance?)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or root
	return m
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
	b.Anchored = false
	b.Massless = true
	b.CanCollide = false
end

local function noCollide(inst: Instance)
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
		end
	end
end

local function sound(id: string, parent: Instance, volume: number, looped: boolean?, maxDistance: number?)
	if id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Looped = looped or false
	s.RollOffMaxDistance = maxDistance or 80
	s.Parent = parent
	return s
end

----------------------------------------------------------------------------------------------------
-- Lights
----------------------------------------------------------------------------------------------------

local function light(parent: BasePart, color: Color3, brightness: number, range: number, shadows: boolean?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = shadows ~= false
	l.Parent = parent
	parent:SetAttribute("BaseBrightness", brightness)
	CollectionService:AddTag(parent, "FlickerLight")
	return l
end

local function candle(pos: Vector3, parent: Instance?, withLight: boolean?)
	local m = model("Candle", parent)
	local height = rng:NextNumber(0.8, 1.6)
	cyl(0.35, height, pos, C.Bone, Enum.Material.SmoothPlastic, m)
	local flame = ball(0.28, pos + Vector3.new(0, height + 0.18, 0), C.Flame, Enum.Material.Neon, m)
	flame.Size = Vector3.new(0.2, 0.36, 0.2)
	if withLight ~= false then
		light(flame, C.Flame, 0.9, 9)
	end
	noCollide(m)
	return m
end

local function wallSconce(pos: Vector3, facing: Vector3, parent: Instance?)
	local m = model("Sconce", parent)
	local cf = CFrame.lookAt(pos, pos + facing)
	box(Vector3.new(0.6, 1.2, 0.3), cf, C.Iron, Enum.Material.Metal, m)
	box(Vector3.new(0.3, 0.2, 1), cf * CFrame.new(0, -0.5, -0.5), C.Iron, Enum.Material.Metal, m)
	local base = cf * CFrame.new(0, -0.4, -1)
	cyl(0.3, 0.9, base.Position, C.Bone, Enum.Material.SmoothPlastic, m)
	local flame = ball(0.25, base.Position + Vector3.new(0, 1.05, 0), C.Flame, Enum.Material.Neon, m)
	flame.Size = Vector3.new(0.2, 0.35, 0.2)
	light(flame, C.Flame, 1, 14)
	noCollide(m)
	return m
end

local function hangingLamp(pos: Vector3, parent: Instance?, brightness: number?, range: number?)
	local m = model("HangingLamp", parent)
	local top = Vector3.new(pos.X, Y0 + WALL_H - 0.5, pos.Z)
	local chainLen = top.Y - pos.Y
	cyl(0.12, chainLen, pos, C.Iron, Enum.Material.Metal, m)
	box(Vector3.new(1.2, 1.4, 1.2), CFrame.new(pos - Vector3.new(0, 0.6, 0)), C.Iron, Enum.Material.Metal, m, { Transparency = 0.2 })
	local bulb = ball(0.6, pos - Vector3.new(0, 0.7, 0), Color3.fromRGB(255, 190, 120), Enum.Material.Neon, m)
	light(bulb, Color3.fromRGB(255, 180, 110), brightness or 0.8, range or 20)
	noCollide(m)
	m.WorldPivot = CFrame.new(top)
	m:SetAttribute("Amp", 3)
	m:SetAttribute("Speed", 0.8)
	CollectionService:AddTag(m, "Swing")
	return m
end

----------------------------------------------------------------------------------------------------
-- Walls, windows and doors
----------------------------------------------------------------------------------------------------

type Opening = { at: number, width: number, top: number, bottom: number?, glass: boolean? }

local function wallSegment(cf: CFrame, x1: number, x2: number, y1: number, y2: number, thick: number, style: string, parent: Instance)
	if x2 - x1 < 0.05 or y2 - y1 < 0.05 then
		return
	end
	local function piece(a: number, b: number, color: Color3, material: Enum.Material)
		if b - a < 0.05 then
			return
		end
		box(Vector3.new(x2 - x1, b - a, thick), cf * CFrame.new((x1 + x2) / 2, (a + b) / 2, 0), color, material, parent)
	end
	if style == "interior" then
		-- dark wood panelling below, faded wallpaper above
		local split = 4.5
		piece(y1, math.min(y2, split), C.Wood, Enum.Material.WoodPlanks)
		piece(math.max(y1, split), y2, C.Wallpaper, Enum.Material.Fabric)
	elseif style == "exterior" then
		piece(y1, y2, C.Brick, Enum.Material.Brick)
	else
		piece(y1, y2, C.StoneDark, Enum.Material.Cobblestone)
	end
end

-- Builds a straight wall along cf's local X axis, cutting holes for doors and windows.
-- Opening offsets are in local X relative to the wall's centre.
local function buildWall(cf: CFrame, length: number, height: number, thick: number, openings: { any }, style: string, parent: Instance)
	table.sort(openings, function(a, b)
		return a.offset < b.offset
	end)
	local x = -length / 2
	for _, o in openings do
		local a, b = o.offset - o.width / 2, o.offset + o.width / 2
		local bottom = o.bottom or 0
		wallSegment(cf, x, a, 0, height, thick, style, parent)
		wallSegment(cf, a, b, o.top, height, thick, style, parent)
		wallSegment(cf, a, b, 0, bottom, thick, style, parent)
		if o.glass then
			local mid = cf * CFrame.new(o.offset, (bottom + o.top) / 2, 0)
			box(Vector3.new(o.width, o.top - bottom, 0.15), mid, Color3.fromRGB(30, 40, 55), Enum.Material.Glass, parent, {
				Transparency = 0.55,
				Reflectance = 0.15,
			})
			box(Vector3.new(0.25, o.top - bottom, thick + 0.2), mid, C.WoodDark, Enum.Material.Wood, parent)
			box(Vector3.new(o.width, 0.25, thick + 0.2), mid, C.WoodDark, Enum.Material.Wood, parent)
			box(Vector3.new(o.width + 0.6, 0.4, thick + 0.8), cf * CFrame.new(o.offset, bottom, 0), C.WoodDark, Enum.Material.Wood, parent)
		end
		x = b
	end
	wallSegment(cf, x, length / 2, 0, height, thick, style, parent)
end

-- Wall running along world X at a fixed Z. Returns a function giving the CFrame of a point on the wall.
local function wallX(z: number, x1: number, x2: number, height: number, thick: number, openings: { Opening }, style: string, parent: Instance)
	local mid = (x1 + x2) / 2
	local cf = CFrame.new(mid, 0, z)
	local ops = {}
	for _, o in openings do
		table.insert(ops, { offset = o.at - mid, width = o.width, top = o.top, bottom = o.bottom, glass = o.glass })
	end
	buildWall(cf, x2 - x1, height, thick, ops, style, parent)
	return function(at: number)
		return CFrame.new(at, 0, z)
	end
end

-- Wall running along world Z at a fixed X. Its local X axis points toward world -Z.
local function wallZ(x: number, z1: number, z2: number, height: number, thick: number, openings: { Opening }, style: string, parent: Instance)
	local mid = (z1 + z2) / 2
	local cf = CFrame.new(x, 0, mid) * CFrame.Angles(0, math.pi / 2, 0)
	local ops = {}
	for _, o in openings do
		table.insert(ops, { offset = mid - o.at, width = o.width, top = o.top, bottom = o.bottom, glass = o.glass })
	end
	buildWall(cf, math.abs(z2 - z1), height, thick, ops, style, parent)
	return function(at: number)
		return CFrame.new(x, 0, at) * CFrame.Angles(0, math.pi / 2, 0)
	end
end

export type Door = {
	panel: BasePart,
	closed: CFrame,
	open: CFrame,
	isOpen: boolean,
	prompt: ProximityPrompt?,
	creak: Sound?,
	slam: Sound?,
}

function MapBuilder.setDoor(door: Door, open: boolean, fast: boolean?)
	if door.isOpen == open then
		return
	end
	door.isOpen = open
	local info = TweenInfo.new(fast and 0.22 or 0.9, fast and Enum.EasingStyle.Back or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(door.panel, info, { CFrame = open and door.open or door.closed }):Play()
	local s = fast and door.slam or door.creak
	if s then
		s:Play()
	end
	if door.prompt then
		door.prompt.ActionText = open and "Close" or "Open"
	end
end

-- `cf` is the bottom-centre of the doorway with local X running along the wall.
-- hinge = -1 hinges on the local -X edge, 1 on the +X edge. The door always swings toward local -Z.
local function makeDoor(cf: CFrame, width: number, height: number, hinge: number, parent: Instance, withPrompt: boolean): Door
	local panelCF = cf * CFrame.new(0, height / 2, 0)
	local panel = box(Vector3.new(width - 0.15, height - 0.1, 0.4), panelCF, C.Wood, Enum.Material.WoodPlanks, parent)
	panel.Name = "Door"
	for _, side in { -1, 1 } do
		for _, y in { -height * 0.22, height * 0.22 } do
			local inset = box(
				Vector3.new(width * 0.6, height * 0.32, 0.12),
				panelCF * CFrame.new(0, y, side * 0.24),
				C.WoodDark,
				Enum.Material.Wood,
				parent
			)
			weld(panel, inset)
		end
		local knob = ball(0.45, (panelCF * CFrame.new(-hinge * (width / 2 - 0.7), -0.6, side * 0.35)).Position, C.Gold, Enum.Material.Metal, parent)
		weld(panel, knob)
	end
	-- Let the monster path straight through closed doors; it bursts them open when it gets close.
	local modifier = Instance.new("PathfindingModifier")
	modifier.PassThrough = true
	modifier.Parent = panel

	local hingeCF = cf * CFrame.new(hinge * width / 2, height / 2, 0)
	local angle = math.rad(100) * -hinge
	local door: Door = {
		panel = panel,
		closed = panelCF,
		open = hingeCF * CFrame.Angles(0, angle, 0) * hingeCF:Inverse() * panelCF,
		isOpen = false,
		creak = sound(Config.Sounds.DoorCreak, panel, 0.8),
		slam = sound(Config.Sounds.DoorSlam, panel, 1.2, false, 120),
	}
	if withPrompt then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open"
		prompt.ObjectText = "Door"
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = panel
		prompt.Triggered:Connect(function()
			MapBuilder.setDoor(door, not door.isOpen)
		end)
		door.prompt = prompt
	end
	return door
end

local function bloodText(cf: CFrame, size: Vector2, text: string, revealAt: number, parent: Instance)
	local p = box(Vector3.new(size.X, size.Y, 0.05), cf, C.Black, Enum.Material.SmoothPlastic, parent, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	p.Name = "BloodText"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.6
	gui.Enabled = revealAt <= 0
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Creepster
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = Color3.fromRGB(120, 0, 0)
	label.Rotation = rng:NextNumber(-4, 4)
	label.Parent = gui
	gui:SetAttribute("RevealAt", revealAt)
	table.insert(map.bloodTexts, gui)
	return gui
end

local function addKeySpot(room: string, pos: Vector3)
	table.insert(map.keySpots, { room = room, position = pos })
end

----------------------------------------------------------------------------------------------------
-- Props
----------------------------------------------------------------------------------------------------

local function table4(center: Vector3, size: Vector3, parent: Instance, color: Color3?)
	-- center = point on the floor under the middle of the table; size.Y = table height
	local m = model("Table", parent)
	local col = color or C.Wood
	box(Vector3.new(size.X, 0.4, size.Z), CFrame.new(center + Vector3.new(0, size.Y - 0.2, 0)), col, Enum.Material.Wood, m)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(
				Vector3.new(0.4, size.Y - 0.4, 0.4),
				CFrame.new(center + Vector3.new(sx * (size.X / 2 - 0.4), (size.Y - 0.4) / 2, sz * (size.Z / 2 - 0.4))),
				col,
				Enum.Material.Wood,
				m
			)
		end
	end
	return m
end

local function chair(pos: Vector3, facing: Vector3, parent: Instance, tall: boolean?)
	local m = model("Chair", parent)
	local cf = CFrame.lookAt(pos, pos + facing)
	box(Vector3.new(2, 0.3, 2), cf * CFrame.new(0, 2, 0), C.WoodDark, Enum.Material.Wood, m)
	box(Vector3.new(2, 0.2, 1.8), cf * CFrame.new(0, 2.2, 0), C.Fabric, Enum.Material.Fabric, m)
	local backH = tall and 5 or 3
	box(Vector3.new(2, backH, 0.3), cf * CFrame.new(0, 2 + backH / 2, 0.85), C.WoodDark, Enum.Material.Wood, m)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(Vector3.new(0.25, 2, 0.25), cf * CFrame.new(sx * 0.8, 1, sz * 0.8), C.WoodDark, Enum.Material.Wood, m)
		end
	end
	return m
end

local function bookshelf(cf: CFrame, length: number, height: number, twoSided: boolean, parent: Instance)
	-- cf = floor centre, shelf runs along local X
	local m = model("Bookshelf", parent)
	local depth = twoSided and 2.4 or 1.4
	box(Vector3.new(length, height, 0.3), cf * CFrame.new(0, height / 2, 0), C.WoodDark, Enum.Material.Wood, m)
	for _, sx in { -1, 1 } do
		box(Vector3.new(0.3, height, depth), cf * CFrame.new(sx * length / 2, height / 2, 0), C.WoodDark, Enum.Material.Wood, m)
	end
	local sides = twoSided and { -1, 1 } or { -1 }
	local shelfY = 0.4
	while shelfY < height - 1 do
		box(Vector3.new(length, 0.2, depth), cf * CFrame.new(0, shelfY, 0), C.Wood, Enum.Material.Wood, m)
		for _, side in sides do
			local x = -length / 2 + 0.3
			while x < length / 2 - 1 do
				local w = rng:NextNumber(0.4, 1.3)
				local h = rng:NextNumber(1.2, 1.9)
				if rng:NextNumber() > 0.08 then
					box(
						Vector3.new(w, h, 0.9),
						cf * CFrame.new(x + w / 2, shelfY + 0.1 + h / 2, side * 0.65) * CFrame.Angles(0, 0, rng:NextNumber(-0.06, 0.06)),
						BOOK_COLORS[rng:NextInteger(1, #BOOK_COLORS)],
						Enum.Material.Leather,
						m
					)
				end
				x += w + 0.05
			end
		end
		shelfY += 2.3
	end
	box(Vector3.new(length + 0.4, 0.3, depth + 0.3), cf * CFrame.new(0, height, 0), C.WoodDark, Enum.Material.Wood, m)
	return m
end

local function painting(cf: CFrame, size: Vector2, parent: Instance, creepy: boolean)
	-- cf = centre of the canvas, facing out of the wall (look vector = into the room)
	local m = model("Painting", parent)
	box(Vector3.new(size.X + 0.8, size.Y + 0.8, 0.25), cf, C.Gold, Enum.Material.Metal, m)
	local canvas = box(Vector3.new(size.X, size.Y, 0.1), cf * CFrame.new(0, 0, -0.15), Color3.fromRGB(28, 22, 20), Enum.Material.Fabric, m)
	if creepy then
		-- A pale portrait whose eyes glow when the lights go out.
		box(Vector3.new(size.X * 0.5, size.Y * 0.55, 0.05), canvas.CFrame * CFrame.new(0, size.Y * 0.08, -0.06), Color3.fromRGB(150, 140, 125), Enum.Material.SmoothPlastic, m)
		box(Vector3.new(size.X * 0.7, size.Y * 0.25, 0.05), canvas.CFrame * CFrame.new(0, -size.Y * 0.36, -0.06), Color3.fromRGB(20, 20, 20), Enum.Material.Fabric, m)
		for _, sx in { -1, 1 } do
			local eye = box(Vector3.new(0.22, 0.12, 0.05), canvas.CFrame * CFrame.new(sx * size.X * 0.1, size.Y * 0.14, -0.1), Color3.fromRGB(255, 0, 0), Enum.Material.Neon, m)
			eye.Transparency = 1
			CollectionService:AddTag(eye, "PortraitEye")
		end
	else
		for _ = 1, 3 do
			box(
				Vector3.new(size.X * rng:NextNumber(0.2, 0.6), size.Y * rng:NextNumber(0.2, 0.5), 0.05),
				canvas.CFrame * CFrame.new(rng:NextNumber(-0.2, 0.2) * size.X, rng:NextNumber(-0.2, 0.2) * size.Y, -0.06),
				Color3.fromRGB(rng:NextInteger(30, 70), rng:NextInteger(25, 50), rng:NextInteger(20, 40)),
				Enum.Material.Fabric,
				m
			)
		end
	end
	noCollide(m)
	return m
end

local function gravestone(pos: Vector3, parent: Instance)
	local m = model("Grave", parent)
	local cf = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.15, 0.15))
	local kind = rng:NextInteger(1, 3)
	if kind == 1 then
		box(Vector3.new(2.6, 3, 0.7), cf * CFrame.new(0, 1.2, 0), C.Stone, Enum.Material.Slate, m)
		local top = box(Vector3.new(0.7, 2.6, 2.6), cf * CFrame.new(0, 2.7, 0) * CFrame.Angles(0, math.pi / 2, 0), C.Stone, Enum.Material.Slate, m)
		top.Shape = Enum.PartType.Cylinder
	elseif kind == 2 then
		box(Vector3.new(0.6, 4.2, 0.6), cf * CFrame.new(0, 1.8, 0), C.Stone, Enum.Material.Slate, m)
		box(Vector3.new(2.4, 0.6, 0.6), cf * CFrame.new(0, 2.8, 0), C.Stone, Enum.Material.Slate, m)
	else
		box(Vector3.new(2, 2.2, 0.8), cf * CFrame.new(0, 0.9, 0), C.StoneDark, Enum.Material.Slate, m)
	end
	-- burial mound
	box(Vector3.new(2.6, 0.6, 5), CFrame.new(pos) * CFrame.new(0, -0.1, 3), Color3.fromRGB(40, 30, 22), Enum.Material.Mud, m)
	return m
end

local function deadTree(pos: Vector3, parent: Instance)
	local m = model("DeadTree", parent)
	local height = rng:NextNumber(14, 22)
	local trunk = cyl(rng:NextNumber(1.4, 2.2), height, pos - Vector3.new(0, 1, 0), Color3.fromRGB(34, 28, 24), Enum.Material.Wood, m)
	trunk.CFrame *= CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, 0)
	for i = 1, rng:NextInteger(4, 7) do
		local y = pos.Y + height * rng:NextNumber(0.45, 0.95)
		local len = rng:NextNumber(4, 9)
		local yaw = rng:NextNumber(0, math.pi * 2)
		local tilt = rng:NextNumber(0.5, 1.1)
		local dir = CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt, 0, 0)
		local start = Vector3.new(pos.X, y, pos.Z)
		local branchCF = CFrame.new(start) * dir * CFrame.new(0, len / 2, 0)
		box(Vector3.new(0.5 + 0.3 / i, len, 0.5 + 0.3 / i), branchCF, Color3.fromRGB(34, 28, 24), Enum.Material.Wood, m)
		local tip = (branchCF * CFrame.new(0, len / 2, 0)).Position
		box(Vector3.new(0.25, len * 0.5, 0.25), CFrame.new(tip) * CFrame.Angles(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * CFrame.new(0, len * 0.25, 0), Color3.fromRGB(34, 28, 24), Enum.Material.Wood, m)
	end
	return m
end

local function lanternPost(pos: Vector3, parent: Instance, color: Color3?)
	local m = model("LanternPost", parent)
	cyl(0.4, 9, pos, C.Iron, Enum.Material.Metal, m)
	box(Vector3.new(2, 0.3, 0.3), CFrame.new(pos + Vector3.new(0.8, 8.8, 0)), C.Iron, Enum.Material.Metal, m)
	local cage = box(Vector3.new(1.1, 1.5, 1.1), CFrame.new(pos + Vector3.new(1.6, 7.8, 0)), C.Iron, Enum.Material.Metal, m, { Transparency = 0.4 })
	local flame = ball(0.6, cage.Position, color or C.Flame, Enum.Material.Neon, m)
	light(flame, color or C.Flame, 1.2, 22)
	return m
end

local function fogEmitter(cf: CFrame, size: Vector3, parent: Instance, rate: number?)
	local p = box(size, cf, Color3.new(), Enum.Material.SmoothPlastic, parent, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	p.Name = "Fog"
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = rate or 5
	e.Lifetime = NumberRange.new(9, 14)
	e.Speed = NumberRange.new(0.3, 1.2)
	e.SpreadAngle = Vector2.new(180, 10)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-8, 8)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 16) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.82),
		NumberSequenceKeypoint.new(0.7, 0.86),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Color = ColorSequence.new(Color3.fromRGB(150, 160, 175))
	e.LightInfluence = 1
	e.Parent = p
	return p
end

local function dust(cf: CFrame, size: Vector3, parent: Instance)
	local p = box(size, cf, Color3.new(), Enum.Material.SmoothPlastic, parent, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	p.Name = "Dust"
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = 6
	e.Lifetime = NumberRange.new(6, 10)
	e.Speed = NumberRange.new(0.1, 0.4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(0.08)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.LightInfluence = 1
	e.Color = ColorSequence.new(Color3.fromRGB(230, 220, 200))
	e.Parent = p
end

-- A head that slowly turns to stare at the nearest player (animated on the client).
local function watcherHead(pos: Vector3, diameter: number, color: Color3, parent: Instance)
	local head = ball(diameter, pos, color, Enum.Material.SmoothPlastic, parent)
	head.Name = "WatcherHead"
	for _, sx in { -1, 1 } do
		local eye = ball(diameter * 0.2, (head.CFrame * CFrame.new(sx * diameter * 0.18, diameter * 0.08, -diameter * 0.42)).Position, C.Black, Enum.Material.SmoothPlastic, parent)
		weld(head, eye)
	end
	CollectionService:AddTag(head, "Watcher")
	return head
end

----------------------------------------------------------------------------------------------------
-- Areas
----------------------------------------------------------------------------------------------------

local function buildTerrain()
	local terrain = workspace.Terrain
	terrain:Clear()
	terrain:FillBlock(CFrame.new(0, -4, -38), Vector3.new(150, 8, 216), Enum.Material.Ground)
	for _ = 1, 18 do
		local x = rng:NextNumber(-58, 58)
		local z = rng:NextNumber(5, 58)
		if rng:NextNumber() < 0.5 then
			z = rng:NextNumber(-128, -84)
		end
		terrain:FillCylinder(CFrame.new(x, -0.5, z), 1, rng:NextNumber(3, 6), Enum.Material.Mud)
	end
	for _ = 1, 14 do
		terrain:FillCylinder(CFrame.new(rng:NextNumber(-58, 58), -0.5, rng:NextNumber(5, 58)), 1, rng:NextNumber(3, 5), Enum.Material.LeafyGrass)
	end
	-- foundation under the lobby chapel
	terrain:FillBlock(CFrame.new(0, -4, 140), Vector3.new(44, 8, 44), Enum.Material.Ground)
end

local function buildLobby()
	local f = folder("Lobby")
	local x1, x2, z1, z2, h = -18, 18, 122, 158, 18
	box(Vector3.new(36, 1, 36), CFrame.new(0, 0, 140), C.StoneDark, Enum.Material.Slate, f)
	box(Vector3.new(38, 1, 38), CFrame.new(0, h + 0.5, 140), C.WoodDark, Enum.Material.WoodPlanks, f)
	local windows = {}
	for _, z in { 130, 140, 150 } do
		table.insert(windows, { at = z, width = 3, top = 13, bottom = 5 })
	end
	wallZ(x1, z1, z2, h, 2, windows, "stone", f)
	wallZ(x2, z1, z2, h, 2, windows, "stone", f)
	wallX(z1, x1, x2, h, 2, {}, "stone", f)
	wallX(z2, x1, x2, h, 2, {}, "stone", f)
	-- stained glass
	local glassColors = { Color3.fromRGB(140, 10, 20), Color3.fromRGB(60, 10, 120), Color3.fromRGB(10, 60, 120) }
	for i, z in { 130, 140, 150 } do
		for _, x in { x1, x2 } do
			local g = box(Vector3.new(0.3, 8, 3), CFrame.new(x, 9, z), glassColors[i], Enum.Material.Neon, f, { Transparency = 0.35 })
			g.Name = "StainedGlass"
		end
	end
	-- pews
	for _, x in { -8, 8 } do
		for z = 132, 152, 5 do
			local pm = model("Pew", f)
			box(Vector3.new(10, 0.4, 2), CFrame.new(x, 2, z), C.WoodDark, Enum.Material.Wood, pm)
			box(Vector3.new(10, 3, 0.3), CFrame.new(x, 3.5, z + 1), C.WoodDark, Enum.Material.Wood, pm)
			for _, sx in { -4.6, 4.6 } do
				box(Vector3.new(0.3, 2, 2), CFrame.new(x + sx, 1, z), C.WoodDark, Enum.Material.Wood, pm)
			end
		end
	end
	-- altar
	box(Vector3.new(12, 1, 6), CFrame.new(0, 1, 126), C.Stone, Enum.Material.Marble, f)
	box(Vector3.new(8, 3, 3), CFrame.new(0, 3, 125), C.Stone, Enum.Material.Marble, f)
	box(Vector3.new(8.4, 0.2, 3.4), CFrame.new(0, 4.6, 125), C.Fabric, Enum.Material.Fabric, f)
	for i = -3, 3 do
		candle(Vector3.new(i * 1.1, 4.7, 125 + (i % 2) * 0.6), f, math.abs(i) % 3 == 0)
	end
	for _, pos in { Vector3.new(-14, 0.5, 125), Vector3.new(14, 0.5, 125), Vector3.new(-14, 0.5, 155), Vector3.new(14, 0.5, 155) } do
		cyl(1, 4, pos, C.Iron, Enum.Material.Metal, f)
		for _, o in { Vector3.new(-0.3, 4, 0), Vector3.new(0.3, 4, 0.2), Vector3.new(0, 4, -0.3) } do
			candle(pos + o, f, o.X == 0)
		end
	end
	local sign = box(Vector3.new(20, 5, 0.3), CFrame.new(0, 11, 123.2) * CFrame.Angles(0, math.pi, 0), C.Black, Enum.Material.SmoothPlastic, f)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Parent = sign
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 1)
	title.Font = Enum.Font.Creepster
	title.TextScaled = true
	title.Text = "THE HOLLOW MANOR"
	title.TextColor3 = Color3.fromRGB(170, 20, 20)
	title.Parent = gui
	dust(CFrame.new(0, 8, 140), Vector3.new(32, 14, 32), f)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.1, 150)
	spawn.Color = C.StoneDark
	spawn.Material = Enum.Material.Slate
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = f

	map.lobbyCFrame = CFrame.new(0, 4, 148)
end

local function buildFrontYard()
	local f = folder("Graveyard")
	-- boundary walls (front yard is x -60..60, z 0..60)
	wallZ(-61, 0, 62, 14, 2, {}, "stone", f)
	wallZ(61, 0, 62, 14, 2, {}, "stone", f)
	wallX(61, -62, 62, 14, 2, { { at = 0, width = 10, top = 12 } }, "stone", f)
	-- iron gate, rusted shut
	for x = -4.5, 4.5, 0.9 do
		box(Vector3.new(0.25, 12, 0.25), CFrame.new(x, 6, 61), C.Iron, Enum.Material.Metal, f)
	end
	box(Vector3.new(10, 0.4, 0.4), CFrame.new(0, 3, 61), C.Iron, Enum.Material.Metal, f)
	box(Vector3.new(10, 0.4, 0.4), CFrame.new(0, 9, 61), C.Iron, Enum.Material.Metal, f)
	for _, x in { -6, 6 } do
		box(Vector3.new(2.4, 16, 2.4), CFrame.new(x, 8, 61), C.Stone, Enum.Material.Cobblestone, f)
		ball(2.4, Vector3.new(x, 16.8, 61), C.Stone, Enum.Material.Cobblestone, f)
	end
	-- path to the door
	for z = 6, 58, 2.6 do
		box(Vector3.new(rng:NextNumber(4.5, 6), 0.3, 2.2), CFrame.new(rng:NextNumber(-0.3, 0.3), 0.05, z) * CFrame.Angles(0, rng:NextNumber(-0.08, 0.08), 0), C.Stone, Enum.Material.Slate, f)
	end
	-- graves
	local placed = 0
	local tries = 0
	while placed < 46 and tries < 400 do
		tries += 1
		local x = rng:NextNumber(-56, 56)
		local z = rng:NextNumber(10, 54)
		if math.abs(x) > 8 and not (x > 32 and z > 34) then
			gravestone(Vector3.new(x, 0, z), f)
			placed += 1
		end
	end
	for _, p in { Vector3.new(-45, 0, 14), Vector3.new(-22, 0, 48), Vector3.new(26, 0, 22), Vector3.new(52, 0, 10), Vector3.new(-52, 0, 40), Vector3.new(14, 0, 54) } do
		deadTree(p, f)
	end
	for _, z in { 16, 32, 48 } do
		lanternPost(Vector3.new(-5, 0, z), f)
		lanternPost(Vector3.new(5, 0, z + 6), f)
	end
	-- mausoleum in the far corner
	local mz = model("Mausoleum", f)
	box(Vector3.new(16, 1, 14), CFrame.new(46, 0.5, 46), C.Stone, Enum.Material.Marble, mz)
	box(Vector3.new(14, 10, 1), CFrame.new(46, 6, 52.5), C.Stone, Enum.Material.Marble, mz)
	box(Vector3.new(1, 10, 12), CFrame.new(39.5, 6, 47), C.Stone, Enum.Material.Marble, mz)
	box(Vector3.new(1, 10, 12), CFrame.new(52.5, 6, 47), C.Stone, Enum.Material.Marble, mz)
	box(Vector3.new(17, 1.2, 15), CFrame.new(46, 11.6, 46.5), C.StoneDark, Enum.Material.Marble, mz)
	for _, x in { 40, 44, 48, 52 } do
		cyl(1, 10, Vector3.new(x, 1, 40), C.Stone, Enum.Material.Marble, mz)
	end
	box(Vector3.new(4, 2, 7), CFrame.new(46, 2, 48), C.StoneDark, Enum.Material.Marble, mz) -- coffin
	candle(Vector3.new(44.5, 3, 46), mz)
	candle(Vector3.new(47.5, 3, 46), mz)
	addKeySpot("Mausoleum", Vector3.new(46, 3.6, 49))

	fogEmitter(CFrame.new(-30, 1, 30), Vector3.new(56, 1, 56), f, 7)
	fogEmitter(CFrame.new(30, 1, 30), Vector3.new(56, 1, 56), f, 7)
	-- tall invisible walls so nobody climbs out
	for _, data in {
		{ Vector3.new(2, 80, 64), Vector3.new(-62, 40, 30) },
		{ Vector3.new(2, 80, 64), Vector3.new(62, 40, 30) },
		{ Vector3.new(126, 80, 2), Vector3.new(0, 40, 62) },
	} do
		box(data[1], CFrame.new(data[2]), Color3.new(), Enum.Material.SmoothPlastic, f, { Transparency = 1, CanQuery = false })
	end

	map.startCFrame = CFrame.new(0, 3.5, 54)
	for _, p in { Vector3.new(0, Y0, 30), Vector3.new(-30, Y0, 20), Vector3.new(30, Y0, 40) } do
		table.insert(map.patrolPoints, p)
	end
end

local function buildManorShell()
	local f = folder("ManorShell")
	-- floor and ceiling
	box(Vector3.new(120, 0.5, 80), CFrame.new(0, 0.25, -40), C.Wood, Enum.Material.WoodPlanks, f)
	box(Vector3.new(124, 1, 84), CFrame.new(0, WALL_H + 0.5, -40), C.WoodDark, Enum.Material.Wood, f)
	-- gabled roof
	local rise, half = 14, 42
	local len = math.sqrt(rise * rise + half * half)
	local angle = math.atan2(rise, half)
	box(Vector3.new(126, 1, len), CFrame.new(0, WALL_H + 1 + rise / 2, -40 + half / 2) * CFrame.Angles(angle, 0, 0), Color3.fromRGB(30, 28, 32), Enum.Material.RoofShingles, f)
	box(Vector3.new(126, 1, len), CFrame.new(0, WALL_H + 1 + rise / 2, -40 - half / 2) * CFrame.Angles(-angle, 0, 0), Color3.fromRGB(30, 28, 32), Enum.Material.RoofShingles, f)
	for _, x in { -36, 30 } do
		box(Vector3.new(5, 14, 5), CFrame.new(x, WALL_H + 14, -30), C.Brick, Enum.Material.Brick, f)
	end

	local rows = { 0, -80 / 3, -160 / 3, -80 }
	local rowMid = { -40 / 3, -40, -200 / 3 }

	-- exterior walls with windows
	local frontWindows: { Opening } = {
		{ at = 0, width = 8, top = 11 },
		{ at = -44, width = 5, top = 11, bottom = 5, glass = true },
		{ at = -24, width = 5, top = 11, bottom = 5, glass = true },
		{ at = 24, width = 5, top = 11, bottom = 5, glass = true },
		{ at = 44, width = 5, top = 11, bottom = 5, glass = true },
	}
	local frontAt = wallX(0, -61, 61, WALL_H + 1, 2, frontWindows, "exterior", f)
	local backWindows: { Opening } = {
		{ at = 0, width = 8, top = 11 },
		{ at = -34, width = 5, top = 11, bottom = 5, glass = true },
		{ at = 34, width = 5, top = 11, bottom = 5, glass = true },
	}
	local backAt = wallX(-80, -61, 61, WALL_H + 1, 2, backWindows, "exterior", f)
	local sideWindows: { Opening } = {}
	for _, z in rowMid do
		table.insert(sideWindows, { at = z, width = 5, top = 11, bottom = 5, glass = true })
	end
	-- west side has the fireplace and bookshelves against it, so its windows sit elsewhere
	wallZ(-60, 0, -80, WALL_H + 1, 2, {
		{ at = -22, width = 5, top = 11, bottom = 5, glass = true },
		{ at = -58, width = 5, top = 11, bottom = 5, glass = true },
	}, "exterior", f)
	wallZ(60, 0, -80, WALL_H + 1, 2, sideWindows, "exterior", f)

	-- hallway walls with a door into every room
	local hallDoors: { Opening } = {}
	for _, z in rowMid do
		table.insert(hallDoors, { at = z, width = 6, top = 10 })
	end
	local leftAt = wallZ(-8, 0, -80, WALL_H, 1, hallDoors, "interior", f)
	local rightAt = wallZ(8, 0, -80, WALL_H, 1, hallDoors, "interior", f)
	for _, z in rowMid do
		table.insert(map.doors, makeDoor(leftAt(z), 6, 10, -1, f, true))
		table.insert(map.doors, makeDoor(rightAt(z), 6, 10, 1, f, true))
	end

	-- walls between rooms; a few open archways make loops you can run around
	wallX(rows[2], -60, -8, WALL_H, 1, { { at = -34, width = 6, top = 10 } }, "interior", f)
	wallX(rows[3], -60, -8, WALL_H, 1, {}, "interior", f)
	wallX(rows[2], 8, 60, WALL_H, 1, {}, "interior", f)
	wallX(rows[3], 8, 60, WALL_H, 1, { { at = 34, width = 6, top = 10 } }, "interior", f)

	-- front double door (opens when the round starts)
	local fl = makeDoor(frontAt(-2), 4, 11, -1, f, false)
	local fr = makeDoor(frontAt(2), 4, 11, 1, f, false)
	map.frontDoors = { fl, fr }

	-- exit double door, swings out into the garden
	local backCF = backAt(0)
	local el = makeDoor(backCF * CFrame.new(-2, 0, 0), 4, 11, -1, f, false)
	local er = makeDoor(backCF * CFrame.new(2, 0, 0), 4, 11, 1, f, false)
	for _, d in { el, er } do
		d.panel.Color = Color3.fromRGB(50, 20, 18)
		local chain = box(Vector3.new(4, 0.5, 0.6), d.closed * CFrame.new(0, 0, 0.4), C.Iron, Enum.Material.DiamondPlate, f)
		weld(d.panel, chain)
		d.panel:FindFirstChildOfClass("PathfindingModifier"):Destroy()
	end
	local lockPart = box(Vector3.new(1.4, 1.8, 0.8), backCF * CFrame.new(0, 5.5, 0.7), C.Gold, Enum.Material.Metal, f)
	lockPart.Name = "ExitLock"
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Exit Door"
	prompt.ActionText = "Unlock"
	prompt.HoldDuration = 1.2
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = lockPart
	map.exitDoors = { el, er }
	map.exitLock = lockPart
	map.exitPrompt = prompt

	-- porch
	box(Vector3.new(16, 0.6, 6), CFrame.new(0, 0.3, 4), C.Stone, Enum.Material.Slate, f)
	box(Vector3.new(18, 0.6, 7), CFrame.new(0, 15.3, 4.5), C.WoodDark, Enum.Material.Wood, f)
	for _, x in { -7, 7 } do
		cyl(1, 15, Vector3.new(x, 0.6, 6.5), C.Pale, Enum.Material.Marble, f)
	end
	local porchLamp = ball(0.8, Vector3.new(0, 13.5, 2), C.Flame, Enum.Material.Neon, f)
	light(porchLamp, C.Flame, 1.4, 24)
	-- invisible ceiling above the manor so nobody walks on the roof
	box(Vector3.new(130, 2, 90), CFrame.new(0, 48, -40), Color3.new(), Enum.Material.SmoothPlastic, f, { Transparency = 1, CanQuery = false })
end

local function buildHallway()
	local f = folder("Hallway")
	box(Vector3.new(9, 0.08, 78), CFrame.new(0, Y0 + 0.04, -40), Color3.fromRGB(80, 10, 16), Enum.Material.Carpet, f)
	for _, z in { -7, -27, -47, -73 } do
		wallSconce(Vector3.new(-7.3, 8, z), Vector3.new(1, 0, 0), f)
	end
	for _, z in { -2, -20, -58, -76 } do
		wallSconce(Vector3.new(7.3, 8, z), Vector3.new(-1, 0, 0), f)
	end
	painting(CFrame.lookAt(Vector3.new(-7.35, 8.5, -20), Vector3.new(0, 8.5, -20)), Vector2.new(4, 5), f, true)
	painting(CFrame.lookAt(Vector3.new(7.35, 8.5, -33), Vector3.new(0, 8.5, -33)), Vector2.new(5, 4), f, false)
	painting(CFrame.lookAt(Vector3.new(-7.35, 8.5, -60), Vector3.new(0, 8.5, -60)), Vector2.new(3.5, 5), f, true)
	painting(CFrame.lookAt(Vector3.new(7.35, 8.5, -6), Vector3.new(0, 8.5, -6)), Vector2.new(3.5, 5), f, true)
	-- side tables with vases
	for _, data in { { -6, -33 }, { 6, -52 } } do
		table4(Vector3.new(data[1], Y0, data[2]), Vector3.new(1.6, 3, 3), f, C.WoodDark)
		local vase = cyl(0.9, 1.6, Vector3.new(data[1], Y0 + 3, data[2] + 0.6), Color3.fromRGB(60, 70, 80), Enum.Material.Glass, f)
		vase.CanCollide = false
	end
	addKeySpot("Hallway", Vector3.new(-6, Y0 + 3.5, -33.8))
	bloodText(CFrame.lookAt(Vector3.new(7.45, 8, -48), Vector3.new(0, 8, -48)), Vector2.new(8, 4), "GET OUT", 2, f)
	bloodText(CFrame.lookAt(Vector3.new(-7.45, 9, -52), Vector3.new(0, 9, -52)), Vector2.new(9, 3.5), "IT HEARS YOU", 1, f)
	hangingLamp(Vector3.new(0, 12, -40), f, 0.5, 16)
	dust(CFrame.new(0, 8, -40), Vector3.new(14, 14, 78), f)
	for _, z in { -13, -40, -67 } do
		table.insert(map.patrolPoints, Vector3.new(0, Y0, z))
	end
end

local function buildParlor()
	local f = folder("Parlor")
	local cz = -40 / 3
	-- fireplace on the west wall
	box(Vector3.new(4, 0.6, 11), CFrame.new(-57.5, Y0 + 0.3, cz), C.Stone, Enum.Material.Slate, f)
	for _, dz in { -4.5, 4.5 } do
		box(Vector3.new(3, 8, 1.8), CFrame.new(-57.8, Y0 + 4, cz + dz), C.Stone, Enum.Material.Cobblestone, f)
	end
	box(Vector3.new(1, 8, 8), CFrame.new(-58.6, Y0 + 4, cz), C.StoneDark, Enum.Material.Cobblestone, f)
	box(Vector3.new(4.4, 1, 12), CFrame.new(-57.5, Y0 + 8.5, cz), C.WoodDark, Enum.Material.Wood, f)
	box(Vector3.new(3, 7, 9), CFrame.new(-58, Y0 + 12.5, cz), C.Stone, Enum.Material.Cobblestone, f)
	for _, dz in { -1, 1 } do
		local log = box(Vector3.new(4, 0.8, 0.8), CFrame.new(-58, Y0 + 1, cz + dz) * CFrame.Angles(0, math.pi / 2 + dz * 0.3, 0), Color3.fromRGB(40, 25, 15), Enum.Material.Wood, f)
		log.Shape = Enum.PartType.Cylinder
	end
	local firePart = box(Vector3.new(2, 1, 4), CFrame.new(-58, Y0 + 1.5, cz), Color3.new(), Enum.Material.SmoothPlastic, f, { Transparency = 1, CanCollide = false })
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 9
	fire.Color = Color3.fromRGB(255, 120, 40)
	fire.SecondaryColor = Color3.fromRGB(200, 30, 10)
	fire.Parent = firePart
	light(firePart, Color3.fromRGB(255, 120, 50), 2.2, 26)
	for _, dz in { -4, -2.5, 2.5, 4 } do
		candle(Vector3.new(-57, Y0 + 9, cz + dz), f, dz == 4)
	end
	addKeySpot("Parlor", Vector3.new(-57, Y0 + 9.5, cz + 1))
	painting(CFrame.lookAt(Vector3.new(-56, Y0 + 12.5, cz), Vector3.new(0, Y0 + 12.5, cz)), Vector2.new(4, 4.5), f, true)

	-- sofa facing the fire
	local sofa = model("Sofa", f)
	box(Vector3.new(3.5, 1.6, 10), CFrame.new(-46, Y0 + 0.8, cz), C.Fabric, Enum.Material.Fabric, sofa)
	box(Vector3.new(1.2, 3.6, 10), CFrame.new(-44, Y0 + 1.8, cz), C.Fabric, Enum.Material.Fabric, sofa)
	for _, dz in { -5, 5 } do
		box(Vector3.new(3.5, 2.4, 0.8), CFrame.new(-46, Y0 + 1.2, cz + dz), C.Fabric, Enum.Material.Fabric, sofa)
	end
	box(Vector3.new(14, 0.08, 16), CFrame.new(-50, Y0 + 0.04, cz), Color3.fromRGB(60, 30, 25), Enum.Material.Carpet, f)

	-- rocking chair that rocks by itself
	local rocker = model("RockingChair", f)
	local rc = CFrame.new(-52, Y0, cz - 8) * CFrame.Angles(0, math.rad(-60), 0)
	box(Vector3.new(2.2, 0.3, 2.2), rc * CFrame.new(0, 2, 0), C.WoodDark, Enum.Material.Wood, rocker)
	box(Vector3.new(2.2, 3.6, 0.3), rc * CFrame.new(0, 3.9, 1.1) * CFrame.Angles(-0.2, 0, 0), C.WoodDark, Enum.Material.Wood, rocker)
	for _, sx in { -1, 1 } do
		box(Vector3.new(0.25, 0.25, 3.4), rc * CFrame.new(sx * 1, 0.25, 0), C.WoodDark, Enum.Material.Wood, rocker)
		box(Vector3.new(0.25, 1.8, 0.25), rc * CFrame.new(sx * 1, 1.1, -0.8), C.WoodDark, Enum.Material.Wood, rocker)
		box(Vector3.new(0.25, 1.8, 0.25), rc * CFrame.new(sx * 1, 1.1, 0.8), C.WoodDark, Enum.Material.Wood, rocker)
	end
	noCollide(rocker)
	rocker.WorldPivot = rc
	rocker:SetAttribute("Amp", 9)
	rocker:SetAttribute("Speed", 1.7)
	CollectionService:AddTag(rocker, "Rock")

	-- piano
	local piano = model("Piano", f)
	box(Vector3.new(9, 4.5, 3), CFrame.new(-20, Y0 + 2.25, -2.8), C.Black, Enum.Material.SmoothPlastic, piano, { Reflectance = 0.08 })
	box(Vector3.new(8, 0.3, 1.2), CFrame.new(-20, Y0 + 2.8, -4.7), Color3.fromRGB(225, 220, 200), Enum.Material.SmoothPlastic, piano)
	for i = -3.6, 3.6, 0.55 do
		box(Vector3.new(0.25, 0.25, 0.7), CFrame.new(-20 + i, Y0 + 3, -4.4), C.Black, Enum.Material.SmoothPlastic, piano)
	end
	chair(Vector3.new(-20, Y0, -7), Vector3.new(0, 0, 1), f)
	candle(Vector3.new(-23, Y0 + 4.5, -2.5), f)
	addKeySpot("Parlor", Vector3.new(-17, Y0 + 5, -2.8))

	-- grandfather clock
	local clock = model("Clock", f)
	box(Vector3.new(3, 10, 2), CFrame.new(-11, Y0 + 5, -24.5), C.WoodDark, Enum.Material.Wood, clock)
	local face = box(Vector3.new(0.2, 2.2, 2.2), CFrame.new(-11, Y0 + 8, -23.4) * CFrame.Angles(0, math.pi / 2, 0), C.Bone, Enum.Material.SmoothPlastic, clock)
	face.Shape = Enum.PartType.Cylinder
	local pendulum = model("Pendulum", clock)
	box(Vector3.new(0.15, 3, 0.15), CFrame.new(-11, Y0 + 4.5, -23.4), C.Gold, Enum.Material.Metal, pendulum)
	ball(0.8, Vector3.new(-11, Y0 + 3, -23.4), C.Gold, Enum.Material.Metal, pendulum)
	noCollide(pendulum)
	pendulum.WorldPivot = CFrame.new(-11, Y0 + 6, -23.4)
	pendulum:SetAttribute("Amp", 14)
	pendulum:SetAttribute("Speed", 3.1)
	CollectionService:AddTag(pendulum, "Swing")

	hangingLamp(Vector3.new(-34, 12, cz), f, 0.5, 18)
	dust(CFrame.new(-34, 8, cz), Vector3.new(50, 14, 24), f)
	table.insert(map.patrolPoints, Vector3.new(-34, Y0, cz))
end

local function buildLibrary()
	local f = folder("Library")
	local cz = -40
	for _, x in { -52, -42 } do
		bookshelf(CFrame.new(x, Y0, cz) * CFrame.Angles(0, math.pi / 2, 0), 16, 11, true, f)
	end
	bookshelf(CFrame.new(-58.6, Y0, cz) * CFrame.Angles(0, -math.pi / 2, 0), 20, 13, false, f)
	-- one shelf has toppled over
	local fallen = bookshelf(CFrame.new(-28, Y0, -48), 10, 9, false, f)
	fallen.WorldPivot = CFrame.new(-28, Y0, -48)
	fallen:PivotTo(CFrame.new(-28, Y0 + 1.3, -49) * CFrame.Angles(math.rad(80), 0.2, 0))
	for _ = 1, 25 do
		box(
			Vector3.new(rng:NextNumber(0.8, 1.4), 0.3, rng:NextNumber(1, 1.6)),
			CFrame.new(rng:NextNumber(-34, -20), Y0 + 0.15, rng:NextNumber(-50, -30)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
			BOOK_COLORS[rng:NextInteger(1, #BOOK_COLORS)],
			Enum.Material.Leather,
			f,
			{ CanCollide = false }
		)
	end
	-- reading desk
	table4(Vector3.new(-20, Y0, cz), Vector3.new(6, 3.4, 3.5), f, C.WoodDark)
	chair(Vector3.new(-20, Y0, cz - 3), Vector3.new(0, 0, 1), f, true)
	box(Vector3.new(2, 0.2, 1.4), CFrame.new(-20.5, Y0 + 3.5, cz) * CFrame.Angles(0, 0.2, 0), C.Bone, Enum.Material.SmoothPlastic, f, { CanCollide = false })
	candle(Vector3.new(-18, Y0 + 3.4, cz + 1), f)
	addKeySpot("Library", Vector3.new(-21.5, Y0 + 3.9, cz + 0.8))
	addKeySpot("Library", Vector3.new(-47, Y0 + 0.5, cz - 6))
	-- globe
	cyl(0.5, 3, Vector3.new(-14, Y0, -30), C.WoodDark, Enum.Material.Wood, f)
	ball(2.2, Vector3.new(-14, Y0 + 4, -30), Color3.fromRGB(70, 80, 60), Enum.Material.Fabric, f)
	-- ladder
	local ladder = model("Ladder", f)
	for _, sx in { -0.8, 0.8 } do
		box(Vector3.new(0.25, 12, 0.25), CFrame.new(-56.5, Y0 + 6, -33 + sx) * CFrame.Angles(0, 0, -0.2), C.Wood, Enum.Material.Wood, ladder)
	end
	for y = 1, 11, 1.5 do
		box(Vector3.new(0.2, 0.2, 1.6), CFrame.new(-56.5 - (y - 6) * 0.2, Y0 + y, -33), C.Wood, Enum.Material.Wood, ladder)
	end
	noCollide(ladder)
	hangingLamp(Vector3.new(-34, 12, cz), f, 0.4, 16)
	dust(CFrame.new(-34, 8, cz), Vector3.new(50, 14, 24), f)
	table.insert(map.patrolPoints, Vector3.new(-30, Y0, cz))
end

local function buildNursery()
	local f = folder("Nursery")
	local cz = -200 / 3
	-- crib
	local crib = model("Crib", f)
	box(Vector3.new(6, 0.4, 3.5), CFrame.new(-50, Y0 + 2, -74), Color3.fromRGB(200, 195, 185), Enum.Material.Wood, crib)
	for x = -2.8, 2.8, 0.7 do
		for _, dz in { -1.6, 1.6 } do
			box(Vector3.new(0.15, 3, 0.15), CFrame.new(-50 + x, Y0 + 3.5, -74 + dz), Color3.fromRGB(200, 195, 185), Enum.Material.Wood, crib)
		end
	end
	for _, sx in { -1, 1 } do
		box(Vector3.new(0.4, 5, 3.5), CFrame.new(-50 + sx * 3, Y0 + 2.5, -74), Color3.fromRGB(200, 195, 185), Enum.Material.Wood, crib)
	end
	box(Vector3.new(5.6, 0.4, 3.2), CFrame.new(-50, Y0 + 2.4, -74), Color3.fromRGB(150, 140, 160), Enum.Material.Fabric, crib)
	addKeySpot("Nursery", Vector3.new(-50, Y0 + 3, -74))
	-- baby mobile, swinging slowly over the crib
	local mobile = model("Mobile", f)
	cyl(0.08, 4, Vector3.new(-50, Y0 + 11.5, -74), C.Iron, Enum.Material.Metal, mobile)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		local p = Vector3.new(-50 + math.cos(a) * 1.4, Y0 + 10, -74 + math.sin(a) * 1.4)
		cyl(0.05, 1.5, p, C.Iron, Enum.Material.Metal, mobile)
		ball(0.5, p, Color3.fromHSV(i / 5, 0.3, 0.5), Enum.Material.SmoothPlastic, mobile)
	end
	noCollide(mobile)
	mobile.WorldPivot = CFrame.new(-50, Y0 + WALL_H - 0.5, -74)
	mobile:SetAttribute("Amp", 5)
	mobile:SetAttribute("Speed", 0.6)
	CollectionService:AddTag(mobile, "Swing")

	-- rocking horse
	local horse = model("RockingHorse", f)
	local hc = CFrame.new(-30, Y0, -60) * CFrame.Angles(0, math.rad(30), 0)
	local horseColor = Color3.fromRGB(150, 120, 90)
	box(Vector3.new(1.4, 1.4, 3.6), hc * CFrame.new(0, 2.4, 0), horseColor, Enum.Material.Wood, horse)
	box(Vector3.new(1, 2, 1), hc * CFrame.new(0, 3.6, -1.6) * CFrame.Angles(0.4, 0, 0), horseColor, Enum.Material.Wood, horse)
	box(Vector3.new(1, 0.9, 1.6), hc * CFrame.new(0, 4.4, -2.2), horseColor, Enum.Material.Wood, horse)
	for _, sx in { -0.5, 0.5 } do
		box(Vector3.new(0.12, 0.12, 0.05), hc * CFrame.new(sx, 4.6, -3.02), Color3.fromRGB(255, 0, 0), Enum.Material.Neon, horse)
		for _, sz in { -1.2, 1.2 } do
			box(Vector3.new(0.3, 1.6, 0.3), hc * CFrame.new(sx, 1.2, sz), horseColor, Enum.Material.Wood, horse)
		end
		box(Vector3.new(0.3, 0.3, 4.6), hc * CFrame.new(sx * 1.3, 0.3, 0), C.WoodDark, Enum.Material.Wood, horse)
	end
	noCollide(horse)
	horse.WorldPivot = hc
	horse:SetAttribute("Amp", 12)
	horse:SetAttribute("Speed", 2.1)
	CollectionService:AddTag(horse, "Rock")

	-- toy blocks
	for _ = 1, 14 do
		box(
			Vector3.one * 0.9,
			CFrame.new(rng:NextNumber(-40, -20), Y0 + 0.45, rng:NextNumber(-76, -58)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			Color3.fromHSV(rng:NextNumber(), 0.45, 0.5),
			Enum.Material.Wood,
			f
		)
	end
	-- child's bed
	box(Vector3.new(5, 1.6, 8), CFrame.new(-18, Y0 + 0.8, -75), Color3.fromRGB(200, 195, 185), Enum.Material.Wood, f)
	box(Vector3.new(4.6, 0.6, 7.6), CFrame.new(-18, Y0 + 1.9, -75), Color3.fromRGB(110, 90, 110), Enum.Material.Fabric, f)
	box(Vector3.new(3, 0.6, 1.4), CFrame.new(-18, Y0 + 2.4, -78), Color3.fromRGB(210, 205, 195), Enum.Material.Fabric, f)

	-- doll on a little chair. Its head follows you.
	local doll = model("Doll", f)
	local dc = Vector3.new(-13, Y0, -63)
	box(Vector3.new(1.6, 1.6, 1.6), CFrame.new(dc + Vector3.new(0, 1, 0)), C.WoodDark, Enum.Material.Wood, doll)
	box(Vector3.new(1, 1.4, 0.7), CFrame.new(dc + Vector3.new(0, 2.5, 0)), Color3.fromRGB(110, 20, 30), Enum.Material.Fabric, doll)
	watcherHead(dc + Vector3.new(0, 3.65, 0), 1, C.Pale, doll)

	-- music box on a small table
	table4(Vector3.new(-56, Y0, -58), Vector3.new(3, 3, 3), f, C.WoodDark)
	box(Vector3.new(1.4, 0.9, 1), CFrame.new(-56, Y0 + 3.45, -58), Color3.fromRGB(120, 40, 60), Enum.Material.Wood, f)
	addKeySpot("Nursery", Vector3.new(-55.5, Y0 + 3.4, -59))

	bloodText(CFrame.lookAt(Vector3.new(-58.95, 8, -68), Vector3.new(0, 8, -68)), Vector2.new(14, 4), "SHE IS STILL HERE", 0, f)
	hangingLamp(Vector3.new(-34, 12, cz), f, 0.35, 14)
	dust(CFrame.new(-34, 8, cz), Vector3.new(50, 14, 24), f)
	table.insert(map.patrolPoints, Vector3.new(-34, Y0, cz))
end

local function buildDining()
	local f = folder("DiningHall")
	local cz = -40 / 3
	table4(Vector3.new(36, Y0, cz), Vector3.new(26, 3.4, 5), f, C.WoodDark)
	box(Vector3.new(26.4, 0.06, 5.4), CFrame.new(36, Y0 + 3.43, cz), Color3.fromRGB(150, 140, 125), Enum.Material.Fabric, f, { CanCollide = false })
	for i = 0, 5 do
		local x = 26 + i * 4
		chair(Vector3.new(x, Y0, cz - 3.6), Vector3.new(0, 0, 1), f, true)
		chair(Vector3.new(x, Y0, cz + 3.6), Vector3.new(0, 0, -1), f, true)
		for _, dz in { -1.6, 1.6 } do
			local plate = cyl(1.2, 0.08, Vector3.new(x, Y0 + 3.46, cz + dz), C.Bone, Enum.Material.SmoothPlastic, f)
			plate.CanCollide = false
		end
	end
	chair(Vector3.new(50.5, Y0, cz), Vector3.new(-1, 0, 0), f, true)
	-- candelabras
	for _, x in { 28, 36, 44 } do
		local base = Vector3.new(x, Y0 + 3.45, cz)
		cyl(0.3, 1.6, base, C.Gold, Enum.Material.Metal, f)
		box(Vector3.new(2, 0.15, 0.15), CFrame.new(base + Vector3.new(0, 1.5, 0)), C.Gold, Enum.Material.Metal, f)
		for _, dx in { -0.9, 0, 0.9 } do
			candle(base + Vector3.new(dx, 1.6, 0), f, dx == 0)
		end
	end
	addKeySpot("DiningHall", Vector3.new(38, Y0 + 0.6, cz))
	addKeySpot("DiningHall", Vector3.new(57.5, Y0 + 4.3, cz - 6))
	-- sideboard
	box(Vector3.new(2.5, 3.8, 12), CFrame.new(57.5, Y0 + 1.9, cz), C.WoodDark, Enum.Material.Wood, f)
	-- the chandelier
	local ch = model("Chandelier", f)
	local top = Vector3.new(36, Y0 + WALL_H - 0.5, cz)
	cyl(0.15, 4, top - Vector3.new(0, 4, 0), C.Iron, Enum.Material.Metal, ch)
	local ring = box(Vector3.new(0.4, 6, 6), CFrame.new(top - Vector3.new(0, 4.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), C.Gold, Enum.Material.Metal, ch)
	ring.Shape = Enum.PartType.Cylinder
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		candle(top + Vector3.new(math.cos(a) * 2.6, -4, math.sin(a) * 2.6), ch, i % 2 == 0)
	end
	noCollide(ch)
	ch.WorldPivot = CFrame.new(top)
	ch:SetAttribute("Amp", 5)
	ch:SetAttribute("Speed", 0.9)
	CollectionService:AddTag(ch, "Swing")
	painting(CFrame.lookAt(Vector3.new(36, 9, -1.1), Vector3.new(36, 9, -20)), Vector2.new(8, 5), f, false)
	painting(CFrame.lookAt(Vector3.new(36, 9, -26), Vector3.new(36, 9, 0)), Vector2.new(4, 5), f, true)
	dust(CFrame.new(34, 8, cz), Vector3.new(50, 14, 24), f)
	table.insert(map.patrolPoints, Vector3.new(34, Y0, cz - 8))
end

local function buildKitchen()
	local f = folder("Kitchen")
	local cz = -40
	local stoneTop = Color3.fromRGB(60, 60, 64)
	box(Vector3.new(3, 3.6, 22), CFrame.new(57.5, Y0 + 1.8, cz), C.Wood, Enum.Material.WoodPlanks, f)
	box(Vector3.new(3.4, 0.4, 22.4), CFrame.new(57.4, Y0 + 3.8, cz), stoneTop, Enum.Material.Granite, f)
	-- stove with a smouldering fire
	box(Vector3.new(4, 4, 5), CFrame.new(12, Y0 + 2, -30), C.Iron, Enum.Material.Metal, f)
	cyl(1.2, 9, Vector3.new(12, Y0 + 4, -31), C.Iron, Enum.Material.Metal, f)
	local stoveFire = box(Vector3.new(2, 0.5, 2), CFrame.new(12, Y0 + 4.2, -28.8), Color3.new(), Enum.Material.SmoothPlastic, f, { Transparency = 1, CanCollide = false })
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Heat = 4
	fire.Parent = stoveFire
	light(stoveFire, Color3.fromRGB(255, 100, 40), 1.4, 16)
	local pot = cyl(1.4, 1.2, Vector3.new(12, Y0 + 4, -29), C.Iron, Enum.Material.Metal, f)
	local steam = Instance.new("ParticleEmitter")
	steam.Texture = SMOKE
	steam.Rate = 3
	steam.Lifetime = NumberRange.new(2, 3)
	steam.Speed = NumberRange.new(1.5, 2.5)
	steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.5) })
	steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
	steam.Color = ColorSequence.new(Color3.fromRGB(120, 140, 110))
	steam.Parent = pot
	-- butcher's island
	box(Vector3.new(10, 3.5, 4), CFrame.new(34, Y0 + 1.75, cz), C.Wood, Enum.Material.Wood, f)
	box(Vector3.new(10.4, 0.5, 4.4), CFrame.new(34, Y0 + 3.75, cz), Color3.fromRGB(80, 50, 35), Enum.Material.Wood, f)
	box(Vector3.new(3, 1, 1.6), CFrame.new(32, Y0 + 4.5, cz), Color3.fromRGB(110, 25, 30), Enum.Material.Fabric, f) -- meat
	local cleaver = box(Vector3.new(0.1, 1, 1.6), CFrame.new(32, Y0 + 5.3, cz) * CFrame.Angles(0, 0.4, 0.1), Color3.fromRGB(170, 170, 175), Enum.Material.Metal, f)
	cleaver.CanCollide = false
	addKeySpot("Kitchen", Vector3.new(36.5, Y0 + 4.4, cz + 1))
	addKeySpot("Kitchen", Vector3.new(57.5, Y0 + 4.4, cz - 8))
	-- blood on the floor
	for _ = 1, 4 do
		local splat = cyl(rng:NextNumber(2, 5), 0.05, Vector3.new(34 + rng:NextNumber(-6, 6), Y0, cz + rng:NextNumber(-6, 6)), C.Blood, Enum.Material.Glass, f)
		splat.CanCollide = false
		splat.Transparency = 0.1
	end
	-- meat hooks swaying from the ceiling
	for i, z in { -34, -40, -46 } do
		local hook = model("MeatHook", f)
		local hookTop = Vector3.new(24, Y0 + WALL_H - 0.5, z)
		cyl(0.1, 5, hookTop - Vector3.new(0, 5, 0), C.Iron, Enum.Material.Metal, hook)
		box(Vector3.new(1.6, 4, 1.2), CFrame.new(hookTop - Vector3.new(0, 7, 0)) * CFrame.Angles(0, i, 0), Color3.fromRGB(120, 40, 40), Enum.Material.Fabric, hook)
		box(Vector3.new(1.4, 1, 1), CFrame.new(hookTop - Vector3.new(0, 9.3, 0)), Color3.fromRGB(150, 60, 55), Enum.Material.Fabric, hook)
		noCollide(hook)
		hook.WorldPivot = CFrame.new(hookTop)
		hook:SetAttribute("Amp", 4 + i)
		hook:SetAttribute("Speed", 0.7 + i * 0.15)
		CollectionService:AddTag(hook, "Swing")
	end
	-- barrels and sacks
	for _, p in { Vector3.new(55, Y0, -51), Vector3.new(52, Y0, -51.5), Vector3.new(56, Y0, -48) } do
		cyl(2.6, 3.6, p, Color3.fromRGB(70, 48, 30), Enum.Material.WoodPlanks, f)
	end
	hangingLamp(Vector3.new(34, 12, cz + 6), f, 0.5, 16)
	dust(CFrame.new(34, 8, cz), Vector3.new(50, 14, 24), f)
	table.insert(map.patrolPoints, Vector3.new(30, Y0, cz))
end

local function buildBedroom()
	local f = folder("Bedroom")
	local cz = -200 / 3
	-- four-poster bed
	local bed = model("Bed", f)
	local bc = Vector3.new(46, Y0, -72)
	box(Vector3.new(8, 1.6, 11), CFrame.new(bc + Vector3.new(0, 1, 0)), C.WoodDark, Enum.Material.Wood, bed)
	box(Vector3.new(7.6, 1, 10.6), CFrame.new(bc + Vector3.new(0, 2.3, 0)), Color3.fromRGB(170, 160, 150), Enum.Material.Fabric, bed)
	box(Vector3.new(7.8, 0.4, 7), CFrame.new(bc + Vector3.new(0, 2.9, 1.6)), C.Fabric, Enum.Material.Fabric, bed)
	for _, sx in { -1, 1 } do
		box(Vector3.new(2.6, 0.8, 1.6), CFrame.new(bc + Vector3.new(sx * 1.8, 3.1, -4)), Color3.fromRGB(200, 195, 185), Enum.Material.Fabric, bed)
		for _, sz in { -1, 1 } do
			box(Vector3.new(0.6, 10, 0.6), CFrame.new(bc + Vector3.new(sx * 3.8, 5, sz * 5.3)), C.WoodDark, Enum.Material.Wood, bed)
		end
		box(Vector3.new(0.1, 8, 10.6), CFrame.new(bc + Vector3.new(sx * 3.95, 6, 0)), C.Fabric, Enum.Material.Fabric, bed, { Transparency = 0.35, CanCollide = false })
	end
	box(Vector3.new(8.6, 0.4, 11.2), CFrame.new(bc + Vector3.new(0, 10.1, 0)), C.Fabric, Enum.Material.Fabric, bed)
	addKeySpot("Bedroom", bc + Vector3.new(1, 3.5, 2))
	-- wardrobe that rattles
	local wardrobe = model("Wardrobe", f)
	box(Vector3.new(3, 10, 7), CFrame.new(57.8, Y0 + 5, -58), C.WoodDark, Enum.Material.Wood, wardrobe)
	local doors = model("WardrobeDoors", wardrobe)
	for _, dz in { -1.7, 1.7 } do
		box(Vector3.new(0.3, 9, 3.3), CFrame.new(56.2, Y0 + 5, -58 + dz), C.Wood, Enum.Material.Wood, doors)
		ball(0.35, Vector3.new(56, Y0 + 5, -58 + dz * 0.2), C.Gold, Enum.Material.Metal, doors)
	end
	noCollide(doors)
	doors.WorldPivot = CFrame.new(56.2, Y0 + 5, -58)
	CollectionService:AddTag(doors, "Rattle")
	-- vanity and mirror
	table4(Vector3.new(30, Y0, -78), Vector3.new(6, 3.2, 2.4), f, C.WoodDark)
	box(Vector3.new(5, 6, 0.2), CFrame.new(30, Y0 + 7.5, -78.85), Color3.fromRGB(180, 190, 200), Enum.Material.Glass, f, { Reflectance = 0.7, Transparency = 0 })
	box(Vector3.new(5.8, 6.8, 0.15), CFrame.new(30, Y0 + 7.5, -78.95), C.Gold, Enum.Material.Metal, f)
	candle(Vector3.new(28, Y0 + 3.2, -78), f)
	addKeySpot("Bedroom", Vector3.new(31.5, Y0 + 3.7, -77.8))
	box(Vector3.new(10, 0.08, 14), CFrame.new(46, Y0 + 0.04, -70), Color3.fromRGB(50, 20, 30), Enum.Material.Carpet, f)
	painting(CFrame.lookAt(Vector3.new(59, 9, -72), Vector3.new(0, 9, -72)), Vector2.new(4, 5), f, true)
	hangingLamp(Vector3.new(34, 12, cz), f, 0.35, 14)
	dust(CFrame.new(34, 8, cz), Vector3.new(50, 14, 24), f)
	table.insert(map.patrolPoints, Vector3.new(34, Y0, cz))
	map.monsterSpawn = CFrame.lookAt(Vector3.new(24, 6, -64), Vector3.new(8, 6, -64))
end

local function buildGarden()
	local f = folder("Garden")
	-- backyard is x -60..60, z -80..-130
	wallZ(-61, -80, -132, 14, 2, {}, "stone", f)
	wallZ(61, -80, -132, 14, 2, {}, "stone", f)
	wallX(-131, -62, 62, 14, 2, { { at = 0, width = 10, top = 13 } }, "stone", f)
	for _, data in {
		{ Vector3.new(2, 80, 54), Vector3.new(-62, 40, -106) },
		{ Vector3.new(2, 80, 54), Vector3.new(62, 40, -106) },
		{ Vector3.new(126, 80, 2), Vector3.new(0, 40, -135) },
	} do
		box(data[1], CFrame.new(data[2]), Color3.new(), Enum.Material.SmoothPlastic, f, { Transparency = 1, CanQuery = false })
	end
	-- the gate out: a wall of ghostly light
	for _, x in { -6.5, 6.5 } do
		box(Vector3.new(3, 18, 3), CFrame.new(x, 9, -131), C.Stone, Enum.Material.Cobblestone, f)
		local orb = ball(1.6, Vector3.new(x, 19, -131), Color3.fromRGB(120, 255, 170), Enum.Material.Neon, f)
		light(orb, Color3.fromRGB(100, 255, 160), 1.6, 26)
	end
	box(Vector3.new(16, 2, 3), CFrame.new(0, 17, -131), C.Stone, Enum.Material.Cobblestone, f)
	local veil = box(Vector3.new(10, 13, 0.4), CFrame.new(0, 6.5, -131), Color3.fromRGB(150, 255, 200), Enum.Material.ForceField, f, {
		CanCollide = false,
		CanQuery = false,
	})
	veil.Name = "Veil"
	local wisps = Instance.new("ParticleEmitter")
	wisps.Texture = SMOKE
	wisps.Rate = 12
	wisps.Lifetime = NumberRange.new(2, 4)
	wisps.Speed = NumberRange.new(1, 3)
	wisps.SpreadAngle = Vector2.new(30, 30)
	wisps.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
	wisps.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	wisps.Color = ColorSequence.new(Color3.fromRGB(140, 255, 190))
	wisps.LightEmission = 0.8
	wisps.EmissionDirection = Enum.NormalId.Back
	wisps.Parent = veil
	local zone = box(Vector3.new(10, 12, 6), CFrame.new(0, 6, -128), Color3.new(), Enum.Material.SmoothPlastic, f, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	zone.Name = "ExitZone"
	map.exitZone = zone
	box(Vector3.new(10, 14, 1), CFrame.new(0, 7, -133), Color3.new(), Enum.Material.SmoothPlastic, f, { Transparency = 1 })

	-- dead hedges
	for _, data in { { -30, -95, 30, 3 }, { 30, -95, 30, 3 }, { -42, -115, 3, 20 }, { 42, -115, 3, 20 } } do
		box(Vector3.new(data[3], 5, data[4]), CFrame.new(data[1], 2.5, data[2]), Color3.fromRGB(38, 42, 30), Enum.Material.Grass, f)
	end
	-- dry fountain with a statue that watches you
	cyl(14, 1.6, Vector3.new(0, 0, -108), C.Stone, Enum.Material.Marble, f)
	local water = cyl(12.5, 0.2, Vector3.new(0, 1.4, -108), Color3.fromRGB(50, 4, 4), Enum.Material.Glass, f)
	water.CanCollide = false
	cyl(2, 5, Vector3.new(0, 1.6, -108), C.Stone, Enum.Material.Marble, f)
	local statue = model("Statue", f)
	box(Vector3.new(2.4, 4, 1.6), CFrame.new(0, 8.6, -108), C.Pale, Enum.Material.Marble, statue)
	for _, sx in { -1, 1 } do
		box(Vector3.new(4, 3, 0.3), CFrame.new(sx * 2.8, 9.6, -108.6) * CFrame.Angles(0, 0, sx * 0.4), C.Pale, Enum.Material.Marble, statue)
	end
	watcherHead(Vector3.new(0, 11.4, -108), 1.6, C.Pale, statue)
	for _, x in { -18, 18 } do
		lanternPost(Vector3.new(x, 0, -122), f, Color3.fromRGB(110, 255, 170))
	end
	for _ = 1, 10 do
		local x = rng:NextNumber(-55, 55)
		if math.abs(x) > 12 then
			gravestone(Vector3.new(x, 0, rng:NextNumber(-126, -100)), f)
		end
	end
	deadTree(Vector3.new(-50, 0, -88), f)
	deadTree(Vector3.new(48, 0, -124), f)
	fogEmitter(CFrame.new(0, 1, -106), Vector3.new(116, 1, 46), f, 9)
	for _, p in { Vector3.new(-25, Y0, -105), Vector3.new(25, Y0, -105) } do
		table.insert(map.patrolPoints, p)
	end
end

----------------------------------------------------------------------------------------------------

function MapBuilder.build()
	-- Clear out the default baseplate and spawn from a fresh place.
	for _, name in { "Baseplate", "SpawnLocation", "HollowManor" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	root = Instance.new("Folder")
	root.Name = "HollowManor"

	map = {
		folder = root,
		doors = {},
		keySpots = {},
		patrolPoints = {},
		bloodTexts = {},
	}

	buildTerrain()
	buildLobby()
	buildFrontYard()
	buildManorShell()
	buildHallway()
	buildParlor()
	buildLibrary()
	buildNursery()
	buildDining()
	buildKitchen()
	buildBedroom()
	buildGarden()

	root.Parent = workspace
	return map
end

return MapBuilder
