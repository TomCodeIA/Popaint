-- Tests d'intégration : les vrais scripts serveur du fichier de jeu, dans un serveur simulé.
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local lib = require("./lib")
local sim = require("./sim")
local test, eq, ok = lib.test, lib.eq, lib.ok

local Config = lib.loadModule("src/Shared/Config.luau")
local V3 = roblox.Vector3
local CF = roblox.CFrame
local HUB_SPAWN = V3.new(0, 3, 24)
local CANDY = V3.new(0, 3, -256) -- dans le rond de Candy Meadow (le centre est le bonbon géant)

local S

local function noScriptErrors()
	ok(#S.errors == 0, "erreurs de script : " .. table.concat(S.errors, "\n"))
	-- tout avertissement est une erreur, sauf ceux prévus par les tests (sauvegarde simulée en panne...)
	local expectedWarnings = { "Sauvegarde désactivée", "verrouillé ailleurs", "échec du chargement", "autosave ratée",
		"échec de sauvegarde", "verrou pris" }
	for _, w in S.warnings do
		local known = false
		for _, k in expectedWarnings do
			if string.find(w, k, 1, true) then
				known = true
			end
		end
		ok(known, "avertissement inattendu : " .. w)
	end
end

local function paletteIndexOf(color)
	for i, c in Config.PaintPalette do
		if math.abs(c.R - color.R) < 1e-3 and math.abs(c.G - color.G) < 1e-3 and math.abs(c.B - color.B) < 1e-3 then
			return i
		end
	end
	return nil
end

local function coins(p)
	-- les données serveur font foi (l'attribut est arrondi par Lune au-delà de 16 millions)
	local profile = sim.module("DataService").get(p)
	if profile then
		return profile.Data.Coins
	end
	return p:GetAttribute("Coins")
end

local function data(p)
	return sim.module("DataService").get(p).Data
end

local function giveCoins(p, n)
	sim.module("DataService").addCoins(p, n)
end

-- Le personnage va toucher chacune de ses bulles (le serveur détecte le contact)
local function touchAll(p, root)
	local touched = 0
	for _, b in sim.liveBubbles(p.UserId) do
		root.CFrame = CF.new(b.position)
		sim.advance(0.1)
		touched += 1
	end
	return touched
end

local function popsSince(userId, since, how)
	local out = {}
	for _, e in sim.events("BubblePopped", since) do
		if e.args[1] == userId and (how == nil or (how == "touch") == (e.args[7] == false)) then
			table.insert(out, e.args)
		end
	end
	return out
end

local function machineOf(p)
	local base = S.game.Workspace.Map.Hub.Bases:FindFirstChild(p:GetAttribute("BaseName"))
	return base.MachineBody.CFrame.Position
end

local function effectNames(userId, since)
	local names = {}
	for _, args in sim.clientEvents("Effect", userId, since) do
		names[args[1]] = (names[args[1]] or 0) + 1
	end
	return names
end

---------------------------------------------------------------- 1. démarrage
lib.suite("Serveur simulé : démarrage")
S = sim.start()
test("le serveur démarre sans erreur, 5 zones prêtes", function()
	noScriptErrors()
	for _, z in Config.Zones do
		local zone = sim.zone(z.Id)
		ok(zone, "zone " .. z.Id)
		ok(type(zone:GetAttribute("ResetAt")) == "number", "réinitialisation programmée " .. z.Id)
	end
	ok(S.game.Workspace:GetAttribute("StormActive") == false, "pas de storm au départ (heure choisie)")
	ok(type(S.game.Workspace:GetAttribute("NextStormAt")) == "number")
	sim.advance(3)
	ok((S.terrainCalls.FillBall or 0) >= 40, "collines de terrain sculptées : " .. tostring(S.terrainCalls.FillBall))
	local terrain = S.game.Workspace:FindFirstChildOfClass("Terrain")
	local grass = terrain:GetMaterialColor(roblox.Enum.Material.Grass)
	ok(grass.R > 0.9 and grass.G < 0.8, "herbe rose bonbon autour de Candy Meadow")
end)

---------------------------------------------------------------- 2. arrivée et didacticiel
lib.suite("Serveur simulé : arrivée et didacticiel")
local tom, tomRoot = sim.join(101, "Tom", HUB_SPAWN)
sim.advance(2)
test("données, base, quêtes et état envoyé au joueur", function()
	noScriptErrors()
	eq(coins(tom), 0)
	eq(tom:GetAttribute("BaseName"), "Base01")
	eq(tom.leaderstats.Level.Value, 1)
	local st = sim.lastState(101)
	ok(st, "état envoyé")
	eq(#st.Quests, 3, "3 quêtes")
	eq(st.Tutorial.Step, "GoToZone")
	eq(st.Zones.CandyMeadow, true)
	ok(not st.Zones.NeonDocks)
	eq(st.Upgrades.Production.Level, 0)
	eq(st.Upgrades.Production.Cost, 25)
	eq(st.Daily.CanClaim, true)
	eq(st.Daily.Day, 1)
end)

test("pas de bulles dans le hub ; entrer dans la zone fait avancer le didacticiel", function()
	local before = sim.logSize()
	sim.advance(5)
	eq(#sim.events("BubbleSpawned", before), 0)
	tomRoot.CFrame = CF.new(CANDY)
	sim.advance(2)
	eq(tom:GetAttribute("TutorialStep"), "PopBubbles")
end)

test("les bulles apparaissent à hauteur de course (et quelques hautes)", function()
	local before = sim.logSize()
	sim.advance(12)
	local spawned = sim.events("BubbleSpawned", before)
	ok(#spawned >= 5, "des bulles apparaissent : " .. #spawned)
	local ZS = sim.module("ZoneService")
	local zone = ZS.get("CandyMeadow")
	for _, e in spawned do
		ok(ZS.hasTile(zone, e.args[3].X, e.args[3].Z), "bulle au-dessus du sol (pas dans le vide ni dans le bonbon)")
		local ground = ZS.heightAt(zone, e.args[3].X, e.args[3].Z)
		local y, kind = e.args[3].Y - ground, e.args[6]
		if kind == "high" then
			ok(y >= Config.HighBubbleMinHeight - 0.01 and y <= Config.HighBubbleMaxHeight + 0.01, "hauteur bulle haute")
		else
			ok(y >= Config.LowBubbleMinHeight - 0.01 and y <= Config.LowBubbleMaxHeight + 0.01, "hauteur bulle basse " .. y)
		end
	end
end)

test("toucher une bulle avec le corps l'éclate, peint et paie", function()
	local before = sim.logSize()
	local coinsBefore = coins(tom)
	touchAll(tom, tomRoot)
	local pops = popsSince(101, before, "touch")
	ok(#pops >= 3, "éclatements au contact : " .. #pops)
	local total = 0
	for _, a in pops do
		total += a[6]
	end
	ok(coins(tom) >= coinsBefore + total, "pièces créditées")
	local colored = 0
	for _, t in sim.zone().Tiles:GetChildren() do
		if paletteIndexOf(t.Color) == tom:GetAttribute("PaintColor") then
			colored += 1
		end
	end
	ok(colored > 0, "le sol est peint")
	noScriptErrors()
end)

test("5 bulles touchées : le didacticiel passe à la machine", function()
	for _ = 1, 6 do
		if tom:GetAttribute("TutorialStep") ~= "PopBubbles" then
			break
		end
		sim.advance(5)
		touchAll(tom, tomRoot)
	end
	eq(tom:GetAttribute("TutorialStep"), "OpenShop")
end)

test("une bulle annoncée par le client n'est acceptée que si on est assez près", function()
	sim.advance(6)
	tomRoot.CFrame = CF.new(CANDY + V3.new(0, 0, 60))
	local live = sim.liveBubbles(101)
	local far
	for id, b in live do
		if (b.position - tomRoot.CFrame.Position).Magnitude > 30 then
			far = id
		end
	end
	if far then
		local before = sim.logSize()
		sim.clientFire(tom, "PopBubble", far)
		sim.advance(0.05, 0.05)
		for _, a in popsSince(101, before, "touch") do
			ok(a[2] ~= far, "bulle lointaine refusée")
		end
	end
	-- près : accepté
	tomRoot.CFrame = CF.new(CANDY)
	sim.advance(4)
	local id, b = next(sim.liveBubbles(101))
	if id then
		tomRoot.CFrame = CF.new(b.position + V3.new(5, 0, 0))
		local before = sim.logSize()
		sim.clientFire(tom, "PopBubble", id)
		sim.advance(0.05, 0.05)
		local found = false
		for _, a in popsSince(101, before) do
			if a[2] == id then
				found = true
			end
		end
		ok(found, "contact annoncé par le client accepté")
	end
	sim.clientFire(tom, "PopBubble", "abc")
	sim.clientFire(tom, "PopBubble", 0 / 0)
	sim.advance(0.1)
	noScriptErrors()
end)

test("les bulles hautes rapportent x2", function()
	local checked = 0
	for _ = 1, 12 do
		local before = sim.logSize()
		sim.advance(6)
		touchAll(tom, tomRoot)
		for _, a in popsSince(101, before, "touch") do
			if a[8] == "high" and a[5] > 0 then
				local z = sim.zone()
				local countdown = z:GetAttribute("ResetAt") - sim.now() <= Config.ZoneCountdown
				local expected = a[5] * 2 * (if countdown then 2 else 1)
				ok(math.abs(a[6] - expected) <= 1, ("x2 attendu : %d tuiles -> %d pièces"):format(a[5], a[6]))
				checked += 1
			end
		end
		if checked > 0 then
			break
		end
	end
	ok(checked > 0, "au moins une bulle haute vérifiée")
end)

---------------------------------------------------------------- 3. boutique et améliorations
lib.suite("Serveur simulé : boutique")
test("acheter loin de sa machine est refusé", function()
	giveCoins(tom, 1000)
	local before = sim.logSize()
	sim.clientFire(tom, "Action", "BuyUpgrade", "Production")
	sim.advance(0.1)
	eq(data(tom).Upgrades.Production, nil)
	local notes = sim.clientEvents("Notify", 101, before)
	ok(#notes >= 1 and notes[1][1] == "MachineTooFar", "message clair")
end)

test("à sa machine : achat, prix qui monte, didacticiel", function()
	tomRoot.CFrame = CF.new(machineOf(tom) + V3.new(0, 0, 6))
	sim.clientFire(tom, "Action", "OpenedShop")
	local c0 = coins(tom)
	sim.clientFire(tom, "Action", "BuyUpgrade", "Production")
	sim.advance(0.3)
	eq(data(tom).Upgrades.Production, 1)
	eq(coins(tom), c0 - 25)
	eq(tom:GetAttribute("TutorialStep"), "OpenEgg")
	local st = sim.lastState(101)
	eq(st.Upgrades.Production.Level, 1)
	eq(st.Upgrades.Production.Cost, 29)
	-- triche : amélioration inconnue, mauvais type
	sim.clientFire(tom, "Action", "BuyUpgrade", "Infinite")
	sim.clientFire(tom, "Action", "BuyUpgrade", 42)
	sim.advance(0.1)
	noScriptErrors()
end)

test("pas assez de pièces : refus sans rien perdre", function()
	local d = data(tom)
	d.Coins = 10
	tom:SetAttribute("Coins", 10)
	sim.clientFire(tom, "Action", "BuyUpgrade", "Magnet")
	sim.advance(0.1)
	eq(d.Upgrades.Magnet, nil)
	eq(d.Coins, 10)
end)

test("aimant : la portée de contact augmente", function()
	giveCoins(tom, 1000)
	local r0 = sim.lastState(101).ContactRadius
	sim.clientFire(tom, "Action", "BuyUpgrade", "Magnet")
	sim.advance(0.5)
	ok(sim.lastState(101).ContactRadius > r0, "portée plus grande")
end)

test("niveau max respecté", function()
	local d = data(tom)
	d.Upgrades.Speed = Config.upgrade("Speed").MaxLevel
	giveCoins(tom, 1000000)
	local c0 = coins(tom)
	sim.clientFire(tom, "Action", "BuyUpgrade", "Speed")
	sim.advance(0.1)
	eq(d.Upgrades.Speed, Config.upgrade("Speed").MaxLevel)
	eq(coins(tom), c0)
end)

---------------------------------------------------------------- 3b. tapis de course
lib.suite("Serveur simulé : tapis de course")
local function beltOf(p)
	local base = S.game.Workspace.Map.Hub.Bases:FindFirstChild(p:GetAttribute("BaseName"))
	return base.Treadmill.Belt
end
test("courir sur son tapis donne des points chaque seconde", function()
	local d = data(tom)
	local p0 = d.Stats.TrainPoints
	tomRoot.CFrame = beltOf(tom).CFrame * CF.new(0, 3, 0)
	local before = sim.logSize()
	sim.advance(3.05)
	eq(tom:GetAttribute("Training"), true)
	local gained = d.Stats.TrainPoints - p0
	ok(gained >= 200 and gained <= 400, "points gagnés en 3 s au niveau 0 : " .. gained)
	local trains = 0
	for _, a in sim.clientEvents("Effect", 101, before) do
		if a[1] == "Train" then
			trains += 1
			eq(a[2].Points, 100)
		end
	end
	ok(trains >= 2, "+100 affiché chaque seconde")
	ok(sim.lastState(101).TrainPoints >= gained, "état envoyé")
end)

test("la vitesse augmente avec l'entraînement, plafonnée", function()
	local US = sim.module("UpgradeService")
	local d = data(tom)
	local s0 = US.walkSpeed(tom)
	d.Stats.TrainPoints = 2000 * 25 -- racine(25) = 5
	ok(US.walkSpeed(tom) >= s0 + 4, "plus rapide")
	d.Stats.TrainPoints = 1e12
	eq(US.walkSpeed(tom) - Config.UpgradeEffects.walkSpeed(US.level(tom, "Speed")), Config.TrainSpeedCap, "plafond")
	d.Stats.TrainPoints = 0
end)

test("améliorer le tapis : plus de points, nouvelle apparence", function()
	local d = data(tom)
	giveCoins(tom, 5000)
	tomRoot.CFrame = CF.new(machineOf(tom) + V3.new(0, 0, 6))
	sim.clientFire(tom, "Action", "BuyUpgrade", "Treadmill")
	sim.advance(0.3)
	eq(d.Upgrades.Treadmill, 1)
	local tm = beltOf(tom).Parent
	eq(tm:GetAttribute("Level"), 1)
	eq(sim.lastState(101).Upgrades.Treadmill.Cost, math.floor(200 * 2.2 + 0.5))
	tomRoot.CFrame = beltOf(tom).CFrame * CF.new(0, 3, 0)
	local before = sim.logSize()
	sim.advance(2.05)
	for _, a in sim.clientEvents("Effect", 101, before) do
		if a[1] == "Train" then
			eq(a[2].Points, Config.TreadmillRates[2], "niveau 1 : +200")
		end
	end
end)

test("le tapis d'un autre joueur ne rapporte rien", function()
	local base2 = S.game.Workspace.Map.Hub.Bases.Base02
	tomRoot.CFrame = base2.Treadmill.Belt.CFrame * CF.new(0, 3, 0)
	sim.advance(1.1)
	local p0 = data(tom).Stats.TrainPoints
	sim.advance(2)
	eq(data(tom).Stats.TrainPoints, p0)
	eq(tom:GetAttribute("Training"), false)
	tomRoot.CFrame = CF.new(CANDY)
	sim.advance(0.5)
	noScriptErrors()
end)

---------------------------------------------------------------- 4. œufs et compagnons
lib.suite("Serveur simulé : œufs et compagnons")
local candyEgg = S.game.Workspace.Map.Eggs.CandyMeadow:FindFirstChildWhichIsA("ProximityPrompt", true)
-- Tom retourne au hub et attend que ses bulles disparaissent (sinon la machine AFK lui rapporte des pièces)
tomRoot.CFrame = CF.new(HUB_SPAWN)
sim.advance(Config.BubbleLifetime + 2, 0.5)

test("didacticiel : premier œuf gratuit, compagnon équipé, récompense", function()
	local d = data(tom)
	local c0 = coins(tom)
	local before = sim.logSize()
	sim.prompt(tom, candyEgg)
	sim.advance(0.5)
	eq(#d.Companions, 1)
	eq(#d.Equipped, 1, "équipé automatiquement")
	ok(string.find(tom:GetAttribute("Pets"), ":0", 1, true), "affiché pour les autres joueurs")
	eq(tom:GetAttribute("TutorialStep"), "Done")
	-- gratuit : le prix de l'œuf n'a pas été retiré (d'autres gains peuvent s'ajouter en parallèle)
	ok(coins(tom) >= c0 + Config.TutorialReward, "œuf gratuit + récompense de fin")
	local fx = effectNames(101, before)
	ok(fx.Hatched == 1 and fx.TutorialDone == 1, "animations envoyées")
end)

test("œuf payant ; refus sans pièces", function()
	local d = data(tom)
	d.Coins = 0
	tom:SetAttribute("Coins", 0)
	sim.prompt(tom, candyEgg)
	sim.advance(0.2)
	eq(#d.Companions, 1, "pas d'œuf sans pièces")
	giveCoins(tom, 1000)
	local before = coins(tom)
	sim.prompt(tom, candyEgg)
	sim.advance(0.2)
	eq(#d.Companions, 2)
	eq(before - coins(tom), 150, "prix de l'œuf retiré")
end)

test("œuf d'une zone verrouillée refusé", function()
	giveCoins(tom, 100000)
	local n = #data(tom).Companions
	sim.prompt(tom, S.game.Workspace.Map.Eggs.NeonDocks:FindFirstChildWhichIsA("ProximityPrompt", true))
	sim.advance(0.2)
	eq(#data(tom).Companions, n)
end)

test("fusion de 3 identiques -> Doré, puis bonus plus fort", function()
	local CS = sim.module("CompanionService")
	local d = data(tom)
	table.clear(d.Companions)
	table.clear(d.Equipped)
	for _ = 1, 3 do
		CS.give(tom, "Gumdrop", 0)
	end
	local base = CS.bonuses(tom).Coins
	local uid = d.Companions[1].Uid
	sim.clientFire(tom, "Action", "Fuse", uid)
	sim.advance(0.2)
	eq(#d.Companions, 1)
	eq(d.Companions[1].Tier, 1)
	eq(#d.Equipped, 1, "le doré est équipé")
	local golden = CS.bonuses(tom).Coins
	ok(golden > base / 3 * 1.5, "bonus du doré > bonus normal")
	-- fusion impossible avec un seul
	sim.clientFire(tom, "Action", "Fuse", d.Companions[1].Uid)
	sim.advance(0.1)
	eq(#d.Companions, 1)
	noScriptErrors()
end)

test("équiper, retirer, supprimer, limite de 3", function()
	local CS = sim.module("CompanionService")
	local d = data(tom)
	for _ = 1, 4 do
		CS.give(tom, "Lolli", 0)
	end
	ok(#d.Equipped <= Config.MaxEquipped, "jamais plus de 3 équipés")
	local last = d.Companions[#d.Companions].Uid
	sim.clientFire(tom, "Action", "Equip", last)
	sim.advance(0.1)
	ok(table.find(d.Equipped, last), "équipé")
	eq(#d.Equipped, Config.MaxEquipped)
	sim.clientFire(tom, "Action", "Unequip", last)
	sim.advance(0.1)
	ok(not table.find(d.Equipped, last))
	sim.clientFire(tom, "Action", "DeletePet", last)
	sim.advance(0.1)
	for _, c in d.Companions do
		ok(c.Uid ~= last, "supprimé")
	end
	sim.clientFire(tom, "Action", "Equip", 99999)
	sim.clientFire(tom, "Action", "Equip", "x")
	sim.advance(0.1)
	noScriptErrors()
end)

test("un compagnon mythique augmente les gains", function()
	local CS = sim.module("CompanionService")
	local BS = sim.module("BubbleService")
	local m0 = BS.coinMultiplier(tom)
	local c = CS.give(tom, "Sugarcorn", 0)
	sim.clientFire(tom, "Action", "Equip", c.Uid)
	sim.advance(0.1)
	ok(BS.coinMultiplier(tom) > m0 * 1.2, "multiplicateur plus grand")
end)

test("inventaire plein", function()
	local CS = sim.module("CompanionService")
	local d = data(tom)
	while #d.Companions < Config.InventorySize do
		CS.give(tom, "Gumdrop", 0)
	end
	local before = sim.logSize()
	ok(CS.give(tom, "Gumdrop", 0) == nil, "refusé")
	local notes = sim.clientEvents("Notify", 101, before)
	eq(notes[1][1], "InventoryFull")
	-- on fait de la place
	while #d.Companions > 5 do
		local c = d.Companions[#d.Companions]
		CS.delete(tom, c.Uid)
	end
end)

---------------------------------------------------------------- 5. zones
lib.suite("Serveur simulé : zones")
local gates = S.game.Workspace.Map.Gates
test("débloquer Neon Docks au portail", function()
	local d = data(tom)
	d.Coins = 100
	tom:SetAttribute("Coins", 100)
	local prompt = gates.NeonDocks:FindFirstChildWhichIsA("ProximityPrompt", true)
	sim.prompt(tom, prompt)
	sim.advance(0.1)
	ok(not d.Zones.NeonDocks, "pas assez de pièces")
	giveCoins(tom, 5000)
	local c0 = coins(tom)
	sim.prompt(tom, prompt)
	sim.advance(0.1)
	eq(d.Zones.NeonDocks, true)
	eq(coins(tom), c0 - 5000)
end)

test("les zones se débloquent dans l'ordre", function()
	giveCoins(tom, 50000000)
	sim.prompt(tom, gates.RainbowCore:FindFirstChildWhichIsA("ProximityPrompt", true))
	sim.advance(0.1)
	ok(not data(tom).Zones.RainbowCore, "Rainbow Core avant Jelly Canyon refusé")
end)

test("entrer dans une zone verrouillée renvoie au hub", function()
	local jelly = sim.zone("JellyCanyon")
	tomRoot.CFrame = CF.new(jelly:GetAttribute("OriginX") + 80, 3, jelly:GetAttribute("OriginZ") + 80)
	sim.advance(1)
	ok((tomRoot.CFrame.Position - HUB_SPAWN).Magnitude < 10, "renvoyé au point d'apparition")
end)

test("dans Neon Docks, les pièces valent x3", function()
	local neon = sim.zone("NeonDocks")
	tomRoot.CFrame = CF.new(neon:GetAttribute("OriginX") + 80, 3, neon:GetAttribute("OriginZ") + 40)
	sim.advance(8)
	local before = sim.logSize()
	touchAll(tom, tomRoot)
	local mult = sim.module("BubbleService").coinMultiplier(tom)
	local checked = 0
	for _, a in popsSince(101, before, "touch") do
		local inNeon = a[3].X < -126
		if a[5] > 0 and a[8] ~= "high" and inNeon then
			local countdown = neon:GetAttribute("ResetAt") - sim.now() <= Config.ZoneCountdown
			local expected = math.max(1, math.floor(a[5] * 3 * mult * (if countdown then 2 else 1) + 0.5))
			ok(math.abs(a[6] - expected) <= 1, ("attendu %d obtenu %d"):format(expected, a[6]))
			checked += 1
		end
	end
	ok(checked > 0, "vérifié")
	noScriptErrors()
end)

---------------------------------------------------------------- 6. quêtes
lib.suite("Serveur simulé : quêtes")
test("une quête terminée paie et est remplacée", function()
	local QS = sim.module("QuestService")
	local d = data(tom)
	local q = d.Quests[1]
	local id, reward = q.Id, q.Reward
	local c0 = coins(tom)
	local done0 = d.Stats.QuestsDone
	local before = sim.logSize()
	QS.progress(tom, Config.quest(id).Type, q.Target, Config.quest(id).Zone)
	sim.advance(0.3)
	eq(d.Stats.QuestsDone, done0 + 1)
	ok(coins(tom) >= c0 + reward, "récompense versée")
	eq(#d.Quests, 3, "toujours 3 quêtes")
	ok(effectNames(101, before).QuestDone == 1)
	for _, other in d.Quests do
		ok(other.Progress < other.Target, "aucune quête bloquée à 100 %")
	end
end)

test("les quêtes avancent en jouant", function()
	local d = data(tom)
	local before = {}
	for _, q in d.Quests do
		before[q.Id] = q.Progress
	end
	sim.advance(6)
	touchAll(tom, tomRoot)
	local moved = false
	for _, q in d.Quests do
		if before[q.Id] and q.Progress > before[q.Id] then
			moved = true
		end
	end
	local hasPlayQuest = false
	for _, q in d.Quests do
		if q.Id == "PopBubbles" or q.Id == "PaintStuds" or q.Id == "EarnCoins" then
			hasPlayQuest = true
		end
	end
	ok(moved or not hasPlayQuest, "progression des quêtes de jeu")
end)

---------------------------------------------------------------- 7. cadeau quotidien
lib.suite("Serveur simulé : cadeau quotidien")
test("jour 1, puis refus le même jour", function()
	local c0 = coins(tom)
	sim.clientFire(tom, "Action", "ClaimDaily")
	sim.advance(0.3)
	ok(coins(tom) > c0, "jour 1 : pièces")
	eq(data(tom).Daily.Streak, 1)
	local c1 = coins(tom)
	sim.clientFire(tom, "Action", "ClaimDaily")
	sim.advance(0.3)
	eq(coins(tom), c1, "pas deux fois")
	eq(sim.lastState(101).Daily.CanClaim, false)
end)

test("jour 2 = boost x2, jour manqué = retour au jour 1", function()
	sim.setTime(sim.now() + 86400)
	sim.clientFire(tom, "Action", "ClaimDaily")
	sim.advance(0.3)
	eq(data(tom).Daily.Streak, 2)
	ok(data(tom).Boosts.CoinsUntil > sim.now(), "boost actif")
	local m = sim.module("BubbleService").coinMultiplier(tom)
	data(tom).Boosts.CoinsUntil = 0
	ok(m > sim.module("BubbleService").coinMultiplier(tom) * 1.9, "le boost double les gains")
	sim.setTime(sim.now() + 86400 * 3)
	sim.clientFire(tom, "Action", "ClaimDaily")
	sim.advance(0.3)
	eq(data(tom).Daily.Streak, 1, "série remise à zéro")
end)

test("jour 7 : compagnon exclusif", function()
	local d = data(tom)
	for day = 2, 7 do
		sim.setTime(sim.now() + 86400)
		sim.clientFire(tom, "Action", "ClaimDaily")
		sim.advance(0.5)
		eq(d.Daily.Streak, day)
	end
	local found = false
	for _, c in d.Companions do
		if c.Id == "Starbub" then
			found = true
		end
	end
	ok(found, "Starbub reçu")
	noScriptErrors()
end)

---------------------------------------------------------------- 8. Rainbow Storm
lib.suite("Serveur simulé : Rainbow Storm")
test("le storm démarre à l'heure, bulles arc-en-ciel x3", function()
	tomRoot.CFrame = CF.new(CANDY)
	local nextAt = S.game.Workspace:GetAttribute("NextStormAt")
	sim.setTime(nextAt - 2)
	sim.advance(3)
	eq(S.game.Workspace:GetAttribute("StormActive"), true)
	local before = sim.logSize()
	sim.advance(4)
	local stormBubbles = 0
	for _, e in sim.events("BubbleSpawned", before) do
		if e.args[1] == 101 and e.args[7] == true then
			stormBubbles += 1
		end
	end
	ok(stormBubbles > 0, "bulles du storm")
	before = sim.logSize()
	touchAll(tom, tomRoot)
	local mult = sim.module("BubbleService").coinMultiplier(tom)
	local checked = 0
	for _, a in popsSince(101, before, "touch") do
		local inCandy = a[3].X >= -80 and a[3].X <= 80 and a[3].Z >= -286 and a[3].Z <= -126
		if a[5] > 0 and a[8] == "low" and inCandy then
			local z = sim.zone()
			local countdown = z:GetAttribute("ResetAt") - sim.now() <= Config.ZoneCountdown
			local expected = math.max(1, math.floor(a[5] * mult * 3 * (if countdown then 2 else 1) + 0.5))
			ok(math.abs(a[6] - expected) <= 1, ("storm x3 : attendu %d obtenu %d"):format(expected, a[6]))
			checked += 1
		end
	end
	ok(checked > 0)
	sim.advance(Config.StormDuration + 2, 0.5)
	eq(S.game.Workspace:GetAttribute("StormActive"), false, "fin du storm")
	noScriptErrors()
end)

---------------------------------------------------------------- 9. sauvegarde
lib.suite("Serveur simulé : sauvegarde")
local saved
test("départ : tout est sauvegardé (améliorations, compagnons, quêtes...)", function()
	saved = sim.deep(data(tom))
	sim.leave(tom)
	sim.advance(1)
	local stored = S.store.data.Player_101
	eq(stored.Lock, nil)
	eq(stored.Data.Coins, saved.Coins)
	eq(stored.Data.Upgrades.Production, saved.Upgrades.Production)
	eq(#stored.Data.Companions, #saved.Companions)
	eq(#stored.Data.Quests, 3)
	eq(stored.Data.Zones.NeonDocks, true)
	eq(stored.Data.Tutorial.Step, #Config.TutorialSteps)
	noScriptErrors()
end)

test("retour 1 h plus tard : progression retrouvée + gains hors ligne", function()
	sim.setTime(sim.now() + 3600)
	local before = sim.logSize()
	local tom2, root2 = sim.join(101, "Tom", HUB_SPAWN)
	sim.advance(2)
	local offline = sim.clientEvents("Effect", 101, before)
	local gained = 0
	for _, a in offline do
		if a[1] == "Offline" then
			gained = a[2].Coins
		end
	end
	ok(gained > 0, "gains hors ligne")
	eq(coins(tom2), saved.Coins + gained)
	eq(#data(tom2).Equipped, #saved.Equipped)
	ok(tom2:GetAttribute("Pets") ~= "", "compagnons visibles")
	tom, tomRoot = tom2, root2
end)

test("données bloquées par un autre serveur : message clair", function()
	S.store.data.Player_303 = { Data = { Coins = 5 }, Lock = { JobId = "autre-serveur", Time = sim.now() } }
	sim.join(303, "Max", HUB_SPAWN)
	sim.advance(Config.LoadRetries * Config.LoadRetryDelay + 2)
	ok(S.kicks[303], "joueur prévenu")
	eq(S.store.data.Player_303.Data.Coins, 5, "données intactes")
end)

test("ancienne sauvegarde v0.1 : mise à niveau sans perte", function()
	S.store.data.Player_505 = { Data = {
		Coins = 777, Stats = { StudsPainted = 10, BubblesPopped = 5, CoinsEarned = 800 },
		Upgrades = {}, Zones = { CandyMeadow = true }, Companions = {}, Cosmetics = {},
		Daily = { Streak = 0, LastClaimDay = 0 }, Settings = { Language = "fr" }, Tutorial = { Done = false },
		PaintColor = 3, LastOnline = 0,
	} }
	local old = sim.join(505, "Ancien", HUB_SPAWN)
	sim.advance(2)
	eq(coins(old), 777)
	eq(old:GetAttribute("Language"), "fr")
	local d = data(old)
	eq(#d.Quests, 3)
	eq(d.Tutorial.Step, 1)
	eq(d.Stats.QuestsDone, 0)
	noScriptErrors()
end)

test("fermeture du serveur : tout le monde est sauvegardé", function()
	local c = coins(tom)
	sim.closeServer()
	sim.advance(3)
	eq(S.store.data.Player_101.Data.Coins, c)
	eq(S.store.data.Player_101.Lock, nil)
end)

---------------------------------------------------------------- 9b. cosmétiques
lib.suite("Serveur simulé : cosmétiques")
test("acheter une traînée à sa machine, l'équiper, la retirer, la retrouver", function()
	S = sim.start({ seed = 11 })
	local p, root = sim.join(601, "Trail", HUB_SPAWN)
	sim.advance(2)
	local d = data(p)
	giveCoins(p, 5000)
	sim.clientFire(p, "Action", "BuyCosmetic", "Ocean")
	sim.advance(0.2)
	ok(not d.Cosmetics.Ocean, "refusé loin de la machine")
	root.CFrame = CF.new(machineOf(p) + V3.new(0, 0, 6))
	local c0 = coins(p)
	sim.clientFire(p, "Action", "BuyCosmetic", "Ocean")
	sim.advance(0.3)
	eq(d.Cosmetics.Ocean, true)
	eq(c0 - coins(p), 3000)
	eq(d.EquippedTrail, "Ocean", "équipée tout de suite")
	ok(root:FindFirstChild("PopaintTrail"), "traînée sur le personnage")
	eq(p:GetAttribute("Trail"), "Ocean")
	sim.clientFire(p, "Action", "BuyCosmetic", "Ocean")
	sim.advance(0.2)
	eq(c0 - coins(p), 3000, "pas acheté deux fois")
	sim.clientFire(p, "Action", "EquipCosmetic", "")
	sim.advance(0.2)
	eq(d.EquippedTrail, "")
	ok(not root:FindFirstChild("PopaintTrail"), "traînée retirée")
	sim.clientFire(p, "Action", "EquipCosmetic", "Galaxy")
	sim.clientFire(p, "Action", "EquipCosmetic", 42)
	sim.advance(0.2)
	eq(d.EquippedTrail, "", "on n'équipe pas ce qu'on n'a pas")
	sim.clientFire(p, "Action", "EquipCosmetic", "Ocean")
	sim.advance(0.2)
	-- réapparition : la traînée revient
	local root2 = sim.respawn(p, HUB_SPAWN)
	sim.advance(0.5)
	ok(root2:FindFirstChild("PopaintTrail"), "traînée après réapparition")
	sim.leave(p)
	sim.advance(1)
	local back = sim.join(601, "Trail", HUB_SPAWN)
	sim.advance(2)
	eq(data(back).EquippedTrail, "Ocean", "sauvegardée")
	eq(sim.lastState(601).Cosmetics.Ocean, true)
	noScriptErrors()
end)

---------------------------------------------------------------- 9c. événements
lib.suite("Serveur simulé : événement Halloween")
local Formulas = lib.loadFile("src/Shared/Formulas.luau")
test("hors des dates : zone fermée, renvoi au hub, pas de quête ni de traînée d'événement", function()
	S = sim.start({ seed = 21 })
	local p, root = sim.join(701, "Spooky", HUB_SPAWN)
	sim.advance(2)
	eq(S.game.Workspace:GetAttribute("Event_Halloween2026"), false)
	local st = sim.lastState(701)
	ok(not st.Zones.PumpkinPatch, "zone fermée")
	local pz = sim.zone("PumpkinPatch")
	root.CFrame = CF.new(pz:GetAttribute("OriginX") + 80, 3, pz:GetAttribute("OriginZ") + 40)
	sim.advance(1)
	ok((root.CFrame.Position - HUB_SPAWN).Magnitude < 10, "renvoyé au hub")
	for _, q in data(p).Quests do
		ok(not Config.quest(q.Id).Event, "pas de quête d'événement")
	end
	giveCoins(p, 100000)
	root.CFrame = CF.new(machineOf(p) + V3.new(0, 0, 6))
	sim.clientFire(p, "Action", "BuyCosmetic", "Spooky")
	sim.advance(0.2)
	ok(not data(p).Cosmetics.Spooky, "traînée d'événement pas en vente")
	sim.clientFire(p, "Action", "UnlockZone", "PumpkinPatch")
	sim.advance(0.2)
	ok(not data(p).Zones.PumpkinPatch, "une zone d'événement ne s'achète pas")
	noScriptErrors()
end)

test("pendant l'événement : zone ouverte, gains adaptés, œuf, quêtes, traînée", function()
	sim.setTime(Formulas.utcEpoch(2026, 10, 25, 12))
	sim.advance(6)
	eq(S.game.Workspace:GetAttribute("Event_Halloween2026"), true, "événement actif")
	local p = S.players[701]
	local root = p.Character.HumanoidRootPart
	sim.advance(15.5) -- l'état est renvoyé au joueur régulièrement
	ok(sim.lastState(701).Zones.PumpkinPatch, "zone ouverte pour le joueur")
	local pz = sim.zone("PumpkinPatch")
	root.CFrame = CF.new(pz:GetAttribute("OriginX") + 80, 3, pz:GetAttribute("OriginZ") + 40)
	sim.advance(8)
	ok((root.CFrame.Position - HUB_SPAWN).Magnitude > 50, "pas renvoyé au hub")
	local before = sim.logSize()
	touchAll(p, root)
	local mult = sim.module("BubbleService").coinMultiplier(p)
	local checked = 0
	for _, a in popsSince(701, before, "touch") do
		if a[5] > 0 and a[8] == "low" and a[3].X > 120 and a[3].Z > 120 then
			local countdown = pz:GetAttribute("ResetAt") - sim.now() <= Config.ZoneCountdown
			local storm = S.game.Workspace:GetAttribute("StormActive") == true
			local expected = math.max(1, math.floor(a[5] * 1.5 * mult * (if countdown then 2 else 1) * (if storm then 3 else 1) + 0.5))
			ok(math.abs(a[6] - expected) <= 1, ("zone d'événement : attendu %d obtenu %d"):format(expected, a[6]))
			checked += 1
		end
	end
	ok(checked > 0, "éclatements vérifiés dans Pumpkin Patch")
	-- œuf d'événement : prix x valeur de la meilleure zone (ici Candy Meadow = x1)
	local d = data(p)
	local n = #d.Companions
	local c0 = coins(p)
	sim.prompt(p, S.game.Workspace.Map.Eggs.PumpkinPatch:FindFirstChildWhichIsA("ProximityPrompt", true))
	sim.advance(0.3)
	eq(#d.Companions, n + 1, "œuf d'événement ouvert")
	ok(c0 - coins(p) <= 200 or d.Tutorial.Step <= 5, "prix adapté")
	ok(Config.Companions[d.Companions[#d.Companions].Id].Zone == "PumpkinPatch", "compagnon d'Halloween")
	-- quêtes d'événement : elles apparaissent parmi les nouvelles quêtes
	local QS = sim.module("QuestService")
	local seen = false
	for _ = 1, 40 do
		local q = d.Quests[1]
		local def = Config.quest(q.Id)
		QS.progress(p, def.Type, q.Target, def.Zone)
		for _, other in d.Quests do
			if Config.quest(other.Id).Event then
				seen = true
			end
		end
		if seen then
			break
		end
	end
	ok(seen, "une quête d'Halloween est proposée")
	-- une quête de zone n'avance que dans sa zone
	local zq
	for _, q in d.Quests do
		if Config.quest(q.Id).Zone then
			zq = q
		end
	end
	if zq then
		local before2 = zq.Progress
		QS.progress(p, Config.quest(zq.Id).Type, 5, "CandyMeadow")
		eq(zq.Progress, before2, "ne compte pas ailleurs")
		QS.progress(p, Config.quest(zq.Id).Type, 5, "PumpkinPatch")
		ok(zq.Progress > before2 or zq.Progress == 0, "compte dans sa zone")
	end
	root.CFrame = CF.new(machineOf(p) + V3.new(0, 0, 6))
	giveCoins(p, 5000)
	sim.clientFire(p, "Action", "BuyCosmetic", "Spooky")
	sim.advance(0.2)
	eq(d.Cosmetics.Spooky, true, "traînée d'Halloween achetée")
	noScriptErrors()
end)

test("fin de l'événement : zone refermée, quêtes retirées, ce qu'on a gagné reste", function()
	local p = S.players[701]
	local root = p.Character.HumanoidRootPart
	local pz = sim.zone("PumpkinPatch")
	root.CFrame = CF.new(pz:GetAttribute("OriginX") + 80, 3, pz:GetAttribute("OriginZ") + 40)
	sim.setTime(Formulas.utcEpoch(2026, 11, 4, 1))
	sim.advance(7)
	eq(S.game.Workspace:GetAttribute("Event_Halloween2026"), false)
	ok((root.CFrame.Position - HUB_SPAWN).Magnitude < 10, "renvoyé au hub")
	local d = data(p)
	for _, q in d.Quests do
		ok(not Config.quest(q.Id).Event, "quêtes d'Halloween retirées")
	end
	eq(#d.Quests, Config.QuestCount)
	eq(d.Cosmetics.Spooky, true, "la traînée reste")
	local hasPet = false
	for _, c in d.Companions do
		if Config.Companions[c.Id].Zone == "PumpkinPatch" then
			hasPet = true
		end
	end
	ok(hasPet, "le compagnon reste")
	noScriptErrors()
end)

test("dans Roblox Studio, les événements sont toujours actifs pour les tester", function()
	S = sim.start({ seed = 31, studio = true })
	sim.advance(1)
	eq(S.game.Workspace:GetAttribute("Event_Halloween2026"), true)
end)

---------------------------------------------------------------- 10. Studio sans accès API
lib.suite("Serveur simulé : Studio sans accès API")
test("le jeu tourne sans sauvegarde et prévient", function()
	S = sim.start({ noDataStore = true, seed = 99 })
	local p, root = sim.join(404, "Test", HUB_SPAWN)
	sim.advance(2)
	eq(p:GetAttribute("SaveOff"), true)
	root.CFrame = CF.new(CANDY)
	sim.advance(6)
	touchAll(p, root)
	ok(coins(p) > 0, "on gagne quand même des pièces")
	noScriptErrors()
end)

---------------------------------------------------------------- 11. charge
lib.suite("Serveur simulé : charge")
test("10 joueurs qui courent partout pendant 30 minutes", function()
	S = sim.start({ seed = 5 })
	local players = {}
	for i = 1, 10 do
		local p, root = sim.join(1000 + i, "P" .. i, HUB_SPAWN)
		table.insert(players, { p = p, root = root })
	end
	sim.advance(3)
	local bases = {}
	for _, e in players do
		local b = e.p:GetAttribute("BaseName")
		ok(b and not bases[b], "une base chacun")
		bases[b] = true
	end
	local rng = math.random
	for _ = 1, 30 do
		for _ = 1, 15 do
			for _, e in players do
				-- chacun court vers un endroit au hasard de Candy Meadow puis touche ses bulles proches
				e.root.CFrame = CF.new(-70 + rng() * 140, 3, -276 + rng() * 140)
				local live = sim.liveBubbles(e.p.UserId)
				local k = 0
				for _, b in live do
					k += 1
					if k > 3 then
						break
					end
					e.root.CFrame = CF.new(b.position)
				end
			end
			sim.advance(4, 0.25)
		end
	end
	noScriptErrors()
	local minC, maxC = math.huge, 0
	for _, e in players do
		local c = coins(e.p)
		minC = math.min(minC, c)
		maxC = math.max(maxC, c)
		ok(c > 0, "tout le monde progresse")
	end
	local resets = #sim.events("ZoneReset", 0)
	print(("       (info) pièces après 30 min : min %d, max %d ; vagues : %d"):format(minC, maxC, resets))
	ok(resets >= 2, "la zone se renouvelle")
end)

if not lib.summary() then
	process.exit(1)
end
