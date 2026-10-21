-- Popaint (générateur de map) : pièces centrales des zones (Centerpiece dans Content/Zones.luau).
-- Elles sont dans le trou central de la forme : on ne peut pas monter dessus.
local lib = require("./lib")

local V3, CF, E = lib.Vector3, lib.CFrame, lib.Enum
local rgb = lib.rgb
local M = E.Material

local centerpieces = {}
local P = lib.P

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

local tint = lib.tint

-- Visage kawaii géant (cf = centre du visage, regard vers -Z)
local function bigFace(parent, cf, s)
	local d = lib.details(parent)
	for _, x in { -1, 1 } do
		lib.blob(parent, "Eye", cf * CF.new(x * 2.4 * s, 0.6 * s, 0), V3.new(1.8, 2.6, 1) * s, P.ink)
		lib.ball(d, "Shine", (cf * CF.new(x * 2.4 * s - 0.4 * s, 1.3 * s, -0.4 * s)).Position, 0.8 * s, P.white)
		lib.blob(d, "Blush", cf * CF.new(x * 4.2 * s, -0.9 * s, 0.2 * s), V3.new(2, 1.1, 0.6) * s, P.rose)
	end
	for k = -2, 2 do
		lib.ball(d, "Smile", (cf * CF.new(k * 0.45 * s, -1.1 * s - (2 - math.abs(k)) * 0.22 * s, 0)).Position, 0.5 * s, P.ink)
	end
end

-- Socle décoré : anneaux, festons et petites boules
local function fancyPedestal(parent, center, diameter, color, trim)
	pedestal(parent, center, diameter, color)
	local d = lib.details(parent)
	lib.part({ Name = "PedestalTop", Shape = E.PartType.Cylinder, Size = V3.new(0.6, diameter + 1, diameter + 1),
		CFrame = CF.new(center + V3.new(0, 1.2, 0)) * CF.Angles(0, 0, math.rad(90)), Color = trim, Material = M.SmoothPlastic, Parent = parent })
	local n = math.floor(diameter * 0.9)
	for k = 1, n do
		local a = k / n * math.pi * 2
		local r = diameter / 2 + 0.3
		lib.ball(d, "Pearl", center + V3.new(math.cos(a) * r, 1.6, math.sin(a) * r), 0.9, if k % 2 == 0 then trim else P.white)
		if k % 2 == 0 then
			lib.blob(d, "Scallop", CF.new(center + V3.new(math.cos(a) * r, -0.6, math.sin(a) * r)) * CF.Angles(0, -a, 0), V3.new(0.6, 2.2, 2.2), tint(trim, 0.3))
		end
	end
end

