-- Tests unitaires : formules, textes, réglages, grille de peinture, sauvegarde (avec faux DataStore).
local lib = require("./lib")
local roblox = require("@lune/roblox")
local test, eq, ok, near = lib.test, lib.eq, lib.ok, lib.near

local Config = lib.loadModule("src/Shared/Config.luau")
local Formulas = lib.loadFile("src/Shared/Formulas.luau")
local Locale = lib.loadFile("src/Shared/Locale.luau")
local PaintGrid = lib.loadFile("src/Server/PaintGrid.luau")
local ProfileStore = lib.loadFile("src/Server/ProfileStore.luau")

---------------------------------------------------------------- Formules
lib.suite("Formules")
test("prix des améliorations +15 % par niveau", function()
	eq(Formulas.upgradeCost(10, 0), 10)
	eq(Formulas.upgradeCost(10, 1), 12) -- 11,5 arrondi
	eq(Formulas.upgradeCost(100, 10), 405) -- 100 x 1,15^10 = 404,56
	local prev = 0
	for lvl = 0, 200 do
		local c = Formulas.upgradeCost(25, lvl)
		ok(c >= prev, "le prix ne doit jamais baisser")
		prev = c
	end
end)
test("niveau du joueur", function()
	local function lvl(s, b, c)
		return Formulas.level({ StudsPainted = s, BubblesPopped = b, CoinsEarned = c })
	end
	eq(lvl(0, 0, 0), 1, "nouveau joueur")
	eq(lvl(199, 0, 0), 1)
	eq(lvl(200, 0, 0), 2) -- racine(200/50) = 2
	eq(lvl(5000, 0, 0), 10)
	eq(lvl(0, 2500, 0), 10) -- 2 points par bulle
	eq(lvl(0, 0, 50000), 10) -- 1 point pour 10 pièces
	eq(lvl(0 / 0, 0, 0), 1, "valeur corrompue")
	local prev = 1
	for s = 0, 200000, 997 do
		local l = lvl(s, 0, 0)
		ok(l >= prev, "le niveau ne doit jamais baisser")
		prev = l
	end
end)
test("récompense d'un éclatement", function()
	eq(Formulas.popReward(0, 1, 1), 0)
	eq(Formulas.popReward(7, 1, 1), 7)
	eq(Formulas.popReward(7, 1, 2), 14)
	eq(Formulas.popReward(7, 3, 1), 21)
	eq(Formulas.popReward(1, 0.1, 1), 1, "jamais 0 si on a peint")
end)
test("affichage des grands nombres", function()
	local cases = {
		{ 0, "0" }, { 7, "7" }, { 999, "999" }, { 1000, "1K" }, { 1050, "1.05K" }, { 1234, "1.23K" },
		{ 10500, "10.5K" }, { 100000, "100K" }, { 999999, "999K" }, { 15000000, "15M" },
		{ 2500000000, "2.5B" }, { -1500, "-1.5K" }, { 12.7, "12" },
	}
	for _, c in cases do
		eq(Formulas.formatNumber(c[1]), c[2], "format de " .. tostring(c[1]))
	end
	eq(Formulas.formatNumber(0 / 0), "0", "NaN")
end)

