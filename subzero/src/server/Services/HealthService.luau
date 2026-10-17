--!strict
-- HealthService: Kollaps, Wiederbelebung, Tod, Leichen, Zuschauer (Abschnitt 4.5).
--   Kollaps bei 24 °C: im Team 30 s am Boden (kriecht mit 1 Stud/s), Teammitglied hält 4 s E
--   und belebt mit 28 °C wieder (max. 2-mal pro Runde). Solo: sofort tot.
--   Vom Wesen gepackt: sofort tot (Kill-Kinematik 2,5 s), danach Zuschauer.
--   Leiche bleibt gefroren liegen, ihre Items können mit E aufgesammelt werden.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Util = require(ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local MapService = require(script.Parent.MapService)
local MovementService = require(script.Parent.MovementService)
local NoiseService = require(script.Parent.NoiseService)
local StatsService = require(script.Parent.StatsService)
local TemperatureService = require(script.Parent.TemperatureService)

local HealthService = {}
HealthService.Name = "HealthService"

-- (Spieler, Ursache)
HealthService.PlayerDied = Signal.new() :: Signal.Signal<Player, string>
HealthService.PlayerDowned = Signal.new() :: Signal.Signal<Player>
HealthService.PlayerRevived = Signal.new() :: Signal.Signal<Player>

type Downed = { EndTime: number, Prompt: ProximityPrompt, Revivers: { [Player]: boolean } }

local downed: { [Player]: Downed } = {}
local revives: { [Player]: number } = {}
local corpseItems: { [Model]: { InventoryService.Slot } } = {}
local corpsesFolder: Folder

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function setState(player: Player, state: string)
	player:SetAttribute("State", state)
end

local function otherAliveTeammates(player: Player): number
	local n = 0
	for _, p in Players:GetPlayers() do
		if p ~= player and Util.GetState(p) == "Alive" then
			n += 1
		end
	end
	return n
end

local function clearReviving(d: Downed, target: Player)
	for reviver in d.Revivers do
		if reviver.Parent then
			reviver:SetAttribute("Reviving", false)
		end
	end
	table.clear(d.Revivers)
	target:SetAttribute("Reviving", false)
end

local function removeDowned(player: Player)
	local d = downed[player]
	if d then
		clearReviving(d, player)
		d.Prompt:Destroy()
		downed[player] = nil
	end
	player:SetAttribute("DownedEnd", 0)
end

----------------------------------------------------------------------
-- Leiche
----------------------------------------------------------------------
local ICE = Color3.fromRGB(175, 215, 240)

local function makeCorpse(player: Player, char: Model, groundCF: CFrame?): Model?
	char.Archivable = true
	local ok, clone = pcall(function(): Instance?
		return char:Clone()
	end)
	if not ok or clone == nil or not clone:IsA("Model") then
		return nil
	end
	local corpse = clone
	corpse.Name = "Corpse_" .. player.Name
	for _, d in corpse:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ProximityPrompt") or d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = d.Name == "HumanoidRootPart"
			d.CollisionGroup = Config.CollisionGroups.ThermalClear
			if d.Name ~= "HumanoidRootPart" then
				d.Color = d.Color:Lerp(ICE, 0.55)
				d.Material = Enum.Material.Glacier
				d.Reflectance = 0.05
			end
		end
	end
	local held = corpse:FindFirstChild("HeldItem")
	if held then
		held:Destroy()
	end
	local hum = corpse:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.PlatformStand = true
	end
	-- flach auf den Rücken legen
	local root = corpse:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		corpse.PrimaryPart = root
		local base = groundCF or root.CFrame
		local pos = base.Position
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { corpse, char }
		local hit = Workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
		local ground = if hit then hit.Position else pos - Vector3.new(0, 3, 0)
		local yaw = select(2, base:ToOrientation())
		corpse:PivotTo(CFrame.new(ground + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-90), 0, 0))
	end
	corpse:SetAttribute("CorpseOf", player.UserId)
	corpse.Parent = corpsesFolder
	return corpse
end

local function setupCorpsePrompt(corpse: Model, items: { InventoryService.Slot })
	corpseItems[corpse] = items
	local root = corpse.PrimaryPart
	if root == nil or #items == 0 then
		return
	end
	local prompt = MapService.MakePrompt(root, {
		Name = "SearchPrompt",
		ActionText = "Search body",
		ObjectText = "Frozen body",
		HoldDuration = Config.Health.CorpseSearchHold,
		MaxDistance = 7,
	})
	prompt.Triggered:Connect(function(player: Player)
		if Util.GetState(player) ~= "Alive" then
			return
		end
		local list = corpseItems[corpse]
		if list == nil or #list == 0 then
			prompt.Enabled = false
			return
		end
		if InventoryService.FreeSlot(player) == nil then
			Net.Event("Notify"):FireClient(player, "BELT FULL")
			return
		end
		local slot = table.remove(list, 1) :: InventoryService.Slot
		InventoryService.GiveItem(player, slot)
		local info = Config.ItemInfo[slot.Id]
		Net.Event("Notify"):FireClient(player, "FOUND: " .. (if info then info.Name else slot.Id))
		if #list == 0 then
			prompt.Enabled = false
		end
	end)
