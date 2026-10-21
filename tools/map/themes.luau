-- Popaint (générateur de map) : thèmes de décor (Theme dans Content/Zones.luau).
-- Chaque thème dit quoi poser AUTOUR de la zone (jamais dans la zone de jeu) :
--   Layers/Cap : couleurs des montagnes à studs ; Terrain/TerrainCap : matériaux des collines lisses
--   (leurs couleurs sont dans src/Server/TerrainService.luau) ; Islet : couleur des îlots ;
--   Land : objets posés sur les îlots ; Water : objets sur l'eau ; Sky : objets dans le ciel ;
--   Mist : couleur de la brume.
-- AJOUTER UN THÈME : copie un bloc, change les couleurs et la liste d'objets (noms dans props.luau).
local lib = require("./lib")
local rgb = lib.rgb
local M = lib.Enum.Material

return {
	Candy = {
		Layers = { rgb(255, 150, 200), rgb(255, 190, 220), rgb(255, 225, 240) },
		Cap = rgb(255, 255, 255), CapMaterial = M.SmoothPlastic,
		Terrain = "Grass", TerrainCap = "Sandstone",
		Islet = rgb(255, 190, 225),
		Land = { "Lollipop", "Lollipop", "CandyCane", "Gumdrop", "Gumdrop", "Donut", "Cupcake", "IceCream", "Macaron", "Tree" },
		Water = { "Duck", "Duck", "LilyPad", "Gumdrop" },
		Sky = { "Cloud", "Balloon" },
		Mist = rgb(255, 210, 235),
	},
	Neon = {
		Layers = { rgb(45, 35, 95), rgb(60, 45, 120), rgb(80, 60, 150) },
		Cap = rgb(82, 215, 255), CapMaterial = M.Neon,
		Terrain = "Basalt", TerrainCap = "CrackedLava",
		Islet = rgb(50, 45, 100),
		Land = { "NeonTower", "NeonTower", "NeonTower", "Crane", "NeonSign", "NeonSign", "Lamp" },
		Water = { "Boat", "Boat", "Buoy", "Buoy" },
		Sky = { "Star" },
		Mist = rgb(140, 180, 255),
	},
	Jelly = {
		Layers = { rgb(110, 210, 100), rgb(150, 235, 120), rgb(200, 255, 170) },
		Cap = rgb(255, 140, 200), CapMaterial = M.Glass,
		Terrain = "LeafyGrass", TerrainCap = "Limestone",
		Islet = rgb(160, 235, 140),
		Land = { "JellyCube", "JellyCube", "GummyBear", "GummyBear", "Mushroom", "Mushroom", "JellyStack" },
		Water = { "LilyPad", "LilyPad", "Duck", "JellyCube" },
		Sky = { "Cloud", "Balloon" },
		Mist = rgb(200, 255, 200),
	},
	Crystal = {
		Layers = { rgb(140, 170, 210), rgb(175, 205, 235), rgb(215, 235, 255) },
		Cap = rgb(255, 255, 255), CapMaterial = M.Snow,
		Terrain = "Glacier", TerrainCap = "Snow",
		Islet = rgb(235, 245, 255),
		Land = { "Pine", "Pine", "Pine", "CrystalCluster", "CrystalCluster", "Snowman", "IceArch" },
		Water = { "CrystalCluster", "LilyPad" },
		Sky = { "Cloud", "Star" },
		Mist = rgb(220, 240, 255),
	},
	Rainbow = {
		Layers = lib.RAINBOW,
		Cap = rgb(255, 255, 255), CapMaterial = M.Neon,
		Terrain = "Sand", TerrainCap = "Salt",
		Islet = rgb(255, 250, 255),
		Land = { "RainbowFall", "Tree", "Flower", "Flower", "Star", "Cupcake" },
		Water = { "Duck", "LilyPad" },
		Sky = { "Cloud", "Cloud", "Balloon", "Balloon", "Star", "Star" },
		Mist = rgb(255, 240, 255),
	},
	Spooky = {
		Layers = { rgb(60, 35, 80), rgb(85, 50, 110), rgb(110, 70, 140) },
		Cap = rgb(255, 140, 40), CapMaterial = M.Neon,
		Terrain = "Mud", TerrainCap = "Slate",
		Islet = rgb(80, 55, 100),
		Land = { "Pumpkin", "Pumpkin", "Pumpkin", "Tombstone", "Tombstone", "DeadTree", "DeadTree", "Candle", "Candle" },
		Water = { "Pumpkin", "Candle" },
		Sky = { "Ghost", "Ghost" },
		Mist = rgb(170, 120, 210),
	},
}