function centerpieces.GiantCandy(zf, center)
	fancyPedestal(zf, center, 30, P.pink, P.butter)
	blocker(zf, center, 34)
	local candy = lib.model("GiantCandy", zf, "Atomic", true)
	local d = lib.details(candy)
	local body = lib.blob(candy, "Body", CF.new(center + V3.new(0, 15, 0)), V3.new(22, 15, 15), P.pink)
	candy.PrimaryPart = body
	for k, x in { -6, -2, 2, 6 } do
		lib.deco({ Name = "Stripe", Shape = E.PartType.Cylinder, Size = V3.new(1.6, if math.abs(x) < 3 then 15.3 else 13, if math.abs(x) < 3 then 15.3 else 13),
			CFrame = CF.new(center + V3.new(x, 15, 0)) * CF.Angles(math.rad(k * 8), 0, 0),
			Color = if k % 2 == 0 then P.white else P.lavender, Material = M.SmoothPlastic, Parent = candy })
	end
	-- vermicelles sur le bonbon
	local rng = lib.rng(77)
	for _ = 1, 40 do
		local a, b = rng(0, math.pi * 2), rng(-1.2, 1.2)
		local dir = V3.new(math.cos(a) * math.cos(b) * 10.6, math.sin(b) * 7.2, math.sin(a) * math.cos(b) * 7.2)
		lib.block(d, "Sprinkle", CF.lookAt(center + V3.new(0, 15, 0) + dir, center + V3.new(0, 15, 0) + dir * 2) * CF.Angles(0, 0, rng(0, 3)),
			V3.new(0.5, 1.6, 0.5), lib.pick(rng, lib.CANDY), M.SmoothPlastic, { TopSurface = E.SurfaceType.Smooth })
	end
	for _, side in { -1, 1 } do
		lib.deco({ Name = "Twist", Shape = E.PartType.Cylinder, Size = V3.new(4, 5, 5), CFrame = CF.new(center + V3.new(side * 12.5, 15, 0)),
			Color = P.butter, Material = M.SmoothPlastic, Parent = candy })
		for k = 0, 2 do
			local wrap = lib.deco({ Name = "Wrapper", Size = V3.new(11 - k * 2, 5, 11 - k * 2),
				CFrame = CF.new(center + V3.new(side * (16.5 + k * 0.2), 15, 0)) * CF.Angles(math.rad(k * 30 - 30), 0, math.rad(side * -90)),
				Color = if k == 1 then P.lilac else P.pink, Material = M.SmoothPlastic, Parent = if k == 1 then d else candy })
			local wm = lib.Instance.new("SpecialMesh")
			wm.MeshType = E.MeshType.Wedge
			wm.Parent = wrap
		end
	end
	bigFace(candy, CF.new(center + V3.new(0, 15.5, -7.4)), 1)
	lib.light(body, P.pink, 36, 0.8)
	lib.anim(candy, "Spin,Bob", { SpinSpeed = 14, BobAmp = 1.5, BobSpeed = 1.1, AnimRange = 450 })
	-- petits bonbons en orbite
	for k = 1, 5 do
		local orb = lib.model("OrbitCandy", zf, "Atomic")
		local a = k / 5 * math.pi * 2
		local pos = center + V3.new(math.cos(a) * 13, 26 + (k % 2) * 3, math.sin(a) * 13)
		local c = lib.CANDY[k]
		local core = lib.blob(orb, "Candy", CF.new(pos), V3.new(3, 2, 2), c)
		orb.PrimaryPart = core
		for _, x in { -1, 1 } do
			lib.blob(orb, "Wrap", CF.new(pos + V3.new(x * 1.9, 0, 0)), V3.new(1.2, 1.6, 1.6), tint(c, 0.4))
		end
		lib.anim(orb, "Swim,Bob", { SwimRadius = 3, SwimSpeed = 0.5 + k * 0.07, BobAmp = 1.2, BobSpeed = 1 + k * 0.2, AnimRange = 450 })
	end
end

