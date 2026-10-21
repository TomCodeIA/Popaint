--!strict
-- Popaint : attribue une base du hub à chaque joueur.

local Players = game:GetService("Players")

local BaseService = {}

-- Clé = nom de la base (plus robuste qu'une clé Instance)
local owners: { [string]: Player } = {}

local function setLabel(base: Instance, text: string)
	local label = base:FindFirstChild("OwnerLabel", true)
	if label and label:IsA("TextLabel") then
		(label :: TextLabel).Text = text
	end
end

local function freeBase(player: Player)
	local bases = workspace:WaitForChild("Map"):WaitForChild("Hub"):WaitForChild("Bases")
	for name, owner in owners do
		if owner == player then
			owners[name] = nil
			local base = bases:FindFirstChild(name)
			if base then
				base:SetAttribute("OwnerId", 0)
				setLabel(base, "Free base")
			end
		end
	end
	player:SetAttribute("BaseName", nil)
end

local function claimBase(player: Player)
	local bases = workspace:WaitForChild("Map"):WaitForChild("Hub"):WaitForChild("Bases")
	local list = bases:GetChildren()
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	for _, base in list do
		if not owners[base.Name] then
			owners[base.Name] = player
			base:SetAttribute("OwnerId", player.UserId)
			setLabel(base, player.DisplayName)
			player:SetAttribute("BaseName", base.Name)
			return
		end
	end
end

function BaseService.start()
	Players.PlayerAdded:Connect(claimBase)
	Players.PlayerRemoving:Connect(freeBase)
	for _, p in Players:GetPlayers() do
		task.spawn(claimBase, p)
	end
end

return BaseService
