--!strict
-- Gemeinsamer Client-Zustand (offene Oberflächen, Kinematik, sichtbare Prompts)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Signal)

local ClientState = {}

local openUis: { [string]: boolean } = {}

ClientState.Cinematic = false
ClientState.PromptsShown = 0
ClientState.Spectating = false
ClientState.UiChanged = Signal.new() :: Signal.Signal<string, boolean>
ClientState.CinematicChanged = Signal.new() :: Signal.Signal<boolean>

function ClientState.SetUi(name: string, open: boolean)
	if (openUis[name] == true) ~= open then
		if open then
			openUis[name] = true
		else
			openUis[name] = nil
		end
		ClientState.UiChanged:Fire(name, open)
	end
end

function ClientState.IsUiOpen(name: string?): boolean
	if name then
		return openUis[name] == true
	end
	return next(openUis) ~= nil
end

function ClientState.SetCinematic(on: boolean)
	if ClientState.Cinematic ~= on then
		ClientState.Cinematic = on
		ClientState.CinematicChanged:Fire(on)
	end
end

-- Eingaben für Spielaktionen gesperrt?
function ClientState.InputBlocked(): boolean
	return ClientState.Cinematic or ClientState.IsUiOpen()
end

return ClientState
