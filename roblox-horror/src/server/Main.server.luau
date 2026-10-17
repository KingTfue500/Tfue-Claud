-- Runs the game: builds the map, sets up the lighting, and loops
-- lobby -> round (find the keys, unlock the exit, escape the monster) -> results.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local MapBuilder = require(script.Parent.MapBuilder)
local Monster = require(script.Parent.Monster)

Players.RespawnTime = 4
Players.CharacterAutoLoads = true

----------------------------------------------------------------------------------------------------
-- Remotes
----------------------------------------------------------------------------------------------------

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(name: string)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local Notify = remote("Notify") -- (text, kind)
local Jumpscare = remote("Jumpscare") -- (monsterModel)
local Escaped = remote("Escaped")
local Lightning = remote("Lightning")
local Blackout = remote("Blackout") -- (seconds)
local Shake = remote("Shake") -- (position, strength)
local FlashlightRemote = remote("Flashlight") -- client -> server (on)
local SprintRemote = remote("Sprint") -- client -> server (on)
remotes.Parent = ReplicatedStorage

local function setState(key: string, value: any)
	ReplicatedStorage:SetAttribute(key, value)
end
setState("Phase", "Intermission")
setState("TimeLeft", 0)
setState("KeysFound", 0)
setState("KeysRequired", Config.KeysRequired)

----------------------------------------------------------------------------------------------------
-- Lighting
----------------------------------------------------------------------------------------------------

for _, child in Lighting:GetChildren() do
	if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") or child:IsA("Clouds") then
		child:Destroy()
	end
end
Lighting.ClockTime = 0
Lighting.Brightness = 0.5
Lighting.Ambient = Color3.fromRGB(12, 12, 18)
Lighting.OutdoorAmbient = Color3.fromRGB(36, 38, 54)
Lighting.EnvironmentDiffuseScale = 0.15
Lighting.EnvironmentSpecularScale = 0.5
Lighting.ExposureCompensation = -0.1
Lighting.GlobalShadows = true

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.42
atmosphere.Offset = 0.1
atmosphere.Color = Color3.fromRGB(58, 62, 78)
atmosphere.Decay = Color3.fromRGB(22, 18, 30)
atmosphere.Glare = 0
atmosphere.Haze = 2.4
atmosphere.Parent = Lighting

local sky = Instance.new("Sky")
sky.StarCount = 1200
sky.MoonAngularSize = 16
sky.CelestialBodiesShown = true
sky.Parent = Lighting

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "Grade"
grade.Contrast = 0.18
grade.Saturation = -0.35
grade.Brightness = -0.02
grade.TintColor = Color3.fromRGB(212, 216, 236)
grade.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.8
bloom.Size = 30
bloom.Threshold = 0.85
bloom.Parent = Lighting

local dof = Instance.new("DepthOfFieldEffect")
dof.FarIntensity = 0.25
dof.FocusDistance = 20
dof.InFocusRadius = 35
dof.NearIntensity = 0
dof.Parent = Lighting

----------------------------------------------------------------------------------------------------
-- Map
----------------------------------------------------------------------------------------------------

local map = MapBuilder.build()

local function notifyAll(text: string, kind: string?)
	Notify:FireAllClients(text, kind or "info")
end

local function inRoundPlayers()
	local list = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("InRound") then
			table.insert(list, p)
		end
	end
	return list
end

map.onDoorSmashed = function(door)
	Shake:FireAllClients(door.panel.Position, 1)
end

----------------------------------------------------------------------------------------------------
-- Players
----------------------------------------------------------------------------------------------------

