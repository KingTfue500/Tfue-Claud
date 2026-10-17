--!strict
-- ZoneController (Abschnitt 2/10.5/11): erkennt die Zone per Volumen-Box (an der Kamera, damit es
-- auch im Zuschauer-Modus stimmt) und tweent das Licht-Preset der Zone in 1,5 s.
-- Setzt SoundService.AmbientReverb je Zone und trübt die Sicht im Dampf.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Settings = require(script.Parent.Parent.Lib.Settings)

local ZoneController = {}
ZoneController.Name = "ZoneController"

ZoneController.ZoneChanged = Signal.new() :: Signal.Signal<string>

local player = Players.LocalPlayer
local currentZone = "Lobby"
local currentPreset = ""
local inSteam = false

local function atmosphere(): Atmosphere
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	if a == nil then
		local na = Instance.new("Atmosphere")
		na.Parent = Lighting
		return na
	end
	return a
end

local function grade(): ColorCorrectionEffect
	local cc = Lighting:FindFirstChild("ZoneGrade")
	if cc and cc:IsA("ColorCorrectionEffect") then
		return cc
	end
	local n = Instance.new("ColorCorrectionEffect")
	n.Name = "ZoneGrade"
	n.Parent = Lighting
	return n
end

function ZoneController.GetZone(): string
	return currentZone
end

local function presetFor(zone: string): string
	local map = Workspace:FindFirstChild("Map")
	local power = if map then map:GetAttribute("PowerState") else "On"
	local gen = if map then map:GetAttribute("GeneratorOn") == true else false
	if zone == "Zone1" then
		return if power == "Off" then "Zone1Dark" else "Zone1"
	elseif zone == "Zone3" then
		return if gen then "Zone3Lit" else "Zone3"
	end
	return zone
end

local function apply(presetName: string, instant: boolean)
	local p = Config.LightPresets[presetName]
	if p == nil then
		return
	end
	currentPreset = presetName
	local info = TweenInfo.new(if instant then 0 else Config.LightTween, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local steamExtra = if inSteam then 0.35 else 0
	TweenService:Create(Lighting, info, { Ambient = p.Ambient, OutdoorAmbient = p.Ambient }):Play()
	TweenService:Create(atmosphere(), info, {
		Density = math.min(1, p.Density + steamExtra),
		Haze = if inSteam then 6 else p.Haze,
		Color = if inSteam then Color3.fromRGB(235, 235, 240) else p.AtmosphereColor,
		Decay = if inSteam then Color3.fromRGB(220, 220, 225) else p.Decay,
	}):Play()
	TweenService:Create(grade(), info, {
		TintColor = p.Tint,
		Saturation = p.Saturation,
		Contrast = p.Contrast,
		Brightness = Settings.Brightness,
	}):Play()
	SoundService.AmbientReverb = p.Reverb
end

function ZoneController.Init() end

function ZoneController.Start()
	apply("Lobby", true)
	Settings.OnChanged(function(key: string)
		if key == "Brightness" then
			grade().Brightness = Settings.Brightness
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local cam = Workspace.CurrentCamera
			if cam then
				local zone = Zones.GetZoneAt(cam.CFrame.Position)
				if zone ~= "None" and zone ~= currentZone then
					currentZone = zone
					ZoneController.ZoneChanged:Fire(zone)
				end
				local steam = player:GetAttribute("InSteam") == true
				local preset = presetFor(currentZone)
				if preset ~= currentPreset or steam ~= inSteam then
					inSteam = steam
					apply(preset, false)
				end
			end
		end
	end)
end

return ZoneController
