--!strict
-- Popaint : événements temporaires (dates dans Content/Events.luau).
-- Publie l'état sur Workspace pour les joueurs : attribut "Event_<Id>" (true/false) et "EventEnds_<Id>".

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Formulas = require(Shared:WaitForChild("Formulas")) :: any
local Bus = require(script.Parent:WaitForChild("Bus")) :: any

local EventService = {}

local active: { [string]: boolean } = {}

local function window(e: any): (number, number)
	local s, en = e.Start, e.End
	return Formulas.utcEpoch(s[1], s[2], s[3], s[4]), Formulas.utcEpoch(en[1], en[2], en[3], en[4])
end
EventService.window = window

local function forced(): boolean
	return Config.ForceEventsInStudio == true and RunService:IsStudio()
end

function EventService.isActive(id: string?): boolean
	if not id then
		return true
	end
	return active[id] == true
end

local function refresh()
	local now = workspace:GetServerTimeNow()
	for _, e in Config.Events do
		local startsAt, endsAt = window(e)
		local isOn = forced() or (now >= startsAt and now < endsAt)
		workspace:SetAttribute("Event_" .. e.Id, isOn)
		workspace:SetAttribute("EventEnds_" .. e.Id, if forced() then now + 86400 else endsAt)
		if isOn ~= (active[e.Id] == true) then
			active[e.Id] = isOn
			Bus.emit(if isOn then "EventStarted" else "EventEnded", e.Id)
		end
	end
end

function EventService.start()
	refresh()
	task.spawn(function()
		while true do
			task.wait(5)
			refresh()
		end
	end)
end

return EventService
