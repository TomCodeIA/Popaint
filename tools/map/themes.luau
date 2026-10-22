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
		Layers = { rgb(250, 182, 212), rgb(255, 206, 226), rgb(255, 230, 242) },
		Cap = rgb(255, 255, 255), CapMaterial = M.SmoothPlastic, Mini = "Gummy",
		Terrain = "Grass", TerrainCap = "Sandstone",
		Islet = rgb(255, 208, 228),
		Land = { "Lollipop", "Lollipop", "CandyCane", "Gumdrop", "Gumdrop", "Donut", "Cupcake", "IceCream", "Macaron", "Tree", "Bush", "FlowerBed", "Windmill", "CandyCart" },
		Water = { "Duck", "Duck", "LilyPad", "Gumdrop", "Seashell", "Coral" },
		Sky = { "Cloud", "Balloon", "Kite" },
		Mist = rgb(255, 226, 240),
	},
	Neon = {
		Layers = { rgb(150, 170, 220), rgb(176, 196, 236), rgb(204, 220, 248) },
		Cap = rgb(176, 234, 250), CapMaterial = M.SmoothPlastic, Mini = "Lamp",
		Terrain = "Basalt", TerrainCap = "CrackedLava",
		Islet = rgb(186, 204, 240),
		Land = { "NeonTower", "NeonTower", "NeonTower", "Crane", "NeonSign", "NeonSign", "Lamp", "Rocks", "Bench" },
		Water = { "Boat", "Boat", "Buoy", "Buoy", "Seashell", "Coral" },
		Sky = { "Star" },
		Mist = rgb(206, 224, 255),
	},
	Jelly = {
		Layers = { rgb(160, 220, 170), rgb(186, 236, 190), rgb(214, 248, 214) },
		Cap = rgb(255, 196, 222), CapMaterial = M.Glass, Mini = "Gummy",
		Terrain = "LeafyGrass", TerrainCap = "Limestone",
		Islet = rgb(190, 238, 196),
		Land = { "JellyCube", "JellyCube", "GummyBear", "GummyBear", "Mushroom", "Mushroom", "JellyStack", "Bush", "Rocks" },
		Water = { "LilyPad", "LilyPad", "Duck", "JellyCube", "Coral" },
		Sky = { "Cloud", "Balloon" },
		Mist = rgb(222, 252, 226),
	},
	Crystal = {
		Layers = { rgb(180, 196, 232), rgb(200, 216, 244), rgb(224, 236, 255) },
		Cap = rgb(255, 255, 255), CapMaterial = M.Snow, Mini = "Crystal",
		Terrain = "Glacier", TerrainCap = "Snow",
		Islet = rgb(235, 245, 255),
		Land = { "Pine", "Pine", "Pine", "CrystalCluster", "CrystalCluster", "Snowman", "IceArch", "Rocks" },
		Water = { "CrystalCluster", "LilyPad" },
		Sky = { "Cloud", "Star" },
		Mist = rgb(220, 240, 255),
	},
	Rainbow = {
		Layers = lib.RAINBOW,
		Cap = rgb(255, 255, 255), CapMaterial = M.SmoothPlastic, Mini = "Flower",
		Terrain = "Sand", TerrainCap = "Salt",
		Islet = rgb(255, 250, 255),
		Land = { "RainbowFall", "Tree", "Flower", "Flower", "Star", "Cupcake", "Windmill", "FlowerBed", "Bush" },
		Water = { "Duck", "LilyPad", "Seashell" },
		Sky = { "Cloud", "Cloud", "Balloon", "Balloon", "Star", "Star", "Kite" },
		Mist = rgb(255, 240, 255),
	},
	Spooky = {
		Layers = { rgb(170, 150, 200), rgb(192, 172, 220), rgb(214, 196, 236) },
		Cap = rgb(255, 204, 160), CapMaterial = M.SmoothPlastic, Mini = "Pumpkin",
		Terrain = "Mud", TerrainCap = "Slate",
		Islet = rgb(186, 166, 214),
		Land = { "Pumpkin", "Pumpkin", "Pumpkin", "Tombstone", "Tombstone", "DeadTree", "DeadTree", "Candle", "Candle", "Rocks" },
		Water = { "Pumpkin", "Candle" },
		Sky = { "Ghost", "Ghost" },
		Mist = rgb(214, 196, 240),
	},
}
