--!strict
-- Popaint : améliorations achetées à sa machine à bulles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Formulas = require(Shared:WaitForChild("Formulas")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local DataService = require(script.Parent:WaitForChild("DataService")) :: any
local ActionRouter = require(script.Parent:WaitForChild("ActionRouter")) :: any
local Bus = require(script.Parent:WaitForChild("Bus")) :: any

local UpgradeService = {}

function UpgradeService.level(player: Player, id: string): number
	local profile = DataService.get(player)
	if not profile then
		return 0
	end
	local lvl = profile.Data.Upgrades[id]
	return if type(lvl) == "number" then lvl else 0
end

function UpgradeService.cost(id: string, level: number): number?
	local def = Config.upgrade(id)
	if not def or level >= def.MaxLevel then
		return nil
	end
	return Formulas.upgradeCost(def.BaseCost, level, def.Growth or Config.UpgradeCostGrowth)
end

local function machinePosition(player: Player): Vector3?
	local baseName = player:GetAttribute("BaseName")
	if type(baseName) ~= "string" then
		return nil
	end
	local base = workspace:WaitForChild("Map"):WaitForChild("Hub"):WaitForChild("Bases"):FindFirstChild(baseName)
	local machine = base and base:FindFirstChild("MachineBody")
	if machine and machine:IsA("BasePart") then
		return (machine :: BasePart).CFrame.Position
	end
	return nil
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return (root :: BasePart).CFrame.Position
	end
	return nil
end

local function notify(player: Player, key: string, kind: string?)
	Remotes.event("Notify"):FireClient(player, key, nil, kind or "error")
end

-- Le joueur est-il à sa machine ? (les achats de la boutique ne se font que là)
function UpgradeService.atMachine(player: Player): boolean
	local machine = machinePosition(player)
	local root = rootPosition(player)
	return machine ~= nil and root ~= nil and (machine - root).Magnitude <= Config.MachineReach
end

-- Retourne true si l'achat est fait
function UpgradeService.buy(player: Player, id: any): boolean
	if type(id) ~= "string" then
		return false
	end
	local def = Config.upgrade(id)
	local profile = DataService.get(player)
	if not def or not profile then
		return false
	end
	-- Il faut être à sa machine (protection contre les achats à distance par un tricheur)
	local machine = machinePosition(player)
	local root = rootPosition(player)
	if not machine or not root or (machine - root).Magnitude > Config.MachineReach then
		notify(player, "MachineTooFar")
		return false
	end
	local level = UpgradeService.level(player, id)
	local price = UpgradeService.cost(id, level)
	if not price then
		return false
	end
	if not DataService.spendCoins(player, price) then
		notify(player, "NotEnough")
		return false
	end
	profile.Data.Upgrades[id] = level + 1
	Bus.emit("UpgradeBought", player, id, level + 1)
	Remotes.event("Effect"):FireClient(player, "Upgraded", { Id = id, Level = level + 1 })
	DataService.markDirty(player)
	return true
end

-- Vitesse totale : amélioration "Speed" + bonus d'entraînement sur le tapis
function UpgradeService.walkSpeed(player: Player): number
	local profile = DataService.get(player)
	local points = if profile then profile.Data.Stats.TrainPoints or 0 else 0
	return Config.UpgradeEffects.walkSpeed(UpgradeService.level(player, "Speed")) + Config.UpgradeEffects.trainSpeed(points)
end

-- Applique la vitesse au personnage
function UpgradeService.applySpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		(humanoid :: Humanoid).WalkSpeed = UpgradeService.walkSpeed(player)
	end
end

function UpgradeService.start()
	ActionRouter.register("BuyUpgrade", function(player: Player, id: any)
		UpgradeService.buy(player, id)
	end)
	DataService.onLoaded(function(player: Player)
		UpgradeService.applySpeed(player)
		player.CharacterAdded:Connect(function(character: Model)
			character:WaitForChild("Humanoid", 10)
			UpgradeService.applySpeed(player)
		end)
	end)
	Bus.on("UpgradeBought", function(player: Player, id: string)
		if id == "Speed" or id == "Treadmill" then
			UpgradeService.applySpeed(player)
		end
	end)
	ActionRouter.register("OpenedShop", function(player: Player)
		Bus.emit("OpenedShop", player)
	end)
end

return UpgradeService
