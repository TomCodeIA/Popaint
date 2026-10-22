-- Popaint (générateur de map) : thèmes de décor (Theme dans Content/Zones.luau).
-- Chaque thème dit quoi poser AUTOUR de la zone (jamais dans la zone de jeu) :
--   Layers/Cap : couleurs des montagnes à studs ; Terrain/TerrainCap : matériaux des collines lisses
--   (leurs couleurs sont dans src/Server/TerrainService.luau) ; Islet : couleur des îlots ;
--   Land : objets posés sur les îlots ; Water : objets sur l'eau ; Sky : objets dans le ciel ;
--   Mist : couleur de la brume ; Air : particules qui flottent (voir lib.particles).
-- AJOUTER UN THÈME : copie un bloc, change les couleurs et la liste d'objets (noms dans props.luau).
local lib = require("./lib")
local rgb = lib.rgb
local M = lib.Enum.Material

return {
	Candy = {
		Air = { Kind = "Petals", Colors = { rgb(255, 196, 214), rgb(255, 255, 255), rgb(232, 196, 244) } },
		Layers = { rgb(250, 182, 212), rgb(255, 206, 226), rgb(255, 230, 242) },
		Cap = rgb(255, 255, 255), CapMaterial = M.SmoothPlastic, Mini = "Gummy",
		Terrain = "Grass", TerrainCap = "Sandstone",
		Islet = rgb(255, 208, 228),
		Land = { "Lollipop", "Lollipop", "CandyCane", "Gumdrop", "Gumdrop", "Donut", "Cupcake", "IceCream", "Macaron", "Tree", "Bush", "FlowerBed", "Windmill", "CandyCart", "Rabbit" },
		Water = { "Duck", "Duck", "LilyPad", "Gumdrop", "Seashell", "Coral", "Fish" },
		Sky = { "Cloud", "Balloon", "Kite", "Bird" },
		Mist = rgb(255, 226, 240),
	},
	Neon = {
		Air = { Kind = "Soap", Colors = { rgb(182, 218, 255), rgb(176, 234, 230), rgb(255, 255, 255) } },
		Layers = { rgb(150, 170, 220), rgb(176, 196, 236), rgb(204, 220, 248) },
		Cap = rgb(176, 234, 250), CapMaterial = M.SmoothPlastic, Mini = "Lamp",
		Terrain = "Basalt", TerrainCap = "CrackedLava",
		Islet = rgb(186, 204, 240),
		Land = { "NeonTower", "NeonTower", "NeonTower", "Crane", "NeonSign", "NeonSign", "Lamp", "Rocks", "Bench", "Crab" },
		Water = { "Boat", "Boat", "Buoy", "Buoy", "Seashell", "Coral", "Fish" },
		Sky = { "Star", "Bird" },
		Mist = rgb(206, 224, 255),
	},
	Jelly = {
		Air = { Kind = "Fireflies", Colors = { rgb(255, 236, 170), rgb(184, 238, 204) } },
		Layers = { rgb(160, 220, 170), rgb(186, 236, 190), rgb(214, 248, 214) },
		Cap = rgb(255, 196, 222), CapMaterial = M.Glass, Mini = "Gummy",
		Terrain = "LeafyGrass", TerrainCap = "Limestone",
		Islet = rgb(190, 238, 196),
		Land = { "JellyCube", "JellyCube", "GummyBear", "GummyBear", "Mushroom", "Mushroom", "JellyStack", "Bush", "Rocks", "Rabbit" },
		Water = { "LilyPad", "LilyPad", "Duck", "JellyCube", "Coral", "Fish" },
		Sky = { "Cloud", "Balloon", "Bird" },
		Mist = rgb(222, 252, 226),
	},
	Crystal = {
		Air = { Kind = "Snow", Colors = { rgb(255, 255, 255), rgb(206, 232, 255) } },
		Layers = { rgb(180, 196, 232), rgb(200, 216, 244), rgb(224, 236, 255) },
		Cap = rgb(255, 255, 255), CapMaterial = M.Snow, Mini = "Crystal",
		Terrain = "Glacier", TerrainCap = "Snow",
		Islet = rgb(235, 245, 255),
		Land = { "Pine", "Pine", "Pine", "CrystalCluster", "CrystalCluster", "Snowman", "IceArch", "Rocks", "Rabbit" },
		Water = { "CrystalCluster", "LilyPad", "Fish" },
		Sky = { "Cloud", "Star", "Bird" },
		Mist = rgb(220, 240, 255),
	},
	Rainbow = {
		Air = { Kind = "Dust", Colors = { rgb(255, 236, 170), rgb(255, 196, 214), rgb(206, 192, 255) } },
		Layers = lib.RAINBOW,
		Cap = rgb(255, 255, 255), CapMaterial = M.SmoothPlastic, Mini = "Flower",
		Terrain = "Sand", TerrainCap = "Salt",
		Islet = rgb(255, 250, 255),
		Land = { "RainbowFall", "Tree", "Flower", "Flower", "Star", "Cupcake", "Windmill", "FlowerBed", "Bush", "Rabbit" },
		Water = { "Duck", "LilyPad", "Seashell", "Fish" },
		Sky = { "Cloud", "Cloud", "Balloon", "Balloon", "Star", "Star", "Kite", "Bird" },
		Mist = rgb(255, 240, 255),
	},
	Spooky = {
		Air = { Kind = "Leaves", Colors = { rgb(255, 210, 178), rgb(232, 196, 244), rgb(180, 160, 210) } },
		Layers = { rgb(170, 150, 200), rgb(192, 172, 220), rgb(214, 196, 236) },
		Cap = rgb(255, 204, 160), CapMaterial = M.SmoothPlastic, Mini = "Pumpkin",
		Terrain = "Mud", TerrainCap = "Slate",
		Islet = rgb(186, 166, 214),
		Land = { "Pumpkin", "Pumpkin", "Pumpkin", "Tombstone", "Tombstone", "DeadTree", "DeadTree", "Candle", "Candle", "Rocks", "Crab" },
		Water = { "Pumpkin", "Candle", "Fish" },
		Sky = { "Ghost", "Ghost", "Bird" },
		Mist = rgb(214, 196, 240),
	},
}
