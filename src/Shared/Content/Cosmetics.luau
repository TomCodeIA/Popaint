--!strict
-- Popaint : LISTE DES COSMÉTIQUES (traînées), achetées avec les pièces à sa machine à bulles.
-- Elles n'apportent aucun avantage de jeu : c'est purement esthétique.
--
-- AJOUTER UNE TRAÎNÉE : une ligne. Colors = les couleurs du dégradé (2 ou plus).
--   Event (facultatif) = achetable seulement pendant cet événement (la garder ensuite pour ceux qui l'ont).
--   Animated = les couleurs défilent en boucle.
-- ⚠ Ne supprime jamais une traînée qui a déjà été en vente : des joueurs la possèdent.

export type CosmeticDef = {
	Id: string,
	Name: string,
	Cost: number,
	Colors: { Color3 },
	Animated: boolean?,
	Event: string?,
}

local Cosmetics: { CosmeticDef } = {
	{ Id = "BubbleGum", Name = "Bubble Gum", Cost = 500,
		Colors = { Color3.fromRGB(255, 150, 210), Color3.fromRGB(255, 255, 255) } },
	{ Id = "Ocean", Name = "Ocean", Cost = 3000,
		Colors = { Color3.fromRGB(150, 214, 250), Color3.fromRGB(120, 170, 240) } },
	{ Id = "Mint", Name = "Mint", Cost = 15000,
		Colors = { Color3.fromRGB(180, 240, 210), Color3.fromRGB(120, 210, 180) } },
	{ Id = "Sunset", Name = "Sunset", Cost = 80000,
		Colors = { Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 170, 130), Color3.fromRGB(250, 150, 190) } },
	{ Id = "Galaxy", Name = "Galaxy", Cost = 600000,
		Colors = { Color3.fromRGB(130, 110, 190), Color3.fromRGB(200, 170, 250), Color3.fromRGB(255, 255, 255) } },
	{ Id = "Rainbow", Name = "Rainbow", Cost = 5000000, Animated = true,
		Colors = {
			Color3.fromRGB(255, 160, 200), Color3.fromRGB(255, 220, 130), Color3.fromRGB(160, 230, 180),
			Color3.fromRGB(150, 206, 250), Color3.fromRGB(196, 170, 250),
		} },
	-- Événement Halloween 2026
	{ Id = "Spooky", Name = "Spooky", Cost = 2500, Event = "Halloween2026", Animated = true,
		Colors = { Color3.fromRGB(255, 186, 130), Color3.fromRGB(170, 140, 210), Color3.fromRGB(190, 240, 170) } },
}

return Cosmetics
