--!strict
-- Popaint : LISTE DES ÉVÉNEMENTS TEMPORAIRES.
--
-- AJOUTER UN ÉVÉNEMENT :
--   1. Une entrée ici : Id unique, dates de début et de fin en heure UTC { année, mois, jour, heure }.
--      L'événement est actif de Start (inclus) à End (exclu).
--   2. Sa zone dans Zones.luau (avec Event = "<Id>"), ses compagnons dans Companions.luau,
--      ses quêtes dans Quests.luau (Event = "<Id>"), ses traînées dans Cosmetics.luau (Event = "<Id>").
--   3. Ses textes dans Locale.luau : Ev_<Id> (nom de l'événement).
--   Dans Roblox Studio, tous les événements sont actifs pour pouvoir les tester
--   (Config.ForceEventsInStudio). Sur les vrais serveurs, seules les dates comptent.
--
-- APRÈS UN ÉVÉNEMENT : tu peux retirer sa zone, son entrée ici et ses quêtes à la mise à jour suivante.
--   ⚠ Garde ses compagnons et ses traînées dans leurs listes : des joueurs les possèdent.

export type EventDef = {
	Id: string,
	NameKey: string,
	Start: { number },
	End: { number },
	Color: Color3,
	Icon: string,
}

local Events: { EventDef } = {
	{
		Id = "Halloween2026",
		NameKey = "Ev_Halloween2026",
		Start = { 2026, 10, 24, 0 },
		End = { 2026, 11, 4, 0 },
		Color = Color3.fromRGB(255, 140, 40),
		Icon = "🎃",
	},
}

return Events
