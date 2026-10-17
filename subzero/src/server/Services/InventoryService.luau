--!strict
-- InventoryService: 1 Kleidungs-Slot und 4 Gürtel-Slots (Abschnitt 6). Aufheben (E), Fallenlassen
-- (Backspace), Items benutzen, Fackeln werfen (Pool), Taschenlampe, Wärmebild-Scanner, Spind-Auswahl.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemModels = require(ReplicatedStorage.Shared.ItemModels)
local Net = require(ReplicatedStorage.Shared.Net)
local ObjectPool = require(ReplicatedStorage.Shared.ObjectPool)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Util = require(ReplicatedStorage.Shared.Util)
local MapService = require(script.Parent.MapService)
local MovementService = require(script.Parent.MovementService)
local NoiseService = require(script.Parent.NoiseService)
local TemperatureService = require(script.Parent.TemperatureService)

local InventoryService = {}
InventoryService.Name = "InventoryService"

export type Slot = {
	Id: string,
	Battery: number?, -- Taschenlampe (Sekunden)
	Lit: boolean?, -- Fackel brennt
	Burn: number?, -- Fackel: verbleibende Brennzeit
}

type Inv = {
	Slots: { [number]: Slot },
	Active: number,
	Clothing: string,
	Loadout: { string },
	HandSource: number?,
	HandBeacon: number?,
	Held: Model?,
	HeldId: string?,
}

-- Wird vom HealthService gesetzt (vermeidet zyklische Abhängigkeit):
-- versucht ein Teammitglied am Boden mit dem Injektor wiederzubeleben
InventoryService.ReviveHook = nil :: ((user: Player) -> boolean)?

-- (Werfer, Fackel-Teil, Leuchtfeuer-Id)
InventoryService.FlareLanded = Signal.new() :: Signal.Signal<Player?, BasePart, number>

local invs: { [Player]: Inv } = {}
local itemsFolder: Folder
local cacheFolder: Folder
local flarePoolFolder: Folder
local itemCache: { [string]: { Model } } = {}

type GroundFlare = { Model: Model, Body: BasePart, Burn: number, Owner: Player?, SourceId: number?, BeaconId: number?, Active: boolean }
local flarePool: ObjectPool.Pool<GroundFlare>
local activeFlares: { GroundFlare } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function getInv(player: Player): Inv
	local inv = invs[player]
	if inv == nil then
		inv = {
			Slots = {},
			Active = 1,
			Clothing = Config.Items.DefaultClothing,
			Loadout = table.clone(Config.Items.DefaultLoadout),
			HandSource = nil,
			HandBeacon = nil,
			Held = nil,
			HeldId = nil,
		}
		invs[player] = inv
	end
	return inv
end

local function inRound(player: Player): boolean
	return Util.GetState(player) == "Alive"
end

----------------------------------------------------------------------
-- Attribute für die UI
----------------------------------------------------------------------
local function firstFlashlight(inv: Inv): Slot?
	for i = 1, Config.Items.BeltSlots do
		local s = inv.Slots[i]
		if s and s.Id == "Flashlight" then
			return s
		end
	end
	return nil
end

local function hasTwoHanded(inv: Inv): boolean
	for i = 1, Config.Items.BeltSlots do
		local s = inv.Slots[i]
		if s and Config.ItemInfo[s.Id] and Config.ItemInfo[s.Id].TwoHanded then
			return true
		end
	end
	return false
end

local function publish(player: Player, inv: Inv)
	for i = 1, Config.Items.BeltSlots do
		local s = inv.Slots[i]
		player:SetAttribute("Slot" .. i, if s then s.Id else "")
	end
	player:SetAttribute("ActiveSlot", inv.Active)
	player:SetAttribute("Clothing", inv.Clothing)
	player:SetAttribute("LoadoutItem1", inv.Loadout[1] or "")
	player:SetAttribute("LoadoutItem2", inv.Loadout[2] or "")
	local fl = firstFlashlight(inv)
	player:SetAttribute("FlashBattery", if fl then math.clamp((fl.Battery or 0) / Config.Items.Flashlight.Battery, 0, 1) else 0)
	local active = inv.Slots[inv.Active]
	local lit = active ~= nil and active.Id == "Flare" and active.Lit == true
	player:SetAttribute("FlareLit", lit)
	player:SetAttribute("FlareBurn", if active and active.Id == "Flare" and active.Lit then math.clamp((active.Burn or 0) / Config.Items.Flare.BurnTime, 0, 1) else 0)
	if fl == nil or hasTwoHanded(inv) then
		player:SetAttribute("FlashlightOn", false)
	end