test("progression vers le niveau suivant", function()
	local function prog(points)
		return Formulas.levelProgress({ StudsPainted = points, BubblesPopped = 0, CoinsEarned = 0 }, 200)
	end
	eq(prog(0), 0)
	near(prog(400), 0.5, 1e-9, "à mi-chemin du niveau 2") -- niveau 2 = 800 points
	eq(Formulas.level({ StudsPainted = 800, BubblesPopped = 0, CoinsEarned = 0 }, 200), 2)
	near(prog(800), 0, 1e-9)
	ok(prog(1799) < 1 and prog(1799) > 0.99)
end)
test("rythme : niveau 10 en ~30 min de jeu", function()
	-- environ 1 éclatement / s, 7 cases, 7 pièces : 7 + 2 + 0,7 = 9,7 points / s
	local seconds = 0
	local stats = { StudsPainted = 0, BubblesPopped = 0, CoinsEarned = 0 }
	while Formulas.level(stats, Config.LevelDivisor) < 10 do
		stats.StudsPainted += 7
		stats.BubblesPopped += 1
		stats.CoinsEarned += 7
		seconds += 1
	end
	ok(seconds > 25 * 60 and seconds < 40 * 60, "niveau 10 atteint en " .. math.floor(seconds / 60) .. " min")
end)
test("bonus des compagnons", function()
	local b = Formulas.companionBonus({ Coins = 0.05 }, 1, 1)
	near(b.Coins, 0.05, 1e-9)
	b = Formulas.companionBonus({ Coins = 0.08, AutoPop = 3 }, 2, 5)
	near(b.Coins, 0.8, 1e-9)
	eq(b.AutoPop, 3, "l'intervalle ne grossit pas")
	local total = Formulas.sumBonuses({ { Coins = 0.1 }, { Coins = 0.2, Radius = 0.3 }, { AutoPop = 3 } })
	near(total.Coins, 0.3, 1e-9)
	near(total.Radius, 0.3, 1e-9)
	eq(#total.AutoPops, 1)
end)
test("tirage des œufs conforme aux probabilités", function()
	local chances = {}
	for _, r in Config.Rarities do
		table.insert(chances, { r.Id, r.Chance })
	end
	eq(Formulas.pickWeighted(chances, 0), "Common")
	eq(Formulas.pickWeighted(chances, 0.9999999), "Mythic")
	local counts = {}
	math.randomseed(3)
	local N = 200000
	for _ = 1, N do
		local r = Formulas.pickWeighted(chances, math.random())
		counts[r] = (counts[r] or 0) + 1
	end
	for _, r in Config.Rarities do
		near(counts[r.Id] / N * 100, r.Chance, math.max(0.15, r.Chance * 0.05), "chance " .. r.Id)
	end
end)
test("horaires du Rainbow Storm (toutes les 1h30 depuis minuit UTC)", function()
	local day = 86400 * 20000
	local active, endsAt, nextStart = Formulas.storm(day, 5400, 600)
	ok(active, "minuit pile : storm")
	eq(endsAt, day + 600)
	eq(nextStart, day + 5400)
	active = Formulas.storm(day + 599, 5400, 600)
	ok(active)
	active, _, nextStart = Formulas.storm(day + 600, 5400, 600)
	ok(not active)
	eq(nextStart, day + 5400, "prochain à 1h30")
	active = Formulas.storm(day + 5400 + 10, 5400, 600)
	ok(active, "1h30 : storm")
	local count = 0
	for t = day, day + 86399, 60 do
		local a = Formulas.storm(t, 5400, 600)
		if a and not Formulas.storm(t - 60, 5400, 600) then
			count += 1
		end
	end
	eq(count, 16, "16 storms par jour")
end)
test("cadeau quotidien", function()
	local can, d = Formulas.daily(0, 0, 100, 7)
	ok(can)
	eq(d, 1, "premier cadeau")
	can, d = Formulas.daily(100, 1, 100, 7)
	ok(not can, "déjà pris aujourd'hui")
	can, d = Formulas.daily(100, 1, 101, 7)
	ok(can)
	eq(d, 2, "lendemain : jour 2")
	can, d = Formulas.daily(100, 5, 103, 7)
	eq(d, 1, "jour manqué : retour au jour 1")
	can, d = Formulas.daily(106, 7, 107, 7)
	eq(d, 1, "après le jour 7 : nouveau cycle")
	eq(Formulas.dayNumber(86400 * 3 + 5), 3)
end)
test("objectifs des quêtes et gains hors ligne", function()
	eq(Formulas.questTarget(40, 0, 0.08, 30), 40)
	eq(Formulas.questTarget(40, 10, 0.08, 30), 72)
	eq(Formulas.questTarget(40, 1000, 0.08, 30), Formulas.questTarget(40, 30, 0.08, 30), "plafonné")
	eq(Formulas.offlineCoins(0, 5, 7, 1, 1, 0.1, 7200), 0)
	eq(Formulas.offlineCoins(3600, 5, 7, 1, 1, 0.1, 7200), 504)
	eq(Formulas.offlineCoins(99999, 5, 7, 1, 1, 0.1, 7200), Formulas.offlineCoins(7200, 5, 7, 1, 1, 0.1, 7200), "2 h max")
	eq(Formulas.formatTime(125), "2:05")
	eq(Formulas.formatTime(3725), "1:02:05")
	eq(Formulas.formatTime(-5), "0:00")
end)
test("dates UTC des événements", function()
	eq(Formulas.utcEpoch(1970, 1, 1, 0), 0)
	eq(Formulas.utcEpoch(2000, 3, 1, 0), 951868800)
	eq(Formulas.utcEpoch(2026, 10, 24, 0), 1792800000)
	eq(Formulas.utcEpoch(2024, 2, 29, 12), 1709208000, "année bissextile")
	eq(Formulas.utcEpoch(2026, 12, 31, 23) + 3600, Formulas.utcEpoch(2027, 1, 1, 0), "passage d'année")
end)

---------------------------------------------------------------- Textes
lib.suite("Traductions")
test("les 5 langues ont tous les textes", function()
	for key in Locale.Strings.en do
		for _, lang in Locale.Languages do
			ok(Locale.Strings[lang][key], ("texte %s manquant en %s"):format(key, lang))
		end
	end
	for _, lang in Locale.Languages do
		for key in Locale.Strings[lang] do
			ok(Locale.Strings.en[key], ("texte %s en %s n'existe pas en anglais"):format(key, lang))
		end
	end
end)
test("les mêmes variables {x} dans chaque langue", function()
	for key, en in Locale.Strings.en do
		local vars = {}
		for v in string.gmatch(en, "{(%w+)}") do
			vars[v] = true
		end
		for _, lang in Locale.Languages do
			local t = Locale.Strings[lang][key]
			for v in string.gmatch(t, "{(%w+)}") do
				ok(vars[v], ("variable {%s} inconnue dans %s/%s"):format(v, lang, key))
			end
			for v in vars do
				ok(string.find(t, "{" .. v .. "}", 1, true), ("variable {%s} absente de %s/%s"):format(v, lang, key))
			end
		end
	end
end)
test("remplacement et langue inconnue", function()
	eq(Locale.get("fr", "ResetIn", { zone = "Candy Meadow", time = "0:27" }), "Candy Meadow se réinitialise dans 0:27")
	eq(Locale.get("xx", "Coins"), "Coins", "repli sur l'anglais")
	eq(Locale.get("de", "CleInconnue"), "CleInconnue")
	ok(Locale.isValid("it") and not Locale.isValid("pt") and not Locale.isValid(nil))
end)

---------------------------------------------------------------- Design system
lib.suite("Design system")
test("le design system est complet et utilisable", function()
	local D = Config.Design
	ok(D ~= nil, "Content/Design.luau chargé")
	eq(#D.Paints, 6, "six peintures")
	for _, paint in D.Paints do
		ok(type(paint.Id) == "string" and paint.Id ~= "", "chaque peinture a un identifiant")
		ok(D.Paint[paint.Id] ~= nil and D.Deep[paint.Id] ~= nil, paint.Id .. " : couleur et face deep")
		ok(paint.Color ~= paint.Deep, paint.Id .. " : la face deep doit être différente")
	end
	for _, name in D.ThemeOrder do
		local t = D.Themes[name]
		ok(t ~= nil, "thème " .. name)
		for _, key in { "Bg", "BgRaised", "BgSunken", "Ink", "InkMuted", "Edge" } do
			ok(t[key] ~= nil, "thème " .. name .. " : couleur " .. key)
		end
		-- le texte doit se détacher du fond (sinon illisible)
		local function lum(c)
			return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
		end
		ok(math.abs(lum(t.Ink) - lum(t.Bg)) > 0.4, "thème " .. name .. " : texte bien contrasté")
	end
	ok(D.Themes[D.DefaultTheme] ~= nil, "le thème par défaut existe")
	for _, font in { D.FontDisplay, D.FontText } do
		ok(roblox.Enum.Font[font] ~= nil, "police inconnue dans Roblox : " .. tostring(font))
	end
	for _, key in { "sm", "md", "lg", "pill" } do
		ok(type(D.Radius[key]) == "number", "arrondi " .. key)
	end
	for _, key in { "Tap", "Pop", "Float" } do
		ok(type(D.Duration[key]) == "number" and D.Duration[key] > 0, "durée " .. key)
	end
end)

---------------------------------------------------------------- Réglages
lib.suite("Réglages")
test("cohérence des réglages", function()
	ok(#Config.PaintPalette >= Config.BaseCount, "une couleur par joueur du serveur")
	ok(Config.ZoneResetMin < Config.ZoneResetMax)
	ok(Config.ZoneCountdown < Config.ZoneResetMin, "le compte à rebours doit être plus court que l'intervalle")
	ok(Config.BubbleMinDistance < Config.BubbleMaxDistance)
	ok(Config.LowBubbleMinHeight < Config.LowBubbleMaxHeight)
	ok(Config.HighBubbleMinHeight < Config.HighBubbleMaxHeight)
	ok(Config.LowBubbleMaxHeight - Config.BubbleSize / 2 < 3, "bulles basses à portée sans sauter")
	ok(Config.HighBubbleMaxHeight - Config.BubbleSize / 2 < 3 + 7.2, "bulles hautes atteignables en sautant")
	ok(Config.CascadeMin <= Config.CascadeMax)
	ok(Config.SessionLockExpire > Config.AutosaveInterval * 2, "le verrou doit survivre entre deux autosaves")
	ok(Config.LoadRetries * Config.LoadRetryDelay < 30, "chargement : pas plus de 30 s d'attente")
	ok(#Config.MainZones >= 5)
	eq(Config.MainZones[1].Cost, 0, "première zone gratuite")
	for i = 2, #Config.MainZones do
		ok(Config.MainZones[i].Cost > Config.MainZones[i - 1].Cost, "zones de plus en plus chères")
		ok(Config.MainZones[i].StudValue > Config.MainZones[i - 1].StudValue, "zones de plus en plus rentables")
	end
end)

---------------------------------------------------------------- Contenu (vérifie chaque mise à jour)
lib.suite("Contenu (Content/*.luau)")
local KNOWN_QUEST_TYPES = { PopBubbles = true, PaintStuds = true, EarnCoins = true, PopCascade = true, PopHigh = true,
	BuyUpgrades = true, OpenEggs = true, TrainSeconds = true }
local SHAPES = { Circle = true, Octagon = true, SCanyon = true, Star = true, Ring = true, Pumpkin = true, Diamond = true, Cross = true }
local CENTERPIECES = { GiantCandy = true, Lighthouse = true, GiantCrystal = true, FloatingIsland = true, JellyCubes = true, GiantPumpkin = true }
local THEMES = { Candy = true, Neon = true, Jelly = true, Crystal = true, Rainbow = true, Spooky = true }

local function unique(list, what)
	local seen = {}
	for _, item in list do
		ok(type(item.Id) == "string" and item.Id ~= "", what .. " sans Id")
		ok(not seen[item.Id], what .. " en double : " .. item.Id)
		seen[item.Id] = true
	end
end

test("Ids uniques partout", function()
	unique(Config.Zones, "zone")
	unique(Config.Quests, "quête")
	unique(Config.Events, "événement")
	unique(Config.Cosmetics, "cosmétique")
	local all = {}
	for id in Config.Companions do
		table.insert(all, { Id = id })
	end
	unique(all, "compagnon")
end)

test("zones : cases, ponts, formes, décors, événements", function()
	local cells = { ["0,0"] = "Hub" }
	local byId = {}
	for _, z in Config.Zones do
		byId[z.Id] = z
		local key = z.Cell[1] .. "," .. z.Cell[2]
		ok(not cells[key], z.Id .. " : case déjà prise par " .. tostring(cells[key]))
		cells[key] = z.Id
		ok(SHAPES[z.Shape], z.Id .. " : forme inconnue " .. tostring(z.Shape))
		ok(CENTERPIECES[z.Centerpiece], z.Id .. " : pièce centrale inconnue " .. tostring(z.Centerpiece))
		ok(THEMES[z.Theme], z.Id .. " : thème inconnu " .. tostring(z.Theme))
		ok(z.EggCost > 0 and z.EggPower > 0 and z.StudValue > 0, z.Id .. " : valeurs positives")
		if z.Event then
			ok(Config.event(z.Event), z.Id .. " : événement inconnu " .. z.Event)
			eq(z.Cost, 0, z.Id .. " : une zone d'événement est gratuite")
		end
	end
	for _, z in Config.Zones do
		local parent = if z.From == "Hub" then { 0, 0 } else (byId[z.From] and byId[z.From].Cell)
		ok(parent, z.Id .. " : From inconnu " .. tostring(z.From))
		local d = math.abs(parent[1] - z.Cell[1]) + math.abs(parent[2] - z.Cell[2])
		eq(d, 1, z.Id .. " : sa case doit toucher celle de " .. z.From)
	end
end)

test("événements : dates valides", function()
	for _, e in Config.Events do
		local s = Formulas.utcEpoch(e.Start[1], e.Start[2], e.Start[3], e.Start[4])
		local en = Formulas.utcEpoch(e.End[1], e.End[2], e.End[3], e.End[4])
		ok(en > s, e.Id .. " : la fin doit être après le début")
		ok(en - s <= 60 * 86400, e.Id .. " : 60 jours maximum")
		ok(type(e.Icon) == "string" and e.Icon ~= "", e.Id .. " : icône")
	end
end)

test("compagnons : apparences 3D valides et modèles constructibles", function()
	local Models = lib.loadModule("src/Shared/CompanionModels.luau")
	for _, row in lib.loadFile("src/Shared/Content/Companions.luau", lib.baseEnv()) do
		local look = row.Look
		if look then
			ok(look.Body == nil or table.find(Models.Bodies, look.Body), row.Id .. " : forme inconnue " .. tostring(look.Body))
			for _, x in look.Extras or {} do
				ok(Models.Extras[x] ~= nil, row.Id .. " : accessoire inconnu " .. tostring(x))
			end
		end
		for tier = 0, 2 do
			local m = Models.build(row, tier)
			ok(m.PrimaryPart ~= nil, row.Id .. " : pièce principale")
			local n, maxR = 0, 0
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					n += 1
					ok(d.Anchored and not d.CanCollide and not d.CanTouch, row.Id .. " : pièce sans collision")
					maxR = math.max(maxR, d.CFrame.Position.Magnitude)
				end
			end
			ok(n >= 12, row.Id .. " : assez détaillé (" .. n .. " pièces)")
			ok(maxR < 4.5, row.Id .. " : taille raisonnable")
		end
	end
end)

test("quêtes : types connus, zones et événements existants", function()
	for _, q in Config.Quests do
		ok(KNOWN_QUEST_TYPES[q.Type], q.Id .. " : type inconnu " .. tostring(q.Type))
		ok(q.Target > 0 and q.Reward > 0, q.Id .. " : objectif et récompense")
		if q.Zone then
			ok(Config.zone(q.Zone), q.Id .. " : zone inconnue " .. q.Zone)
			ok(q.Type == "PopBubbles" or q.Type == "PaintStuds", q.Id .. " : Zone ne marche qu'avec PopBubbles / PaintStuds")
		end
		if q.Event then
			ok(Config.event(q.Event), q.Id .. " : événement inconnu " .. q.Event)
		end
	end
	local normal = 0
	for _, q in Config.Quests do
		if not q.Event then
			normal += 1
		end
	end
	ok(normal > Config.QuestCount, "assez de quêtes hors événement")
end)

test("cosmétiques : prix et couleurs", function()
	for _, c in Config.Cosmetics do
		ok(c.Cost > 0, c.Id .. " : prix")
		ok(#c.Colors >= 1, c.Id .. " : au moins une couleur")
		ok(type(c.Name) == "string" and c.Name ~= "", c.Id .. " : nom")
		if c.Event then
			ok(Config.event(c.Event), c.Id .. " : événement inconnu " .. c.Event)
		end
	end
end)
test("compagnons et œufs", function()
	local total = 0
	for _, r in Config.Rarities do
		total += r.Chance
		ok(Config.RarityBonus[r.Id], "bonus défini pour " .. r.Id)
	end
	near(total, 100, 1e-9, "les chances font 100 %")
	for _, z in Config.Zones do
		local contents = Config.EggContents[z.Id]
		ok(contents and #contents == 5, "œuf de " .. z.Id .. " : 5 compagnons")
		local rarities = {}
		for _, id in contents do
			rarities[Config.Companions[id].Rarity] = true
		end
		for _, r in Config.Rarities do
			ok(rarities[r.Id], z.Id .. " a un " .. r.Id)
		end
	end
	ok(Config.Companions.Starbub, "compagnon exclusif du jour 7")
end)
test("améliorations, quêtes, cadeaux, didacticiel", function()
	local ids = {}
	for _, u in Config.Upgrades do
		ok(not ids[u.Id], "id unique " .. u.Id)
		ids[u.Id] = true
		ok(u.MaxLevel > 0 and u.BaseCost > 0)
	end
	local E = Config.UpgradeEffects
	ok(E.spawnInterval(10) < E.spawnInterval(0), "plus de bulles")
	ok(E.paintRadius(10) > E.paintRadius(0))
	ok(E.valueMultiplier(10) > E.valueMultiplier(0))
	ok(E.cascadeChance(20) <= 0.6)
	ok(E.walkSpeed(14) <= 30, "vitesse raisonnable")
	ok(E.afkInterval(15) >= 1, "AFK jamais plus rapide qu'une bulle par seconde")
	ok(E.contactRadius(15) < 15, "aimant raisonnable")
	local qids = {}
	for _, q in Config.Quests do
		ok(not qids[q.Id], "quête unique " .. q.Id)
		qids[q.Id] = true
	end
	ok(#Config.Quests > Config.QuestCount, "assez de quêtes différentes")
	eq(#Config.Daily, 7)
	eq(Config.Daily[7].Kind, "Companion")
	eq(Config.TutorialSteps[#Config.TutorialSteps], "Done")
end)
test("chaque texte utilisé par les réglages existe dans les 5 langues", function()
	local keys = {}
	for _, u in Config.Upgrades do
		table.insert(keys, u.NameKey)
		table.insert(keys, u.DescKey)
	end
	for _, z in Config.Zones do
		table.insert(keys, z.DisplayKey)
	end
	for _, e in Config.Events do
		table.insert(keys, e.NameKey)
	end
	for _, q in Config.Quests do
		table.insert(keys, q.TextKey)
	end
	for _, r in Config.Rarities do
		table.insert(keys, "R_" .. r.Id)
	end
	for _, k in { "Tier_1", "Tier_2", "D_Coins", "D_Boost", "D_Egg", "D_Companion" } do
		table.insert(keys, k)
	end
	for _, step in Config.TutorialSteps do
		table.insert(keys, "T_" .. step)
	end
	for _, k in keys do
		for _, lang in Locale.Languages do
			ok(Locale.Strings[lang][k], ("texte %s manquant en %s"):format(k, lang))
		end
	end
end)

---------------------------------------------------------------- Grille
lib.suite("Grille de peinture")
local grid = PaintGrid.new(-80, -261, 4, 40, 40)
test("case sous un point", function()
	local i, j = PaintGrid.tileAt(grid, -80, -261)
	eq(i, 1)
	eq(j, 1)
	i, j = PaintGrid.tileAt(grid, -80 + 159.9, -261 + 159.9)
	eq(i, 40)
	eq(j, 40)
	i, j = PaintGrid.tileAt(grid, -81, 0)
	eq(i, nil, "hors zone")
	local cx, cz = PaintGrid.tileCenter(grid, 1, 1)
	eq(cx, -78)
	eq(cz, -259)
end)
test("cercle de peinture", function()
	local tiles = PaintGrid.tilesInRadius(grid, 0, -181, 6)
	ok(#tiles >= 4 and #tiles <= 12, "entre 4 et 12 cases pour un rayon de 6, obtenu " .. #tiles)
	-- en moyenne, aire du cercle / aire d'une case = 113 / 16 ≈ 7 cases
	local total, n = 0, 0
	local rng = Random and nil
	math.randomseed(7)
	for _ = 1, 2000 do
		local x, z = -60 + math.random() * 120, -240 + math.random() * 120
		total += #PaintGrid.tilesInRadius(grid, x, z, 6)
		n += 1
	end
	near(total / n, 7.07, 0.4, "moyenne de cases par éclatement")
	local _ = rng
	for _, t in tiles do
		local cx, cz = PaintGrid.tileCenter(grid, t[1], t[2])
		ok((cx - 0) ^ 2 + (cz + 181) ^ 2 <= 36 + 1e-9)
	end
	eq(#PaintGrid.tilesInRadius(grid, 0, -181, 0.1), 1, "un tout petit rayon peint au moins une case")
	eq(#PaintGrid.tilesInRadius(grid, 500, 500, 6), 0, "loin de la zone : rien")
	local corner = PaintGrid.tilesInRadius(grid, -80, -261, 6)
	for _, t in corner do
		ok(t[1] >= 1 and t[2] >= 1, "jamais de case en dehors de la grille")
	end
end)
test("clés uniques pour les 1600 cases", function()
	local seen = {}
	local n = 0
	for i = 1, 40 do
		for j = 1, 40 do
			local k = PaintGrid.key(grid, i, j)
			ok(not seen[k], "clé en double")
			seen[k] = true
			n += 1
		end
	end
	eq(n, 1600)
end)

---------------------------------------------------------------- Sauvegarde
lib.suite("Sauvegarde (faux DataStore)")

-- Faux DataStore : copie les valeurs comme Roblox (sérialisation), peut simuler des pannes.
local function deep(v)
	if type(v) ~= "table" then
		return v
	end
	local o = {}
	for k, x in v do
		o[k] = deep(x)
	end
	return o
end
local function makeStore()
	local store = { data = {}, failNext = 0, calls = 0 }
	function store:UpdateAsync(key, fn)
		self.calls += 1
		if self.failNext > 0 then
			self.failNext -= 1
			error("DataStore indisponible (simulé)")
		end
		local new = fn(deep(self.data[key]))
		if new ~= nil then
			self.data[key] = deep(new)
		end
		return new
	end
	return store
end

local TEMPLATE = {
	Coins = 0,
	Stats = { StudsPainted = 0, BubblesPopped = 0, CoinsEarned = 0 },
	Zones = { CandyMeadow = true },
	Companions = {},
	Settings = { Language = "en", Shake = true },
}

local clock = 1000
local function newPS(store, jobId)
	return ProfileStore.new({
		store = store,
		jobId = jobId,
		now = function()
			return clock
		end,
		wait = function(t)
			clock += t
		end,
		template = TEMPLATE,
		lockExpire = 360,
		retries = 6,
		retryDelay = 4,
	})
end

test("nouveau joueur : modèle + verrou", function()
	local store = makeStore()
	local ps = newPS(store, "A")
	local res, p = ps:load("Player_1")
	eq(res, "ok")
	eq(p.Data.Coins, 0)
	eq(store.data.Player_1.Lock.JobId, "A")
	p.Data.Coins = 50
	eq(store.data.Player_1.Data.Coins, 0, "les données en mémoire ne touchent pas le store avant une sauvegarde")
end)

test("sauvegarde, libération, rechargement ailleurs", function()
	local store = makeStore()
	local a = newPS(store, "A")
	local _, p = a:load("Player_1")
	p.Data.Coins = 123
	table.insert(p.Data.Companions, { Id = "Blub", Gold = false })
	ok(a:save(p, false))
	eq(store.data.Player_1.Data.Coins, 123)
	eq(store.data.Player_1.Lock.JobId, "A", "autosave garde le verrou")
	p.Data.Coins = 124
	eq(store.data.Player_1.Data.Coins, 123, "la sauvegarde est une copie, pas une référence")
	ok(a:save(p, true))
	eq(store.data.Player_1.Lock, nil, "verrou libéré au départ")
	ok(not p.Active)
	ok(not a:save(p, false), "plus d'écriture après libération")
	local b = newPS(store, "B")
	local res, p2 = b:load("Player_1")
	eq(res, "ok")
	eq(p2.Data.Coins, 124)
	eq(#p2.Data.Companions, 1)
	eq(p2.Data.Companions[1].Id, "Blub")
end)

test("verrou récent ailleurs : refus sans écraser", function()
	local store = makeStore()
	local a = newPS(store, "A")
	local _, p = a:load("Player_2")
	p.Data.Coins = 77
	a:save(p, false)
	local b = newPS(store, "B")
	local before = clock
	local res, p2 = b:load("Player_2")
	eq(res, "locked")
	eq(p2, nil)
	eq(store.data.Player_2.Lock.JobId, "A")
	eq(store.data.Player_2.Data.Coins, 77)
	ok(clock - before <= 30, "attente raisonnable avant d'abandonner")
end)

test("le verrou se libère pendant les essais", function()
	local store = makeStore()
	local a = newPS(store, "A")
	local _, p = a:load("Player_3")
	p.Data.Coins = 5
	local b = newPS(store, "B")
	local released = false
	local origWait
	-- A libère pendant que B attend
	b._opts.wait = function(t)
		clock += t
		if not released then
			released = true
			a:save(p, true)
		end
	end
	local res, p2 = b:load("Player_3")
	eq(res, "ok")
	eq(p2.Data.Coins, 5)
	eq(store.data.Player_3.Lock.JobId, "B")
	local _ = origWait
end)

test("verrou périmé (serveur planté) : repris", function()
	local store = makeStore()
	store.data.Player_4 = { Data = { Coins = 9 }, Lock = { JobId = "Dead", Time = clock - 1000 } }
	local b = newPS(store, "B")
	local res, p = b:load("Player_4")
	eq(res, "ok")
	eq(p.Data.Coins, 9)
	eq(p.Data.Stats.StudsPainted, 0, "les nouvelles clés sont ajoutées")
	eq(store.data.Player_4.Lock.JobId, "B")
end)

test("un autre serveur a volé le verrou : on n'écrase plus", function()
	local store = makeStore()
	local a = newPS(store, "A")
	local _, p = a:load("Player_5")
	p.Data.Coins = 10
	-- B reprend (verrou périmé)
	clock += 1000
	local b = newPS(store, "B")
	local _, pb = b:load("Player_5")
	pb.Data.Coins = 500
	b:save(pb, false)
	-- A tente sa sauvegarde
	ok(not a:save(p, false))
	ok(p.Lost, "A sait qu'il a perdu le profil")
	eq(store.data.Player_5.Data.Coins, 500, "les données de B sont intactes")
end)

test("pannes passagères du DataStore", function()
	local store = makeStore()
	store.failNext = 3
	local a = newPS(store, "A")
	local res, p = a:load("Player_6")
	eq(res, "ok")
	ok(p ~= nil)
	store.failNext = 1
	p.Data.Coins = 3
	ok(a:save(p, true), "la sauvegarde de départ réessaie")
	eq(store.data.Player_6.Data.Coins, 3)
end)

test("DataStore en panne totale : erreur propre", function()
	local store = makeStore()
	store.failNext = 99
	local a = newPS(store, "A")
	local res, p = a:load("Player_7")
	eq(res, "error")
	eq(p, nil)
end)

test("données corrompues ou anciennes réparées", function()
	local store = makeStore()
	store.data.Player_8 = { Data = { Coins = "beaucoup", Stats = { StudsPainted = 4 }, Companions = { { Id = "X" } } } }
	local a = newPS(store, "A")
	local _, p = a:load("Player_8")
	eq(p.Data.Coins, 0, "type invalide remis à zéro")
	eq(p.Data.Stats.StudsPainted, 4, "valeur existante gardée")
	eq(p.Data.Stats.BubblesPopped, 0, "clé manquante ajoutée")
	eq(#p.Data.Companions, 1, "liste du joueur conservée")
	eq(p.Data.Settings.Language, "en")
end)

test("mode mémoire (Studio sans accès API)", function()
	local ps = ProfileStore.new({
		store = nil, jobId = "S", now = function() return clock end, wait = function() end,
		template = TEMPLATE, lockExpire = 360, retries = 1, retryDelay = 0,
	})
	ok(ps:isMemoryMode())
	local res, p = ps:load("Player_9")
	eq(res, "ok")
	p.Data.Coins = 42
	ok(ps:save(p, true))
	local _, p2 = ps:load("Player_9")
	eq(p2.Data.Coins, 42)
end)

local _ = roblox
return lib
