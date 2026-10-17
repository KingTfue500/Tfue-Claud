--!strict
-- SUB-ZERO: THE HEAT HUNTER - Server-Einstieg
-- Lädt alle Services: zuerst Init() (Aufbau), dann Start() (Ereignisse, Schleifen).

local Lighting = game:GetService("Lighting")
local ServerScriptService = game:GetService("ServerScriptService")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")

local Services = ServerScriptService:WaitForChild("Services")

-- Licht-Effekte und SoundGroups sicherstellen (falls die Place-Datei ohne Bake gebaut wurde)
local function ensureEnvironment()
	if Lighting:FindFirstChildOfClass("Atmosphere") == nil then
		local atm = Instance.new("Atmosphere")
		atm.Density = 0.25
		atm.Haze = 0.5
		atm.Parent = Lighting
	end
	if Lighting:FindFirstChild("ZoneGrade") == nil then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "ZoneGrade"
		cc.Parent = Lighting
	end
	if Lighting:FindFirstChildOfClass("BloomEffect") == nil then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.6
		bloom.Size = 28
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
	end
	if Lighting:FindFirstChildOfClass("Sky") == nil then
		local sky = Instance.new("Sky")
		sky.StarCount = 0
		sky.CelestialBodiesShown = false
		sky.Parent = Lighting
	end
	for _, name in { "Effects", "Ambience", "Creature", "Biometrics", "Interface", "Music" } do
		if SoundService:FindFirstChild(name) == nil then
			local g = Instance.new("SoundGroup")
			g.Name = name
			g.Parent = SoundService
		end
	end
	StarterPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
end

ensureEnvironment()

type Service = { Name: string, Init: () -> (), Start: () -> () }

-- Reihenfolge = Abhängigkeiten (untere Services nutzen obere)
local services: { Service } = {
	require(Services.MapService),
	require(Services.NoiseService),
	require(Services.StatsService),
	require(Services.DataService),
	require(Services.TemperatureService),
	require(Services.MovementService),
	require(Services.InventoryService),
	require(Services.HealthService),
	require(Services.EntityService),
	require(Services.PuzzleService),
	require(Services.RoundService),
}

for _, service in services do
	service.Init()
end
for _, service in services do
	service.Start()
	print("[SubZero] " .. service.Name .. " Started")
end
