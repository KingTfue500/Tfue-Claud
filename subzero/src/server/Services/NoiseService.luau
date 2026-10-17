--!strict
-- NoiseService: alle Geräusche laufen über Emit(position, radius, art) (Abschnitt 5.1).
-- Außerdem Wärme-Leuchtfeuer (große Wärmequellen mit eigenem Signal-Radius) und
-- 3D-Sounds an die Clients.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

local NoiseService = {}
NoiseService.Name = "NoiseService"

-- (event, attentionOverride)
NoiseService.Emitted = Signal.new() :: Signal.Signal<Types.NoiseEvent, number?>

local sound3D: RemoteEvent
local beacons: { [number]: Types.Beacon } = {}
local nextBeaconId = 0

-- Geräusch-Ereignis. attention: optionaler Aufmerksamkeits-Wert (z. B. Schritte)
function NoiseService.Emit(position: Vector3, radius: number, kind: string, source: Player?, attention: number?)
	if radius <= 0 then
		return
	end
	local ev: Types.NoiseEvent = {
		Position = position,
		Radius = radius,
		Kind = kind,
		Source = source,
		Time = Workspace:GetServerTimeNow(),
	}
	NoiseService.Emitted:Fire(ev, attention)
end

-- 3D-Sound bei allen Clients abspielen (Schlüssel aus Config.Sounds)
function NoiseService.PlaySound(key: string, position: Vector3, volume: number?, pitch: number?, rollOff: number?)
	sound3D:FireAllClients(key, position, volume or 1, pitch or 1, rollOff or Config.SoundVolume.DefaultRollOff)
end

-- Geräusch + Sound in einem
function NoiseService.EmitWithSound(position: Vector3, radius: number, kind: string, soundKey: string, source: Player?, volume: number?)
	NoiseService.Emit(position, radius, kind, source)
	NoiseService.PlaySound(soundKey, position, volume, 1, math.max(radius * 2, 40))
end

----------------------------------------------------------------------
-- Wärme-Leuchtfeuer: Generator 250, Radiator 60, Fackel 80, Dampfventil 30
----------------------------------------------------------------------
function NoiseService.AddBeacon(kind: string, position: Vector3, part: BasePart?, owner: Player?): number
	nextBeaconId += 1
	local radius = Config.Entity.Beacon[kind] or 30
	beacons[nextBeaconId] = {
		Id = nextBeaconId,
		Kind = kind,
		Position = position,
		Radius = radius,
		Active = false,
		Owner = owner,
		Part = part,
	}
	return nextBeaconId
end

function NoiseService.SetBeaconActive(id: number, active: boolean)
	local b = beacons[id]
	if b then
		b.Active = active
	end
end

function NoiseService.RemoveBeacon(id: number)
	beacons[id] = nil
end

function NoiseService.GetBeacon(id: number): Types.Beacon?
	return beacons[id]
end

function NoiseService.GetActiveBeacons(): { Types.Beacon }
	local out: { Types.Beacon } = {}
	for _, b in beacons do
		if b.Active then
			if b.Part and b.Part.Parent then
				b.Position = b.Part.Position
			end
			table.insert(out, b)
		end
	end
	return out
end

function NoiseService.Init()
	sound3D = Net.Event("Sound3D")
end

function NoiseService.Start() end

return NoiseService
