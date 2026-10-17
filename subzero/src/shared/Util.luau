--!strict
-- Kleine Hilfsfunktionen

local Players = game:GetService("Players")

local Util = {}

function Util.GetCharacter(player: Player): Model?
	local c = player.Character
	if c and c.Parent then
		return c
	end
	return nil
end

function Util.GetRoot(player: Player): BasePart?
	local c = Util.GetCharacter(player)
	if c then
		local r = c:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") then
			return r
		end
	end
	return nil
end

function Util.GetHumanoid(player: Player): Humanoid?
	local c = Util.GetCharacter(player)
	if c then
		return c:FindFirstChildOfClass("Humanoid")
	end
	return nil
end

function Util.GetHead(player: Player): BasePart?
	local c = Util.GetCharacter(player)
	if c then
		local h = c:FindFirstChild("Head")
		if h and h:IsA("BasePart") then
			return h
		end
	end
	return nil
end

-- Spieler, deren State in der Liste steht
function Util.PlayersInState(states: { string }): { Player }
	local out: { Player } = {}
	for _, p in Players:GetPlayers() do
		local s = p:GetAttribute("State")
		if type(s) == "string" and table.find(states, s) then
			table.insert(out, p)
		end
	end
	return out
end

function Util.GetState(player: Player): string
	local s = player:GetAttribute("State")
	return if type(s) == "string" then s else "Lobby"
end

function Util.NumAttr(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else default
end

function Util.StrAttr(inst: Instance, name: string, default: string): string
	local v = inst:GetAttribute(name)
	return if type(v) == "string" then v else default
end

function Util.BoolAttr(inst: Instance, name: string, default: boolean): boolean
	local v = inst:GetAttribute(name)
	return if type(v) == "boolean" then v else default
end

function Util.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Util.InverseLerp(a: number, b: number, v: number): number
	if a == b then
		return 0
	end
	return math.clamp((v - a) / (b - a), 0, 1)
end

function Util.FlatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

function Util.FormatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", s // 60, s % 60)
end

function Util.Shuffle<T>(list: { T }, rng: Random): { T }
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Fehler abfangen und als Warnung ausgeben: Spielschleifen dürfen nie abbrechen
function Util.Try(label: string, fn: () -> ())
	xpcall(fn, function(err: any)
		warn("[" .. label .. "] " .. tostring(err) .. "\n" .. debug.traceback())
	end)
end

return Util