end

----------------------------------------------------------------------
-- Licht und gehaltene Items am Charakter (für andere Spieler sichtbar)
----------------------------------------------------------------------
local function charPart(player: Player, name: string): BasePart?
	local char = Util.GetCharacter(player)
	if char then
		local p = char:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

local function setupCharacterLights(player: Player)
	local head = charPart(player, "Head")
	if head and head:FindFirstChild("LampAttachment") == nil then
		local att = Instance.new("Attachment")
		att.Name = "LampAttachment"
		att.Position = Vector3.new(0.4, 0, -0.6)
		att.Parent = head
		local spot = Instance.new("SpotLight")
		spot.Name = "Flashlight"
		spot.Range = Config.Items.Flashlight.Range
		spot.Angle = Config.Items.Flashlight.Angle
		spot.Brightness = Config.Items.Flashlight.Brightness
		spot.Color = Config.Items.Flashlight.Color
		spot.Face = Enum.NormalId.Front
		spot.Shadows = true
		spot.Enabled = false
		spot.Parent = att
	end
	local hand = charPart(player, "RightHand")
	if hand and hand:FindFirstChild("FlareAttachment") == nil then
		local att = Instance.new("Attachment")
		att.Name = "FlareAttachment"
		att.Position = Vector3.new(0, -0.6, -0.3)
		att.Parent = hand
		local light = Instance.new("PointLight")
		light.Name = "FlareLight"
		light.Color = Config.Items.Flare.LightColor
		light.Range = Config.Items.Flare.LightRange
		light.Brightness = Config.Items.Flare.LightBrightness
		light.Shadows = true
		light.Enabled = false
		light.Parent = att
		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "FlareSmoke"
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(Color3.fromRGB(255, 60, 50), Color3.fromRGB(120, 40, 40))
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 3) })
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		smoke.Lifetime = NumberRange.new(1.5, 2.5)
		smoke.Rate = 14
		smoke.Speed = NumberRange.new(1, 2)
		smoke.Acceleration = Vector3.new(0, 2, 0)
		smoke.Enabled = false
		smoke.Parent = att
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "FlareSparks"
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 150))
		sparks.Size = NumberSequence.new(0.15)
		sparks.LightEmission = 1
		sparks.Lifetime = NumberRange.new(0.3, 0.6)
		sparks.Rate = 30
		sparks.Speed = NumberRange.new(3, 6)
		sparks.SpreadAngle = Vector2.new(60, 60)
		sparks.Acceleration = Vector3.new(0, -20, 0)
		sparks.Enabled = false
		sparks.Parent = att
	end
end

local function updateLights(player: Player, inv: Inv)
	local head = charPart(player, "Head")
	local att = if head then head:FindFirstChild("LampAttachment") else nil
	local spot = if att then att:FindFirstChild("Flashlight") else nil
	if spot and spot:IsA("SpotLight") then
		spot.Enabled = player:GetAttribute("FlashlightOn") == true
	end
	local hand = charPart(player, "RightHand")
	local fatt = if hand then hand:FindFirstChild("FlareAttachment") else nil
	local lit = player:GetAttribute("FlareLit") == true
	if fatt then
		for _, c in fatt:GetChildren() do
			if c:IsA("Light") then
				c.Enabled = lit
			elseif c:IsA("ParticleEmitter") then
				c.Enabled = lit
			end
		end
	end
end

local function updateHeld(player: Player, inv: Inv)
	local active = inv.Slots[inv.Active]
	local id = if active then active.Id else nil
	if inv.HeldId == id and inv.Held and inv.Held.Parent then
		return
	end
	if inv.Held then
		inv.Held:Destroy()
		inv.Held = nil
	end
	inv.HeldId = id
	local hand = charPart(player, "RightHand")
	if id == nil or hand == nil then
		return
	end
	local model = ItemModels.Build(id)
	model.Name = "HeldItem"
	local handle = model.PrimaryPart :: BasePart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.Massless = true
			d.CollisionGroup = Config.CollisionGroups.Limbs
		end
	end
	local offset = if id == "Diesel" then CFrame.new(0, -1.4, 0) else CFrame.new(0, -0.8, -0.35) * CFrame.Angles(math.rad(-90), 0, 0)
	handle.CFrame = hand.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = hand
	w.Part1 = handle
	w.Parent = handle
	model.Parent = Util.GetCharacter(player)
	inv.Held = model
