-- Popaint : génère le fichier de jeu Popaint.rbxl (map + scripts) avec Lune.
-- Usage : lune run tools/build.luau

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

local SRC = "src"
local OUT = process.args[1] or "build/Popaint.rbxl"

local game = Instance.new("DataModel")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
game:GetService("Players")
game:GetService("StarterGui")
game:GetService("SoundService")

-- Le terrain (collines lisses) est sculpté par le serveur au lancement
local okTerrain = pcall(function()
	local terrain = Instance.new("Terrain")
	terrain.Parent = Workspace
end)
if not okTerrain then
	print("(info) Terrain non créé dans le fichier : Roblox Studio l'ajoute automatiquement")
end

local StarterPlayerScripts = Instance.new("StarterPlayerScripts")
StarterPlayerScripts.Parent = StarterPlayer
local StarterCharacterScripts = Instance.new("StarterCharacterScripts")
StarterCharacterScripts.Parent = StarterPlayer

---------------------------------------------------------------- scripts (découverte automatique)
local function listLuau(dir)
	local out = {}
	for _, name in fs.readDir(SRC .. "/" .. dir) do
		if string.sub(name, -5) == ".luau" then
			table.insert(out, name)
		end
	end
	table.sort(out)
	return out
end

local function addScript(class, name, path, parent)
	local s = Instance.new(class)
	s.Name = name
	s.Source = fs.readFile(SRC .. "/" .. path)
	s.Parent = parent
	return s
end

local shared = Instance.new("Folder")
shared.Name = "Shared"
shared.Parent = ReplicatedStorage
for _, file in listLuau("Shared") do
	addScript("ModuleScript", string.gsub(file, "%.luau$", ""), "Shared/" .. file, shared)
end

local server = Instance.new("Folder")
server.Name = "Server"
server.Parent = ServerScriptService
for _, file in listLuau("Server") do
	if string.find(file, "%.server%.luau$") then
		addScript("Script", (string.gsub(file, "%.server%.luau$", "")), "Server/" .. file, server)
	else
		addScript("ModuleScript", (string.gsub(file, "%.luau$", "")), "Server/" .. file, server)
	end
end

local clientMain = addScript("LocalScript", "ClientMain", "Client/ClientMain.client.luau", StarterPlayerScripts)
local clientModules = Instance.new("Folder")
clientModules.Name = "Modules"
clientModules.Parent = clientMain
for _, file in listLuau("Client") do
	if not string.find(file, "%.client%.luau$") then
		addScript("ModuleScript", (string.gsub(file, "%.luau$", "")), "Client/" .. file, clientModules)
	end
end

---------------------------------------------------------------- contenu (lu aussi par le jeu)
local luau = require("@lune/luau")
local contentFolder = Instance.new("Folder")
contentFolder.Name = "Content"
contentFolder.Parent = shared
local content = {}
for _, file in listLuau("Shared/Content") do
	local name = string.gsub(file, "%.luau$", "")
	addScript("ModuleScript", name, "Shared/Content/" .. file, contentFolder)
	local env = { Color3 = Color3, Vector3 = Vector3, math = math, table = table, string = string }
	content[name] = luau.load(fs.readFile(SRC .. "/Shared/Content/" .. file), { debugName = file, environment = env })()
end

---------------------------------------------------------------- map
local world = require("./map/world")
world.build(Workspace, content)

-- Chargement progressif façon « render distance » : le décor proche du joueur se charge en détail,
-- le lointain se décharge (et les grands objets restent visibles en version simplifiée).
Workspace.StreamingEnabled = true
Workspace.StreamingMinRadius = 96
Workspace.StreamingTargetRadius = 480
Workspace.StreamingIntegrityMode = Enum.StreamingIntegrityMode.MinimumRadiusPause

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

---------------------------------------------------------------- éclairage
Lighting.Technology = Enum.Technology.Future
Lighting.Brightness = 2.3
Lighting.ClockTime = 14
Lighting.Ambient = rgb(150, 138, 168)
Lighting.OutdoorAmbient = rgb(206, 196, 226)
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.6
Lighting.GlobalShadows = true

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.3 -- léger : le pastel ne doit pas éblouir
bloom.Size = 28
bloom.Threshold = 2
bloom.Parent = Lighting

local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "PopaintColor"
cc.Saturation = -0.05 -- ton pastel (la Rainbow Storm la remonte, voir src/Client/World.luau)
cc.Contrast = -0.02
cc.Brightness = 0.04
cc.TintColor = rgb(255, 248, 255)
cc.Parent = Lighting

local atmo = Instance.new("Atmosphere")
atmo.Density = 0.32
atmo.Offset = 0.22
atmo.Color = rgb(250, 232, 246)
atmo.Decay = rgb(206, 196, 250)
atmo.Glare = 0.15
atmo.Haze = 1.8
atmo.Parent = Lighting

---------------------------------------------------------------- export
fs.writeDir("build")
-- format binaire .rbxl : ~70 fois plus léger que le XML (.rbxlx), Studio l'ouvre bien plus vite
local file = roblox.serializePlace(game, false)
-- ancien fichier XML éventuel : on le retire pour ne pas livrer une vieille version par erreur
if fs.isFile("build/Popaint.rbxlx") then
	fs.removeFile("build/Popaint.rbxlx")
end
fs.writeFile(OUT, file)
print(("OK : %s (%d octets)"):format(OUT, #file))
