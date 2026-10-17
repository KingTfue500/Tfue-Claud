--!strict
-- StatsService: Statistik pro Runde und Spieler (Sieg-Bildschirm, Abschnitt 7 Extraktion):
-- Überlebenszeit, niedrigste Temperatur, Ablenkungen, Wiederbelebungen, wie oft entdeckt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Types)

local StatsService = {}
StatsService.Name = "StatsService"

local stats: { [Player]: Types.RoundStats } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

function StatsService.StartRound(participants: { Player })
	table.clear(stats)
	local t = now()
	for _, p in participants do
		stats[p] = {
			StartTime = t,
			EndTime = nil,
			LowestTemp = 37,
			Distractions = 0,
			Revives = 0,
			Detected = 0,
			Escaped = false,
		}
	end
end

function StatsService.Get(player: Player): Types.RoundStats?
	return stats[player]
end

function StatsService.RecordTemp(player: Player, temp: number)
	local s = stats[player]
	if s and s.EndTime == nil and temp < s.LowestTemp then
		s.LowestTemp = temp
	end
end

function StatsService.AddDistraction(player: Player)
	local s = stats[player]
	if s then
		s.Distractions += 1
	end
end

function StatsService.AddRevive(player: Player)
	local s = stats[player]
	if s then
		s.Revives += 1
	end
end

function StatsService.AddDetected(player: Player)
	local s = stats[player]
	if s then
		s.Detected += 1
	end
end

-- Spieler ist raus (tot, vermisst oder entkommen)
function StatsService.Finish(player: Player, escaped: boolean)
	local s = stats[player]
	if s and s.EndTime == nil then
		s.EndTime = now()
		s.Escaped = escaped
	end
end

function StatsService.SurvivalTime(player: Player): number
	local s = stats[player]
	if s == nil then
		return 0
	end
	return (s.EndTime or now()) - s.StartTime
end

-- Für den Sieg-/Niederlage-Bildschirm
function StatsService.Summary(): { { [string]: any } }
	local out: { { [string]: any } } = {}
	for p, s in stats do
		table.insert(out, {
			Name = p.DisplayName,
			UserId = p.UserId,
			Survived = (s.EndTime or now()) - s.StartTime,
			LowestTemp = s.LowestTemp,
			Distractions = s.Distractions,
			Revives = s.Revives,
			Detected = s.Detected,
			Escaped = s.Escaped,
		})
	end
	table.sort(out, function(a, b)
		return (a.Survived :: number) > (b.Survived :: number)
	end)
	return out
end

function StatsService.Remove(player: Player)
	stats[player] = nil
end

function StatsService.Init() end
function StatsService.Start() end

return StatsService
