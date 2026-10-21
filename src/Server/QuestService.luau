--!strict
-- Popaint : 3 quêtes à l'écran en permanence. Une quête finie est récompensée et remplacée.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Formulas = require(Shared:WaitForChild("Formulas")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local DataService = require(script.Parent:WaitForChild("DataService")) :: any
local ZoneAccess = require(script.Parent:WaitForChild("ZoneAccess")) :: any
local Bus = require(script.Parent:WaitForChild("Bus")) :: any
local EventService = require(script.Parent:WaitForChild("EventService")) :: any

local QuestService = {}

local rng = Random.new()

type Quest = { Id: string, Target: number, Progress: number, Reward: number }

-- Crée une nouvelle quête différente de celles en cours
local function newQuest(player: Player, current: { Quest }): Quest
	local profile = DataService.get(player)
	local done = if profile then profile.Data.Stats.QuestsDone else 0
	local candidates = {}
	for _, def in Config.Quests do
		if def.Event and not EventService.isActive(def.Event) then
			continue
		end
		local taken = false
		for _, q in current do
			if q.Id == def.Id then
				taken = true
			end
		end
		if not taken then
			table.insert(candidates, def)
		end
	end
	if #candidates == 0 then
		for _, def in Config.Quests do
			if not def.Event then
				table.insert(candidates, def)
			end
		end
	end
	local def = candidates[rng:NextInteger(1, #candidates)]
	local studValue = ZoneAccess.bestZone(player).StudValue
	local target = Formulas.questTarget(def.Target, done, Config.QuestGrowth, Config.QuestGrowthCap)
	if def.Type == "EarnCoins" then
		target *= studValue -- gagner des pièces : objectif adapté à la zone
	end
	local reward = math.floor(def.Reward * studValue * (1 + Config.QuestGrowth * math.min(done, Config.QuestGrowthCap)))
	return { Id = def.Id, Target = target, Progress = 0, Reward = reward }
end

local function ensureQuests(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local quests = profile.Data.Quests
	-- nettoyage des quêtes invalides (ancienne version, données abîmées)
	for i = #quests, 1, -1 do
		local q = quests[i]
		local def = if type(q) == "table" then Config.quest(q.Id) else nil
		if not def or type(q.Target) ~= "number" or (def.Event and not EventService.isActive(def.Event)) then
			table.remove(quests, i)
		end
	end
	while #quests < Config.QuestCount do
		table.insert(quests, newQuest(player, quests))
	end
end

QuestService.ensure = ensureQuests

-- Fait avancer toutes les quêtes d'un type (zoneId : là où l'action a eu lieu, pour les quêtes de zone)
function QuestService.progress(player: Player, questType: string, amount: number, zoneId: string?)
	local profile = DataService.get(player)
	if not profile or amount <= 0 then
		return
	end
	local quests = profile.Data.Quests
	local changed = false
	for i, q in quests do
		local def = Config.quest(q.Id)
		local matches = def ~= nil and def.Type == questType and (def.Zone == nil or def.Zone == zoneId)
		if matches and q.Progress < q.Target then
			q.Progress = math.min(q.Target, q.Progress + amount)
			changed = true
			if q.Progress >= q.Target then
				profile.Data.Stats.QuestsDone += 1
				local reward = q.Reward
				quests[i] = newQuest(player, quests)
				Remotes.event("Effect"):FireClient(player, "QuestDone", { Id = q.Id, Reward = reward })
				-- les pièces de récompense ne comptent pas pour "gagner des pièces"
				profile.Data.Coins += reward
				profile.Data.Stats.CoinsEarned += reward
				player:SetAttribute("Coins", profile.Data.Coins)
				local ls = player:FindFirstChild("leaderstats")
				local coins = ls and ls:FindFirstChild("Coins")
				if coins and coins:IsA("NumberValue") then
					(coins :: NumberValue).Value = profile.Data.Coins
				end
				Bus.emit("QuestDone", player, q.Id)
			end
		end
	end
	if changed then
		DataService.markDirty(player)
	end
end

function QuestService.start()
	DataService.onLoaded(function(player: Player)
		ensureQuests(player)
	end)
	Bus.on("Popped", function(player: Player, info: any)
		QuestService.progress(player, "PopBubbles", 1, info.Zone)
		if info.Tiles > 0 then
			QuestService.progress(player, "PaintStuds", info.Tiles, info.Zone)
		end
		if info.Kind == "cascade" then
			QuestService.progress(player, "PopCascade", 1)
		elseif info.Kind == "high" then
			QuestService.progress(player, "PopHigh", 1)
		end
	end)
	Bus.on("CoinsEarned", function(player: Player, amount: number)
		QuestService.progress(player, "EarnCoins", amount)
	end)
	Bus.on("UpgradeBought", function(player: Player)
		QuestService.progress(player, "BuyUpgrades", 1)
	end)
	Bus.on("EggOpened", function(player: Player)
		QuestService.progress(player, "OpenEggs", 1)
	end)
	Bus.on("Trained", function(player: Player)
		QuestService.progress(player, "TrainSeconds", 1)
	end)
	-- début ou fin d'un événement : les quêtes sont mises à jour pour tout le monde
	local function refreshAll()
		for _, player in game:GetService("Players"):GetPlayers() do
			ensureQuests(player)
			DataService.markDirty(player)
		end
	end
	Bus.on("EventStarted", refreshAll)
	Bus.on("EventEnded", refreshAll)
end

return QuestService
