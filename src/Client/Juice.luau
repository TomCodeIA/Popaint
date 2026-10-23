--!strict
-- Popaint : petites animations « qui font plaisir » dans le monde :
--   * la machine à bulles saute et lâche des confettis quand on achète une amélioration ;
--   * le personnage fait un petit saut de joie au passage de niveau.
-- Tout se passe chez le joueur (rien n'est envoyé au serveur).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Effects = require(script.Parent:WaitForChild("Effects")) :: any

local Juice = {}

local player = Players.LocalPlayer

local function animated(inst: Instance, stop: Instance): boolean
	local node: Instance? = inst
	while node and node ~= stop do
		if node:GetAttribute("Anim") then
			return true
		end
		node = node.Parent
	end
	return false
end

local busy = false

-- La machine saute (écrasement → envol → atterrissage)
function Juice.machineHop(base: Instance)
	local machine = base:FindFirstChild("MachineBody")
	if busy or not machine or not machine:IsA("BasePart") then
		return
	end
	local mcf = (machine :: BasePart).CFrame
	local parts: { { Part: BasePart, CF: CFrame } } = {}
	for _, d in base:GetDescendants() do
		if d:IsA("BasePart") and not d:IsDescendantOf(base:FindFirstChild("Treadmill") or base) and not animated(d, base) then
			local rel = mcf:PointToObjectSpace((d :: BasePart).CFrame.Position)
			if math.abs(rel.X) <= 4.8 and math.abs(rel.Z) <= 4.8 and rel.Y > -3.6 and rel.Y < 8 then
				table.insert(parts, { Part = d :: BasePart, CF = (d :: BasePart).CFrame })
			end
		end
	end
	busy = true
	local start = os.clock()
	local DURATION = 0.55
	local conn: any
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - start) / DURATION, 0, 1)
		-- 0 → 0.2 : écrasement, 0.2 → 1 : saut avec rebond
		local squash = if a < 0.2 then 1 - math.sin(a / 0.2 * math.pi) * 0.15 else 1 + math.sin((a - 0.2) / 0.8 * math.pi) * 0.08
		local lift = if a < 0.2 then 0 else math.sin((a - 0.2) / 0.8 * math.pi) * 2.2
		local foot = mcf * CFrame.new(0, -3.6, 0)
		for _, p in parts do
			local rel = foot:ToObjectSpace(p.CF)
			local pos = rel.Position
			p.Part.CFrame = foot * CFrame.new(pos.X / math.sqrt(squash), pos.Y * squash + lift, pos.Z / math.sqrt(squash)) * (rel - pos)
		end
		if a >= 1 then
			conn:Disconnect()
			for _, p in parts do
				p.Part.CFrame = p.CF
			end
			busy = false
		end
	end)
	task.delay(0.2, function()
		local top = (mcf * CFrame.new(0, 9, 0)).Position
		for _, c in Config.PaintPalette do
			Effects.burst(top, c, 5, 1.2)
		end
	end)
end

local function myBase(): Instance?
	local name = player:GetAttribute("BaseName")
	if type(name) ~= "string" then
		return nil
	end
	local map = workspace:FindFirstChild("Map")
	local hub = map and map:FindFirstChild("Hub")
	local bases = hub and hub:FindFirstChild("Bases")
	return bases and bases:FindFirstChild(name)
end

-- Petit saut de joie du personnage
local function cheer()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
		humanoid.Jump = true
	end
end

function Juice.start()
	Remotes.event("Effect").OnClientEvent:Connect(function(kind: string, _data: any)
		if kind == "Upgraded" or kind == "CosmeticBought" then
			local base = myBase()
			if base then
				Juice.machineHop(base)
			end
		elseif kind == "LevelUp" then
			cheer()
		end
	end)
end

return Juice
