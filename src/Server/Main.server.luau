--!strict
-- Popaint : point d'entrée du serveur. Démarre chaque service dans le bon ordre.

local ServerFolder = script.Parent

local function load(name: string): any
	return require(ServerFolder:WaitForChild(name)) :: any
end

-- L'ordre compte : les services qui réagissent au chargement d'un joueur doivent être
-- démarrés AVANT DataService (qui charge les joueurs).
local ORDER = {
	"TerrainService",
	"ActionRouter",
	"EventService",
	"ZoneService",
	"ZoneAccess",
	"StormService",
	"UpgradeService",
	"CompanionService",
	"BubbleService",
	"QuestService",
	"DailyService",
	"ProgressService",
	"TrainService",
	"CosmeticService",
	"LookService",
	"StateService",
	"BaseService",
	"DataService",
}

for _, name in ORDER do
	local ok, err = pcall(function()
		load(name).start()
	end)
	if not ok then
		warn(("[Popaint] le service %s n'a pas démarré : %s"):format(name, tostring(err)))
	end
end

print("[Popaint] serveur prêt")
