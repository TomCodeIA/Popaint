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
		Colors = { Color3.fromRGB(82, 215, 255), Color3.fromRGB(40, 120, 255) } },
	{ Id = "Mint", Name = "Mint", Cost = 15000,
		Colors = { Color3.fromRGB(150, 255, 200), Color3.fromRGB(60, 210, 160) } },
	{ Id = "Sunset", Name = "Sunset", Cost = 80000,
		Colors = { Color3.fromRGB(255, 214, 64), Color3.fromRGB(255, 120, 60), Color3.fromRGB(255, 70, 140) } },
	{ Id = "Galaxy", Name = "Galaxy", Cost = 600000,
		Colors = { Color3.fromRGB(60, 30, 140), Color3.fromRGB(186, 120, 255), Color3.fromRGB(255, 255, 255) } },
	{ Id = "Rainbow", Name = "Rainbow", Cost = 5000000, Animated = true,
		Colors = {
			Color3.fromRGB(255, 92, 168), Color3.fromRGB(255, 214, 64), Color3.fromRGB(120, 255, 140),
			Color3.fromRGB(82, 215, 255), Color3.fromRGB(186, 120, 255),
		} },
	-- Événement Halloween 2026
	{ Id = "Spooky", Name = "Spooky", Cost = 2500, Event = "Halloween2026", Animated = true,
		Colors = { Color3.fromRGB(255, 140, 40), Color3.fromRGB(110, 60, 160), Color3.fromRGB(150, 255, 120) } },
}

return Cosmetics
