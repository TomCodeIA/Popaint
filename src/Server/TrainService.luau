--!strict
-- Popaint : tapis de course des bases.
-- Le propriétaire qui se tient sur son tapis gagne des points de course chaque seconde ;
-- ces points augmentent sa vitesse pour toujours (avec un plafond).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local DataService = require(script.Parent:WaitForChild("DataService")) :: any
local UpgradeService = require(script.Parent:WaitForChild("UpgradeService")) :: any
local Bus = require(script.Parent:WaitForChild("Bus")) :: any

local TrainService = {}

local function bases(): Instance
	return workspace:WaitForChild("Map"):WaitForChild("Hub"):WaitForChild("Bases")
end

local function treadmillOf(player: Player): Instance?
	local baseName = player:GetAttribute("BaseName")
	if type(baseName) ~= "string" then
		return nil
	end
	local base = bases():FindFirstChild(baseName)
	return base and base:FindFirstChild("Treadmill")
end

function TrainService.rate(player: Player): number
	local level = UpgradeService.level(player, "Treadmill")
	return Config.TreadmillRates[math.clamp(level + 1, 1, #Config.TreadmillRates)]
end

-- Le personnage est-il debout sur ce tapis ?
local function isOnBelt(player: Player, treadmill: Instance): boolean
	local belt = treadmill:FindFirstChild("Belt")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not belt or not belt:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return false
	end
	local b = belt :: BasePart
	local rel = b.CFrame:PointToObjectSpace((root :: BasePart).CFrame.Position)
	return math.abs(rel.X) <= b.Size.X / 2 + 0.5 and math.abs(rel.Z) <= b.Size.Z / 2 + 0.5 and rel.Y > 0 and rel.Y < 7
end
TrainService.isOnBelt = isOnBelt

-- Apparence du tapis selon son niveau
function TrainService.applyLook(treadmill: Instance, level: number)
	local color = Config.TreadmillLooks[1][2]
	local tier = 1
	for k, look in Config.TreadmillLooks do
		if level >= look[1] then
			color = look[2]
			tier = k
		end
	end
	treadmill:SetAttribute("Level", level)
	treadmill:SetAttribute("Tier", tier)
	for _, p in treadmill:GetChildren() do
		if p:IsA("BasePart") then
			local part = p :: BasePart
			if part.Name == "Frame" or part.Name == "Post" then
				part.Color = color
			elseif part.Name == "Rail" then
				part.Color = color:Lerp(Color3.new(1, 1, 1), 0.4)
			end
		end
	end
	for _, d in treadmill:GetDescendants() do
		if d:IsA("TextLabel") and d.Name == "Screen" then
			(d :: TextLabel).Text = "Lv. " .. tostring(level)
		end
	end
end

local function refreshLook(player: Player)
	local tm = treadmillOf(player)
	if tm then
		TrainService.applyLook(tm, UpgradeService.level(player, "Treadmill"))
	end
end

local function tick()
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		local tm = treadmillOf(player)
		local on = profile ~= nil and tm ~= nil and isOnBelt(player, tm :: Instance)
		if player:GetAttribute("Training") ~= on then
			player:SetAttribute("Training", on)
		end
		if on and profile then
			local stats = profile.Data.Stats
			local before = UpgradeService.walkSpeed(player)
			local rate = TrainService.rate(player)
			stats.TrainPoints = (stats.TrainPoints or 0) + rate
			stats.TrainSeconds = (stats.TrainSeconds or 0) + 1
			local after = UpgradeService.walkSpeed(player)
			Remotes.event("Effect"):FireClient(player, "Train", { Points = rate, Speed = after, SpeedUp = after > before })
			if after > before then
				UpgradeService.applySpeed(player)
			end
			Bus.emit("Trained", player, rate)
			DataService.markDirty(player)
		end
	end
end

function TrainService.start()
	for _, base in bases():GetChildren() do
		local tm = base:FindFirstChild("Treadmill")
		if tm then
			TrainService.applyLook(tm, 0)
		end
	end
	DataService.onLoaded(function(player: Player)
		refreshLook(player)
		player:GetAttributeChangedSignal("BaseName"):Connect(function()
			refreshLook(player)
		end)
	end)
	Bus.on("UpgradeBought", function(player: Player, id: string)
		if id == "Treadmill" then
			refreshLook(player)
		end
	end)
	DataService.onLeaving(function(player: Player)
		local tm = treadmillOf(player)
		if tm then
			TrainService.applyLook(tm, 0)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(tick :: any)
			if not ok then
				warn("[Popaint] erreur tapis : " .. tostring(err))
			end
		end
	end)
end

return TrainService
