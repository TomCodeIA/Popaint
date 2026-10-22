-- Popaint (générateur de map) : bibliothèque d'objets de décor, en couleurs pastel.
-- Chaque fonction construit un objet posé au point "pos" (Vector3, le sol sous l'objet) et renvoie
-- son modèle. "s" = échelle, "rng" = hasard déterministe.
-- Les petites pièces vont dans lib.details(m) : elles ne s'affichent que de près (src/Client/Detail.luau).
-- AJOUTER UN OBJET : écris une fonction ici, puis ajoute son nom dans un thème (themes.luau).
-- Pour voir le résultat sans Studio : tools/preview.sh props
local lib = require("./lib")

local V3, CF, E = lib.Vector3, lib.CFrame, lib.Enum
local rgb = lib.rgb
local M = E.Material
local P = lib.P
local tint, dark = lib.tint, lib.dark

local props = {}

local function at(pos, y)
	return V3.new(pos.X, pos.Y + y, pos.Z)
end

local function new(name, parent, big)
	return lib.model(name, parent, "Atomic", big)
end

local function yawCF(pos, rng)
	return CF.new(pos) * CF.Angles(0, rng(0, math.pi * 2), 0)
end

-- Anneau de boules autour de l'axe Y du repère cf
local function ring(parent, name, cf, radius, count, size, color, material)
	for k = 1, count do
		local a = k / count * math.pi * 2
		lib.ball(parent, name, (cf * CF.new(math.cos(a) * radius, 0, math.sin(a) * radius)).Position, size, color, material)
	end
end

-- Petits vermicelles colorés sur une surface (cf = centre de la surface, vers le haut)
local function sprinkles(parent, cf, radius, n, rng, size)
	for _ = 1, n do
		local a, d = rng(0, math.pi * 2), math.sqrt(rng()) * radius
		lib.block(parent, "Sprinkle", cf * CF.new(math.cos(a) * d, 0, math.sin(a) * d) * CF.Angles(0, rng(0, math.pi), rng(-0.3, 0.3)),
			V3.new(0.25, 0.25, 0.9) * (size or 1), lib.pick(rng, lib.CANDY), M.SmoothPlastic, { TopSurface = E.SurfaceType.Smooth })
	end
end

-- Petit visage « kawaii » : yeux avec reflet, bouche, joues roses. cf = centre du visage, regard vers -Z
local function face(parent, cf, s, rng)
	local d = lib.details(parent)
	for _, x in { -1, 1 } do
		lib.blob(d, "Eye", cf * CF.new(x * 0.55 * s, 0.15 * s, 0), V3.new(0.42, 0.6, 0.3) * s, P.ink)
		lib.ball(d, "Shine", (cf * CF.new(x * 0.55 * s - 0.08 * s, 0.32 * s, -0.12 * s)).Position, 0.18 * s, P.white)
		lib.blob(d, "Blush", cf * CF.new(x * 0.95 * s, -0.2 * s, 0.05 * s), V3.new(0.45, 0.25, 0.15) * s, P.rose)
	end
	local smile = (rng and rng() < 0.5)
	if smile then
		for k = -1, 1 do
			lib.ball(d, "Mouth", (cf * CF.new(k * 0.14 * s, -0.25 * s - (if k == 0 then 0.06 * s else 0), 0)).Position, 0.13 * s, P.ink)
		end
	else
		lib.blob(d, "Mouth", cf * CF.new(0, -0.27 * s, 0), V3.new(0.3, 0.22, 0.15) * s, P.ink)
	end
end

---------------------------------------------------------------- Bonbons
function props.Lollipop(parent, pos, rng, s)
	local m = new("Lollipop", parent)
	local d = lib.details(m)
	local h = (14 + rng(0, 8)) * s
	local stick = lib.cyl(m, "Stick", at(pos, h / 2), h, 1.2 * s, P.white)
	m.PrimaryPart = stick
	local r = 5 * s
	local c1, c2 = lib.pick(rng, lib.CANDY), lib.pick(rng, lib.CANDY)
	local head = CF.new(at(pos, h + r * 0.85)) * CF.Angles(0, rng(0, math.pi * 2), 0)
	-- disque (axe X = épaisseur) + spirale de boules en deux couleurs
	lib.deco({ Name = "Disc", Shape = E.PartType.Cylinder, Size = V3.new(1.6 * s, r * 2, r * 2), CFrame = head, Color = P.cream,
		Material = M.SmoothPlastic, Parent = m })
	for k = 1, 26 do
		local a = k * 0.55
		local rr = r * (k / 26) * 0.92
		for _, side in { -1, 1 } do
			lib.ball(d, "Swirl", (head * CF.new(side * 0.75 * s, math.cos(a) * rr, math.sin(a) * rr)).Position, (0.9 + k * 0.03) * s,
				if k % 2 == 0 then c1 else c2)
		end
	end
	ring(d, "Rim", head * CF.Angles(0, 0, math.rad(90)), r, 18, 1.2 * s, tint(c1, 0.3))
	-- ruban noué sous le bonbon
	local bow = head * CF.new(0, -r - 0.6 * s, 0)
	lib.blob(d, "Knot", bow, V3.new(1, 1, 1) * s, P.rose)
	for _, z in { -1, 1 } do
		lib.blob(d, "Ribbon", bow * CF.new(0, 0, z * 1 * s) * CF.Angles(math.rad(z * 30), 0, 0), V3.new(0.6, 1.2, 1.8) * s, P.rose)
	end
	return m
end

function props.CandyCane(parent, pos, rng, s)
	local m = new("CandyCane", parent)
	local d = lib.details(m)
	local seg = 1.2 * s
	local n = math.floor(11 + rng(0, 6))
	local stripe = lib.pick(rng, { P.rose, P.mint, P.sky, P.lavender })
	for k = 1, n do
		local p = lib.cyl(m, "Seg", at(pos, (k - 0.5) * seg), seg, 1.8 * s, if k % 2 == 0 then stripe else P.white)
		if k == 1 then
			m.PrimaryPart = p
		end
	end
	local top = at(pos, n * seg)
	local yaw = rng(0, math.pi * 2)
	for k = 1, 12 do
		local a = k / 12 * math.pi
		local off = V3.new(math.cos(yaw) * (1 - math.cos(a)) * 2.4 * s, math.sin(a) * 2.4 * s, math.sin(yaw) * (1 - math.cos(a)) * 2.4 * s)
		lib.ball(m, "Hook", top + off, 1.9 * s, if k % 2 == 0 then stripe else P.white)
	end
	-- nœud en ruban et petites étoiles de sucre
	local knot = at(pos, n * seg * 0.7)
	lib.blob(d, "Bow", CF.new(knot) * CF.Angles(0, yaw, 0) * CF.new(0, 0, -1 * s), V3.new(2.2, 1.2, 0.6) * s, P.butter)
	for _ = 1, 4 do
		lib.ball(d, "Sugar", knot + V3.new(rng(-1.2, 1.2), rng(-2, 4), rng(-1.2, 1.2)) * s, 0.4 * s, P.white, M.SmoothPlastic)
	end
	return m
end

function props.Gumdrop(parent, pos, rng, s)
	local m = new("Gumdrop", parent)
	local d = lib.details(m)
	local size = (5 + rng(0, 3)) * s
	local c = lib.pick(rng, lib.CANDY)
	local yaw = yawCF(pos, rng)
	local body = lib.blob(m, "Drop", yaw * CF.new(0, size * 0.42, 0), V3.new(size, size * 1.05, size), c, M.Glass, { Transparency = 0.1 })
	m.PrimaryPart = body
	lib.blob(m, "Base", yaw * CF.new(0, size * 0.12, 0), V3.new(size * 1.1, size * 0.3, size * 1.1), tint(c, 0.15), M.Glass)
	lib.blob(d, "Core", yaw * CF.new(0, size * 0.45, 0), V3.new(0.6, 0.6, 0.6) * size, tint(c, 0.45), M.SmoothPlastic, { Transparency = 0.3 })
	for _ = 1, 14 do
		local a, h = rng(0, math.pi * 2), rng(0.25, 0.85)
		local r = size * 0.5 * math.sqrt(1 - (h - 0.4) ^ 2) * 0.98
		lib.ball(d, "Sugar", (yaw * CF.new(math.cos(a) * r, size * h, math.sin(a) * r)).Position, 0.45 * s, P.white, M.SmoothPlastic)
	end
	face(m, yaw * CF.new(0, size * 0.45, -size * 0.49), size * 0.22, rng)
	return m
end

function props.Donut(parent, pos, rng, s)
	local m = new("Donut", parent)
	local d = lib.details(m)
	local r = 4 * s
	local dough = rgb(240, 205, 160)
	local icing = lib.pick(rng, { P.pink, P.lavender, P.mint, P.sky, P.butter })
	local center = CF.new(at(pos, 2.6 * s)) * CF.Angles(math.rad(rng(-15, 15)), rng(0, math.pi * 2), 0)
	for k = 1, 18 do
		local a = k / 18 * math.pi * 2
		local p = center * CF.new(math.cos(a) * r, 0, math.sin(a) * r)
		local dp = lib.ball(m, "Dough", p.Position, 3.4 * s, dough)
		if k == 1 then
			m.PrimaryPart = dp
		end
		lib.blob(m, "Icing", p * CF.new(0, 0.75 * s, 0), V3.new(3.3, 2.2, 3.3) * s, icing)
		-- gouttes de glaçage
		if k % 3 == 0 then
			lib.blob(d, "Drip", p * CF.new(math.cos(a) * 1.4 * s, 0, math.sin(a) * 1.4 * s), V3.new(0.9, 1.6, 0.9) * s, icing)
		end
	end
	sprinkles(d, center * CF.new(0, 1.9 * s, 0), r * 1.1, 26, rng, s)
	return m
end

function props.Cupcake(parent, pos, rng, s)
	local m = new("Cupcake", parent)
	local d = lib.details(m)
	local wrapper = lib.pick(rng, { P.pink, P.sky, P.butter, P.mint, P.lavender })
	local cake = lib.cyl(m, "Cup", at(pos, 2.4 * s), 4.8 * s, 6.4 * s, wrapper)
	m.PrimaryPart = cake
	-- plis du papier
	for k = 1, 16 do
		local a = k / 16 * math.pi * 2
		lib.block(d, "Pleat", CF.new(at(pos, 2.4 * s)) * CF.Angles(0, a, 0) * CF.new(0, 0, 3.15 * s), V3.new(0.35, 4.6, 0.3) * s,
			tint(wrapper, 0.35), M.SmoothPlastic, { TopSurface = E.SurfaceType.Smooth })
	end
	lib.cyl(m, "Lip", at(pos, 4.9 * s), 0.5 * s, 7 * s, tint(wrapper, 0.25))
	local cream = lib.pick(rng, { P.cream, P.pink, P.lilac, P.mint })
	local y = 5.6 * s
	for k = 1, 4 do
		local w = (7.2 - k * 1.5) * s
		lib.blob(m, "Cream", CF.new(at(pos, y)) * CF.Angles(0, k * 0.7, 0), V3.new(w, 1.9 * s, w), cream)
		y += 1.25 * s
	end
	lib.ball(m, "Cherry", at(pos, y + 0.6 * s), 1.8 * s, P.coral)
	lib.block(d, "Stem", CF.new(at(pos, y + 1.8 * s)) * CF.Angles(0, 0, 0.3), V3.new(0.2, 1.4, 0.2) * s, P.sage, M.SmoothPlastic)
	sprinkles(d, CF.new(at(pos, 6.6 * s)), 2.6 * s, 18, rng, s)
	return m
end

function props.IceCream(parent, pos, rng, s)
	local m = new("IceCream", parent)
	local d = lib.details(m)
	local cone = rgb(240, 200, 150)
	for k = 1, 8 do
		local p = lib.cyl(m, "Cone", at(pos, (k - 0.5) * 1 * s), 1 * s, (0.7 + k * 0.62) * s, if k % 2 == 0 then cone else tint(cone, 0.15))
		if k == 1 then
			m.PrimaryPart = p
		end
	end
	-- quadrillage de la gaufre
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		lib.block(d, "Waffle", CF.new(at(pos, 4 * s)) * CF.Angles(0, a, 0) * CF.Angles(math.rad(-21), 0, 0) * CF.new(0, 0, 1.75 * s),
			V3.new(0.2, 8.2, 0.2) * s, dark(cone, 0.15), M.SmoothPlastic, { TopSurface = E.SurfaceType.Smooth })
	end
	local y = 8.2 * s
	local flavors = { P.pink, P.cream, P.mint, P.lavender, P.butter, P.peach }
	for _ = 1, math.floor(2 + rng(0, 1.99)) do
		local f = lib.pick(rng, flavors)
		lib.ball(m, "Scoop", at(pos, y + 2.4 * s), 5.6 * s, f)
		ring(d, "ScoopRim", CF.new(at(pos, y + 0.9 * s)), 2.6 * s, 12, 1.1 * s, tint(f, 0.2))
		y += 3.8 * s
	end
	sprinkles(d, CF.new(at(pos, y + 1.2 * s)), 1.8 * s, 12, rng, s)
	lib.ball(m, "Cherry", at(pos, y + 1.9 * s), 1.5 * s, P.coral)
	return m
end

function props.Macaron(parent, pos, rng, s)
	local m = new("Macaron", parent)
	local d = lib.details(m)
	local base = CF.new(pos)
	for k = 1, math.floor(1 + rng(0, 2.99)) do
		local c = lib.pick(rng, lib.CANDY)
		local cf = base * CF.new(rng(-0.4, 0.4) * s, 0, rng(-0.4, 0.4) * s)
		local b = lib.blob(m, "Bottom", cf * CF.new(0, 1 * s, 0), V3.new(7, 2.2, 7) * s, c)
		if not m.PrimaryPart then
			m.PrimaryPart = b
		end
		ring(d, "Foot", cf * CF.new(0, 1.9 * s, 0), 3.2 * s, 16, 0.8 * s, tint(c, 0.2))
		lib.cyl(m, "Cream", (cf * CF.new(0, 2.3 * s, 0)).Position, 0.9 * s, 6.4 * s, P.cream)
		ring(d, "Foot", cf * CF.new(0, 2.7 * s, 0), 3.2 * s, 16, 0.8 * s, tint(c, 0.2))
		lib.blob(m, "Top", cf * CF.new(0, 3.6 * s, 0), V3.new(7, 2.2, 7) * s, c)
		base = base * CF.new(0, 4.4 * s, 0) * CF.Angles(0, rng(0, 1), 0)
	end
	return m
end

---------------------------------------------------------------- Port pastel (Neon Docks)
function props.NeonTower(parent, pos, rng, s)
	local m = new("NeonTower", parent, true)
	local d = lib.details(m)
	local w, dd = (9 + rng(0, 5)) * s, (9 + rng(0, 5)) * s
	local h = (26 + rng(0, 30)) * s
	local wall = lib.pick(rng, { P.lavender, P.sky, P.lilac, rgb(196, 200, 240) })
	local glow = lib.pick(rng, { P.butter, P.aqua, P.pink })
	local body = lib.block(m, "Body", CF.new(at(pos, h / 2)), V3.new(w, h, dd), wall)
	m.PrimaryPart = body
	lib.block(m, "Plinth", CF.new(at(pos, 1 * s)), V3.new(w + 1.4 * s, 2 * s, dd + 1.4 * s), dark(wall, 0.15))
	-- fenêtres en grille sur les 4 faces
	local floors = math.floor((h - 4 * s) / (3.6 * s))
	local cols = math.max(2, math.floor(w / (2.6 * s)))
	for f = 1, floors do
		local y = 3.5 * s + (f - 0.5) * 3.6 * s
		for c = 1, cols do
			local x = -w / 2 + (c - 0.5) * (w / cols)
			local lit = rng() < 0.65
			local col = if lit then glow else tint(wall, 0.5)
			for _, side in { { 0, -1 }, { 0, 1 } } do
				local win = lib.block(d, "Window", CF.new(at(pos, y)) * CF.new(x, 0, side[2] * (dd / 2 + 0.05)), V3.new(1.4, 2, 0.2) * s, col,
					M.SmoothPlastic, { TopSurface = E.SurfaceType.Smooth })
				local _ = win
			end
			for _, side in { -1, 1 } do
				lib.block(d, "Window", CF.new(at(pos, y)) * CF.new(side * (w / 2 + 0.05), 0, x * dd / w), V3.new(0.2, 2, 1.4) * s, col,
					M.SmoothPlastic, { TopSurface = E.SurfaceType.Smooth })
			end
		end
		if f % 3 == 0 then
			lib.block(d, "Ledge", CF.new(at(pos, y + 1.6 * s)), V3.new(w + 0.6 * s, 0.4 * s, dd + 0.6 * s), tint(wall, 0.4))
		end
	end
	-- toit : petit étage, enseigne et antenne
	lib.block(m, "Roof", CF.new(at(pos, h + 0.4 * s)), V3.new(w + 0.8 * s, 0.8 * s, dd + 0.8 * s), tint(wall, 0.3))
	lib.block(m, "Penthouse", CF.new(at(pos, h + 2.2 * s)), V3.new(w * 0.5, 3 * s, dd * 0.5), wall)
	local sign = lib.block(d, "RoofSign", CF.new(at(pos, h + 5 * s)), V3.new(w * 0.7, 2.4 * s, 0.4 * s), glow, M.SmoothPlastic,
		{ TopSurface = E.SurfaceType.Smooth })
	lib.light(sign, glow, 16, 0.6)
	lib.cyl(d, "Antenna", at(pos, h + 7.5 * s), 6 * s, 0.35 * s, P.white)
	local tip = lib.ball(d, "Blink", at(pos, h + 10.7 * s), 1.1 * s, P.coral, M.SmoothPlastic)
	lib.anim(tip, "Pulse", { PulseSpeed = 3 })
	return m
end

function props.Boat(parent, pos, rng, s)
	local m = new("Boat", parent)
	local d = lib.details(m)
	local hull = lib.pick(rng, { P.pink, P.sky, P.butter, P.mint, P.white })
	local stripe = lib.pick(rng, { P.rose, P.lavender, P.aqua })
	local base = yawCF(at(pos, 0.7 * s), rng)
	local h = lib.block(m, "Hull", base, V3.new(5.2, 2, 11) * s, hull, M.SmoothPlastic, { TopSurface = E.SurfaceType.Smooth })
	m.PrimaryPart = h
	lib.blob(m, "Bow", base * CF.new(0, 0, -5.6 * s), V3.new(5.2, 2, 4) * s, hull)
	lib.block(m, "Stripe", base * CF.new(0, 0.2 * s, 0), V3.new(5.35, 0.45, 11.1) * s, stripe, M.SmoothPlastic)
	lib.block(m, "Deck", base * CF.new(0, 1.05 * s, 0.4 * s), V3.new(4.6, 0.2, 10) * s, rgb(236, 210, 180), M.Wood)
	local cabin = lib.block(m, "Cabin", base * CF.new(0, 2.5 * s, 1.8 * s), V3.new(3.8, 2.8, 4) * s, P.cream)
	lib.block(m, "CabinRoof", base * CF.new(0, 4.05 * s, 1.8 * s), V3.new(4.4, 0.4, 4.6) * s, stripe)
	-- hublots
	for _, z in { 0.9, 2.7 } do
		for _, x in { -1, 1 } do
			lib.cyl(d, "Porthole", (base * CF.new(x * 1.92 * s, 2.6 * s, z * s)).Position, 0.2 * s, 1 * s, P.aqua, M.Glass)
		end
	end
	local _ = cabin
	-- mât, voile et fanion
	lib.cyl(m, "Mast", (base * CF.new(0, 6 * s, -2 * s)).Position, 9 * s, 0.4 * s, P.white)
	lib.block(m, "Sail", base * CF.new(0, 6 * s, -3.4 * s) * CF.Angles(0, math.rad(90), 0), V3.new(2.6, 6, 0.15) * s, P.cream, M.Fabric,
		{ TopSurface = E.SurfaceType.Smooth })
	lib.block(d, "Flag", base * CF.new(0, 10 * s, -2.6 * s), V3.new(0.1, 0.9, 1.2) * s, stripe, M.Fabric)
	-- bouée de sauvetage et rambarde
	ring(d, "Lifebuoy", base * CF.new(2.75 * s, 1.6 * s, -1.5 * s) * CF.Angles(0, 0, math.rad(90)), 0.8 * s, 10, 0.5 * s, P.coral)
	for k = -2, 2 do
		lib.cyl(d, "RailPost", (base * CF.new(2.4 * s, 1.6 * s, k * 1.2 * s - 3 * s)).Position, 1 * s, 0.2 * s, P.white)
		lib.cyl(d, "RailPost", (base * CF.new(-2.4 * s, 1.6 * s, k * 1.2 * s - 3 * s)).Position, 1 * s, 0.2 * s, P.white)
	end
	local lamp = lib.ball(d, "Lamp", (base * CF.new(0, 4.6 * s, 1.8 * s)).Position, 0.8 * s, P.butter, M.SmoothPlastic)
	lib.light(lamp, P.butter, 12, 0.6)
	lib.anim(m, "Bob", { BobAmp = 0.35, BobSpeed = 1.3 })
	return m
end

function props.Buoy(parent, pos, rng, s)
	local m = new("Buoy", parent)
	local d = lib.details(m)
	local c = lib.pick(rng, { P.coral, P.butter, P.pink })
	local f = lib.ball(m, "Float", at(pos, 0.6 * s), 3.2 * s, c)
	m.PrimaryPart = f
	lib.cyl(m, "Band", at(pos, 0.9 * s), 0.6 * s, 3.25 * s, P.white)
	lib.cyl(m, "Pole", at(pos, 3 * s), 3.4 * s, 0.5 * s, P.white)
	lib.cyl(m, "Cage", at(pos, 4.8 * s), 1.4 * s, 1.6 * s, c)
	local lamp = lib.ball(m, "Lamp", at(pos, 4.8 * s), 1.1 * s, P.aqua, M.SmoothPlastic)
	lib.light(lamp, P.aqua, 10, 0.6)
	lib.cyl(d, "Cap", at(pos, 5.7 * s), 0.3 * s, 1.7 * s, P.white)
	ring(d, "Ripple", CF.new(at(pos, 0.05)), 2.4 * s, 12, 0.5 * s, P.white)
	lib.anim(m, "Bob", { BobAmp = 0.4, BobSpeed = 1.8 })
	return m
end

function props.Crane(parent, pos, rng, s)
	local m = new("Crane", parent, true)
	local d = lib.details(m)
	local c = P.butter
	local h = (24 + rng(0, 8)) * s
	local leg
	for _, o in { { -1.6, -1.6 }, { 1.6, -1.6 }, { -1.6, 1.6 }, { 1.6, 1.6 } } do
		leg = lib.block(m, "Leg", CF.new(at(pos, h / 2) + V3.new(o[1], 0, o[2]) * s), V3.new(0.6 * s, h, 0.6 * s), c)
	end
	m.PrimaryPart = leg
	-- croisillons de la tour
	for y = 3, h / s - 2, 4 do
		for _, side in { { 0, -1.6 }, { 0, 1.6 } } do
			lib.block(d, "Brace", CF.new(at(pos, y * s) + V3.new(side[1], 0, side[2]) * s) * CF.Angles(0, 0, math.rad(45)), V3.new(0.25, 4.4, 0.25) * s,
				tint(c, 0.3), M.SmoothPlastic)
		end
	end
	local yaw = CF.Angles(0, rng(0, math.pi * 2), 0)
	local top = CF.new(at(pos, h)) * yaw
	lib.block(m, "Arm", top * CF.new(0, 0.6 * s, -7 * s), V3.new(1.4, 1.4, 24) * s, c)
	lib.block(m, "Counter", top * CF.new(0, 0, 5 * s), V3.new(3.4, 2.4, 2.4) * s, P.lavender)
	lib.block(m, "Cabin", top * CF.new(0, 2.4 * s, 0), V3.new(3.2, 2.6, 3.2) * s, P.cream)
	lib.block(d, "CabinGlass", top * CF.new(0, 2.6 * s, -1.62 * s), V3.new(2.6, 1.4, 0.1) * s, P.aqua, M.Glass)
	lib.block(m, "Cable", top * CF.new(0, -5 * s, -16 * s), V3.new(0.2, 10, 0.2) * s, P.ink, M.SmoothPlastic)
	lib.block(d, "Hook", top * CF.new(0, -10.3 * s, -16 * s), V3.new(0.8, 0.8, 0.3) * s, P.ink, M.SmoothPlastic)
	local crate = lib.block(m, "Crate", top * CF.new(0, -12.4 * s, -16 * s), V3.new(4, 3.4, 4) * s, lib.pick(rng, lib.CANDY), M.Wood)
	local _ = crate
	for _, x in { -2.05, 2.05 } do
		lib.block(d, "Slat", top * CF.new(x * s, -12.4 * s, -16 * s), V3.new(0.1, 3.4, 4.1) * s, P.white, M.Wood)
	end
	local beacon = lib.ball(d, "Beacon", (top * CF.new(0, 1.6 * s, -19 * s)).Position, 0.8 * s, P.coral, M.SmoothPlastic)
	lib.anim(beacon, "Pulse", { PulseSpeed = 2.5 })
	return m
end

function props.NeonSign(parent, pos, rng, s)
	local m = new("NeonSign", parent)
	local d = lib.details(m)
	local p1 = lib.cyl(m, "Post", at(pos, 5 * s) + V3.new(-3.2 * s, 0, 0), 10 * s, 0.5 * s, P.lavender)
	m.PrimaryPart = p1
	lib.cyl(m, "Post", at(pos, 5 * s) + V3.new(3.2 * s, 0, 0), 10 * s, 0.5 * s, P.lavender)
	local yaw = CF.Angles(0, rng(0, math.pi * 2), 0)
	local panelCF = CF.new(at(pos, 12 * s)) * yaw
	local panel = lib.block(m, "Panel", panelCF, V3.new(9.4, 4.4, 0.6) * s, P.cream)
	lib.block(m, "Frame", panelCF * CF.new(0, 0, 0.05 * s), V3.new(10, 5, 0.4) * s, P.lavender)
	local glow = lib.pick(rng, { P.pink, P.sky, P.mint, P.butter })
	local word = lib.pick(rng, { "POP!", "SPLASH", "WOW", "BUBBLES", "SWEET", "HELLO", "★ ★ ★" })
	for _, f in { E.NormalId.Front, E.NormalId.Back } do
		local t = lib.surfaceText(panel, f, word, dark(glow, 0.25))
		t.TextStrokeTransparency = 1
	end
	-- ampoules tout autour du panneau
	for k = 0, 11 do
		local x = -4.6 + (k % 6) * 1.84
		local y = if k < 6 then 2.3 else -2.3
		lib.ball(d, "Bulb", (panelCF * CF.new(x * s, y * s, -0.3 * s)).Position, 0.45 * s, glow, M.SmoothPlastic)
	end
	lib.light(panel, glow, 12, 0.5)
	return m
end

---------------------------------------------------------------- Gelée (Jelly Canyon)
function props.JellyCube(parent, pos, rng, s)
	local m = new("JellyCube", parent)
	local d = lib.details(m)
	local size = (6 + rng(0, 6)) * s
	local c = lib.pick(rng, lib.CANDY)
	local yaw = yawCF(pos, rng)
	local cube = lib.block(m, "Jelly", yaw * CF.new(0, size / 2, 0), V3.new(size, size, size), c, M.Glass,
		{ Transparency = 0.25, TopSurface = E.SurfaceType.Smooth })
	m.PrimaryPart = cube
	lib.block(m, "Plate", yaw * CF.new(0, 0.2 * s, 0), V3.new(size * 1.3, 0.4 * s, size * 1.3), P.white, M.SmoothPlastic,
		{ TopSurface = E.SurfaceType.Smooth })
	-- bulles et fruits pris dans la gelée
	for _ = 1, 6 do
		lib.ball(d, "Bubble", (yaw * CF.new(rng(-0.35, 0.35) * size, rng(0.2, 0.85) * size, rng(-0.35, 0.35) * size)).Position,
			rng(0.5, 1.1) * s, P.white, M.SmoothPlastic, { Transparency = 0.4 })
	end
	lib.ball(d, "Fruit", (yaw * CF.new(0, size * 0.45, 0)).Position, size * 0.28, tint(c, 0.5), M.SmoothPlastic)
	-- chantilly et cerise sur le dessus
	lib.blob(m, "Cream", yaw * CF.new(0, size + 0.6 * s, 0), V3.new(size * 0.45, 1.6 * s, size * 0.45), P.cream)
	lib.ball(d, "Cherry", (yaw * CF.new(0, size + 1.8 * s, 0)).Position, 1.2 * s, P.coral)
	face(m, yaw * CF.new(0, size * 0.5, -size / 2 - 0.05), size * 0.16, rng)
	lib.anim(cube, "Wobble", { WobbleSpeed = 2 + rng(0, 1.5) })
	return m
end

function props.GummyBear(parent, pos, rng, s)
	local m = new("GummyBear", parent)
	local d = lib.details(m)
	local c = lib.pick(rng, lib.CANDY)
	local g = { Transparency = 0.12 }
	local yaw = yawCF(pos, rng)
	local body = lib.blob(m, "Body", yaw * CF.new(0, 3.2 * s, 0), V3.new(4.4, 5.2, 3.6) * s, c, M.Glass, g)
	m.PrimaryPart = body
	lib.blob(m, "Belly", yaw * CF.new(0, 3 * s, -1.4 * s), V3.new(2.6, 3, 1) * s, tint(c, 0.35), M.Glass, g)
	local head = yaw * CF.new(0, 6.9 * s, 0)
	lib.blob(m, "Head", head, V3.new(3.8, 3.4, 3.4) * s, c, M.Glass, g)
	lib.blob(m, "Snout", head * CF.new(0, -0.5 * s, -1.5 * s), V3.new(1.6, 1.1, 0.9) * s, tint(c, 0.35), M.Glass, g)
	lib.ball(d, "Nose", (head * CF.new(0, -0.3 * s, -1.95 * s)).Position, 0.45 * s, P.ink)
	for _, x in { -1, 1 } do
		lib.ball(m, "Ear", (head * CF.new(x * 1.4 * s, 1.5 * s, 0)).Position, 1.4 * s, c, M.Glass, g)
		lib.ball(d, "EarIn", (head * CF.new(x * 1.4 * s, 1.5 * s, -0.4 * s)).Position, 0.8 * s, tint(c, 0.4), M.SmoothPlastic)
		lib.blob(m, "Arm", yaw * CF.new(x * 2.4 * s, 4 * s, -0.4 * s) * CF.Angles(0, 0, x * 0.5), V3.new(1.6, 2.4, 1.6) * s, c, M.Glass, g)
		lib.blob(m, "Leg", yaw * CF.new(x * 1.3 * s, 0.9 * s, -0.4 * s), V3.new(1.8, 1.8, 2.2) * s, c, M.Glass, g)
		lib.blob(d, "Paw", yaw * CF.new(x * 1.3 * s, 0.9 * s, -1.45 * s), V3.new(1, 1, 0.2) * s, tint(c, 0.4), M.SmoothPlastic)
	end
	face(m, head * CF.new(0, 0.3 * s, -1.6 * s), 0.9 * s, rng)
	return m
end

function props.Mushroom(parent, pos, rng, s)
	local m = new("Mushroom", parent)
	local d = lib.details(m)
	local h = (5 + rng(0, 4)) * s
	local stem = lib.blob(m, "Stem", CF.new(at(pos, h / 2)), V3.new(2.8 * s, h, 2.8 * s), P.cream)
	m.PrimaryPart = stem
	ring(d, "Skirt", CF.new(at(pos, h * 0.7)), 1.4 * s, 12, 0.8 * s, P.white)
	local cap = lib.pick(rng, { P.coral, P.lavender, P.sky, P.pink, P.mint })
	lib.blob(m, "Cap", CF.new(at(pos, h + 0.8 * s)), V3.new(8.4, 4.4, 8.4) * s, cap)
	lib.blob(m, "Gills", CF.new(at(pos, h - 0.2 * s)), V3.new(7.4, 1.2, 7.4) * s, tint(cap, 0.55))
	for _ = 1, 9 do
		local a, r = rng(0, math.pi * 2), rng(0.8, 3.1)
		local y = 1.9 * math.sqrt(math.max(0, 1 - (r / 4.2) ^ 2))
		lib.blob(d, "Dot", CF.new(at(pos, h + 0.8 * s + y * s) + V3.new(math.cos(a) * r, 0, math.sin(a) * r) * s), V3.new(1, 0.4, 1) * s, P.white)
	end
	face(m, CF.new(at(pos, h * 0.45)) * CF.new(0, 0, -1.42 * s), 0.85 * s, rng)
	-- petits champignons autour
	for _ = 1, 2 do
		local a = rng(0, math.pi * 2)
		local p = at(pos, 0) + V3.new(math.cos(a) * 3, 0, math.sin(a) * 3) * s
		lib.cyl(d, "BabyStem", at(p, 0.6 * s), 1.2 * s, 0.6 * s, P.cream)
		lib.blob(d, "BabyCap", CF.new(at(p, 1.3 * s)), V3.new(1.8, 1, 1.8) * s, cap)
	end
	return m
end

function props.JellyStack(parent, pos, rng, s)
	local m = new("JellyStack", parent, true)
	local d = lib.details(m)
	local y, size = 0, (14 + rng(0, 6)) * s
	lib.cyl(m, "Plate", at(pos, 0.3 * s), 0.6 * s, size * 1.25, P.white)
	for k = 1, 4 do
		local h = size * 0.5
		local c = lib.CANDY[(k % #lib.CANDY) + 1]
		local layer = lib.block(m, "Layer", CF.new(at(pos, y + h / 2 + 0.6 * s)) * CF.Angles(0, k * 0.4, 0), V3.new(size, h, size), c, M.Glass,
			{ Transparency = 0.22, TopSurface = E.SurfaceType.Smooth })
		if k == 1 then
			m.PrimaryPart = layer
		end
		-- frange de crème entre deux étages
		for q = 1, 12 do
			local a = q / 12 * math.pi * 2
			lib.ball(d, "Cream", at(pos, y + h + 0.6 * s) + V3.new(math.cos(a + k * 0.4), 0, math.sin(a + k * 0.4)) * size * 0.52,
				size * 0.12, P.cream)
		end
		y += h
		size *= 0.72
	end
	lib.ball(m, "Cherry", at(pos, y + 2 * s), 3 * s, P.coral)
	lib.block(d, "Stem", CF.new(at(pos, y + 3.8 * s)) * CF.Angles(0, 0, 0.4), V3.new(0.3, 2, 0.3) * s, P.sage, M.SmoothPlastic)
	return m
end

---------------------------------------------------------------- Cristal / neige (Crystal Peaks)
function props.CrystalCluster(parent, pos, rng, s)
	local m = new("CrystalCluster", parent)
	local d = lib.details(m)
	local c = lib.pick(rng, { P.sky, P.lavender, P.lilac, P.aqua, P.pink })
	local rock = lib.blob(m, "Rock", CF.new(at(pos, 0.8 * s)), V3.new(6, 2.4, 5) * s, rgb(220, 222, 240))
	m.PrimaryPart = rock
	for k = 1, math.floor(5 + rng(0, 3)) do
		local h = (4 + rng(0, 9)) * s
		local a = rng(0, math.pi * 2)
		local lean = rng(5, 32)
		local cf = CF.new(pos + V3.new(math.cos(a) * 1.4 * s, h / 2 + 0.8 * s, math.sin(a) * 1.4 * s))
			* CF.Angles(math.rad(math.cos(a) * lean), a, math.rad(math.sin(a) * lean))
		lib.block(m, "Crystal", cf, V3.new(1.7 * s, h, 1.7 * s), if k % 3 == 0 then tint(c, 0.4) else c, M.Glass,
			{ Transparency = 0.12, TopSurface = E.SurfaceType.Smooth })
		lib.block(d, "Tip", cf * CF.new(0, h / 2, 0) * CF.Angles(0, math.rad(45), 0), V3.new(1.2, 1.2, 1.2) * s, tint(c, 0.6), M.Glass,
			{ TopSurface = E.SurfaceType.Smooth })
	end
	for _ = 1, 5 do
		lib.ball(d, "Sparkle", at(pos, rng(2, 9) * s) + V3.new(rng(-3, 3), 0, rng(-3, 3)) * s, 0.35 * s, P.white, M.SmoothPlastic)
	end
	lib.light(rock, c, 10, 0.5)
	lib.anim(m, "Pulse", { PulseSpeed = 1 + rng(0, 1.5) })
	return m
end

function props.Pine(parent, pos, rng, s)
	local m = new("Pine", parent)
	local d = lib.details(m)
	local h = (11 + rng(0, 7)) * s
	local trunk = lib.cyl(m, "Trunk", at(pos, 1.6 * s), 3.2 * s, 1.6 * s, P.cocoa)
	m.PrimaryPart = trunk
	local leaf = lib.pick(rng, { P.sage, P.mint, rgb(170, 220, 205) })
	local layers = 5
	for k = 1, layers do
		local w = (8.4 - k * 1.35) * s
		local y = 3 * s + (k - 1) * (h / layers)
		local cf = CF.new(at(pos, y + h / layers / 2)) * CF.Angles(0, math.rad(k * 22), 0)
		lib.block(m, "Leaves", cf, V3.new(w, h / layers, w), leaf)
		lib.block(m, "Leaves", cf * CF.Angles(0, math.rad(45), 0), V3.new(w * 0.8, h / layers * 0.9, w * 0.8), leaf)
		lib.block(m, "Snow", cf * CF.new(0, h / layers / 2, 0), V3.new(w * 0.85, 0.5 * s, w * 0.85), P.white, M.Snow)
		-- guirlande de boules
		for q = 1, 4 do
			local a = q / 4 * math.pi * 2 + k
			lib.ball(d, "Ornament", (cf * CF.new(math.cos(a) * w * 0.5, -h / layers * 0.25, math.sin(a) * w * 0.5)).Position, 0.6 * s,
				lib.pick(rng, lib.CANDY), M.SmoothPlastic)
		end
	end
	local star = CF.new(at(pos, 3 * s + h + 0.9 * s))
	for k = 0, 4 do
		lib.block(d, "Star", star * CF.Angles(0, 0, k / 5 * math.pi * 2) * CF.new(0, 0.6 * s, 0), V3.new(0.5, 1.3, 0.4) * s, P.gold, M.SmoothPlastic,
			{ TopSurface = E.SurfaceType.Smooth })
	end
	return m
end

function props.Snowman(parent, pos, rng, s)
	local m = new("Snowman", parent)
	local d = lib.details(m)
	local yaw = yawCF(pos, rng)
	local b = lib.ball(m, "Base", at(pos, 2.6 * s), 5.6 * s, P.white, M.Snow)
	m.PrimaryPart = b
	lib.ball(m, "Middle", at(pos, 6.5 * s), 4.2 * s, P.white, M.Snow)
	local head = yaw * CF.new(0, 9.5 * s, 0)
	lib.ball(m, "Head", head.Position, 3.1 * s, P.white, M.Snow)
	lib.block(d, "Nose", head * CF.new(0, -0.1 * s, -1.9 * s) * CF.Angles(math.rad(-90), 0, 0), V3.new(0.45, 1.6, 0.45) * s, P.peach, M.SmoothPlastic)
	face(m, head * CF.new(0, 0.1 * s, -1.45 * s), 0.8 * s, rng)
	-- bonnet à pompon
	lib.cyl(m, "Hat", (head * CF.new(0, 1.6 * s, 0)).Position, 1.4 * s, 3 * s, P.pink)
	lib.cyl(m, "HatBand", (head * CF.new(0, 1.1 * s, 0)).Position, 0.6 * s, 3.2 * s, P.white)
	lib.ball(d, "Pompom", (head * CF.new(0, 2.6 * s, 0)).Position, 1.1 * s, P.white)
	-- écharpe, boutons, bras en bois
	lib.cyl(m, "Scarf", (yaw * CF.new(0, 8.2 * s, 0)).Position, 0.8 * s, 3.6 * s, P.sky)
	lib.block(d, "ScarfEnd", yaw * CF.new(1 * s, 7.2 * s, -1.6 * s) * CF.Angles(0, 0, 0.2), V3.new(0.8, 2, 0.3) * s, P.sky, M.Fabric)
	for k = 1, 3 do
		lib.ball(d, "Button", (yaw * CF.new(0, (5.2 + k * 0.8) * s, -2 * s)).Position, 0.45 * s, P.plum)
	end
	for _, x in { -1, 1 } do
		lib.block(d, "Arm", yaw * CF.new(x * 3.2 * s, 7 * s, 0) * CF.Angles(0, 0, x * -0.6), V3.new(0.3, 3.4, 0.3) * s, P.cocoa, M.Wood)
	end
	return m
end

function props.IceArch(parent, pos, rng, s)
	local m = new("IceArch", parent, true)
	local d = lib.details(m)
	local yaw = yawCF(pos, rng)
	local r = 9 * s
	for k = 0, 12 do
		local a = k / 12 * math.pi
		local b = lib.block(m, "Ice", yaw * CF.new(math.cos(a) * r, math.sin(a) * r, 0) * CF.Angles(0, 0, a), V3.new(2.6, 3.2, 3) * s,
			if k % 2 == 0 then rgb(206, 236, 255) else rgb(226, 244, 255), M.Glass, { Transparency = 0.18 })
		if k == 0 then
			m.PrimaryPart = b
		end
		lib.block(d, "Frost", yaw * CF.new(math.cos(a) * (r + 1.6 * s), math.sin(a) * (r + 1.6 * s), 0) * CF.Angles(0, 0, a),
			V3.new(0.4, 2.6, 3.2) * s, P.white, M.Snow)
		if k % 3 == 1 then
			lib.block(d, "Icicle", yaw * CF.new(math.cos(a) * (r - 1.8 * s), math.sin(a) * (r - 1.8 * s) - 0.8 * s, 0), V3.new(0.4, 1.8, 0.4) * s,
				P.white, M.Glass, { Transparency = 0.2 })
		end
	end
	for _, x in { -1, 1 } do
		lib.blob(m, "SnowPile", yaw * CF.new(x * r, 0.4 * s, 0), V3.new(5, 2, 5) * s, P.white, M.Snow)
	end
	return m
end

---------------------------------------------------------------- Ciel et arc-en-ciel
function props.Cloud(parent, pos, rng, s)
	local m = new("Cloud", parent)
	local d = lib.details(m)
	local y = (8 + rng(0, 12)) * s
	local c = lib.pick(rng, { P.white, P.cream, rgb(255, 240, 250), rgb(240, 245, 255) })
	local main = lib.blob(m, "Puff", CF.new(at(pos, y)), V3.new(10, 7, 8) * s, c)
	m.PrimaryPart = main
	for k = 1, 6 do
		local x = (k - 3.5) * 3.2 * s
		lib.blob(m, "Puff", CF.new(at(pos, y + rng(-1, 1.5) * s) + V3.new(x, 0, rng(-1.5, 1.5) * s)), V3.new(6, 5, 6) * s * rng(0.8, 1.2), c)
	end
	lib.blob(m, "Belly", CF.new(at(pos, y - 1.8 * s)), V3.new(18, 3, 7) * s, tint(c, 0.2))
	face(m, CF.new(at(pos, y)) * CF.new(0, 0, -4 * s), 1.2 * s, rng)
	local _ = d
	lib.anim(m, "Bob", { BobAmp = 1.5, BobSpeed = 0.5 + rng(0, 0.4) })
	return m
end

function props.Balloon(parent, pos, rng, s)
	local m = new("Balloon", parent)
	local d = lib.details(m)
	local c1, c2 = lib.pick(rng, lib.CANDY), lib.pick(rng, lib.CANDY)
	local y = (12 + rng(0, 8)) * s
	local env = lib.blob(m, "Envelope", CF.new(at(pos, y)), V3.new(9, 10.5, 9) * s, c1)
	m.PrimaryPart = env
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		lib.blob(m, "Gore", CF.new(at(pos, y)) * CF.Angles(0, a, 0) * CF.new(0, 0, 3.9 * s), V3.new(1.6, 10.2, 1.4) * s,
			if k % 2 == 0 then c2 else P.white)
	end
	lib.blob(m, "Bottom", CF.new(at(pos, y - 5.2 * s)), V3.new(3.4, 2, 3.4) * s, c2)
	-- cordes et nacelle tressée
	for _, o in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		lib.block(d, "Rope", CF.new(at(pos, y - 7 * s) + V3.new(o[1] * 1.1, 0, o[2] * 1.1) * s), V3.new(0.12, 3.6, 0.12) * s, P.cocoa, M.Fabric)
	end
	lib.block(m, "Basket", CF.new(at(pos, y - 9.6 * s)), V3.new(3, 2.2, 3) * s, rgb(222, 184, 140), M.Wood)
	lib.block(d, "BasketRim", CF.new(at(pos, y - 8.4 * s)), V3.new(3.3, 0.4, 3.3) * s, P.cocoa, M.Wood)
	lib.block(d, "Flag", CF.new(at(pos, y - 9.6 * s) + V3.new(1.55 * s, 0, 0)), V3.new(0.1, 1.2, 1.6) * s, c2, M.Fabric)
	lib.anim(m, "Bob", { BobAmp = 2.5, BobSpeed = 0.4 + rng(0, 0.3) })
	return m
end

function props.Star(parent, pos, rng, s)
	local m = new("Star", parent)
	local y = (10 + rng(0, 18)) * s
	local c = lib.pick(rng, { P.butter, P.pink, P.sky, P.lilac })
	local core = lib.ball(m, "Core", at(pos, y), 2.4 * s, c, M.SmoothPlastic)
	m.PrimaryPart = core
	for k = 0, 4 do
		lib.block(m, "Ray", CF.new(at(pos, y)) * CF.Angles(0, 0, k / 5 * math.pi * 2) * CF.new(0, 2 * s, 0), V3.new(1.6, 3.4, 1.2) * s, c,
			M.SmoothPlastic, { TopSurface = E.SurfaceType.Smooth })
		lib.block(m, "RayTip", CF.new(at(pos, y)) * CF.Angles(0, 0, k / 5 * math.pi * 2) * CF.new(0, 3.6 * s, 0) * CF.Angles(0, 0, math.rad(45)),
			V3.new(0.8, 0.8, 1) * s, tint(c, 0.4), M.SmoothPlastic)
	end
	face(m, CF.new(at(pos, y)) * CF.new(0, 0, -1.25 * s), 0.7 * s, rng)
	lib.light(core, c, 12, 0.6)
	lib.anim(m, "Spin,Bob", { SpinSpeed = 30, BobAmp = 1, BobSpeed = 1 })
	return m
end

function props.RainbowFall(parent, pos, rng, s)
	local m = new("RainbowFall", parent, true)
	local d = lib.details(m)
	local h = (18 + rng(0, 8)) * s
	local rock = lib.blob(m, "Cloud", CF.new(at(pos, h)), V3.new(13, 5, 10) * s, P.white)
	m.PrimaryPart = rock
	for k = 1, 4 do
		lib.blob(m, "Puff", CF.new(at(pos, h + 1.4 * s) + V3.new((k - 2.5) * 3.2 * s, 0, rng(-1, 1) * s)), V3.new(5, 4.4, 5) * s, P.white)
	end
	for k, c in lib.RAINBOW do
		lib.block(m, "Fall", CF.new(at(pos, h / 2) + V3.new((k - 3) * 1.15 * s, 0, 3 * s)), V3.new(1.15 * s, h, 0.6 * s), c, M.SmoothPlastic,
			{ Transparency = 0.1, TopSurface = E.SurfaceType.Smooth })
	end
	-- éclaboussures au pied de la cascade
	for k = 1, 10 do
		local a = k / 10 * math.pi * 2
		lib.ball(d, "Splash", at(pos, 0.6 * s) + V3.new(math.cos(a) * 3.6 * s, rng(0, 1) * s, 3 * s + math.sin(a) * 2 * s), rng(0.8, 1.6) * s,
			lib.RAINBOW[(k % 5) + 1])
	end
	lib.cyl(m, "Pool", at(pos, 0.3 * s) + V3.new(0, 0, 3 * s), 0.6 * s, 9 * s, P.sky, M.Glass, { Transparency = 0.2 })
	return m
end

---------------------------------------------------------------- Halloween (pastel « spooky-cute »)
function props.Pumpkin(parent, pos, rng, s)
	local m = new("Pumpkin", parent)
	local d = lib.details(m)
	local size = (4 + rng(0, 4)) * s
	local yaw = yawCF(pos, rng)
	local c = lib.pick(rng, { rgb(255, 186, 120), rgb(255, 200, 140), rgb(250, 176, 130) })
	local core = lib.blob(m, "Core", yaw * CF.new(0, size * 0.45, 0), V3.new(size * 0.8, size * 0.85, size * 0.8), c)
	m.PrimaryPart = core
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		lib.blob(m, "Lobe", yaw * CF.new(math.cos(a) * size * 0.27, size * 0.45, math.sin(a) * size * 0.27),
			V3.new(size * 0.55, size * 0.88, size * 0.55), if k % 2 == 0 then c else tint(c, 0.12))
	end
	lib.cyl(m, "Stem", (yaw * CF.new(0, size * 0.98, 0)).Position, size * 0.3, size * 0.16, P.sage)
	lib.blob(d, "Leaf", yaw * CF.new(size * 0.2, size * 0.95, 0) * CF.Angles(0, 0, -0.5), V3.new(size * 0.4, size * 0.08, size * 0.25), P.mint)
	-- visage mignon qui brille un peu
	local glow = P.butter
	for _, x in { -0.22, 0.22 } do
		lib.block(d, "Eye", yaw * CF.new(x * size, size * 0.55, -size * 0.43) * CF.Angles(0, 0, math.rad(45)), V3.new(0.18, 0.18, 0.1) * size,
			glow, M.SmoothPlastic)
	end
	local mouth = lib.blob(d, "Mouth", yaw * CF.new(0, size * 0.33, -size * 0.43), V3.new(0.4, 0.14, 0.1) * size, glow, M.SmoothPlastic)
	lib.light(mouth, P.butter, 9, 0.7)
	return m
end

function props.Tombstone(parent, pos, rng, s)
	local m = new("Tombstone", parent)
	local d = lib.details(m)
	local yaw = CF.new(pos) * CF.Angles(math.rad(rng(-6, 6)), rng(0, math.pi * 2), math.rad(rng(-6, 6)))
	local stone = P.lavender
	local st = lib.block(m, "Stone", yaw * CF.new(0, 2.6 * s, 0), V3.new(3.8, 5, 1) * s, stone)
	m.PrimaryPart = st
	lib.deco({ Name = "Top", Shape = E.PartType.Cylinder, Size = V3.new(1 * s, 3.8 * s, 3.8 * s),
		CFrame = yaw * CF.new(0, 5.1 * s, 0) * CF.Angles(0, math.rad(90), 0), Color = stone, Parent = m })
	lib.block(m, "Plinth", yaw * CF.new(0, 0.3 * s, 0), V3.new(4.6, 0.6, 2) * s, dark(stone, 0.15))
	lib.surfaceText(st, E.NormalId.Front, "BOO", P.plum).TextStrokeTransparency = 1
	-- mousse et petites fleurs
	for _ = 1, 4 do
		lib.ball(d, "Moss", (yaw * CF.new(rng(-1.6, 1.6) * s, rng(0.4, 1.2) * s, -0.55 * s)).Position, 0.7 * s, P.mint)
	end
	for _ = 1, 3 do
		lib.ball(d, "Flower", (yaw * CF.new(rng(-2, 2) * s, 0.7 * s, rng(-1.8, -1) * s)).Position, 0.5 * s, P.pink)
	end
	return m
end

function props.DeadTree(parent, pos, rng, s)
	local m = new("DeadTree", parent)
	local d = lib.details(m)
	local wood = rgb(150, 120, 160)
	local h = (10 + rng(0, 5)) * s
	local trunk = lib.block(m, "Trunk", CF.new(at(pos, h / 2)) * CF.Angles(0, 0, math.rad(rng(-5, 5))), V3.new(1.8 * s, h, 1.8 * s), wood, M.Wood)
	m.PrimaryPart = trunk
	for k = 1, 5 do
		local a = k / 5 * math.pi * 2 + rng(0, 1)
		local y = h * (0.4 + k * 0.1)
		local br = CF.new(at(pos, y)) * CF.Angles(0, a, math.rad(50)) * CF.new(0, 2.4 * s, 0)
		lib.block(m, "Branch", br, V3.new(0.8 * s, 4.8 * s, 0.8 * s), wood, M.Wood)
		lib.block(d, "Twig", br * CF.new(0, 2.2 * s, 0) * CF.Angles(0, 0, 0.7) * CF.new(0, 0.8 * s, 0), V3.new(0.4, 1.8, 0.4) * s, wood, M.Wood)
		-- lanterne qui pend
		if k % 2 == 0 then
			local tip = (br * CF.new(0, 2.4 * s, 0)).Position
			lib.block(d, "String", CF.new(tip - V3.new(0, 0.9 * s, 0)), V3.new(0.08, 1.8, 0.08) * s, P.ink, M.Fabric)
			local lan = lib.ball(d, "Lantern", tip - V3.new(0, 2.2 * s, 0), 1 * s, P.butter, M.SmoothPlastic)
			lib.light(lan, P.butter, 8, 0.6)
		end
	end
	lib.blob(m, "Roots", CF.new(at(pos, 0.3 * s)), V3.new(4, 1, 4) * s, wood)
	return m
end

function props.Ghost(parent, pos, rng, s)
	local m = new("Ghost", parent)
	local d = lib.details(m)
	local y = (6 + rng(0, 6)) * s
	local body = lib.blob(m, "Body", CF.new(at(pos, y)), V3.new(5, 6, 5) * s, P.white, M.SmoothPlastic, { Transparency = 0.15 })
	m.PrimaryPart = body
	-- bas ondulé
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		lib.ball(m, "Hem", at(pos, y - 2.6 * s) + V3.new(math.cos(a) * 1.9 * s, (k % 2) * -0.5 * s, math.sin(a) * 1.9 * s), 1.6 * s, P.white,
			M.SmoothPlastic, { Transparency = 0.15 })
	end
	for _, x in { -1, 1 } do
		lib.blob(m, "Arm", CF.new(at(pos, y - 0.4 * s) + V3.new(x * 2.6 * s, 0, 0)) * CF.Angles(0, 0, x * 0.6), V3.new(1, 2.2, 1) * s, P.white,
			M.SmoothPlastic, { Transparency = 0.15 })
	end
	face(m, CF.new(at(pos, y + 0.6 * s)) * CF.new(0, 0, -2.45 * s), 1 * s, rng)
	lib.cyl(d, "Bow", at(pos, y + 2.9 * s), 0.6 * s, 1.4 * s, P.pink)
	lib.anim(m, "Bob", { BobAmp = 1.5, BobSpeed = 1.2 + rng(0, 0.6) })
	return m
end

function props.Candle(parent, pos, rng, s)
	local m = new("Candle", parent)
	local d = lib.details(m)
	local count = math.floor(1 + rng(0, 2.99))
	for k = 1, count do
		local off = if k == 1 then V3.zero else V3.new(rng(-1.6, 1.6), 0, rng(-1.6, 1.6)) * s
		local h = (2 + rng(0, 3)) * s * (if k == 1 then 1.3 else 0.8)
		local wax = lib.cyl(m, "Wax", at(pos, h / 2) + off, h, 1.3 * s, lib.pick(rng, { P.cream, P.lilac, P.pink }))
		if k == 1 then
			m.PrimaryPart = wax
		end
		lib.blob(d, "Drip", CF.new(at(pos, h - 0.3 * s) + off + V3.new(0.55 * s, 0, 0)), V3.new(0.3, 0.9, 0.3) * s, P.white)
		lib.cyl(d, "Wick", at(pos, h + 0.25 * s) + off, 0.5 * s, 0.12 * s, P.ink)
		local flame = lib.blob(d, "Flame", CF.new(at(pos, h + 0.8 * s) + off), V3.new(0.6, 1.1, 0.6) * s, P.butter, M.SmoothPlastic)
		lib.light(flame, P.peach, 8, 0.8)
		lib.anim(flame, "Pulse", { PulseSpeed = 6 })
	end
	lib.cyl(m, "Saucer", at(pos, 0.15 * s), 0.3 * s, 5 * s, P.lavender)
	return m
end

---------------------------------------------------------------- Partout
function props.Tree(parent, pos, rng, s)
	local m = new("Tree", parent)
	local d = lib.details(m)
	local h = (6 + rng(0, 3)) * s
	local trunk = lib.cyl(m, "Trunk", at(pos, h / 2), h, 1.6 * s, P.cocoa)
	m.PrimaryPart = trunk
	for _, a in { 0.5, 2.6, 4.4 } do
		lib.block(d, "Root", CF.new(at(pos, 0.3 * s)) * CF.Angles(0, a, 0) * CF.new(0, 0, 1 * s), V3.new(0.6, 0.6, 1.6) * s, P.cocoa, M.Wood)
	end
	local leaf = lib.pick(rng, { P.pink, P.mint, P.butter, P.lavender, P.peach })
	lib.ball(m, "Leaves", at(pos, h + 2.6 * s), 7 * s, leaf)
	for k = 1, 4 do
		local a = k / 4 * math.pi * 2 + rng(0, 1)
		lib.ball(m, "Leaves", at(pos, h + rng(1, 3.4) * s) + V3.new(math.cos(a) * 2.6 * s, 0, math.sin(a) * 2.6 * s), rng(4, 5.4) * s,
			if k % 2 == 0 then leaf else tint(leaf, 0.2))
	end
	-- fruits ou fleurs dans le feuillage
	for _ = 1, 8 do
		local a, e = rng(0, math.pi * 2), rng(-0.3, 0.9)
		local p = at(pos, h + 2.6 * s) + V3.new(math.cos(a) * math.cos(e), math.sin(e), math.sin(a) * math.cos(e)) * 3.6 * s
		lib.ball(d, "Fruit", p, 0.7 * s, lib.pick(rng, { P.coral, P.white, P.butter }))
	end
	return m
end

function props.Flower(parent, pos, rng, s)
	local m = new("Flower", parent)
	local d = lib.details(m)
	local stem = lib.cyl(m, "Stem", at(pos, 1.4 * s), 2.8 * s, 0.3 * s, P.sage)
	m.PrimaryPart = stem
	lib.blob(d, "Leaf", CF.new(at(pos, 1 * s)) * CF.Angles(0, rng(0, 3), 0.5) * CF.new(0.5 * s, 0, 0), V3.new(1.2, 0.2, 0.6) * s, P.mint)
	local c = lib.pick(rng, lib.CANDY)
	local head = CF.new(at(pos, 2.9 * s)) * CF.Angles(math.rad(-20), rng(0, 6), 0)
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2
		lib.blob(m, "Petal", head * CF.new(math.cos(a) * 0.7 * s, 0, math.sin(a) * 0.7 * s), V3.new(0.9, 0.3, 0.9) * s, c)
	end
	lib.ball(m, "Heart", (head * CF.new(0, 0.1 * s, 0)).Position, 0.7 * s, P.butter)
	return m
end

function props.Duck(parent, pos, rng, s)
	local m = new("RubberDuck", parent)
	local d = lib.details(m)
	local yaw = yawCF(at(pos, 0.6 * s), rng)
	local c = lib.pick(rng, { P.butter, P.butter, P.pink, P.sky })
	local body = lib.blob(m, "Body", yaw, V3.new(3.2, 2.2, 4) * s, c)
	m.PrimaryPart = body
	lib.blob(m, "Tail", yaw * CF.new(0, 0.7 * s, 1.9 * s) * CF.Angles(-0.6, 0, 0), V3.new(1.2, 1, 1.2) * s, c)
	for _, x in { -1, 1 } do
		lib.blob(d, "Wing", yaw * CF.new(x * 1.5 * s, 0.3 * s, 0.3 * s), V3.new(0.5, 1.2, 2) * s, tint(c, 0.25))
	end
	local head = yaw * CF.new(0, 1.8 * s, -1.2 * s)
	lib.ball(m, "Head", head.Position, 2 * s, c)
	lib.blob(m, "Beak", head * CF.new(0, -0.25 * s, -1.05 * s), V3.new(1, 0.4, 0.9) * s, P.peach)
	face(m, head * CF.new(0, 0.2 * s, -0.85 * s), 0.55 * s, rng)
	lib.cyl(d, "Bow", (head * CF.new(0, 1 * s, 0)).Position, 0.3 * s, 0.9 * s, P.rose)
	lib.anim(m, "Bob", { BobAmp = 0.25, BobSpeed = 1.5 + rng(0, 0.8) })
	return m
end

function props.LilyPad(parent, pos, rng, s)
	local m = new("LilyPad", parent)
	local d = lib.details(m)
	local r = (2 + rng(0, 1.5)) * s
	local pad = lib.cyl(m, "Pad", at(pos, 0.1), 0.3, r * 2, P.mint)
	m.PrimaryPart = pad
	lib.block(d, "Notch", CF.new(at(pos, 0.12)) * CF.Angles(0, rng(0, 6), 0) * CF.new(0, 0, r * 0.6), V3.new(0.5, 0.32, r * 0.9), P.sky,
		M.SmoothPlastic, { TopSurface = E.SurfaceType.Smooth })
	for k = 1, 5 do
		local a = k / 5 * math.pi * 2
		lib.block(d, "Vein", CF.new(at(pos, 0.27)) * CF.Angles(0, a, 0) * CF.new(0, 0, r * 0.45), V3.new(0.12, 0.05, r * 0.85), P.sage,
			M.SmoothPlastic)
	end
	if rng() < 0.6 then
		local c = lib.pick(rng, { P.pink, P.white, P.lilac })
		for k = 1, 6 do
			local a = k / 6 * math.pi * 2
			lib.blob(m, "Petal", CF.new(at(pos, 0.8 * s)) * CF.Angles(0, a, 0) * CF.new(0, 0, 0.5 * s) * CF.Angles(0.6, 0, 0),
				V3.new(0.7, 0.3, 1.2) * s, c)
		end
		lib.ball(d, "Heart", at(pos, 0.9 * s), 0.6 * s, P.butter)
	end
	return m
end

function props.Lamp(parent, pos, rng, s)
	local m = new("Lamp", parent)
	local d = lib.details(m)
	local base = lib.cyl(m, "Base", at(pos, 0.4 * s), 0.8 * s, 1.6 * s, P.white)
	m.PrimaryPart = base
	lib.cyl(m, "Post", at(pos, 4 * s), 7.4 * s, 0.45 * s, P.white)
	for y = 2, 6, 2 do
		lib.cyl(d, "Ring", at(pos, y * s), 0.3 * s, 0.75 * s, P.lavender)
	end
	local c = lib.pick(rng, { P.pink, P.butter, P.sky, P.mint })
	local bulb = lib.ball(m, "Bulb", at(pos, 8.6 * s), 1.9 * s, c, M.SmoothPlastic)
	lib.light(bulb, c, 14, 0.7)
	lib.cyl(m, "Cap", at(pos, 9.7 * s), 0.5 * s, 2.6 * s, P.white)
	lib.ball(d, "Finial", at(pos, 10.3 * s), 0.6 * s, P.white)
	-- petit fanion accroché
	lib.block(d, "Banner", CF.new(at(pos, 6.2 * s) + V3.new(0.9 * s, 0, 0)), V3.new(1.4, 2, 0.08) * s, c, M.Fabric)
	return m
end

function props.Bench(parent, pos, rng, s, yawAngle)
	local m = new("Bench", parent)
	local d = lib.details(m)
	local yaw = CF.new(pos) * CF.Angles(0, yawAngle or rng(0, math.pi * 2), 0)
	local c = lib.pick(rng, lib.CANDY)
	local seat
	for k = -1, 1 do
		seat = lib.block(m, "Seat", yaw * CF.new(0, 1.5 * s, k * 0.62 * s), V3.new(6, 0.35, 0.55) * s, c, M.Wood)
		lib.block(m, "Back", yaw * CF.new(0, 2.5 * s + k * 0.55 * s, 0.95 * s), V3.new(6, 0.45, 0.25) * s, c, M.Wood)
	end
	m.PrimaryPart = seat
	for _, x in { -2.6, 2.6 } do
		lib.block(m, "Leg", yaw * CF.new(x * s, 0.75 * s, 0), V3.new(0.35, 1.5, 1.6) * s, P.white)
		lib.block(d, "Arm", yaw * CF.new(x * s, 2.1 * s, 0), V3.new(0.35, 0.3, 1.8) * s, P.white)
	end
	return m
end

-- Îlot sous un groupe d'objets (sur l'eau) : terre, plage, galets et touffes d'herbe
function props.Islet(parent, pos, radius, color, rng)
	local m = new("Islet", parent)
	local d = lib.details(m)
	local ground = lib.cyl(m, "Ground", V3.new(pos.X, lib.WATER + 0.6, pos.Z), 2.4, radius * 2, color)
	m.PrimaryPart = ground
	lib.cyl(m, "Top", V3.new(pos.X, lib.WATER + 1.85, pos.Z), 0.1, radius * 2 - 1, tint(color, 0.15))
	lib.cyl(m, "Shore", V3.new(pos.X, lib.WATER + 0.2, pos.Z), 1.2, radius * 2 + 3, P.cream)
	if rng then
		for k = 1, math.floor(radius * 1.2) do
			local a = k / math.floor(radius * 1.2) * math.pi * 2 + rng(0, 0.3)
			lib.blob(d, "Pebble", CF.new(pos.X + math.cos(a) * (radius + 0.8), lib.WATER + 0.7, pos.Z + math.sin(a) * (radius + 0.8)),
				V3.new(1.1, 0.6, 0.9) * rng(0.7, 1.3), lib.pick(rng, { P.white, P.lavender, P.peach }))
		end
		for _ = 1, math.floor(radius * 0.8) do
			local a, r = rng(0, math.pi * 2), rng(0.3, 0.9) * radius
			lib.blob(d, "Grass", CF.new(pos.X + math.cos(a) * r, lib.WATER + 2.1, pos.Z + math.sin(a) * r), V3.new(1, 0.7, 1), tint(color, 0.25))
		end
	end
	return m, V3.new(pos.X, lib.WATER + 1.9, pos.Z)
end

---------------------------------------------------------------- objets ajoutés en 0.7
function props.Bush(parent, pos, rng, s)
	local m = new("Bush", parent)
	local d = lib.details(m)
	local c = lib.pick(rng, { P.mint, P.sage, tint(P.sage, 0.15) })
	local main = lib.ball(m, "Leaves", at(pos, 1.6 * s), 3.6 * s, c)
	m.PrimaryPart = main
	for k = 1, 5 do
		local a = k / 5 * math.pi * 2 + rng(0, 0.6)
		lib.ball(m, "Leaves", at(pos, rng(1, 1.8) * s) + V3.new(math.cos(a) * 1.5 * s, 0, math.sin(a) * 1.5 * s), rng(2.2, 3) * s,
			if k % 2 == 0 then c else tint(c, 0.18))
	end
	local berry = lib.pick(rng, { P.coral, P.pink, P.lavender, P.butter })
	for _ = 1, 9 do
		local a, e = rng(0, math.pi * 2), rng(0, 1.1)
		lib.ball(d, "Berry", at(pos, 1.6 * s) + V3.new(math.cos(a) * math.cos(e), math.sin(e), math.sin(a) * math.cos(e)) * 2.1 * s,
			0.45 * s, berry)
	end
	return m
end

function props.FlowerBed(parent, pos, rng, s)
	local m = new("FlowerBed", parent)
	local d = lib.details(m)
	local r = 3 * s
	local soil = lib.cyl(m, "Soil", at(pos, 0.5 * s), 1 * s, r * 2, P.cocoa)
	m.PrimaryPart = soil
	lib.cyl(m, "Rim", at(pos, 0.45 * s), 0.9 * s, r * 2 + 0.6 * s, P.white)
	for k = 1, 16 do
		local a = k / 16 * math.pi * 2
		lib.ball(d, "RimPearl", at(pos, 1 * s) + V3.new(math.cos(a) * (r + 0.2 * s), 0, math.sin(a) * (r + 0.2 * s)), 0.6 * s,
			if k % 2 == 0 then P.pink else P.white)
	end
	local c1, c2 = lib.pick(rng, lib.CANDY), lib.pick(rng, lib.CANDY)
	for k = 1, 9 do
		local a, dd = rng(0, math.pi * 2), math.sqrt(rng()) * (r - 0.8 * s)
		local fp = at(pos, 1 * s) + V3.new(math.cos(a) * dd, 0, math.sin(a) * dd)
		lib.cyl(d, "Stem", fp + V3.new(0, 0.6 * s, 0), 1.2 * s, 0.15 * s, P.sage)
		local c = if k % 2 == 0 then c1 else c2
		for p = 1, 5 do
			local pa = p / 5 * math.pi * 2
			lib.ball(m, "Petal", fp + V3.new(math.cos(pa) * 0.32 * s, 1.3 * s, math.sin(pa) * 0.32 * s), 0.45 * s, c)
		end
		lib.ball(d, "Heart", fp + V3.new(0, 1.35 * s, 0), 0.35 * s, P.butter)
	end
	return m
end

function props.Rocks(parent, pos, rng, s)
	local m = new("Rocks", parent)
	local c = lib.pick(rng, { P.lavender, P.cream, P.peach, P.sky })
	local main = lib.blob(m, "Rock", CF.new(at(pos, 0.8 * s)) * CF.Angles(0, rng(0, 3), rng(-0.2, 0.2)), V3.new(3.4, 2, 2.8) * s, c)
	m.PrimaryPart = main
	for _ = 1, 4 do
		local a = rng(0, math.pi * 2)
		lib.blob(m, "Rock", CF.new(at(pos, 0.4 * s) + V3.new(math.cos(a) * 2 * s, 0, math.sin(a) * 2 * s)) * CF.Angles(rng(-0.3, 0.3), a, 0),
			V3.new(1.6, 1, 1.3) * s * rng(0.7, 1.2), tint(c, rng(0, 0.3)))
	end
	return m
end

function props.Coral(parent, pos, rng, s)
	local m = new("Coral", parent)
	local d = lib.details(m)
	local c = lib.pick(rng, { P.coral, P.pink, P.lilac, P.peach })
	local base = lib.blob(m, "Base", CF.new(at(pos, 0.3 * s)), V3.new(3, 1, 3) * s, tint(c, 0.2))
	m.PrimaryPart = base
	for k = 1, 5 do
		local a = k / 5 * math.pi * 2
		local h = rng(2, 4) * s
		local tilt = CF.new(at(pos, 0.5 * s)) * CF.Angles(0, a, 0) * CF.Angles(rng(0.2, 0.5), 0, 0)
		lib.cyl(m, "Branch", (tilt * CF.new(0, h / 2, 0)).Position, h, 0.5 * s, c)
		lib.ball(d, "Tip", (tilt * CF.new(0, h, 0)).Position, 0.8 * s, tint(c, 0.3))
	end
	return m
end

function props.Seashell(parent, pos, rng, s)
	local m = new("Seashell", parent)
	local c = lib.pick(rng, { P.peach, P.pink, P.cream })
	local yaw = yawCF(at(pos, 0.5 * s), rng)
	local main = lib.blob(m, "Shell", yaw, V3.new(3, 1.2, 2.6) * s, c)
	m.PrimaryPart = main
	for k = -3, 3 do
		lib.blob(m, "Rib", yaw * CF.new(k * 0.38 * s, 0.4 * s, 0) * CF.Angles(0, k * 0.2, 0), V3.new(0.3, 0.6, 2.4) * s, tint(c, 0.3))
	end
	lib.ball(m, "Pearl", (yaw * CF.new(0, 0.6 * s, -1.2 * s)).Position, 0.8 * s, P.white)
	return m
end

function props.Windmill(parent, pos, rng, s)
	local m = new("Windmill", parent, true)
	local d = lib.details(m)
	local c = lib.pick(rng, { P.pink, P.sky, P.butter, P.mint })
	local yaw = yawCF(pos, rng)
	local h = 14 * s
	local tower = lib.roundBox(m, "Tower", yaw * CF.new(0, h / 2, 0), V3.new(5, h, 5) * s, P.cream, M.SmoothPlastic, 1.2 * s)
	m.PrimaryPart = tower
	lib.roundBox(m, "Band", yaw * CF.new(0, h * 0.3, 0), V3.new(5.4, 0.6, 5.4) * s, c, M.SmoothPlastic, 1.3 * s)
	lib.roundBox(m, "Band", yaw * CF.new(0, h * 0.7, 0), V3.new(5.4, 0.6, 5.4) * s, c, M.SmoothPlastic, 1.3 * s)
	-- toit pointu en anneaux
	for k = 0, 4 do
		lib.cyl(m, "Roof", (yaw * CF.new(0, h + 0.5 * s + k * 0.9 * s, 0)).Position, 0.9 * s, (6.4 - k * 1.3) * s, if k % 2 == 0 then c else tint(c, 0.3))
	end
	lib.ball(d, "Tip", (yaw * CF.new(0, h + 5.2 * s, 0)).Position, 0.8 * s, P.butter)
	-- porte et fenêtres
	lib.blob(d, "Door", yaw * CF.new(0, 1.6 * s, -2.55 * s), V3.new(1.8, 3.2, 0.3) * s, P.cocoa)
	for _, y in { 0.45, 0.62 } do
		lib.blob(d, "Window", yaw * CF.new(0, h * y, -2.55 * s), V3.new(1.2, 1.2, 0.3) * s, P.sky)
	end
	-- ailes qui tournent
	local blades = new("Blades", m)
	local hubCF = yaw * CF.new(0, h * 0.82, -2.9 * s) * CF.Angles(0, math.rad(90), 0)
	local hub = lib.deco({ Name = "BladeHub", Shape = E.PartType.Cylinder, Size = V3.new(0.8 * s, 1.4 * s, 1.4 * s), CFrame = hubCF,
		Color = P.white, Material = M.SmoothPlastic, Parent = blades })
	blades.PrimaryPart = hub
	for k = 1, 4 do
		local arm = hubCF * CF.Angles(k * math.pi / 2, 0, 0)
		lib.block(blades, "Arm", arm * CF.new(0, 3.2 * s, 0), V3.new(0.3, 6.4, 0.4) * s, P.cocoa, M.Wood)
		lib.block(blades, "Sail", arm * CF.new(0.05, 3.8 * s, 0.7 * s), V3.new(0.12, 4.6, 1.4) * s, if k % 2 == 0 then P.white else c, M.Fabric,
			{ TopSurface = E.SurfaceType.Smooth })
	end
	lib.anim(blades, "Spin", { SpinSpeed = 35, SpinAxis = "X" })
	return m
end

function props.CandyCart(parent, pos, rng, s, yawAngle)
	local m = new("CandyCart", parent)
	local d = lib.details(m)
	local yaw = CF.new(pos) * CF.Angles(0, yawAngle or rng(0, math.pi * 2), 0)
	local c = lib.pick(rng, { P.pink, P.sky, P.mint, P.lavender })
	local body = lib.roundBox(m, "Cart", yaw * CF.new(0, 2.4 * s, 0), V3.new(6, 2.6, 3.4) * s, c, M.SmoothPlastic, 0.8 * s)
	m.PrimaryPart = body
	lib.roundBox(m, "Counter", yaw * CF.new(0, 3.85 * s, 0), V3.new(6.4, 0.3, 3.8) * s, P.white, M.SmoothPlastic, 0.9 * s)
	for _, x in { -2.4, 2.4 } do
		lib.cyl(m, "Wheel", (yaw * CF.new(x * s, 1 * s, -1.8 * s)).Position, 0.4 * s, 2 * s, P.white, M.SmoothPlastic,
			{ CFrame = yaw * CF.new(x * s, 1 * s, -1.8 * s) * CF.Angles(0, math.rad(90), 0) })
		lib.cyl(m, "Wheel", (yaw * CF.new(x * s, 1 * s, 1.8 * s)).Position, 0.4 * s, 2 * s, P.white, M.SmoothPlastic,
			{ CFrame = yaw * CF.new(x * s, 1 * s, 1.8 * s) * CF.Angles(0, math.rad(90), 0) })
		lib.cyl(m, "Pole", (yaw * CF.new(x * s, 5.8 * s, 0)).Position, 4 * s, 0.3 * s, P.white)
	end
	-- auvent rayé
	for k = -3, 3 do
		lib.block(m, "Awning", yaw * CF.new(k * 0.95 * s, 8 * s, 0) * CF.Angles(0, 0, 0), V3.new(0.95, 0.4, 4.6) * s,
			if k % 2 == 0 then P.white else c, M.SmoothPlastic, { TopSurface = E.SurfaceType.Smooth })
		lib.blob(d, "Scallop", yaw * CF.new(k * 0.95 * s, 7.6 * s, -2.3 * s), V3.new(0.95, 0.8, 0.3) * s, if k % 2 == 0 then P.white else c)
	end
	-- bocaux de bonbons
	for k = -2, 2 do
		local jp = yaw * CF.new(k * 1.1 * s, 4.6 * s, 0.4 * s)
		lib.cyl(d, "Jar", jp.Position, 1.2 * s, 0.9 * s, P.white, M.Glass, { Transparency = 0.4 })
		lib.ball(d, "Candy", jp.Position, 0.6 * s, lib.CANDY[k + 3])
		lib.cyl(d, "Lid", (jp * CF.new(0, 0.7 * s, 0)).Position, 0.2 * s, 1 * s, lib.CANDY[k + 4])
	end
	-- sucette géante en enseigne
	lib.cyl(d, "SignStick", (yaw * CF.new(3.6 * s, 9.5 * s, 0)).Position, 3 * s, 0.25 * s, P.white)
	lib.ball(m, "SignCandy", (yaw * CF.new(3.6 * s, 11.4 * s, 0)).Position, 2 * s, P.pink)
	return m
end

function props.Kite(parent, pos, rng, s)
	local m = new("Kite", parent)
	local c = lib.pick(rng, lib.CANDY)
	local y = (18 + rng(0, 10)) * s
	local kcf = CF.new(at(pos, y)) * CF.Angles(0, rng(0, 6), math.rad(45))
	local body = lib.block(m, "Kite", kcf, V3.new(3, 3, 0.15) * s, c, M.Fabric, { TopSurface = E.SurfaceType.Smooth })
	m.PrimaryPart = body
	lib.block(m, "Cross", kcf * CF.new(0, 0, -0.1 * s), V3.new(3, 0.2, 0.1) * s, P.white, M.SmoothPlastic)
	for k = 1, 5 do
		lib.blob(m, "Bow", CF.new(at(pos, y - 2.2 * s - k * 1.1 * s)), V3.new(0.9, 0.4, 0.2) * s, lib.CANDY[(k % #lib.CANDY) + 1])
	end
	lib.anim(m, "Bob,Drift", { BobAmp = 1.5, BobSpeed = 0.9, DriftAmp = 3, DriftSpeed = 0.3 })
	return m
end

---------------------------------------------------------------- animations du décor
-- Chaque objet reçoit ici ses animations (en plus de celles posées dans sa fonction).
-- Elles ne sont jouées que près du joueur (src/Client/Animator.luau).
local ANIMS = {
	Lollipop = { "Sway", { SwayAmp = 3, SwaySpeed = 0.9 } },
	CandyCane = { "Sway", { SwayAmp = 2, SwaySpeed = 0.8 } },
	IceCream = { "Sway", { SwayAmp = 3, SwaySpeed = 1.3 } },
	Cupcake = { "Wobble", { WobbleSpeed = 1.6 } },
	Gumdrop = { "Wobble", { WobbleSpeed = 2.2 } },
	GummyBear = { "Sway", { SwayAmp = 5, SwaySpeed = 1.6 } },
	JellyStack = { "Wobble", { WobbleSpeed = 1.8 } },
	Mushroom = { "Sway", { SwayAmp = 3, SwaySpeed = 1.1 } },
	Tree = { "Sway", { SwayAmp = 2, SwaySpeed = 0.7 } },
	Pine = { "Sway", { SwayAmp = 1.5, SwaySpeed = 0.6 } },
	DeadTree = { "Sway", { SwayAmp = 2, SwaySpeed = 0.5 } },
	Flower = { "Sway", { SwayAmp = 8, SwaySpeed = 1.5 } },
	Snowman = { "Sway", { SwayAmp = 2.5, SwaySpeed = 1.2 } },
	Pumpkin = { "Wobble", { WobbleSpeed = 1.2 } },
	Boat = { "Sway", { SwayAmp = 4, SwaySpeed = 0.9 } },
	Buoy = { "Sway", { SwayAmp = 7, SwaySpeed = 1.4 } },
	Duck = { "Swim", { SwimRadius = 2.5, SwimSpeed = 0.35 } },
	Cloud = { "Drift", { DriftAmp = 6, DriftSpeed = 0.12 } },
	Ghost = { "Drift,Sway", { DriftAmp = 3, DriftSpeed = 0.3, SwayAmp = 6, SwaySpeed = 1.2 } },
	Lamp = { "Blink", { BlinkSpeed = 1.5 } },
	NeonTower = { "Blink", { BlinkSpeed = 2 } },
	NeonSign = { "Blink", { BlinkSpeed = 3 } },
	Candle = { "Blink", { BlinkSpeed = 7 } },
	Crane = { "Spin", { SpinSpeed = 3 } },
	LilyPad = { "Bob", { BobAmp = 0.12, BobSpeed = 1.2 } },
	Macaron = { "Bob", { BobAmp = 0.3, BobSpeed = 1.4 } },
	Donut = { "Bob", { BobAmp = 0.3, BobSpeed = 1.2 } },
	Bush = { "Sway", { SwayAmp = 2, SwaySpeed = 1.1 } },
	FlowerBed = { "Sway", { SwayAmp = 1.5, SwaySpeed = 1.6 } },
	Coral = { "Sway", { SwayAmp = 4, SwaySpeed = 0.8 } },
}

-- Papillon : vole en rond au-dessus d'un objet (fleurs, arbres, sucettes)
local function butterfly(parent, pos, rng, s)
	local m = new("Butterfly", parent)
	local c = lib.pick(rng, lib.CANDY)
	local y = (4 + rng(0, 4)) * s
	local body = lib.blob(m, "Body", CF.new(at(pos, y)), V3.new(0.25, 0.25, 0.9) * s, P.plum)
	m.PrimaryPart = body
	for _, x in { -1, 1 } do
		lib.blob(m, "Wing", CF.new(at(pos, y + 0.1 * s)) * CF.new(x * 0.5 * s, 0, -0.15 * s) * CF.Angles(0, 0, x * 0.5),
			V3.new(0.9, 0.08, 0.8) * s, c)
		lib.blob(m, "Wing", CF.new(at(pos, y)) * CF.new(x * 0.4 * s, 0, 0.3 * s) * CF.Angles(0, 0, x * 0.4), V3.new(0.6, 0.08, 0.55) * s, tint(c, 0.3))
	end
	lib.anim(m, "Swim,Bob", { SwimRadius = 3 + rng(0, 3), SwimSpeed = 0.6 + rng(0, 0.6), BobAmp = 0.8, BobSpeed = 2 + rng(0, 1.5) })
	return m
end

local BUTTERFLY_ON = { Flower = 0.35, Tree = 0.3, Lollipop = 0.2, Mushroom = 0.25, Gumdrop = 0.15, FlowerBed = 0.5, Bush = 0.25 }

for name, fn in props do
	local a = ANIMS[name]
	local bf = BUTTERFLY_ON[name]
	if type(fn) == "function" and name ~= "Islet" and (a or bf) then
		props[name] = function(parent, pos, rng, s, ...)
			local m = fn(parent, pos, rng, s, ...)
			if a and m then
				local old = m:GetAttribute("Anim")
				local kinds = if type(old) == "string" then old .. "," .. a[1] else a[1]
				lib.anim(m, kinds, a[2])
			end
			if bf and rng() < bf then
				butterfly(parent, pos, rng, s or 1)
			end
			return m
		end
	end
end

return props
