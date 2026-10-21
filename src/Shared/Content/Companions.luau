--!strict
-- Popaint : LISTE DES COMPAGNONS.
--
-- AJOUTER DES COMPAGNONS : une ligne par compagnon.
--   Egg = l'Id de la zone dont l'œuf le contient (voir Zones.luau), ou "Daily" pour une récompense.
--   Chaque œuf doit contenir 5 compagnons : un de chaque rareté (Common, Rare, Epic, Legendary, Mythic).
--   Les chances et les bonus par rareté sont dans Config.luau (Rarities, RarityBonus).
-- ⚠ Ne supprime jamais un compagnon qui a déjà été disponible : des joueurs le possèdent
--   (après un événement, garde sa ligne ; il n'est simplement plus dans aucun œuf ouvert).

export type CompanionRow = {
	Id: string,
	Name: string,
	Rarity: string,
	Egg: string,
	Color: Color3,
}

local Companions: { CompanionRow } = {
	-- Candy Meadow
	{ Id = "Gumdrop", Name = "Gumdrop", Rarity = "Common", Egg = "CandyMeadow", Color = Color3.fromRGB(255, 170, 200) },
	{ Id = "Lolli", Name = "Lolli", Rarity = "Rare", Egg = "CandyMeadow", Color = Color3.fromRGB(255, 110, 170) },
	{ Id = "Taffy", Name = "Taffy", Rarity = "Epic", Egg = "CandyMeadow", Color = Color3.fromRGB(200, 140, 255) },
	{ Id = "Sprinkle", Name = "Sprinkle", Rarity = "Legendary", Egg = "CandyMeadow", Color = Color3.fromRGB(255, 220, 120) },
	{ Id = "Sugarcorn", Name = "Sugarcorn", Rarity = "Mythic", Egg = "CandyMeadow", Color = Color3.fromRGB(255, 255, 255) },
	-- Neon Docks
	{ Id = "Glowfish", Name = "Glowfish", Rarity = "Common", Egg = "NeonDocks", Color = Color3.fromRGB(90, 230, 255) },
	{ Id = "Zap", Name = "Zap", Rarity = "Rare", Egg = "NeonDocks", Color = Color3.fromRGB(255, 240, 80) },
	{ Id = "Bulb", Name = "Bulb", Rarity = "Epic", Egg = "NeonDocks", Color = Color3.fromRGB(255, 120, 220) },
	{ Id = "Laser", Name = "Laser", Rarity = "Legendary", Egg = "NeonDocks", Color = Color3.fromRGB(255, 60, 90) },
	{ Id = "Neonix", Name = "Neonix", Rarity = "Mythic", Egg = "NeonDocks", Color = Color3.fromRGB(120, 255, 200) },
	-- Jelly Canyon
	{ Id = "Wobble", Name = "Wobble", Rarity = "Common", Egg = "JellyCanyon", Color = Color3.fromRGB(150, 255, 150) },
	{ Id = "Jiggle", Name = "Jiggle", Rarity = "Rare", Egg = "JellyCanyon", Color = Color3.fromRGB(255, 160, 90) },
	{ Id = "Slime", Name = "Slime", Rarity = "Epic", Egg = "JellyCanyon", Color = Color3.fromRGB(110, 230, 90) },
	{ Id = "Gelato", Name = "Gelato", Rarity = "Legendary", Egg = "JellyCanyon", Color = Color3.fromRGB(255, 200, 230) },
	{ Id = "Jellord", Name = "Jellord", Rarity = "Mythic", Egg = "JellyCanyon", Color = Color3.fromRGB(180, 90, 255) },
	-- Crystal Peaks
	{ Id = "Shard", Name = "Shard", Rarity = "Common", Egg = "CrystalPeaks", Color = Color3.fromRGB(190, 230, 255) },
	{ Id = "Gem", Name = "Gem", Rarity = "Rare", Egg = "CrystalPeaks", Color = Color3.fromRGB(80, 160, 255) },
	{ Id = "Prism", Name = "Prism", Rarity = "Epic", Egg = "CrystalPeaks", Color = Color3.fromRGB(220, 170, 255) },
	{ Id = "Diamondo", Name = "Diamondo", Rarity = "Legendary", Egg = "CrystalPeaks", Color = Color3.fromRGB(230, 250, 255) },
	{ Id = "Crystalis", Name = "Crystalis", Rarity = "Mythic", Egg = "CrystalPeaks", Color = Color3.fromRGB(120, 255, 255) },
	-- Rainbow Core
	{ Id = "Glimmer", Name = "Glimmer", Rarity = "Common", Egg = "RainbowCore", Color = Color3.fromRGB(255, 240, 180) },
	{ Id = "Spark", Name = "Spark", Rarity = "Rare", Egg = "RainbowCore", Color = Color3.fromRGB(255, 180, 60) },
	{ Id = "Aurora", Name = "Aurora", Rarity = "Epic", Egg = "RainbowCore", Color = Color3.fromRGB(140, 255, 210) },
	{ Id = "Celestia", Name = "Celestia", Rarity = "Legendary", Egg = "RainbowCore", Color = Color3.fromRGB(200, 200, 255) },
	{ Id = "Prismo", Name = "Prismo", Rarity = "Mythic", Egg = "RainbowCore", Color = Color3.fromRGB(255, 120, 200) },
	-- Récompense du 7e jour
	{ Id = "Starbub", Name = "Starbub", Rarity = "Mythic", Egg = "Daily", Color = Color3.fromRGB(255, 230, 90) },
	-- Événement Halloween 2026 (œuf de Pumpkin Patch)
	{ Id = "Pumpkid", Name = "Pumpkid", Rarity = "Common", Egg = "PumpkinPatch", Color = Color3.fromRGB(255, 150, 50) },
	{ Id = "Batty", Name = "Batty", Rarity = "Rare", Egg = "PumpkinPatch", Color = Color3.fromRGB(110, 70, 150) },
	{ Id = "Spookle", Name = "Spookle", Rarity = "Epic", Egg = "PumpkinPatch", Color = Color3.fromRGB(235, 240, 255) },
	{ Id = "Candlewick", Name = "Candlewick", Rarity = "Legendary", Egg = "PumpkinPatch", Color = Color3.fromRGB(255, 220, 120) },
	{ Id = "Hauntix", Name = "Hauntix", Rarity = "Mythic", Egg = "PumpkinPatch", Color = Color3.fromRGB(150, 255, 120) },
}

return Companions
