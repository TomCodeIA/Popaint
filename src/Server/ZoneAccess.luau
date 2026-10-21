--!strict
-- Popaint : déblocage des zones (portails) et protection contre l'entrée sans les avoir payées.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local DataService = require(script.Parent:WaitForChild("DataService")) :: any
local ZoneService = require(script.Parent:WaitForChild("ZoneService")) :: any
local ActionRouter = require(script.Parent:WaitForChild("ActionRouter")) :: any
local Bus = require(script.Parent:WaitForChild("Bus")) :: any
local EventService = require(script.Parent:WaitForChild("EventService")) :: any

local ZoneAccess = {}

-- Le joueur peut-il jouer dans cette zone ? (zone d'événement : ouverte à tous pendant l'événement)
function ZoneAccess.hasZone(player: Player, zoneId: string): boolean
	local profile = DataService.get(player)
	if not profile then
		return false
	end
	local zone = Config.zone(zoneId)
	if zone and zone.Event then
		return EventService.isActive(zone.Event)
	end
	return profile.Data.Zones[zoneId] == true
end

-- Meilleure zone normale débloquée (sert à adapter les récompenses)
function ZoneAccess.bestZone(player: Player): any
	local best = Config.MainZones[1]
	for _, z in Config.MainZones do
		if ZoneAccess.hasZone(player, z.Id) then
			best = z
		end
	end
	return best
end

-- Valeur d'un stud pour ce joueur dans cette zone (les zones d'événement suivent sa progression)
function ZoneAccess.studValue(player: Player, zone: any): number
	if zone.StudValueScale then
		return ZoneAccess.bestZone(player).StudValue * zone.StudValueScale
	end
	return zone.StudValue
end

-- Prix de l'œuf d'une zone pour ce joueur
function ZoneAccess.eggCost(player: Player, zone: any): number
	if zone.EggScale then
		return zone.EggCost * ZoneAccess.bestZone(player).StudValue
	end
	return zone.EggCost
end

-- Les zones normales se débloquent dans l'ordre
local function previousZone(zoneId: string): string?
	for i, z in Config.MainZones do
		if z.Id == zoneId then
			return if i > 1 then Config.MainZones[i - 1].Id else nil
		end
	end
	return nil
end

function ZoneAccess.unlock(player: Player, zoneId: any): boolean
	if type(zoneId) ~= "string" then
		return false
	end
	local zone = Config.zone(zoneId)
	local profile = DataService.get(player)
	if not zone or not profile or zone.Event or ZoneAccess.hasZone(player, zoneId) then
		return false
	end
	local prev = previousZone(zoneId)
	if prev and not ZoneAccess.hasZone(player, prev) then
		local prevZone = Config.zone(prev)
		Remotes.event("Notify"):FireClient(player, "EggLocked", { zone = prevZone and prevZone.DisplayKey or prev }, "error")
		return false
	end
	if not DataService.spendCoins(player, zone.Cost) then
		Remotes.event("Notify"):FireClient(player, "NotEnough", nil, "error")
		return false
	end
	profile.Data.Zones[zoneId] = true
	Remotes.event("Effect"):FireClient(player, "ZoneUnlocked", { Zone = zoneId })
	Bus.emit("ZoneUnlocked", player, zoneId)
	DataService.markDirty(player)
	return true
end

local function hubSpawn(): CFrame
	local spawn = workspace:WaitForChild("Map"):WaitForChild("Hub"):FindFirstChild("Spawn")
	if spawn and spawn:IsA("BasePart") then
		return (spawn :: BasePart).CFrame + Vector3.new(0, 4, 0)
	end
	return CFrame.new(0, 5, 20)
end

function ZoneAccess.start()
	ActionRouter.register("UnlockZone", function(player: Player, zoneId: any)
		ZoneAccess.unlock(player, zoneId)
	end)

	-- Portails : une invite "Débloquer" sur chaque portail
	local gates = workspace:WaitForChild("Map"):FindFirstChild("Gates")
	if gates then
		for _, gate in gates:GetChildren() do
			local prompt = gate:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt then
				(prompt :: ProximityPrompt).Triggered:Connect(function(player: Player)
					ZoneAccess.unlock(player, gate.Name)
				end)
			end
		end
	end

	-- Un joueur dans une zone qu'il n'a pas débloquée est renvoyé au hub
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") and DataService.get(player) then
					local rootPart = root :: BasePart
					local zone = ZoneService.zoneAt(rootPart.CFrame.Position)
					if zone and not ZoneAccess.hasZone(player, zone.Id) then
						rootPart.CFrame = hubSpawn()
						Remotes.event("Notify"):FireClient(player, "Locked", nil, "error")
					end
				end
			end
		end
	end)
end

return ZoneAccess
