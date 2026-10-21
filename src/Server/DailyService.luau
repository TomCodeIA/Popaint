--!strict
-- Popaint : cadeau quotidien sur 7 jours (un jour manqué = retour au jour 1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Formulas = require(Shared:WaitForChild("Formulas")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local DataService = require(script.Parent:WaitForChild("DataService")) :: any
local ActionRouter = require(script.Parent:WaitForChild("ActionRouter")) :: any
local ZoneAccess = require(script.Parent:WaitForChild("ZoneAccess")) :: any
local CompanionService = require(script.Parent:WaitForChild("CompanionService")) :: any

local DailyService = {}

local function today(): number
	return Formulas.dayNumber(os.time())
end

-- (peut réclamer ?, jour 1..7)
function DailyService.status(player: Player): (boolean, number)
	local profile = DataService.get(player)
	if not profile then
		return false, 1
	end
	local d = profile.Data.Daily
	return Formulas.daily(d.LastClaimDay, d.Streak, today(), #Config.Daily)
end

function DailyService.claim(player: Player): boolean
	local profile = DataService.get(player)
	if not profile then
		return false
	end
	local can, day = DailyService.status(player)
	if not can then
		return false
	end
	local d = profile.Data.Daily
	local reward = Config.Daily[day]
	local studValue = ZoneAccess.bestZone(player).StudValue
	-- Le compagnon exclusif et l'œuf ont besoin de place dans l'inventaire
	if (reward.Kind == "Companion" or reward.Kind == "Egg") and #profile.Data.Companions >= Config.InventorySize then
		Remotes.event("Notify"):FireClient(player, "InventoryFull", nil, "error")
		return false
	end
	d.Streak = if day == 1 then 1 else d.Streak + 1
	d.LastClaimDay = today()
	if reward.Kind == "Coins" then
		DataService.addCoins(player, reward.Amount * studValue)
	elseif reward.Kind == "Boost" then
		local boosts = profile.Data.Boosts
		boosts.CoinsUntil = math.max(boosts.CoinsUntil, os.time()) + reward.Seconds
	elseif reward.Kind == "Egg" then
		CompanionService.openEgg(player, ZoneAccess.bestZone(player).Id, true)
	elseif reward.Kind == "Companion" then
		CompanionService.give(player, reward.Id, 0)
		Remotes.event("Effect"):FireClient(player, "Hatched", { Id = reward.Id, Zone = "Daily" })
	end
	Remotes.event("Effect"):FireClient(player, "DailyClaimed", { Day = day })
	DataService.markDirty(player)
	return true
end

function DailyService.start()
	ActionRouter.register("ClaimDaily", function(player: Player)
		DailyService.claim(player)
	end)
end

return DailyService
