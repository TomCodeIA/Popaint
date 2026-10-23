--!strict
-- Popaint : qualité automatique. Choisit un niveau de détail (1 = léger, 2 = moyen, 3 = beau) selon
-- le réglage graphique Roblox du joueur et la fluidité réelle (images par seconde) :
--   * réglage graphique bas → léger ; haut → beau ;
--   * réglage « automatique » → on part de « moyen » sur téléphone, « beau » sur ordinateur, puis on
--     baisse si le jeu rame et on remonte s'il est très fluide.
-- Detail.luau (petits détails), Animator.luau (animations du décor) et Pets.luau s'en servent.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Quality = {}

type Settings = { DetailDistance: number, AnimScale: number, PetDetail: number, Particles: boolean }
local LEVELS: { Settings } = {
	{ DetailDistance = 60, AnimScale = 0.5, PetDetail = 50, Particles = false }, -- léger
	{ DetailDistance = 130, AnimScale = 0.9, PetDetail = 110, Particles = true }, -- moyen
	{ DetailDistance = 220, AnimScale = 1.3, PetDetail = 170, Particles = true }, -- beau
}

local level = 2
local automatic = true
local listeners: { (number) -> () } = {}

function Quality.level(): number
	return level
end

function Quality.settings(): Settings
	return LEVELS[level]
end

function Quality.onChange(fn: (number) -> ())
	table.insert(listeners, fn)
end

local function set(n: number)
	n = math.clamp(n, 1, #LEVELS)
	if n == level then
		return
	end
	level = n
	for _, fn in listeners do
		task.spawn(fn, n)
	end
end

-- Niveau graphique Roblox du joueur : 0 = automatique, 1 à 10 sinon
local function robloxLevel(): number
	local ok, value = pcall(function()
		local s = UserSettings():GetService("UserGameSettings")
		return s.SavedQualityLevel.Value
	end)
	return if ok and type(value) == "number" then value else 0
end

local function fromSettings()
	local v = robloxLevel()
	automatic = v == 0
	if automatic then
		local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		set(if phone then 2 else 3)
	else
		set(if v <= 3 then 1 elseif v <= 7 then 2 else 3)
	end
end

function Quality.start()
	level = 2
	fromSettings()
	pcall(function()
		local s = UserSettings():GetService("UserGameSettings")
		s:GetPropertyChangedSignal("SavedQualityLevel"):Connect(fromSettings)
	end)
	-- en automatique, on suit la fluidité réelle
	local frames, elapsed, smooth = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		if not automatic then
			return
		end
		frames += 1
		elapsed += dt
		if elapsed < 5 then
			return
		end
		local fps = frames / elapsed
		frames, elapsed = 0, 0
		if fps < 28 then
			smooth = 0
			set(level - 1)
		elseif fps > 55 then
			smooth += 1
			if smooth >= 4 then -- 20 secondes très fluides de suite
				smooth = 0
				set(level + 1)
			end
		else
			smooth = 0
		end
	end)
end

return Quality
