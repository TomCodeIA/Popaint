-- Popaint (générateur de map) : pièces centrales des zones (Centerpiece dans Content/Zones.luau).
-- Elles sont dans le trou central de la forme : on ne peut pas monter dessus.
local lib = require("./lib")

local V3, CF, E = lib.Vector3, lib.CFrame, lib.Enum
local rgb = lib.rgb
local M = E.Material

local centerpieces = {}

-- Cylindre invisible, lisse et très haut : empêche de grimper sur la pièce centrale
local function blocker(parent, center, diameter)
	lib.part({ Name = "Blocker", Shape = E.PartType.Cylinder, Size = V3.new(80, diameter, diameter),
		CFrame = CF.new(center + V3.new(0, 32, 0)) * CF.Angles(0, 0, math.rad(90)),
		Transparency = 1, CanQuery = false, Parent = parent })
end

local function pedestal(parent, center, diameter, color)
	lib.part({ Name = "Pedestal", Shape = E.PartType.Cylinder, Size = V3.new(9, diameter, diameter),
		CFrame = CF.new(center + V3.new(0, -3.5, 0)) * CF.Angles(0, 0, math.rad(90)),
		Color = color, Material = M.SmoothPlastic, Parent = parent })
end

function centerpieces.GiantCandy(zf, center)
	pedestal(zf, center, 30, rgb(255, 120, 190))
	blocker(zf, center, 34)
	local candy = lib.model("GiantCandy", zf, "Atomic", true)
	local body = lib.blob(candy, "Body", CF.new(center + V3.new(0, 15, 0)), V3.new(22, 15, 15), rgb(255, 92, 168))
	candy.PrimaryPart = body
	for k, x in { -5, 0, 5 } do
		local d = if k == 2 then 15.4 else 13.6
		lib.deco({ Name = "Stripe", Shape = E.PartType.Cylinder, Size = V3.new(2, d, d), CFrame = CF.new(center + V3.new(x, 15, 0)),
			Color = rgb(255, 255, 255), Material = M.SmoothPlastic, Parent = candy })
	end
	for _, side in { -1, 1 } do
		lib.deco({ Name = "Twist", Shape = E.PartType.Cylinder, Size = V3.new(4, 5, 5), CFrame = CF.new(center + V3.new(side * 12.5, 15, 0)),
			Color = rgb(255, 214, 64), Material = M.Neon, Parent = candy })
		local wrap = lib.deco({ Name = "Wrapper", Size = V3.new(12, 6, 12),
			CFrame = CF.new(center + V3.new(side * 17, 15, 0)) * CF.Angles(0, 0, math.rad(side * -90)),
			Color = rgb(255, 170, 220), Material = M.SmoothPlastic, Parent = candy })
		local wm = lib.Instance.new("SpecialMesh")
		wm.MeshType = E.MeshType.Wedge
		wm.Parent = wrap
	end
	lib.light(body, rgb(255, 150, 210), 40, 1.5)
	lib.anim(candy, "Spin,Bob", { SpinSpeed = 18, BobAmp = 1.5, BobSpeed = 1.2 })
end

function centerpieces.Lighthouse(zf, center)
	pedestal(zf, center, 22, rgb(40, 35, 80))
	local tower = lib.model("Lighthouse", zf, "Atomic", true)
	local y = 1
	for k = 1, 8 do
		local r = 12 - k * 0.6
		local p = lib.part({ Name = "Floor" .. k, Shape = E.PartType.Cylinder, Size = V3.new(5, r, r),
			CFrame = CF.new(center + V3.new(0, y + 2.5, 0)) * CF.Angles(0, 0, math.rad(90)),
			Color = if k % 2 == 0 then rgb(82, 215, 255) else rgb(35, 30, 75),
			Material = if k % 2 == 0 then M.Neon else M.SmoothPlastic, Parent = tower })
		if k == 1 then
			tower.PrimaryPart = p
		end
		y += 5
	end
	local lamp = lib.ball(tower, "Lamp", center + V3.new(0, y + 3, 0), 7, rgb(255, 240, 120), M.Neon)
	lib.light(lamp, rgb(255, 240, 160), 60, 2)
	lib.anim(lamp, "Pulse", { PulseSpeed = 2 })
	local beam = lib.model("LightBeam", zf, "Atomic")
	local ray = lib.deco({ Name = "Ray", Size = V3.new(70, 2, 2), CFrame = CF.new(center + V3.new(0, y + 3, 0)),
		Color = rgb(255, 245, 160), Material = M.Neon, Transparency = 0.45, Parent = beam })
	beam.PrimaryPart = ray
	lib.anim(beam, "Spin", { SpinSpeed = 70 })
end

function centerpieces.GiantCrystal(zf, center)
	pedestal(zf, center, 22, rgb(200, 230, 255))
	local crystal = lib.model("GiantCrystal", zf, "Atomic", true)
	local main = lib.part({ Name = "Main", Size = V3.new(8, 44, 8), CFrame = CF.new(center + V3.new(0, 22, 0)) * CF.Angles(0, math.rad(45), 0),
		Color = rgb(120, 230, 255), Material = M.Neon, Transparency = 0.15, Parent = crystal })
	crystal.PrimaryPart = main
	for k, a in { 0, 120, 240 } do
		local rad = math.rad(a)
		lib.part({ Name = "Shard" .. k, Size = V3.new(5, 26, 5),
			CFrame = CF.new(center + V3.new(math.cos(rad) * 5, 12, math.sin(rad) * 5))
				* CF.Angles(math.rad(math.cos(rad) * 18), rad, math.rad(math.sin(rad) * -18)),
			Color = rgb(220, 245, 255), Material = M.Neon, Transparency = 0.2, Parent = crystal })
	end
	lib.light(main, rgb(150, 230, 255), 50, 2)
	lib.anim(crystal, "Pulse", { PulseSpeed = 1.5 })
