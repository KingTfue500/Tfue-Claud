--!strict
-- Gürtel (Hotbar, Abschnitt 9): 4 Taschen aus Leder/Canvas mit Messingschnallen.
-- Aktiver Slot wächst per Feder-Physik auf x1,15 (eigener Feder-Löser: Steifigkeit 300, Dämpfung 20).
-- Batterie-Anzeige an der Lampe, Brenndauer der Fackel, Scanner-Abklingzeit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Spring = require(ReplicatedStorage.Shared.Spring)
local Util = require(ReplicatedStorage.Shared.Util)
local UiKit = require(script.Parent.Parent.Parent.Lib.UiKit)

local Belt = {}

local player = Players.LocalPlayer

type Pouch = {
	Frame: Frame,
	Scale: UIScale,
	Spring: Spring.Spring,
	Name: TextLabel,
	Icon: Frame,
	Meter: Frame,
	MeterFill: Frame,
	Note: TextLabel,
}

local root: Frame
local pouches: { Pouch } = {}
local clothingLabel: TextLabel

local SHORT: { [string]: string } = {
	Flashlight = "LAMP",
	Scanner = "SCAN",
	Flare = "FLARE",
	HandWarmer = "WARM",
	Battery = "BATT",
	Injector = "INJ",
	Fuse = "FUSE",
	VialBlue = "VIAL",
	VialGreen = "VIAL",
	VialRed = "VIAL",
	Keycard = "CARD",
	Diesel = "DIESEL",
}

local LEATHER = Color3.fromRGB(92, 60, 38)
local LEATHER_DARK = Color3.fromRGB(52, 34, 22)
local BRASS = Color3.fromRGB(196, 160, 72)

function Belt.Build(hud: ScreenGui)
	local W, Hh, gap = 84, 96, 10
	root = UiKit.Frame(hud, "Belt", UDim2.fromOffset(4 * W + 3 * gap + 20, Hh + 30), UDim2.new(1, -(4 * W + 3 * gap + 44), 1, -(Hh + 46)), LEATHER_DARK, 1)
	-- Gurtband
	local strap = UiKit.Frame(root, "Strap", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 8), Color3.fromRGB(70, 58, 40), 0)
	UiKit.Gradient(strap, ColorSequence.new(Color3.fromRGB(85, 70, 48), Color3.fromRGB(45, 36, 26)), 90)
	UiKit.Stroke(strap, Color3.fromRGB(30, 24, 18), 1, 0)
	for i = 1, 4 do
		local f = UiKit.Frame(root, "Pouch" .. i, UDim2.fromOffset(W, Hh), UDim2.fromOffset(10 + (i - 1) * (W + gap), 20), LEATHER, 0)
		f.AnchorPoint = Vector2.new(0, 0)
		UiKit.Corner(f, 0, 8)
		UiKit.Gradient(f, ColorSequence.new(Color3.fromRGB(120, 80, 50), LEATHER_DARK), 90)
		UiKit.Stroke(f, Color3.fromRGB(35, 22, 14), 2, 0)
		-- Naht
		local stitch = UiKit.Frame(f, "Stitch", UDim2.new(1, -10, 1, -10), UDim2.fromOffset(5, 5), LEATHER, 1)
		UiKit.Corner(stitch, 0, 6)
		UiKit.Stroke(stitch, Color3.fromRGB(190, 160, 110), 1, 0.55)
		-- Klappe mit Messingschnalle
		local flap = UiKit.Frame(f, "Flap", UDim2.new(1, -8, 0, 26), UDim2.fromOffset(4, 2), Color3.fromRGB(105, 70, 44), 0)
		UiKit.Corner(flap, 0, 6)
		UiKit.Gradient(flap, ColorSequence.new(Color3.fromRGB(130, 90, 58), Color3.fromRGB(80, 52, 32)), 90)
		local buckle = UiKit.Frame(f, "Buckle", UDim2.fromOffset(20, 14), UDim2.new(0.5, -10, 0, 19), BRASS, 0)
		UiKit.Corner(buckle, 0, 3)
		UiKit.Gradient(buckle, ColorSequence.new(Color3.fromRGB(240, 210, 120), Color3.fromRGB(140, 105, 40)), 45)
		UiKit.Stroke(buckle, Color3.fromRGB(90, 66, 24), 1, 0)
		UiKit.Frame(buckle, "Pin", UDim2.new(0, 2, 1, -4), UDim2.new(0.5, -1, 0, 2), Color3.fromRGB(80, 60, 20), 0)
		local num = UiKit.Text(f, "Num", tostring(i), UDim2.fromOffset(16, 14), UDim2.fromOffset(6, 4), UiKit.Label, 10, Color3.fromRGB(230, 210, 170))
		num.TextXAlignment = Enum.TextXAlignment.Left
		local icon = UiKit.Frame(f, "Icon", UDim2.fromOffset(26, 26), UDim2.new(0.5, -13, 0, 38), Color3.fromRGB(80, 80, 80), 1)
		UiKit.Corner(icon, 0, 5)
		UiKit.Stroke(icon, Color3.fromRGB(20, 20, 20), 1, 0.3)
		local name = UiKit.Text(f, "ItemName", "", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 1, -28), UiKit.MonoBold, 12, Color3.fromRGB(240, 228, 200))
		local meter = UiKit.Frame(f, "Meter", UDim2.new(1, -16, 0, 4), UDim2.new(0, 8, 1, -11), Color3.fromRGB(20, 20, 20), 0.2)
		local fill = UiKit.Frame(meter, "Fill", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(240, 210, 80), 0)
		local note = UiKit.Text(f, "Note", "", UDim2.new(1, 0, 0, 12), UDim2.new(0, 0, 0, 66), UiKit.Mono, 10, Color3.fromRGB(255, 200, 120))
		local scale = Instance.new("UIScale")
		scale.Parent = f
		local hc = Config.HUD
		table.insert(pouches, {
			Frame = f,
			Scale = scale,
			Spring = Spring.new(1, hc.HotbarSpringStiffness, hc.HotbarSpringDamping),
			Name = name,
			Icon = icon,
			Meter = meter,
			MeterFill = fill,
			Note = note,
		})
	end
	clothingLabel = UiKit.Text(root, "Clothing", "", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, -12), UiKit.Label, 10, Color3.fromRGB(220, 200, 160))
	clothingLabel.TextXAlignment = Enum.TextXAlignment.Right
