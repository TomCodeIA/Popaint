-- Popaint (générateur de map) : formes des zones, collines peignables et murs de contour.
-- Une zone est une grille de 40 x 40 cases ; la forme dit quelles cases existent.
local lib = require("./lib")

local shapes = {}

local COUNT = lib.ZONE / lib.TILE -- 40
local C = (COUNT + 1) / 2 -- 20.5, centre de la grille
local SPAN_MIN, SPAN_MAX = 18, 23 -- les 6 cases du milieu d'un côté (= largeur d'un pont)
shapes.COUNT = COUNT
shapes.SPAN_MIN, shapes.SPAN_MAX = SPAN_MIN, SPAN_MAX

local function polar(i, j)
	local dx, dz = i - C, j - C
	return math.sqrt(dx * dx + dz * dz), math.atan2(dz, dx), dx, dz
end

-- Formes disponibles (Shape dans Content/Zones.luau). Chaque forme garde un trou au centre
-- pour la pièce centrale (sauf SCanyon et Cross, qui ont leurs décors sur les côtés).
shapes.list = {
	Circle = function(i, j)
		local d = polar(i, j)
		return d <= 19.6 and d >= 4.6
	end,
	Octagon = function(i, j)
		local d, _, dx, dz = polar(i, j)
		local ax, az = math.abs(dx), math.abs(dz)
		return ax <= 19.5 and az <= 19.5 and ax + az <= 27 and d >= 3.6
	end,
	SCanyon = function(i, j)
		local path = C + 10 * math.sin((j - 0.5) / COUNT * math.pi * 2)
		return math.abs(i - path) <= 7.5
	end,
	Star = function(i, j)
		local d, a = polar(i, j)
		local r = 13 + 6.5 * math.cos(5 * (a + math.pi / 2))
		return d <= r and d >= 3.6
	end,
	Ring = function(i, j)
		local d = polar(i, j)
		return d <= 19.6 and d >= 9
	end,
	-- citrouille : un cercle à 8 bosses
	Pumpkin = function(i, j)
		local d, a = polar(i, j)
		return d <= 16.5 + 2.8 * math.cos(8 * a) and d >= 4.6
	end,
	Diamond = function(i, j)
		local d, _, dx, dz = polar(i, j)
		return math.abs(dx) + math.abs(dz) <= 19.5 and d >= 3.6
	end,
	Cross = function(i, j)
		local _, _, dx, dz = polar(i, j)
		return (math.abs(dx) <= 6.5 or math.abs(dz) <= 6.5) and math.abs(dx) <= 19.5 and math.abs(dz) <= 19.5
	end,
}

-- Masque final : la forme + un couloir jusqu'à chaque entrée (sides = { N = true, ... })
function shapes.mask(shapeName, sides)
	local shape = shapes.list[shapeName]
	assert(shape, "forme inconnue : " .. tostring(shapeName))
	local mask = {}
	local function set(i, j)
		mask[i * 100 + j] = true
	end
	local function has(i, j)
		return mask[i * 100 + j] == true
	end
	for i = 1, COUNT do
		for j = 1, COUNT do
			if shape(i, j) then
				set(i, j)
			end
		end
	end
	for k = SPAN_MIN, SPAN_MAX do
		if sides.S then
			for j = COUNT, 1, -1 do
				if has(k, j) and j < COUNT - 1 then
					break
				end
				set(k, j)
			end
		end
		if sides.N then
			for j = 1, COUNT do
				if has(k, j) and j > 2 then
					break
				end
				set(k, j)
			end
		end
		if sides.W then
			for i = 1, COUNT do
				if has(i, k) and i > 2 then
					break
				end
				set(i, k)
			end
		end
		if sides.E then
			for i = COUNT, 1, -1 do
				if has(i, k) and i < COUNT - 1 then
					break
				end
				set(i, k)
			end
		end
	end
	return function(i, j)
		return i >= 1 and j >= 1 and i <= COUNT and j <= COUNT and has(i, j)
	end
end

