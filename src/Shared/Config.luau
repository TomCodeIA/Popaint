--!strict
-- Popaint : réglages centraux du jeu.
-- Tous les nombres d'équilibrage sont ici, pour pouvoir les ajuster sans toucher au reste du code.

local Config = {}

Config.Version = "0.7.0"

-- Le contenu (zones, compagnons, quêtes, événements, cosmétiques) est dans le dossier Content.
local ContentFolder = script.Parent:WaitForChild("Content")
local function content(name: string): any
	return require(ContentFolder:WaitForChild(name)) :: any
end

---------------------------------------------------------------- Sons
-- Remplace ces identifiants par ceux choisis dans la Toolbox (clic droit > Copy Asset ID).
-- Exemple : Config.Sounds.Pop = "rbxassetid://1234567890"
Config.Sounds = {
	Pop = "rbxassetid://121085167616471",
	Splash = "rbxasset://sounds/impact_water.mp3",
	Coin = "rbxassetid://138090647930091",
	Click = "rbxasset://sounds/button.wav",
	Reward = "rbxassetid://94433663716765",
	Wash = "rbxasset://sounds/action_swim.mp3",
	Error = "rbxasset://sounds/button.wav",
}

---------------------------------------------------------------- Sauvegarde
Config.DataStoreName = "PopaintData_v1"
Config.AutosaveInterval = 120
Config.SessionLockExpire = 360
Config.LoadRetries = 6
Config.LoadRetryDelay = 4

---------------------------------------------------------------- Grille de peinture
Config.TileSize = 4
Config.GreyColor = Color3.fromRGB(176, 172, 186) -- gris doux (légèrement lavande)

---------------------------------------------------------------- Bulles (valeurs de base, avant améliorations)
Config.BubbleSpawnInterval = 1.25
Config.MaxBubblesPerPlayer = 12
Config.BubbleLifetime = 30
Config.BubbleMinDistance = 6
Config.BubbleMaxDistance = 24
Config.LowBubbleMinHeight = 2.2 -- à hauteur de course
Config.LowBubbleMaxHeight = 3.8
Config.HighBubbleChance = 0.2 -- bulles hautes, à attraper en sautant
Config.HighBubbleMinHeight = 7.5
Config.HighBubbleMaxHeight = 9
Config.HighBubbleValue = 2
Config.BubbleSize = 3.4
Config.CascadeBubbleSize = 2.2
Config.ContactRadius = 2.4 -- distance corps -> bord de la bulle pour l'éclater
Config.ContactTolerance = 9 -- tolérance réseau quand le client annonce un contact
Config.MaxPopsPerSecond = 15
Config.PaintRadius = 6
Config.CascadeRadiusFactor = 0.65
Config.CascadeChance = 0.1
Config.CascadeMin = 2
Config.CascadeMax = 4
Config.AfkPopInterval = 5

---------------------------------------------------------------- Améliorations
export type UpgradeDef = {
	Id: string,
	NameKey: string,
	DescKey: string,
	BaseCost: number,
	MaxLevel: number,
	Icon: string, -- emoji affiché dans la boutique
	Color: Color3,
	Growth: number?, -- croissance du prix (sinon Config.UpgradeCostGrowth)
}

Config.Upgrades = {
	{ Id = "Production", NameKey = "Up_Production", DescKey = "UpD_Production", BaseCost = 25, MaxLevel = 25, Icon = "🫧", Color = Color3.fromRGB(130, 200, 250) },
	{ Id = "Size", NameKey = "Up_Size", DescKey = "UpD_Size", BaseCost = 40, MaxLevel = 20, Icon = "💥", Color = Color3.fromRGB(255, 150, 196) },
	{ Id = "Value", NameKey = "Up_Value", DescKey = "UpD_Value", BaseCost = 60, MaxLevel = 50, Icon = "💰", Color = Color3.fromRGB(255, 210, 110) },
	{ Id = "Cascade", NameKey = "Up_Cascade", DescKey = "UpD_Cascade", BaseCost = 100, MaxLevel = 20, Icon = "🌈", Color = Color3.fromRGB(190, 160, 250) },
	{ Id = "Speed", NameKey = "Up_Speed", DescKey = "UpD_Speed", BaseCost = 30, MaxLevel = 14, Icon = "👟", Color = Color3.fromRGB(140, 222, 166) },
	{ Id = "Afk", NameKey = "Up_Afk", DescKey = "UpD_Afk", BaseCost = 80, MaxLevel = 15, Icon = "💤", Color = Color3.fromRGB(170, 186, 250) },
	{ Id = "Magnet", NameKey = "Up_Magnet", DescKey = "UpD_Magnet", BaseCost = 150, MaxLevel = 15, Icon = "🧲", Color = Color3.fromRGB(255, 184, 140) },
	{ Id = "Treadmill", NameKey = "Up_Treadmill", DescKey = "UpD_Treadmill", BaseCost = 200, MaxLevel = 10, Icon = "🏃", Color = Color3.fromRGB(130, 226, 214), Growth = 2.2 },
} :: { UpgradeDef }

