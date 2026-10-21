--!strict
-- Popaint : calculs de la grille de peinture (purs, testés automatiquement).
-- Une zone est une grille de cases carrées ("studs peignables") posée à plat.
-- La case (1,1) est au coin minX/minZ de la zone.

local PaintGrid = {}

export type Grid = {
	OriginX: number, -- coordonnée X du bord de la zone (coin minX)
	OriginZ: number,
	TileSize: number,
	CountX: number,
	CountZ: number,
}

function PaintGrid.new(originX: number, originZ: number, tileSize: number, countX: number, countZ: number): Grid
	assert(tileSize > 0, "tileSize must be > 0")
	assert(countX > 0 and countZ > 0, "grid must not be empty")
	return { OriginX = originX, OriginZ = originZ, TileSize = tileSize, CountX = countX, CountZ = countZ }
end

-- Centre (x, z) de la case (i, j)
function PaintGrid.tileCenter(grid: Grid, i: number, j: number): (number, number)
	return grid.OriginX + (i - 0.5) * grid.TileSize, grid.OriginZ + (j - 0.5) * grid.TileSize
end

-- Case qui contient le point (x, z), ou nil si hors de la zone
function PaintGrid.tileAt(grid: Grid, x: number, z: number): (number?, number?)
	local i = math.floor((x - grid.OriginX) / grid.TileSize) + 1
	local j = math.floor((z - grid.OriginZ) / grid.TileSize) + 1
	if i < 1 or j < 1 or i > grid.CountX or j > grid.CountZ then
		return nil, nil
	end
	return i, j
end

function PaintGrid.contains(grid: Grid, x: number, z: number): boolean
	return x >= grid.OriginX
		and z >= grid.OriginZ
		and x <= grid.OriginX + grid.CountX * grid.TileSize
		and z <= grid.OriginZ + grid.CountZ * grid.TileSize
end

-- Toutes les cases dont le centre est dans le cercle (x, z, rayon).
-- Garantit au moins la case sous le centre si elle existe, pour qu'un éclatement peigne toujours quelque chose.
function PaintGrid.tilesInRadius(grid: Grid, x: number, z: number, radius: number): { { number } }
	local out = {}
	local ts = grid.TileSize
	local iMin = math.max(1, math.floor((x - radius - grid.OriginX) / ts) + 1)
	local iMax = math.min(grid.CountX, math.floor((x + radius - grid.OriginX) / ts) + 1)
	local jMin = math.max(1, math.floor((z - radius - grid.OriginZ) / ts) + 1)
	local jMax = math.min(grid.CountZ, math.floor((z + radius - grid.OriginZ) / ts) + 1)
	local r2 = radius * radius
	for i = iMin, iMax do
		for j = jMin, jMax do
			local cx, cz = PaintGrid.tileCenter(grid, i, j)
			local dx, dz = cx - x, cz - z
			if dx * dx + dz * dz <= r2 then
				table.insert(out, { i, j })
			end
		end
	end
	if #out == 0 then
		local ci, cj = PaintGrid.tileAt(grid, x, z)
		if ci and cj then
			table.insert(out, { ci, cj })
		end
	end
	return out
end

-- Clé unique d'une case, pour les tables de propriétaires
function PaintGrid.key(grid: Grid, i: number, j: number): number
	return (i - 1) * grid.CountZ + j
end

return PaintGrid
