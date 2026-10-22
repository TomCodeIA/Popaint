--!strict
-- Popaint : didacticiel guidé (message + faisceau arc-en-ciel + flèche vers l'objectif).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Ui = require(script.Parent:WaitForChild("Ui")) :: any
local State = require(script.Parent:WaitForChild("State")) :: any
local Hud = require(script.Parent:WaitForChild("Hud")) :: any

local Tutorial = {}

local player = Players.LocalPlayer
local t = Ui.t

local hint: Frame
local hintLabel: TextLabel
local marker: Part
local markerAttachment: Attachment
local beam: Beam
local arrowGui: BillboardGui
local rootAttachment: Attachment? = nil

local function myMachine(): BasePart?
	local baseName = player:GetAttribute("BaseName")
	if type(baseName) ~= "string" then
		return nil
	end
	local base = workspace:WaitForChild("Map"):WaitForChild("Hub"):WaitForChild("Bases"):FindFirstChild(baseName)
	local body = base and base:FindFirstChild("MachineBody")
	return if body and body:IsA("BasePart") then body :: BasePart else nil
end

local function nearestBubble(from: Vector3): Vector3?
	local folder = workspace:FindFirstChild("MyBubbles")
	if not folder then
		return nil
	end
	local best: Vector3? = nil
	local bestD = math.huge
	for _, b in folder:GetChildren() do
		if b:IsA("BasePart") and (b :: BasePart).Transparency < 1 and (b :: BasePart).Material == Enum.Material.ForceField then
			local d = ((b :: BasePart).Position - from).Magnitude
			if d < bestD then
				bestD = d
				best = (b :: BasePart).Position
			end
		end
	end
	return best
end

local function target(step: string, rootPos: Vector3): Vector3?
	if step == "GoToZone" then
		local first = workspace:WaitForChild("Map"):WaitForChild("Zones"):FindFirstChild(Config.MainZones[1].Id)
		local entrance = first and first:GetAttribute("Entrance")
		return if typeof(entrance) == "Vector3" then entrance :: Vector3 else Vector3.new(0, 3, -140)
	elseif step == "PopBubbles" then
		return nearestBubble(rootPos)
	elseif step == "OpenShop" or step == "BuyUpgrade" then
		local m = myMachine()
		return if m then m.Position + Vector3.new(0, 2, 0) else nil
	elseif step == "OpenEgg" then
		local egg = workspace:WaitForChild("Map"):WaitForChild("Eggs"):FindFirstChild(Config.MainZones[1].Id)
		local shell = egg and egg:FindFirstChild("Shell")
		return if shell and shell:IsA("BasePart") then (shell :: BasePart).Position else nil
	end
	return nil
end

local function text(step: string, state: any): string
	if step == "PopBubbles" then
		local pops = state.Tutorial and state.Tutorial.Pops or 0
		return "🫧 " .. t("T_PopBubbles", { n = pops, max = Config.TutorialPopTarget })
	elseif step == "GoToZone" then
		return "🏃 " .. t("T_GoToZone")
	elseif step == "OpenShop" then
		return "⚙️ " .. t("T_OpenShop")
	elseif step == "BuyUpgrade" then
		return "⬆️ " .. t("T_BuyUpgrade")
	elseif step == "OpenEgg" then
		return "🥚 " .. t("T_OpenEgg")
	end
	return ""
end

local function attachToCharacter()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local a = Instance.new("Attachment")
		a.Name = "TutorialAttachment"
		a.Parent = root
		rootAttachment = a
		beam.Attachment0 = a
	end
end

function Tutorial.start()
	local gui = Hud.gui :: ScreenGui
	hint = Ui.frame(gui, {
		Name = "TutorialHint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(620, 66),
		BackgroundColor3 = Ui.White,
		Visible = false,
	})
	Ui.corner(hint, UDim.new(1, 0))
	Ui.stroke(hint, 4)
	Ui.gradient(hint, Color3.fromRGB(255, 170, 220), Ui.Pink)
	hintLabel = Ui.label(hint, "", { Size = UDim2.new(1, -30, 0.7, 0), Position = UDim2.new(0, 15, 0.15, 0) })

	marker = Instance.new("Part")
	marker.Name = "TutorialMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.new(0.5, 0.5, 0.5)
	marker.Parent = workspace
	markerAttachment = Instance.new("Attachment")
	markerAttachment.Parent = marker
	beam = Instance.new("Beam")
	beam.Attachment1 = markerAttachment
	beam.FaceCamera = true
	beam.Width0 = 0.8
	beam.Width1 = 0.8
	beam.LightEmission = 0.25
	beam.Transparency = NumberSequence.new(0.2)
	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Config.PaintPalette[1]),
		ColorSequenceKeypoint.new(0.25, Config.PaintPalette[3]),
		ColorSequenceKeypoint.new(0.5, Config.PaintPalette[4]),
		ColorSequenceKeypoint.new(0.75, Config.PaintPalette[2]),
		ColorSequenceKeypoint.new(1, Config.PaintPalette[5]),
	})
	beam.Enabled = false
	beam.Parent = marker
	arrowGui = Instance.new("BillboardGui")
	arrowGui.Size = UDim2.fromOffset(80, 80)
	arrowGui.AlwaysOnTop = true
	arrowGui.LightInfluence = 0
	arrowGui.Enabled = false
	arrowGui.Parent = marker
	Ui.label(arrowGui, "⬇️", { Size = UDim2.fromScale(1, 1) })

	attachToCharacter()
	player.CharacterAdded:Connect(function(character: Model)
		character:WaitForChild("HumanoidRootPart", 10)
		attachToCharacter()
	end)

	RunService.RenderStepped:Connect(function()
		local state = State.current
		local step = state and state.Tutorial and state.Tutorial.Step
		if not state or not step or step == "Done" then
			hint.Visible = false
			beam.Enabled = false
			arrowGui.Enabled = false
			return
		end
		hint.Visible = true
		hintLabel.Text = text(step, state)
		hint.Rotation = math.sin(os.clock() * 3) * 1.5
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local rootPos = if root and root:IsA("BasePart") then (root :: BasePart).Position else nil
		local goal = if rootPos then target(step, rootPos) else nil
		if goal then
			marker.CFrame = CFrame.new(goal + Vector3.new(0, 2 + math.abs(math.sin(os.clock() * 4)) * 1.5, 0))
			beam.Enabled = rootAttachment ~= nil and rootAttachment.Parent ~= nil
			arrowGui.Enabled = true
		else
			beam.Enabled = false
			arrowGui.Enabled = false
		end
	end)
end

return Tutorial