-- Collines peignables (2 ou 3 par zone), entièrement dans la forme, loin des entrées
function shapes.hills(seed, inMask)
	local rng = lib.rng(seed)
	-- « profondeur » de chaque case : à quelle distance du bord de l'île elle se trouve.
	-- Cela garantit que le bord reste plat (pas de falaise) quelle que soit la forme de la zone.
	local depth = {}
	local queue, head = {}, 1
	for i = 1, COUNT do
		depth[i] = {}
		for j = 1, COUNT do
			if inMask(i, j) then
				local border = not inMask(i - 1, j) or not inMask(i + 1, j) or not inMask(i, j - 1) or not inMask(i, j + 1)
				depth[i][j] = if border then 1 else math.huge
				if border then
					table.insert(queue, { i, j })
				end
			else
				depth[i][j] = 0
			end
		end
	end
	while head <= #queue do
		local c = queue[head]
		head += 1
		local i, j = c[1], c[2]
		for _, o in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local ni, nj = i + o[1], j + o[2]
			if ni >= 1 and nj >= 1 and ni <= COUNT and nj <= COUNT and depth[ni][nj] == math.huge then
				depth[ni][nj] = depth[i][j] + 1
				table.insert(queue, { ni, nj })
			end
		end
	end

	-- collines : on les pose au cœur de l'île (là où il y a de la place)
	local hills = {}
	local tries = 0
	while #hills < 5 and tries < 3000 do
		tries += 1
		local ci, cj = math.floor(rng(2, COUNT - 1)), math.floor(rng(2, COUNT - 1))
		local d = depth[ci][cj]
		if d >= 4 then
			local r = math.min(rng(4, 9), d + 1.5)
			local ok = true
			-- pas de colline à l'arrivée d'un pont, ni collée à une autre
			for _, e in { { COUNT / 2, COUNT }, { COUNT / 2, 1 }, { 1, COUNT / 2 }, { COUNT, COUNT / 2 } } do
				if math.sqrt((ci - e[1]) ^ 2 + (cj - e[2]) ^ 2) < r + 6 then
					ok = false
				end
			end
			for _, h in hills do
				if math.sqrt((ci - h[1]) ^ 2 + (cj - h[2]) ^ 2) < r + h[3] - 1 then
					ok = false
				end
			end
			if ok then
				table.insert(hills, { ci, cj, r })
			end
		end
	end

	return function(i, j)
		if i < 1 or j < 1 or i > COUNT or j > COUNT or not inMask(i, j) then
			return 0
		end
		local best = 0
		for _, h in hills do
			local d = math.sqrt((i - h[1]) ^ 2 + (j - h[2]) ^ 2)
			best = math.max(best, math.clamp(math.floor((h[3] - d) / 1.35), 0, 6))
		end
		-- jamais de marche au bord de l'île
		return math.min(best, math.max(0, depth[i][j] - 2))
	end
end

-- Bords extérieurs de la forme (pour le glaçage décoratif) : liste de { i, j, di, dj }
-- (di, dj) = direction vers l'extérieur. Les arrivées de pont sont exclues.
function shapes.edges(inMask, sides)
	local out = {}
	for i = 1, COUNT do
		for j = 1, COUNT do
			if inMask(i, j) then
				local spanI = i >= SPAN_MIN and i <= SPAN_MAX
				local spanJ = j >= SPAN_MIN and j <= SPAN_MAX
				if not inMask(i, j - 1) and not (j == 1 and sides.N and spanI) then
					table.insert(out, { i, j, 0, -1 })
				end
				if not inMask(i, j + 1) and not (j == COUNT and sides.S and spanI) then
					table.insert(out, { i, j, 0, 1 })
				end
				if not inMask(i - 1, j) and not (i == 1 and sides.W and spanJ) then
					table.insert(out, { i, j, -1, 0 })
				end
				if not inMask(i + 1, j) and not (i == COUNT and sides.E and spanJ) then
					table.insert(out, { i, j, 1, 0 })
				end
			end
		end
	end
	return out
end

function shapes.walls(ctx, id, minX, minZ, inMask, sides)
	local TILE = lib.TILE
	local H = lib.WALL_H
	local horiz, vert = {}, {}
	local function addH(edge, i)
		horiz[edge] = horiz[edge] or {}
		horiz[edge][i] = true
	end
	local function addV(edge, j)
		vert[edge] = vert[edge] or {}
		vert[edge][j] = true
	end
	for i = 1, COUNT do
		for j = 1, COUNT do
			if inMask(i, j) then
				local spanI = i >= SPAN_MIN and i <= SPAN_MAX
				local spanJ = j >= SPAN_MIN and j <= SPAN_MAX
				if not inMask(i, j - 1) and not (j == 1 and sides.N and spanI) then
					addH(j - 1, i)
				end
				if not inMask(i, j + 1) and not (j == COUNT and sides.S and spanI) then
					addH(j, i)
				end
				if not inMask(i - 1, j) and not (i == 1 and sides.W and spanJ) then
					addV(i - 1, j)
				end
				if not inMask(i + 1, j) and not (i == COUNT and sides.E and spanJ) then
					addV(i, j)
				end
			end
		end
	end
	local function runs(set)
		local out, start, prev = {}, nil, nil
		for k = 1, COUNT do
			if set[k] then
				start = start or k
				prev = k
			elseif start then
				table.insert(out, { start, prev })
				start = nil
			end
		end
		if start then
			table.insert(out, { start, prev })
		end
		return out
	end
	for edge, set in horiz do
		for _, r in runs(set) do
			local x0, x1 = minX + (r[1] - 1) * TILE, minX + r[2] * TILE
			ctx.wall(id .. "Edge", lib.Vector3.new(x1 - x0 + 1, H, 1), lib.CFrame.new((x0 + x1) / 2, H / 2 - 8, minZ + edge * TILE))
		end
	end
	for edge, set in vert do
		for _, r in runs(set) do
			local z0, z1 = minZ + (r[1] - 1) * TILE, minZ + r[2] * TILE
			ctx.wall(id .. "Edge", lib.Vector3.new(1, H, z1 - z0 + 1), lib.CFrame.new(minX + edge * TILE, H / 2 - 8, (z0 + z1) / 2))
		end
	end
end

return shapes