local function setupCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	local head = char:WaitForChild("Head") :: BasePart
	char:SetAttribute("Flashlight", false)
	char:SetAttribute("Sprinting", false)
	hum.WalkSpeed = Config.Player.WalkSpeed

	local att = Instance.new("Attachment")
	att.Name = "FlashlightAttachment"
	att.Position = Vector3.new(0, 0, -0.9)
	att.Parent = head
	local beam = Instance.new("SpotLight")
	beam.Name = "Flashlight"
	beam.Angle = Config.Flashlight.Angle
	beam.Range = Config.Flashlight.Range
	beam.Brightness = Config.Flashlight.Brightness
	beam.Color = Color3.fromRGB(255, 236, 205)
	beam.Shadows = true
	beam.Face = Enum.NormalId.Front
	beam.Enabled = false
	beam.Parent = att
	local spill = Instance.new("SpotLight")
	spill.Name = "FlashlightSpill"
	spill.Angle = 120
	spill.Range = 16
	spill.Brightness = 0.35
	spill.Color = beam.Color
	spill.Shadows = false
	spill.Face = Enum.NormalId.Front
	spill.Enabled = false
	spill.Parent = att

	hum.Died:Connect(function()
		if player:GetAttribute("InRound") then
			player:SetAttribute("InRound", false)
			notifyAll(player.DisplayName .. " didn't make it.", "death")
		end
	end)
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("InRound", false)
	player:SetAttribute("Escaped", false)
	player.CharacterAdded:Connect(function(char)
		setupCharacter(player, char)
	end)
	if player.Character then
		task.spawn(setupCharacter, player, player.Character)
	end
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

FlashlightRemote.OnServerEvent:Connect(function(player, on)
	if typeof(on) ~= "boolean" then
		return
	end
	local char = player.Character
	local att = char and char:FindFirstChild("Head") and char.Head:FindFirstChild("FlashlightAttachment")
	if not att then
		return
	end
	char:SetAttribute("Flashlight", on)
	for _, l in att:GetChildren() do
		if l:IsA("Light") then
			l.Enabled = on
		end
	end
end)

SprintRemote.OnServerEvent:Connect(function(player, on)
	if typeof(on) == "boolean" and player.Character then
		player.Character:SetAttribute("Sprinting", on)
	end
end)

----------------------------------------------------------------------------------------------------
-- Round state
----------------------------------------------------------------------------------------------------

local monster = nil
local keysFound = 0
local exitUnlocked = false
local keysFolder: Folder? = nil

local function refreshExitPrompt()
	map.exitPrompt.ActionText = if keysFound >= Config.KeysRequired
		then "Unlock"
		else string.format("Locked (%d/%d keys)", keysFound, Config.KeysRequired)
end

local function revealBloodTexts()
	for _, gui in map.bloodTexts do
		gui.Enabled = gui:GetAttribute("RevealAt") <= keysFound
	end
end

local function onKeyTaken(player: Player, keyModel: Model)
	if ReplicatedStorage:GetAttribute("Phase") ~= "Playing" or not player:GetAttribute("InRound") or not keyModel.Parent then
		return
	end
	local pos = keyModel:GetPivot().Position
	keyModel:Destroy()
	keysFound += 1
	setState("KeysFound", keysFound)
	refreshExitPrompt()
	revealBloodTexts()
	if keysFound >= Config.KeysRequired then
		notifyAll(player.DisplayName .. " found the last key! Unlock the exit at the end of the hallway!", "key")
	else
		notifyAll(string.format("%s found a key (%d/%d)", player.DisplayName, keysFound, Config.KeysRequired), "key")
	end
	-- the house reacts...
	Blackout:FireAllClients(2.4)
	if monster then
		monster:alert(pos)
	end
end

