--!strict
-- Popaint : Rainbow Storm, toutes les 1h30 (calé sur minuit UTC), pendant 10 minutes.
-- L'état est publié en attributs sur Workspace pour que tous les clients l'affichent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Formulas = require(Shared:WaitForChild("Formulas")) :: any
local Bus = require(script.Parent:WaitForChild("Bus")) :: any

local StormService = {}

local active = false

local function now(): number
	return workspace:GetServerTimeNow()
end

function StormService.isActive(): boolean
	return active
end

function StormService.multiplier(): number
	return if active then Config.StormMultiplier else 1
end

local function refresh()
	local isActive, endsAt, nextStart = Formulas.storm(now(), Config.StormPeriod, Config.StormDuration)
	workspace:SetAttribute("StormActive", isActive)
	workspace:SetAttribute("StormEndsAt", endsAt)
	workspace:SetAttribute("NextStormAt", if isActive then nextStart else nextStart)
	if isActive ~= active then
		active = isActive
		Bus.emit(if isActive then "StormStarted" else "StormEnded")
	end
end

function StormService.start()
	refresh()
	task.spawn(function()
		while true do
			task.wait(1)
			refresh()
		end
	end)
end

return StormService
