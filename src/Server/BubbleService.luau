--!strict
-- Popaint : bulles de chaque joueur.
-- Le serveur décide où apparaissent les bulles et valide chaque éclatement.
-- Une bulle éclate quand le personnage la touche (contact), ou toute seule (machine AFK,
-- compagnons). Le client annonce les contacts pour que ce soit instantané, le serveur vérifie.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Formulas = require(Shared:WaitForChild("Formulas")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local DataService = require(script.Parent:WaitForChild("DataService")) :: any
local ZoneService = require(script.Parent:WaitForChild("ZoneService")) :: any
local ZoneAccess = require(script.Parent:WaitForChild("ZoneAccess")) :: any
local UpgradeService = require(script.Parent:WaitForChild("UpgradeService")) :: any
local CompanionService = require(script.Parent:WaitForChild("CompanionService")) :: any
local StormService = require(script.Parent:WaitForChild("StormService")) :: any
local Bus = require(script.Parent:WaitForChild("Bus")) :: any

local BubbleService = {}

export type Kind = "low" | "high" | "cascade"

type Bubble = {
	Id: number,
	Position: Vector3,
	Size: number,
	Radius: number,
	ZoneId: string,
	Kind: string,
	Storm: boolean,
	ExpiresAt: number,
}

type PlayerState = {
	Bubbles: { [number]: Bubble },
	Count: number,
	NextId: number,
	SpawnTimer: number,
	AfkTimer: number,
	PetTimers: { number },
	PopWindowStart: number,
	PopsInWindow: number,
	ColorIndex: number,
}

local states: { [Player]: PlayerState } = {}
local rng = Random.new()

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return (root :: BasePart).CFrame.Position
	end
	return nil
end

local function paintColor(state: PlayerState): Color3
	return Config.PaintPalette[state.ColorIndex] or Config.PaintPalette[1]
end

local E = Config.UpgradeEffects

local function contactRadius(player: Player): number
	return E.contactRadius(UpgradeService.level(player, "Magnet"))
end
BubbleService.contactRadius = contactRadius

-- Multiplicateur de pièces hors zone (améliorations, compagnons, boost, storm)
function BubbleService.coinMultiplier(player: Player): number
	local mult = E.valueMultiplier(UpgradeService.level(player, "Value"))
	mult *= 1 + CompanionService.bonuses(player).Coins
	local profile = DataService.get(player)
	if profile and profile.Data.Boosts.CoinsUntil > os.time() then
		mult *= Config.BoostMultiplier
	end
	if player:GetAttribute("Premium") == true then
		mult *= 1.1
	end
	return mult
end

local function addBubble(player: Player, state: PlayerState, position: Vector3, kind: string, zoneId: string)
	local maxBubbles = E.maxBubbles(UpgradeService.level(player, "Production"))
	if state.Count >= maxBubbles + (if kind == "cascade" then Config.CascadeMax else 0) then
		return
	end
	state.NextId += 1
	local id = state.NextId
	local size = if kind == "cascade" then Config.CascadeBubbleSize else Config.BubbleSize
	local radius = E.paintRadius(UpgradeService.level(player, "Size")) * (1 + CompanionService.bonuses(player).Radius)
	if kind == "cascade" then
		radius *= Config.CascadeRadiusFactor
	end
	local storm = StormService.isActive()
	state.Bubbles[id] = {
		Id = id,
		Position = position,
		Size = size,
		Radius = radius,
		ZoneId = zoneId,
		Kind = kind,
		Storm = storm,
		ExpiresAt = os.clock() + Config.BubbleLifetime,
	}
	state.Count += 1
	Remotes.event("BubbleSpawned"):FireAllClients(player.UserId, id, position, size, state.ColorIndex, kind, storm)
end

local function removeBubble(state: PlayerState, id: number): Bubble?
	local bubble = state.Bubbles[id]
	if bubble then
		state.Bubbles[id] = nil
		state.Count -= 1
	end
	return bubble
end

-- Éclate une bulle (déjà validée). how = "touch" | "afk" | "pet"
local function popBubble(player: Player, state: PlayerState, bubble: Bubble, how: string)
	local zone = ZoneService.get(bubble.ZoneId)
	local tiles = 0
	local coins = 0
	if zone then
		tiles = ZoneService.paint(zone, player.UserId, bubble.Position.X, bubble.Position.Z, bubble.Radius, paintColor(state))
		local mult = BubbleService.coinMultiplier(player) * ZoneService.multiplier(zone)
		-- Rainbow Storm : tout éclatement pendant le storm (et les bulles arc-en-ciel restantes) vaut x3
		if bubble.Storm or StormService.isActive() then
			mult *= Config.StormMultiplier
		end
		if bubble.Kind == "high" then
			mult *= Config.HighBubbleValue
		end
		local zoneDef = Config.zone(bubble.ZoneId)
		coins = Formulas.popReward(tiles, if zoneDef then ZoneAccess.studValue(player, zoneDef) else zone.StudValue, mult)
	end
	DataService.addStat(player, "BubblesPopped", 1)
	if tiles > 0 then
		DataService.addStat(player, "StudsPainted", tiles)
	end
	if bubble.Kind == "cascade" then
		DataService.addStat(player, "CascadePopped", 1)
	elseif bubble.Kind == "high" then
		DataService.addStat(player, "HighPopped", 1)
	end
	if coins > 0 then
		DataService.addCoins(player, coins)
	end
	Remotes.event("BubblePopped"):FireAllClients(player.UserId, bubble.Id, bubble.Position, state.ColorIndex, tiles, coins,
		how ~= "touch", bubble.Kind)
	Bus.emit("Popped", player, { Kind = bubble.Kind, Tiles = tiles, Coins = coins, How = how, Zone = bubble.ZoneId })

	-- Cascade : une bulle (pas déjà une cascade) peut libérer plusieurs petites bulles
	local chance = E.cascadeChance(UpgradeService.level(player, "Cascade"))
	if zone and bubble.Kind ~= "cascade" and rng:NextNumber() < chance then
		local n = rng:NextInteger(Config.CascadeMin, Config.CascadeMax)
		for _ = 1, n do
			local p = ZoneService.randomPointNear(zone, bubble.Position, 3, 9, Config.LowBubbleMinHeight, Config.LowBubbleMaxHeight)
			if p then
				addBubble(player, state, p, "cascade", zone.Id)
			end
		end
	end
end

local function onPop(player: Player, id: any)
	local state = states[player]
	if not state or type(id) ~= "number" then
		return
	end
	local now = os.clock()
	if now - state.PopWindowStart >= 1 then
		state.PopWindowStart = now
		state.PopsInWindow = 0
	end
	state.PopsInWindow += 1
	if state.PopsInWindow > Config.MaxPopsPerSecond then
		return
	end
	local bubble = state.Bubbles[id]
	if not bubble then
		return
	end
	local root = rootPosition(player)
	local reach = contactRadius(player) + bubble.Size / 2 + Config.ContactTolerance
	if not root or (root - bubble.Position).Magnitude > reach then
		return
	end
	removeBubble(state, id)
	popBubble(player, state, bubble, "touch")
end

local function nearestBubble(state: PlayerState, center: Vector3?, maxDist: number?): Bubble?
	local best: Bubble? = nil
	local bestScore = math.huge
	for _, bubble in state.Bubbles do
		local score: number
		if center then
			score = (bubble.Position - center).Magnitude
			if maxDist and score > maxDist then
				continue
			end
		else
			score = bubble.ExpiresAt
		end
		if score < bestScore then
			bestScore = score
			best = bubble
		end
	end
	return best
end

local function update(dt: number)
	local now = os.clock()
	for player, state in states do
		-- Bulles expirées
		for id, bubble in state.Bubbles do
			if now >= bubble.ExpiresAt then
				removeBubble(state, id)
				Remotes.event("BubbleRemoved"):FireAllClients(player.UserId, id)
			end
		end

		local root = rootPosition(player)
		local zone = if root then ZoneService.zoneAt(root) else nil
		if zone and not ZoneAccess.hasZone(player, zone.Id) then
			zone = nil
		end

		-- Contact : le corps (et l'aimant) touche une bulle
		if root then
			local reach = contactRadius(player)
			-- on liste d'abord (éclater peut créer des bulles de cascade pendant le parcours)
			local touched = {}
			for _, bubble in state.Bubbles do
				if (root - bubble.Position).Magnitude <= reach + bubble.Size / 2 then
					table.insert(touched, bubble)
				end
			end
			for _, bubble in touched do
				if state.Bubbles[bubble.Id] then
					removeBubble(state, bubble.Id)
					popBubble(player, state, bubble, "touch")
				end
			end
		end

		-- Nouvelles bulles quand le joueur est dans une zone débloquée
		local interval = E.spawnInterval(UpgradeService.level(player, "Production"))
		if StormService.isActive() then
			interval *= Config.StormSpawnFactor
		end
		state.SpawnTimer += dt
		if state.SpawnTimer >= interval then
			state.SpawnTimer = 0
			if zone and root then
				local high = rng:NextNumber() < Config.HighBubbleChance
				local p = ZoneService.randomPointNear(zone, root, Config.BubbleMinDistance, Config.BubbleMaxDistance,
					if high then Config.HighBubbleMinHeight else Config.LowBubbleMinHeight,
					if high then Config.HighBubbleMaxHeight else Config.LowBubbleMaxHeight)
				if p then
					addBubble(player, state, p, if high then "high" else "low", zone.Id)
				end
			end
		end

		-- Machine AFK : éclate la plus vieille bulle
		state.AfkTimer += dt
		if state.AfkTimer >= E.afkInterval(UpgradeService.level(player, "Afk")) then
			state.AfkTimer = 0
			local oldest = nearestBubble(state, nil, nil)
			if oldest then
				removeBubble(state, oldest.Id)
				popBubble(player, state, oldest, "afk")
			end
		end

		-- Compagnons épiques : éclatent une bulle proche régulièrement
		local autoPops = CompanionService.bonuses(player).AutoPops
		for i, every in autoPops do
			state.PetTimers[i] = (state.PetTimers[i] or 0) + dt
			if state.PetTimers[i] >= every then
				state.PetTimers[i] = 0
				local target = nearestBubble(state, root, 30)
				if target then
					removeBubble(state, target.Id)
					popBubble(player, state, target, "pet")
				end
			end
		end
	end
end

local function clearAll(player: Player, state: PlayerState)
	for id in state.Bubbles do
		Remotes.event("BubbleRemoved"):FireAllClients(player.UserId, id)
	end
	table.clear(state.Bubbles)
	state.Count = 0
end

function BubbleService.start()
	DataService.onLoaded(function(player: Player, profile: any)
		local data = profile.Data
		if type(data.PaintColor) ~= "number" or data.PaintColor < 1 or data.PaintColor > #Config.PaintPalette then
			data.PaintColor = rng:NextInteger(1, #Config.PaintPalette)
		end
		player:SetAttribute("PaintColor", data.PaintColor)
		states[player] = {
			Bubbles = {},
			Count = 0,
			NextId = 0,
			SpawnTimer = 0,
			AfkTimer = 0,
			PetTimers = {},
			PopWindowStart = 0,
			PopsInWindow = 0,
			ColorIndex = data.PaintColor,
		}
		player.CharacterAdded:Connect(function()
			local s = states[player]
			if s then
				clearAll(player, s)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local state = states[player]
		if state then
			clearAll(player, state)
			states[player] = nil
		end
	end)

	Remotes.event("PopBubble").OnServerEvent:Connect(onPop)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local dt = now - last
			last = now
			local ok, err = pcall(update :: any, dt)
			if not ok then
				warn("[Popaint] erreur bulles : " .. tostring(err))
			end
		end
	end)
end

return BubbleService