end

function centerpieces.FloatingIsland(zf, center)
	local island = lib.model("FloatingIsland", zf, "Atomic", true)
	local rock = lib.blob(island, "Island", CF.new(center + V3.new(0, 14, 0)), V3.new(34, 12, 34), rgb(255, 245, 255))
	island.PrimaryPart = rock
	for k, c in lib.RAINBOW do
		local r = 15 - k * 1.6
		for a = 0, 180, 12 do
			local rad = math.rad(a)
			lib.deco({ Name = "Arc", Size = V3.new(2.2, 2.2, 2.2), CFrame = CF.new(center + V3.new(math.cos(rad) * r, 19 + math.sin(rad) * r, 0)),
				Color = c, Material = M.Neon, Parent = island })
		end
	end
	for k = 1, 3 do
		local a = k / 3 * math.pi * 2
		lib.ball(island, "Tree", center + V3.new(math.cos(a) * 9, 22, math.sin(a) * 9), 5, lib.RAINBOW[k + 1])
	end
	lib.anim(island, "Spin,Bob", { SpinSpeed = 12, BobAmp = 3, BobSpeed = 0.8 })
end

-- Cherche, dans un coin de la grille, un endroit assez loin de toutes les cases de jeu
local function freeSpot(inMask, cornerI, cornerJ, radiusTiles)
	local stepI = if cornerI == 1 then 1 else -1
	local stepJ = if cornerJ == 1 then 1 else -1
	for d = 0, 18 do
		for a = 0, d do
			local i, j = cornerI + stepI * a, cornerJ + stepJ * (d - a)
			local clear = true
			for di = -math.ceil(radiusTiles), math.ceil(radiusTiles) do
				for dj = -math.ceil(radiusTiles), math.ceil(radiusTiles) do
					if di * di + dj * dj <= (radiusTiles + 1) ^ 2 and inMask(i + di, j + dj) then
						clear = false
					end
				end
			end
			if clear then
				return i, j
			end
		end
	end
	return cornerI, cornerJ
end

function centerpieces.JellyCubes(zf, center, info)
	-- cubes de gelée géants dans les coins libres du canyon en S
	for k, corner in { { 1, 1 }, { 40, 40 }, { 40, 1 }, { 1, 40 } } do
		local size = 14 + k * 2
		local ri, rj = freeSpot(info.InMask, corner[1], corner[2], size * 0.75 / lib.TILE)
		local pos = V3.new(info.MinX + (ri - 0.5) * lib.TILE, lib.WATER + size / 2, info.MinZ + (rj - 0.5) * lib.TILE)
		local cube = lib.deco({ Name = "GiantJelly", Size = V3.new(size, size, size), CFrame = CF.new(pos) * CF.Angles(0, math.rad(k * 25), 0),
			Color = lib.CANDY[k], Material = M.Glass, Transparency = 0.35, Parent = zf })
		lib.light(cube, lib.CANDY[k], 30, 1)
		lib.anim(cube, "Wobble", { WobbleSpeed = 2 + k * 0.3 })
	end
	local _ = center
end

function centerpieces.GiantPumpkin(zf, center)
	pedestal(zf, center, 30, rgb(60, 35, 80))
	blocker(zf, center, 34)
	local pumpkin = lib.model("GiantPumpkin", zf, "Atomic", true)
	local core = lib.blob(pumpkin, "Core", CF.new(center + V3.new(0, 12, 0)), V3.new(20, 18, 20), rgb(255, 120, 20))
	pumpkin.PrimaryPart = core
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		lib.blob(pumpkin, "Lobe", CF.new(center + V3.new(math.cos(a) * 7, 12, math.sin(a) * 7)), V3.new(11, 17, 11), rgb(255, 130, 30))
	end
	lib.cyl(pumpkin, "Stem", center + V3.new(0, 23, 0), 6, 3, rgb(90, 140, 60))
	local glow = rgb(255, 230, 90)
	-- visage sur les 4 côtés (il tourne)
	for k = 0, 3 do
		local face = CF.new(center + V3.new(0, 12, 0)) * CF.Angles(0, k * math.pi / 2, 0)
		for _, x in { -4, 4 } do
			lib.deco({ Name = "Eye", Size = V3.new(3.4, 3.4, 1), CFrame = face * CF.new(x, 3, -12.4) * CF.Angles(0, 0, math.rad(45)),
				Color = glow, Material = M.Neon, Parent = pumpkin })
		end
		lib.deco({ Name = "Mouth", Size = V3.new(10, 2.2, 1), CFrame = face * CF.new(0, -3, -12.4), Color = glow, Material = M.Neon, Parent = pumpkin })
	end
	lib.light(core, rgb(255, 150, 50), 60, 2.5)
	lib.anim(pumpkin, "Spin,Bob", { SpinSpeed = 10, BobAmp = 1, BobSpeed = 0.9 })
end

return centerpieces
