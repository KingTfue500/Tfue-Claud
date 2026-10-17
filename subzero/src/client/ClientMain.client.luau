--!strict
-- SUB-ZERO: THE HEAT HUNTER - Client-Einstieg
-- Lädt alle Controller: zuerst Init(), dann Start(). Der Client zeigt nur an und schickt Eingaben.

local Controllers = script.Parent:WaitForChild("Controllers")

type Controller = { Name: string, Init: () -> (), Start: () -> () }

local controllers: { Controller } = {
	require(Controllers.InputController),
	require(Controllers.CameraController),
	require(Controllers.ZoneController),
	require(Controllers.AudioController),
	require(Controllers.ViewmodelController),
	require(Controllers.HUDController),
	require(Controllers.TerminalController),
	require(Controllers.EffectsController),
	require(Controllers.PoseController),
}

for _, c in controllers do
	c.Init()
end
for _, c in controllers do
	c.Start()
	print("[SubZero] " .. c.Name .. " Started")
end