end

----------------------------------------------------------------------
-- Tod
----------------------------------------------------------------------
function HealthService.Kill(player: Player, cause: string, corpseCF: CFrame?, noCorpse: boolean?)
	local state = Util.GetState(player)
	if state ~= "Alive" and state ~= "Downed" and state ~= "Grabbed" then
		return
	end
	removeDowned(player)
	MovementService.ExitLocker(player)
	setState(player, "Dead")
	StatsService.Finish(player, false)
	DataService.Add(player, "Deaths", 1)
	DataService.Add(player, "MinutesSurvived", StatsService.SurvivalTime(player) / 60)
	local items = InventoryService.TakeAll(player)
	local char = Util.GetCharacter(player)
	if char then
		if not noCorpse then
			local corpse = makeCorpse(player, char, corpseCF)
			if corpse then
				setupCorpsePrompt(corpse, items)
			end
		end
		player.Character = nil
		char:Destroy()
	end
	HealthService.PlayerDied:Fire(player, cause)
end

----------------------------------------------------------------------
-- Kollaps und Wiederbelebung
----------------------------------------------------------------------
function HealthService.Revive(target: Player, reviver: Player?, viaInjector: boolean?)
	if Util.GetState(target) ~= "Downed" then
		return
	end
	removeDowned(target)
	revives[target] = (revives[target] or 0) + 1
	target:SetAttribute("Revives", revives[target])
	setState(target, "Alive")
	TemperatureService.SetTemp(target, Config.Temperature.ReviveTemp)
	MovementService.SetStance(target, "Stand")
	if reviver then
		StatsService.AddRevive(reviver)
		Net.Event("Notify"):FireClient(reviver, "REVIVED " .. string.upper(target.DisplayName))
	end
	Net.Event("Notify"):FireClient(target, if viaInjector then "HEAT INJECTION - YOU'RE BACK" else "REVIVED")
	HealthService.PlayerRevived:Fire(target)
end

local function collapse(player: Player)
	if Util.GetState(player) ~= "Alive" then
		return
	end
	local teammates = otherAliveTeammates(player)
	if teammates == 0 or (revives[player] or 0) >= Config.Health.MaxRevivesPerRound then
		HealthService.Kill(player, "Hypothermia")
		return
	end
	local root = Util.GetRoot(player)
	if root == nil then
		HealthService.Kill(player, "Hypothermia")
		return
	end
	MovementService.ExitLocker(player)
	setState(player, "Downed")
	MovementService.SetStance(player, "Downed", true)
	TemperatureService.SetTemp(player, Config.Temperature.Collapse)
	player:SetAttribute("FlashlightOn", false)
	local endTime = now() + Config.Health.DownedTime
	player:SetAttribute("DownedEnd", endTime)
	local prompt = MapService.MakePrompt(root, {
		Name = "RevivePrompt",
		ActionText = "Revive",
		ObjectText = player.DisplayName,
		HoldDuration = Config.Health.ReviveHoldTime,
		MaxDistance = Config.Health.ReviveRange,
	})
	prompt:SetAttribute("OwnerUserId", player.UserId)
	local d: Downed = { EndTime = endTime, Prompt = prompt, Revivers = {} }
	downed[player] = d
	prompt.PromptButtonHoldBegan:Connect(function(reviver: Player)
		if reviver ~= player and Util.GetState(reviver) == "Alive" then
			d.Revivers[reviver] = true
			reviver:SetAttribute("Reviving", true)
			player:SetAttribute("Reviving", true)
		end
	end)
	prompt.PromptButtonHoldEnded:Connect(function(reviver: Player)
		if d.Revivers[reviver] then
			d.Revivers[reviver] = nil
			reviver:SetAttribute("Reviving", false)
			if next(d.Revivers) == nil then
				player:SetAttribute("Reviving", false)
			end
		end
	end)
	prompt.Triggered:Connect(function(reviver: Player)
		if reviver == player or Util.GetState(reviver) ~= "Alive" then
			return
		end
		local rroot = Util.GetRoot(reviver)
		local troot = Util.GetRoot(player)
		if rroot and troot and (rroot.Position - troot.Position).Magnitude <= Config.Health.ReviveRange + 2 then
			HealthService.Revive(player, reviver, false)
		end
	end)
	NoiseService.PlaySound("Gasp", root.Position, 0.8)
	HealthService.PlayerDowned:Fire(player)
