-- Popaint (générateur de map) : construit tout le monde à partir du contenu (Content/*.luau).
local lib = require("./lib")
local layout = require("./layout")
local shapes = require("./shapes")
local props = require("./props")
local themes = require("./themes")
local centerpieces = require("./centerpieces")

local V3, CF, E, UDim2 = lib.Vector3, lib.CFrame, lib.Enum, lib.UDim2
local rgb = lib.rgb
local M = E.Material
local ZONE, TILE, HALF, HUB, H = lib.ZONE, lib.TILE, lib.HALF, lib.HUB, lib.WALL_H

local world = {}

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
function world.hub(hub, plan, ctx)
	lib.part({ Name = "HubFloor", Size = V3.new(HUB, 1, HUB), CFrame = CF.new(0, -0.5, 0), Color = rgb(214, 196, 255),
		TopSurface = E.SurfaceType.Studs, Parent = hub })
	lib.part({ Name = "HubPlatform", Size = V3.new(HUB, 7, HUB), CFrame = CF.new(0, -4.5, 0), Color = rgb(255, 182, 214),
		Material = M.SmoothPlastic, Parent = hub })
	-- bordure en bonbons tout autour du hub
	for k = 0, 39 do
		local t = (k + 0.5) / 40 * HUB - HALF
		for _, p in { V3.new(t, -1, -HALF - 1.5), V3.new(t, -1, HALF + 1.5), V3.new(-HALF - 1.5, -1, t), V3.new(HALF + 1.5, -1, t) } do
			lib.ball(hub, "Border", p, 4, lib.CANDY[(k % #lib.CANDY) + 1])
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
	local pathColors = { N = rgb(255, 200, 225), S = rgb(200, 230, 255), W = rgb(210, 200, 255), E = rgb(200, 255, 215) }
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
				Color = lib.CANDY[k % 5 + 1], Material = M.Neon, Parent = hub })
		end
	end

	local spawn = lib.part({ Class = "SpawnLocation", Name = "Spawn", Size = V3.new(14, 1, 14), CFrame = CF.new(0, 0.5, 24),
		Color = rgb(255, 92, 168), Material = M.Neon, Parent = hub })
	spawn.Neutral = true
	spawn.Duration = 0

	-- Fontaine arc-en-ciel au centre
	for i, c in lib.RAINBOW do
		local size = 18 - (i - 1) * 3.2
		lib.part({ Name = "Fountain" .. i, Shape = E.PartType.Cylinder, Size = V3.new(1.2, size, size),
			CFrame = CF.new(0, 0.6 + (i - 1) * 1.2, 0) * CF.Angles(0, 0, math.rad(90)), Color = c,
			Material = if i % 2 == 0 then M.Neon else M.SmoothPlastic, Parent = hub })
	end
	local fountainBubble = lib.ball(hub, "FountainBubble", V3.new(0, 10, 0), 7, rgb(255, 170, 230), M.ForceField)
	lib.anim(fountainBubble, "Bob", { BobAmp = 1, BobSpeed = 1.5 })
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2
		local jet = lib.ball(hub, "Jet", V3.new(math.cos(a) * 5, 7.5, math.sin(a) * 5), 1.6, lib.RAINBOW[(k % 5) + 1], M.Neon)
		lib.anim(jet, "Bob", { BobAmp = 0.8, BobSpeed = 3 + k * 0.2 })
	end
	local _, title = lib.billboard(fountainBubble, UDim2.fromScale(26, 7), 8, "POPAINT", rgb(255, 240, 120), 250)
	title.Name = "Title"

	-- 10 bases autour de la fontaine (les axes restent libres pour aller aux zones)
	local bases = lib.folder("Bases", hub)
	local padColors = {
		rgb(255, 205, 225), rgb(205, 235, 255), rgb(255, 245, 190), rgb(205, 255, 215), rgb(230, 210, 255),
		rgb(255, 220, 190), rgb(255, 205, 205), rgb(195, 255, 245), rgb(255, 215, 245), rgb(215, 225, 255),
	}
	local baseAngles = { 22.5, 45, 67.5, 112.5, 135, 157.5, 202.5, 225, 292.5, 315 }
	for n, deg in baseAngles do
		local angle = math.rad(deg)
		local pos = V3.new(math.cos(angle) * 78, 0, math.sin(angle) * 78)
		local base = lib.Instance.new("Model")
		base.Name = string.format("Base%02d", n)
		base.Parent = bases
		local facing = CF.lookAt(pos, V3.new(0, 0, 0))
		local pad = lib.part({ Name = "Pad", Size = V3.new(22, 0.6, 22), CFrame = facing + V3.new(0, 0.3, 0), Color = padColors[n],
			TopSurface = E.SurfaceType.Studs, Parent = base })
		base.PrimaryPart = pad
		-- petite clôture de bonbons derrière la base
		for k = -4, 4 do
			lib.ball(base, "Fence", (facing * CF.new(k * 2.5, 1.2, 10.5)).Position, 1.6, lib.CANDY[(k + 5) % 5 + 1])
		end
		local body = lib.part({ Name = "MachineBody", Size = V3.new(6, 6, 6), CFrame = facing * CF.new(0, 3.6, 4),
			Color = lib.RAINBOW[(n - 1) % #lib.RAINBOW + 1], TopSurface = E.SurfaceType.Studs, Parent = base })
		lib.prompt(body, "ShopPrompt", "Upgrade", "Bubble Machine", 14)
		lib.part({ Name = "MachineTube", Shape = E.PartType.Cylinder, Size = V3.new(4, 2, 2),
			CFrame = facing * CF.new(0, 8.6, 4) * CF.Angles(0, 0, math.rad(90)), Color = rgb(255, 255, 255), Material = M.SmoothPlastic,
			Parent = base })
		local mb = lib.part({ Name = "MachineBubble", Shape = E.PartType.Ball, Size = V3.new(4.5, 4.5, 4.5), CFrame = facing * CF.new(0, 12.5, 4),
			Color = padColors[n], Material = M.ForceField, CanCollide = false, Parent = base })
		lib.anim(mb, "Bob", { BobAmp = 0.6, BobSpeed = 2 })
		-- Tapis de course (son apparence change avec son niveau, voir src/Server/TrainService.luau)
		local tm = lib.Instance.new("Model")
		tm.Name = "Treadmill"
		tm.Parent = base
		local frame = lib.part({ Name = "Frame", Size = V3.new(5.5, 1, 12), CFrame = facing * CF.new(-7, 1.1, -2), Color = rgb(120, 120, 135),
			TopSurface = E.SurfaceType.Studs, Parent = tm })
		tm.PrimaryPart = frame
		lib.part({ Name = "Belt", Size = V3.new(4.2, 0.3, 11.2), CFrame = facing * CF.new(-7, 1.75, -2), Color = rgb(45, 40, 60),
			Material = M.SmoothPlastic, Parent = tm })
		for k = 1, 6 do
			lib.part({ Name = "Stripe" .. k, Size = V3.new(4.2, 0.05, 0.4), CFrame = facing * CF.new(-7, 1.93, -2 - 5.6 + (k - 0.5) * (11.2 / 6)),
				Color = rgb(90, 85, 110), Material = M.SmoothPlastic, CanCollide = false, CanQuery = false, Parent = tm })
		end
		for _, sx in { -1, 1 } do
			lib.part({ Name = "Rail", Size = V3.new(0.4, 0.4, 11), CFrame = facing * CF.new(-7 + sx * 2.6, 3.6, -2), Color = rgb(200, 200, 215),
				Material = M.Neon, CanCollide = false, Parent = tm })
			lib.part({ Name = "Post", Size = V3.new(0.4, 2.2, 0.4), CFrame = facing * CF.new(-7 + sx * 2.6, 2.5, -7.3), Color = rgb(200, 200, 215),
				Parent = tm })
		end
		local console = lib.part({ Name = "Console", Size = V3.new(5.5, 3, 0.8), CFrame = facing * CF.new(-7, 4.2, -8), Color = rgb(60, 55, 85),
			Parent = tm })
		for _, face in { E.NormalId.Back, E.NormalId.Front } do
			local t = lib.surfaceText(console, face, "RUN!", rgb(120, 255, 160))
			t.Name = "Screen"
			t.TextStrokeTransparency = 1
		end
		local sign = lib.part({ Name = "Sign", Size = V3.new(1, 1, 1), CFrame = facing * CF.new(0, 17, 4), Transparency = 1, CanCollide = false,
			CanQuery = false, Parent = base })
		local _, label = lib.billboard(sign, UDim2.fromScale(12, 3), 0, "Free base", rgb(255, 255, 255), 140)
		label.Name = "OwnerLabel"
	end

	-- détails du hub : arbres et fleurs dans les coins, lampadaires et bancs le long des chemins
	local deco = lib.folder("HubDecor", hub)
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
					Color = rgb(150, 150, 158),
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
	local builder = centerpieces[def.Centerpiece]
	assert(builder, "pièce centrale inconnue : " .. tostring(def.Centerpiece))
	builder(zf, V3.new(info.CX, 0, info.CZ), info)

	-- pont + arche + portail
	local b = info.Bridge
	local len = b.Length
	lib.part({ Name = def.Id .. "Bridge", Size = if b.AlongX then V3.new(len, 1, 24) else V3.new(24, 1, len),
		CFrame = CF.new(b.X, -0.5, b.Z), Color = rgb(255, 236, 140), TopSurface = E.SurfaceType.Studs, Parent = hub })
	for _, s in { -1, 1 } do
		local offset = if b.AlongX then V3.new(0, 2, s * 12.75) else V3.new(s * 12.75, 2, 0)
		lib.part({ Name = def.Id .. "BridgeRail", Size = if b.AlongX then V3.new(len, 3, 1.5) else V3.new(1.5, 3, len),
			CFrame = CF.new(V3.new(b.X, 0, b.Z) + offset), Color = def.Color, Material = M.Neon, Parent = hub })
		ctx.wall(def.Id .. "BridgeWall", if b.AlongX then V3.new(len, H, 1) else V3.new(1, H, len),
			CF.new(V3.new(b.X, H / 2, b.Z) + (if b.AlongX then V3.new(0, 0, s * 12.5) else V3.new(s * 12.5, 0, 0))))
	end
	local rot = if b.AlongX then CF.Angles(0, math.rad(90), 0) else CF.new()
	local base = CF.new(b.GateX, 0, b.GateZ) * rot
	local arch = lib.model(def.Id .. "Arch", decor, "Atomic", true)
	for _, s in { -1, 1 } do
		lib.part({ Name = "ArchPillar", Size = V3.new(3, 16, 3), CFrame = base * CF.new(s * 13.5, 8, 0), Color = rgb(255, 255, 255),
			TopSurface = E.SurfaceType.Studs, Parent = arch })
		lib.ball(arch, "ArchBall", (base * CF.new(s * 13.5, 17, 0)).Position, 4, def.Color, M.Neon)
	end
	local top = lib.part({ Name = "ArchTop", Size = V3.new(30, 4, 3), CFrame = base * CF.new(0, 18, 0), Color = def.Color,
		TopSurface = E.SurfaceType.Studs, Parent = arch })
	for _, face in { E.NormalId.Front, E.NormalId.Back } do
		lib.surfaceText(top, face, def.Name)
	end
	if def.Cost > 0 or def.Event then
		local gate = lib.part({ Name = def.Id, Size = if b.AlongX then V3.new(1.5, 16, 24) else V3.new(24, 16, 1.5),
			CFrame = CF.new(b.GateX, 8, b.GateZ), Color = def.Color, Material = M.ForceField,
			CanCollide = false, -- le joueur voit le portail solide tant que la zone est fermée (src/Client/World.luau)
			Parent = gatesModel })
		gate:SetAttribute("Cost", def.Cost)
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
		if placed >= 14 then
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
local EGG_SPOTS = {
	{ 44, 215 }, { 44, 145 }, { 44, 35 }, { 44, 55 }, { 44, 125 }, { 44, 325 },
	{ 44, 235 }, { 44, 305 }, { 30, 45 }, { 30, 135 }, { 30, 225 }, { 30, 315 },
}
function world.eggs(eggsModel, content)
	local zones = content.Zones
	assert(#zones <= #EGG_SPOTS, "trop de zones pour les emplacements d'œufs du hub (ajoute des EGG_SPOTS)")
	for k, def in zones do
		local spot = EGG_SPOTS[k]
		local angle = math.rad(spot[2])
		local pos = V3.new(math.cos(angle) * spot[1], 0, math.sin(angle) * spot[1])
		local egg = lib.Instance.new("Model")
		egg.Name = def.Id
		egg.Parent = eggsModel
		local pedestal = lib.part({ Name = "Pedestal", Shape = E.PartType.Cylinder, Size = V3.new(2, 10, 10),
			CFrame = CF.new(pos + V3.new(0, 1, 0)) * CF.Angles(0, 0, math.rad(90)), Color = def.Color, Material = M.Neon, Parent = egg })
		egg.PrimaryPart = pedestal
		local shell = lib.part({ Name = "Shell", Shape = E.PartType.Ball, Size = V3.new(6, 6, 6), CFrame = CF.new(pos + V3.new(0, 5, 0)),
			Color = def.Platform, Material = M.SmoothPlastic, Parent = egg })
		local mesh = lib.Instance.new("SpecialMesh")
		mesh.MeshType = E.MeshType.Sphere
		mesh.Scale = V3.new(1, 1.3, 1)
		mesh.Parent = shell
		for s = 1, 4 do
			local a = math.rad(s * 90)
			lib.ball(egg, "Spot", pos + V3.new(math.cos(a) * 2.7, 5 + (s % 2) * 1.2, math.sin(a) * 2.7), 1.4, lib.CANDY[s], M.Neon)
		end
		local lines = { def.Name .. " EGG", "💰 " .. lib.formatCost(def.EggCost) }
		local _, label = lib.billboard(shell, UDim2.fromScale(10, 12), 10, table.concat(lines, "\n"), rgb(255, 255, 255), 60)
		label.Name = "EggLabel"
		lib.prompt(shell, "EggPrompt", "Open", def.Name .. " Egg", 12)
	end
end

---------------------------------------------------------------- décor autour d'une zone
local function studMountain(theme, x, z, baseSize, layers, rng, parent)
	local m = lib.model("Mountain", parent, nil, true)
	local layerH = rng(4, 6.5)
	local y = lib.WATER
	local size = baseSize
	local rot = CF.Angles(0, math.rad(rng(0, 90)), 0)
	for k = 1, layers do
		local isTop = k == layers
		lib.part({
			Name = if isTop then "MountainCap" else "MountainLayer",
			Size = V3.new(size, layerH, size * rng(0.8, 1)),
			CFrame = CF.new(x + rng(-1.5, 1.5), y + layerH / 2, z + rng(-1.5, 1.5)) * rot,
			Color = if isTop then theme.Cap else theme.Layers[(k - 1) % #theme.Layers + 1],
			Material = if isTop then theme.CapMaterial else M.Plastic,
			TopSurface = E.SurfaceType.Studs,
			Transparency = if isTop and theme.CapMaterial == M.Glass then 0.3 else 0,
			Parent = m,
		})
		y += layerH
		size *= rng(0.68, 0.8)
		if size < 4 then
			break
		end
	end
	-- petites cascades de bonbons / neige sur les flancs
	if rng() < 0.5 then
		lib.block(m, "Drip", CF.new(x, (lib.WATER + y) / 2 - 2, z) * rot * CF.new(0, 0, baseSize * 0.42), V3.new(2, math.max(4, y - lib.WATER - 6), 1),
			theme.Cap, M.Neon, { Transparency = 0.3 })
	end
	lib.primary(m)
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
				if name ~= "NeonTower" and name ~= "Crane" and name ~= "IceArch" and name ~= "RainbowFall" and name ~= "JellyStack" then
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
		if islets >= 16 then
			break
		end
		local r = rng(6, 13)
		local x, z = ring(ZONE / 2 + 26, ZONE / 2 + 160)
		if keepOut:free(x, z, r + 3) then
			local isle, top = props.Islet(decor, V3.new(x, 0, z), r, theme.Islet)
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
		if water >= 22 then
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
		if sky >= 8 then
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
		if n >= 14 then
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
