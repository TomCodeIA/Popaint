--!strict
-- Popaint : sculpte les collines lisses (terrain Roblox) autour des zones au lancement du serveur.
-- Le plan (positions, tailles, matériaux) est rangé dans Map.TerrainPlan par le build de la map.

local TerrainService = {}

-- Couleurs des matériaux du terrain (une couleur par matériau, choisie selon la zone qui l'utilise)
local COLORS: { [string]: Color3 } = {
	Grass = Color3.fromRGB(250, 196, 222),
	Sandstone = Color3.fromRGB(255, 238, 200),
	Basalt = Color3.fromRGB(168, 182, 226),
	CrackedLava = Color3.fromRGB(190, 232, 248),
	LeafyGrass = Color3.fromRGB(176, 230, 180),
	Limestone = Color3.fromRGB(226, 248, 220),
	Glacier = Color3.fromRGB(200, 222, 250),
	Snow = Color3.fromRGB(255, 255, 255),
	Sand = Color3.fromRGB(255, 240, 205),
	Salt = Color3.fromRGB(255, 220, 245),
	Mud = Color3.fromRGB(180, 160, 206),
	Slate = Color3.fromRGB(255, 206, 170),
}

local function materialOf(name: any): Enum.Material?
	if type(name) ~= "string" then
		return nil
	end
	for _, m in Enum.Material:GetEnumItems() do
		if m.Name == name then
			return m :: any
		end
	end
	return nil
end

function TerrainService.start()
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	local plan = workspace:WaitForChild("Map"):FindFirstChild("TerrainPlan")
	if not terrain or not plan then
		return
	end
	local t = terrain :: Terrain
	for name, color in COLORS do
		local m = materialOf(name)
		if m then
			t:SetMaterialColor(m, color)
		end
	end
	-- Collines d'abord, sommets ensuite ; petites pauses pour ne pas figer le serveur
	task.spawn(function()
		local items = plan:GetChildren()
		table.sort(items, function(a, b)
			return (if a.Name == "Hill" then 0 else 1) < (if b.Name == "Hill" then 0 else 1)
		end)
		for k, item in items do
			local pos = item:GetAttribute("Position")
			local radius = item:GetAttribute("Radius")
			local material = materialOf(item:GetAttribute("Material"))
			if typeof(pos) == "Vector3" and type(radius) == "number" and material then
				t:FillBall(pos :: Vector3, radius, material)
			end
			if k % 8 == 0 then
				task.wait()
			end
		end
	end)
end

return TerrainService