local function makeKey(position: Vector3, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "Key"
	local gold = Color3.fromRGB(255, 196, 70)
	local function piece(size: Vector3, cf: CFrame, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.Size = size
		p.CFrame = CFrame.new(position) * cf
		p.Color = gold
		p.Material = Enum.Material.Neon
		if shape then
			p.Shape = shape
		end
		p.Parent = m
		return p
	end
	local shaft = piece(Vector3.new(1.6, 0.18, 0.18), CFrame.new(0.3, 0, 0))
	piece(Vector3.new(0.16, 0.8, 0.8), CFrame.new(-0.7, 0, 0), Enum.PartType.Cylinder)
	piece(Vector3.new(0.16, 0.35, 0.16), CFrame.new(0.9, -0.2, 0))
	piece(Vector3.new(0.16, 0.25, 0.16), CFrame.new(0.6, -0.15, 0))

	local glow = Instance.new("PointLight")
	glow.Color = gold
	glow.Brightness = 1.6
	glow.Range = 9
	glow.Shadows = false
	glow.Parent = shaft
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Rate = 8
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Speed = NumberRange.new(0.5, 1.5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	sparkle.LightEmission = 1
	sparkle.Color = ColorSequence.new(gold)
	sparkle.Parent = shaft

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take"
	prompt.ObjectText = "Old Key"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = shaft
	prompt.Triggered:Connect(function(player)
		onKeyTaken(player, m)
	end)

	m.PrimaryPart = shaft
	m.WorldPivot = CFrame.new(position)
	m:SetAttribute("Amp", 0.25)
	CollectionService:AddTag(m, "Spin")
	m.Parent = parent
end

local function spawnKeys()
	if keysFolder then
		keysFolder:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "Keys"
	f.Parent = map.folder
	keysFolder = f

	-- one key per room, in different rooms each round
	local byRoom = {}
	local rooms = {}
	for _, spot in map.keySpots do
		if not byRoom[spot.room] then
			byRoom[spot.room] = {}
			table.insert(rooms, spot.room)
		end
		table.insert(byRoom[spot.room], spot.position)
	end
	for i = #rooms, 2, -1 do
		local j = math.random(1, i)
		rooms[i], rooms[j] = rooms[j], rooms[i]
	end
	for i = 1, math.min(Config.KeysRequired, #rooms) do
		local spots = byRoom[rooms[i]]
		makeKey(spots[math.random(1, #spots)] + Vector3.new(0, 0.4, 0), f)
	end
end

local function setExitLocked(locked: boolean)
	exitUnlocked = not locked
	map.exitPrompt.Enabled = locked
	map.exitLock.Transparency = locked and 0 or 1
	map.exitLock.CanCollide = locked
	for _, d in map.exitDoors do
		MapBuilder.setDoor(d, not locked)
	end
end

map.exitPrompt.Triggered:Connect(function(player)
	if exitUnlocked or not player:GetAttribute("InRound") then
		return
	end
	if keysFound < Config.KeysRequired then
		Notify:FireClient(player, string.format("It's locked. You need %d keys (%d/%d).", Config.KeysRequired, keysFound, Config.KeysRequired), "warn")
		return
	end
	setExitLocked(false)
	notifyAll(player.DisplayName .. " unlocked the exit! Get to the gate in the garden!", "exit")
	if monster then
		monster:alert(map.exitLock.Position)
	end
end)

map.exitZone.Touched:Connect(function(hit)
	local char = hit:FindFirstAncestorOfClass("Model")
	local player = char and Players:GetPlayerFromCharacter(char)
	if not player or not player:GetAttribute("InRound") then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	player:SetAttribute("InRound", false)
	player:SetAttribute("Escaped", true)
	notifyAll(player.DisplayName .. " escaped the manor!", "escape")
	Escaped:FireClient(player)
	task.delay(2.5, function()
		if player.Character == char and char.Parent then
			char:PivotTo(map.lobbyCFrame)
		end
	end)
end)

local function onCatch(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or not player:GetAttribute("InRound") then
		return
	end
	player:SetAttribute("InRound", false)
	hum.WalkSpeed = 0
	hum.JumpHeight = 0
	hum.JumpPower = 0
	Jumpscare:FireClient(player, monster and monster.model)
	Shake:FireAllClients(char:GetPivot().Position, 1.5)
	notifyAll(player.DisplayName .. " was taken by The Pale.", "death")
	task.wait(1.7)
	if hum.Parent then
		hum.Health = 0
	end
end

----------------------------------------------------------------------------------------------------
-- Ambient scares
----------------------------------------------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(math.random(18, 45))
		Lightning:FireAllClients()
	end
end)

local WHISPERS = {
	"...behind you...",
	"...it knows where you are...",
	"...don't look at the paintings...",
	"...why did you come back...",
	"...stay with us...",
	"...run...",
}

task.spawn(function()
	while true do
		task.wait(math.random(35, 70))
		if ReplicatedStorage:GetAttribute("Phase") == "Playing" then
			local roll = math.random(1, 3)
			if roll == 1 then
				Blackout:FireAllClients(math.random(25, 45) / 10)
			elseif roll == 2 then
				-- a random open door slams shut on its own
				local open = {}
				for _, d in map.doors do
					if d.isOpen then
						table.insert(open, d)
					end
				end
				if #open > 0 then
					local d = open[math.random(1, #open)]
					MapBuilder.setDoor(d, false, true)
					Shake:FireAllClients(d.panel.Position, 0.6)
				end
			else
				local list = inRoundPlayers()
				if #list > 0 then
					Notify:FireClient(list[math.random(1, #list)], WHISPERS[math.random(1, #WHISPERS)], "whisper")
				end
			end
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- Round loop
----------------------------------------------------------------------------------------------------

local function resetMap()
	keysFound = 0
	setState("KeysFound", 0)
	spawnKeys()
	setExitLocked(true)
	refreshExitPrompt()
	revealBloodTexts()
	for _, d in map.frontDoors do
		MapBuilder.setDoor(d, false)
	end
	for _, d in map.doors do
		MapBuilder.setDoor(d, math.random() < 0.4)
	end
end

local function sendToLobby(player: Player)
	player:SetAttribute("InRound", false)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and (hrp.Position - map.lobbyCFrame.Position).Magnitude > 40 then
		player:LoadCharacterAsync()
	end
end

local function intermission()
	setState("Phase", "Intermission")
	local t = Config.IntermissionTime
	while t > 0 do
		setState("TimeLeft", t)
		task.wait(1)
		if #Players:GetPlayers() >= Config.MinPlayers then
			t -= 1
		else
			t = Config.IntermissionTime
		end
	end
end

local function playRound()
	resetMap()

	local count = 0
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			count += 1
			player:SetAttribute("InRound", true)
			player:SetAttribute("Escaped", false)
			char:PivotTo(map.startCFrame * CFrame.new(math.random(-8, 8), 0, math.random(-2, 3)))
		end
	end
	if count == 0 then
		return
	end

	setState("Phase", "Playing")
	notifyAll(string.format("Find %d keys, unlock the exit and escape. Don't let it see your light.", Config.KeysRequired), "info")
	task.delay(2, function()
		for _, d in map.frontDoors do
			MapBuilder.setDoor(d, true)
		end
	end)

	monster = Monster.new(map, onCatch)
	local thisMonster = monster
	task.delay(Config.Monster.GraceTime, function()
		if monster == thisMonster and ReplicatedStorage:GetAttribute("Phase") == "Playing" then
			monster:wake()
			Lightning:FireAllClients()
			notifyAll("Something in the master bedroom has woken up...", "danger")
		end
	end)

	local t = Config.RoundTime
	while t > 0 and #inRoundPlayers() > 0 do
		setState("TimeLeft", t)
		task.wait(1)
		t -= 1
		if t == 60 then
			notifyAll("One minute left. It's getting hungry.", "danger")
		end
	end

	setState("Phase", "Ended")
	setState("TimeLeft", 0)
	local escaped = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Escaped") then
			table.insert(escaped, player.DisplayName)
		end
	end
	if t <= 0 and #inRoundPlayers() > 0 then
		for _, player in inRoundPlayers() do
			Jumpscare:FireClient(player, monster.model)
		end
		notifyAll("Time's up. The manor keeps you forever.", "death")
		task.wait(2)
	elseif #escaped > 0 then
		notifyAll("Survivors: " .. table.concat(escaped, ", "), "escape")
	else
		notifyAll("Nobody escaped. The manor is hungry again tonight.", "death")
	end

	task.wait(6)
	monster:destroy()
	monster = nil
	for _, d in map.frontDoors do
		MapBuilder.setDoor(d, false)
	end
	for _, player in Players:GetPlayers() do
		sendToLobby(player)
		player:SetAttribute("Escaped", false)
	end
end

while true do
	intermission()
	local ok, err = pcall(playRound)
	if not ok then
		warn("[HollowManor] round crashed: " .. tostring(err))
		if monster then
			monster:destroy()
			monster = nil
		end
		for _, player in Players:GetPlayers() do
			sendToLobby(player)
		end
	end
end
