--!strict
-- Untergrund unter einer Position bestimmen (für Schritte und Geräusch-Radius).
-- Teile können ein Attribut "Surface" tragen: Grate, Snow, Concrete, Ice, Metal.

local Workspace = game:GetService("Workspace")

local Surface = {}

local MATERIAL_MAP: { [Enum.Material]: string } = {
	[Enum.Material.DiamondPlate] = "Grate",
	[Enum.Material.Snow] = "Snow",
	[Enum.Material.Ice] = "Ice",
	[Enum.Material.Glacier] = "Ice",
	[Enum.Material.Concrete] = "Concrete",
	[Enum.Material.Slate] = "Concrete",
	[Enum.Material.Pavement] = "Concrete",
	[Enum.Material.Metal] = "Metal",
	[Enum.Material.CorrodedMetal] = "Metal",
	[Enum.Material.Foil] = "Metal",
}

function Surface.FromPart(part: BasePart): string
	local attr = part:GetAttribute("Surface")
	if type(attr) == "string" then
		return attr
	end
	return MATERIAL_MAP[part.Material] or "Concrete"
end

function Surface.Below(pos: Vector3, ignore: { Instance }): (string, BasePart?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local hit = Workspace:Raycast(pos, Vector3.new(0, -8, 0), params)
	if hit and hit.Instance:IsA("BasePart") then
		return Surface.FromPart(hit.Instance), hit.Instance
	end
	return "Concrete", nil
end

return Surface
