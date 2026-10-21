--!strict
-- Popaint : œufs, compagnons, équipement, fusion et bonus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Formulas = require(Shared:WaitForChild("Formulas")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local DataService = require(script.Parent:WaitForChild("DataService")) :: any
local ActionRouter = require(script.Parent:WaitForChild("ActionRouter")) :: any
local ZoneAccess = require(script.Parent:WaitForChild("ZoneAccess")) :: any
local Bus = require(script.Parent:WaitForChild("Bus")) :: any

local CompanionService = {}

local rng = Random.new()
local bonusCache: { [Player]: any } = {}

type Companion = { Uid: number, Id: string, Tier: number }

local function data(player: Player): { [string]: any }?
	local profile = DataService.get(player)
	return if profile then profile.Data else nil
end

local function find(list: { Companion }, uid: number): (Companion?, number?)
	for i, c in list do
		if c.Uid == uid then
			return c, i
		end
	end
	return nil, nil
end

local function isEquipped(d: { [string]: any }, uid: number): boolean
	return table.find(d.Equipped, uid) ~= nil
end

-- Bonus total des compagnons équipés : { Coins, Radius, AutoPops }
function CompanionService.bonuses(player: Player): any
	local cached = bonusCache[player]
	if cached then
		return cached
	end
	local d = data(player)
	local list = {}
	if d then
		for _, uid in d.Equipped do
			local c = find(d.Companions, uid)
			local def = c and Config.Companions[c.Id]
			if c and def then
				local base = Config.RarityBonus[def.Rarity] or {}
				table.insert(list, Formulas.companionBonus(base, def.Power, Config.TierMultipliers[c.Tier] or 1))
			end
		end
	end
	local total = Formulas.sumBonuses(list)
	bonusCache[player] = total
	return total
end

local function changed(player: Player)
	bonusCache[player] = nil
	local d = data(player)
	if d then
		-- Liste des compagnons équipés pour l'affichage (chaque client les fait suivre le joueur)
		local shown = {}
		for _, uid in d.Equipped do
			local c = find(d.Companions, uid)
			if c then
				table.insert(shown, c.Id .. ":" .. tostring(c.Tier))
			end
		end
		player:SetAttribute("Pets", table.concat(shown, ","))
	end
	DataService.markDirty(player)
end
CompanionService.changed = changed

-- Ajoute un compagnon. Retourne le compagnon, ou nil si l'inventaire est plein.
function CompanionService.give(player: Player, id: string, tier: number?): Companion?
	local d = data(player)
	if not d or not Config.Companions[id] then
		return nil
	end
	if #d.Companions >= Config.InventorySize then
		Remotes.event("Notify"):FireClient(player, "InventoryFull", nil, "error")
		return nil
	end
	local c: Companion = { Uid = d.NextUid, Id = id, Tier = tier or 0 }
	d.NextUid += 1
	table.insert(d.Companions, c)
	-- Équipé automatiquement s'il reste de la place
	if #d.Equipped < CompanionService.maxEquipped(player) then
		table.insert(d.Equipped, c.Uid)
	end
	changed(player)
	return c
end

function CompanionService.maxEquipped(player: Player): number
	local extra = player:GetAttribute("ExtraPetSlot")
	return Config.MaxEquipped + (if extra == true then 1 else 0)
end

-- Tire un compagnon dans l'œuf d'une zone
function CompanionService.roll(zoneId: string, roll: number?): string?
	local contents = Config.EggContents[zoneId]
	if not contents then
		return nil
	end
	local chances = {}
	for _, r in Config.Rarities do
		for _, id in contents do
			if Config.Companions[id].Rarity == r.Id then
				table.insert(chances, { id, r.Chance })
			end
		end
	end
	return Formulas.pickWeighted(chances, roll or rng:NextNumber())
end

-- Ouvre un œuf. free = payé par une récompense (didacticiel, cadeau quotidien)
function CompanionService.openEgg(player: Player, zoneId: any, free: boolean?): boolean
	if type(zoneId) ~= "string" then
		return false
	end
	local zone = Config.zone(zoneId)
	local d = data(player)
	if not zone or not d then
		return false
	end
	if not ZoneAccess.hasZone(player, zoneId) then
		Remotes.event("Notify"):FireClient(player, "EggLocked", { zone = zone.DisplayKey }, "error")
		return false
	end
	if #d.Companions >= Config.InventorySize then
		Remotes.event("Notify"):FireClient(player, "InventoryFull", nil, "error")
		return false
	end
	local isFree = free == true or (d.Tutorial.Step == table.find(Config.TutorialSteps, "OpenEgg"))
	if not isFree and not DataService.spendCoins(player, ZoneAccess.eggCost(player, zone)) then
		Remotes.event("Notify"):FireClient(player, "NotEnough", nil, "error")
		return false
	end
	local id = CompanionService.roll(zoneId)
	if not id then
		return false
	end
	local c = CompanionService.give(player, id, 0)
	if not c then
		return false
	end
	d.Stats.EggsOpened += 1
	Remotes.event("Effect"):FireClient(player, "Hatched", { Id = id, Zone = zoneId })
	Bus.emit("EggOpened", player, id)
	return true
end

function CompanionService.equip(player: Player, uid: any)
	local d = data(player)
	if not d or type(uid) ~= "number" then
		return
	end
	if not find(d.Companions, uid) or isEquipped(d, uid) then
		return
	end
	if #d.Equipped >= CompanionService.maxEquipped(player) then
		table.remove(d.Equipped, 1) -- remplace le plus ancien
	end
	table.insert(d.Equipped, uid)
	changed(player)
end

function CompanionService.unequip(player: Player, uid: any)
	local d = data(player)
	if not d or type(uid) ~= "number" then
		return
	end
	local i = table.find(d.Equipped, uid)
	if i then
		table.remove(d.Equipped, i)
		changed(player)
	end
end

function CompanionService.delete(player: Player, uid: any)
	local d = data(player)
	if not d or type(uid) ~= "number" then
		return
	end
	local _, index = find(d.Companions, uid)
	if index then
		table.remove(d.Companions, index)
		local e = table.find(d.Equipped, uid)
		if e then
			table.remove(d.Equipped, e)
		end
		changed(player)
	end
end

-- Fusion : 3 compagnons identiques (même espèce, même rang) -> 1 du rang supérieur
function CompanionService.fuse(player: Player, uid: any): boolean
	local d = data(player)
	if not d or type(uid) ~= "number" then
		return false
	end
	local base = find(d.Companions, uid)
	if not base or base.Tier >= 2 then
		return false
	end
	local same = { base.Uid }
	for _, c in d.Companions do
		if #same >= Config.FuseCount then
			break
		end
		if c.Uid ~= base.Uid and c.Id == base.Id and c.Tier == base.Tier then
			table.insert(same, c.Uid)
		end
	end
	if #same < Config.FuseCount then
		return false
	end
	local wasEquipped = false
	for _, u in same do
		local _, index = find(d.Companions, u)
		if index then
			table.remove(d.Companions, index)
		end
		local e = table.find(d.Equipped, u)
		if e then
			table.remove(d.Equipped, e)
			wasEquipped = true
		end
	end
	local newC: Companion = { Uid = d.NextUid, Id = base.Id, Tier = base.Tier + 1 }
	d.NextUid += 1
	table.insert(d.Companions, newC)
	if wasEquipped or #d.Equipped < CompanionService.maxEquipped(player) then
		table.insert(d.Equipped, newC.Uid)
	end
	changed(player)
	Remotes.event("Effect"):FireClient(player, "Fused", { Id = base.Id, Tier = newC.Tier })
	return true
end

function CompanionService.start()
	DataService.onLoaded(function(player: Player, profile: any)
		local d = profile.Data
		-- Nettoyage : équipés qui n'existent plus, doublons, trop d'équipés
		local clean = {}
		for _, uid in d.Equipped do
			if find(d.Companions, uid) and not table.find(clean, uid) and #clean < CompanionService.maxEquipped(player) then
				table.insert(clean, uid)
			end
		end
		d.Equipped = clean
		changed(player)
	end)
	DataService.onLeaving(function(player: Player)
		bonusCache[player] = nil
	end)

	ActionRouter.register("Equip", CompanionService.equip)
	ActionRouter.register("Unequip", CompanionService.unequip)
	ActionRouter.register("DeletePet", CompanionService.delete)
	ActionRouter.register("Fuse", function(player: Player, uid: any)
		CompanionService.fuse(player, uid)
	end)
	ActionRouter.register("OpenEgg", function(player: Player, zoneId: any)
		CompanionService.openEgg(player, zoneId, false)
	end)

	-- Œufs du hub : une invite "Ouvrir" sur chaque œuf
	local eggs = workspace:WaitForChild("Map"):FindFirstChild("Eggs")
	if eggs then
		for _, egg in eggs:GetChildren() do
			local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt then
				(prompt :: ProximityPrompt).Triggered:Connect(function(player: Player)
					CompanionService.openEgg(player, egg.Name, false)
				end)
			end
		end
	end
end

return CompanionService
