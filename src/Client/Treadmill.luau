--!strict
-- Popaint : tapis de course côté joueur (on court tout seul dessus, tapis animés, gains qui s'affichent).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Formulas = require(Shared:WaitForChild("Formulas")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Ui = require(script.Parent:WaitForChild("Ui")) :: any
local Hud = require(script.Parent:WaitForChild("Hud")) :: any
local Effects = require(script.Parent:WaitForChild("Effects")) :: any

local Treadmill = {}

local player = Players.LocalPlayer
local t = Ui.t

type Mill = { Model: Instance, Belt: BasePart, Stripes: { { Part: BasePart, Offset: number } }, Base: Instance }
local mills: { Mill } = {}
local suspendedUntil = 0
local hinted = false
local RAINBOW = Config.PaintPalette

local function collect()
	local bases = workspace:WaitForChild("Map"):WaitForChild("Hub"):WaitForChild("Bases")
	for _, base in bases:GetChildren() do
		local tm = base:FindFirstChild("Treadmill")
		local belt = tm and tm:FindFirstChild("Belt")
		if tm and belt and belt:IsA("BasePart") then
			local b = belt :: BasePart
			local stripes = {}
			for _, c in tm:GetChildren() do
				if c:IsA("BasePart") and string.sub(c.Name, 1, 6) == "Stripe" then
					local rel = b.CFrame:PointToObjectSpace((c :: BasePart).Position)
					table.insert(stripes, { Part = c :: BasePart, Offset = rel.Z })
				end
			end
			table.insert(mills, { Model = tm, Belt = b, Stripes = stripes, Base = base })
		end
	end
end

local function myMill(): Mill?
	local baseName = player:GetAttribute("BaseName")
	for _, m in mills do
		if m.Base.Name == baseName then
			return m
		end
	end
	return nil
end

local function onBelt(m: Mill, pos: Vector3): boolean
	local rel = m.Belt.CFrame:PointToObjectSpace(pos)
	return math.abs(rel.X) <= m.Belt.Size.X / 2 + 0.3 and math.abs(rel.Z) <= m.Belt.Size.Z / 2 + 0.3 and rel.Y > 0 and rel.Y < 7
end

local function ownerTraining(m: Mill): boolean
	local ownerId = m.Base:GetAttribute("OwnerId")
	if type(ownerId) ~= "number" or ownerId == 0 then
		return false
	end
	local owner = Players:GetPlayerByUserId(ownerId)
	return owner ~= nil and owner:GetAttribute("Training") == true
end

local function tierColor(level: number): Color3
	local color = Config.TreadmillLooks[1][2]
	for _, look in Config.TreadmillLooks do
		if level >= look[1] then
			color = look[2]
		end
	end
	return color
end

function Treadmill.start()
	collect()

	-- Sauter fait descendre du tapis
	local function hookHumanoid(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			(humanoid :: Humanoid).StateChanged:Connect(function(_, new: Enum.HumanoidStateType)
				if new == Enum.HumanoidStateType.Jumping then
					suspendedUntil = os.clock() + 1.5
				end
			end)
		end
	end
	if player.Character then
		task.spawn(hookHumanoid, player.Character)
	end
	player.CharacterAdded:Connect(hookHumanoid)

	-- Gains affichés au-dessus de la tête à chaque seconde
	Remotes.event("Effect").OnClientEvent:Connect(function(kind: string, data: any)
		if kind ~= "Train" then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local mine = myMill()
			local level = (mine and mine.Model:GetAttribute("Level")) or 0
			local color = if level >= 9 then RAINBOW[math.random(1, #RAINBOW)] else Ui.lighten(tierColor(level), 0.3)
			Effects.floatingText((root :: BasePart).Position + Vector3.new(math.random(-15, 15) / 10, 3.5, 0),
				"+" .. Formulas.formatNumber(data.Points), color, 1 + math.min(level, 10) * 0.06)
			Effects.burst((root :: BasePart).Position - Vector3.new(0, 2.5, 0), color, 6, 0.5)
		end
		if data.SpeedUp then
			Effects.play(Config.Sounds.Reward, 0.5, 1.2)
			Hud.toast("👟 " .. t("SpeedStat", { n = data.Speed }) .. " !", Ui.Green)
		end
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		local now = os.clock()
		-- Bandes qui défilent sur les tapis utilisés + tapis arc-en-ciel au niveau max
		for _, m in mills do
			local running = ownerTraining(m)
			if running then
				local speed = 14
				for _, s in m.Stripes do
					s.Offset += speed * dt
					local half = m.Belt.Size.Z / 2
					if s.Offset > half then
						s.Offset -= m.Belt.Size.Z
					end
					s.Part.CFrame = m.Belt.CFrame * CFrame.new(0, m.Belt.Size.Y / 2 + 0.03, s.Offset)
				end
			end
			local level = m.Model:GetAttribute("Level")
			if type(level) == "number" and level >= 9 then
				local c = RAINBOW[(math.floor(now * 4) % #RAINBOW) + 1]
				for _, p in m.Model:GetChildren() do
					if p:IsA("BasePart") and (p.Name == "Frame" or p.Name == "Rail" or p.Name == "Post") then
						(p :: BasePart).Color = c
					end
				end
			end
		end

		-- Mon personnage court tout seul sur mon tapis
		local m = myMill()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not m or not root or not root:IsA("BasePart") or not humanoid then
			return
		end
		local h = humanoid :: Humanoid
		local on = onBelt(m, (root :: BasePart).Position) and now >= suspendedUntil
		if on then
			local forward = m.Belt.CFrame.LookVector
			h:Move(forward, false)
			m.Belt.AssemblyLinearVelocity = -forward * h.WalkSpeed
			if not hinted then
				hinted = true
				Hud.toast("🏃 " .. t("JumpToStop"), Ui.Blue)
			end
		else
			m.Belt.AssemblyLinearVelocity = Vector3.zero
		end
	end)
end

return Treadmill