Config.UpgradeCostGrowth = 1.15
Config.TrainSpeedCap = 20 -- +20 de vitesse maximum grâce à l'entraînement sur le tapis
Config.MachineReach = 22 -- distance max à sa machine pour acheter

-- Effet de chaque amélioration selon son niveau
Config.UpgradeEffects = {
	spawnInterval = function(level: number): number
		return Config.BubbleSpawnInterval * 0.94 ^ level
	end,
	maxBubbles = function(level: number): number
		return Config.MaxBubblesPerPlayer + math.floor(level / 2)
	end,
	paintRadius = function(level: number): number
		return Config.PaintRadius * (1 + 0.06 * level)
	end,
	valueMultiplier = function(level: number): number
		return 1 + 0.15 * level
	end,
	cascadeChance = function(level: number): number
		return math.min(0.6, Config.CascadeChance + 0.015 * level)
	end,
	walkSpeed = function(level: number): number
		return 16 + level
	end,
	afkInterval = function(level: number): number
		return Config.AfkPopInterval * 0.9 ^ level
	end,
	contactRadius = function(level: number): number
		return Config.ContactRadius + 0.6 * level
	end,
	-- vitesse bonus gagnée à l'entraînement (points de course cumulés)
	trainSpeed = function(points: number): number
		return math.min(Config.TrainSpeedCap, math.floor(math.sqrt(math.max(0, points) / 2000)))
	end,
}

---------------------------------------------------------------- Tapis de course
-- Points gagnés par seconde sur le tapis, selon son niveau (0 à 10)
Config.TreadmillRates = { 100, 200, 350, 500, 800, 1200, 1800, 2600, 3800, 5500, 8000 }
-- Apparence du tapis par paliers de niveau : { niveau mini, couleur du cadre, matériau des rails }
Config.TreadmillLooks = ({
	{ 0, Color3.fromRGB(170, 166, 186) },
	{ 1, Color3.fromRGB(150, 200, 246) },
	{ 3, Color3.fromRGB(150, 220, 170) },
	{ 5, Color3.fromRGB(196, 170, 246) },
	{ 7, Color3.fromRGB(250, 210, 120) },
	{ 9, Color3.fromRGB(250, 164, 204) }, -- arc-en-ciel animé côté joueur
} :: { { any } })

---------------------------------------------------------------- Zones (liste dans Content/Zones.luau)
export type ZoneConfig = {
	Id: string,
	Name: string,
	DisplayKey: string,
	Cost: number,
	StudValue: number,
	EggCost: number,
	EggPower: number,
	Color: Color3,
	Platform: Color3,
	Cell: { number },
	From: string,
	Shape: string,
	Centerpiece: string,
	Theme: string,
	Event: string?,
	StudValueScale: number?,
	EggScale: boolean?,
}

Config.Zones = content("Zones") :: { ZoneConfig }

-- Zones normales, dans l'ordre de déblocage (sans les zones d'événement)
Config.MainZones = {} :: { ZoneConfig }
for _, z in Config.Zones do
	if not z.Event then
		table.insert(Config.MainZones, z)
	end
end

Config.ZoneResetMin = 300
Config.ZoneResetMax = 900
Config.ZoneCountdown = 30
Config.ZoneFullThreshold = 0.85
Config.CountdownMultiplier = 2
Config.ResetWaveDuration = 2

---------------------------------------------------------------- Compagnons
export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic"

Config.Rarities = {
	{ Id = "Common", Chance = 60, Color = Color3.fromRGB(200, 200, 214) },
	{ Id = "Rare", Chance = 25, Color = Color3.fromRGB(120, 192, 255) },
	{ Id = "Epic", Chance = 10, Color = Color3.fromRGB(190, 140, 255) },
	{ Id = "Legendary", Chance = 4.5, Color = Color3.fromRGB(255, 196, 70) },
	{ Id = "Mythic", Chance = 0.5, Color = Color3.fromRGB(255, 120, 176) },
}

