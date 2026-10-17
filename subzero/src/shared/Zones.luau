--!strict
-- Zonen-Erkennung per Volumen-Boxen (Map/ZoneVolumes, persistent gestreamt).
-- Wird von Server (Temperatur, Runde) und Client (Licht, Hall) genutzt.

local Workspace = game:GetService("Workspace")

local Zones = {}

type Volume = { Part: BasePart, Id: string, Priority: number }

local volumes: { Volume } = {}
local watched: Instance? = nil

local function rebuild(container: Instance)
	table.clear(volumes)
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") then
			local id = d:GetAttribute("ZoneId")
			if type(id) == "string" then
				local prio = d:GetAttribute("Priority")
				table.insert(volumes, {
					Part = d,
					Id = id,
					Priority = if type(prio) == "number" then prio else 0,
				})
			end
		end
	end
	-- höhere Priorität zuerst (z. B. Leiterschacht vor Zone 4)
	table.sort(volumes, function(a: Volume, b: Volume)
		return a.Priority > b.Priority
	end)
end

local function ensure()
	if watched ~= nil and watched.Parent ~= nil and #volumes > 0 then
		return
	end
	local map = Workspace:FindFirstChild("Map")
	local container = if map then map:FindFirstChild("ZoneVolumes") else nil
	if container == nil then
		return
	end
	if watched ~= container then
		watched = container
		container.DescendantAdded:Connect(function()
			rebuild(container)
		end)
		container.DescendantRemoving:Connect(function()
			task.defer(rebuild, container)
		end)
	end
	rebuild(container)
end

function Zones.IsInsidePart(part: BasePart, pos: Vector3): boolean
	local rel = part.CFrame:PointToObjectSpace(pos)
	local half = part.Size * 0.5
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

function Zones.GetZoneAt(pos: Vector3): string
	ensure()
	for _, v in volumes do
		if Zones.IsInsidePart(v.Part, pos) then
			return v.Id
		end
	end
	return "None"
end

-- Index einer Zone für Fortschritt (Lobby 0, Zone1..4, Helipad 5)
function Zones.Index(id: string): number
	if id == "Lobby" then
		return 0
	elseif id == "Zone1" then
		return 1
	elseif id == "Zone2" then
		return 2
	elseif id == "Zone3" then
		return 3
	elseif id == "Zone4" then
		return 4
	elseif id == "Helipad" then
		return 5
	end
	return -1
end

return Zones
