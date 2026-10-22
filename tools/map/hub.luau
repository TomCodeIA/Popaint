-- Popaint (générateur de map) : décor détaillé du hub — grande fontaine, place en mosaïque,
-- bord du hub en glaçage, jardins, chariots de bonbons. Tout est décoratif (aucune collision,
-- sauf les bassins de la fontaine).
local lib = require("./lib")
local props = require("./props")

local V3, CF, E = lib.Vector3, lib.CFrame, lib.Enum
local M = E.Material
local P = lib.P
local tint = lib.tint
local HALF = lib.HALF

local hub = {}

local function ringOf(parent, name, center, radius, count, size, colors, material)
	for k = 1, count do
		local a = k / count * math.pi * 2
		lib.ball(parent, name, center + V3.new(math.cos(a) * radius, 0, math.sin(a) * radius), size,
			colors[(k - 1) % #colors + 1], material)
	end
end

-- Arc de gouttes d'eau entre deux points (parabole)
local function waterArc(parent, from, to, height, drops)
	-- les gouttes défilent le long de l'arc : on dirait que l'eau coule en continu
	local function pointAt(t)
		return from:Lerp(to, t) + V3.new(0, math.sin(t * math.pi) * height, 0)
	end
	for k = 1, drops do
		local t = k / (drops + 1)
		local p = pointAt(t)
		local nextP = pointAt(math.min(1, t + 1 / (drops + 1)))
		local ball = lib.ball(parent, "Drop", p, 0.75 - t * 0.2, P.sky, M.Glass, { Transparency = 0.25 })
		local dir = nextP - p
		lib.anim(ball, "Flow", {
			FlowX = dir.X, FlowY = dir.Y, FlowZ = dir.Z, FlowDist = dir.Magnitude, FlowSpeed = 1.1, AnimRange = 200,
		})
	end
end

-- Petit poisson kawaii qui crache de l'eau (statue de la fontaine)
local function fish(parent, cf, color)
	local d = lib.details(parent)
	lib.blob(parent, "FishBody", cf, V3.new(2, 2.2, 2.8), color)
	local tail = lib.blob(parent, "FishTail", cf * CF.new(0, 0.6, 1.7) * CF.Angles(-0.6, 0, 0), V3.new(0.4, 1.8, 1.4), tint(color, 0.3))
	local _ = tail
	for _, x in { -1, 1 } do
		lib.ball(d, "FishEye", (cf * CF.new(x * 0.6, 0.4, -1.05)).Position, 0.5, P.ink)
		lib.ball(d, "FishShine", (cf * CF.new(x * 0.6 - 0.1, 0.55, -1.25)).Position, 0.2, P.white)
		lib.blob(d, "FishFin", cf * CF.new(x * 1, -0.3, 0) * CF.Angles(0, 0, x * 0.6), V3.new(0.2, 0.8, 1), tint(color, 0.3))
	end
	lib.cyl(d, "FishMouth", (cf * CF.new(0, -0.2, -1.4)).Position, 0.3, 0.6, P.rose, M.SmoothPlastic,
		{ CFrame = cf * CF.new(0, -0.2, -1.4) * CF.Angles(0, math.rad(90), 0) })
end

-- Grande fontaine à trois étages (remplace l'ancienne). Les bassins sont solides.
function hub.fountain(parent)
	local f = lib.model("Fountain", parent)
	local d = lib.details(f)
	-- bassin du bas
	lib.part({ Name = "Basin", Shape = E.PartType.Cylinder, Size = V3.new(2.4, 24, 24), CFrame = CF.new(0, 1.2, 0) * CF.Angles(0, 0, math.rad(90)),
		Color = P.white, Material = M.SmoothPlastic, Parent = f })
	lib.deco({ Name = "BasinBand", Shape = E.PartType.Cylinder, Size = V3.new(0.6, 24.4, 24.4), CFrame = CF.new(0, 0.6, 0) * CF.Angles(0, 0, math.rad(90)),
		Color = P.lavender, Material = M.SmoothPlastic, Parent = f })
	lib.deco({ Name = "Water", Shape = E.PartType.Cylinder, Size = V3.new(0.3, 22, 22), CFrame = CF.new(0, 2.35, 0) * CF.Angles(0, 0, math.rad(90)),
		Color = P.sky, Material = M.Glass, Transparency = 0.25, Parent = f })
	ringOf(f, "Rim", V3.new(0, 2.6, 0), 11.6, 44, 1.4, { P.pink, P.white, P.sky, P.white, P.butter, P.white, P.mint, P.white })
	-- festons sur le côté du bassin
	for k = 1, 28 do
		local a = k / 28 * math.pi * 2
		lib.blob(d, "Scallop", CF.new(math.cos(a) * 12.1, 1.4, math.sin(a) * 12.1) * CF.Angles(0, -a, 0), V3.new(0.5, 1.6, 2.4), lib.CANDY[k % #lib.CANDY + 1])
	end
	-- colonne avec anneaux
	lib.part({ Name = "Column", Shape = E.PartType.Cylinder, Size = V3.new(5, 3.2, 3.2), CFrame = CF.new(0, 4.5, 0) * CF.Angles(0, 0, math.rad(90)),
		Color = P.cream, Material = M.SmoothPlastic, Parent = f })
	for k, y in { 2.8, 4.4, 6 } do
		lib.cyl(f, "ColumnRing", V3.new(0, y, 0), 0.5, 3.8, lib.RAINBOW[k + 1])
	end
	-- bassin du milieu
	lib.part({ Name = "MidBowl", Shape = E.PartType.Cylinder, Size = V3.new(1.2, 12, 12), CFrame = CF.new(0, 7.2, 0) * CF.Angles(0, 0, math.rad(90)),
		Color = P.lavender, Material = M.SmoothPlastic, Parent = f })
	lib.blob(f, "MidBowlUnder", CF.new(0, 6.3, 0), V3.new(11, 2, 11), tint(P.lavender, 0.2))
	lib.deco({ Name = "Water", Shape = E.PartType.Cylinder, Size = V3.new(0.3, 11, 11), CFrame = CF.new(0, 7.85, 0) * CF.Angles(0, 0, math.rad(90)),
		Color = P.sky, Material = M.Glass, Transparency = 0.25, Parent = f })
	ringOf(f, "Rim", V3.new(0, 8, 0), 5.8, 24, 0.9, { P.white, P.pink })
	-- tige et coupe du haut
	lib.cyl(f, "Stem", V3.new(0, 9.4, 0), 2.6, 1.8, P.cream)
	lib.cyl(f, "TopBowl", V3.new(0, 10.8, 0), 0.9, 6, P.pink)
	lib.blob(f, "TopBowlUnder", CF.new(0, 10.2, 0), V3.new(5.6, 1.4, 5.6), tint(P.pink, 0.2))
	ringOf(f, "Rim", V3.new(0, 11.3, 0), 2.9, 14, 0.6, { P.white, P.butter })
	-- jets d'eau en arcs
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		local dir = V3.new(math.cos(a), 0, math.sin(a))
		waterArc(d, V3.new(0, 11.4, 0) + dir * 2.6, V3.new(0, 8.1, 0) + dir * 5, 1.6, 4)
		waterArc(d, V3.new(0, 8.1, 0) + dir * 5.6, V3.new(0, 2.6, 0) + dir * 9.5, 2.2, 6)
	end
	-- vaguelettes qui scintillent
	for k, r in { 4, 8, 6.5 } do
		local ripple = lib.deco({ Name = "Ripple", Shape = E.PartType.Cylinder, Size = V3.new(0.1, r * 2, r * 2),
			CFrame = CF.new(0, if k == 3 then 7.95 else 2.45, 0) * CF.Angles(0, 0, math.rad(90)), Color = P.white, Material = M.Glass,
			Transparency = 0.6, Parent = f })
		lib.anim(ripple, "Pulse", { PulseSpeed = 1.2 + k * 0.4, AnimRange = 200 })
	end
	-- poissons qui crachent de l'eau
	for k = 1, 4 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local pos = V3.new(math.cos(a) * 11.2, 3.6, math.sin(a) * 11.2)
		local cf = CF.lookAt(pos, V3.new(0, 3.6, 0))
		fish(f, cf, lib.CANDY[k])
		waterArc(d, (cf * CF.new(0, -0.2, -1.6)).Position, V3.new(math.cos(a) * 5, 2.6, math.sin(a) * 5), 2.4, 5)
	end
	-- grosse bulle au sommet (titre POPAINT) et petites bulles qui tournent autour
	local bubble = lib.ball(parent, "FountainBubble", V3.new(0, 15.5, 0), 7, P.pink, M.ForceField)
	lib.anim(bubble, "Bob", { BobAmp = 1, BobSpeed = 1.5, AnimRange = 300 })
	for k = 1, 5 do
		local orb = lib.model("FountainOrb", parent, "Atomic")
		local a = k / 5 * math.pi * 2
		local ball = lib.ball(orb, "Orb", V3.new(math.cos(a) * 6, 13 + (k % 2) * 2, math.sin(a) * 6), 1.4 + (k % 3) * 0.4, lib.CANDY[k], M.Glass,
			{ Transparency = 0.3 })
		orb.PrimaryPart = ball
		lib.anim(orb, "Swim,Bob", { SwimRadius = 2, SwimSpeed = 0.6 + k * 0.08, BobAmp = 0.8, BobSpeed = 1.4, AnimRange = 220 })
	end
	return bubble
end

-- Place en mosaïque autour de la fontaine (au ras du sol, on marche dessus)
-- Ambiance du hub : bulles de savon qui montent et pétales qui tombent sur la place
function hub.air(parent)
	local air = lib.folder("Air", parent)
	local up = lib.airBox(air, "AirBoxUp", CF.new(0, 6, 0), V3.new(170, 2, 170))
	lib.particles(up, "Soap", { P.sky, P.white, P.pink }, { Rate = 9, Size = 1.4 })
	local down = lib.airBox(air, "AirBoxDown", CF.new(0, 42, 0), V3.new(180, 2, 180))
	lib.particles(down, "Petals", { P.pink, P.white, P.lilac }, { Rate = 12, Size = 1.5, Direction = E.NormalId.Bottom })
	local sparkle = lib.airBox(air, "AirBoxFountain", CF.new(0, 13, 0), V3.new(16, 2, 16))
	lib.particles(sparkle, "Sparkle", { P.white, P.sky }, { Rate = 5, Size = 1.2 })
end

function hub.plaza(parent)
	local m = lib.model("Plaza", parent)
	for ringIdx, r in { 13.8, 16.2 } do
		local n = if ringIdx == 1 then 32 else 40
		for k = 1, n do
			local a = (k + ringIdx * 0.5) / n * math.pi * 2
			local w = 2 * math.pi * r / n - 0.3
			lib.deco({ Name = "Mosaic", Size = V3.new(w, 0.1, 2.2), CFrame = CF.new(math.cos(a) * r, 0.05, math.sin(a) * r) * CF.Angles(0, -a + math.pi / 2, 0),
				Color = if k % 2 == 0 then P.cream else lib.CANDY[(k + ringIdx) % #lib.CANDY + 1], Material = M.SmoothPlastic, Parent = m })
		end
	end
	lib.deco({ Name = "PlazaEdge", Shape = E.PartType.Cylinder, Size = V3.new(0.08, 36.4, 36.4), CFrame = CF.new(0, 0.03, 0) * CF.Angles(0, 0, math.rad(90)),
		Color = P.white, Material = M.SmoothPlastic, Parent = m })
	-- étoiles au sol entre les bases
	for k = 0, 7 do
		local a = math.rad(k * 45 + 22.5)
		local c = CF.new(math.cos(a) * 24, 0.08, math.sin(a) * 24)
		for r = 0, 4 do
			lib.deco({ Name = "FloorStar", Size = V3.new(0.9, 0.1, 2.2), CFrame = c * CF.Angles(0, r / 5 * math.pi * 2, 0) * CF.new(0, 0, 1),
				Color = P.butter, Material = M.SmoothPlastic, Parent = m })
		end
	end
	return m
end

-- Bord du hub : glaçage qui coule sur le côté de la plateforme (pas devant les ponts)
function hub.edge(parent, hubSides)
	local m = lib.model("HubEdge", parent)
	local d = lib.details(m)
	local rng = lib.rng(404)
	local sides = {
		{ "N", function(t) return V3.new(t, 0, -HALF - 0.3) end },
		{ "S", function(t) return V3.new(t, 0, HALF + 0.3) end },
		{ "W", function(t) return V3.new(-HALF - 0.3, 0, t) end },
		{ "E", function(t) return V3.new(HALF + 0.3, 0, t) end },
	}
	for _, sd in sides do
		local open = hubSides[sd[1]]
		for k = 0, 49 do
			local t = (k + 0.5) / 50 * lib.HUB - HALF
			if not (open and math.abs(t) < 14) then
				local p = sd[2](t)
				local long = rng(1, 2.4)
				lib.blob(d, "Icing", CF.new(p.X, -1.6 - long * 0.5, p.Z), V3.new(1.6, 1.6 + long, 1.6), P.cream)
			end
		end
		-- bandes colorées plus bas
		local a, b = sd[2](-HALF), sd[2](HALF)
		local mid = (a + b) / 2
		local horizontal = sd[1] == "N" or sd[1] == "S"
		for k, y in { -5, -6.8 } do
			lib.deco({ Name = "Band", Size = if horizontal then V3.new(lib.HUB + 1, 0.8, 0.3) else V3.new(0.3, 0.8, lib.HUB + 1),
				CFrame = CF.new(mid.X, y, mid.Z), Color = if k == 1 then P.lavender else P.sky, Material = M.SmoothPlastic, Parent = m })
		end
	end
	return m
end

-- Jardins entre les bases et les œufs : massifs de fleurs, buissons, chariots, bancs
function hub.gardens(parent, basePositions, eggPositions)
	local rng = lib.rng(2027)
	local function free(p, r)
		if math.abs(p.X) < 13 + r or math.abs(p.Z) < 13 + r then
			return false -- chemins vers les ponts
		end
		for _, b in basePositions do
			if (V3.new(p.X, 0, p.Z) - b).Magnitude < 16 + r then
				return false
			end
		end
		for _, e in eggPositions do
			if (V3.new(p.X, 0, p.Z) - e).Magnitude < 8 + r then
				return false
			end
		end
		return (p.X * p.X + p.Z * p.Z) > 20 * 20 and math.abs(p.X) < HALF - 4 and math.abs(p.Z) < HALF - 4
	end
	local placed = {}
	local function far(p, r)
		for _, q in placed do
			if (q[1] - p).Magnitude < q[2] + r then
				return false
			end
		end
		return true
	end
	local kinds = { "FlowerBed", "Bush", "Bush", "FlowerBed", "Rocks", "Bush" }
	local n = 0
	for _ = 1, 1200 do
		if n >= 34 then
			break
		end
		local a, r = rng(0, math.pi * 2), rng(20, 96)
		local p = V3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if free(p, 3) and far(p, 4) then
			local kind = kinds[n % #kinds + 1]
			props[kind](parent, p, rng, rng(0.9, 1.2))
			table.insert(placed, { p, 4 })
			n += 1
		end
	end
	-- deux chariots de bonbons et des bancs tournés vers la fontaine
	local carts = 0
	for _ = 1, 400 do
		if carts >= 2 then
			break
		end
		local a, r = rng(0, math.pi * 2), rng(40, 60)
		local p = V3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if free(p, 6) and far(p, 7) then
			props.CandyCart(parent, p, rng, 1, math.atan2(p.X, p.Z))
			table.insert(placed, { p, 7 })
			carts += 1
		end
	end
	local benches = 0
	for _ = 1, 400 do
		if benches >= 6 then
			break
		end
		local a = rng(0, math.pi * 2)
		local p = V3.new(math.cos(a) * 21, 0, math.sin(a) * 21)
		if free(p, 3) and far(p, 4) then
			props.Bench(parent, p, rng, 1, math.atan2(p.X, p.Z))
			table.insert(placed, { p, 4 })
			benches += 1
		end
	end
end

return hub