-- Bonus de base par rareté (multipliés par la force de l'œuf et le rang Doré/Arc-en-ciel)
--   Coins : +x % de pièces ; Radius : +x % de rayon de peinture ; AutoPop : éclate une bulle proche toutes les x s
Config.RarityBonus = {
	Common = { Coins = 0.05 },
	Rare = { Coins = 0.12 },
	Epic = { Coins = 0.08, AutoPop = 3 },
	Legendary = { Coins = 0.10, Radius = 0.20 },
	Mythic = { Coins = 0.40 },
}

Config.TierMultipliers = { [0] = 1, [1] = 2, [2] = 5 } -- normal, Doré, Arc-en-ciel
Config.FuseCount = 3
Config.MaxEquipped = 3
Config.InventorySize = 50

export type CompanionDef = {
	Id: string,
	Name: string,
	Rarity: string,
	Zone: string,
	Power: number, -- force de l'œuf (zone)
	Color: Color3,
	Row: any, -- ligne complète de Content/Companions (apparence 3D "Look")
}

Config.Companions = {} :: { [string]: CompanionDef }
Config.EggContents = {} :: { [string]: { string } }
for _, row in content("Companions") do
	local zone = nil
	for _, z in Config.Zones do
		if z.Id == row.Egg then
			zone = z
		end
	end
	local def: CompanionDef = {
		Id = row.Id,
		Name = row.Name,
		Rarity = row.Rarity,
		Zone = row.Egg,
		Power = if zone then zone.EggPower else 2.5,
		Color = row.Color,
		Row = row,
	}
	Config.Companions[def.Id] = def
	if zone then
		Config.EggContents[row.Egg] = Config.EggContents[row.Egg] or {}
		table.insert(Config.EggContents[row.Egg], def.Id)
	end
end

---------------------------------------------------------------- Quêtes (liste dans Content/Quests.luau)
export type QuestDef = {
	Id: string,
	Type: string,
	TextKey: string,
	Target: number,
	Reward: number,
	Zone: string?,
	Event: string?,
}

Config.QuestCount = 3
Config.Quests = content("Quests") :: { QuestDef }
Config.QuestGrowth = 0.08 -- chaque quête terminée rend les suivantes un peu plus longues (max x3,4)
Config.QuestGrowthCap = 30

---------------------------------------------------------------- Événements (liste dans Content/Events.luau)
Config.Events = content("Events") :: { any }
Config.ForceEventsInStudio = true -- dans Studio, tous les événements sont actifs pour les tester

---------------------------------------------------------------- Cosmétiques (liste dans Content/Cosmetics.luau)
Config.Cosmetics = content("Cosmetics") :: { any }

---------------------------------------------------------------- Récompenses quotidiennes (cycle de 7 jours)
Config.Daily = ({
	{ Kind = "Coins", Amount = 100 },
	{ Kind = "Boost", Seconds = 600 },
	{ Kind = "Coins", Amount = 250 },
	{ Kind = "Egg" },
	{ Kind = "Coins", Amount = 600 },
	{ Kind = "Boost", Seconds = 1800 },
	{ Kind = "Companion", Id = "Starbub" },
} :: { { [string]: any } })

---------------------------------------------------------------- Rainbow Storm
Config.StormPeriod = 5400 -- toutes les 1h30, calé sur minuit UTC
Config.StormDuration = 600 -- 10 minutes
Config.StormMultiplier = 3
Config.StormSpawnFactor = 0.5 -- les bulles apparaissent 2x plus vite
Config.StormAnnounce = 300 -- annonce 5 minutes avant

---------------------------------------------------------------- Boosts
Config.BoostMultiplier = 2

---------------------------------------------------------------- Gains hors ligne
Config.OfflineMaxSeconds = 7200 -- 2 heures maximum
Config.OfflineRate = 0.1 -- 10 % du rythme AFK
Config.OfflineMinSeconds = 120

---------------------------------------------------------------- Niveau
Config.LevelDivisor = 200 -- niveau = racine(points / 200) : niveau 10 en ~30 min

---------------------------------------------------------------- Didacticiel
Config.TutorialSteps = { "GoToZone", "PopBubbles", "OpenShop", "BuyUpgrade", "OpenEgg", "Done" }
Config.TutorialPopTarget = 5
Config.TutorialReward = 100

---------------------------------------------------------------- Couleurs de peinture des joueurs
-- Pastel « soutenu » : doux pour les yeux mais bien visible sur les cases grises
Config.PaintPalette = {
	Color3.fromRGB(255, 150, 196), -- rose
	Color3.fromRGB(130, 206, 250), -- ciel
	Color3.fromRGB(255, 220, 120), -- beurre
	Color3.fromRGB(140, 226, 170), -- menthe
	Color3.fromRGB(190, 160, 250), -- lavande
	Color3.fromRGB(255, 184, 140), -- pêche
	Color3.fromRGB(255, 160, 160), -- corail
	Color3.fromRGB(130, 226, 214), -- turquoise
	Color3.fromRGB(240, 170, 230), -- lilas
	Color3.fromRGB(170, 186, 250), -- pervenche
}

Config.BaseCount = 10

function Config.zone(id: string): ZoneConfig?
	for _, z in Config.Zones do
		if z.Id == id then
			return z
		end
	end
	return nil
end

function Config.event(id: string): any
	for _, e in Config.Events do
		if e.Id == id then
			return e
		end
	end
	return nil
end

function Config.cosmetic(id: string): any
	for _, c in Config.Cosmetics do
		if c.Id == id then
			return c
		end
	end
	return nil
end

function Config.upgrade(id: string): UpgradeDef?
	for _, u in Config.Upgrades do
		if u.Id == id then
			return u
		end
	end
	return nil
end

function Config.quest(id: string): QuestDef?
	for _, q in Config.Quests do
		if q.Id == id then
			return q
		end
	end
	return nil
end

return Config