function centerpieces.Lighthouse(zf, center)
	fancyPedestal(zf, center, 22, P.sky, P.white)
	local tower = lib.model("Lighthouse", zf, "Atomic", true)
	local d = lib.details(tower)
	local y = 1
	for k = 1, 8 do
		local r = 12 - k * 0.6
		local p = lib.part({ Name = "Floor" .. k, Shape = E.PartType.Cylinder, Size = V3.new(5, r, r),
			CFrame = CF.new(center + V3.new(0, y + 2.5, 0)) * CF.Angles(0, 0, math.rad(90)),
			Color = if k % 2 == 0 then P.coral else P.white, Material = M.SmoothPlastic, Parent = tower })
		if k == 1 then
			tower.PrimaryPart = p
		end
		-- hublots
		if k % 2 == 1 and k > 1 then
			for w = 0, 3 do
				local a = w / 4 * math.pi * 2 + k
				lib.blob(d, "Window", CF.new(center + V3.new(math.cos(a) * r / 2, y + 2.5, math.sin(a) * r / 2)) * CF.Angles(0, -a + math.pi / 2, 0),
					V3.new(1.4, 1.8, 0.4), P.butter)
			end
		end
		y += 5
	end
	-- balcon avec rambarde
	lib.part({ Name = "Balcony", Shape = E.PartType.Cylinder, Size = V3.new(0.8, 11, 11),
		CFrame = CF.new(center + V3.new(0, y + 0.2, 0)) * CF.Angles(0, 0, math.rad(90)), Color = P.sky, Material = M.SmoothPlastic, Parent = tower })
	for k = 1, 16 do
		local a = k / 16 * math.pi * 2
		lib.cyl(d, "Rail", center + V3.new(math.cos(a) * 5.1, y + 1.3, math.sin(a) * 5.1), 1.6, 0.3, P.white)
	end
	local lamp = lib.ball(tower, "Lamp", center + V3.new(0, y + 3, 0), 6, P.butter, M.Glass, { Transparency = 0.2 })
	lib.light(lamp, P.butter, 50, 1.2)
	lib.anim(lamp, "Pulse", { PulseSpeed = 2, AnimRange = 450 })
	local roof = lib.blob(tower, "Roof", CF.new(center + V3.new(0, y + 7, 0)), V3.new(8, 4, 8), P.coral)
	lib.ball(d, "Tip", center + V3.new(0, y + 9.2, 0), 1.2, P.butter)
	local _ = roof
	local beam = lib.model("LightBeam", zf, "Atomic")
	local ray = lib.deco({ Name = "Ray", Size = V3.new(60, 1.6, 1.6), CFrame = CF.new(center + V3.new(0, y + 3, 0)),
		Color = P.butter, Material = M.SmoothPlastic, Transparency = 0.6, Parent = beam })
	beam.PrimaryPart = ray
	lib.anim(beam, "Spin", { SpinSpeed = 50, AnimRange = 450 })
	-- mouettes qui tournent autour
	for k = 1, 3 do
		local gull = lib.model("Seagull", zf, "Atomic")
		local pos = center + V3.new(14, y - 4 + k * 3, 0)
		local b = lib.blob(gull, "Body", CF.new(pos), V3.new(1, 1, 2), P.white)
		gull.PrimaryPart = b
		for _, x in { -1, 1 } do
			lib.blob(gull, "Wing", CF.new(pos + V3.new(x * 1.4, 0.3, 0)) * CF.Angles(0, 0, x * 0.4), V3.new(2.4, 0.2, 1), P.white)
		end
		lib.blob(gull, "Beak", CF.new(pos + V3.new(0, 0, -1.2)), V3.new(0.3, 0.3, 0.6), P.peach)
		lib.anim(gull, "Swim,Bob", { SwimRadius = 4 + k, SwimSpeed = 0.3 + k * 0.08, BobAmp = 1, BobSpeed = 0.8, AnimRange = 450 })
	end
end

function centerpieces.GiantCrystal(zf, center)
	fancyPedestal(zf, center, 22, P.lavender, P.sky)
	local crystal = lib.model("GiantCrystal", zf, "Atomic", true)
	local d = lib.details(crystal)
	local main = lib.part({ Name = "Main", Size = V3.new(8, 40, 8), CFrame = CF.new(center + V3.new(0, 21, 0)) * CF.Angles(0, math.rad(45), 0),
		Color = P.sky, Material = M.Glass, Transparency = 0.2, Parent = crystal })
	crystal.PrimaryPart = main
	lib.part({ Name = "Tip", Size = V3.new(5.6, 5.6, 5.6), CFrame = CF.new(center + V3.new(0, 41, 0)) * CF.Angles(math.rad(45), math.rad(45), 0),
		Color = P.sky, Material = M.Glass, Transparency = 0.2, Parent = crystal })
	lib.part({ Name = "Core", Size = V3.new(3, 34, 3), CFrame = CF.new(center + V3.new(0, 21, 0)) * CF.Angles(0, math.rad(45), 0),
		Color = P.white, Material = M.SmoothPlastic, Parent = crystal })
	for k, a in { 0, 72, 144, 216, 288 } do
		local rad = math.rad(a)
		local h = 14 + (k % 3) * 6
		lib.part({ Name = "Shard" .. k, Size = V3.new(4, h, 4),
			CFrame = CF.new(center + V3.new(math.cos(rad) * 5, h / 2 - 1, math.sin(rad) * 5))
				* CF.Angles(math.rad(math.cos(rad) * 18), rad, math.rad(math.sin(rad) * -18)),
			Color = lib.pick(lib.rng(k), { P.lilac, P.lavender, P.aqua, P.pink }), Material = M.Glass, Transparency = 0.25, Parent = crystal })
	end
	-- éclats flottants
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		lib.part({ Name = "Floater", Size = V3.new(1.4, 2.6, 1.4),
			CFrame = CF.new(center + V3.new(math.cos(a) * 9, 18 + (k % 3) * 6, math.sin(a) * 9)) * CF.Angles(0.4, a, 0.4),
			Color = lib.CANDY[k], Material = M.Glass, Transparency = 0.15, CanCollide = false, CanQuery = false, CanTouch = false, Parent = d })
	end
	lib.light(main, P.sky, 44, 1)
	lib.anim(crystal, "Pulse,Spin", { PulseSpeed = 1.2, SpinSpeed = 6, AnimRange = 450 })
