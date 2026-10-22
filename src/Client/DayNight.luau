--!strict
-- Popaint : cycle jour / nuit doux.
-- Tout le serveur voit la même heure : elle est calculée à partir de l'heure du serveur
-- (workspace:GetServerTimeNow()), donc personne n'a besoin d'envoyer quoi que ce soit.
-- Il ne fait jamais nuit noire : on va du lever du jour (6 h) au crépuscule (21 h) et retour.
-- Le soir, les lampes de la map s'allument toutes seules (et s'éteignent le jour : c'est aussi
-- plus fluide sur les petits téléphones).

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local DayNight = {}

local CYCLE = 1200 -- un tour complet en 20 minutes
local DAWN, DUSK = 6, 21 -- heures affichées dans le ciel

-- couleurs de l'ambiance : plein jour → crépuscule
local DAY_OUT = Color3.fromRGB(206, 196, 226)
local NIGHT_OUT = Color3.fromRGB(150, 146, 196)
local DAY_AMB = Color3.fromRGB(150, 138, 168)
local NIGHT_AMB = Color3.fromRGB(120, 116, 160)
local DAY_FOG = Color3.fromRGB(250, 232, 246)
local NIGHT_FOG = Color3.fromRGB(214, 206, 246)

local lights: { PointLight } = {}
local lightsOn: boolean? = nil

local function trackLights(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("PointLight") then
			table.insert(lights, d :: PointLight)
		end
	end
end

-- 0 = plein jour, 1 = crépuscule
function DayNight.darkness(): number
	local now = workspace:GetServerTimeNow()
	local phase = (now % CYCLE) / CYCLE
	return (1 - math.cos(phase * math.pi * 2)) / 2
end

function DayNight.start()
	local map = workspace:WaitForChild("Map")
	trackLights(map)
	map.DescendantAdded:Connect(function(d: Instance)
		if d:IsA("PointLight") then
			local l = d :: PointLight
			table.insert(lights, l)
			if lightsOn ~= nil then
				l.Enabled = lightsOn :: boolean
			end
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local k = DayNight.darkness()
		-- pendant la Rainbow Storm, on remet le plein jour pour que la fête soit lumineuse
		if workspace:GetAttribute("StormActive") == true then
			k = 0
		end
		Lighting.ClockTime = DAWN + (DUSK - DAWN) * k
		Lighting.OutdoorAmbient = DAY_OUT:Lerp(NIGHT_OUT, k)
		Lighting.Ambient = DAY_AMB:Lerp(NIGHT_AMB, k)
		Lighting.Brightness = 2.3 - 0.5 * k
		local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmo then
			atmo.Color = DAY_FOG:Lerp(NIGHT_FOG, k)
		end
		-- les lampes s'allument au crépuscule
		local on = k > 0.62
		if on ~= lightsOn then
			lightsOn = on
			for i = #lights, 1, -1 do
				local l = lights[i]
				if l.Parent then
					l.Enabled = on
				else
					table.remove(lights, i) -- la pièce a été déchargée
				end
			end
		end
	end)
end

return DayNight
