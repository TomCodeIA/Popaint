--!strict
-- Popaint : envoie à chaque joueur l'état dont son interface a besoin, quand il change
-- (au plus 4 fois par seconde, pour ne pas surcharger le réseau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Formulas = require(Shared:WaitForChild("Formulas")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local DataService = require(script.Parent:WaitForChild("DataService")) :: any
local UpgradeService = require(script.Parent:WaitForChild("UpgradeService")) :: any
local CompanionService = require(script.Parent:WaitForChild("CompanionService")) :: any
local DailyService = require(script.Parent:WaitForChild("DailyService")) :: any
local BubbleService = require(script.Parent:WaitForChild("BubbleService")) :: any
local Bus = require(script.Parent:WaitForChild("Bus")) :: any
local ActionRouter = require(script.Parent:WaitForChild("ActionRouter")) :: any
local ZoneAccess = require(script.Parent:WaitForChild("ZoneAccess")) :: any

local StateService = {}

local dirty: { [Player]: boolean } = {}

function StateService.build(player: Player): { [string]: any }?
	local profile = DataService.get(player)
	if not profile then
		return nil
	end
	local d = profile.Data
	local upgrades = {}
	for _, def in Config.Upgrades do
		local lvl = UpgradeService.level(player, def.Id)
		upgrades[def.Id] = { Level = lvl, Max = def.MaxLevel, Cost = UpgradeService.cost(def.Id, lvl) or 0 }
	end
	local companions = {}
	for _, c in d.Companions do
		table.insert(companions, { Uid = c.Uid, Id = c.Id, Tier = c.Tier })
	end
	local quests = {}
	for _, q in d.Quests do
		table.insert(quests, { Id = q.Id, Target = q.Target, Progress = q.Progress, Reward = q.Reward })
	end
	local canClaim, day = DailyService.status(player)
	local bonuses = CompanionService.bonuses(player)
	return {
		Coins = d.Coins,
		Level = Formulas.level(d.Stats, Config.LevelDivisor),
		LevelProgress = Formulas.levelProgress(d.Stats, Config.LevelDivisor),
		Upgrades = upgrades,
		Zones = (function()
			local zones = table.clone(d.Zones)
			for _, z in Config.Zones do
				if z.Event then
					zones[z.Id] = ZoneAccess.hasZone(player, z.Id) or nil
				end
			end
			return zones
		end)(),
		EggCosts = (function()
			local costs = {}
			for _, z in Config.Zones do
				costs[z.Id] = ZoneAccess.eggCost(player, z)
			end
			return costs
		end)(),
		Cosmetics = table.clone(d.Cosmetics),
		EquippedTrail = d.EquippedTrail,
		Companions = companions,
		Equipped = table.clone(d.Equipped),
		MaxEquipped = CompanionService.maxEquipped(player),
		PetBonus = { Coins = bonuses.Coins, Radius = bonuses.Radius, AutoPops = #bonuses.AutoPops },
		Quests = quests,
		Daily = { CanClaim = canClaim, Day = day, Streak = d.Daily.Streak },
		Tutorial = { Step = Config.TutorialSteps[d.Tutorial.Step], Pops = d.Tutorial.Pops },
		BoostUntil = d.Boosts.CoinsUntil,
		ContactRadius = BubbleService.contactRadius(player),
		Speed = UpgradeService.walkSpeed(player),
		TrainPoints = d.Stats.TrainPoints or 0,
		TrainRate = Config.TreadmillRates[math.clamp(UpgradeService.level(player, "Treadmill") + 1, 1, #Config.TreadmillRates)],
		Multiplier = BubbleService.coinMultiplier(player),
		Language = d.Settings.Language,
		Theme = d.Settings.Theme or "dark",
	}
end

local function push(player: Player)
	local state = StateService.build(player)
	if state then
		Remotes.event("State"):FireClient(player, state)
	end
end
StateService.push = push

function StateService.start()
	-- Le joueur choisit son thème d'interface (Nuit / Jour) : on le garde dans sa sauvegarde.
	ActionRouter.register("SetTheme", function(player: Player, name: any)
		if name ~= "dark" and name ~= "light" then
			return
		end
		local profile = DataService.get(player)
		if not profile then
			return
		end
		profile.Data.Settings.Theme = name
		DataService.markDirty(player)
		Bus.emit("Dirty", player)
	end)
	Bus.on("Dirty", function(player: Player)
		dirty[player] = true
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		dirty[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player in dirty do
				dirty[player] = nil
				if player.Parent then
					push(player)
				end
			end
		end
	end)
	-- Le boost et le cadeau du jour changent avec le temps : rafraîchissement régulier
	task.spawn(function()
		while true do
			task.wait(15)
			for _, player in Players:GetPlayers() do
				dirty[player] = true
			end
		end
	end)
end

return StateService
