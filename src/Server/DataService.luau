--!strict
-- Popaint : gestion des données joueurs (chargement, autosave, départ, fermeture du serveur).

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Locale = require(Shared:WaitForChild("Locale")) :: any
local ProfileStore = require(script.Parent:WaitForChild("ProfileStore")) :: any
local Bus = require(script.Parent:WaitForChild("Bus")) :: any

local DataService = {}

-- Modèle des données d'un nouveau joueur. Ajouter une clé ici suffit : les anciens joueurs la
-- reçoivent automatiquement au prochain chargement.
DataService.Template = {
	Coins = 0,
	Stats = {
		StudsPainted = 0,
		BubblesPopped = 0,
		CoinsEarned = 0,
		CascadePopped = 0,
		HighPopped = 0,
		EggsOpened = 0,
		QuestsDone = 0,
		TrainPoints = 0,
		TrainSeconds = 0,
	},
	Upgrades = {}, -- { Production = 3, ... }
	Zones = { CandyMeadow = true },
	Companions = {}, -- liste de { Uid, Id, Tier }
	Equipped = {}, -- liste d'Uid
	NextUid = 1,
	Quests = {}, -- liste de { Id, Target, Progress, Reward }
	Cosmetics = {}, -- traînées possédées : { [Id] = true }
	EquippedTrail = "",
	Daily = { Streak = 0, LastClaimDay = 0 },
	Boosts = { CoinsUntil = 0 },
	Settings = { Language = "en", Music = 0.5, Sfx = 0.8, Shake = true, HighQuality = true },
	Tutorial = { Step = 1, Pops = 0 },
	PaintColor = 0, -- 0 = pas encore choisie
	LastOnline = 0,
}

type Profile = {
	Key: string,
	Data: { [string]: any },
	Active: boolean,
	Lost: boolean,
	LastSave: number,
}

local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (Player, Profile) -> () } = {}
local leavingCallbacks: { (Player, Profile) -> () } = {}
local store: any = nil
local memoryMode = false

-- Studio sans accès aux API : on joue quand même, sans sauvegarde.
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
		if RunService:IsStudio() then
			local testOk = pcall(function()
				(result :: any):GetAsync("__popaint_probe")
			end)
			if not testOk then
				store = nil
			end
		end
	end
	memoryMode = store == nil
	if memoryMode then
		warn("[Popaint] Sauvegarde désactivée (Studio sans accès aux API). Le jeu fonctionne en mode test.")
	end
end

local profileStore = ProfileStore.new({
	store = store,
	jobId = if game.JobId ~= "" then game.JobId else "studio-" .. tostring(math.random(1, 1e9)),
	now = os.time,
	wait = function(t: number)
		task.wait(t)
	end,
	template = DataService.Template,
	lockExpire = Config.SessionLockExpire,
	retries = Config.LoadRetries,
	retryDelay = Config.LoadRetryDelay,
	log = function(msg: string)
		warn(msg)
	end,
})

function DataService.isMemoryMode(): boolean
	return memoryMode
end

function DataService.get(player: Player): Profile?
	local p = profiles[player]
	if p and p.Active then
		return p
	end
	return nil
end

function DataService.onLoaded(callback: (Player, Profile) -> ())
	table.insert(loadedCallbacks, callback)
end

function DataService.onLeaving(callback: (Player, Profile) -> ())
	table.insert(leavingCallbacks, callback)
end

-- Prévient l'interface du joueur que ses données ont changé
function DataService.markDirty(player: Player)
	Bus.emit("Dirty", player)
end

local function syncCoins(player: Player, data: { [string]: any })
	player:SetAttribute("Coins", data.Coins)
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Coins")
	if coins and coins:IsA("NumberValue") then
		(coins :: NumberValue).Value = data.Coins
	end
end

local function setupLeaderstats(player: Player, profile: Profile)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = 1
	level.Parent = folder
	local coins = Instance.new("NumberValue")
	coins.Name = "Coins"
	coins.Value = profile.Data.Coins
	coins.Parent = folder
	folder.Parent = player
end

-- Ajoute des pièces gagnées en jouant. Met aussi à jour les statistiques et les quêtes.
function DataService.addCoins(player: Player, amount: number)
	local profile = DataService.get(player)
	if not profile or amount ~= amount or amount <= 0 then
		return
	end
	amount = math.floor(amount)
	local data = profile.Data
	data.Coins += amount
	data.Stats.CoinsEarned += amount
	syncCoins(player, data)
	Bus.emit("CoinsEarned", player, amount)
	DataService.markDirty(player)
end

-- Retire des pièces (achats). Retourne false si pas assez.
function DataService.spendCoins(player: Player, amount: number): boolean
	local profile = DataService.get(player)
	if not profile or amount ~= amount or amount < 0 then
		return false
	end
	if profile.Data.Coins < amount then
		return false
	end
	profile.Data.Coins -= amount
	syncCoins(player, profile.Data)
	DataService.markDirty(player)
	return true
end

function DataService.addStat(player: Player, stat: string, amount: number)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local stats = profile.Data.Stats
	if type(stats[stat]) == "number" then
		stats[stat] += amount
	end
end

function DataService.language(player: Player): string
	local profile = profiles[player]
	if profile then
		return profile.Data.Settings.Language
	end
	return "en"
end

local function onPlayerAdded(player: Player)
	local result, profile = profileStore:load("Player_" .. player.UserId)
	if not player.Parent then
		if profile then
			profileStore:save(profile, true)
		end
		return
	end
	if result ~= "ok" or not profile then
		local key = if result == "locked" then "KickLocked" else "KickLoadFail"
		player:Kick(Locale.get(DataService.language(player), key))
		return
	end
	profiles[player] = profile
	player:SetAttribute("Language", profile.Data.Settings.Language)
	player:SetAttribute("SaveOff", memoryMode)
	setupLeaderstats(player, profile)
	for _, cb in loadedCallbacks do
		local ok, err = pcall(cb :: any, player, profile)
		if not ok then
			warn("[Popaint] erreur au chargement : " .. tostring(err))
		end
	end
	-- "Coins" en dernier : le client attend cet attribut pour savoir que tout est prêt
	syncCoins(player, profile.Data)
	DataService.markDirty(player)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	for _, cb in leavingCallbacks do
		local ok, err = pcall(cb :: any, player, profile)
		if not ok then
			warn("[Popaint] erreur à la déconnexion : " .. tostring(err))
		end
	end
	profile.Data.LastOnline = os.time()
	profileStore:save(profile, true)
	profiles[player] = nil
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player, profile in profiles do
				if profile.Active then
					profile.Data.LastOnline = os.time()
					local ok = profileStore:save(profile, false)
					if profile.Lost then
						player:Kick(Locale.get(DataService.language(player), "KickLocked"))
					elseif not ok then
						warn("[Popaint] autosave ratée pour " .. player.Name .. ", nouvel essai au prochain cycle")
					end
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, profile in profiles do
			pending += 1
			task.spawn(function()
				profile.Data.LastOnline = os.time()
				profileStore:save(profile, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
