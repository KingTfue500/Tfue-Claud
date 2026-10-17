--!strict
-- Einstellungen (Abschnitt 9): Kamerawackeln reduzieren, Lautstärke Musik/Effekte, Helligkeit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Signal)

local Settings = {
	ReduceShake = false,
	MusicVolume = 0.6,
	EffectsVolume = 1.0,
	Brightness = 0.0, -- -0.3 .. 0.3 (Gamma über ColorCorrectionEffect)
}

local changed = Signal.new() :: Signal.Signal<string>

function Settings.Set(key: string, value: any)
	(Settings :: any)[key] = value
	changed:Fire(key)
end

function Settings.OnChanged(fn: (string) -> ()): Signal.Connection
	return changed:Connect(fn)
end

function Settings.ShakeFactor(): number
	return if Settings.ReduceShake then 0.2 else 1
end

return Settings
