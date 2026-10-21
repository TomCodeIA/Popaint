-- Popaint (générateur de map) : placement des zones sur la grille du monde et des ponts.
-- Le hub est la case { 0, 0 }. Chaque zone occupe une case et se relie par un pont à la zone "From".
local lib = require("./lib")

local layout = {}

local ZONE, HALF = lib.ZONE, lib.HALF
local STEP = lib.ZONE + lib.BRIDGE -- 186 studs entre deux zones voisines
local FIRST = lib.HALF + lib.BRIDGE + lib.ZONE / 2 -- 206 : centre d'une zone collée au hub

-- Coordonnée du centre d'une case sur un axe
function layout.center(n)
	if n == 0 then
		return 0
	end
	local sign = if n > 0 then 1 else -1
	return sign * (FIRST + (math.abs(n) - 1) * STEP)
end

local DIRS = {
	N = { 0, -1 },
	S = { 0, 1 },
	W = { -1, 0 },
	E = { 1, 0 },
}
local OPPOSITE = { N = "S", S = "N", W = "E", E = "W" }
layout.OPPOSITE = OPPOSITE

-- Direction (N/S/E/W) pour aller de la case a à la case b (voisines), sinon nil
function layout.direction(a, b)
	local dx, dz = b[1] - a[1], b[2] - a[2]
	for name, d in DIRS do
		if d[1] == dx and d[2] == dz then
			return name
		end
	end
	return nil
end

-- Bords d'une case : hub (200 de large) ou zone (160)
local function bounds(cell)
	if cell[1] == 0 and cell[2] == 0 then
		return -HALF, -HALF, HALF, HALF
	end
	local cx, cz = layout.center(cell[1]), layout.center(cell[2])
	return cx - ZONE / 2, cz - ZONE / 2, cx + ZONE / 2, cz + ZONE / 2
end
layout.bounds = bounds

-- Calcule tout le placement à partir de la liste des zones (Content/Zones.luau)
-- Retourne { zones = { [Id] = info }, order = { info }, bridges = { ... }, hubSides = { N = true, ... } }
function layout.build(zoneDefs)
	local result = { zones = {}, order = {}, bridges = {}, hubSides = {} }
	local cells = { ["0,0"] = "Hub" }
	for index, def in zoneDefs do
		local key = def.Cell[1] .. "," .. def.Cell[2]
		assert(not cells[key], ("zone %s : la case %s est déjà prise par %s"):format(def.Id, key, tostring(cells[key])))
		cells[key] = def.Id
		local minX, minZ = bounds(def.Cell)
		local info = {
			Def = def,
			Index = index,
			MinX = minX,
			MinZ = minZ,
			CX = minX + ZONE / 2,
			CZ = minZ + ZONE / 2,
			Sides = {},
		}
		result.zones[def.Id] = info
		table.insert(result.order, info)
	end
	for _, info in result.order do
		local def = info.Def
		local parentCell
		if def.From == "Hub" then
			parentCell = { 0, 0 }
		else
			local parent = result.zones[def.From]
			assert(parent, ("zone %s : From = %s n'existe pas"):format(def.Id, tostring(def.From)))
			parentCell = parent.Def.Cell
		end
		local dir = layout.direction(parentCell, def.Cell)
		assert(dir, ("zone %s : sa case doit toucher celle de %s"):format(def.Id, def.From))
		-- côtés ouverts
		info.Sides[OPPOSITE[dir]] = true
		if def.From == "Hub" then
			result.hubSides[dir] = true
		else
			result.zones[def.From].Sides[dir] = true
		end
		-- pont entre les deux bords qui se font face
		local pMinX, pMinZ, pMaxX, pMaxZ = bounds(parentCell)
		local cMinX, cMinZ, cMaxX, cMaxZ = bounds(def.Cell)
		local bridge = { Child = def.Id, Dir = dir }
		if dir == "N" or dir == "S" then
			local from = if dir == "N" then pMinZ else pMaxZ
			local to = if dir == "N" then cMaxZ else cMinZ
			bridge.AlongX = false
			bridge.X = info.CX
			bridge.Z = (from + to) / 2
			bridge.Length = math.abs(to - from)
			bridge.GateX, bridge.GateZ = info.CX, to + (if dir == "N" then 1.5 else -1.5)
			bridge.EntranceX, bridge.EntranceZ = info.CX, to + (if dir == "N" then -10 else 10)
		else
			local from = if dir == "W" then pMinX else pMaxX
			local to = if dir == "W" then cMaxX else cMinX
			bridge.AlongX = true
			bridge.X = (from + to) / 2
			bridge.Z = info.CZ
			bridge.Length = math.abs(to - from)
			bridge.GateX, bridge.GateZ = to + (if dir == "W" then 1.5 else -1.5), info.CZ
			bridge.EntranceX, bridge.EntranceZ = to + (if dir == "W" then -10 else 10), info.CZ
		end
		info.Bridge = bridge
		table.insert(result.bridges, bridge)
	end
	return result
end

return layout
