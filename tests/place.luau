-- Vérifie le fichier de jeu généré : scripts à leur place, map cohérente avec le contenu
-- (Content/*.luau), décor jamais posé sur les zones de jeu, chargement progressif réglé.
-- Ces tests lisent la liste des zones : une zone ajoutée en mise à jour est vérifiée automatiquement.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local lib = require("./lib")
local test, eq, ok = lib.test, lib.eq, lib.ok

local game = roblox.deserializePlace(fs.readFile("build/Popaint.rbxlx"))
local Config = lib.loadModule("src/Shared/Config.luau")
local ws = game:GetService("Workspace")
local Map = ws.Map
local E = roblox.Enum

lib.suite("Fichier de jeu : scripts")

local expected = {}
local function addDir(dir, root, classFor)
	for _, file in fs.readDir("src/" .. dir) do
		if string.sub(file, -5) == ".luau" then
			local class, name = classFor(file)
			if class then
				table.insert(expected, { root .. "." .. name, class, "src/" .. dir .. "/" .. file })
			end
		end
	end
end
local function moduleOf(f)
	return "ModuleScript", (string.gsub(f, "%.luau$", ""))
end
addDir("Shared", "ReplicatedStorage.Shared", moduleOf)
addDir("Shared/Content", "ReplicatedStorage.Shared.Content", moduleOf)
addDir("Server", "ServerScriptService.Server", function(f)
	if string.find(f, "%.server%.luau$") then
		return "Script", (string.gsub(f, "%.server%.luau$", ""))
	end
	return moduleOf(f)
end)
addDir("Client", "StarterPlayer.StarterPlayerScripts.ClientMain.Modules", function(f)
	if string.find(f, "%.client%.luau$") then
		return nil, nil
	end
	return moduleOf(f)
end)
table.insert(expected, { "StarterPlayer.StarterPlayerScripts.ClientMain", "LocalScript", "src/Client/ClientMain.client.luau" })

local function find(path)
	local node = game
	for name in string.gmatch(path, "[^%.]+") do
		node = node:FindFirstChild(name)
		if not node then
			return nil
		end
	end
	return node
end

test("chaque script est présent, du bon type, avec le bon code", function()
	for _, e in expected do
		local inst = find(e[1])
		ok(inst, "absent : " .. e[1])
		eq(inst.ClassName, e[2], e[1])
		eq(inst.Source, fs.readFile(e[3]), "code différent : " .. e[1])
	end
end)

test("aucun script en trop (ex. scripts de test oubliés)", function()
	local count = 0
	for _, d in game:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			count += 1
		end
	end
	eq(count, #expected)
end)

test("chaque WaitForChild vise un objet existant", function()
	local names = {}
	for _, d in game:GetDescendants() do
		names[d.Name] = true
	end
	for _, svc in game:GetChildren() do
		names[svc.Name] = true
	end
	for _, created in { "Remotes", "PlayerGui", "HumanoidRootPart", "Humanoid", "leaderstats", "Coins" } do
		names[created] = true
	end
	for _, e in expected do
		local src = fs.readFile(e[3])
		for name in string.gmatch(src, 'WaitForChild%("([^"]+)"') do
			ok(names[name], ("%s attend '%s' qui n'existe pas"):format(e[1], name))
		end
	end
end)

---------------------------------------------------------------- zones de jeu
lib.suite("Fichier de jeu : zones")

-- Rectangles jouables : hub, ponts, et chaque case peignable
local tileRects = {}
local playRects = { { -100, -100, 100, 100 } }
for _, b in Map.Hub:GetChildren() do
	if string.find(b.Name, "Bridge$") then
		local p, sz = b.CFrame.Position, b.Size
		table.insert(playRects, { p.X - sz.X / 2, p.Z - sz.Z / 2, p.X + sz.X / 2, p.Z + sz.Z / 2 })
	end
end
for _, zone in Map.Zones:GetChildren() do
	for _, t in zone.Tiles:GetChildren() do
		local p = t.CFrame.Position
		table.insert(tileRects, { p.X - 2, p.Z - 2, p.X + 2, p.Z + 2 })
	end
end
for _, r in tileRects do
	table.insert(playRects, r)
end

local function circleHits(rects, x, z, r)
	for _, rc in rects do
		local cx, cz = math.clamp(x, rc[1], rc[3]), math.clamp(z, rc[2], rc[4])
		if (x - cx) ^ 2 + (z - cz) ^ 2 < r * r then
			return true
		end
	end
	return false
end

-- rayon au sol d'une pièce (cercle englobant, rotation comprise)
local function footprint(p)
	local s = p.Size
	if p.Shape == E.PartType.Cylinder then
		local look = p.CFrame.RightVector
		if math.abs(look.Y) > 0.9 then
			return s.Y / 2 -- cylindre vertical
		end
	end
	return 0.5 * math.sqrt(s.X * s.X + s.Z * s.Z + (if math.abs(p.CFrame.UpVector.Y) < 0.9 then s.Y * s.Y else 0))
end

local function bottomOf(p)
	return p.CFrame.Position.Y - 0.5 * math.max(p.Size.X, p.Size.Y, p.Size.Z)
end

test("une zone dans la map pour chaque zone du contenu", function()
	eq(#Map.Zones:GetChildren(), #Config.Zones)
	for _, z in Config.Zones do
		local zone = Map.Zones:FindFirstChild(z.Id)
		ok(zone, "zone absente : " .. z.Id)
		ok(typeof(zone:GetAttribute("Entrance")) == "Vector3", "entrée de " .. z.Id)
		eq(zone:GetAttribute("Event"), z.Event, "événement de " .. z.Id)
	end
end)

test("cases : position, hauteur, forme", function()
	for _, zone in Map.Zones:GetChildren() do
		local ox, oz = zone:GetAttribute("OriginX"), zone:GetAttribute("OriginZ")
		eq(zone:GetAttribute("CountX") * zone:GetAttribute("CountZ"), 1600)
		local seen, n = {}, 0
		for _, t in zone.Tiles:GetChildren() do
			local i, j = t:GetAttribute("I"), t:GetAttribute("J")
			local key = i .. ":" .. j
			ok(not seen[key], "case en double " .. key)
			seen[key] = true
			n += 1
			local p = t.CFrame.Position
			ok(math.abs(p.X - (ox + (i - 0.5) * 4)) < 1e-3 and math.abs(p.Z - (oz + (j - 0.5) * 4)) < 1e-3, "position " .. key)
			local h = t:GetAttribute("H") or 0
			ok(math.abs(p.Y + t.Size.Y / 2 - h) < 1e-3, "hauteur de colline")
			ok(math.abs((p.Y - t.Size.Y / 2) - (-8)) < 1e-3, "chaque case descend jusqu'à l'eau")
			eq(t.TopSurface, E.SurfaceType.Studs, "studs sur le dessus")
			ok(t.Anchored, "case ancrée")
		end
		ok(n > 300 and n < 1600, zone.Name .. " a une vraie forme (pas un carré plein) : " .. n)
	end
end)

test("collines peignables : praticables (marches de 1 stud), entrées plates", function()
	local withHills = 0
	for _, zone in Map.Zones:GetChildren() do
		local heights = {}
		local hillTiles = 0
		for _, t in zone.Tiles:GetChildren() do
			local h = t:GetAttribute("H") or 0
			heights[t:GetAttribute("I") .. ":" .. t:GetAttribute("J")] = h
			ok(h <= 4, "collines de 4 marches max")
			if h > 0 then
				hillTiles += 1
			end
		end
		if hillTiles > 20 then
			withHills += 1
		end
		for i = 1, 40 do
			for j = 1, 40 do
				local h = heights[i .. ":" .. j]
				for _, d in { { 1, 0 }, { 0, 1 } } do
					local n = heights[(i + d[1]) .. ":" .. (j + d[2])]
					if n and h then
						ok(math.abs(h - n) <= 1, ("marche trop haute dans %s en %d,%d"):format(zone.Name, i, j))
					end
				end
			end
		end
		for _, e in { { 20, 1 }, { 21, 40 }, { 1, 20 }, { 40, 21 } } do
			local h = heights[e[1] .. ":" .. e[2]]
			if h ~= nil then
				ok(h == 0, zone.Name .. " : entrée plate")
			end
		end
	end
	ok(withHills >= math.ceil(#Config.Zones / 2), "des collines dans la plupart des zones")
end)

test("murs invisibles tout le long des contours (on ne tombe pas à l'eau)", function()
	for _, zone in Map.Zones:GetChildren() do
		local ox, oz = zone:GetAttribute("OriginX"), zone:GetAttribute("OriginZ")
		local has = {}
		for _, t in zone.Tiles:GetChildren() do
			has[t:GetAttribute("I") * 100 + t:GetAttribute("J")] = true
		end
		local walls = {}
		for _, w in Map.Walls:GetChildren() do
			if w.Name == zone.Name .. "Edge" then
				table.insert(walls, w)
			end
		end
		local function covered(x, z)
			for _, w in walls do
				local p, s = w.CFrame.Position, w.Size
				if math.abs(x - p.X) <= s.X / 2 + 0.01 and math.abs(z - p.Z) <= s.Z / 2 + 0.01 then
					return true
				end
			end
			return false
		end
		local openings = 0
		for key in has do
			local i, j = key // 100, key % 100
			for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local ni, nj = i + d[1], j + d[2]
				if not has[ni * 100 + nj] then
					local ex = ox + (i - 0.5 + d[1] * 0.5) * 4
					local ez = oz + (j - 0.5 + d[2] * 0.5) * 4
					local outside = ni < 1 or nj < 1 or ni > 40 or nj > 40
					local mid = (d[1] == 0 and i >= 18 and i <= 23) or (d[2] == 0 and j >= 18 and j <= 23)
					if outside and mid and not covered(ex, ez) then
						openings += 1 -- ouverture vers un pont
					else
						ok(covered(ex, ez), ("trou dans le contour de %s en %d,%d"):format(zone.Name, i, j))
					end
				end
			end
		end
		ok(openings >= 6, zone.Name .. " : ouverture vers un pont")
	end
end)

test("ponts : chaque zone est reliée, le hub n'est ouvert que vers des ponts", function()
	local bridges = {}
	for _, b in Map.Hub:GetChildren() do
		if string.find(b.Name, "Bridge$") then
			bridges[(string.gsub(b.Name, "Bridge$", ""))] = b
		end
	end
	for _, z in Config.Zones do
		local b = bridges[z.Id]
		ok(b, "pont vers " .. z.Id)
		local len = math.max(b.Size.X, b.Size.Z)
		ok(len >= 20 and len <= 60, "longueur du pont " .. z.Id .. " : " .. len)
	end
	-- les murs du hub laissent un trou de 24 studs seulement face à un pont
	local hubWalls = {}
	for _, w in Map.Walls:GetChildren() do
		if string.sub(w.Name, 1, 3) == "Hub" then
			table.insert(hubWalls, w)
		end
	end
	for _, side in { { 0, -100.5 }, { 0, 100.5 }, { -100.5, 0 }, { 100.5, 0 } } do
		local blocked = false
		for _, w in hubWalls do
			local p, s = w.CFrame.Position, w.Size
			if math.abs(side[1] - p.X) <= s.X / 2 + 0.01 and math.abs(side[2] - p.Z) <= s.Z / 2 + 0.01 then
				blocked = true
			end
		end
		local hasBridge = false
		for _, b in bridges do
			local p = b.CFrame.Position
			if (side[1] == 0 and math.abs(p.X) < 1 and p.Z * side[2] > 0 and math.abs(p.Z) < 130)
				or (side[2] == 0 and math.abs(p.Z) < 1 and p.X * side[1] > 0 and math.abs(p.X) < 130) then
				hasBridge = true
			end
		end
		eq(blocked, not hasBridge, "ouverture du hub en " .. side[1] .. "," .. side[2])
	end
end)

test("portails, œufs et machines", function()
	for _, z in Config.Zones do
		local gate = Map.Gates:FindFirstChild(z.Id)
		if z.Cost > 0 or z.Event then
			ok(gate and gate:FindFirstChildWhichIsA("ProximityPrompt", true), "portail " .. z.Id)
			ok(not gate.CanCollide, "le portail n'est solide que côté joueur")
		else
			ok(not gate, z.Id .. " est ouverte")
		end
		local egg = Map.Eggs:FindFirstChild(z.Id)
		ok(egg and egg:FindFirstChildWhichIsA("ProximityPrompt", true), "œuf " .. z.Id)
	end
	local bases = Map.Hub.Bases:GetChildren()
	eq(#bases, Config.BaseCount)
	for _, base in bases do
		ok(base:FindFirstChild("ShopPrompt", true), "machine " .. base.Name)
		ok(base:FindFirstChild("OwnerLabel", true) and base:FindFirstChild("Pad"), "base " .. base.Name)
	end
	ok(Map.Hub:FindFirstChild("Spawn") and Map.Hub.Spawn.ClassName == "SpawnLocation", "point d'apparition")
	-- les œufs et les bases ne bloquent pas les passages vers les ponts
	for _, folder in { Map.Eggs, Map.Hub.Bases } do
		for _, m in folder:GetChildren() do
			local p = m.PrimaryPart.CFrame.Position
			ok(math.abs(p.X) > 21 or math.abs(p.Z) > 100, "passage libre (" .. m.Name .. ")")
			ok(math.abs(p.Z) > 21 or math.abs(p.X) > 100, "passage libre (" .. m.Name .. ")")
		end
	end
end)

test("tapis de course dans chaque base", function()
	for _, base in Map.Hub.Bases:GetChildren() do
		local tm = base:FindFirstChild("Treadmill")
		ok(tm and tm:FindFirstChild("Belt") and tm:FindFirstChild("Console"), "tapis " .. base.Name)
		local belt, machine, pad = tm.Belt, base.MachineBody, base.Pad
		local rel = pad.CFrame:PointToObjectSpace(belt.CFrame.Position)
		ok(math.abs(rel.X) + belt.Size.X / 2 <= pad.Size.X / 2 and math.abs(rel.Z) + belt.Size.Z / 2 <= pad.Size.Z / 2, "tapis sur le socle")
		local m = pad.CFrame:PointToObjectSpace(machine.CFrame.Position)
		ok(math.abs(m.X - rel.X) > (machine.Size.X + belt.Size.X) / 2, "le tapis ne touche pas la machine")
	end
end)

test("pièces centrales : présentes, jamais sur les cases, impossibles à escalader", function()
	for _, z in Config.Zones do
		local zone = Map.Zones[z.Id]
		local count = 0
		for _, child in zone:GetChildren() do
			if child.Name ~= "Tiles" and child.Name ~= "Decor" and child.Name ~= "Mist" then
				for _, p in (if child:IsA("BasePart") then { child } else child:GetDescendants()) do
					if p:IsA("BasePart") then
						count += 1
						local pos = p.CFrame.Position
						-- ce qui est au niveau du sol ne doit couvrir aucune case
						if bottomOf(p) < 6 and p.Name ~= "Blocker" then
							ok(not circleHits(tileRects, pos.X, pos.Z, footprint(p) * 0.9),
								("%s : %s couvre des cases de jeu"):format(z.Id, p.Name))
						end
					end
				end
			end
		end
		ok(count >= 3, "pièce centrale de " .. z.Id)
	end
	for _, id in { "CandyMeadow", "PumpkinPatch" } do
		local zone = Map.Zones:FindFirstChild(id)
		if zone then
			local blocker = zone:FindFirstChild("Blocker")
			ok(blocker and blocker.CanCollide and blocker.Size.X >= 60, "on ne peut pas grimper au centre de " .. id)
		end
	end
end)

---------------------------------------------------------------- décor
lib.suite("Fichier de jeu : décor et chargement progressif")

test("le décor n'empiète jamais sur le hub, les ponts ou les zones", function()
	local checked = 0
	local function check(inst, where)
		for _, p in inst:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "CandySea" and p.Name ~= "SeaShine" then
				local pos = p.CFrame.Position
				if bottomOf(p) < 12 then
					ok(not circleHits(playRects, pos.X, pos.Z, footprint(p) * 0.9),
						("%s : %s (%s) empiète sur une zone de jeu en %d,%d"):format(where, p.Name, p.Parent.Name, pos.X, pos.Z))
				end
				checked += 1
			end
		end
	end
	for _, child in Map.Decor:GetChildren() do
		if not string.find(child.Name, "Arch$") then
			check(child, "Decor")
		end
	end
	check(Map.Relief, "Relief")
	for _, zone in Map.Zones:GetChildren() do
		local d = zone:FindFirstChild("Decor")
		if d then
			check(d, zone.Name)
		end
	end
	ok(checked > 1500, "beaucoup de décor : " .. checked .. " pièces")
end)

test("le décor ne bloque rien : pas de collision, ancré", function()
	for _, folder in { Map.Decor, Map.Hub:FindFirstChild("HubDecor") } do
		for _, p in folder:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "CandySea" and not string.find(p.Parent.Name, "Arch$") then
				ok(not p.CanCollide, "décor solide : " .. p:GetFullName())
			end
		end
	end
	for _, p in Map:GetDescendants() do
		if p:IsA("BasePart") then
			ok(p.Anchored, "pièce non ancrée : " .. p:GetFullName())
		end
	end
end)

test("chaque zone a son décor autour (montagnes, îlots, objets, collines lisses)", function()
	for _, z in Config.Zones do
		local relief = Map.Relief:FindFirstChild(z.Id)
		ok(relief, "relief de " .. z.Id)
		local mountains = 0
		for _, m in relief:GetChildren() do
			if m.Name == "Mountain" then
				mountains += 1
			end
		end
		ok(mountains >= 6, z.Id .. " : montagnes " .. mountains)
		local hills = 0
		for _, item in Map.TerrainPlan:GetChildren() do
			if item:GetAttribute("Zone") == z.Id and item.Name == "Hill" then
				hills += 1
				local pos, r = item:GetAttribute("Position"), item:GetAttribute("Radius")
				ok(typeof(pos) == "Vector3" and type(r) == "number" and type(item:GetAttribute("Material")) == "string", "plan de terrain valide")
				ok(not circleHits(playRects, pos.X, pos.Z, r), "colline de terrain sur une zone de jeu")
			end
		end
		ok(hills >= 6, z.Id .. " : collines lisses " .. hills)
	end
	local islets = 0
	for _, m in Map.Decor:GetChildren() do
		if m.Name == "Islet" then
			islets += 1
		end
	end
	ok(islets >= 8 * #Config.Zones, "îlots décorés : " .. islets)
end)

test("animations valides et brouillard léger", function()
	local valid = { Spin = true, Bob = true, Pulse = true, Wobble = true, Sway = true, Drift = true, Swim = true, Blink = true }
	local animated, mists = 0, 0
	for _, d in Map:GetDescendants() do
		local a = d:GetAttribute("Anim")
		if a then
			animated += 1
			for k in string.gmatch(a, "[^,]+") do
				ok(valid[k], "animation inconnue : " .. k)
			end
			ok((d:IsA("Model") and d.PrimaryPart) or d:IsA("BasePart"), "objet animé valide : " .. d:GetFullName())
			if d:IsA("Model") then
				eq(d.ModelStreamingMode, E.ModelStreamingMode.Atomic, "un modèle animé arrive en entier : " .. d:GetFullName())
			end
		end
		if d:IsA("ParticleEmitter") and d.Parent.Name == "Mist" then
			mists += 1
		end
	end
	ok(animated >= 150, "décor animé : " .. animated)
	ok(mists >= 6 * #Config.Zones, "brume autour des zones")
	local atmo = game:GetService("Lighting"):FindFirstChildOfClass("Atmosphere")
	ok(atmo and atmo.Density > 0.25 and atmo.Density < 0.45, "brouillard léger")
end)

test("chargement progressif (render distance)", function()
	eq(ws.StreamingEnabled, true)
	ok(ws.StreamingTargetRadius >= 256 and ws.StreamingTargetRadius <= 1024, "distance de chargement")
	ok(ws.StreamingMinRadius >= 64, "zone toujours chargée autour du joueur")
	-- ce que les scripts des joueurs lisent dès le départ doit toujours être chargé
	for _, m in { Map.Hub, Map.Gates, Map.Eggs } do
		eq(m.ClassName, "Model")
		eq(m.ModelStreamingMode, E.ModelStreamingMode.Persistent, m.Name .. " toujours chargé")
	end
	-- les montagnes restent visibles de loin en version simplifiée
	for _, zf in Map.Relief:GetChildren() do
		for _, m in zf:GetChildren() do
			if m.Name == "Mountain" then
				eq(m.LevelOfDetail, E.ModelLevelOfDetail.StreamingMesh, "montagne visible de loin")
			end
		end
	end
end)

return lib