end

function Belt.Update(dt: number, visible: boolean)
	root.Visible = visible
	if not visible then
		return
	end
	local active = Util.NumAttr(player, "ActiveSlot", 1)
	local t = Workspace:GetServerTimeNow()
	for i, p in pouches do
		local id = player:GetAttribute("Slot" .. i)
		local itemId = if type(id) == "string" and id ~= "" then id else nil
		local info = if itemId then Config.ItemInfo[itemId] else nil
		p.Name.Text = if itemId then (SHORT[itemId] or itemId) else ""
		p.Icon.BackgroundTransparency = if info then 0 else 1
		if info then
			p.Icon.BackgroundColor3 = info.Color
		end
		p.Spring.Target = if i == active then Config.HUD.HotbarActiveScale else 1
		p.Scale.Scale = p.Spring:Step(dt)
		p.Frame.ZIndex = if i == active then 2 else 1
		-- Anzeigen pro Item
		p.Meter.Visible = false
		p.Note.Text = ""
		if itemId == "Flashlight" then
			p.Meter.Visible = true
			local b = Util.NumAttr(player, "FlashBattery", 0)
			p.MeterFill.Size = UDim2.fromScale(b, 1)
			p.MeterFill.BackgroundColor3 = if b < 0.2 then Color3.fromRGB(230, 60, 40) else Color3.fromRGB(240, 210, 80)
			p.Note.Text = if player:GetAttribute("FlashlightOn") == true then "ON" else "OFF"
		elseif itemId == "Flare" and i == active and player:GetAttribute("FlareLit") == true then
			p.Meter.Visible = true
			p.MeterFill.Size = UDim2.fromScale(Util.NumAttr(player, "FlareBurn", 0), 1)
			p.MeterFill.BackgroundColor3 = Color3.fromRGB(255, 70, 50)
			p.Note.Text = "LIT"
		elseif itemId == "Scanner" then
			local ready = Util.NumAttr(player, "ScannerReadyAt", 0)
			p.Note.Text = if ready > t then string.format("%ds", math.ceil(ready - t)) else "READY"
		end
	end
	local clothing = Util.StrAttr(player, "Clothing", "Parka")
	local cinfo = Config.ClothingInfo[clothing]
	clothingLabel.Text = if cinfo then cinfo.Name else clothing
end

return Belt
