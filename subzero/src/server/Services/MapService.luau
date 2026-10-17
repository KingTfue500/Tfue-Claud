--!strict
-- MapService: stellt sicher, dass die Map existiert, registriert Kollisionsgruppen,
-- steuert Türen (öffnen, schließen, aufbrechen) und erzeugt ProximityPrompts.

local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)

local MapService = {}
MapService.Name = "MapService"

MapService.DoorOpened = Signal.new() :: Signal.Signal<Model>

local map: Model? = nil
local doors: { [string]: Model } = {}
local normalPanels: { Instance } = {}

export type PromptSpec = {
	ActionText: string,
	ObjectText: string?,
	HoldDuration: number?,
	MaxDistance: number?,
	Enabled: boolean?,
	Name: string?,
	KeyboardKeyCode: Enum.KeyCode?,
}

function MapService.GetMap(): Model
	assert(map, "Map not ready")
	return map
end

-- Alle getaggten Instanzen innerhalb der Map
function MapService.GetTagged(tag: string): { Instance }
	local out: { Instance } = {}
	local m = map
	if m == nil then
		return out
	end
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsDescendantOf(m) then
			table.insert(out, inst)
		end
	end
	return out
end

function MapService.GetTaggedParts(tag: string): { BasePart }
	local out: { BasePart } = {}
	for _, inst in MapService.GetTagged(tag) do
		if inst:IsA("BasePart") then
			table.insert(out, inst)
		end
	end
	return out
end

function MapService.GetTaggedModels(tag: string): { Model }
	local out: { Model } = {}
	for _, inst in MapService.GetTagged(tag) do
		if inst:IsA("Model") then
			table.insert(out, inst)
		end
	end
	return out
end

function MapService.FindPart(parent: Instance, name: string): BasePart?
	local p = parent:FindFirstChild(name, true)
	if p and p:IsA("BasePart") then
		return p
	end
	return nil
end

function MapService.RequirePart(parent: Instance, name: string): BasePart
	local p = MapService.FindPart(parent, name)
	assert(p, "missing part " .. name .. " in " .. parent:GetFullName())
	return p
end

function MapService.ModelPosition(model: Model): Vector3
	if model.PrimaryPart then
		return model.PrimaryPart.Position
	end
	local p = model:FindFirstChildWhichIsA("BasePart", true)
	if p then
		return p.Position
	end
	return Vector3.zero
end

----------------------------------------------------------------------
-- ProximityPrompts (eigener Stil: der Client zeichnet das CRT-Fenster)
----------------------------------------------------------------------
function MapService.MakePrompt(parent: Instance, spec: PromptSpec): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = spec.Name or "Prompt"
	p.ActionText = spec.ActionText
	p.ObjectText = spec.ObjectText or ""
	p.HoldDuration = spec.HoldDuration or 0
	p.MaxActivationDistance = spec.MaxDistance or Config.Prompt.MaxDistance
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p.KeyboardKeyCode = spec.KeyboardKeyCode or Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.Enabled = spec.Enabled ~= false
	p.Parent = parent
	return p
end

----------------------------------------------------------------------
-- Bewegliche Teile: Details mit Attribut "PanelOffset" werden an das Paneel geschweißt
----------------------------------------------------------------------
local function weldDetails(model: Model, panel: BasePart)
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and d ~= panel and d:GetAttribute("PanelOffset") ~= nil then
			d.Anchored = false
			d.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = panel
			w.Part1 = d
			w.Parent = d
		end
	end
end

function MapService.TweenCFrame(part: BasePart, target: CFrame, duration: number, style: Enum.EasingStyle?): Tween
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local tw = TweenService:Create(part, info, { CFrame = target })
	tw:Play()
	return tw
end

local function attrCF(part: BasePart, name: string): CFrame
	local v = part:GetAttribute(name)
	if typeof(v) == "CFrame" then
		return v
	end
	return part.CFrame
end

----------------------------------------------------------------------
-- Türen
----------------------------------------------------------------------
function MapService.GetDoor(name: string): Model?
	return doors[name]
end

function MapService.GetNormalDoorPanels(): { Instance }
	return normalPanels
end

local function panelOf(door: Model): BasePart
	return MapService.RequirePart(door, "Panel")
end