end

function centerpieces.FloatingIsland(zf, center)
	local island = lib.model("FloatingIsland", zf, "Atomic", true)
	local d = lib.details(island)
	local rock = lib.blob(island, "Island", CF.new(center + V3.new(0, 14, 0)), V3.new(34, 12, 34), P.cream)
	island.PrimaryPart = rock
	lib.blob(island, "Grass", CF.new(center + V3.new(0, 18.5, 0)), V3.new(31, 3, 31), P.mint)
	-- dessous en stalactites de nuage
	for k = 1, 7 do
		local a = k / 7 * math.pi * 2
		lib.blob(island, "Under", CF.new(center + V3.new(math.cos(a) * 8, 8, math.sin(a) * 8)), V3.new(9, 8, 9), tint(P.lavender, 0.4))
	end
	for k, c in lib.RAINBOW do
		local r = 15 - k * 1.6
		for a = 0, 180, 9 do
			local rad = math.rad(a)
			lib.deco({ Name = "Arc", Size = V3.new(2.1, 2.1, 2.1), CFrame = CF.new(center + V3.new(math.cos(rad) * r, 19 + math.sin(rad) * r, 0)),
				Color = c, Material = M.SmoothPlastic, Parent = island })
		end
	end
	for _, x in { -15, 15 } do
		for k = 1, 5 do
			lib.blob(island, "ArcCloud", CF.new(center + V3.new(x + (k - 3) * 1.2, 20 + (k % 2), (k - 3) * 0.8)), V3.new(4, 3, 4), P.white)
		end
	end
	-- petits arbres ronds et fleurs
	for k = 1, 4 do
		local a = k / 4 * math.pi * 2 + 0.4
		local p = center + V3.new(math.cos(a) * 9, 20, math.sin(a) * 9)
		lib.cyl(island, "Trunk", p + V3.new(0, 1.5, 0), 3, 0.9, P.cocoa)
		lib.ball(island, "Tree", p + V3.new(0, 4, 0), 4.5, lib.CANDY[k])
		lib.ball(d, "Fruit", p + V3.new(1.4, 4.6, -1.2), 0.8, P.white)
	end
	local rng = lib.rng(31)
	for _ = 1, 18 do
		local a, r = rng(0, math.pi * 2), rng(3, 13)
		lib.ball(d, "Flower", center + V3.new(math.cos(a) * r, 20.2, math.sin(a) * r), 0.8, lib.pick(rng, lib.CANDY))
	end
	lib.anim(island, "Spin,Bob", { SpinSpeed = 10, BobAmp = 3, BobSpeed = 0.7, AnimRange = 450 })
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
	-- cubes de gelée géants dans les coins libres du canyon en S, avec un fruit à l'intérieur
	for k, corner in { { 1, 1 }, { 40, 40 }, { 40, 1 }, { 1, 40 } } do
		local size = 14 + k * 2
		local ri, rj = freeSpot(info.InMask, corner[1], corner[2], size * 0.75 / lib.TILE)
		local pos = V3.new(info.MinX + (ri - 0.5) * lib.TILE, lib.WATER + size / 2, info.MinZ + (rj - 0.5) * lib.TILE)
		local jelly = lib.model("GiantJelly", zf, "Atomic", true)
		local cube = lib.deco({ Name = "GiantJelly", Size = V3.new(size, size, size), CFrame = CF.new(pos) * CF.Angles(0, math.rad(k * 25), 0),
			Color = lib.CANDY[k], Material = M.Glass, Transparency = 0.35, Parent = jelly })
		jelly.PrimaryPart = cube
		lib.ball(jelly, "Fruit", pos + V3.new(0, -size * 0.1, 0), size * 0.35, tint(lib.CANDY[k + 2], 0.1))
		lib.blob(jelly, "Cream", CF.new(pos + V3.new(0, size / 2 + 0.8, 0)), V3.new(size * 0.7, 2.4, size * 0.7), P.cream)
		lib.ball(jelly, "Cherry", pos + V3.new(0, size / 2 + 2.6, 0), 2.4, P.coral)
		bigFace(jelly, CF.new(pos) * CF.Angles(0, math.rad(k * 25), 0) * CF.new(0, size * 0.1, -size / 2 - 0.1), size / 14)
		lib.light(cube, lib.CANDY[k], 26, 0.6)
		lib.anim(jelly, "Wobble", { WobbleSpeed = 2 + k * 0.3, AnimRange = 450 })
	end
	local _ = center
