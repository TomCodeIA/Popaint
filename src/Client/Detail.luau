--!strict
-- Popaint : affiche les petits détails du décor seulement de près (comme une « distance de rendu »).
-- Chaque objet de la map peut avoir un sous-modèle "Details" (voir tools/map/lib.luau : lib.details) :
-- ses pièces sont cachées chez le joueur au-delà d'une distance qui dépend de la qualité, ce qui garde le jeu fluide sur téléphone.

local RunService = game:GetService("RunService")
local Quality = require(script.Parent:WaitForChild("Quality")) :: any

local Detail = {}

-- la distance dépend de la qualité (src/Client/Quality.luau)
local DETAIL_DISTANCE = 140
local HYSTERESIS = 12 -- évite le clignotement à la limite

type Group = { Model: Instance, Parts: { BasePart }, Center: Vector3?, Hidden: boolean, Count: number }

local groups: { [Instance]: Group } = {}
local list: { Group } = {}

local function collect(g: Group)
	local parts = {}
	local sum = Vector3.zero
	for _, d in g.Model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d :: BasePart)
			sum += (d :: BasePart).CFrame.Position
		end
	end
	g.Parts = parts
	g.Count = #parts
	g.Center = if #parts > 0 then sum / #parts else nil
	for _, p in parts do
		p.LocalTransparencyModifier = if g.Hidden then 1 else 0
	end
end

local function track(inst: Instance)
	if inst.Name ~= "Details" or not inst:IsA("Model") or groups[inst] then
		return
	end
	local g: Group = { Model = inst, Parts = {}, Center = nil, Hidden = false, Count = 0 }
	groups[inst] = g
	table.insert(list, g)
	collect(g)
end

local function untrack(inst: Instance)
	local g = groups[inst]
	if g then
		groups[inst] = nil
		local i = table.find(list, g)
		if i then
			table.remove(list, i)
		end
	end
end

-- Nombre de groupes vérifiés par image (on fait le tour de tous en quelques images)
local PER_FRAME = 250
local cursor = 1

function Detail.start()
	local map = workspace:WaitForChild("Map")
	for _, d in map:GetDescendants() do
		track(d)
	end
	map.DescendantAdded:Connect(function(d: Instance)
		if d.Name == "Details" then
			track(d)
		elseif d:IsA("BasePart") then
			-- une pièce arrive (chargement progressif) : on recompte son groupe
			local parent = d.Parent
			while parent and parent ~= map do
				local g = groups[parent]
				if g then
					collect(g)
					break
				end
				parent = parent.Parent
			end
		end
	end)
	map.DescendantRemoving:Connect(untrack)

	RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera or #list == 0 then
			return
		end
		local eye = camera.CFrame.Position
		DETAIL_DISTANCE = Quality.settings().DetailDistance
		for _ = 1, math.min(PER_FRAME, #list) do
			if cursor > #list then
				cursor = 1
			end
			local g = list[cursor]
			cursor += 1
			local center = g.Center
			if center then
				local dist = (center - eye).Magnitude
				local hide = if g.Hidden then dist > DETAIL_DISTANCE - HYSTERESIS else dist > DETAIL_DISTANCE
				if hide ~= g.Hidden then
					g.Hidden = hide
					for _, p in g.Parts do
						p.LocalTransparencyModifier = if hide then 1 else 0
					end
				end
			end
		end
	end)
end

return Detail
