--!strict
-- Popaint : LISTE DES QUÊTES (3 affichées en même temps, remplacées dès qu'une est finie).
--
-- AJOUTER UNE QUÊTE : une ligne. Id unique, TextKey = son texte dans Locale.luau ({n} = l'objectif).
--   Type = ce qu'il faut faire (types existants, déjà branchés dans le jeu) :
--     PopBubbles, PaintStuds, EarnCoins, PopCascade, PopHigh, BuyUpgrades, OpenEggs, TrainSeconds
--   Zone (facultatif) = ne compte que dans cette zone (fonctionne avec PopBubbles et PaintStuds).
--   Event (facultatif) = la quête n'apparaît que pendant cet événement (voir Events.luau).
--   Reward est multiplié par la valeur des studs de la meilleure zone du joueur.

export type QuestDef = {
	Id: string,
	Type: string,
	TextKey: string,
	Target: number,
	Reward: number,
	Zone: string?,
	Event: string?,
}

local Quests: { QuestDef } = {
	{ Id = "PopBubbles", Type = "PopBubbles", TextKey = "Q_PopBubbles", Target = 40, Reward = 120 },
	{ Id = "PaintStuds", Type = "PaintStuds", TextKey = "Q_PaintStuds", Target = 250, Reward = 150 },
	{ Id = "EarnCoins", Type = "EarnCoins", TextKey = "Q_EarnCoins", Target = 300, Reward = 150 },
	{ Id = "PopCascade", Type = "PopCascade", TextKey = "Q_PopCascade", Target = 10, Reward = 180 },
	{ Id = "PopHigh", Type = "PopHigh", TextKey = "Q_PopHigh", Target = 8, Reward = 160 },
	{ Id = "BuyUpgrades", Type = "BuyUpgrades", TextKey = "Q_BuyUpgrades", Target = 2, Reward = 120 },
	{ Id = "OpenEggs", Type = "OpenEggs", TextKey = "Q_OpenEggs", Target = 1, Reward = 200 },
	{ Id = "TrainSeconds", Type = "TrainSeconds", TextKey = "Q_TrainSeconds", Target = 30, Reward = 150 },
	-- Événement Halloween 2026
	{ Id = "PopInPumpkin", Type = "PopBubbles", TextKey = "Q_PopInPumpkin", Target = 60, Reward = 400,
		Zone = "PumpkinPatch", Event = "Halloween2026" },
	{ Id = "PaintPumpkin", Type = "PaintStuds", TextKey = "Q_PaintPumpkin", Target = 400, Reward = 450,
		Zone = "PumpkinPatch", Event = "Halloween2026" },
}

return Quests
