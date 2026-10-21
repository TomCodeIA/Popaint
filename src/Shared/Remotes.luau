--!strict
-- Popaint : liste unique des événements réseau client <-> serveur.
-- Le serveur les crée au démarrage, le client les attend.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local EVENTS = {
	"BubbleSpawned", -- serveur -> tous : (ownerUserId, id, position, size, colorIndex, isCascade)
	"BubbleRemoved", -- serveur -> tous : (ownerUserId, id)  bulle expirée sans éclater
	"BubblePopped", -- serveur -> tous : (ownerUserId, id, position, colorIndex, tiles, coins, isAuto)
	"PopBubble", -- client -> serveur : (id)  le client a touché sa bulle
	"ZoneReset", -- serveur -> tous : (zoneId)
	"Notify", -- serveur -> un client : (localeKey, vars?, kind?)  message à l'écran
	"State", -- serveur -> un client : (state)  tout ce que l'interface doit afficher
	"Action", -- client -> serveur : (action, arg?)  acheter, équiper, réclamer...
	"Effect", -- serveur -> un client : (kind, data)  célébrations (œuf, niveau, quête...)
}

local folder: Folder

if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing and existing:IsA("Folder") then
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.event(name: string): RemoteEvent
	assert(table.find(EVENTS, name), "Unknown remote: " .. name)
	local ev = folder:WaitForChild(name, 30)
	assert(ev and ev:IsA("RemoteEvent"), "Remote missing: " .. name)
	return ev :: RemoteEvent
end

Remotes.Names = EVENTS

return Remotes
