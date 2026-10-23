-- Popaint : exporte des modèles en JSON pour l'aperçu 3D (tools/preview/render.py).
-- Usage : lune run tools/preview/export.luau <sortie.json> <quoi>
--   quoi = "props" (tous les objets de décor), "base" (une base complète), "companions",
--          "showcase" (fontaine, œuf, portail, pont, montagne, îlot),
--          "centerpieces", ou un chemin dans le fichier de jeu (ex. "Workspace.Map.Hub.Bases.Base01")
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local luau = require("@lune/luau")

local OUT = process.args[1] or "build/preview.json"
local WHAT = process.args[2] or "props"

local function export(model)
	local parts = {}
	local descendants = if model:IsA("BasePart") then { model } else model:GetDescendants()
	for _, p in descendants do
		if p:IsA("BasePart") and p.Transparency < 0.99 then
			local c = { p.CFrame:GetComponents() }
			local mesh = p:FindFirstChildOfClass("SpecialMesh")
			local shape = "Block"
			if p:IsA("Part") then
				shape = p.Shape.Name
			elseif p.ClassName == "WedgePart" then
				shape = "Wedge"
			end
			local scale = { 1, 1, 1 }
			if mesh then
				if mesh.MeshType == roblox.Enum.MeshType.Sphere then
					shape = "Ellipsoid"
				elseif mesh.MeshType == roblox.Enum.MeshType.Wedge then
					shape = "Wedge"
				end
				scale = { mesh.Scale.X, mesh.Scale.Y, mesh.Scale.Z }
			end
			table.insert(parts, {
				shape = shape,
				cf = c,
				size = { p.Size.X * scale[1], p.Size.Y * scale[2], p.Size.Z * scale[3] },
				color = { p.Color.R, p.Color.G, p.Color.B },
				transparency = p.Transparency,
				material = p.Material.Name,
				studs = p.TopSurface == roblox.Enum.SurfaceType.Studs,
			})
		end
	end
	return parts
end

local scenes = {}

local function sandbox()
	local f = roblox.Instance.new("Folder")
	f.Name = "Preview"
	return f
end

if WHAT == "props" then
	local props = require("../map/props")
	local lib = require("../map/lib")
	local names = {}
	for name, fn in props do
		if type(fn) == "function" and name ~= "Islet" then
			table.insert(names, name)
		end
	end
	table.sort(names)
	for k, name in names do
		local f = sandbox()
		props[name](f, roblox.Vector3.new(0, 0, 0), lib.rng(k * 17), 1)
		table.insert(scenes, { name = name, parts = export(f) })
	end
elseif WHAT == "companions" then
	local roblox_env = {
		Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3,
		Enum = roblox.Enum, ColorSequence = roblox.ColorSequence, NumberSequence = roblox.NumberSequence,
		NumberRange = roblox.NumberRange, Vector2 = roblox.Vector2, math = math, table = table, string = string, type = type,
		ipairs = ipairs, pairs = pairs, tostring = tostring, error = error, assert = assert,
	}
	local Models = luau.load(fs.readFile("src/Shared/CompanionModels.luau"), { debugName = "CompanionModels", environment = roblox_env })()
	local companions = luau.load(fs.readFile("src/Shared/Content/Companions.luau"),
		{ debugName = "Companions", environment = { Color3 = roblox.Color3 } })()
	local only = process.args[3]
	for _, row in companions do
		if not only or string.find(row.Egg, only, 1, true) or row.Id == only then
			for tier = 0, (if only then 2 else 0) do
				local f = sandbox()
				local m = Models.build(row, tier)
				m.Parent = f
				table.insert(scenes, { name = row.Name .. (if tier > 0 then " (" .. tier .. ")" else ""), parts = export(f) })
			end
		end
	end
else
	-- un modèle du fichier de jeu
	local game = roblox.deserializePlace(fs.readFile("build/Popaint.rbxl"))
	local list = {}
	if WHAT == "base" then
		table.insert(list, game.Workspace.Map.Hub.Bases.Base01)
	elseif WHAT == "showcase" then
		-- un échantillon de ce qui change souvent : fontaine, œuf, portail, pont, montagne, îlot
		local ws = game:GetService("Workspace")
		local function grab(parent, match)
			for _, c in parent:GetChildren() do
				if string.find(c.Name, match) then
					return c
				end
			end
			return nil
		end
		local picks = {
			ws.Map.Hub:FindFirstChild("Fountain"),
			ws.Map.Eggs:GetChildren()[1],
			grab(ws.Map.Decor, "Arch$"),
			grab(ws.Map.Hub, "BridgeDecor$"),
			grab(ws.Map.Relief:GetChildren()[1], "Mountain"),
			grab(ws.Map.Decor, "Islet"),
		}
		for _, m in picks do
			if m then
				table.insert(list, m)
			end
		end
	elseif WHAT == "centerpieces" then
		for _, z in game.Workspace.Map.Zones:GetChildren() do
			local f = sandbox()
			for _, c in z:GetChildren() do
				if c.Name ~= "Tiles" and c.Name ~= "Decor" and c.Name ~= "Mist" then
					c:Clone().Parent = f
				end
			end
			f.Name = z.Name
			table.insert(list, f)
		end
	else
		local node = game
		for name in string.gmatch(WHAT, "[^%.]+") do
			node = if name == "Workspace" then game:GetService("Workspace") else node:FindFirstChild(name)
		end
		table.insert(list, node)
	end
	for _, m in list do
		table.insert(scenes, { name = m.Name, parts = export(m) })
	end
end

fs.writeFile(OUT, serde.encode("json", scenes))
print(("%d modèles exportés dans %s"):format(#scenes, OUT))
