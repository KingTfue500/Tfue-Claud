--!strict
-- DataService: Statistiken speichern (DataStore PlayerStats_v1) und Bestenlisten
-- (OrderedDataStore) auf dem Schwarzen Brett der Lobby anzeigen (Abschnitt 12).
-- Speichern beim Verlassen, alle 120 s und bei BindToClose, jeweils mit 3 Wiederholungen.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapService = require(script.Parent.MapService)

local DataService = {}
DataService.Name = "DataService"

export type Profile = {
	Evacuations: number,
	MinutesSurvived: number,
	Distractions: number,
	Deaths: number,
	LogsFound: { [string]: boolean },
}

local profiles: { [Player]: Profile } = {}
local loaded: { [Player]: boolean } = {}
local enabled = true
local store: DataStore? = nil
local ordered: { [string]: OrderedDataStore } = {}
local nameCache: { [number]: string } = {}

local function defaults(): Profile
	return { Evacuations = 0, MinutesSurvived = 0, Distractions = 0, Deaths = 0, LogsFound = {} }
end

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function withRetries<T>(fn: () -> T): (boolean, T?)
	for attempt = 1, Config.Data.Retries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attempt < Config.Data.Retries then
			task.wait(Config.Data.RetryDelay * attempt)
		else
			warn("[DataService] DataStore request failed: " .. tostring(result))
		end
	end
	return false, nil
end

local function sanitize(raw: any): Profile
	local p = defaults()
	if type(raw) == "table" then
		for _, k in { "Evacuations", "MinutesSurvived", "Distractions", "Deaths" } do
			local v = raw[k]
			if type(v) == "number" then
				(p :: any)[k] = v
			end
		end
		if type(raw.LogsFound) == "table" then
			for id, v in raw.LogsFound do
				if type(id) == "string" and v == true then
					p.LogsFound[id] = true
				end
			end
		end
	end
	return p
end

local function publishAttributes(player: Player, p: Profile)
	local logs = 0
	for _ in p.LogsFound do
		logs += 1
	end
	player:SetAttribute("StatEvacuations", p.Evacuations)
	player:SetAttribute("StatLogs", logs)
end

local function load(player: Player)
	local p = defaults()
	local s = store
	if enabled and s then
		local ok, raw = withRetries(function(): any
			return s:GetAsync(key(player))
		end)
		if ok then
			p = sanitize(raw)
		end
	end
	if player.Parent then
		profiles[player] = p
		loaded[player] = true
		publishAttributes(player, p)
	end
end

local function save(player: Player)
	local p = profiles[player]
	local s = store
	if not enabled or s == nil or p == nil or not loaded[player] then
		return
	end
	local snapshot = table.clone(p)
	withRetries(function(): any
		return s:UpdateAsync(key(player), function(_old: any): any
			return snapshot
		end)
	end)
	local values: { [string]: number } = {
		Evacuations = p.Evacuations,
		MinutesSurvived = p.MinutesSurvived,
		Distractions = p.Distractions,
	}
	for stat, ods in ordered do
		local v = math.floor(values[stat] or 0)
		withRetries(function(): any
			ods:SetAsync(tostring(player.UserId), v)
			return true
		end)
	end
end

function DataService.Get(player: Player): Profile?
	return profiles[player]
end

function DataService.Add(player: Player, stat: string, delta: number)
	local p = profiles[player]
	if p == nil then
		return
	end
	local cur = (p :: any)[stat]
	if type(cur) == "number" then
		(p :: any)[stat] = cur + delta
		publishAttributes(player, p)
	end
end

function DataService.AddLog(player: Player, noteId: string)
	local p = profiles[player]
	if p and not p.LogsFound[noteId] then
		p.LogsFound[noteId] = true
		publishAttributes(player, p)
	end
end

----------------------------------------------------------------------
-- Bestenlisten
----------------------------------------------------------------------
local function nameOf(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function(): string
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local n = if ok and type(name) == "string" then name else ("#" .. userId)
	nameCache[userId] = n
	return n
end

local function refreshBoards()
	for _, panel in MapService.GetTaggedParts("Leaderboard") do
		local stat = panel:GetAttribute("Stat")
		local gui = panel:FindFirstChild("BoardGui")
		local list = if gui then gui:FindFirstChild("List") else nil
		if type(stat) == "string" and list and list:IsA("TextLabel") then
			local ods = ordered[stat]
			if not enabled or not ods then
				list.Text = "OFFLINE\n(DataStore unavailable)"
			else
				local ok, pages = pcall(function(): DataStorePages
					return ods:GetSortedAsync(false, Config.Data.LeaderboardSize)
				end)
				if ok and pages then
					local entries = pages:GetCurrentPage()
					local lines: { string } = {}
					for i, e in entries do
						local entry = e :: any
						local uid = tonumber(entry.key) or 0
						table.insert(lines, string.format("%d. %-12s %5d", i, string.sub(nameOf(uid), 1, 12), entry.value))
					end
					list.Text = if #lines > 0 then table.concat(lines, "\n") else "NO DATA"
				end
			end
		end
	end
end

function DataService.Init()
	local ok, result = pcall(function(): DataStore
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok and result then
		store = result
		for stat, storeName in Config.Data.OrderedStores do
			local ok2, ods = pcall(function(): OrderedDataStore
				return DataStoreService:GetOrderedDataStore(storeName)
			end)
			if ok2 and ods then
				ordered[stat] = ods
			end
		end
		-- Zugriff testen (in Studio ohne API-Zugriff schlägt das fehl)
		local s = result
		local okProbe = pcall(function()
			s:GetAsync("__probe")
		end)
		if not okProbe then
			enabled = false
			print("[DataService] DataStores not available - stats are kept in memory only (enable 'Studio Access to API Services' to save).")
		end
	else
		enabled = false
		print("[DataService] DataStores not available - stats are kept in memory only.")
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
		loaded[player] = nil
	end)
	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local t = 0
		while pending > 0 and t < 25 do
			t += task.wait(0.2)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveInterval)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player)
			end
		end
	end)
	task.spawn(function()
		while true do
			refreshBoards()
			task.wait(Config.Data.LeaderboardInterval)
		end
	end)
end

return DataService
