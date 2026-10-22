-- Popaint (générateur de map) : construit tout le monde à partir du contenu (Content/*.luau).
local lib = require("./lib")
local layout = require("./layout")
local shapes = require("./shapes")
local props = require("./props")
local themes = require("./themes")
local centerpieces = require("./centerpieces")
local hubDecor = require("./hub")

local V3, CF, E, UDim2 = lib.Vector3, lib.CFrame, lib.Enum, lib.UDim2
local rgb = lib.rgb
local M = E.Material
local ZONE, TILE, HALF, HUB, H = lib.ZONE, lib.TILE, lib.HALF, lib.HUB, lib.WALL_H

local world = {}

-- emplacements des œufs dans le hub : { distance au centre, angle en degrés }
local EGG_SPOTS = {
	{ 44, 215 }, { 44, 145 }, { 44, 35 }, { 44, 55 }, { 44, 125 }, { 44, 325 },
	{ 44, 235 }, { 44, 305 }, { 30, 45 }, { 30, 135 }, { 30, 225 }, { 30, 315 },
}

function world.build(Workspace, content)
	local map = lib.folder("Map", Workspace)
	local hub = lib.model("Hub", map, "Persistent")
	local zonesFolder = lib.folder("Zones", map)
	local gatesModel = lib.model("Gates", map, "Persistent")
	local eggsModel = lib.model("Eggs", map, "Persistent")
	local decor = lib.folder("Decor", map)
	local walls = lib.folder("Walls", map)
	local reliefFolder = lib.folder("Relief", map)
	local terrainPlan = lib.folder("TerrainPlan", map)

	local ctx = {}
	function ctx.wall(name, size, cf)
		lib.part({ Name = name, Size = size, CFrame = cf, Transparency = 1, CanQuery = false, Parent = walls })
	end

	local plan = layout.build(content.Zones)
	-- keepPlay : uniquement le hub, les zones et les ponts (rien ne doit flotter au-dessus)
	local keepPlay = lib.newKeepOut()
	keepPlay:add(-HALF - 10, -HALF - 10, HALF + 10, HALF + 10)
	for _, info in plan.order do
		keepPlay:add(info.MinX - 10, info.MinZ - 10, info.MinX + ZONE + 10, info.MinZ + ZONE + 10)
	end
	ctx.keepPlay = keepPlay
	local keepOut = lib.newKeepOut()
	keepOut:add(-HALF - 6, -HALF - 6, HALF + 6, HALF + 6)
	for _, info in plan.order do
		keepOut:add(info.MinX - 22, info.MinZ - 22, info.MinX + ZONE + 22, info.MinZ + ZONE + 22)
	end
	for _, b in plan.bridges do
		local hl, hw = b.Length / 2 + 4, 16
		if b.AlongX then
			keepOut:add(b.X - hl, b.Z - hw, b.X + hl, b.Z + hw)
		else
			keepOut:add(b.X - hw, b.Z - hl, b.X + hw, b.Z + hl)
		end
	end

	------------------------------------------------------------ mer
	local seaMinX, seaMinZ, seaMaxX, seaMaxZ = -HALF, -HALF, HALF, HALF
	for _, info in plan.order do
		seaMinX = math.min(seaMinX, info.MinX)
		seaMinZ = math.min(seaMinZ, info.MinZ)
		seaMaxX = math.max(seaMaxX, info.MinX + ZONE)
		seaMaxZ = math.max(seaMaxZ, info.MinZ + ZONE)
	end
	local seaPad = 600
	lib.part({
		Name = "CandySea",
		Size = V3.new(seaMaxX - seaMinX + seaPad * 2, 2, seaMaxZ - seaMinZ + seaPad * 2),
		CFrame = CF.new((seaMinX + seaMaxX) / 2, lib.WATER - 1, (seaMinZ + seaMaxZ) / 2),
		Color = rgb(150, 220, 255),
		Material = M.SmoothPlastic,
		Parent = decor,
	})
	lib.part({
		Name = "SeaShine",
		Size = V3.new(seaMaxX - seaMinX + seaPad * 2, 0.2, seaMaxZ - seaMinZ + seaPad * 2),
		CFrame = CF.new((seaMinX + seaMaxX) / 2, lib.WATER + 0.05, (seaMinZ + seaMaxZ) / 2),
		Color = rgb(200, 240, 255),
		Material = M.Glass,
		Transparency = 0.6,
		CanCollide = false,
		CanQuery = false,
		Parent = decor,
	})

	------------------------------------------------------------ hub
	world.hub(hub, plan, ctx)

	------------------------------------------------------------ zones
	for _, info in plan.order do
		world.zone(info, zonesFolder, gatesModel, hub, decor, ctx)
	end

	------------------------------------------------------------ œufs
	world.eggs(eggsModel, content)

	------------------------------------------------------------ décor autour des zones
	for _, info in plan.order do
		world.surroundings(info, keepOut, reliefFolder, terrainPlan, decor, keepPlay)
	end
	world.hubSurroundings(keepOut, decor)

	return map, plan
end

---------------------------------------------------------------- hub
---------------------------------------------------------------- une base de joueur (socle, machine, tapis)
-- Les noms Pad, MachineBody (avec ShopPrompt), MachineBubble, Sign/OwnerLabel et les pièces du tapis
-- (Frame, Belt, Stripe1-6, Rail, Post, Console/Screen) sont utilisés par les scripts : ne pas les renommer.
-- Les petites pièces vont dans des modèles "Details" (affichés seulement de près).
local P = lib.P
local tint = lib.tint

local function gear(parent, cf, diameter, color, speed)
	local g = lib.model("Gear", parent, "Atomic")
	local d = diameter
	local disk = lib.deco({ Name = "Disk", Shape = E.PartType.Cylinder, Size = V3.new(0.5, d, d), CFrame = cf, Color = color,
		Material = M.SmoothPlastic, Parent = g })
	g.PrimaryPart = disk
	lib.deco({ Name = "Hub", Shape = E.PartType.Cylinder, Size = V3.new(0.7, d * 0.35, d * 0.35), CFrame = cf, Color = P.white,
		Material = M.SmoothPlastic, Parent = g })
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		lib.deco({ Name = "Tooth", Size = V3.new(0.5, d * 0.18, d * 0.18), CFrame = cf * CF.Angles(a, 0, 0) * CF.new(0, d / 2, 0),
			Color = color, Material = M.SmoothPlastic, Parent = g })
	end
	lib.anim(g, "Spin", { SpinSpeed = speed, SpinAxis = "X", AnimRange = 160 })
	return g
end

local function buildBase(base, facing, padColor, accent, n)
	local d = lib.details(base)
	local rng = lib.rng(n * 101)
	-- bordure du socle : petites dalles alternées + boules aux coins
	for k = -5, 5 do
		for _, side in { { 0, 1 }, { 1, 0 }, { -1, 0 } } do
			local x = if side[1] == 0 then k * 2 else side[1] * 11.2
			local z = if side[1] == 0 then side[2] * 11.2 else k * 2
			lib.block(d, "Trim", facing * CF.new(x, 0.75, z), V3.new(if side[1] == 0 then 1.8 else 0.6, 0.3, if side[1] == 0 then 0.6 else 1.8),
				if k % 2 == 0 then P.white else tint(accent, 0.2), M.SmoothPlastic)
		end
	end
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		lib.ball(base, "Corner", (facing * CF.new(c[1] * 11.2, 1.3, c[2] * 11.2)).Position, 1.6, accent)
	end
	-- clôture en sucre d'orge derrière la base (poteaux + 2 lisses)
	for k = -4, 4 do
		local post = facing * CF.new(k * 2.5, 1.6, 10.5)
		lib.cyl(base, "Fence", post.Position, 2.6, 0.7, if k % 2 == 0 then P.white else lib.V.pink)
		lib.ball(d, "FenceCap", (post * CF.new(0, 1.5, 0)).Position, 0.9, lib.VCANDY[(k + 5) % #lib.VCANDY + 1])
	end
	for _, y in { 1.2, 2.3 } do
		lib.block(d, "FenceRail", facing * CF.new(0, y, 10.5), V3.new(20.5, 0.3, 0.25), P.white, M.SmoothPlastic)
	end
	-- pots de fleurs devant
	for _, x in { -9.5, 9.5 } do
		local pot = facing * CF.new(x, 1.3, -9.5)
		lib.cyl(base, "Pot", pot.Position, 1.6, 2, P.peach)
		lib.cyl(d, "PotRim", (pot * CF.new(0, 0.85, 0)).Position, 0.3, 2.3, tint(P.peach, 0.3))
		for k = 1, 3 do
			local a = k / 3 * math.pi * 2
			lib.ball(d, "Bloom", (pot * CF.new(math.cos(a) * 0.5, 1.5 + k * 0.1, math.sin(a) * 0.5)).Position, 0.9, lib.pick(rng, lib.VCANDY))
		end
	end
	-- paillasson « welcome »
	lib.block(d, "Mat", facing * CF.new(0, 0.62, -9), V3.new(6, 0.06, 2.4), tint(accent, 0.3), M.Fabric, { TopSurface = E.SurfaceType.Smooth })

	-- MACHINE À BULLES
	local body = lib.part({ Name = "MachineBody", Size = V3.new(6, 6, 6), CFrame = facing * CF.new(0, 3.6, 4),
		Color = accent, TopSurface = E.SurfaceType.Studs, Parent = base })
	lib.prompt(body, "ShopPrompt", "Upgrade", "Bubble Machine", 14)
	local mc = facing * CF.new(0, 3.6, 4)
	-- arêtes arrondies (pied, bandes blanches)
	lib.block(base, "MachineFoot", mc * CF.new(0, -2.8, 0), V3.new(6.8, 0.8, 6.8), P.white, M.SmoothPlastic)
	lib.block(d, "MachineBand", mc * CF.new(0, 1.8, 0), V3.new(6.2, 0.5, 6.2), P.white, M.SmoothPlastic, { TopSurface = E.SurfaceType.Smooth })
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			lib.cyl(d, "Edge", (mc * CF.new(cx * 3, 0, cz * 3)).Position, 6, 0.8, tint(accent, 0.35))
		end
	end
	-- façade (vers la fontaine : -Z) : hublot, cadran, boutons, levier
	local front = mc * CF.new(0, 0, -3.05)
	lib.cyl(d, "Porthole", front.Position + V3.new(0, 0.6, 0), 0.3, 3.2, P.white, M.SmoothPlastic, { CFrame = front * CF.new(0, 0.6, 0) * CF.Angles(0, math.rad(90), 0) })
	lib.cyl(d, "PortholeGlass", front.Position, 0.35, 2.5, P.sky, M.Glass,
		{ CFrame = front * CF.new(0, 0.6, -0.05) * CF.Angles(0, math.rad(90), 0), Transparency = 0.2 })
	for k = 1, 4 do
		lib.ball(d, "InnerBubble", (front * CF.new(rng(-0.7, 0.7), 0.6 + rng(-0.7, 0.7), 0.3)).Position, rng(0.4, 0.8), P.white, M.Glass, { Transparency = 0.3 })
	end
	for k, c in { P.coral, P.butter, P.mint } do
		lib.cyl(d, "Button", (front * CF.new(-1.6 + (k - 1) * 1.6, -1.6, -0.1)).Position, 0.3, 0.8, c, M.SmoothPlastic,
			{ CFrame = front * CF.new(-1.6 + (k - 1) * 1.6, -1.6, -0.1) * CF.Angles(0, math.rad(90), 0) })
	end
	-- cadran sur le côté avec aiguille
	local dial = mc * CF.new(3.05, 0.8, 0)
	lib.cyl(d, "Dial", dial.Position, 0.2, 2.2, P.white, M.SmoothPlastic, { CFrame = dial })
	lib.block(d, "Needle", dial * CF.new(0.12, 0.35, 0) * CF.Angles(0.5, 0, 0), V3.new(0.08, 0.9, 0.12), P.coral, M.SmoothPlastic)
	-- engrenages qui tournent sur l'autre côté
	gear(base, mc * CF.new(-3.25, 0.9, -0.9), 2.6, P.butter, 60)
	gear(base, mc * CF.new(-3.25, -0.9, 1.1), 1.8, P.lavender, -85)
	-- levier
	lib.cyl(d, "LeverBase", (mc * CF.new(3.2, -1.4, 1.8)).Position, 0.3, 0.8, P.white, M.SmoothPlastic, { CFrame = mc * CF.new(3.2, -1.4, 1.8) })
	lib.block(d, "Lever", mc * CF.new(3.5, -0.7, 1.8) * CF.Angles(0, 0, -0.4), V3.new(0.2, 1.4, 0.2), P.white, M.SmoothPlastic)
	lib.ball(d, "LeverKnob", (mc * CF.new(3.8, 0, 1.8)).Position, 0.6, P.coral)
	-- lumières qui clignotent sur le dessus
	local lights = lib.model("MachineLights", base, "Atomic")
	for k, c in { { -2.4, -2.4 }, { 2.4, -2.4 }, { -2.4, 2.4 }, { 2.4, 2.4 } } do
		local bulb = lib.ball(lights, "Bulb", (mc * CF.new(c[1], 3.3, c[2])).Position, 0.8, lib.VCANDY[k], M.SmoothPlastic)
		lib.light(bulb, lib.VCANDY[k], 6, 0.6)
	end
	lib.anim(lights, "Blink", { BlinkSpeed = 3 + n * 0.1, AnimRange = 160 })
	-- tuyau et entonnoir qui soufflent la bulle
	lib.part({ Name = "MachineTube", Shape = E.PartType.Cylinder, Size = V3.new(4, 2, 2),
		CFrame = facing * CF.new(0, 8.6, 4) * CF.Angles(0, 0, math.rad(90)), Color = P.white, Material = M.SmoothPlastic, Parent = base })
	for _, y in { 7.4, 9.6 } do
		lib.cyl(d, "TubeRing", (facing * CF.new(0, y, 4)).Position, 0.4, 2.4, accent)
	end
	lib.cyl(base, "Funnel", (facing * CF.new(0, 10.8, 4)).Position, 0.8, 3.4, tint(accent, 0.3))
	local mb = lib.part({ Name = "MachineBubble", Shape = E.PartType.Ball, Size = V3.new(4.5, 4.5, 4.5), CFrame = facing * CF.new(0, 12.9, 4),
		Color = padColor, Material = M.ForceField, CanCollide = false, Parent = base })
	lib.anim(mb, "Bob,Wobble", { BobAmp = 0.6, BobSpeed = 2, WobbleSpeed = 1.4 })
	-- petites bulles qui s'échappent
	for k = 1, 3 do
		local bub = lib.ball(base, "FreeBubble", (facing * CF.new(rng(-2, 2), 15 + k * 1.6, 4 + rng(-1.5, 1.5))).Position, 0.6 + k * 0.25,
			lib.VCANDY[k + n % 4], M.Glass, { Transparency = 0.35 })
		lib.anim(bub, "Bob,Drift", { BobAmp = 0.8 + k * 0.3, BobSpeed = 1 + k * 0.4, DriftAmp = 0.8, DriftSpeed = 0.6, AnimRange = 160 })
	end

	-- TAPIS DE COURSE (son apparence change avec son niveau, voir src/Server/TrainService.luau)
	local tm = lib.Instance.new("Model")
	tm.Name = "Treadmill"
	tm.Parent = base
	local td = lib.details(tm)
	local frame = lib.part({ Name = "Frame", Size = V3.new(5.5, 1, 12), CFrame = facing * CF.new(-7, 1.1, -2), Color = rgb(170, 166, 186),
		TopSurface = E.SurfaceType.Studs, Parent = tm })
	tm.PrimaryPart = frame
	lib.part({ Name = "Belt", Size = V3.new(4.2, 0.3, 11.2), CFrame = facing * CF.new(-7, 1.75, -2), Color = rgb(96, 88, 116),
		Material = M.SmoothPlastic, Parent = tm })
	for k = 1, 6 do
		lib.part({ Name = "Stripe" .. k, Size = V3.new(4.2, 0.05, 0.4), CFrame = facing * CF.new(-7, 1.93, -2 - 5.6 + (k - 0.5) * (11.2 / 6)),
			Color = rgb(150, 140, 176), Material = M.SmoothPlastic, CanCollide = false, CanQuery = false, Parent = tm })
	end
	-- rouleaux aux deux bouts, bandes latérales et petits pieds
	for _, z in { -7.6, 3.6 } do
		lib.deco({ Name = "Roller", Shape = E.PartType.Cylinder, Size = V3.new(5.2, 1.1, 1.1), CFrame = facing * CF.new(-7, 1.4, z),
			Color = P.white, Material = M.SmoothPlastic, Parent = td })
	end
	for _, sx in { -1, 1 } do
		lib.block(td, "SideStrip", facing * CF.new(-7 + sx * 2.45, 1.7, -2), V3.new(0.4, 0.25, 11.6), accent, M.SmoothPlastic)
		for _, z in { -7, 3 } do
			lib.ball(td, "Foot", (facing * CF.new(-7 + sx * 2.4, 0.65, z)).Position, 0.8, P.white)
		end
		lib.part({ Name = "Rail", Size = V3.new(0.4, 0.4, 11), CFrame = facing * CF.new(-7 + sx * 2.6, 3.6, -2), Color = rgb(220, 216, 232),
			Material = M.SmoothPlastic, CanCollide = false, Parent = tm })
		lib.part({ Name = "Post", Size = V3.new(0.4, 2.2, 0.4), CFrame = facing * CF.new(-7 + sx * 2.6, 2.5, -7.3), Color = rgb(170, 166, 186),
			Parent = tm })
		lib.ball(td, "Grip", (facing * CF.new(-7 + sx * 2.6, 3.6, 3.4)).Position, 0.7, P.coral)
	end
	local console = lib.part({ Name = "Console", Size = V3.new(5.5, 3, 0.8), CFrame = facing * CF.new(-7, 4.2, -8), Color = rgb(120, 112, 150),
		Parent = tm })
	for _, face in { E.NormalId.Back, E.NormalId.Front } do
		local t = lib.surfaceText(console, face, "RUN!", rgb(170, 250, 196))
		t.Name = "Screen"
		t.TextStrokeTransparency = 1
	end
	lib.block(td, "ConsoleTop", facing * CF.new(-7, 5.85, -8), V3.new(5.9, 0.3, 1.2), P.white, M.SmoothPlastic, { TopSurface = E.SurfaceType.Smooth })
	for k, c in { P.mint, P.butter, P.coral } do
		lib.ball(td, "ConsoleButton", (facing * CF.new(-8.6 + k * 0.8, 3, -7.55)).Position, 0.45, c)
	end
	lib.cyl(td, "Bottle", (facing * CF.new(-4.5, 4.6, -8)).Position, 1.2, 0.6, P.sky)
	lib.ball(td, "BottleCap", (facing * CF.new(-4.5, 5.3, -8)).Position, 0.45, P.white)
	-- ventilateur qui tourne au-dessus de la console
	local fan = lib.model("Fan", tm, "Atomic")
	local fc = facing * CF.new(-7, 6.6, -8) * CF.Angles(0, math.rad(90), 0)
	local hub = lib.deco({ Name = "FanHub", Shape = E.PartType.Cylinder, Size = V3.new(0.4, 0.6, 0.6), CFrame = fc, Color = P.white, Parent = fan })
	fan.PrimaryPart = hub
	for k = 1, 4 do
		lib.blob(fan, "Blade", fc * CF.Angles(k * math.pi / 2, 0, 0) * CF.new(0, 0.6, 0), V3.new(0.1, 1, 0.45), lib.VCANDY[k])
	end
	lib.anim(fan, "Spin", { SpinSpeed = 240, SpinAxis = "X", AnimRange = 160 })
	-- CUVE À SAVON en verre, avec des bulles qui montent et un manomètre
	local tankAt = facing * CF.new(5.8, 3.4, 2.6)
	lib.cyl(base, "TankFoot", (facing * CF.new(5.8, 1, 2.6)).Position, 1.4, 3.4, P.white)
	lib.cyl(base, "Tank", (facing * CF.new(5.8, 3.6, 2.6)).Position, 4.4, 2.9, P.sky, M.Glass, { Transparency = 0.35 })
	lib.cyl(base, "TankSoap", (facing * CF.new(5.8, 2.8, 2.6)).Position, 2.6, 2.6, tint(padColor, 0.2), M.SmoothPlastic, { Transparency = 0.15 })
	lib.cyl(d, "TankRing", (facing * CF.new(5.8, 5.7, 2.6)).Position, 0.5, 3.2, accent)
	lib.cyl(d, "TankRing", (facing * CF.new(5.8, 1.7, 2.6)).Position, 0.5, 3.2, accent)
	for k = 1, 3 do
		local bub = lib.ball(base, "TankBubble", (facing * CF.new(5.8 + rng(-0.7, 0.7), 2.4 + k * 0.7, 2.6 + rng(-0.7, 0.7))).Position,
			0.45 + k * 0.12, P.white, M.Glass, { Transparency = 0.25 })
		lib.anim(bub, "Flow", { FlowY = 1, FlowDist = 2.4, FlowSpeed = 0.5 + k * 0.12, AnimRange = 140 })
	end
	-- tuyau courbe entre la cuve et la machine
	for k = 0, 6 do
		local t = k / 6
		local p = tankAt:Lerp(mc * CF.new(3.2, 1.4, 0.6), t) * CF.new(0, math.sin(t * math.pi) * 1.4, 0)
		lib.cyl(d, "Pipe", p.Position, 0.9, 0.85, P.white)
	end
	-- manomètre dont l'aiguille tourne
	local gaugeAt = facing * CF.new(5.8, 6.4, 2.6)
	lib.cyl(base, "Gauge", gaugeAt.Position, 0.4, 2, P.cream, M.SmoothPlastic, { CFrame = gaugeAt * CF.Angles(math.rad(90), 0, 0) })
	local needle = lib.model("GaugeNeedle", base, "Atomic")
	local nd = lib.block(needle, "Needle", gaugeAt * CF.new(0, 0.3, 0), V3.new(0.12, 0.8, 0.12), P.coral, M.SmoothPlastic)
	needle.PrimaryPart = nd
	lib.anim(needle, "Spin", { SpinSpeed = 25, SpinAxis = "Y", AnimRange = 120 })

	-- CHEMINÉE sur le toit de la machine
	lib.cyl(base, "Chimney", (mc * CF.new(2, 4.2, 1.9)).Position, 3, 1.6, P.white)
	lib.cyl(d, "ChimneyCap", (mc * CF.new(2, 5.9, 1.9)).Position, 0.5, 2.3, accent)
	for k = 1, 3 do
		lib.ball(d, "Puff", (mc * CF.new(2 + rng(-0.4, 0.4), 6.6 + k * 0.9, 1.9 + rng(-0.4, 0.4))).Position, 0.8 + k * 0.2, P.white,
			M.SmoothPlastic, { Transparency = 0.35 + k * 0.12 })
	end

	-- AUVENT rayé au-dessus de la façade + marche
	for k = -3, 3 do
		lib.block(base, "Awning", mc * CF.new(k * 0.9, 2.6, -3.9) * CF.Angles(math.rad(-28), 0, 0), V3.new(0.9, 0.3, 2.6),
			if k % 2 == 0 then P.white else accent, M.Fabric, { TopSurface = E.SurfaceType.Smooth })
	end
	lib.block(d, "AwningEdge", mc * CF.new(0, 1.95, -5), V3.new(6.6, 0.35, 0.35), accent, M.SmoothPlastic)
	lib.roundBox(base, "Step", facing * CF.new(0, 0.95, 0.3), V3.new(6, 0.7, 1.8), P.white, M.SmoothPlastic, 0.4)

	-- rivets tout autour du corps
	for k = -2, 2 do
		for _, zs in { -1, 1 } do
			lib.ball(d, "Rivet", (mc * CF.new(k * 1.2, 2.5, zs * 3.05)).Position, 0.3, P.white)
		end
	end

	-- BOÎTE AUX LETTRES et petit panneau « chez moi »
	lib.cyl(base, "MailPost", (facing * CF.new(8.4, 2, -5.5)).Position, 4, 0.5, P.white)
	lib.roundBox(base, "Mailbox", facing * CF.new(8.4, 4.4, -5.5), V3.new(2.4, 1.6, 1.6), accent, M.SmoothPlastic, 0.6)
	lib.blob(d, "MailFlag", facing * CF.new(9.5, 4.9, -5.5), V3.new(0.2, 1, 0.6), P.coral)

	-- HAUT-PARLEUR et serviette près du tapis
	lib.roundBox(base, "Speaker", facing * CF.new(-10, 1.8, -7.4), V3.new(1.8, 2.4, 1.6), P.plum, M.SmoothPlastic, 0.4)
	for _, y in { 1.4, 2.4 } do
		lib.cyl(td, "SpeakerCone", (facing * CF.new(-10, y, -8.25)).Position, 0.2, 1.2, P.white, M.SmoothPlastic,
			{ CFrame = facing * CF.new(-10, y, -8.25) * CF.Angles(math.rad(90), 0, 0) })
	end
	lib.block(td, "Towel", facing * CF.new(-7, 4.1, 3.2) * CF.Angles(0.2, 0, 0), V3.new(2.4, 1.8, 0.2), P.pink, M.Fabric,
		{ TopSurface = E.SurfaceType.Smooth })

	-- fanion de la base qui se balance
	local flag = lib.model("BaseFlag", base, "Atomic")
	local pole = lib.cyl(flag, "Pole", (facing * CF.new(9.8, 4, 9.5)).Position, 8, 0.3, P.white)
	flag.PrimaryPart = pole
	lib.ball(flag, "PoleTop", (facing * CF.new(9.8, 8.2, 9.5)).Position, 0.6, P.butter)
	lib.block(flag, "Flag", facing * CF.new(8.4, 7, 9.5), V3.new(2.6, 1.6, 0.1), accent, M.Fabric, { TopSurface = E.SurfaceType.Smooth })
	lib.anim(flag, "Sway", { SwayAmp = 3, SwaySpeed = 1.6, AnimRange = 160 })
end

function world.hub(hub, plan, ctx)
	lib.part({ Name = "HubFloor", Size = V3.new(HUB, 1, HUB), CFrame = CF.new(0, -0.5, 0), Color = rgb(196, 172, 255),
		TopSurface = E.SurfaceType.Studs, Parent = hub })
	lib.part({ Name = "HubPlatform", Size = V3.new(HUB, 7, HUB), CFrame = CF.new(0, -4.5, 0), Color = rgb(255, 128, 180),
		Material = M.SmoothPlastic, Parent = hub })
	-- bordure en bonbons tout autour du hub
	for k = 0, 39 do
		local t = (k + 0.5) / 40 * HUB - HALF
		for _, p in { V3.new(t, -1, -HALF - 1.5), V3.new(t, -1, HALF + 1.5), V3.new(-HALF - 1.5, -1, t), V3.new(HALF + 1.5, -1, t) } do
			lib.ball(hub, "Border", p, 4, lib.VCANDY[(k % #lib.VCANDY) + 1])
		end
	end
	-- murs du hub : ouverts seulement là où un pont arrive
	local function side(name, horizontal, fixed, open)
		if open then
			local seg = (HUB - 24) / 2
			for k, offset in { -HALF + seg / 2, HALF - seg / 2 } do
				if horizontal then
					ctx.wall("Hub" .. name .. k, V3.new(seg, H, 1), CF.new(offset, H / 2, fixed))
				else
					ctx.wall("Hub" .. name .. k, V3.new(1, H, seg), CF.new(fixed, H / 2, offset))
				end
			end
		elseif horizontal then
			ctx.wall("Hub" .. name, V3.new(HUB + 2, H, 1), CF.new(0, H / 2, fixed))
		else
			ctx.wall("Hub" .. name, V3.new(1, H, HUB + 2), CF.new(fixed, H / 2, 0))
		end
	end
	side("N", true, -HALF - 0.5, plan.hubSides.N)
	side("S", true, HALF + 0.5, plan.hubSides.S)
	side("W", false, -HALF - 0.5, plan.hubSides.W)
	side("E", false, HALF + 0.5, plan.hubSides.E)

	-- chemins colorés vers chaque pont
	local pathColors = { N = rgb(255, 140, 190), S = rgb(90, 180, 250), W = rgb(160, 126, 250), E = rgb(96, 218, 160) }
	for dir in plan.hubSides do
		local horizontal = dir == "W" or dir == "E"
		local sign = if dir == "N" or dir == "W" then -1 else 1
		local len = HALF - 14
		local mid = sign * (14 + len / 2)
		lib.deco({ Name = "Path", Size = if horizontal then V3.new(len, 0.1, 18) else V3.new(18, 0.1, len),
			CFrame = if horizontal then CF.new(mid, 0.05, 0) else CF.new(0, 0.05, mid), Color = pathColors[dir],
			Material = M.SmoothPlastic, Parent = hub })
		-- pastilles qui guident vers le pont
		for k = 1, 6 do
			local d = sign * (20 + k * 12)
			lib.deco({ Name = "Dot", Shape = E.PartType.Cylinder, Size = V3.new(0.2, 3, 3),
				CFrame = (if horizontal then CF.new(d, 0.12, 0) else CF.new(0, 0.12, d)) * CF.Angles(0, 0, math.rad(90)),
				Color = lib.VCANDY[k % 5 + 1], Material = M.SmoothPlastic, Parent = hub })
		end
	end

	local spawn = lib.part({ Class = "SpawnLocation", Name = "Spawn", Size = V3.new(14, 1, 14), CFrame = CF.new(0, 0.5, 24),
		Color = lib.V.pink, Material = M.SmoothPlastic, Parent = hub })
	spawn.Neutral = true
	spawn.Duration = 0

	-- Grande fontaine, place en mosaïque et bord du hub en glaçage (voir tools/map/hub.luau)
	local fountainBubble = hubDecor.fountain(hub)
	local _, title = lib.billboard(fountainBubble, UDim2.fromScale(26, 7), 8, "POPAINT", rgb(255, 240, 190), 250)
	title.Name = "Title"
	hubDecor.plaza(hub)
	hubDecor.air(hub)
	hubDecor.edge(hub, plan.hubSides)

	-- 10 bases autour de la fontaine (les axes restent libres pour aller aux zones)
	local bases = lib.folder("Bases", hub)
	local padColors = {
		rgb(255, 158, 198), rgb(126, 196, 252), rgb(255, 222, 110), rgb(132, 230, 170), rgb(182, 150, 252),
		rgb(255, 180, 120), rgb(255, 146, 146), rgb(110, 224, 214), rgb(246, 150, 236), rgb(158, 172, 252),
	}
	local baseAngles = { 22.5, 45, 67.5, 112.5, 135, 157.5, 202.5, 225, 292.5, 315 }
	local basePositions = {}
	for n, deg in baseAngles do
		local angle = math.rad(deg)
		local pos = V3.new(math.cos(angle) * 78, 0, math.sin(angle) * 78)
		table.insert(basePositions, pos)
		local base = lib.Instance.new("Model")
		base.Name = string.format("Base%02d", n)
		base.Parent = bases
		local facing = CF.lookAt(pos, V3.new(0, 0, 0))
		local pad = lib.part({ Name = "Pad", Size = V3.new(22, 0.6, 22), CFrame = facing + V3.new(0, 0.3, 0), Color = padColors[n],
			TopSurface = E.SurfaceType.Studs, Parent = base })
		base.PrimaryPart = pad
		local accent = lib.VRAINBOW[(n - 1) % #lib.VRAINBOW + 1]
		buildBase(base, facing, padColors[n], accent, n)
		local sign = lib.part({ Name = "Sign", Size = V3.new(1, 1, 1), CFrame = facing * CF.new(0, 17, 4), Transparency = 1, CanCollide = false,
			CanQuery = false, Parent = base })
		local _, label = lib.billboard(sign, UDim2.fromScale(12, 3), 0, "Free base", rgb(255, 255, 255), 140)
		label.Name = "OwnerLabel"
	end

	-- détails du hub : arbres et fleurs dans les coins, lampadaires et bancs le long des chemins
	local deco = lib.folder("HubDecor", hub)
	local eggPositions = {}
	for _, spot in EGG_SPOTS do
		local a = math.rad(spot[2])
		table.insert(eggPositions, V3.new(math.cos(a) * spot[1], 0, math.sin(a) * spot[1]))
	end
	hubDecor.gardens(deco, basePositions, eggPositions)
	local rng = lib.rng(77)
	for _, c in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		local cx, cz = c[1] * 90, c[2] * 90
		props.Tree(deco, V3.new(cx, 0, cz), rng, 1.3)
		for k = 1, 10 do
			local a = rng(0, math.pi * 2)
			local r = rng(4, 9)
			props.Flower(deco, V3.new(cx + math.cos(a) * r, 0, cz + math.sin(a) * r), rng, 1.2)
		end
		props.Balloon(deco, V3.new(cx - c[1] * 4, 0, cz - c[2] * 4), rng, 0.8)
	end
	for dir in plan.hubSides do
		local horizontal = dir == "W" or dir == "E"
		local sign = if dir == "N" or dir == "W" then -1 else 1
		for _, d in { 32, 60, 88 } do
			for _, o in { -12, 12 } do
				local pos = if horizontal then V3.new(sign * d, 0, o) else V3.new(o, 0, sign * d)
				props.Lamp(deco, pos, rng, 1)
			end
		end
	end
end

---------------------------------------------------------------- une zone
function world.zone(info, zonesFolder, gatesModel, hub, decor, ctx)
	local def = info.Def
	local zf = lib.folder(def.Id, zonesFolder)
	local count = shapes.COUNT
	zf:SetAttribute("OriginX", info.MinX)
	zf:SetAttribute("OriginZ", info.MinZ)
	zf:SetAttribute("CountX", count)
	zf:SetAttribute("CountZ", count)
	zf:SetAttribute("FloorY", 0)
	zf:SetAttribute("Order", info.Index)
	zf:SetAttribute("Entrance", V3.new(info.Bridge.EntranceX, 3, info.Bridge.EntranceZ))
	if def.Event then
		zf:SetAttribute("Event", def.Event)
	end

	-- cases peignables (elles descendent jusqu'à l'eau : ce sont elles qui forment l'île)
	local inMask = shapes.mask(def.Shape, info.Sides)
	info.InMask = inMask
	local heightOf = shapes.hills(1000 + info.Index * 77, inMask)
	local tiles = lib.folder("Tiles", zf)
	for i = 1, count do
		for j = 1, count do
			if inMask(i, j) then
				local h = heightOf(i, j)
				local t = lib.part({
					Name = "T",
					Size = V3.new(TILE, h + 8, TILE),
					CFrame = CF.new(info.MinX + (i - 0.5) * TILE, (h - 8) / 2, info.MinZ + (j - 0.5) * TILE),
					Color = rgb(176, 172, 186),
					TopSurface = E.SurfaceType.Studs,
					BottomSurface = E.SurfaceType.Inlet,
					Parent = tiles,
				})
				t:SetAttribute("I", i)
				t:SetAttribute("J", j)
				if h > 0 then
					t:SetAttribute("H", h)
				end
			end
		end
	end
	-- bord de l'île : glaçage qui coule sous le bord des cases et bande colorée plus bas (décoratif)
	local theme0 = themes[def.Theme]
	local trim = lib.model("Trim", zf)
	local td = lib.details(trim)
	local trimRng = lib.rng(777 + info.Index)
	local edgeCells = 0
	for _, e in shapes.edges(inMask, info.Sides) do
		local i, j, di, dj = e[1], e[2], e[3], e[4]
		local cx = info.MinX + (i - 0.5) * TILE + di * (TILE / 2 + 0.3)
		local cz = info.MinZ + (j - 0.5) * TILE + dj * (TILE / 2 + 0.3)
		local top = heightOf(i, j)
		for k = -1, 1, 2 do
			local x = cx + (if di == 0 then k * 1 else 0)
			local z = cz + (if dj == 0 then k * 1 else 0)
			local long = trimRng(1, 2.4)
			local thin = if di == 0 then V3.new(1.9, 1 + long, 1.1) else V3.new(1.1, 1 + long, 1.9)
			lib.blob(td, "Icing", CF.new(x, top - 0.5 - long * 0.4, z), thin, theme0.Cap)
		end
		lib.deco({ Name = "Strata", Size = if di == 0 then V3.new(TILE, 1.2, 0.3) else V3.new(0.3, 1.2, TILE),
			CFrame = CF.new(cx - di * 0.15, -4.5, cz - dj * 0.15), Color = theme0.Layers[1], Material = M.SmoothPlastic, Parent = trim })
		-- coulée de peinture de couleur, de temps en temps : on dirait que la zone déborde
		if trimRng() < 0.1 then
			local paint = lib.pick(trimRng, lib.CANDY)
			lib.blob(trim, "PaintDrip", CF.new(cx, top - 2.4, cz), V3.new(1.4, 4 + trimRng(0, 3), 1.4), paint)
			lib.ball(td, "PaintBlob", V3.new(cx, top - 5.5, cz), 1.5, paint)
		end
		edgeCells += 1
		-- bornes et jardinières tout autour de l'île
		if edgeCells % 9 == 0 then
			local ox, oz = cx + di * 1.6, cz + dj * 1.6
			if trimRng() < 0.55 then
				lib.cyl(trim, "RimPost", V3.new(ox, top + 1.4, oz), 2.8, 0.7, P.white)
				local lantern = lib.ball(trim, "RimLantern", V3.new(ox, top + 3.2, oz), 1.6, P.butter, M.Glass, { Transparency = 0.2 })
				lib.light(lantern, P.butter, 10, 0.5)
				lib.cyl(td, "RimCap", V3.new(ox, top + 4.1, oz), 0.4, 1.9, def.Color)
			else
				lib.cyl(trim, "Planter", V3.new(ox, top + 0.8, oz), 1.6, 2.6, P.cream)
				lib.cyl(td, "PlanterRim", V3.new(ox, top + 1.5, oz), 0.4, 3, def.Color)
				for b = 1, 4 do
					local a = b / 4 * math.pi * 2
					lib.ball(td, "PlanterFlower", V3.new(ox + math.cos(a) * 0.7, top + 2.1, oz + math.sin(a) * 0.7), 1, lib.pick(trimRng, lib.CANDY))
				end
			end
		end
	end

	-- chemin balisé entre l'arrivée du pont et le centre de la zone
	do
		local from = V3.new(info.Bridge.EntranceX, 0, info.Bridge.EntranceZ)
		local to = V3.new(info.CX, 0, info.CZ)
		local dir = (to - from)
		local len = dir.Magnitude
		if len > 20 then
			local unit = dir.Unit
			local side = V3.new(-unit.Z, 0, unit.X)
			local steps = math.floor((len - 24) / 13)
			for k = 0, steps do
				local along = 10 + k * 13
				for _, sgn in { -1, 1 } do
					local p = from + unit * along + side * (sgn * 8)
					local i = math.floor((p.X - info.MinX) / TILE) + 1
					local j = math.floor((p.Z - info.MinZ) / TILE) + 1
					if inMask(i, j) then
						local top = heightOf(i, j)
						lib.cyl(trim, "PathPost", V3.new(p.X, top + 1.1, p.Z), 2.2, 0.5, P.white)
						local lamp = lib.ball(trim, "PathLamp", V3.new(p.X, top + 2.5, p.Z), 1.2, def.Color, M.Glass, { Transparency = 0.25 })
						lib.light(lamp, def.Color, 9, 0.45)
						lib.ball(td, "PathTop", V3.new(p.X, top + 3.2, p.Z), 0.6, P.white)
					end
				end
			end
		end
	end

	-- rayon libre au centre de la zone (le trou où va la pièce centrale) : sert à ne jamais déborder
	local freeR = math.huge
	for i = 1, count do
		for j = 1, count do
			if inMask(i, j) then
				local dx = info.MinX + (i - 0.5) * TILE - info.CX
				local dz = info.MinZ + (j - 0.5) * TILE - info.CZ
				freeR = math.min(freeR, math.sqrt(dx * dx + dz * dz))
			end
		end
	end
	info.FreeR = math.max(0, freeR - TILE * 0.8)

	local builder = centerpieces[def.Centerpiece]
	assert(builder, "pièce centrale inconnue : " .. tostring(def.Centerpiece))
	builder(zf, V3.new(info.CX, 0, info.CZ), info)

	-- pont + arche + portail
	local b = info.Bridge
	local len = b.Length
	-- couleur franche de la zone, pour tout ce qui est à l'entrée (pont, portail, arche)
	local vivid = lib.vivid(def.Color)
	lib.part({ Name = def.Id .. "Bridge", Size = if b.AlongX then V3.new(len, 1, 24) else V3.new(24, 1, len),
		CFrame = CF.new(b.X, -0.5, b.Z), Color = rgb(255, 206, 72), TopSurface = E.SurfaceType.Studs, Parent = hub })
	-- rambardes en balustres (le mur invisible empêche de tomber)
	local along = if b.AlongX then V3.new(1, 0, 0) else V3.new(0, 0, 1)
	local across = if b.AlongX then V3.new(0, 0, 1) else V3.new(1, 0, 0)
	local center = V3.new(b.X, 0, b.Z)
	local bridgeDecor = lib.model(def.Id .. "BridgeDecor", hub)
	local bd = lib.details(bridgeDecor)
	for _, s in { -1, 1 } do
		local railCenter = center + across * (s * 12.75)
		lib.part({ Name = def.Id .. "BridgeRail", Size = if b.AlongX then V3.new(len, 0.8, 1.6) else V3.new(1.6, 0.8, len),
			CFrame = CF.new(railCenter + V3.new(0, 3.2, 0)), Color = vivid, Material = M.SmoothPlastic, CanCollide = false, Parent = hub })
		lib.deco({ Name = "RailBase", Size = if b.AlongX then V3.new(len, 0.6, 1.8) else V3.new(1.8, 0.6, len),
			CFrame = CF.new(railCenter + V3.new(0, 0.3, 0)), Color = P.white, Material = M.SmoothPlastic, Parent = bridgeDecor })
		local posts = math.floor(len / 2.2)
		for k = 0, posts do
			local p = railCenter + along * ((k / posts - 0.5) * (len - 1))
			lib.cyl(bridgeDecor, "Baluster", p + V3.new(0, 1.7, 0), 2.4, 0.7, P.white)
			lib.ball(bd, "BalusterBead", p + V3.new(0, 1.7, 0), 0.95, lib.tint(vivid, 0.25))
		end
		-- lanternes aux deux bouts
		for _, e in { -1, 1 } do
			local lp = railCenter + along * (e * (len / 2 - 0.8))
			lib.cyl(bridgeDecor, "LampPost", lp + V3.new(0, 4.6, 0), 3.2, 0.5, P.white)
			local bulb = lib.ball(bridgeDecor, "LampBulb", lp + V3.new(0, 6.9, 0), 1.5, P.butter, M.Glass, { Transparency = 0.15 })
			lib.light(bulb, P.butter, 12, 0.5)
			lib.cyl(bd, "LampCap", lp + V3.new(0, 7.8, 0), 0.4, 1.8, vivid)
		end
		ctx.wall(def.Id .. "BridgeWall", if b.AlongX then V3.new(len, H, 1) else V3.new(1, H, len),
			CF.new(V3.new(b.X, H / 2, b.Z) + across * (s * 12.5)))
	end
	-- arche de soutien sous le pont et bord en glaçage
	for k = 0, 12 do
		local t = k / 12
		local p = center + along * ((t - 0.5) * len)
		local depth = math.sin(t * math.pi) * 4.5
		lib.deco({ Name = "ArchStone", Size = if b.AlongX then V3.new(len / 12 + 0.3, 1.4, 22) else V3.new(22, 1.4, len / 12 + 0.3),
			CFrame = CF.new(p + V3.new(0, -1.7 - (4.5 - depth), 0)), Color = if k % 2 == 0 then lib.tint(vivid, 0.3) else P.cream,
			Material = M.SmoothPlastic, Parent = bridgeDecor })
	end
	for _, s in { -1, 1 } do
		local e0 = center + across * (s * 12.1) - along * (len / 2)
		lib.drips(bd, e0, e0 + along * len, -1.1, P.cream, 1.2, lib.rng(len + s * 7 + 20))
	end
	local rot = if b.AlongX then CF.Angles(0, math.rad(90), 0) else CF.new()
	local base = CF.new(b.GateX, 0, b.GateZ) * rot
	local arch = lib.model(def.Id .. "Arch", decor, "Atomic", true)
	local ad = lib.details(arch)
	for _, s in { -1, 1 } do
		lib.part({ Name = "ArchPillar", Size = V3.new(3, 16, 3), CFrame = base * CF.new(s * 13.5, 8, 0), Color = P.white,
			TopSurface = E.SurfaceType.Studs, Parent = arch })
		lib.roundBox(arch, "ArchFoot", base * CF.new(s * 13.5, 1, 0), V3.new(4.6, 2, 4.6), vivid, M.SmoothPlastic, 1)
		for k, y in { 4.5, 8, 11.5, 15 } do
			lib.roundBox(ad, "PillarRing", base * CF.new(s * 13.5, y, 0), V3.new(3.6, 0.6, 3.6), if k % 2 == 0 then vivid else lib.tint(vivid, 0.4),
				M.SmoothPlastic, 0.8)
		end
		-- ruban en spirale autour du pilier
		for k = 0, 11 do
			local a = k / 12 * math.pi * 4
			lib.ball(ad, "Ribbon", (base * CF.new(s * 13.5 + math.cos(a) * 1.7, 2 + k * 1.15, math.sin(a) * 1.7)).Position, 0.6, lib.V.pink)
		end
		lib.ball(arch, "ArchBall", (base * CF.new(s * 13.5, 17.5, 0)).Position, 4, vivid, M.SmoothPlastic)
		lib.ball(ad, "ArchBallShine", (base * CF.new(s * 13.5 - 0.9, 18.6, -1.3)).Position, 1, P.white)
	end
	local top = lib.part({ Name = "ArchTop", Size = V3.new(30, 4, 3), CFrame = base * CF.new(0, 18, 0), Color = vivid,
		TopSurface = E.SurfaceType.Studs, Parent = arch })
	for _, face in { E.NormalId.Front, E.NormalId.Back } do
		lib.surfaceText(top, face, def.Name)
	end
	-- arc arrondi au-dessus du panneau, guirlande de fanions dessous
	for k = 0, 14 do
		local a = k / 14 * math.pi
		lib.roundBox(arch, "ArchCurve", base * CF.new(math.cos(a) * 13, 20 + math.sin(a) * 5, 0) * CF.Angles(0, 0, a - math.pi / 2), V3.new(2.2, 1.6, 2.4),
			if k % 2 == 0 then P.white else lib.tint(vivid, 0.3), M.SmoothPlastic, 0.6)
	end
	lib.ball(ad, "ArchStar", (base * CF.new(0, 26, 0)).Position, 2.4, lib.V.gold)
	local pennants = lib.model("Pennants", ad, "Atomic")
	for k = 1, 9 do
		local x = -11 + (k - 1) * 2.75
		local sag = math.sin((k - 1) / 8 * math.pi) * 2
		local flag = lib.block(pennants, "Pennant", base * CF.new(x, 15 - sag, 0) * CF.Angles(0, 0, math.rad(180)), V3.new(1.6, 1.8, 0.1),
			lib.VCANDY[k % #lib.VCANDY + 1], M.Fabric, { TopSurface = E.SurfaceType.Smooth })
		local wm = lib.Instance.new("SpecialMesh")
		wm.MeshType = E.MeshType.Wedge
		wm.Parent = flag
		if k == 5 then
			pennants.PrimaryPart = flag
		end
	end
	-- la guirlande ondule au vent
	lib.anim(pennants, "Sway", { SwayAmp = 7, SwaySpeed = 1.3, AnimRange = 200 })
	if def.Cost > 0 or def.Event then
		local gate = lib.part({ Name = def.Id, Size = if b.AlongX then V3.new(1.5, 16, 24) else V3.new(24, 16, 1.5),
			CFrame = CF.new(b.GateX, 8, b.GateZ), Color = vivid, Material = M.ForceField,
			CanCollide = false, -- le joueur voit le portail solide tant que la zone est fermée (src/Client/World.luau)
			Parent = gatesModel })
		gate:SetAttribute("Cost", def.Cost)
		-- losanges de lumière douce qui pulsent le long du portail (cachés quand la zone est ouverte)
		local glow = lib.model("GateGlow", gate, "Atomic")
		local gdir = if b.AlongX then V3.new(0, 0, 1) else V3.new(1, 0, 0)
		local gcenter = V3.new(b.GateX, 0, b.GateZ)
		for k = -3, 3 do
			local p = gcenter + gdir * (k * 3.2) + V3.new(0, 8 + (3 - math.abs(k)) * 1.4, 0)
			local rune = lib.blob(glow, "Rune", CF.new(p) * CF.Angles(0, 0, math.rad(45)), V3.new(1.6, 2.4, 1.6), lib.tint(vivid, 0.25),
				M.SmoothPlastic, { Transparency = 0.25 })
			if k == 0 then
				glow.PrimaryPart = rune
			end
		end
		lib.anim(glow, "Pulse,Bob", { PulseSpeed = 1.6, BobAmp = 0.6, BobSpeed = 1.2, AnimRange = 250 })
		local text = if def.Event then def.Name else def.Name .. "\n🔒 " .. lib.formatCost(def.Cost)
		local _, label = lib.billboard(gate, UDim2.fromScale(18, 5), 11, text, rgb(255, 255, 255), 160)
		label.Name = "GateLabel"
		lib.prompt(gate, "UnlockPrompt", "Unlock", def.Name, 14)
	end

	shapes.walls(ctx, def.Id, info.MinX, info.MinZ, inMask, info.Sides)

	-- décor à l'intérieur de la zone, dans les coins hors forme (sur l'eau, sous le niveau du jeu)
	local theme = themes[def.Theme]
	assert(theme, "thème inconnu : " .. tostring(def.Theme))
	local inner = lib.folder("Decor", zf)
	local rng = lib.rng(3000 + info.Index * 53)
	local placed = 0
	for _ = 1, 400 do
		if placed >= 20 then
			break
		end
		local i, j = math.floor(rng(1, count + 1)), math.floor(rng(1, count + 1))
		-- un objet ne se pose qu'au milieu de cases vides (2 cases de marge partout autour)
		local free = true
		for di = -3, 3 do
			for dj = -3, 3 do
				if inMask(i + di, j + dj) then
					free = false
				end
			end
		end
		local dCenter = math.sqrt((i - 20.5) ^ 2 + (j - 20.5) ^ 2)
		if free and dCenter > 6 then
			local pos = V3.new(info.MinX + (i - 0.5) * TILE, lib.WATER, info.MinZ + (j - 0.5) * TILE)
			local name = lib.pick(rng, theme.Water)
			props[name](inner, pos, rng, 0.9)
			placed += 1
		end
	end

	-- ambiance qui flotte dans l'air au-dessus de la zone (pétales, flocons, lucioles… voir themes.luau)
	if theme.Air then
		local air = lib.folder("Air", zf)
		local box = lib.airBox(air, "AirBox", CF.new(info.CX, 34, info.CZ), V3.new(ZONE - 10, 2, ZONE - 10))
		local down = theme.Air.Kind == "Petals" or theme.Air.Kind == "Snow" or theme.Air.Kind == "Leaves"
		lib.particles(box, theme.Air.Kind, theme.Air.Colors, {
			Rate = if down then 16 else 10,
			Direction = if down then E.NormalId.Bottom else E.NormalId.Top,
			Size = 1.6,
		})
		-- une deuxième nappe plus basse, au niveau du joueur
		local low = lib.airBox(air, "AirBoxLow", CF.new(info.CX, 10, info.CZ), V3.new(ZONE - 30, 2, ZONE - 30))
		lib.particles(low, theme.Air.Kind, theme.Air.Colors, { Rate = 6, Size = 1.1 })
	end

	-- brume légère au ras de l'eau autour de la zone
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local holder = lib.deco({ Name = "Mist", Size = V3.new(30, 1, 30), CFrame = CF.new(info.CX + math.cos(a) * 95, -6, info.CZ + math.sin(a) * 95),
			Transparency = 1, Parent = zf })
		local e = lib.Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = lib.roblox.ColorSequence.new(theme.Mist)
		e.Size = lib.roblox.NumberSequence.new(18, 30)
		e.Transparency = lib.roblox.NumberSequence.new({
			lib.roblox.NumberSequenceKeypoint.new(0, 1),
			lib.roblox.NumberSequenceKeypoint.new(0.3, 0.82),
			lib.roblox.NumberSequenceKeypoint.new(1, 1),
		})
		e.Lifetime = lib.roblox.NumberRange.new(10, 14)
		e.Rate = 1.2
		e.Speed = lib.roblox.NumberRange.new(0.5, 1.5)
		e.SpreadAngle = lib.roblox.Vector2.new(180, 10)
		e.LightEmission = 0.25
		e.RotSpeed = lib.roblox.NumberRange.new(-10, 10)
		e.Parent = holder
	end
end

---------------------------------------------------------------- œufs du hub
function world.eggs(eggsModel, content)
	local zones = content.Zones
	assert(#zones <= #EGG_SPOTS, "trop de zones pour les emplacements d'œufs du hub (ajoute des EGG_SPOTS)")
	for k, def in zones do
		local spot = EGG_SPOTS[k]
		local angle = math.rad(spot[2])
		local pos = V3.new(math.cos(angle) * spot[1], 0, math.sin(angle) * spot[1])
		local vivid = lib.vivid(def.Color)
		local vividPlatform = lib.vivid(def.Platform)
		local egg = lib.Instance.new("Model")
		egg.Name = def.Id
		egg.Parent = eggsModel
		local pedestal = lib.part({ Name = "Pedestal", Shape = E.PartType.Cylinder, Size = V3.new(2, 10, 10),
			CFrame = CF.new(pos + V3.new(0, 1, 0)) * CF.Angles(0, 0, math.rad(90)), Color = vivid, Material = M.SmoothPlastic, Parent = egg })
		egg.PrimaryPart = pedestal
		local d = lib.details(egg)
		-- socle à étages avec perles et festons
		lib.cyl(egg, "PedestalFoot", pos + V3.new(0, 0.25, 0), 0.5, 11.4, lib.tint(vivid, 0.2))
		lib.cyl(egg, "PedestalTop", pos + V3.new(0, 2.1, 0), 0.4, 8.6, P.white)
		for k = 1, 20 do
			local a = k / 20 * math.pi * 2
			lib.ball(d, "Pearl", pos + V3.new(math.cos(a) * 5.05, 1.9, math.sin(a) * 5.05), 0.7, if k % 2 == 0 then P.white else vividPlatform)
			if k % 2 == 0 then
				lib.blob(d, "Scallop", CF.new(pos + V3.new(math.cos(a) * 5.1, 0.9, math.sin(a) * 5.1)) * CF.Angles(0, -a, 0), V3.new(0.4, 1.2, 1.8),
					lib.tint(vivid, 0.35))
			end
		end
		-- l'œuf : coquille, bande en zigzag, pois et reflet. Tout est dans "EggBody" pour qu'il tremble.
		local body = lib.model("EggBody", egg, "Atomic")
		local shell = lib.part({ Name = "Shell", Shape = E.PartType.Ball, Size = V3.new(6, 6, 6), CFrame = CF.new(pos + V3.new(0, 5, 0)),
			Color = vividPlatform, Material = M.SmoothPlastic, Parent = body })
		body.PrimaryPart = shell
		local mesh = lib.Instance.new("SpecialMesh")
		mesh.MeshType = E.MeshType.Sphere
		mesh.Scale = V3.new(1, 1.3, 1)
		mesh.Parent = shell
		for k = 1, 16 do
			local a = k / 16 * math.pi * 2
			local y = 5 + (if k % 2 == 0 then 0.5 else -0.5)
			lib.block(body, "Zigzag", CF.new(pos + V3.new(math.cos(a) * 2.92, y, math.sin(a) * 2.92)) * CF.Angles(0, -a, if k % 2 == 0 then 0.6 else -0.6),
				V3.new(0.4, 1.4, 1.3), vivid, M.SmoothPlastic, { TopSurface = E.SurfaceType.Smooth })
		end
		for s = 1, 6 do
			local a = math.rad(s * 60 + 30)
			local up = if s % 2 == 0 then 1.9 else -1.6
			local r = math.sqrt(math.max(0, 1 - (up / 3.9) ^ 2)) * 2.95
			lib.ball(body, "Spot", pos + V3.new(math.cos(a) * r, 5 + up, math.sin(a) * r), 1.1, lib.VCANDY[s], M.SmoothPlastic)
		end
		lib.blob(lib.details(body), "Gloss", CF.new(pos + V3.new(-1.2, 6.8, -1.6)) * CF.Angles(0.3, 0.6, 0.4), V3.new(1, 1.8, 0.4), P.white, M.SmoothPlastic,
			{ Transparency = 0.35 })
		-- l'œuf tremble de temps en temps : il est sur le point d'éclore
		lib.anim(body, "Shake", { ShakePeriod = 5 + (k % 4) * 0.7, ShakeAmp = 6, AnimRange = 180 })
		-- halo de magie et étincelles autour de l'œuf
		local aura = lib.airBox(egg, "Aura", CF.new(pos + V3.new(0, 2.6, 0)), V3.new(7, 1, 7))
		lib.particles(aura, "Aura", { vivid, vividPlatform }, { Rate = 5, Size = 1.1 })
		local spark = lib.airBox(egg, "Magic", CF.new(pos + V3.new(0, 5, 0)), V3.new(6.5, 6.5, 6.5))
		lib.particles(spark, "Sparkle", { P.white, vivid }, { Rate = 8, Size = 1.1 })
		-- étincelles qui tournent autour de l'œuf
		local sparkles = lib.model("EggSparkles", egg, "Atomic")
		local center = lib.deco({ Name = "Center", Size = V3.new(0.2, 0.2, 0.2), CFrame = CF.new(pos + V3.new(0, 5, 0)), Transparency = 1, Parent = sparkles })
		sparkles.PrimaryPart = center
		for k = 1, 6 do
			local a = k / 6 * math.pi * 2
			local sp = CF.new(pos + V3.new(math.cos(a) * 4.4, 5 + math.sin(k * 1.3) * 1.6, math.sin(a) * 4.4))
			for r = 0, 1 do
				lib.block(sparkles, "Sparkle", sp * CF.Angles(0, 0, r * math.pi / 2 + math.pi / 4), V3.new(0.25, 0.9, 0.25), if k % 2 == 0 then P.butter else P.white,
					M.SmoothPlastic, { TopSurface = E.SurfaceType.Smooth })
			end
		end
		lib.anim(sparkles, "Spin", { SpinSpeed = 40, AnimRange = 120 })
		-- couronne flottante au-dessus
		local crown = lib.model("EggCrown", egg, "Atomic")
		local band = lib.cyl(crown, "CrownBand", pos + V3.new(0, 10, 0), 0.6, 2.4, lib.V.gold)
		crown.PrimaryPart = band
		for k = 1, 5 do
			local a = k / 5 * math.pi * 2
			lib.ball(crown, "CrownPoint", pos + V3.new(math.cos(a) * 1.05, 10.6, math.sin(a) * 1.05), 0.55, lib.V.gold)
		end
		lib.ball(crown, "CrownJewel", pos + V3.new(0, 10.1, -1.2), 0.5, vivid)
		lib.anim(crown, "Spin,Bob", { SpinSpeed = 30, BobAmp = 0.4, BobSpeed = 2, AnimRange = 140 })
		local lines = { def.Name .. " EGG", "💰 " .. lib.formatCost(def.EggCost) }
		local _, label = lib.billboard(shell, UDim2.fromScale(10, 12), 10, table.concat(lines, "\n"), rgb(255, 255, 255), 60)
		label.Name = "EggLabel"
		lib.prompt(shell, "EggPrompt", "Open", def.Name .. " Egg", 12)
	end
end

---------------------------------------------------------------- décor autour d'une zone
local function studMountain(theme, x, z, baseSize, layers, rng, parent)
	-- montagne en terrasses arrondies, avec avancées rocheuses, petits objets sur les corniches,
	-- glaçage qui coule du sommet et parfois une cascade. Les petites pièces vont dans "Details".
	local m = lib.model("Mountain", parent, nil, true)
	local d = lib.details(m)
	local layerH = rng(4, 6.5)
	local y = lib.WATER
	local size = baseSize
	local rot = CF.Angles(0, math.rad(rng(0, 90)), 0)
	local first = nil
	local terraces = {}
	for k = 1, layers do
		local isTop = k == layers or size * 0.74 < 4
		local depth = size * rng(0.8, 1)
		local cf = CF.new(x + rng(-1.5, 1.5), y + layerH / 2, z + rng(-1.5, 1.5)) * rot
		local color = if isTop then theme.Cap else theme.Layers[(k - 1) % #theme.Layers + 1]
		local material = if isTop then theme.CapMaterial else M.Plastic
		local extra = { Transparency = if isTop and theme.CapMaterial == M.Glass then 0.3 else 0 }
		local layerPart = lib.roundBox(m, if isTop then "MountainCap" else "MountainLayer", cf, V3.new(size, layerH, depth), color, material,
			math.min(size, depth) * 0.22, extra)
		layerPart.CanCollide = true
		first = first or layerPart
		-- avancée rocheuse sur un côté
		if not isTop and rng() < 0.7 then
			local a = rng(0, math.pi * 2)
			local w = size * rng(0.25, 0.4)
			lib.roundBox(m, "Outcrop", cf * CF.new(math.cos(a) * size * 0.42, -layerH * 0.2, math.sin(a) * depth * 0.42), V3.new(w, layerH * 0.6, w),
				lib.tint(color, 0.12), M.Plastic, w * 0.3)
		end
		table.insert(terraces, { CF = cf, Size = size, Depth = depth, Top = y + layerH, Color = color })
		y += layerH
		size *= rng(0.68, 0.8)
		if isTop then
			break
		end
	end
	-- petits objets du thème sur les corniches (entre le bord d'un étage et l'étage suivant)
	for k = 1, #terraces - 1 do
		local t, nxt = terraces[k], terraces[k + 1]
		for _ = 1, 3 do
			local a = rng(0, math.pi * 2)
			local r = (t.Size / 2 + nxt.Size / 2) / 2
			local p = (t.CF * CF.new(math.cos(a) * r, 0, math.sin(a) * r)).Position
			p = V3.new(p.X, t.Top, p.Z)
			local kind = theme.Mini or "Tree"
			if kind == "Tree" or kind == "Gummy" then
				local c = lib.pick(rng, lib.CANDY)
				lib.cyl(d, "MiniTrunk", p + V3.new(0, 0.6, 0), 1.2, 0.4, P.cocoa)
				lib.ball(d, "MiniTree", p + V3.new(0, 1.8, 0), 1.8, if kind == "Gummy" then c else lib.tint(P.sage, rng(0, 0.3)))
			elseif kind == "Crystal" then
				lib.block(d, "MiniCrystal", CF.new(p + V3.new(0, 1, 0)) * CF.Angles(rng(-0.3, 0.3), rng(0, 3), rng(-0.3, 0.3)), V3.new(0.8, 2.2, 0.8),
					lib.pick(rng, { P.sky, P.lilac, P.aqua }), M.Glass, { Transparency = 0.2, TopSurface = E.SurfaceType.Smooth })
			elseif kind == "Lamp" then
				lib.cyl(d, "MiniPost", p + V3.new(0, 1, 0), 2, 0.25, P.white)
				lib.ball(d, "MiniLamp", p + V3.new(0, 2.2, 0), 0.7, lib.pick(rng, lib.CANDY))
			elseif kind == "Pumpkin" then
				lib.blob(d, "MiniPumpkin", CF.new(p + V3.new(0, 0.5, 0)), V3.new(1.4, 1, 1.4), P.peach)
				lib.cyl(d, "MiniStem", p + V3.new(0, 1.1, 0), 0.4, 0.2, P.sage)
			else -- fleurs
				lib.ball(d, "MiniFlower", p + V3.new(0, 0.4, 0), 0.8, lib.pick(rng, lib.CANDY))
			end
		end
	end
	-- glaçage / neige qui coule du sommet
	local top = terraces[#terraces]
	for k = 1, 10 do
		local a = k / 10 * math.pi * 2
		local p = (top.CF * CF.new(math.cos(a) * top.Size * 0.5, 0, math.sin(a) * top.Depth * 0.5)).Position
		lib.blob(d, "CapDrip", CF.new(p.X, top.Top - layerH * 0.5, p.Z), V3.new(1.6, rng(1.6, 3.2), 1.6), theme.Cap)
	end
	-- cascade sur un flanc (verre + écume en bas)
	if rng() < 0.45 then
		local fall = CF.new(x, (lib.WATER + y) / 2 - 2, z) * rot * CF.new(0, 0, baseSize * 0.45)
		local h = math.max(4, y - lib.WATER - 6)
		lib.block(m, "Waterfall", fall, V3.new(2.4, h, 0.8), P.sky, M.Glass, { Transparency = 0.25, TopSurface = E.SurfaceType.Smooth })
		for k = 1, 5 do
			lib.ball(d, "Foam", (fall * CF.new(rng(-1.6, 1.6), -h / 2 + 0.4, rng(-0.4, 1.2))).Position, rng(0.9, 1.6), P.white)
		end
	end
	if first then
		m.PrimaryPart = first
	end
	return m
end

function world.surroundings(info, keepOut, reliefFolder, terrainPlan, decor, keepPlay)
	local def = info.Def
	local theme = themes[def.Theme]
	local rng = lib.rng(5000 + info.Index * 131)
	local zf = lib.folder(def.Id, reliefFolder)
	local cx, cz = info.CX, info.CZ
	local function ring(minD, maxD)
		local a = rng(0, math.pi * 2)
		local d = rng(minD, maxD)
		return cx + math.cos(a) * d, cz + math.sin(a) * d
	end

	-- montagnes à studs
	local placed = 0
	for _ = 1, 500 do
		if placed >= 10 then
			break
		end
		local base = rng(22, 42)
		local x, z = ring(ZONE / 2 + 40, ZONE / 2 + 120)
		if keepOut:free(x, z, base * 0.75) then
			studMountain(theme, x, z, base, math.floor(rng(4, 8)), rng, zf)
			keepOut:add(x - base * 0.45, z - base * 0.45, x + base * 0.45, z + base * 0.45)
			placed += 1
		end
	end

	-- collines lisses (terrain Roblox, sculpté par le serveur au lancement)
	local hills = 0
	for _ = 1, 1500 do
		if hills >= 11 then
			break
		end
		local r = rng(14, 30)
		local x, z = ring(ZONE / 2 + 30 + r * 0.5, ZONE / 2 + 170)
		if keepOut:free(x, z, r + 2) then
			for _, layer in { { "Hill", V3.new(x, lib.WATER - r * 0.45, z), r, theme.Terrain }, { "Cap", V3.new(x, lib.WATER - r * 0.45 + r * 0.75, z), r * 0.35, theme.TerrainCap } } do
				if layer[1] == "Hill" or r > 20 then
					local c = lib.Instance.new("Configuration")
					c.Name = layer[1]
					c:SetAttribute("Position", layer[2])
					c:SetAttribute("Radius", layer[3])
					c:SetAttribute("Material", layer[4])
					c:SetAttribute("Zone", def.Id)
					c.Parent = terrainPlan
				end
			end
			-- quelques objets du thème posés sur la colline
			for _ = 1, 2 do
				local a = rng(0, math.pi * 2)
				local d = rng(0, r * 0.35)
				local top = lib.WATER - r * 0.45 + math.sqrt(math.max(0, r * r - d * d)) - 0.5
				local name = lib.pick(rng, theme.Land)
				if name ~= "NeonTower" and name ~= "Crane" and name ~= "IceArch" and name ~= "RainbowFall" and name ~= "JellyStack"
					and name ~= "Windmill" and name ~= "CandyCart" then
					props[name](zf, V3.new(x + math.cos(a) * d, top, z + math.sin(a) * d), rng, 0.8)
				end
			end
			keepOut:add(x - r * 0.6, z - r * 0.6, x + r * 0.6, z + r * 0.6)
			hills += 1
		end
	end

	-- îlots couverts d'objets du thème
	local islets = 0
	for _ = 1, 600 do
		if islets >= 22 then
			break
		end
		local r = rng(6, 13)
		local x, z = ring(ZONE / 2 + 26, ZONE / 2 + 160)
		if keepOut:free(x, z, r + 3) then
			local isle, top = props.Islet(decor, V3.new(x, 0, z), r, theme.Islet, rng)
			local n = math.floor(rng(1, 4.99))
			for k = 1, n do
				local a = rng(0, math.pi * 2)
				local d = if k == 1 then 0 else rng(r * 0.3, r * 0.7)
				local name = lib.pick(rng, theme.Land)
				props[name](isle, top + V3.new(math.cos(a) * d, 0, math.sin(a) * d), rng, if k == 1 then rng(0.9, 1.4) else rng(0.6, 0.9))
			end
			keepOut:add(x - r, z - r, x + r, z + r)
			islets += 1
		end
	end

	-- objets sur l'eau
	local water = 0
	for _ = 1, 600 do
		if water >= 30 then
			break
		end
		local x, z = ring(ZONE / 2 + 24, ZONE / 2 + 140)
		if keepOut:free(x, z, 5) then
			props[lib.pick(rng, theme.Water)](decor, V3.new(x, lib.WATER, z), rng, rng(0.8, 1.2))
			keepOut:add(x - 3, z - 3, x + 3, z + 3)
			water += 1
		end
	end

	-- objets dans le ciel
	local sky = 0
	for _ = 1, 100 do
		if sky >= 12 then
			break
		end
		local x, z = ring(ZONE / 2 + 20, ZONE / 2 + 140)
		if keepPlay:free(x, z, 14) then
			props[lib.pick(rng, theme.Sky)](decor, V3.new(x, lib.WATER + rng(20, 40), z), rng, rng(1, 1.6))
			sky += 1
		end
	end
end

-- Décor de l'eau autour du hub (canards, nénuphars, petits îlots)
function world.hubSurroundings(keepOut, decor)
	local rng = lib.rng(91)
	local theme = themes.Candy
	local n = 0
	for _ = 1, 400 do
		if n >= 24 then
			break
		end
		local a = rng(0, math.pi * 2)
		local d = rng(120, 175)
		local x, z = math.cos(a) * d, math.sin(a) * d
		if keepOut:free(x, z, 5) then
			props[lib.pick(rng, theme.Water)](decor, V3.new(x, lib.WATER, z), rng, 1)
			keepOut:add(x - 3, z - 3, x + 3, z + 3)
			n += 1
		end
	end
end

return world