end

local function refresh(player: Player)
	local inv = getInv(player)
	publish(player, inv)
	updateLights(player, inv)
	updateHeld(player, inv)
	MovementService.RefreshSpeed(player)
end

----------------------------------------------------------------------
-- Fackel in der Hand: Wärmequelle und Leuchtfeuer
----------------------------------------------------------------------
local function clearHandFlare(inv: Inv)
	if inv.HandSource then
		TemperatureService.RemoveSource(inv.HandSource)
		inv.HandSource = nil
	end
	if inv.HandBeacon then
		NoiseService.RemoveBeacon(inv.HandBeacon)
		inv.HandBeacon = nil
	end
end

local function ensureHandFlare(player: Player, inv: Inv)
	local active = inv.Slots[inv.Active]
	local lit = active ~= nil and active.Id == "Flare" and active.Lit == true
	if not lit then
		clearHandFlare(inv)
		return
	end
	local hand = charPart(player, "RightHand")
	if hand == nil then
		return
	end
	if inv.HandSource == nil then
		inv.HandSource = TemperatureService.AddSource("FlareHand", hand.Position, hand, player, true)
	end
	if inv.HandBeacon == nil then
		local id = NoiseService.AddBeacon("Flare", hand.Position, hand, player)
		NoiseService.SetBeaconActive(id, true)
		inv.HandBeacon = id
	end
end

----------------------------------------------------------------------
-- Boden-Fackeln (Pool, Abschnitt 13.2: nie in der Runde neu erzeugen)
----------------------------------------------------------------------
local function createGroundFlare(): GroundFlare
	local model = ItemModels.Build("Flare")
	model.Name = "GroundFlare"
	local body = model.PrimaryPart :: BasePart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= body then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = body
			w.Part1 = d
			w.Parent = d
		end
	end
	body.CanCollide = true
	body.CanQuery = false
	body.CollisionGroup = Config.CollisionGroups.Items
	body.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.9, 0.05, 1, 1)
	local light = Instance.new("PointLight")
	light.Name = "FlareLight"
	light.Color = Config.Items.Flare.LightColor
	light.Range = Config.Items.Flare.LightRange
	light.Brightness = Config.Items.Flare.LightBrightness
	light.Shadows = true
	light.Parent = body
	body:AddTag("DynamicLight")
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(255, 50, 40), Color3.fromRGB(110, 30, 30))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(2, 3.5)
	smoke.Rate = 22
	smoke.Speed = NumberRange.new(1, 3)
	smoke.Acceleration = Vector3.new(0, 2.5, 0)
	smoke.Parent = body
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 210, 160))
	sparks.Size = NumberSequence.new(0.2)
	sparks.LightEmission = 1
	sparks.Lifetime = NumberRange.new(0.3, 0.7)
	sparks.Rate = 40
	sparks.Speed = NumberRange.new(4, 8)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Acceleration = Vector3.new(0, -25, 0)
	sparks.Parent = body
	model.Parent = flarePoolFolder
	return { Model = model, Body = body, Burn = 0, Owner = nil, SourceId = nil, BeaconId = nil, Active = false }
end

local function resetGroundFlare(f: GroundFlare)
	f.Active = false
	f.Owner = nil
	if f.SourceId then
		TemperatureService.RemoveSource(f.SourceId)
		f.SourceId = nil
	end
	if f.BeaconId then
		NoiseService.RemoveBeacon(f.BeaconId)
		f.BeaconId = nil
	end
	f.Body.Anchored = true
	f.Body.AssemblyLinearVelocity = Vector3.zero
	f.Model.Parent = flarePoolFolder
	f.Model:SetAttribute("OwnerUserId", 0)
end

local function releaseFlare(f: GroundFlare)
	local idx = table.find(activeFlares, f)
	if idx then
		table.remove(activeFlares, idx)
	end
	flarePool:Release(f)
end

