--!strict
-- Popaint : dernier état reçu du serveur + abonnement aux changements.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")) :: any

local State = {}

State.current = nil :: { [string]: any }?
local listeners: { ({ [string]: any }) -> () } = {}

function State.onChange(fn: ({ [string]: any }) -> ())
	table.insert(listeners, fn)
	if State.current then
		task.spawn(fn, State.current)
	end
end

function State.action(name: string, arg: any?)
	Remotes.event("Action"):FireServer(name, arg)
end

function State.start()
	Remotes.event("State").OnClientEvent:Connect(function(state: { [string]: any })
		State.current = state
		for _, fn in listeners do
			task.spawn(fn, state)
		end
	end)
end

return State
