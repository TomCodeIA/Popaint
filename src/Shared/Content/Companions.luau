--!strict
-- Popaint : LISTE DES COMPAGNONS.
--
-- AJOUTER DES COMPAGNONS : une ligne par compagnon.
--   Egg = l'Id de la zone dont l'œuf le contient (voir Zones.luau), ou "Daily" pour une récompense.
--   Chaque œuf doit contenir 5 compagnons : un de chaque rareté (Common, Rare, Epic, Legendary, Mythic).
--   Les chances et les bonus par rareté sont dans Config.luau (Rarities, RarityBonus).
-- ⚠ Ne supprime jamais un compagnon qui a déjà été disponible : des joueurs le possèdent
--   (après un événement, garde sa ligne ; il n'est simplement plus dans aucun œuf ouvert).

export type CompanionLook = {
	Body: string?, -- Round, Tall, Squish, Fish, Gem, Ghost, Pumpkin, Star, Cube, Bird
	Extras: { string }?, -- oreilles, ailes, cornes… (liste complète en tête de src/Shared/CompanionModels.luau)
	Accent: Color3?, -- deuxième couleur
}

export type CompanionRow = {
	Id: string,
	Name: string,
	Rarity: string,
	Egg: string,
	Color: Color3, -- couleurs pastel : douces pour les yeux
	Look: CompanionLook?, -- apparence 3D (facultatif : sinon une apparence selon la rareté)
}

local rgb = Color3.fromRGB

local Companions: { CompanionRow } = {
	-- Candy Meadow
	{ Id = "Gumdrop", Name = "Gumdrop", Rarity = "Common", Egg = "CandyMeadow", Color = rgb(255, 196, 214),
		Look = { Body = "Squish", Extras = { "Cherry", "Dots" }, Accent = rgb(255, 255, 255) } },
	{ Id = "Lolli", Name = "Lolli", Rarity = "Rare", Egg = "CandyMeadow", Color = rgb(255, 170, 200),
		Look = { Body = "Round", Extras = { "BunnyEars", "Bow" }, Accent = rgb(255, 236, 170) } },
	{ Id = "Taffy", Name = "Taffy", Rarity = "Epic", Egg = "CandyMeadow", Color = rgb(214, 190, 255),
		Look = { Body = "Tall", Extras = { "CatEars", "Tail", "Scarf" }, Accent = rgb(255, 196, 214) } },
	{ Id = "Sprinkle", Name = "Sprinkle", Rarity = "Legendary", Egg = "CandyMeadow", Color = rgb(255, 232, 170),
		Look = { Body = "Bird", Extras = { "Wings", "Dots" }, Accent = rgb(255, 178, 200) } },
	{ Id = "Sugarcorn", Name = "Sugarcorn", Rarity = "Mythic", Egg = "CandyMeadow", Color = rgb(255, 250, 244),
		Look = { Body = "Round", Extras = { "Horn", "FairyWings", "Tail" }, Accent = rgb(232, 196, 244) } },
	-- Neon Docks
	{ Id = "Glowfish", Name = "Glowfish", Rarity = "Common", Egg = "NeonDocks", Color = rgb(170, 226, 250),
		Look = { Body = "Fish", Extras = { "Antennae" }, Accent = rgb(196, 246, 236) } },
	{ Id = "Zap", Name = "Zap", Rarity = "Rare", Egg = "NeonDocks", Color = rgb(255, 238, 160),
		Look = { Body = "Round", Extras = { "Bolt", "CatEars" }, Accent = rgb(255, 210, 160) } },
	{ Id = "Bulb", Name = "Bulb", Rarity = "Epic", Egg = "NeonDocks", Color = rgb(246, 186, 232),
		Look = { Body = "Tall", Extras = { "Bulb", "Fins" }, Accent = rgb(255, 236, 170) } },
	{ Id = "Laser", Name = "Laser", Rarity = "Legendary", Egg = "NeonDocks", Color = rgb(255, 176, 184),
		Look = { Body = "Bird", Extras = { "Wings", "Antennae" }, Accent = rgb(182, 218, 255) } },
	{ Id = "Neonix", Name = "Neonix", Rarity = "Mythic", Egg = "NeonDocks", Color = rgb(176, 240, 216),
		Look = { Body = "Fish", Extras = { "FairyWings", "Crown" }, Accent = rgb(206, 192, 255) } },
	-- Jelly Canyon
	{ Id = "Wobble", Name = "Wobble", Rarity = "Common", Egg = "JellyCanyon", Color = rgb(190, 242, 190),
		Look = { Body = "Cube", Extras = { "Leaf" }, Accent = rgb(220, 250, 220) } },
	{ Id = "Jiggle", Name = "Jiggle", Rarity = "Rare", Egg = "JellyCanyon", Color = rgb(255, 204, 168),
		Look = { Body = "Squish", Extras = { "BearEars", "Tail" }, Accent = rgb(255, 236, 210) } },
	{ Id = "Slime", Name = "Slime", Rarity = "Epic", Egg = "JellyCanyon", Color = rgb(176, 230, 168),
		Look = { Body = "Squish", Extras = { "Antennae", "Dots" }, Accent = rgb(255, 236, 170) } },
	{ Id = "Gelato", Name = "Gelato", Rarity = "Legendary", Egg = "JellyCanyon", Color = rgb(255, 214, 232),
		Look = { Body = "Cube", Extras = { "Cherry", "Wings" }, Accent = rgb(255, 248, 236) } },
	{ Id = "Jellord", Name = "Jellord", Rarity = "Mythic", Egg = "JellyCanyon", Color = rgb(206, 176, 250),
		Look = { Body = "Cube", Extras = { "Crown", "FairyWings", "Tail" }, Accent = rgb(255, 196, 214) } },
	-- Crystal Peaks
	{ Id = "Shard", Name = "Shard", Rarity = "Common", Egg = "CrystalPeaks", Color = rgb(206, 232, 255),
		Look = { Body = "Gem", Extras = {}, Accent = rgb(255, 255, 255) } },
	{ Id = "Gem", Name = "Gem", Rarity = "Rare", Egg = "CrystalPeaks", Color = rgb(170, 204, 255),
		Look = { Body = "Round", Extras = { "Horns", "Scarf" }, Accent = rgb(255, 255, 255) } },
	{ Id = "Prism", Name = "Prism", Rarity = "Epic", Egg = "CrystalPeaks", Color = rgb(226, 200, 255),
		Look = { Body = "Gem", Extras = { "FairyWings" }, Accent = rgb(182, 218, 255) } },
	{ Id = "Diamondo", Name = "Diamondo", Rarity = "Legendary", Egg = "CrystalPeaks", Color = rgb(232, 248, 255),
		Look = { Body = "Tall", Extras = { "Spikes", "Horns", "Tail" }, Accent = rgb(182, 218, 255) } },
	{ Id = "Crystalis", Name = "Crystalis", Rarity = "Mythic", Egg = "CrystalPeaks", Color = rgb(186, 240, 240),
		Look = { Body = "Gem", Extras = { "Halo", "Wings" }, Accent = rgb(255, 255, 255) } },
	-- Rainbow Core
	{ Id = "Glimmer", Name = "Glimmer", Rarity = "Common", Egg = "RainbowCore", Color = rgb(255, 242, 196),
		Look = { Body = "Star", Extras = {}, Accent = rgb(255, 255, 255) } },
	{ Id = "Spark", Name = "Spark", Rarity = "Rare", Egg = "RainbowCore", Color = rgb(255, 210, 160),
		Look = { Body = "Round", Extras = { "Flame", "Tail" }, Accent = rgb(255, 236, 170) } },
	{ Id = "Aurora", Name = "Aurora", Rarity = "Epic", Egg = "RainbowCore", Color = rgb(186, 240, 220),
		Look = { Body = "Bird", Extras = { "FairyWings" }, Accent = rgb(232, 196, 244) } },
	{ Id = "Celestia", Name = "Celestia", Rarity = "Legendary", Egg = "RainbowCore", Color = rgb(212, 212, 255),
		Look = { Body = "Star", Extras = { "Wings", "Bow" }, Accent = rgb(255, 196, 214) } },
	{ Id = "Prismo", Name = "Prismo", Rarity = "Mythic", Egg = "RainbowCore", Color = rgb(255, 190, 222),
		Look = { Body = "Round", Extras = { "Horn", "Wings", "Halo" }, Accent = rgb(182, 218, 255) } },
	-- Récompense du 7e jour
	{ Id = "Starbub", Name = "Starbub", Rarity = "Mythic", Egg = "Daily", Color = rgb(255, 232, 150),
		Look = { Body = "Star", Extras = { "Crown", "FairyWings" }, Accent = rgb(255, 255, 255) } },
	-- Événement Halloween 2026 (œuf de Pumpkin Patch)
	{ Id = "Pumpkid", Name = "Pumpkid", Rarity = "Common", Egg = "PumpkinPatch", Color = rgb(255, 196, 140),
		Look = { Body = "Pumpkin", Extras = { "Leaf" }, Accent = rgb(176, 132, 110) } },
	{ Id = "Batty", Name = "Batty", Rarity = "Rare", Egg = "PumpkinPatch", Color = rgb(180, 160, 210),
		Look = { Body = "Round", Extras = { "CatEars", "BatWings" }, Accent = rgb(150, 120, 172) } },
	{ Id = "Spookle", Name = "Spookle", Rarity = "Epic", Egg = "PumpkinPatch", Color = rgb(244, 246, 255),
		Look = { Body = "Ghost", Extras = { "Bow" }, Accent = rgb(206, 192, 255) } },
	{ Id = "Candlewick", Name = "Candlewick", Rarity = "Legendary", Egg = "PumpkinPatch", Color = rgb(255, 238, 200),
		Look = { Body = "Tall", Extras = { "Flame", "Scarf" }, Accent = rgb(255, 196, 140) } },
	{ Id = "Hauntix", Name = "Hauntix", Rarity = "Mythic", Egg = "PumpkinPatch", Color = rgb(196, 246, 186),
		Look = { Body = "Ghost", Extras = { "Horns", "BatWings", "Halo" }, Accent = rgb(206, 192, 255) } },
}

return Companions
