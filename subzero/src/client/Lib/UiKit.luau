--!strict
-- Kleine Bausteine für die Oberfläche (80er-Hardware-Look, Platzhalter ohne Bild-Assets)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local UiKit = {}

UiKit.Mono = Font.fromEnum(Enum.Font.RobotoMono)
UiKit.MonoBold = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
UiKit.Label = Font.fromEnum(Enum.Font.Michroma)

function UiKit.Screen(name: string, order: number): ScreenGui
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui") :: PlayerGui
	local old = pg:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local g = Instance.new("ScreenGui")
	g.Name = name
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = order
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Parent = pg
	return g
end

function UiKit.Frame(parent: Instance, name: string, size: UDim2, pos: UDim2, color: Color3, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

function UiKit.Text(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2, font: Font, textSize: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.Size = size
	l.Position = pos
	l.FontFace = font
	l.TextSize = textSize
	l.TextColor3 = color
	l.BackgroundTransparency = 1
	l.RichText = true
	l.Parent = parent
	return l
end

function UiKit.Button(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Size = size
	b.Position = pos
	b.FontFace = UiKit.Mono
	b.TextSize = 20
	b.TextColor3 = color
	b.BackgroundColor3 = Color3.fromRGB(6, 16, 9)
	b.BackgroundTransparency = 0.2
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Parent = parent
	UiKit.Stroke(b, color, 1, 0.3)
	return b
end

function UiKit.Corner(inst: Instance, scale: number, offset: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, offset or 0)
	c.Parent = inst
	return c
end

function UiKit.Stroke(inst: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

function UiKit.Gradient(inst: Instance, colors: ColorSequence, rotation: number, transparency: NumberSequence?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = colors
	g.Rotation = rotation
	if transparency then
		g.Transparency = transparency
	end
	g.Parent = inst
	return g
end

function UiKit.Tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Bild (falls Asset-ID eingetragen), sonst nil
function UiKit.ImageOrNil(parent: Instance, name: string, id: string, size: UDim2, pos: UDim2): ImageLabel?
	if id == "" then
		return nil
	end
	local img = Instance.new("ImageLabel")
	img.Name = name
	img.Image = id
	img.Size = size
	img.Position = pos
	img.BackgroundTransparency = 1
	img.Parent = parent
	return img
end

-- Scanlines (gekachelt). Mit Asset: ImageLabel; ohne: dünne Linien-Frames.
function UiKit.Scanlines(parent: Instance, spacing: number, transparency: number, maxLines: number?): Frame
	local holder = UiKit.Frame(parent, "Scanlines", UDim2.new(1, 0, 1, spacing * 4), UDim2.fromOffset(0, 0), Color3.new(0, 0, 0), 1)
	holder.ZIndex = 50
	holder.Active = false
	if Config.Images.Scanlines ~= "" then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Image = Config.Images.Scanlines
		img.ImageTransparency = transparency
		img.ScaleType = Enum.ScaleType.Tile
		img.TileSize = UDim2.fromOffset(4, spacing)
		img.ZIndex = 50
		img.Parent = holder
		return holder
	end
	local n = maxLines or 360
	for i = 0, n do
		local l = UiKit.Frame(holder, "L", UDim2.new(1, 0, 0, 1), UDim2.fromOffset(0, i * spacing), Color3.new(0, 0, 0), transparency)
		l.ZIndex = 50
	end
	return holder
end

-- Vignette aus 4 Verläufen
function UiKit.Vignette(parent: Instance, color: Color3, depth: number, transparency: number): Frame
	local holder = UiKit.Frame(parent, "Vignette", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), color, 1)
	local seq = NumberSequence.new({ NumberSequenceKeypoint.new(0, transparency), NumberSequenceKeypoint.new(1, 1) })
	type Side = { Size: UDim2, Pos: UDim2, Rot: number }
	local sides: { Side } = {
		{ Size = UDim2.new(1, 0, depth, 0), Pos = UDim2.fromScale(0, 0), Rot = 90 },
		{ Size = UDim2.new(1, 0, depth, 0), Pos = UDim2.new(0, 0, 1 - depth, 0), Rot = 270 },
		{ Size = UDim2.new(depth, 0, 1, 0), Pos = UDim2.fromScale(0, 0), Rot = 0 },
		{ Size = UDim2.new(depth, 0, 1, 0), Pos = UDim2.new(1 - depth, 0, 0, 0), Rot = 180 },
	}
	for i, s in sides do
		local f = UiKit.Frame(holder, "Side" .. i, s.Size, s.Pos, color, 0)
		UiKit.Gradient(f, ColorSequence.new(color), s.Rot, seq)
	end
	return holder
end

-- Kreisförmiger Fortschrittsring (zwei Hälften mit gedrehten Verläufen auf UIStroke)
export type Ring = {
	Frame: Frame,
	SetProgress: (self: Ring, p: number) -> (),
	SetColor: (self: Ring, c: Color3) -> (),
}

function UiKit.Ring(parent: Instance, name: string, sizePx: number, thickness: number, color: Color3): Ring
	local holder = UiKit.Frame(parent, name, UDim2.fromOffset(sizePx, sizePx), UDim2.fromOffset(0, 0), color, 1)
	local strokes: { UIStroke } = {}
	local grads: { UIGradient } = {}
	local seq = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.501, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	for i = 1, 2 do
		local clip = UiKit.Frame(holder, if i == 1 then "Right" else "Left", UDim2.new(0.5, 0, 1, 0), if i == 1 then UDim2.fromScale(0.5, 0) else UDim2.fromScale(0, 0), color, 1)
		clip.ClipsDescendants = true
		local circle = UiKit.Frame(clip, "Circle", UDim2.new(2, -thickness * 2, 1, -thickness * 2), if i == 1 then UDim2.new(-1, thickness, 0, thickness) else UDim2.fromOffset(thickness, thickness), color, 1)
		UiKit.Corner(circle, 1)
		local stroke = UiKit.Stroke(circle, color, thickness, 0)
		local g = Instance.new("UIGradient")
		g.Transparency = seq
		g.Parent = stroke
		table.insert(strokes, stroke)
		table.insert(grads, g)
	end
	local ring = { Frame = holder } :: Ring
	function ring.SetProgress(_r: Ring, p: number)
		local a = math.clamp(p, 0, 1) * 360
		grads[1].Rotation = math.clamp(a, 0, 180)
		grads[2].Rotation = math.clamp(a, 180, 360)
		strokes[1].Enabled = a > 0.5
		strokes[2].Enabled = a > 180.5
	end
	function ring.SetColor(_r: Ring, c: Color3)
		for _, s in strokes do
			s.Color = c
		end
	end
	ring:SetProgress(0)
	return ring
end

return UiKit