end

-- Injektor auf ein Teammitglied am Boden (über InventoryService.ReviveHook)
local function injectorRevive(user: Player): boolean
	local uroot = Util.GetRoot(user)
	if uroot == nil then
		return false
	end
	local best: Player? = nil
	local bestDist = Config.Health.InjectorReviveRange
	for target in downed do
		local troot = Util.GetRoot(target)
		if troot then
			local d = (troot.Position - uroot.Position).Magnitude
			if d <= bestDist then
				best = target
				bestDist = d
			end
		end
	end
	if best then
		HealthService.Revive(best, user, true)
		return true
	end
	return false
end

----------------------------------------------------------------------
-- Vom Wesen gepackt (Kill-Kinematik)
----------------------------------------------------------------------
function HealthService.Grab(player: Player, creature: Model): boolean
	local state = Util.GetState(player)
	if state ~= "Alive" and state ~= "Downed" then
		return false
	end
	local root = Util.GetRoot(player)
	local hand = creature:FindFirstChild("RightHand", true)
	local grab = if hand then hand:FindFirstChild("GrabPoint") else nil
	if root == nil then
		HealthService.Kill(player, "Entity")
		return true
	end
	removeDowned(player)
	MovementService.ExitLocker(player)
	setState(player, "Grabbed")
	player:SetAttribute("FlashlightOn", false)
	root.Anchored = true
	Net.Event("PlayCinematic"):FireClient(player, "Kill", creature)
	NoiseService.PlaySound("MetalScreech", root.Position, 1.2, 0.8, 120)
	local start = root.CFrame
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local a = math.clamp((os.clock() - t0) / Config.Health.KillCinematicTime, 0, 1)
		if root.Parent == nil then
			conn:Disconnect()
			return
		end
		if grab and grab:IsA("Attachment") then
			local target = grab.WorldCFrame * CFrame.new(0, -1.5, 0)
			root.CFrame = start:Lerp(target, math.min(1, a * 2.5))
		else
			root.CFrame = start + Vector3.new(0, Config.Health.KillLiftHeight * a, 0)
		end
	end)
	task.delay(Config.Health.KillCinematicTime, function()
		conn:Disconnect()
		local cpos = if creature.PrimaryPart then creature.PrimaryPart.CFrame * CFrame.new(0, 0, -3) else root.CFrame
		HealthService.Kill(player, "Entity", cpos)
	end)
	return true
end

----------------------------------------------------------------------
-- Runde
----------------------------------------------------------------------
function HealthService.ResetPlayer(player: Player)
	removeDowned(player)
	revives[player] = 0
	player:SetAttribute("Revives", 0)
	player:SetAttribute("Reviving", false)
end

function HealthService.ClearCorpses()
	for corpse in corpseItems do
		corpseItems[corpse] = nil
	end
	corpsesFolder:ClearAllChildren()
end

function HealthService.IsDowned(player: Player): boolean
	return downed[player] ~= nil
end

function HealthService.Init()
	corpsesFolder = Instance.new("Folder")
	corpsesFolder.Name = "Corpses"
	corpsesFolder.Parent = Workspace
	InventoryService.ReviveHook = injectorRevive
	TemperatureService.Collapsed:Connect(collapse)
end

function HealthService.Start()
	local function onPlayer(player: Player)
		revives[player] = 0
		player.CharacterAdded:Connect(function(char)
			local hum = char:WaitForChild("Humanoid", 10)
			if hum and hum:IsA("Humanoid") then
				hum.Died:Connect(function()
					-- Unerwarteter Tod (z. B. Reset): wie ein Tod behandeln
					if Util.GetState(player) == "Alive" or Util.GetState(player) == "Downed" then
						HealthService.Kill(player, "Unknown")
					end
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		removeDowned(player)
		revives[player] = nil
	end)
	-- Abgelaufene Kollaps-Zeit, Sturz in den Abgrund
	task.spawn(function()
		while true do
			task.wait(0.25)
			local t = now()
			for player, d in downed do
				if t >= d.EndTime then
					HealthService.Kill(player, "Hypothermia")
				end
			end
			for _, player in Players:GetPlayers() do
				local st = Util.GetState(player)
				if st == "Alive" or st == "Downed" then
					local root = Util.GetRoot(player)
					if root and root.Position.Y < Config.Health.FallKillY then
						HealthService.Kill(player, "Fall", nil, true)
					end
				end
			end
		end
	end)
end

return HealthService
