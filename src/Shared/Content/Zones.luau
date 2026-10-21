--!strict
-- Popaint : LISTE DES ZONES.
-- Ce fichier est lu à la fois par le jeu et par le générateur de map (tools/build.luau).
--
-- AJOUTER UNE ZONE (mise à jour de contenu) :
--   1. Ajoute une entrée à la fin de la liste (l'ordre = l'ordre de déblocage).
--   2. Cell : sa case sur la grille du monde. Le hub est en { 0, 0 } ; { 0, -1 } est au nord du hub,
--      { 1, 0 } à l'est, { -1, 0 } à l'ouest, { 0, 1 } au sud. Une case = 186 studs.
--   3. From : la zone (ou "Hub") d'où part le pont. Sa case doit toucher celle de la nouvelle zone.
--   4. Shape / Centerpiece / Theme : formes et décors disponibles dans tools/build.luau
--      (Shapes : Circle, Octagon, SCanyon, Star, Ring, Pumpkin, Diamond, Cross).
--   5. Ajoute ses textes (Zone_<Id>) dans Locale.luau et ses compagnons dans Companions.luau.
--   Les tests vérifient tout automatiquement (case libre, pont valide, textes dans les 5 langues...).
--
-- ZONE D'ÉVÉNEMENT : mets Event = "<Id de l'événement>" (voir Events.luau). Elle est gratuite,
-- ouverte seulement pendant l'événement, et ses gains suivent la meilleure zone du joueur.

export type ZoneDef = {
	Id: string,
	Name: string, -- texte de l'arche d'entrée (toujours en anglais, c'est un nom propre)
	DisplayKey: string, -- texte traduit (Locale)
	Cost: number,
	StudValue: number,
	EggCost: number,
	EggPower: number, -- force des compagnons de son œuf
	Color: Color3, -- couleur principale (portail, mini-map, brume)
	Platform: Color3,
	Cell: { number },
	From: string,
	Shape: string,
	Centerpiece: string,
	Theme: string,
	Event: string?,
	StudValueScale: number?, -- zones d'événement : valeur = meilleure zone du joueur x ce nombre
	EggScale: boolean?, -- zones d'événement : prix de l'œuf x valeur de la meilleure zone du joueur
}

local Zones: { ZoneDef } = {
	{
		Id = "CandyMeadow", Name = "CANDY MEADOW", DisplayKey = "Zone_CandyMeadow",
		Cost = 0, StudValue = 1, EggCost = 150, EggPower = 1,
		Color = Color3.fromRGB(255, 92, 168), Platform = Color3.fromRGB(255, 205, 225),
		Cell = { 0, -1 }, From = "Hub", Shape = "Circle", Centerpiece = "GiantCandy", Theme = "Candy",
	},
	{
		Id = "NeonDocks", Name = "NEON DOCKS", DisplayKey = "Zone_NeonDocks",
		Cost = 5000, StudValue = 3, EggCost = 2500, EggPower = 1.6,
		Color = Color3.fromRGB(82, 215, 255), Platform = Color3.fromRGB(40, 40, 90),
		Cell = { -1, 0 }, From = "Hub", Shape = "Octagon", Centerpiece = "Lighthouse", Theme = "Neon",
	},
	{
		Id = "JellyCanyon", Name = "JELLY CANYON", DisplayKey = "Zone_JellyCanyon",
		Cost = 75000, StudValue = 10, EggCost = 40000, EggPower = 2.4,
		Color = Color3.fromRGB(120, 255, 140), Platform = Color3.fromRGB(150, 230, 140),
		Cell = { 1, 0 }, From = "Hub", Shape = "SCanyon", Centerpiece = "JellyCubes", Theme = "Jelly",
	},
	{
		Id = "CrystalPeaks", Name = "CRYSTAL PEAKS", DisplayKey = "Zone_CrystalPeaks",
		Cost = 1000000, StudValue = 35, EggCost = 600000, EggPower = 3.5,
		Color = Color3.fromRGB(170, 220, 255), Platform = Color3.fromRGB(200, 230, 255),
		Cell = { 0, 1 }, From = "Hub", Shape = "Star", Centerpiece = "GiantCrystal", Theme = "Crystal",
	},
	{
		Id = "RainbowCore", Name = "RAINBOW CORE", DisplayKey = "Zone_RainbowCore",
		Cost = 20000000, StudValue = 120, EggCost = 10000000, EggPower = 5,
		Color = Color3.fromRGB(255, 214, 64), Platform = Color3.fromRGB(255, 255, 255),
		Cell = { 0, -2 }, From = "CandyMeadow", Shape = "Ring", Centerpiece = "FloatingIsland", Theme = "Rainbow",
	},

	---------------------------------------------------------------- zones d'événement
	{
		Id = "PumpkinPatch", Name = "PUMPKIN PATCH", DisplayKey = "Zone_PumpkinPatch",
		Cost = 0, StudValue = 1, EggCost = 200, EggPower = 2.4,
		Color = Color3.fromRGB(255, 140, 40), Platform = Color3.fromRGB(70, 40, 90),
		Cell = { 1, 1 }, From = "JellyCanyon", Shape = "Pumpkin", Centerpiece = "GiantPumpkin", Theme = "Spooky",
		Event = "Halloween2026", StudValueScale = 1.5, EggScale = true,
	},
}

return Zones
