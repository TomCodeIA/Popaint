--!strict
-- Popaint : zones peignables (grille de studs, peinture, réinitialisations avec compte à rebours).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local PaintGrid = require(script.Parent:WaitForChild("PaintGrid")) :: any

local ZoneService = {}

type Zone = {
	Id: string,
	Folder: Instance,
	Grid: any,
	FloorY: number,
	StudValue: number,
	Tiles: { [number]: BasePart },
	Owners: { [number]: number },
	Heights: { [number]: number }, -- hauteur des collines peignables (0 = sol plat)
	PaintedCount: number,
	Total: number,
	Washing: boolean,
}

local zones: { [string]: Zone } = {}
local zoneList: { Zone } = {}
local rng = Random.new()

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function scheduleReset(zone: Zone)
	local delay = rng:NextNumber(Config.ZoneResetMin, Config.ZoneResetMax)
	zone.Folder:SetAttribute("ResetAt", serverNow() + delay)
	zone.Folder:SetAttribute("Washing", false)
end

local function buildZone(folder: Instance, zoneConfig: any): Zone?
	local tilesFolder = folder:FindFirstChild("Tiles")
	if not tilesFolder then
		warn("[Popaint] zone sans dossier Tiles : " .. folder.Name)
		return nil
	end
	local originX = folder:GetAttribute("OriginX")
	local originZ = folder:GetAttribute("OriginZ")
	local countX = folder:GetAttribute("CountX")
	local countZ = folder:GetAttribute("CountZ")
	local floorY = folder:GetAttribute("FloorY")
	if type(originX) ~= "number" or type(originZ) ~= "number" or type(countX) ~= "number"
		or type(countZ) ~= "number" or type(floorY) ~= "number" then
		warn("[Popaint] attributs de zone manquants : " .. folder.Name)
		return nil
	end
	local grid = PaintGrid.new(originX, originZ, Config.TileSize, countX, countZ)
	local zone: Zone = {
		Id = folder.Name,
		Folder = folder,
		Grid = grid,
		FloorY = floorY,
		StudValue = zoneConfig.StudValue,
		Tiles = {},
		Owners = {},
		Heights = {},
		PaintedCount = 0,
		Total = 0,
		Washing = false,
	}
	for _, tile in tilesFolder:GetChildren() do
		if tile:IsA("BasePart") then
			local part = tile :: BasePart
			local i = part:GetAttribute("I")
			local j = part:GetAttribute("J")
			if type(i) == "number" and type(j) == "number" then
				zone.Tiles[PaintGrid.key(grid, i, j)] = part
				local h = part:GetAttribute("H")
				if type(h) == "number" and h > 0 then
					zone.Heights[PaintGrid.key(grid, i, j)] = h
				end
				zone.Total += 1
				part.Color = Config.GreyColor
			end
		end
	end
	return zone
end

function ZoneService.start()
	local map = workspace:WaitForChild("Map")
	local zonesFolder = map:WaitForChild("Zones")
	for _, zoneConfig in Config.Zones do
		local folder = zonesFolder:FindFirstChild(zoneConfig.Id)
		if folder then
			local zone = buildZone(folder, zoneConfig)
			if zone then
				zones[zone.Id] = zone
				table.insert(zoneList, zone)
				scheduleReset(zone)
				folder:SetAttribute("Painted", 0)
			end
		else
			warn("[Popaint] zone absente de la map : " .. zoneConfig.Id)
		end
	end

	-- Boucle des réinitialisations
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, zone in zoneList do
				local resetAt = zone.Folder:GetAttribute("ResetAt")
				if not zone.Washing and type(resetAt) == "number" and serverNow() >= resetAt then
					task.spawn(ZoneService.wash, zone)
				end
			end
		end
	end)
end

-- Grande vague qui efface la zone, ligne par ligne.
function ZoneService.wash(zone: Zone)
	if zone.Washing then
		return
	end
	zone.Washing = true
	zone.Folder:SetAttribute("Washing", true)
	Remotes.event("ZoneReset"):FireAllClients(zone.Id)
	local grid = zone.Grid
	local stepDelay = Config.ResetWaveDuration / grid.CountX
	for i = 1, grid.CountX do
		for j = 1, grid.CountZ do
			local key = PaintGrid.key(grid, i, j)
			if zone.Owners[key] then
				zone.Owners[key] = nil
				local tile = zone.Tiles[key]
				if tile then
					tile.Color = Config.GreyColor
				end
			end
		end
		task.wait(stepDelay)
	end
	zone.PaintedCount = 0
	zone.Folder:SetAttribute("Painted", 0)
	zone.Washing = false
	scheduleReset(zone)
