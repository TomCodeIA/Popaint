--!strict
-- Popaint : niveau au-dessus de la tête, didacticiel et gains hors ligne.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Formulas = require(Shared:WaitForChild("Formulas")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local DataService = require(script.Parent:WaitForChild("DataService")) :: any
local UpgradeService = require(script.Parent:WaitForChild("UpgradeService")) :: any
local ZoneAccess = require(script.Parent:WaitForChild("ZoneAccess")) :: any
local BubbleService = require(script.Parent:WaitForChild("BubbleService")) :: any
local Bus = require(script.Parent:WaitForChild("Bus")) :: any

local ProgressService = {}

local TIER_COLORS: { { any } } = {
	{ 1, Color3.fromRGB(255, 255, 255) },
	{ 10, Color3.fromRGB(160, 236, 180) },
	{ 25, Color3.fromRGB(150, 206, 252) },
	{ 50, Color3.fromRGB(200, 172, 252) },
	{ 100, Color3.fromRGB(255, 214, 120) },
	{ 200, Color3.fromRGB(255, 166, 206) }, -- arc-en-ciel animé côté client
}

local function levelColor(level: number): Color3
	local color = TIER_COLORS[1][2]
	for _, t in TIER_COLORS do
		if level >= t[1] then
			color = t[2]
		end
	end
	return color
end

local function levelOf(player: Player): number
	local profile = DataService.get(player)
	if not profile then
		return 1
	end
	return Formulas.level(profile.Data.Stats, Config.LevelDivisor)
end
ProgressService.levelOf = levelOf

---------------------------------------------------------------- niveau
local function overhead(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root then
		return
	end
	local gui = character:FindFirstChild("PopaintTag")
	if not gui then
		local bb = Instance.new("BillboardGui")
		bb.Name = "PopaintTag"
		bb.Size = UDim2.fromOffset(200, 50)
		bb.StudsOffset = Vector3.new(0, 4.2, 0)
		bb.MaxDistance = 90
		bb.LightInfluence = 0
		bb.Adornee = root
		local label = Instance.new("TextLabel")
		label.Name = "Level"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.fromRGB(45, 25, 70)
		label.Parent = bb
		bb.Parent = character
		gui = bb
	end
	local level = levelOf(player)
	local label = (gui :: Instance):FindFirstChild("Level")
	if label and label:IsA("TextLabel") then
		local l = label :: TextLabel
		l.Text = "Lv. " .. tostring(level)
		l.TextColor3 = levelColor(level)
	end
end

local function refreshLevel(player: Player)
	local level = levelOf(player)
	local previous = player:GetAttribute("Level")
	player:SetAttribute("Level", level)
	local ls = player:FindFirstChild("leaderstats")
	local lv = ls and ls:FindFirstChild("Level")
	if lv and lv:IsA("IntValue") then
		(lv :: IntValue).Value = level
	end
	if type(previous) == "number" and level > previous then
		Remotes.event("Effect"):FireClient(player, "LevelUp", { Level = level })
		overhead(player)
	end
end

---------------------------------------------------------------- didacticiel
local function step(player: Player): string?
	local profile = DataService.get(player)
	if not profile then
		return nil
	end
	return Config.TutorialSteps[profile.Data.Tutorial.Step]
end
ProgressService.tutorialStep = step

local function advance(player: Player, from: string)
	local profile = DataService.get(player)
	if not profile or step(player) ~= from then
		return
	end
	local t = profile.Data.Tutorial
	t.Step += 1
	if Config.TutorialSteps[t.Step] == "Done" then
		DataService.addCoins(player, Config.TutorialReward)
		Remotes.event("Effect"):FireClient(player, "TutorialDone", { Reward = Config.TutorialReward })
	end
	player:SetAttribute("TutorialStep", Config.TutorialSteps[t.Step])
	DataService.markDirty(player)
end
ProgressService.advanceTutorial = advance

---------------------------------------------------------------- hors ligne
local function offline(player: Player, profile: any)
	local last = profile.Data.LastOnline
	if type(last) ~= "number" or last <= 0 then
		return
	end
	local elapsed = os.time() - last
	if elapsed < Config.OfflineMinSeconds then
		return
	end
	local afk = Config.UpgradeEffects.afkInterval(UpgradeService.level(player, "Afk"))
	local zone = ZoneAccess.bestZone(player)
	local avgTiles = 7 * (1 + 0.06 * UpgradeService.level(player, "Size")) ^ 2
	local coins = Formulas.offlineCoins(elapsed, afk, avgTiles, zone.StudValue, BubbleService.coinMultiplier(player),
		Config.OfflineRate, Config.OfflineMaxSeconds)
	if coins > 0 then
		DataService.addCoins(player, coins)
		Remotes.event("Effect"):FireClient(player, "Offline", { Coins = coins })
	end
end

function ProgressService.start()
	DataService.onLoaded(function(player: Player, profile: any)
		offline(player, profile)
		local t = profile.Data.Tutorial
		if type(t.Step) ~= "number" or t.Step < 1 or t.Step > #Config.TutorialSteps then
			t.Step = 1
		end
		player:SetAttribute("TutorialStep", Config.TutorialSteps[t.Step])
		refreshLevel(player)
		overhead(player)
		player.CharacterAdded:Connect(function(character: Model)
			character:WaitForChild("HumanoidRootPart", 10)
			overhead(player)
		end)
	end)

	Bus.on("Popped", function(player: Player, info: any)
		refreshLevel(player)
		if info.How == "touch" and step(player) == "PopBubbles" then
			local profile = DataService.get(player)
			if profile then
				profile.Data.Tutorial.Pops += 1
				DataService.markDirty(player)
				if profile.Data.Tutorial.Pops >= Config.TutorialPopTarget then
					advance(player, "PopBubbles")
				end
			end
		end
	end)
	Bus.on("QuestDone", refreshLevel)
	Bus.on("OpenedShop", function(player: Player)
		advance(player, "OpenShop")
	end)
	Bus.on("UpgradeBought", function(player: Player)
		advance(player, "OpenShop") -- au cas où la boutique a été ouverte sans prévenir
		advance(player, "BuyUpgrade")
	end)
	Bus.on("EggOpened", function(player: Player)
		advance(player, "OpenEgg")
	end)

	-- Étape "va dans la zone"
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in game:GetService("Players"):GetPlayers() do
				if step(player) == "GoToZone" then
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						local ZoneService = require(script.Parent:WaitForChild("ZoneService")) :: any
						if ZoneService.zoneAt((root :: BasePart).CFrame.Position) then
							advance(player, "GoToZone")
						end
					end
				end
			end
		end
	end)
end

return ProgressService