local function launchFlare(player: Player?, from: Vector3, velocity: Vector3, burn: number)
	local f = flarePool:Get()
	if f == nil then
		return
	end
	f.Active = true
	f.Burn = burn
	f.Owner = player
	f.Model:SetAttribute("OwnerUserId", if player then player.UserId else 0)
	f.Body.CFrame = CFrame.new(from) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
	f.Model.Parent = itemsFolder
	f.Body.Anchored = false
	pcall(function()
		f.Body:SetNetworkOwner(nil)
	end)
	f.Body.AssemblyLinearVelocity = velocity
	f.Body.AssemblyAngularVelocity = Vector3.new(math.random() * 10 - 5, math.random() * 10 - 5, math.random() * 10 - 5)
	f.SourceId = TemperatureService.AddSource("FlareGround", from, f.Body, player, true)
	local beacon = NoiseService.AddBeacon("Flare", from, f.Body, player)
	NoiseService.SetBeaconActive(beacon, true)
	f.BeaconId = beacon
	table.insert(activeFlares, f)
	NoiseService.PlaySound("FlareBurn", from, 0.7)
	-- nach der Landung (kurz warten) das Ereignis melden
	task.delay(1.2, function()
		if f.Active and f.BeaconId == beacon then
			InventoryService.FlareLanded:Fire(player, f.Body, beacon)
		end
	end)
end

function InventoryService.GetActiveGroundFlares(): { BasePart }
	local out: { BasePart } = {}
	for _, f in activeFlares do
		table.insert(out, f.Body)
	end
	return out
end

function InventoryService.ClearGroundFlares()
	for _, f in table.clone(activeFlares) do
		releaseFlare(f)
	end
end

----------------------------------------------------------------------
-- Welt-Items
----------------------------------------------------------------------
local function takeFromCache(id: string): Model
	local list = itemCache[id]
	if list and #list > 0 then
		return table.remove(list) :: Model
	end
	local model = ItemModels.Build(id)
	local handle = model.PrimaryPart :: BasePart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d == handle
			d.CanCollide = false
			d.CanTouch = false
			d.CastShadow = false
			d.CollisionGroup = Config.CollisionGroups.Items
		end
	end
	handle.CanQuery = true
	local info = Config.ItemInfo[id]
	local prompt = MapService.MakePrompt(handle, {
		Name = "PickupPrompt",
		ActionText = "Pick up",
		ObjectText = if info then info.Name else id,
		MaxDistance = Config.Prompt.ItemMaxDistance,
	})
	prompt.Triggered:Connect(function(player: Player)
		InventoryService.PickUp(player, model)
	end)
	return model
end

local function returnToCache(model: Model)
	local id = model:GetAttribute("ItemId")
	if type(id) ~= "string" then
		model:Destroy()
		return
	end
	model.Parent = cacheFolder
	local list = itemCache[id]
	if list == nil then
		list = {}
		itemCache[id] = list
	end
	table.insert(list, model)
end

function InventoryService.SpawnWorldItem(id: string, cf: CFrame, data: Slot?): Model
	local model = takeFromCache(id)
	local handle = model.PrimaryPart :: BasePart
	-- Alle Teile relativ zum Handle verschieben (Handle verankert, Rest geschweißt)
	handle.CFrame = cf
	model:SetAttribute("Battery", if data and data.Battery then data.Battery else nil)
	model:SetAttribute("Burn", if data and data.Burn then data.Burn else nil)
	model.Parent = itemsFolder
	return model
end

function InventoryService.ClearWorldItems()
	for _, m in itemsFolder:GetChildren() do
		if m:IsA("Model") and m.Name ~= "GroundFlare" then
			returnToCache(m)
		end
	end
	InventoryService.ClearGroundFlares()
end