end

function centerpieces.GiantPumpkin(zf, center)
	fancyPedestal(zf, center, 30, P.lilac, P.peach)
	blocker(zf, center, 34)
	local pumpkin = lib.model("GiantPumpkin", zf, "Atomic", true)
	local d = lib.details(pumpkin)
	local orange = lib.rgb(255, 190, 130)
	local core = lib.blob(pumpkin, "Core", CF.new(center + V3.new(0, 12, 0)), V3.new(20, 18, 20), orange)
	pumpkin.PrimaryPart = core
	for k = 1, 10 do
		local a = k / 10 * math.pi * 2
		lib.blob(pumpkin, "Lobe", CF.new(center + V3.new(math.cos(a) * 7, 12, math.sin(a) * 7)), V3.new(10, 17, 10), if k % 2 == 0 then orange else tint(orange, 0.12))
	end
	lib.cyl(pumpkin, "Stem", center + V3.new(0, 23, 0), 6, 3, P.sage)
	for _, x in { -1, 1 } do
		lib.blob(d, "Leaf", CF.new(center + V3.new(x * 3, 21.5, 0)) * CF.Angles(0, 0, x * -0.4), V3.new(5, 0.6, 3), P.mint)
	end
	-- vrille en spirale
	for k = 1, 10 do
		local a = k * 0.9
		lib.ball(d, "Curl", center + V3.new(math.cos(a) * (1.5 + k * 0.15), 24.5 + k * 0.25, math.sin(a) * (1.5 + k * 0.15)), 0.5, P.sage)
	end
	local glow = P.butter
	-- visage mignon sur les 4 côtés (il tourne)
	for k = 0, 3 do
		local face = CF.new(center + V3.new(0, 12, 0)) * CF.Angles(0, k * math.pi / 2, 0)
		for _, x in { -4, 4 } do
			lib.deco({ Name = "Eye", Size = V3.new(3, 3, 1), CFrame = face * CF.new(x, 3, -12.3) * CF.Angles(0, 0, math.rad(45)),
				Color = glow, Material = M.SmoothPlastic, Parent = pumpkin })
		end
		for m = -2, 2 do
			lib.deco({ Name = "Mouth", Size = V3.new(1.8, 1.6, 1), CFrame = face * CF.new(m * 1.9, -3 - (2 - math.abs(m)) * 0.5, -12.2),
				Color = glow, Material = M.SmoothPlastic, Parent = pumpkin })
		end
		lib.blob(d, "Blush", face * CF.new(-7, -1, -11), V3.new(2.6, 1.4, 0.6), P.rose)
		lib.blob(d, "Blush", face * CF.new(7, -1, -11), V3.new(2.6, 1.4, 0.6), P.rose)
	end
	lib.light(core, P.peach, 50, 1.2)
	lib.anim(pumpkin, "Spin,Bob", { SpinSpeed = 8, BobAmp = 1, BobSpeed = 0.9, AnimRange = 450 })
	-- chauves-souris mignonnes en orbite
	for k = 1, 4 do
		local bat = lib.model("Bat", zf, "Atomic")
		local pos = center + V3.new(16, 22 + k * 2.5, 0)
		local b = lib.ball(bat, "Body", pos, 1.6, P.plum)
		bat.PrimaryPart = b
		for _, x in { -1, 1 } do
			lib.blob(bat, "Wing", CF.new(pos + V3.new(x * 1.5, 0.2, 0)) * CF.Angles(0, 0, x * 0.3), V3.new(2.2, 0.9, 0.2), P.lavender)
			lib.ball(bat, "Eye", pos + V3.new(x * 0.3, 0.2, -0.75), 0.35, P.white)
		end
		lib.anim(bat, "Swim,Bob", { SwimRadius = 3 + k, SwimSpeed = 0.5 + k * 0.1, BobAmp = 1.5, BobSpeed = 1.5, AnimRange = 450 })
	end
end

return centerpieces