end

-- Zone dans laquelle se trouve une position (ou nil)
function ZoneService.zoneAt(position: Vector3): Zone?
	for _, zone in zoneList do
		if PaintGrid.contains(zone.Grid, position.X, position.Z)
			and position.Y > zone.FloorY - 5 and position.Y < zone.FloorY + 60 then
			return zone
		end
	end
	return nil
end

function ZoneService.get(id: string): Zone?
	return zones[id]
end

-- Multiplicateur actuel de la zone (x2 pendant le compte à rebours)
function ZoneService.multiplier(zone: Zone): number
	local resetAt = zone.Folder:GetAttribute("ResetAt")
	if type(resetAt) == "number" and resetAt - serverNow() <= Config.ZoneCountdown then
		return Config.CountdownMultiplier
	end
	return 1
end

-- Peint autour de (x, z). Seules les cases encore grises comptent.
-- Retourne le nombre de cases peintes.
function ZoneService.paint(zone: Zone, userId: number, x: number, z: number, radius: number, color: Color3): number
	if zone.Washing then
		return 0
	end
	local painted = 0
	for _, ij in PaintGrid.tilesInRadius(zone.Grid, x, z, radius) do
		local key = PaintGrid.key(zone.Grid, ij[1], ij[2])
		local tile = zone.Tiles[key]
		if tile and zone.Owners[key] == nil then
			zone.Owners[key] = userId
			tile.Color = color
			painted += 1
		end
	end
	if painted > 0 then
		zone.PaintedCount += painted
		local ratio = zone.PaintedCount / math.max(1, zone.Total)
		zone.Folder:SetAttribute("Painted", ratio)
		-- Zone presque pleine : on lance le compte à rebours sans attendre
		if ratio >= Config.ZoneFullThreshold then
			local resetAt = zone.Folder:GetAttribute("ResetAt")
			local soon = serverNow() + Config.ZoneCountdown
			if type(resetAt) ~= "number" or resetAt > soon then
				zone.Folder:SetAttribute("ResetAt", soon)
			end
		end
	end
	return painted
end

-- Hauteur du sol (collines comprises) en un point de la zone
function ZoneService.heightAt(zone: Zone, x: number, z: number): number
	local i, j = PaintGrid.tileAt(zone.Grid, x, z)
	if not i or not j then
		return 0
	end
	return zone.Heights[PaintGrid.key(zone.Grid, i, j)] or 0
end

-- La case sous (x, z) existe-t-elle ? (les zones ont des formes : rond, étoile, anneau...)
function ZoneService.hasTile(zone: Zone, x: number, z: number): boolean
	local i, j = PaintGrid.tileAt(zone.Grid, x, z)
	if not i or not j then
		return false
	end
	if zone.Tiles[PaintGrid.key(zone.Grid, i, j)] then
		return true
	end
	return false
end

-- Point au hasard au-dessus du sol de la zone, autour d'une position (nil si aucun trouvé)
function ZoneService.randomPointNear(zone: Zone, center: Vector3, minDist: number, maxDist: number, minH: number, maxH: number): Vector3?
	local grid = zone.Grid
	local margin = 2
	local minX, maxX = grid.OriginX + margin, grid.OriginX + grid.CountX * grid.TileSize - margin
	local minZ, maxZ = grid.OriginZ + margin, grid.OriginZ + grid.CountZ * grid.TileSize - margin
	for _ = 1, 12 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(minDist, maxDist)
		local x = math.clamp(center.X + math.cos(angle) * dist, minX, maxX)
		local z = math.clamp(center.Z + math.sin(angle) * dist, minZ, maxZ)
		if ZoneService.hasTile(zone, x, z) then
			return Vector3.new(x, zone.FloorY + ZoneService.heightAt(zone, x, z) + rng:NextNumber(minH, maxH), z)
		end
	end
	return nil
end

return ZoneService