-- Bodenposition vor dem Spieler
local function groundPointNear(player: Player, forward: number): CFrame?
	local root = Util.GetRoot(player)
	if root == nil then
		return nil
	end
	local look = root.CFrame.LookVector
	local origin = root.Position + Vector3.new(look.X, 0, look.Z).Unit * forward + Vector3.new(0, 1, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { itemsFolder }
	local char = Util.GetCharacter(player)
	if char then
		table.insert(ignore, char)
	end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(origin, Vector3.new(0, -12, 0), params)
	local pos = if hit then hit.Position else root.Position - Vector3.new(0, 2.5, 0)
	return CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
end

----------------------------------------------------------------------
-- Gürtel
----------------------------------------------------------------------
function InventoryService.FindItem(player: Player, id: string): number?
	local inv = getInv(player)
	for i = 1, Config.Items.BeltSlots do
		local s = inv.Slots[i]
		if s and s.Id == id then
			return i
		end
	end
	return nil
end

function InventoryService.HasItem(player: Player, id: string): boolean
	return InventoryService.FindItem(player, id) ~= nil
end

function InventoryService.FreeSlot(player: Player): number?
	local inv = getInv(player)
	for i = 1, Config.Items.BeltSlots do
		if inv.Slots[i] == nil then
			return i
		end
	end
	return nil
end

function InventoryService.GiveItem(player: Player, slot: Slot): boolean
	local inv = getInv(player)
	local idx = InventoryService.FreeSlot(player)
	if idx == nil then
		return false
	end
	if slot.Id == "Flashlight" and slot.Battery == nil then
		slot.Battery = Config.Items.Flashlight.Battery
	end
	inv.Slots[idx] = slot
	refresh(player)
	return true
end

function InventoryService.TakeItem(player: Player, id: string): Slot?
	local inv = getInv(player)
	local idx = InventoryService.FindItem(player, id)
	if idx == nil then
		return nil
	end
	local s = inv.Slots[idx]
	inv.Slots[idx] = nil
	if idx == inv.Active then
		clearHandFlare(inv)
	end
	refresh(player)
	return s
end

function InventoryService.TakeSlot(player: Player, idx: number): Slot?
	local inv = getInv(player)
	local s = inv.Slots[idx]
	if s == nil then
		return nil
	end
	inv.Slots[idx] = nil
	if idx == inv.Active then
		clearHandFlare(inv)
	end
	refresh(player)
	return s
end

-- Alles abgeben (Tod: Items gehen an die Leiche)
function InventoryService.TakeAll(player: Player): { Slot }
	local inv = getInv(player)
	local out: { Slot } = {}
	for i = 1, Config.Items.BeltSlots do
		local s = inv.Slots[i]
		if s then
			if s.Id == "Flare" and s.Lit then
				-- brennende Fackel fällt zu Boden
				local root = Util.GetRoot(player)
				if root then
					launchFlare(player, root.Position, Vector3.zero, s.Burn or 0)
				end
			else
				table.insert(out, s)
			end
		end
		inv.Slots[i] = nil
	end
	clearHandFlare(inv)
	player:SetAttribute("FlashlightOn", false)
	refresh(player)
	return out
end

function InventoryService.PickUp(player: Player, model: Model)
	if not inRound(player) or model.Parent ~= itemsFolder then
		return
	end
	local id = model:GetAttribute("ItemId")
	if type(id) ~= "string" then
		return
	end
	local root = Util.GetRoot(player)
	local handle = model.PrimaryPart
	if root == nil or handle == nil or (root.Position - handle.Position).Magnitude > Config.Items.PickupRange then
		return
	end
	local slot: Slot = { Id = id }
	local bat = model:GetAttribute("Battery")
	if type(bat) == "number" then
		slot.Battery = bat
	end
	if not InventoryService.GiveItem(player, slot) then
		Net.Event("Notify"):FireClient(player, "BELT FULL")
		return
	end
	returnToCache(model)
	NoiseService.PlaySound("Pickup", handle.Position, 0.6)
end

function InventoryService.ResetPlayer(player: Player)
	local inv = getInv(player)
	inv.Slots = {}
	inv.Active = 1
	clearHandFlare(inv)
	player:SetAttribute("FlashlightOn", false)
	player:SetAttribute("HandWarmerUntil", 0)
	player:SetAttribute("ScanPingUntil", 0)
	player:SetAttribute("ScannerReadyAt", 0)
	player:SetAttribute("InjectorUntil", 0)
	refresh(player)
end

-- Rundenstart: Spind-Auswahl anwenden (Kleidung + 2 Start-Items)
function InventoryService.ApplyLoadout(player: Player)
	local inv = getInv(player)
	InventoryService.ResetPlayer(player)
	for i, id in inv.Loadout do
		if i <= Config.Items.LoadoutItems then
			local s: Slot = { Id = id }
			if id == "Flashlight" then
				s.Battery = Config.Items.Flashlight.Battery
			end
			inv.Slots[i] = s
		end
	end
	inv.Active = 1
	refresh(player)
end

----------------------------------------------------------------------
-- Aktionen
----------------------------------------------------------------------
local function dropLitFlareFromHand(player: Player, inv: Inv)
	local active = inv.Slots[inv.Active]
	if active and active.Id == "Flare" and active.Lit then
		inv.Slots[inv.Active] = nil
		clearHandFlare(inv)
		local hand = charPart(player, "RightHand")
		if hand then
			launchFlare(player, hand.Position, Vector3.new(0, -2, 0), active.Burn or 0)
		end
	end
end

local function selectSlot(player: Player, n: number)
	local inv = getInv(player)
	if n == inv.Active then
		return
	end
	dropLitFlareFromHand(player, inv)
	inv.Active = n
	refresh(player)
end

local function toggleFlashlight(player: Player)
	local inv = getInv(player)
	local fl = firstFlashlight(inv)
	if fl == nil then
		return
	end
	local on = player:GetAttribute("FlashlightOn") == true
	if not on then
		if hasTwoHanded(inv) then
			Net.Event("Notify"):FireClient(player, "HANDS FULL")
			return
		end
		if (fl.Battery or 0) <= 0 then
			Net.Event("Notify"):FireClient(player, "BATTERY EMPTY")
			return
		end
	end
	player:SetAttribute("FlashlightOn", not on)
	refresh(player)
	local root = Util.GetRoot(player)
	if root then
		NoiseService.PlaySound("UiClick", root.Position, 0.4)
	end
end

local function useScanner(player: Player)
	if not InventoryService.HasItem(player, "Scanner") then
		return
	end
	local t = now()
	if Util.NumAttr(player, "ScannerReadyAt", 0) > t then
		return
	end
	local root = Util.GetRoot(player)
	if root == nil then
		return
	end
	local SC = Config.Items.Scanner
	player:SetAttribute("ScannerReadyAt", t + SC.Cooldown)
	player:SetAttribute("ScanPingUntil", t + Config.Signature.Items.ScannerPingTime)
	NoiseService.Emit(root.Position, SC.PingNoise, "ScannerPing", player)
	NoiseService.PlaySound("ScannerPing", root.Position, 0.8, 1, 30)
	-- Ergebnis: Wesen und Wärmequellen im Umkreis von 80 Studs (durch Wände)
	local results: { { Kind: string, Target: Instance?, Position: Vector3 } } = {}
	for _, c in game:GetService("CollectionService"):GetTagged("Creature") do
		if c:IsA("Model") and c.PrimaryPart and c:GetAttribute("InVent") ~= true then
			local p = c.PrimaryPart.Position
			if (p - root.Position).Magnitude <= SC.Radius then
				table.insert(results, { Kind = "Creature", Target = c :: Instance, Position = p })
			end
		end
	end
	for _, p in TemperatureService.GetActiveSourcePositions() do
		if (p - root.Position).Magnitude <= SC.Radius then
			table.insert(results, { Kind = "Heat", Target = nil, Position = p })
		end
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and (Util.GetState(other) == "Alive" or Util.GetState(other) == "Downed") then
			local oroot = Util.GetRoot(other)
			local ochar = Util.GetCharacter(other)
			if oroot and ochar and (oroot.Position - root.Position).Magnitude <= SC.Radius then
				table.insert(results, { Kind = "Player", Target = ochar :: Instance, Position = oroot.Position })
			end
		end
	end
	Net.Event("ScannerResult"):FireClient(player, results, SC.Duration)
end

local function useItem(player: Player)
	local inv = getInv(player)
	local s = inv.Slots[inv.Active]
	if s == nil then
		return
	end
	local t = now()
	local id = s.Id
	if id == "Flashlight" then
		toggleFlashlight(player)
	elseif id == "Scanner" then
		useScanner(player)
	elseif id == "Flare" then
		if not s.Lit then
			s.Lit = true
			s.Burn = Config.Items.Flare.BurnTime
			refresh(player)
			ensureHandFlare(player, inv)
			local root = Util.GetRoot(player)
			if root then
				NoiseService.PlaySound("FlareBurn", root.Position, 0.8)
				NoiseService.Emit(root.Position, 6, "FlareIgnite", player)
			end
		end
	elseif id == "HandWarmer" then
		inv.Slots[inv.Active] = nil
		player:SetAttribute("HandWarmerUntil", t + Config.Temperature.HandWarmerDuration)
		refresh(player)
	elseif id == "Battery" then
		local fl = firstFlashlight(inv)
		if fl then
			fl.Battery = Config.Items.Flashlight.Battery
			inv.Slots[inv.Active] = nil
			refresh(player)
			Net.Event("Notify"):FireClient(player, "FLASHLIGHT RECHARGED")
		else
			Net.Event("Notify"):FireClient(player, "NO FLASHLIGHT")
		end
	elseif id == "Injector" then
		local hook = InventoryService.ReviveHook
		local revived = hook ~= nil and hook(player)
		if not revived then
			TemperatureService.AddTemp(player, Config.Temperature.InjectorBoost)
		end
		player:SetAttribute("InjectorUntil", t + Config.Signature.Items.InjectorTime)
		inv.Slots[inv.Active] = nil
		refresh(player)
	end
end

local function throwItem(player: Player, dir: Vector3)
	local inv = getInv(player)
	local s = inv.Slots[inv.Active]
	if s == nil or s.Id ~= "Flare" then
		return
	end
	local root = Util.GetRoot(player)
	if root == nil then
		return
	end
	local burn = if s.Lit then (s.Burn or 0) else Config.Items.Flare.BurnTime
	inv.Slots[inv.Active] = nil
	clearHandFlare(inv)
	refresh(player)
	-- ballistische Bahn: landet ca. 40 Studs entfernt (oder an der ersten Wand)
	local head = charPart(player, "Head")
	local from = (if head then head.Position else root.Position + Vector3.new(0, 1.5, 0)) + dir * 1.5
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { itemsFolder }
	local char = Util.GetCharacter(player)
	if char then
		table.insert(ignore, char)
	end
	params.FilterDescendantsInstances = ignore
	local maxDist = Config.Items.Flare.ThrowDistance
	local hit = Workspace:Raycast(from, dir * maxDist, params)
	local target = if hit then hit.Position - dir * 1.0 else from + dir * maxDist
	local delta = target - from
	local flight = math.max(0.35, delta.Magnitude / Config.Items.Flare.ThrowSpeed)
	local g = Workspace.Gravity
	local vel = delta / flight + Vector3.new(0, 0.5 * g * flight, 0)
	launchFlare(player, from, vel, burn)
	NoiseService.Emit(root.Position, 4, "Throw", player)
end

local function dropItem(player: Player)
	local inv = getInv(player)
	local s = inv.Slots[inv.Active]
	if s == nil then
		return
	end
	local root = Util.GetRoot(player)
	if root == nil then
		return
	end
	if s.Id == "Flare" and s.Lit then
		dropLitFlareFromHand(player, inv)
		refresh(player)
		return
	end
	local cf = groundPointNear(player, Config.Items.DropDistance)
	if cf == nil then
		return
	end
	inv.Slots[inv.Active] = nil
	refresh(player)
	InventoryService.SpawnWorldItem(s.Id, cf, s)
	local isVial = string.sub(s.Id, 1, 4) == "Vial"
	local radius = if isVial then Config.Items.VialDropNoiseRadius else Config.Items.DropNoiseRadius
	NoiseService.EmitWithSound(cf.Position, radius, "Drop", if isVial then "Clink" else "ItemDrop", player)
end

local function chooseLoadout(player: Player, clothing: unknown, item1: unknown, item2: unknown)
	if Util.GetState(player) ~= "Lobby" then
		return
	end
	if type(clothing) ~= "string" or type(item1) ~= "string" or type(item2) ~= "string" then
		return
	end
	if not table.find(Config.Items.ClothingChoices, clothing) then
		return
	end
	local choices = Config.Items.LoadoutChoices
	if not table.find(choices, item1) or not table.find(choices, item2) then
		return
	end
	-- Fackeln: max. 2 (beide Start-Slots); andere Items nur einmal
	if item1 == item2 and item1 ~= "Flare" then
		return
	end
	local inv = getInv(player)
	inv.Clothing = clothing
	inv.Loadout = { item1, item2 }
	publish(player, inv)
	Net.Event("Notify"):FireClient(player, "LOADOUT SAVED")
end

----------------------------------------------------------------------
-- Takt: Batterie, Fackel-Brenndauer
----------------------------------------------------------------------
local function tickPlayer(player: Player, dt: number)
	local inv = invs[player]
	if inv == nil then
		return
	end
	local changed = false
	if player:GetAttribute("FlashlightOn") == true then
		local fl = firstFlashlight(inv)
		if fl then
			fl.Battery = math.max(0, (fl.Battery or 0) - dt)
			if fl.Battery <= 0 then
				player:SetAttribute("FlashlightOn", false)
				Net.Event("Notify"):FireClient(player, "BATTERY EMPTY")
			end
			changed = true
		end
	end
	local active = inv.Slots[inv.Active]
	if active and active.Id == "Flare" and active.Lit then
		active.Burn = (active.Burn or 0) - dt
		if active.Burn <= 0 then
			inv.Slots[inv.Active] = nil
			clearHandFlare(inv)
		end
		changed = true
	end
	if changed then
		refresh(player)
	end
	ensureHandFlare(player, inv)
end

function InventoryService.Init()
	itemsFolder = Instance.new("Folder")
	itemsFolder.Name = "Items"
	itemsFolder.Parent = Workspace
	cacheFolder = Instance.new("Folder")
	cacheFolder.Name = "ItemCache"
	cacheFolder.Parent = ServerStorage
	flarePoolFolder = Instance.new("Folder")
	flarePoolFolder.Name = "FlarePool"
	flarePoolFolder.Parent = ServerStorage
	flarePool = ObjectPool.new(Config.Items.Flare.PoolSize, createGroundFlare, resetGroundFlare, true)
	-- Item-Cache vorwärmen (keine Erzeugung während der Runde)
	for id, _ in Config.ItemInfo do
		local list: { Model } = {}
		for _ = 1, 3 do
			local m = takeFromCache(id)
			m.Parent = cacheFolder
			table.insert(list, m)
		end
		itemCache[id] = list
	end
end

function InventoryService.Start()
	Net.Event("SelectSlot").OnServerEvent:Connect(function(player: Player, n: unknown)
		if type(n) == "number" and n == math.floor(n) and n >= 1 and n <= Config.Items.BeltSlots and inRound(player) then
			selectSlot(player, n)
		end
	end)
	Net.Event("UseItem").OnServerEvent:Connect(function(player: Player)
		if inRound(player) and player:GetAttribute("InLocker") ~= true then
			useItem(player)
		end
	end)
	Net.Event("ThrowItem").OnServerEvent:Connect(function(player: Player, dir: unknown)
		if typeof(dir) ~= "Vector3" or not inRound(player) or player:GetAttribute("InLocker") == true then
			return
		end
		local d = dir :: Vector3
		if d.Magnitude < 0.5 or d.Magnitude > 1.5 or d ~= d then
			return
		end
		throwItem(player, d.Unit)
	end)
	Net.Event("DropItem").OnServerEvent:Connect(function(player: Player)
		if inRound(player) and player:GetAttribute("InLocker") ~= true then
			dropItem(player)
		end
	end)
	Net.Event("ToggleFlashlight").OnServerEvent:Connect(function(player: Player)
		if inRound(player) then
			toggleFlashlight(player)
		end
	end)
	Net.Event("UseScanner").OnServerEvent:Connect(function(player: Player)
		if inRound(player) and player:GetAttribute("InLocker") ~= true then
			useScanner(player)
		end
	end)
	Net.Event("ChooseLoadout").OnServerEvent:Connect(chooseLoadout)

	local function onPlayer(player: Player)
		local inv = getInv(player)
		publish(player, inv)
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("Head", 10)
			char:WaitForChild("RightHand", 10)
			setupCharacterLights(player)
			inv.Held = nil
			inv.HeldId = nil
			refresh(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		local inv = invs[player]
		if inv then
			clearHandFlare(inv)
		end
		invs[player] = nil
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.25)
			local t = os.clock()
			local dt = t - last
			last = t
			for player in invs do
				if player.Parent then
					Util.Try("InventoryService", function()
						tickPlayer(player, dt)
					end)
				end
			end
			-- Boden-Fackeln abbrennen lassen
			for _, f in table.clone(activeFlares) do
				f.Burn -= dt
				if f.Burn <= 0 or f.Body.Position.Y < Config.Health.FallKillY - 40 then
					releaseFlare(f)
				end
			end
		end
	end)
end

return InventoryService
