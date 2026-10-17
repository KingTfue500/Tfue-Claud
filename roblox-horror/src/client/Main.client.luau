-- Client entry point: starts the HUD, controls, animations and effects,
-- and keeps the objective text in sync with the round.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(script.Parent.UI)
local Controls = require(script.Parent.Controls)
local Animator = require(script.Parent.Animator)
local Effects = require(script.Parent.Effects)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

UI.init()
Controls.init()
Animator.init()
Effects.init()

remotes.Notify.OnClientEvent:Connect(Effects.notify)
remotes.Jumpscare.OnClientEvent:Connect(Effects.jumpscare)
remotes.Escaped.OnClientEvent:Connect(Effects.escaped)
remotes.Lightning.OnClientEvent:Connect(Effects.lightning)
remotes.Blackout.OnClientEvent:Connect(Effects.blackout)
remotes.Shake.OnClientEvent:Connect(Effects.shake)

local function formatTime(seconds: number)
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function refresh()
	local phase = ReplicatedStorage:GetAttribute("Phase")
	local timeLeft = ReplicatedStorage:GetAttribute("TimeLeft") or 0
	local keys = ReplicatedStorage:GetAttribute("KeysFound") or 0
	local needed = ReplicatedStorage:GetAttribute("KeysRequired") or 3

	if phase == "Intermission" then
		UI.setObjective("The next night begins in " .. timeLeft, "Gather in the chapel")
	elseif phase == "Playing" then
		if player:GetAttribute("InRound") then
			local goal = if keys >= needed
				then "Unlock the exit at the end of the hallway and escape!"
				else string.format("Find the keys  %d / %d", keys, needed)
			UI.setObjective(goal, formatTime(timeLeft))
		elseif player:GetAttribute("Escaped") then
			UI.setObjective("You escaped. Wait for the others...", formatTime(timeLeft))
		else
			UI.setObjective("A night is in progress...", formatTime(timeLeft))
		end
	else
		UI.setObjective("Dawn breaks...", "")
	end
end

for _, key in { "Phase", "TimeLeft", "KeysFound" } do
	ReplicatedStorage:GetAttributeChangedSignal(key):Connect(refresh)
end
player:GetAttributeChangedSignal("InRound"):Connect(refresh)
player:GetAttributeChangedSignal("Escaped"):Connect(refresh)
refresh()

UI.message("Welcome to the Hollow Manor.", "info")