local function setPrompt(door: Model)
	local anchor = door:FindFirstChild("PromptAnchor")
	if anchor == nil then
		return
	end
	local prompt = anchor:FindFirstChild("DoorPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		local open = door:GetAttribute("Open") == true
		local broken = door:GetAttribute("Broken") == true
		prompt.ActionText = if open then "Close" else "Open"
		prompt.Enabled = not broken
	end
end

function MapService.OpenDoor(door: Model, duration: number?)
	if door:GetAttribute("Open") == true then
		return
	end
	local panel = panelOf(door)
	door:SetAttribute("Open", true)
	panel:SetAttribute("ThermalBlock", false)
	local d = duration or Config.Doors.NormalOpenTime
	local tw = MapService.TweenCFrame(panel, attrCF(panel, "OpenCF"), d, Enum.EasingStyle.Sine)
	tw.Completed:Once(function()
		if door:GetAttribute("Open") == true then
			panel.CanCollide = false
		end
	end)
	setPrompt(door)
	MapService.DoorOpened:Fire(door)
end

function MapService.CloseDoor(door: Model, duration: number?)
	if door:GetAttribute("Open") ~= true or door:GetAttribute("Broken") == true then
		return
	end
	local panel = panelOf(door)
	door:SetAttribute("Open", false)
	panel:SetAttribute("ThermalBlock", true)
	panel.CanCollide = true
	MapService.TweenCFrame(panel, attrCF(panel, "ClosedCF"), duration or Config.Doors.NormalOpenTime, Enum.EasingStyle.Sine)
	setPrompt(door)
end

-- Das Wesen bricht eine normale Tür auf: sie bleibt offen und hängt schief
function MapService.BreakDoor(door: Model)
	local panel = panelOf(door)
	door:SetAttribute("Broken", true)
	door:SetAttribute("Open", true)
	panel:SetAttribute("ThermalBlock", false)
	panel.CanCollide = false
	local open = attrCF(panel, "OpenCF")
	MapService.TweenCFrame(panel, open * CFrame.Angles(0, 0, math.rad(Config.Doors.BrokenTilt)), 0.25, Enum.EasingStyle.Back)
	setPrompt(door)
	MapService.DoorOpened:Fire(door)
end

function MapService.ResetDoor(door: Model)
	local panel = panelOf(door)
	local kind = door:GetAttribute("DoorKind")
	door:SetAttribute("Open", false)
	door:SetAttribute("Broken", false)
	door:SetAttribute("Locked", kind ~= "Normal" and kind ~= "Airlock")
	panel:SetAttribute("ThermalBlock", true)
	panel.CanCollide = true
	panel.CFrame = attrCF(panel, "ClosedCF")
	setPrompt(door)
end

function MapService.ResetAllDoors()
	for _, door in doors do
		MapService.ResetDoor(door)
	end
end

local function setupDoors()
	for _, door in MapService.GetTaggedModels("Door") do
		local name = string.gsub(string.gsub(door.Name, "^Door_", ""), "_PH$", "")
		doors[name] = door
		local panel = panelOf(door)
		weldDetails(door, panel)
		if door:GetAttribute("DoorKind") == "Normal" then
			table.insert(normalPanels, panel)
			local anchor = door:FindFirstChild("PromptAnchor")
			if anchor then
				local prompt = MapService.MakePrompt(anchor, { Name = "DoorPrompt", ActionText = "Open", ObjectText = "Door", MaxDistance = 7 })
				prompt.Triggered:Connect(function(_player: Player)
					if door:GetAttribute("Broken") == true then
						return
					end
					if door:GetAttribute("Open") == true then
						MapService.CloseDoor(door)
					else
						MapService.OpenDoor(door)
					end
				end)
			end
		end
	end
end

----------------------------------------------------------------------
-- Kollisionsgruppen (Abschnitt 5.1: Wärme-Strahlen ignorieren Glas, Gitter, Props)
----------------------------------------------------------------------
local function setupCollisionGroups()
	local G = Config.CollisionGroups
	for _, name in { G.Players, G.Limbs, G.Creature, G.ThermalClear, G.ThermalRay, G.Items } do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	local all = { "Default", G.Players, G.Limbs, G.Creature, G.ThermalClear, G.ThermalRay, G.Items }
	for _, other in all do
		PhysicsService:CollisionGroupSetCollidable(G.Limbs, other, false)
	end
	PhysicsService:CollisionGroupSetCollidable(G.Players, G.Players, false)
	PhysicsService:CollisionGroupSetCollidable(G.Players, G.Creature, false)
	PhysicsService:CollisionGroupSetCollidable(G.Players, G.Items, false)
	PhysicsService:CollisionGroupSetCollidable(G.Creature, G.Items, false)
	PhysicsService:CollisionGroupSetCollidable(G.Items, G.Items, false)
	-- Strahlen: nur Wände (Default) blockieren
	for _, other in { G.ThermalClear, G.Players, G.Creature, G.Items, G.ThermalRay } do
		PhysicsService:CollisionGroupSetCollidable(G.ThermalRay, other, false)
	end
end

local function reapplyGroups(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local g = d.CollisionGroup
			if g ~= "Default" then
				d.CollisionGroup = g
			end
			-- Platzhalter-Materialien durch eigene MaterialVariants ersetzen, falls angelegt
			local kitName = d:GetAttribute("MaterialKit")
			if type(kitName) == "string" then
				local variant = MaterialService:FindFirstChild(kitName)
				if variant and variant:IsA("MaterialVariant") then
					d.MaterialVariant = kitName
				end
			end
		end
	end
end

function MapService.Init()
	setupCollisionGroups()
	local existing = Workspace:FindFirstChild("Map")
	if existing and existing:IsA("Model") then
		map = existing
	else
		-- Map fehlt (z. B. reiner Rojo-Sync ohne Bake): zur Laufzeit bauen
		local builderModule = ServerStorage:FindFirstChild("MapBuilder")
		assert(builderModule and builderModule:IsA("ModuleScript"), "MapBuilder missing")
		local builder = (require :: any)(builderModule)
		map = builder.Build(Workspace, Config)
	end
	local m = map :: Model
	reapplyGroups(m)
	m:SetAttribute("PowerState", "On")
	m:SetAttribute("GeneratorOn", false)
	m:SetAttribute("HatchesOpen", false)
	setupDoors()
end

function MapService.Start() end

return MapService
