--!strict
-- Popaint : LE DESIGN SYSTEM (couleurs, polices, arrondis, reliefs, durées).
--
-- Ce fichier est la copie, en code, du design system « Popaint » créé par Tom dans Claude Design.
-- Il est lu par le jeu (interface, couleurs de peinture) ET par le générateur de map (lobby).
-- Pour changer le style du jeu, c'est ICI qu'on touche : tout le reste suit.
--
-- Deux thèmes d'interface : "dark" (Nuit, par défaut) et "light" (Jour). Le joueur choisit.

export type ThemeColors = {
	Bg: Color3, -- fond des fenêtres
	BgRaised: Color3, -- cartes et panneaux posés dessus
	BgSunken: Color3, -- rails de barres, creux
	Ink: Color3, -- texte principal
	InkMuted: Color3, -- texte secondaire
	Edge: Color3, -- contour cartoon épais + ombre dure
}

local Design = {}

local rgb = Color3.fromRGB

---------------------------------------------------------------- Thèmes d'interface
Design.Themes = {
	dark = {
		Name = "Nuit",
		Bg = rgb(22, 11, 38),
		BgRaised = rgb(36, 19, 61),
		BgSunken = rgb(15, 7, 25),
		Ink = rgb(255, 247, 236),
		InkMuted = rgb(201, 184, 230),
		Edge = rgb(11, 5, 20),
	},
	light = {
		Name = "Jour",
		Bg = rgb(255, 244, 224),
		BgRaised = rgb(255, 255, 255),
		BgSunken = rgb(245, 230, 200),
		Ink = rgb(27, 14, 46),
		InkMuted = rgb(91, 74, 114),
		Edge = rgb(27, 14, 46),
	},
}
Design.DefaultTheme = "dark"
Design.ThemeOrder = { "dark", "light" }

---------------------------------------------------------------- Les six peintures
-- Chaque peinture a une face « deep » : c'est elle qui donne le relief 3D (face latérale).
Design.Paints = {
	{ Id = "pink", Color = rgb(255, 46, 136), Deep = rgb(184, 16, 92) },
	{ Id = "yellow", Color = rgb(255, 214, 10), Deep = rgb(201, 154, 0) },
	{ Id = "cyan", Color = rgb(24, 216, 255), Deep = rgb(10, 141, 176) },
	{ Id = "lime", Color = rgb(124, 255, 79), Deep = rgb(58, 168, 28) },
	{ Id = "orange", Color = rgb(255, 122, 26), Deep = rgb(184, 77, 0) },
	{ Id = "violet", Color = rgb(166, 107, 255), Deep = rgb(104, 52, 184) },
}

-- Raccourcis par nom
Design.Paint = {}
Design.Deep = {}
for _, p in Design.Paints do
	Design.Paint[p.Id] = p.Color
	Design.Deep[p.Id] = p.Deep
end

-- Texte posé sur une peinture claire (jaune, cyan, lime, orange)
Design.OnPaint = rgb(27, 14, 46)
Design.Danger = rgb(255, 59, 59)
Design.Success = Design.Paint.lime

---------------------------------------------------------------- Polices
-- « Bungee » n'existe pas dans Roblox : Luckiest Guy est la plus proche (grosse, cartoon, capitales).
Design.FontDisplay = "LuckiestGuy" -- titres, boutons, score (toujours en capitales)
Design.FontText = "Nunito" -- texte courant, bien rond et lisible

---------------------------------------------------------------- Arrondis (en pixels)
Design.Radius = {
	sm = 10, -- badges, petites puces
	md = 18, -- boutons
	lg = 28, -- cartes, fenêtres
	pill = 999, -- barres de progression, toasts
}

---------------------------------------------------------------- Relief « jouet » : ombres dures, sans flou
Design.Depth = {
	sm = 4, -- badges, petits boutons
	md = 8, -- boutons au repos
	lg = 14, -- cartes qui flottent
}
Design.PressDrop = 6 -- de combien un bouton s'enfonce quand on appuie
Design.StrokeThickness = 3 -- contour cartoon

---------------------------------------------------------------- Durées d'animation (en secondes)
Design.Duration = {
	Tap = 0.09, -- enfoncement d'un bouton
	Pop = 0.42, -- apparition élastique
	Float = 3.2, -- flottement en boucle
}

return Design
