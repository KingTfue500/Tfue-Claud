--!nocheck
-- Lune-Skript: baut die Map mit dem MapBuilder (derselbe Code wie im Spiel) und
-- schreibt sie zusammen mit Licht-Effekten und SoundGroups in die Place-Datei.
-- Aufruf: lune run tools/bake.luau build/SubZero.rbxl

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local placePath = process.args[1] or "build/SubZero.rbxl"

local globals = {
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Font = roblox.Font,
	PhysicalProperties = roblox.PhysicalProperties,
	BrickColor = roblox.BrickColor,
	Rect = roblox.Rect,
}

-- Nachbildung von "script" und "require" für Roblox-ModuleScripts aus Dateien.
-- Der Proxy-Baum wird vorab aus dem Dateisystem gebaut (fs darf nicht in Metamethoden laufen).
local proxyMeta = {}
local proxyData = setmetatable({}, { __mode = "k" })

proxyMeta.__index = function(self, key)
	local d = proxyData[self]
	if key == "Parent" then
		return d.Parent
	end
	local child = d.Children[key]
	if child == nil then
		error("bake: unknown module " .. tostring(key))
	end
	return child
end

local function buildTree(dir: string, file: string?, parent)
	local proxy = setmetatable({}, proxyMeta)
	local data = { File = file, Parent = parent, Children = {} }
	proxyData[proxy] = data
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			local init = path .. "/init.luau"
			data.Children[name] = buildTree(path, if fs.isFile(init) then init else nil, proxy)
		elseif string.sub(name, -5) == ".luau" and name ~= "init.luau" then
			local child = setmetatable({}, proxyMeta)
			proxyData[child] = { File = path, Parent = proxy, Children = {} }
			data.Children[string.sub(name, 1, -6)] = child
		end
	end
	return proxy
end

local cache = {}
local function requireProxy(proxy)
	if cache[proxy] ~= nil then
		return cache[proxy]
	end
	local d = proxyData[proxy]
	assert(d and d.File, "bake: require of non-module")
	local env = setmetatable({ script = proxy, require = requireProxy }, { __index = function(_, k)
		local g = globals[k]
		if g ~= nil then
			return g
		end
		return _G[k] or getfenv(0)[k]
	end })
	for k, v in globals do
		env[k] = v
	end
	env.math, env.table, env.string, env.print, env.error, env.type, env.typeof = math, table, string, print, error, type, typeof
	env.pairs, env.ipairs, env.tostring, env.tonumber, env.setmetatable, env.assert, env.select = pairs, ipairs, tostring, tonumber, setmetatable, assert, select
	local fn = luau.load(fs.readFile(d.File), { debugName = d.File, environment = env })
	local result = fn()
	cache[proxy] = result
	return result
end

-- Shared-Ordner (für Config) und MapBuilder als Proxy-Bäume
local sharedRoot = buildTree("src/shared", nil, nil)
local mapRoot = buildTree("src/mapbuilder", "src/mapbuilder/init.luau", nil)
local Config = requireProxy(sharedRoot.Config)
local MapBuilder = requireProxy(mapRoot)

local game = roblox.deserializePlace(fs.readFile(placePath))
local Workspace = game:GetService("Workspace")
local old = Workspace:FindFirstChild("Map")
if old then
	old:Destroy()
end

local t0 = os.clock()
local map = MapBuilder.Build(Workspace, Config)
local count = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
print(string.format("bake: Map gebaut (%d Teile) in %.2f s", count, os.clock() - t0))

-- Licht-Effekte (Abschnitt 2 / 10.5)
local Lighting = game:GetService("Lighting")
for _, c in Lighting:GetChildren() do
	c:Destroy()
end
local atm = roblox.Instance.new("Atmosphere")
atm.Density = 0.25
atm.Offset = 0
atm.Haze = 0.5
atm.Glare = 0
atm.Color = roblox.Color3.fromRGB(80, 50, 35)
atm.Decay = roblox.Color3.fromRGB(40, 25, 15)
atm.Parent = Lighting
local cc = roblox.Instance.new("ColorCorrectionEffect")
cc.Name = "ZoneGrade"
cc.Parent = Lighting
local bloom = roblox.Instance.new("BloomEffect")
bloom.Intensity = 0.6
bloom.Size = 28
bloom.Threshold = 1.6
bloom.Parent = Lighting
local sky = roblox.Instance.new("Sky")
sky.StarCount = 0
sky.CelestialBodiesShown = false
sky.Parent = Lighting

-- SoundGroups (Abschnitt 11)
local SoundService = game:GetService("SoundService")
for _, name in { "Effects", "Ambience", "Creature", "Biometrics", "Interface", "Music" } do
	if not SoundService:FindFirstChild(name) then
		local g = roblox.Instance.new("SoundGroup")
		g.Name = name
		g.Volume = 1
		g.Parent = SoundService
	end
end

fs.writeFile(placePath, roblox.serializePlace(game))
print("bake: geschrieben nach " .. placePath)
