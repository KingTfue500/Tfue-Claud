--!strict
-- Item-Modelle aus Teilen (Platzhalter für spätere Meshes, daher _PH im Modellnamen).
-- Jedes Modell hat ein PrimaryPart "Handle"; alle anderen Teile sind per WeldConstraint verbunden.

local Config = require(script.Parent.Config)

local ItemModels = {}

local function part(model: Model, handle: BasePart?, name: string, size: Vector3, offset: CFrame, material: Enum.Material, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Material = material
	p.Color = color
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	if handle then
		p.CFrame = handle.CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = p
		w.Parent = p
	else
		p.CFrame = offset
	end
	p.Parent = model
	return p
end

local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- Zylinderachse (X) nach Z drehen

function ItemModels.Build(itemId: string): Model
	local info = Config.ItemInfo[itemId]
	local model = Instance.new("Model")
	model.Name = itemId .. "_PH"
	local baseColor = if info then info.Color else Color3.fromRGB(120, 120, 120)

	local handle: Part
	if itemId == "Flashlight" then
		handle = part(model, nil, "Handle", Vector3.new(0.9, 0.35, 0.35), ALONG_Z, Enum.Material.Metal, baseColor, CYL)
		part(model, handle, "Head", Vector3.new(0.3, 0.5, 0.5), CFrame.new(-0.5, 0, 0), Enum.Material.Metal, baseColor, CYL)
		local lens = part(model, handle, "Lens", Vector3.new(0.05, 0.42, 0.42), CFrame.new(-0.66, 0, 0), Enum.Material.Neon, Color3.fromRGB(255, 240, 200), CYL)
		lens:SetAttribute("Lens", true)
		part(model, handle, "Switch", Vector3.new(0.15, 0.08, 0.12), CFrame.new(0.1, 0.19, 0), Enum.Material.Rubber, Color3.fromRGB(20, 20, 20))
	elseif itemId == "Scanner" then
		handle = part(model, nil, "Handle", Vector3.new(0.7, 0.35, 1.0), CFrame.new(), Enum.Material.Metal, baseColor)
		part(model, handle, "Screen", Vector3.new(0.5, 0.05, 0.45), CFrame.new(0, 0.18, -0.15), Enum.Material.Neon, Color3.fromRGB(255, 120, 40))
		part(model, handle, "Grip", Vector3.new(0.3, 0.6, 0.3), CFrame.new(0, -0.4, 0.3), Enum.Material.Rubber, Color3.fromRGB(25, 25, 25))
		part(model, handle, "Antenna", Vector3.new(0.06, 0.5, 0.06), CFrame.new(0.25, 0.4, -0.4), Enum.Material.Metal, Color3.fromRGB(40, 40, 40))
	elseif itemId == "Flare" then
		handle = part(model, nil, "Handle", Vector3.new(1.0, 0.22, 0.22), CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, baseColor, CYL)
		local tip = part(model, handle, "Tip", Vector3.new(0.15, 0.23, 0.23), CFrame.new(0.55, 0, 0), Enum.Material.Metal, Color3.fromRGB(60, 60, 60), CYL)
		tip:SetAttribute("FlareTip", true)
		part(model, handle, "Cap", Vector3.new(0.12, 0.25, 0.25), CFrame.new(-0.5, 0, 0), Enum.Material.Rubber, Color3.fromRGB(240, 220, 200), CYL)
	elseif itemId == "HandWarmer" then
		handle = part(model, nil, "Handle", Vector3.new(0.6, 0.12, 0.45), CFrame.new(), Enum.Material.Fabric, baseColor)
		part(model, handle, "Label", Vector3.new(0.4, 0.13, 0.2), CFrame.new(0, 0.005, 0), Enum.Material.Fabric, Color3.fromRGB(240, 230, 210))
	elseif itemId == "Battery" then
		handle = part(model, nil, "Handle", Vector3.new(0.6, 0.3, 0.3), CFrame.new(), Enum.Material.Metal, baseColor, CYL)
		part(model, handle, "Cap", Vector3.new(0.08, 0.12, 0.12), CFrame.new(0.33, 0, 0), Enum.Material.Metal, Color3.fromRGB(200, 200, 200), CYL)
	elseif itemId == "Injector" then
		handle = part(model, nil, "Handle", Vector3.new(0.8, 0.22, 0.22), CFrame.new(), Enum.Material.Glass, Color3.fromRGB(230, 230, 230), CYL)
		handle.Transparency = 0.3
		part(model, handle, "Fluid", Vector3.new(0.6, 0.16, 0.16), CFrame.new(0.05, 0, 0), Enum.Material.Neon, baseColor, CYL)
		part(model, handle, "Plunger", Vector3.new(0.3, 0.1, 0.1), CFrame.new(0.5, 0, 0), Enum.Material.Metal, Color3.fromRGB(80, 80, 80), CYL)
		part(model, handle, "Needle", Vector3.new(0.3, 0.03, 0.03), CFrame.new(-0.55, 0, 0), Enum.Material.Metal, Color3.fromRGB(200, 200, 210), CYL)
	elseif itemId == "Fuse" then
		handle = part(model, nil, "Handle", Vector3.new(0.7, 0.28, 0.28), CFrame.new(), Enum.Material.Glass, Color3.fromRGB(220, 230, 240), CYL)
		handle.Transparency = 0.35
		part(model, handle, "CapA", Vector3.new(0.14, 0.32, 0.32), CFrame.new(0.38, 0, 0), Enum.Material.Metal, baseColor, CYL)
		part(model, handle, "CapB", Vector3.new(0.14, 0.32, 0.32), CFrame.new(-0.38, 0, 0), Enum.Material.Metal, baseColor, CYL)
		part(model, handle, "Wire", Vector3.new(0.6, 0.04, 0.04), CFrame.new(), Enum.Material.Metal, Color3.fromRGB(80, 60, 30), CYL)
	elseif itemId == "VialBlue" or itemId == "VialGreen" or itemId == "VialRed" then
		handle = part(model, nil, "Handle", Vector3.new(0.7, 0.3, 0.3), CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Glass, Color3.fromRGB(230, 240, 250), CYL)
		handle.Transparency = 0.4
		part(model, handle, "Fluid", Vector3.new(0.5, 0.24, 0.24), CFrame.new(-0.05, 0, 0), Enum.Material.Neon, baseColor, CYL)
		part(model, handle, "Cork", Vector3.new(0.12, 0.26, 0.26), CFrame.new(0.38, 0, 0), Enum.Material.Metal, Color3.fromRGB(60, 60, 65), CYL)
	elseif itemId == "Keycard" then
		handle = part(model, nil, "Handle", Vector3.new(0.55, 0.03, 0.35), CFrame.new(), Enum.Material.Foil, baseColor)
		part(model, handle, "Stripe", Vector3.new(0.55, 0.035, 0.07), CFrame.new(0, 0, 0.1), Enum.Material.Metal, Color3.fromRGB(20, 20, 20))
		part(model, handle, "Chip", Vector3.new(0.1, 0.035, 0.08), CFrame.new(-0.15, 0, -0.05), Enum.Material.Metal, Color3.fromRGB(210, 180, 60))
	elseif itemId == "Diesel" then
		handle = part(model, nil, "Handle", Vector3.new(1.4, 1.7, 0.7), CFrame.new(), Enum.Material.Metal, baseColor)
		part(model, handle, "Grip", Vector3.new(0.9, 0.18, 0.2), CFrame.new(0, 0.95, 0), Enum.Material.Metal, Color3.fromRGB(120, 20, 18))
		part(model, handle, "Spout", Vector3.new(0.25, 0.3, 0.25), CFrame.new(0.5, 0.95, 0), Enum.Material.Metal, Color3.fromRGB(40, 40, 40), CYL)
		part(model, handle, "Ridge", Vector3.new(1.2, 1.2, 0.75), CFrame.new(0, -0.1, 0), Enum.Material.Metal, Color3.fromRGB(140, 25, 22))
	else
		handle = part(model, nil, "Handle", Vector3.new(0.5, 0.5, 0.5), CFrame.new(), Enum.Material.Metal, baseColor, BALL)
	end

	model.PrimaryPart = handle
	model:SetAttribute("ItemId", itemId)
	return model
end

return ItemModels
