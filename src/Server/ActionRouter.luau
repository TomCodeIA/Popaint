--!strict
-- Popaint : reçoit les actions des joueurs (acheter, équiper, réclamer...) et les envoie au bon service.
-- Un seul point d'entrée = une seule protection anti-spam.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")) :: any

local ActionRouter = {}

local handlers: { [string]: (Player, any) -> () } = {}
local windows: { [number]: { Start: number, Count: number } } = {}
local MAX_PER_SECOND = 12

function ActionRouter.register(action: string, handler: (Player, any) -> ())
	assert(not handlers[action], "action déjà enregistrée : " .. action)
	handlers[action] = handler
end

function ActionRouter.start()
	Remotes.event("Action").OnServerEvent:Connect(function(player: Player, action: any, arg: any)
		if type(action) ~= "string" then
			return
		end
		local handler = handlers[action]
		if not handler then
			return
		end
		local now = os.clock()
		local existing = windows[player.UserId]
		local win: { Start: number, Count: number }
		if existing and now - existing.Start < 1 then
			win = existing
		else
			win = { Start = now, Count = 0 }
			windows[player.UserId] = win
		end
		win.Count += 1
		if win.Count > MAX_PER_SECOND then
			return
		end
		local ok, err = pcall(handler :: any, player, arg)
		if not ok then
			warn(("[Popaint] action %s : %s"):format(action, tostring(err)))
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		windows[player.UserId] = nil
	end)
end

return ActionRouter
