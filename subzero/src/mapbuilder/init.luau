--!strict
-- MapBuilder: baut die komplette Map (Lobby, Zone 1-4, Landeplatz) aus dem Bau-Kit.
-- Wird beim Erstellen der Place-Datei vorab ausgeführt (tools/bake.luau, Lune) und
-- vom Server nur dann zur Laufzeit, wenn Workspace.Map fehlt.

local Kit = require(script.Kit)
local Lobby = require(script.Lobby)
local Zone1 = require(script.Zone1)
local Zone2 = require(script.Zone2)
local Zone3 = require(script.Zone3)
local Zone4 = require(script.Zone4)
local Helipad = require(script.Helipad)

local MapBuilder = {}

MapBuilder.Version = 1

function MapBuilder.Build(parent: Instance, config: any): Model
	local map = Instance.new("Model")
	map.Name = "Map"
	map:SetAttribute("MapVersion", MapBuilder.Version)

	-- Zonen-Volumen immer beim Client (persistent gestreamt)
	local volumes = Instance.new("Model")
	volumes.Name = "ZoneVolumes"
	volumes.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	volumes.Parent = map

	local ctx = { Map = map, Volumes = volumes, Config = config, Rng = Kit.Rng(20261016) }
	Lobby.Build(ctx)
	Zone1.Build(ctx)
	Zone2.Build(ctx)
	Zone3.Build(ctx)
	Zone4.Build(ctx)
	Helipad.Build(ctx)

	map.Parent = parent
	return map
end

return MapBuilder
