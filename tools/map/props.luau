-- Popaint (générateur de map) : bibliothèque d'objets de décor.
-- Chaque fonction construit un objet posé au point "pos" (Vector3, le sol sous l'objet) et
-- renvoie son modèle. "s" = échelle, "rng" = hasard déterministe.
-- AJOUTER UN OBJET : écris une fonction ici, puis ajoute son nom dans un thème (themes.luau).
local lib = require("./lib")

local V3, CF, E = lib.Vector3, lib.CFrame, lib.Enum
local rgb = lib.rgb
local M = E.Material

local props = {}

local function at(pos, y)
	return V3.new(pos.X, pos.Y + y, pos.Z)
end

local function new(name, parent, big)
	return lib.model(name, parent, "Atomic", big)
end

---------------------------------------------------------------- Bonbons
function props.Lollipop(parent, pos, rng, s)
	local m = new("Lollipop", parent)
	local h = (14 + rng(0, 10)) * s
	lib.cyl(m, "Stick", at(pos, h / 2), h, 1.4 * s, rgb(255, 255, 255))
	-- disque vertical (l'axe d'un cylindre Roblox est X)
	lib.deco({ Name = "Candy", Shape = E.PartType.Cylinder, Size = V3.new(2.2 * s, 10 * s, 10 * s),
		CFrame = CF.new(at(pos, h + 4 * s)) * CF.Angles(0, rng(0, math.pi * 2), 0), Color = lib.pick(rng, lib.CANDY),
		Material = M.SmoothPlastic, Parent = m })
	lib.ball(m, "Swirl", at(pos, h + 4 * s), 4 * s, rgb(255, 255, 255))
	lib.anim(m, "Bob", { BobAmp = 0.5, BobSpeed = 1 + rng(0, 1) })
	return m
end

function props.CandyCane(parent, pos, rng, s)
	local m = new("CandyCane", parent)
	local seg = 2.2 * s
	local n = math.floor(6 + rng(0, 4))
	for k = 1, n do
		lib.cyl(m, "Seg", at(pos, (k - 0.5) * seg), seg, 1.8 * s, if k % 2 == 0 then rgb(255, 60, 90) else rgb(255, 255, 255))
	end
	-- crosse
	local top = at(pos, n * seg)
	local yaw = rng(0, math.pi * 2)
	for k = 1, 6 do
		local a = k / 6 * math.pi
		local off = V3.new(math.cos(yaw) * (1 - math.cos(a)) * 2.2 * s, math.sin(a) * 2.2 * s, math.sin(yaw) * (1 - math.cos(a)) * 2.2 * s)
		lib.ball(m, "Hook", top + off, 1.9 * s, if k % 2 == 0 then rgb(255, 60, 90) else rgb(255, 255, 255))
	end
	return m
end

function props.Gumdrop(parent, pos, rng, s)
	local m = new("Gumdrop", parent)
	local size = (5 + rng(0, 4)) * s
	lib.blob(m, "Drop", CF.new(at(pos, size * 0.35)), V3.new(size, size * 1.1, size), lib.pick(rng, lib.CANDY), M.Glass,
		{ Transparency = 0.15 })
	for k = 1, 5 do
		local a = k / 5 * math.pi * 2
		lib.ball(m, "Sugar", at(pos, size * 0.6) + V3.new(math.cos(a) * size * 0.3, rng(0, size * 0.2), math.sin(a) * size * 0.3),
			0.7 * s, rgb(255, 255, 255))
	end
	return m
end

function props.Donut(parent, pos, rng, s)
	local m = new("Donut", parent)
	local r = 4 * s
	local dough = rgb(240, 190, 120)
	local icing = lib.pick(rng, { rgb(255, 130, 200), rgb(140, 90, 60), rgb(255, 255, 255), rgb(130, 220, 255) })
	local tilt = CF.Angles(math.rad(rng(-25, 25)), math.rad(rng(0, 360)), 0)
	local center = CF.new(at(pos, 3.5 * s)) * tilt
	for k = 1, 14 do
		local a = k / 14 * math.pi * 2
		local p = (center * CF.new(math.cos(a) * r, 0, math.sin(a) * r)).Position
		lib.ball(m, "Dough", p, 3.4 * s, dough)
		lib.ball(m, "Icing", p + V3.new(0, 0.9 * s, 0), 3 * s, icing)
		if k % 3 == 0 then
			lib.block(m, "Sprinkle", CF.new(p + V3.new(0, 2.3 * s, 0)) * CF.Angles(0, a, 0), V3.new(0.3, 0.3, 1) * s,
				lib.pick(rng, lib.CANDY), M.Neon, { TopSurface = E.SurfaceType.Smooth })
		end
	end
	return m
end

function props.Cupcake(parent, pos, rng, s)
	local m = new("Cupcake", parent)
	local wrapper = lib.pick(rng, { rgb(255, 150, 200), rgb(150, 210, 255), rgb(255, 230, 130) })
	for k = 1, 3 do
		lib.cyl(m, "Cup", at(pos, (k - 0.5) * 1.6 * s), 1.6 * s, (6 + k * 0.5) * s, wrapper)
	end
	for k = 1, 3 do
		lib.ball(m, "Cream", at(pos, 4.8 * s + k * 1.4 * s), (8 - k * 1.8) * s, rgb(255, 245, 250))
	end
	lib.ball(m, "Cherry", at(pos, 10.5 * s), 1.8 * s, rgb(255, 40, 70), M.SmoothPlastic)
	return m
end

function props.IceCream(parent, pos, rng, s)
	local m = new("IceCream", parent)
	for k = 1, 6 do
		lib.cyl(m, "Cone", at(pos, (k - 0.5) * 1.3 * s), 1.3 * s, (0.8 + k * 0.85) * s, rgb(230, 170, 90))
	end
	local y = 8 * s
	for k = 1, math.floor(2 + rng(0, 2)) do
		lib.ball(m, "Scoop", at(pos, y + 2.4 * s), 6 * s, lib.pick(rng, { rgb(255, 180, 210), rgb(255, 255, 230), rgb(150, 230, 180), rgb(140, 90, 60) }))
		y += 4 * s
	end
	return m
end

function props.Macaron(parent, pos, rng, s)
	local m = new("Macaron", parent)
	local c = lib.pick(rng, lib.CANDY)
	lib.blob(m, "Bottom", CF.new(at(pos, 1 * s)), V3.new(7, 2.4, 7) * s, c)
	lib.cyl(m, "Cream", at(pos, 2.4 * s), 1 * s, 6.4 * s, rgb(255, 250, 240))
	lib.blob(m, "Top", CF.new(at(pos, 3.8 * s)), V3.new(7, 2.4, 7) * s, c)
	return m
end

---------------------------------------------------------------- Néon / port
function props.NeonTower(parent, pos, rng, s)
	local m = new("NeonTower", parent, true)
	local w, d = (8 + rng(0, 6)) * s, (8 + rng(0, 6)) * s
	local h = (24 + rng(0, 34)) * s
	local body = lib.block(m, "Body", CF.new(at(pos, h / 2)), V3.new(w, h, d), lib.pick(rng, { rgb(35, 30, 75), rgb(50, 35, 95), rgb(25, 25, 60) }))
	m.PrimaryPart = body
	local glow = lib.pick(rng, { rgb(82, 215, 255), rgb(255, 92, 200), rgb(255, 230, 90), rgb(120, 255, 200) })
	local floors = math.floor(h / (4 * s))
	for k = 1, floors do
		if k % 2 == 0 or rng() < 0.3 then
			lib.block(m, "Window", CF.new(at(pos, k * 4 * s - 1 * s)), V3.new(w + 0.2, 0.6 * s, d + 0.2), glow, M.Neon,
				{ TopSurface = E.SurfaceType.Smooth })
		end
	end
	lib.block(m, "Roof", CF.new(at(pos, h + 0.5 * s)), V3.new(w * 0.6, 1 * s, d * 0.6), glow, M.Neon)
	if rng() < 0.5 then
		local ant = lib.cyl(m, "Antenna", at(pos, h + 4 * s), 7 * s, 0.4 * s, rgb(200, 200, 220))
		local tip = lib.ball(m, "Blink", at(pos, h + 7.8 * s), 1.4 * s, rgb(255, 60, 80), M.Neon)
		lib.anim(tip, "Pulse", { PulseSpeed = 4 })
		local _ = ant
	end
	return m
end

function props.Boat(parent, pos, rng, s)
	local m = new("Boat", parent)
	local hull = lib.pick(rng, { rgb(255, 92, 168), rgb(82, 215, 255), rgb(255, 214, 64), rgb(255, 255, 255) })
	local yaw = CF.Angles(0, rng(0, math.pi * 2), 0)
	local base = CF.new(at(pos, 0.6 * s)) * yaw
	lib.block(m, "Hull", base, V3.new(5, 2, 12) * s, hull, M.SmoothPlastic, { TopSurface = E.SurfaceType.Smooth })
	lib.block(m, "Bow", base * CF.new(0, 0, -7 * s) * CF.Angles(0, math.rad(45), 0), V3.new(3.5, 2, 3.5) * s, hull, M.SmoothPlastic)
	lib.block(m, "Cabin", base * CF.new(0, 2.2 * s, 1.5 * s), V3.new(4, 2.6, 4) * s, rgb(255, 255, 255))
	lib.block(m, "Light", base * CF.new(0, 3.8 * s, 1.5 * s), V3.new(4.2, 0.4, 4.2) * s, rgb(82, 215, 255), M.Neon)
	local mast = lib.cyl(m, "Mast", (base * CF.new(0, 6 * s, -2 * s)).Position, 8 * s, 0.5 * s, rgb(240, 240, 255))
	local _ = mast
	lib.anim(m, "Bob", { BobAmp = 0.35, BobSpeed = 1.3 })
	return m
end

function props.Buoy(parent, pos, rng, s)
	local m = new("Buoy", parent)
	lib.ball(m, "Float", at(pos, 0.5 * s), 3 * s, lib.pick(rng, { rgb(255, 80, 80), rgb(255, 214, 64) }))
	lib.cyl(m, "Pole", at(pos, 2.5 * s), 3 * s, 0.5 * s, rgb(255, 255, 255))
	local lamp = lib.ball(m, "Lamp", at(pos, 4.3 * s), 1.2 * s, rgb(82, 215, 255), M.Neon)
	lib.light(lamp, rgb(82, 215, 255), 10, 1)
	lib.anim(m, "Bob", { BobAmp = 0.4, BobSpeed = 1.8 })
	return m
end

function props.Crane(parent, pos, rng, s)
	local m = new("Crane", parent, true)
	local c = rgb(255, 200, 40)
	local h = (26 + rng(0, 8)) * s
	for _, o in { { -1.5, -1.5 }, { 1.5, -1.5 }, { -1.5, 1.5 }, { 1.5, 1.5 } } do
		lib.block(m, "Leg", CF.new(at(pos, h / 2) + V3.new(o[1], 0, o[2]) * s), V3.new(0.6 * s, h, 0.6 * s), c)
	end
	local yaw = CF.Angles(0, rng(0, math.pi * 2), 0)
	local top = CF.new(at(pos, h)) * yaw
	lib.block(m, "Arm", top * CF.new(0, 0, -6 * s), V3.new(1.2, 1.2, 22) * s, c)
	lib.block(m, "Cabin", top * CF.new(0, 1.8 * s, 0), V3.new(3, 2.4, 3) * s, rgb(40, 40, 80))
	lib.block(m, "Cable", top * CF.new(0, -5 * s, -14 * s), V3.new(0.2, 10, 0.2) * s, rgb(30, 30, 30), M.SmoothPlastic)
	lib.block(m, "Crate", top * CF.new(0, -11 * s, -14 * s), V3.new(4, 3, 4) * s, lib.pick(rng, lib.CANDY))
	return m
end

function props.NeonSign(parent, pos, rng, s)
	local m = new("NeonSign", parent)
	lib.cyl(m, "Post", at(pos, 5 * s), 10 * s, 0.6 * s, rgb(40, 40, 70))
	local panel = lib.block(m, "Panel", CF.new(at(pos, 12 * s)) * CF.Angles(0, rng(0, math.pi * 2), 0), V3.new(9, 4, 0.6) * s,
		rgb(30, 25, 60))
	local glow = lib.pick(rng, { rgb(82, 215, 255), rgb(255, 92, 200), rgb(255, 230, 90) })
	local word = lib.pick(rng, { "POP!", "SPLASH", "WOW", "BUBBLES", "NEON", "OPEN", "★" })
	for _, f in { E.NormalId.Front, E.NormalId.Back } do
		lib.surfaceText(panel, f, word, glow)
	end
	lib.light(panel, glow, 14, 1.2)
	return m
end

---------------------------------------------------------------- Gelée
function props.JellyCube(parent, pos, rng, s)
	local m = new("JellyCube", parent)
	local size = (6 + rng(0, 8)) * s
	local cube = lib.block(m, "Jelly", CF.new(at(pos, size / 2)) * CF.Angles(0, rng(0, math.pi), 0), V3.new(size, size, size),
		lib.pick(rng, lib.CANDY), M.Glass, { Transparency = 0.35, TopSurface = E.SurfaceType.Smooth })
	lib.ball(m, "Core", at(pos, size / 2), size * 0.3, rgb(255, 255, 255), M.Neon, { Transparency = 0.4 })
	lib.anim(cube, "Wobble", { WobbleSpeed = 2 + rng(0, 1.5) })
	return m
end

function props.GummyBear(parent, pos, rng, s)
	local m = new("GummyBear", parent)
	local c = lib.pick(rng, lib.CANDY)
	local g = { Transparency = 0.2 }
	local yaw = CF.new(pos) * CF.Angles(0, rng(0, math.pi * 2), 0)
	lib.blob(m, "Body", yaw * CF.new(0, 3.2 * s, 0), V3.new(4.4, 5.4, 3.6) * s, c, M.Glass, g)
	lib.ball(m, "Head", (yaw * CF.new(0, 7 * s, 0)).Position, 3.6 * s, c, M.Glass, g)
	for _, x in { -1, 1 } do
		lib.ball(m, "Ear", (yaw * CF.new(x * 1.3 * s, 8.7 * s, 0)).Position, 1.4 * s, c, M.Glass, g)
		lib.ball(m, "Arm", (yaw * CF.new(x * 2.4 * s, 4 * s, -0.4 * s)).Position, 1.8 * s, c, M.Glass, g)
		lib.ball(m, "Leg", (yaw * CF.new(x * 1.3 * s, 0.9 * s, -0.4 * s)).Position, 2 * s, c, M.Glass, g)
		lib.ball(m, "Eye", (yaw * CF.new(x * 0.7 * s, 7.3 * s, -1.6 * s)).Position, 0.6 * s, rgb(40, 20, 50))
	end
	return m
end

function props.Mushroom(parent, pos, rng, s)
	local m = new("Mushroom", parent)
	local h = (5 + rng(0, 5)) * s
	lib.cyl(m, "Stem", at(pos, h / 2), h, 2.4 * s, rgb(255, 245, 230))
	local cap = lib.pick(rng, { rgb(255, 80, 120), rgb(186, 120, 255), rgb(82, 215, 255), rgb(255, 160, 60) })
	lib.blob(m, "Cap", CF.new(at(pos, h + 0.6 * s)), V3.new(8, 4, 8) * s, cap)
	for k = 1, 5 do
		local a = k / 5 * math.pi * 2 + rng(0, 1)
		lib.ball(m, "Dot", at(pos, h + 1.8 * s) + V3.new(math.cos(a) * 2.4 * s, 0, math.sin(a) * 2.4 * s), 1 * s, rgb(255, 255, 255))
	end
	return m
end

function props.JellyStack(parent, pos, rng, s)
	local m = new("JellyStack", parent, true)
	local y, size = 0, (14 + rng(0, 6)) * s
	for k = 1, 4 do
		local h = size * 0.5
		lib.block(m, "Layer", CF.new(at(pos, y + h / 2)) * CF.Angles(0, k * 0.4, 0), V3.new(size, h, size), lib.CANDY[(k % 5) + 1], M.Glass,
			{ Transparency = 0.3, TopSurface = E.SurfaceType.Smooth })
		y += h
		size *= 0.72
	end
	lib.ball(m, "Cherry", at(pos, y + 1.5 * s), 3 * s, rgb(255, 40, 70))
	return m
end

---------------------------------------------------------------- Cristal / neige
function props.CrystalCluster(parent, pos, rng, s)
	local m = new("CrystalCluster", parent)
	local c = lib.pick(rng, { rgb(120, 230, 255), rgb(200, 170, 255), rgb(255, 180, 240), rgb(220, 250, 255) })
	for k = 1, math.floor(3 + rng(0, 4)) do
		local h = (5 + rng(0, 10)) * s
		local a = rng(0, math.pi * 2)
		local lean = rng(5, 30)
		lib.block(m, "Crystal", CF.new(pos + V3.new(math.cos(a) * 1.5 * s, h / 2, math.sin(a) * 1.5 * s))
			* CF.Angles(math.rad(math.cos(a) * lean), a, math.rad(math.sin(a) * lean)), V3.new(1.8 * s, h, 1.8 * s), c, M.Neon,
			{ Transparency = 0.15, TopSurface = E.SurfaceType.Smooth })
	end
	lib.anim(m, "Pulse", { PulseSpeed = 1 + rng(0, 1.5) })
	return m
end

function props.Pine(parent, pos, rng, s)
	local m = new("Pine", parent)
	local h = (10 + rng(0, 8)) * s
	lib.cyl(m, "Trunk", at(pos, 1.5 * s), 3 * s, 1.6 * s, rgb(120, 80, 60))
	local layers = 4
	for k = 1, layers do
		local w = (8 - k * 1.5) * s
		local y = 3 * s + (k - 1) * (h / layers)
		lib.block(m, "Leaves", CF.new(at(pos, y + h / layers / 2)) * CF.Angles(0, math.rad(k * 22), 0), V3.new(w, h / layers, w),
			rgb(60, 170, 120))
		lib.block(m, "Snow", CF.new(at(pos, y + h / layers)) * CF.Angles(0, math.rad(k * 22), 0), V3.new(w * 0.8, 0.5 * s, w * 0.8),
			rgb(255, 255, 255), M.Snow)
	end
	return m
end

function props.Snowman(parent, pos, rng, s)
	local m = new("Snowman", parent)
	local yaw = CF.new(pos) * CF.Angles(0, rng(0, math.pi * 2), 0)
	lib.ball(m, "Base", at(pos, 2.6 * s), 5.6 * s, rgb(255, 255, 255), M.Snow)
	lib.ball(m, "Middle", at(pos, 6.6 * s), 4.2 * s, rgb(255, 255, 255), M.Snow)
	lib.ball(m, "Head", at(pos, 9.6 * s), 3 * s, rgb(255, 255, 255), M.Snow)
	lib.block(m, "Nose", yaw * CF.new(0, 9.6 * s, -1.8 * s), V3.new(0.5, 0.5, 1.6) * s, rgb(255, 140, 40), M.SmoothPlastic)
	for _, x in { -0.6, 0.6 } do
		lib.ball(m, "Eye", (yaw * CF.new(x * s, 10.1 * s, -1.3 * s)).Position, 0.5 * s, rgb(30, 30, 40))
	end
	lib.cyl(m, "Hat", (yaw * CF.new(0, 11.8 * s, 0)).Position, 2 * s, 2.4 * s, rgb(255, 92, 168))
	lib.block(m, "Scarf", yaw * CF.new(0, 8.3 * s, 0), V3.new(3.4, 0.7, 3.4) * s, rgb(82, 215, 255))
	return m
end

function props.IceArch(parent, pos, rng, s)
	local m = new("IceArch", parent, true)
	local yaw = CF.new(pos) * CF.Angles(0, rng(0, math.pi), 0)
	local r = 9 * s
	for k = 0, 10 do
		local a = k / 10 * math.pi
		lib.block(m, "Ice", yaw * CF.new(math.cos(a) * r, math.sin(a) * r, 0) * CF.Angles(0, 0, a), V3.new(2.6, 3.6, 3) * s,
			rgb(190, 235, 255), M.Glass, { Transparency = 0.25 })
	end
	return m
end

---------------------------------------------------------------- Arc-en-ciel / ciel
function props.Cloud(parent, pos, rng, s)
	local m = new("Cloud", parent)
	local y = (8 + rng(0, 14)) * s
	for k = 1, 5 do
		lib.ball(m, "Puff", at(pos, y) + V3.new((k - 3) * 4 * s, rng(-1, 1.5) * s, rng(-2, 2) * s), (6 + rng(0, 4)) * s,
			rgb(255, 255, 255))
	end
	lib.anim(m, "Bob", { BobAmp = 1.5, BobSpeed = 0.5 + rng(0, 0.4) })
	return m
end

function props.Balloon(parent, pos, rng, s)
	local m = new("Balloon", parent)
	local c = lib.pick(rng, lib.RAINBOW)
	local y = (12 + rng(0, 10)) * s
	lib.blob(m, "Envelope", CF.new(at(pos, y)), V3.new(9, 11, 9) * s, c)
	for k = 1, 4 do
		local a = k / 4 * math.pi * 2
		lib.blob(m, "Stripe", CF.new(at(pos, y) + V3.new(math.cos(a) * 3.3 * s, 0, math.sin(a) * 3.3 * s)),
			V3.new(2.6, 10.6, 2.6) * s, rgb(255, 255, 255))
	end
	lib.block(m, "Basket", CF.new(at(pos, y - 8 * s)), V3.new(3, 2.4, 3) * s, rgb(190, 130, 80))
	lib.anim(m, "Bob", { BobAmp = 2.5, BobSpeed = 0.4 + rng(0, 0.3) })
	return m
end

function props.Star(parent, pos, rng, s)
	local m = new("Star", parent)
	local y = (10 + rng(0, 20)) * s
	local c = lib.pick(rng, { rgb(255, 230, 90), rgb(255, 255, 255), rgb(255, 170, 230) })
	for k = 0, 4 do
		lib.block(m, "Ray", CF.new(at(pos, y)) * CF.Angles(0, 0, k / 5 * math.pi * 2) * CF.new(0, 1.6 * s, 0), V3.new(1.4, 3.4, 1) * s, c,
			M.Neon, { TopSurface = E.SurfaceType.Smooth })
	end
	lib.ball(m, "Core", at(pos, y), 2 * s, c, M.Neon)
	lib.anim(m, "Spin,Bob", { SpinSpeed = 40, BobAmp = 1, BobSpeed = 1 })
	return m
end

function props.RainbowFall(parent, pos, rng, s)
	local m = new("RainbowFall", parent, true)
	local h = (18 + rng(0, 10)) * s
	lib.blob(m, "Rock", CF.new(at(pos, h)), V3.new(12, 5, 10) * s, rgb(255, 245, 255))
	for k, c in lib.RAINBOW do
		lib.block(m, "Fall", CF.new(at(pos, h / 2) + V3.new((k - 3) * 1.1 * s, 0, 3 * s)), V3.new(1.1 * s, h, 0.6 * s), c, M.Neon,
			{ Transparency = 0.2, TopSurface = E.SurfaceType.Smooth })
	end
	lib.cyl(m, "Splash", at(pos, 0.5 * s) + V3.new(0, 0, 3 * s), 1 * s, 8 * s, rgb(255, 255, 255), M.Neon, { Transparency = 0.4 })
	return m
end

---------------------------------------------------------------- Halloween
function props.Pumpkin(parent, pos, rng, s)
	local m = new("Pumpkin", parent)
	local size = (4 + rng(0, 4)) * s
	local yaw = CF.new(pos) * CF.Angles(0, rng(0, math.pi * 2), 0)
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2
		lib.blob(m, "Lobe", yaw * CF.new(math.cos(a) * size * 0.25, size * 0.45, math.sin(a) * size * 0.25),
			V3.new(size * 0.7, size * 0.9, size * 0.7), rgb(255, 130, 30))
	end
	lib.cyl(m, "Stem", (yaw * CF.new(0, size * 0.95, 0)).Position, size * 0.3, size * 0.15, rgb(90, 140, 60))
	if rng() < 0.6 then
		local glow = rgb(255, 230, 90)
		for _, x in { -0.22, 0.22 } do
			lib.block(m, "Eye", yaw * CF.new(x * size, size * 0.55, -size * 0.55) * CF.Angles(0, 0, math.rad(45)), V3.new(0.25, 0.25, 0.1) * size,
				glow, M.Neon)
		end
		lib.block(m, "Mouth", yaw * CF.new(0, size * 0.32, -size * 0.55), V3.new(0.5, 0.12, 0.1) * size, glow, M.Neon)
		lib.light(m:FindFirstChild("Mouth"), rgb(255, 160, 60), 10, 1.5)
	end
	return m
end

function props.Tombstone(parent, pos, rng, s)
	local m = new("Tombstone", parent)
	local yaw = CF.new(pos) * CF.Angles(math.rad(rng(-8, 8)), rng(0, math.pi * 2), math.rad(rng(-8, 8)))
	lib.block(m, "Stone", yaw * CF.new(0, 2.5 * s, 0), V3.new(3.6, 5, 1) * s, rgb(150, 140, 170))
	lib.deco({ Name = "Top", Shape = E.PartType.Cylinder, Size = V3.new(1 * s, 3.6 * s, 3.6 * s),
		CFrame = yaw * CF.new(0, 5 * s, 0) * CF.Angles(0, math.rad(90), 0), Color = rgb(150, 140, 170), Parent = m })
	lib.surfaceText(m:FindFirstChild("Stone"), E.NormalId.Front, "RIP", rgb(80, 70, 100))
	return m
end

function props.DeadTree(parent, pos, rng, s)
	local m = new("DeadTree", parent)
	local wood = rgb(70, 50, 70)
	local h = (10 + rng(0, 6)) * s
	lib.block(m, "Trunk", CF.new(at(pos, h / 2)) * CF.Angles(0, 0, math.rad(rng(-6, 6))), V3.new(1.6 * s, h, 1.6 * s), wood)
	for k = 1, 4 do
		local a = k / 4 * math.pi * 2 + rng(0, 1)
		local y = h * (0.45 + k * 0.12)
		lib.block(m, "Branch", CF.new(at(pos, y)) * CF.Angles(0, a, math.rad(50)) * CF.new(0, 2.2 * s, 0), V3.new(0.8 * s, 4.5 * s, 0.8 * s), wood)
	end
	return m
end

function props.Ghost(parent, pos, rng, s)
	local m = new("Ghost", parent)
	local y = (6 + rng(0, 6)) * s
	lib.blob(m, "Body", CF.new(at(pos, y)), V3.new(5, 7, 5) * s, rgb(240, 245, 255), M.SmoothPlastic, { Transparency = 0.25 })
	for _, x in { -0.8, 0.8 } do
		lib.ball(m, "Eye", at(pos, y + 1.2 * s) + V3.new(x * s, 0, -2.3 * s), 0.9 * s, rgb(40, 30, 60))
	end
	lib.anim(m, "Bob", { BobAmp = 1.5, BobSpeed = 1.2 + rng(0, 0.6) })
	return m
end

function props.Candle(parent, pos, rng, s)
	local m = new("Candle", parent)
	local h = (2 + rng(0, 3)) * s
	lib.cyl(m, "Wax", at(pos, h / 2), h, 1.2 * s, rgb(255, 245, 220))
	local flame = lib.blob(m, "Flame", CF.new(at(pos, h + 0.6 * s)), V3.new(0.6, 1.2, 0.6) * s, rgb(255, 200, 60), M.Neon)
	lib.light(flame, rgb(255, 170, 70), 8, 1.4)
	lib.anim(flame, "Pulse", { PulseSpeed = 6 })
	return m
end

---------------------------------------------------------------- Partout
function props.Tree(parent, pos, rng, s)
	local m = new("Tree", parent)
	local h = (6 + rng(0, 4)) * s
	lib.cyl(m, "Trunk", at(pos, h / 2), h, 1.6 * s, rgb(150, 100, 70))
	local leaf = lib.pick(rng, { rgb(255, 170, 210), rgb(140, 230, 150), rgb(255, 220, 140), rgb(190, 160, 255) })
	lib.ball(m, "Leaves", at(pos, h + 2.5 * s), 7 * s, leaf)
	lib.ball(m, "Leaves", at(pos, h + 1.5 * s) + V3.new(2.5 * s, 0, 1 * s), 5 * s, leaf)
	lib.ball(m, "Leaves", at(pos, h + 1.5 * s) + V3.new(-2.2 * s, 0.5 * s, -1.2 * s), 5 * s, leaf)
	return m
end

function props.Flower(parent, pos, rng, s)
	local m = new("Flower", parent)
	lib.cyl(m, "Stem", at(pos, 1.2 * s), 2.4 * s, 0.3 * s, rgb(90, 200, 110))
	local c = lib.pick(rng, lib.CANDY)
	for k = 1, 5 do
		local a = k / 5 * math.pi * 2
		lib.ball(m, "Petal", at(pos, 2.6 * s) + V3.new(math.cos(a) * 0.55 * s, 0, math.sin(a) * 0.55 * s), 0.8 * s, c)
	end
	lib.ball(m, "Heart", at(pos, 2.7 * s), 0.6 * s, rgb(255, 240, 120))
	return m
end

function props.Duck(parent, pos, rng, s)
	local m = new("RubberDuck", parent)
	local yaw = CF.new(at(pos, 0.4 * s)) * CF.Angles(0, rng(0, math.pi * 2), 0)
	local y = rgb(255, 220, 50)
	lib.blob(m, "Body", yaw, V3.new(3, 2, 3.8) * s, y)
	lib.ball(m, "Head", (yaw * CF.new(0, 1.6 * s, -1.1 * s)).Position, 1.8 * s, y)
	lib.block(m, "Beak", yaw * CF.new(0, 1.4 * s, -2.1 * s), V3.new(0.8, 0.3, 0.7) * s, rgb(255, 140, 40), lib.Enum.Material.SmoothPlastic)
	for _, x in { -0.45, 0.45 } do
		lib.ball(m, "Eye", (yaw * CF.new(x * s, 1.9 * s, -1.85 * s)).Position, 0.3 * s, rgb(20, 20, 30))
	end
	lib.anim(m, "Bob", { BobAmp = 0.25, BobSpeed = 1.5 + rng(0, 0.8) })
	return m
end

function props.LilyPad(parent, pos, rng, s)
	local m = new("LilyPad", parent)
	lib.cyl(m, "Pad", at(pos, 0.1), 0.3, (4 + rng(0, 3)) * s, rgb(110, 210, 120))
	if rng() < 0.5 then
		lib.ball(m, "Bloom", at(pos, 0.8 * s), 1.4 * s, lib.pick(rng, { rgb(255, 170, 220), rgb(255, 255, 255) }))
	end
	return m
end

function props.Lamp(parent, pos, rng, s)
	local m = new("Lamp", parent)
	lib.cyl(m, "Post", at(pos, 4 * s), 8 * s, 0.5 * s, rgb(255, 255, 255))
	local bulb = lib.ball(m, "Bulb", at(pos, 8.6 * s), 1.8 * s, lib.pick(rng, lib.CANDY), lib.Enum.Material.Neon)
	lib.light(bulb, bulb.Color, 16, 1)
	lib.cyl(m, "Cap", at(pos, 9.6 * s), 0.4 * s, 2.4 * s, rgb(255, 255, 255))
	return m
end

function props.Bench(parent, pos, rng, s, yawAngle)
	local m = new("Bench", parent)
	local yaw = CF.new(pos) * CF.Angles(0, yawAngle or rng(0, math.pi * 2), 0)
	local c = lib.pick(rng, lib.CANDY)
	lib.block(m, "Seat", yaw * CF.new(0, 1.5 * s, 0), V3.new(6, 0.5, 2) * s, c)
	lib.block(m, "Back", yaw * CF.new(0, 2.8 * s, 0.9 * s), V3.new(6, 2, 0.4) * s, c)
	for _, x in { -2.5, 2.5 } do
		lib.block(m, "Leg", yaw * CF.new(x * s, 0.7 * s, 0), V3.new(0.4, 1.4, 1.8) * s, rgb(255, 255, 255))
	end
	return m
end

-- Îlot sous un groupe d'objets (sur l'eau)
function props.Islet(parent, pos, radius, color)
	local m = new("Islet", parent)
	lib.cyl(m, "Ground", V3.new(pos.X, lib.WATER + 0.6, pos.Z), 2.4, radius * 2, color)
	lib.cyl(m, "Shore", V3.new(pos.X, lib.WATER + 0.2, pos.Z), 1.2, radius * 2 + 3, lib.rgb(255, 240, 200))
	return m, V3.new(pos.X, lib.WATER + 1.8, pos.Z)
end

return props
