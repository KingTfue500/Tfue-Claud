--!strict
-- HUDController (Abschnitt 9): baut alle Anzeigen und verbindet sie mit den Remotes.
-- Ebenen: Frost (unten), HUD, CRT (Scanlines, Vignette, Monitor-Rahmen), Vollbild (oben).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(ReplicatedStorage.Shared.Util)
local ClientState = require(script.Parent.Parent.Lib.ClientState)
local UiKit = require(script.Parent.Parent.Lib.UiKit)
local Belt = require(script.Parent.HUD.Belt)
local Gauges = require(script.Parent.HUD.Gauges)
local Prompts = require(script.Parent.HUD.Prompts)
local Screens = require(script.Parent.HUD.Screens)
local CameraController = require(script.Parent.CameraController)
local InputController = require(script.Parent.InputController)

local HUDController = {}
HUDController.Name = "HUDController"

local player = Players.LocalPlayer

local hudGui: ScreenGui
local crtGui: ScreenGui
local scan: Frame

local function buildCrt()
	crtGui = UiKit.Screen("SubZeroCRT", 8)
	-- Scanlines (gekachelt, langsam scrollend)
	scan = UiKit.Scanlines(crtGui, Config.HUD.ScanlineSpacing, 0.9, 600)
	-- Vignette
	UiKit.Vignette(crtGui, Color3.new(0, 0, 0), 0.22, 0.25)
	-- gewölbter Monitor-Rahmen
	if UiKit.ImageOrNil(crtGui, "MonitorFrame", Config.Images.MonitorFrame, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0)) == nil then
		local frame = UiKit.Frame(crtGui, "MonitorFrame", UDim2.new(1, 24, 1, 24), UDim2.fromOffset(-12, -12), Color3.new(0, 0, 0), 1)
		UiKit.Corner(frame, 0.07)
		UiKit.Stroke(frame, Color3.fromRGB(8, 8, 9), 22, 0.05)
	end
	-- Einschalt-Flackern
	local flash = UiKit.Frame(crtGui, "PowerOn", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 0)
	task.spawn(function()
		for _ = 1, 3 do
			flash.BackgroundTransparency = 0.6
			task.wait(0.05)
			flash.BackgroundTransparency = 0
			task.wait(0.07)
		end
		UiKit.Tween(flash, 0.8, { BackgroundTransparency = 1 })
	end)
end

function HUDController.Init()
	local frostGui = UiKit.Screen("SubZeroFrost", 1)
	hudGui = UiKit.Screen("SubZeroHUD", 5)
	local topGui = UiKit.Screen("SubZeroTop", 30)
	-- Unsichtbarer Modal-Knopf: gibt die Maus in der ersten Person frei, solange eine Oberfläche offen ist
	local modal = Instance.new("TextButton")
	modal.Name = "MouseUnlock"
	modal.Size = UDim2.fromOffset(1, 1)
	modal.BackgroundTransparency = 1
	modal.Text = ""
	modal.Modal = true
	modal.Visible = false
	modal.Parent = topGui
	ClientState.UiChanged:Connect(function()
		modal.Visible = ClientState.IsUiOpen()
	end)
	buildCrt()
	Gauges.Build(hudGui, frostGui)
	Belt.Build(hudGui)
	Screens.Build(hudGui, topGui)
end

function HUDController.Start()
	Prompts.Start()
	Net.Event("Notify").OnClientEvent:Connect(function(text: unknown)
		if type(text) == "string" then
			Screens.Notify(text)
		end
	end)
	Net.Event("OpenNote").OnClientEvent:Connect(function(id: unknown)
		if type(id) == "string" then
			Screens.ShowNote(id)
		end
	end)
	Net.Event("ScannerResult").OnClientEvent:Connect(function(results: unknown, duration: unknown)
		if type(results) == "table" then
			Screens.ScannerResult(results :: { any }, if type(duration) == "number" then duration else Config.Items.Scanner.Duration)
		end
	end)
	Net.Event("RoundStateChanged").OnClientEvent:Connect(function(state: unknown, data: unknown)
		if type(state) == "string" then
			Screens.OnRoundState(state, data)
		end
	end)
	Net.Event("PlayCinematic").OnClientEvent:Connect(function(kind: unknown)
		if kind == "Kill" then
			Screens.PlayKill()
		end
	end)
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		Screens.ZoneBanner(Util.StrAttr(player, "Zone", "None"))
	end)
	InputController.SettingsToggled:Connect(function()
		Screens.ToggleSettings()
	end)
	InputController.CloseRequested:Connect(function()
		Screens.CloseAll()
	end)

	local scroll = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local st = Util.GetState(player)
		local inRound = st == "Alive" or st == "Downed"
		local visible = (inRound or st == "Lobby") and not ClientState.Cinematic
		Gauges.Update(dt, visible)
		Belt.Update(dt, inRound and not ClientState.Cinematic)
		Screens.Update(CameraController.GetSpectateTarget())
		hudGui.Enabled = not ClientState.Cinematic
		scroll = (scroll + dt * Config.HUD.ScanlineScrollSpeed) % (Config.HUD.ScanlineSpacing * 4)
		scan.Position = UDim2.fromOffset(0, -scroll)
	end)
end

return HUDController
