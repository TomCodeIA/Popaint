--!strict
-- Popaint : point d'entrée côté joueur.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local modules = script:WaitForChild("Modules")

local function load(name: string): any
	return require(modules:WaitForChild(name)) :: any
end

local Ui = load("Ui")
local Effects = load("Effects")
local State = load("State")
local Bubbles = load("Bubbles")
local Hud = load("Hud")

Ui.setSoundPlayer(Effects.play)
State.start()

-- On attend que le serveur ait chargé les données (max 20 s, le jeu démarre quand même après)
local started = os.clock()
while player:GetAttribute("Coins") == nil and os.clock() - started < 20 do
	task.wait(0.1)
end

local function safeStart(name: string, fn: () -> ())
	local ok, err = pcall(fn :: any)
	if not ok then
		warn(("[Popaint] %s : %s"):format(name, tostring(err)))
	end
end

safeStart("Quality", function()
	load("Quality").start()
end)
safeStart("Hud", Hud.start)
for _, name in { "Shop", "Pets", "Daily", "MiniMap", "Tutorial", "World", "Treadmill", "Animator", "Detail", "Juice", "DayNight" } do
	safeStart(name, function()
		load(name).start()
	end)
end

Bubbles.onPopped(function(tiles: number, coins: number, position: Vector3, color: Color3, isAuto: boolean, kind: string)
	if coins > 0 then
		local text = "+" .. tostring(coins)
		if kind == "high" then
			text ..= " x2"
		end
		Effects.floatingText(position + Vector3.new(0, 1.5, 0), text, Color3.fromRGB(255, 222, 140),
			if isAuto then 0.7 elseif kind == "high" then 1.4 else 1.1)
		Hud.coinsGained(coins, if isAuto then nil else position)
	end
	local _ = tiles
	local _c = color
end)

safeStart("Bubbles", Bubbles.start)
