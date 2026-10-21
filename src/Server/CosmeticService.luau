--!strict
-- Popaint : cosmétiques (traînées) achetés à sa machine avec les pièces. Aucun avantage de jeu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local DataService = require(script.Parent:WaitForChild("DataService")) :: any
local UpgradeService = require(script.Parent:WaitForChild("UpgradeService")) :: any
local EventService = require(script.Parent:WaitForChild("EventService")) :: any
local ActionRouter = require(script.Parent:WaitForChild("ActionRouter")) :: any

local CosmeticService = {}

local function sequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	return ColorSequence.new(keys)
end

-- Ajoute (ou retire) la traînée sur le personnage du joueur
function CosmeticService.apply(player: Player)
	local profile = DataService.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not profile or not root then
		return
	end
	local old = root:FindFirstChild("PopaintTrail")
	if old then
		old:Destroy()
	end
	for _, name in { "TrailTop", "TrailBottom" } do
		local a = root:FindFirstChild(name)
		if a then
			a:Destroy()
		end
	end
	local def = Config.cosmetic(profile.Data.EquippedTrail)
	player:SetAttribute("Trail", if def then def.Id else "")
	if not def then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 0.8, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -1.6, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "PopaintTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = sequence(def.Colors)
	trail.Lifetime = 0.7
	trail.LightEmission = 0.6
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail:SetAttribute("Animated", def.Animated == true)
	trail.Parent = root
end

local function owned(profile: any, id: string): boolean
	return profile.Data.Cosmetics[id] == true
end

function CosmeticService.buy(player: Player, id: any): boolean
	if type(id) ~= "string" then
		return false
	end
	local def = Config.cosmetic(id)
	local profile = DataService.get(player)
	if not def or not profile or owned(profile, id) then
		return false
	end
	if def.Event and not EventService.isActive(def.Event) then
		return false
	end
	if not UpgradeService.atMachine(player) then
		Remotes.event("Notify"):FireClient(player, "MachineTooFar", nil, "error")
		return false
	end
	if not DataService.spendCoins(player, def.Cost) then
		Remotes.event("Notify"):FireClient(player, "NotEnough", nil, "error")
		return false
	end
	profile.Data.Cosmetics[id] = true
	profile.Data.EquippedTrail = id
	CosmeticService.apply(player)
	Remotes.event("Effect"):FireClient(player, "CosmeticBought", { Id = id })
	DataService.markDirty(player)
	return true
end

-- id = "" pour retirer la traînée
function CosmeticService.equip(player: Player, id: any)
	local profile = DataService.get(player)
	if not profile or type(id) ~= "string" then
		return
	end
	if id ~= "" and (not Config.cosmetic(id) or not owned(profile, id)) then
		return
	end
	profile.Data.EquippedTrail = id
	CosmeticService.apply(player)
	DataService.markDirty(player)
end

function CosmeticService.start()
	ActionRouter.register("BuyCosmetic", function(player: Player, id: any)
		CosmeticService.buy(player, id)
	end)
	ActionRouter.register("EquipCosmetic", CosmeticService.equip)
	DataService.onLoaded(function(player: Player, profile: any)
		-- traînée équipée qui n'existe plus ou n'est pas possédée : retirée
		local id = profile.Data.EquippedTrail
		if id ~= "" and (not Config.cosmetic(id) or not owned(profile, id)) then
			profile.Data.EquippedTrail = ""
		end
		CosmeticService.apply(player)
		player.CharacterAdded:Connect(function(character: Model)
			character:WaitForChild("HumanoidRootPart", 10)
			CosmeticService.apply(player)
		end)
	end)
	local _ = Players
end

return CosmeticService
