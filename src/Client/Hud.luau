--!strict
-- Popaint : interface principale (pièces, niveau, quêtes, Rainbow Storm, boost, messages, célébrations).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Formulas = require(Shared:WaitForChild("Formulas")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Ui = require(script.Parent:WaitForChild("Ui")) :: any
local State = require(script.Parent:WaitForChild("State")) :: any
local Effects = require(script.Parent:WaitForChild("Effects")) :: any

local Hud = {}

local player = Players.LocalPlayer
local t = Ui.t

Hud.gui = nil :: ScreenGui?
Hud.leftBar = nil :: Frame?

local gui: ScreenGui
local coinsPill: Frame
local coinsLabel: TextLabel
local coinIcon: Frame
local levelBadge: TextLabel
local levelFill: Frame
local stormChip: Frame
local stormLabel: TextLabel
local boostChip: Frame
local boostLabel: TextLabel
local speedLabel: TextLabel
local eventChip: Frame
local eventLabel: TextLabel
local banner: Frame
local bannerLabel: TextLabel
local bonusLabel: TextLabel
local questPanel: Frame
local questCards: { Frame } = {}
local toastHolder: Frame
local celebration: Frame
local celebrationTitle: TextLabel
local celebrationSub: TextLabel

local displayedCoins = 0
local targetCoins = 0
local lastLevel = 0
local lastCoinSound = 0

---------------------------------------------------------------- construction
local function buildCoins()
	coinsPill = Ui.frame(gui, {
		Name = "Coins",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(260, 66),
		BackgroundColor3 = Ui.White,
	})
	Ui.corner(coinsPill, UDim.new(1, 0))
	Ui.stroke(coinsPill, 4)
	Ui.gradient(coinsPill, Color3.fromRGB(255, 248, 210), Color3.fromRGB(255, 206, 120))
	coinIcon = Ui.frame(coinsPill, {
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.fromOffset(7, 7),
		BackgroundColor3 = Color3.fromRGB(255, 208, 110),
	})
	Ui.corner(coinIcon, UDim.new(1, 0))
	Ui.stroke(coinIcon, 3)
	Ui.label(coinIcon, "$", { Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.15, 0.15) })
	coinsLabel = Ui.label(coinsPill, "0", {
		Size = UDim2.new(1, -80, 0.72, 0),
		Position = UDim2.new(0, 68, 0.14, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- Niveau + barre de progression
	local levelBar = Ui.frame(gui, {
		Name = "Level",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 82),
		Size = UDim2.fromOffset(240, 26),
		BackgroundColor3 = Color3.fromRGB(120, 100, 150),
	})
	Ui.corner(levelBar, UDim.new(1, 0))
	Ui.stroke(levelBar, 3)
	levelFill = Ui.frame(levelBar, {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Ui.White,
	})
	Ui.corner(levelFill, UDim.new(1, 0))
	Ui.gradient(levelFill, Color3.fromRGB(190, 244, 200), Color3.fromRGB(130, 210, 160))
	levelBadge = Ui.label(levelBar, t("Level", { n = 1 }), {
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 3,
	})
end

local function buildChips()
	stormChip = Ui.frame(gui, {
		Name = "Storm",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(250, 44),
		BackgroundColor3 = Ui.White,
	})
	Ui.corner(stormChip, UDim.new(1, 0))
	Ui.stroke(stormChip, 3)
	local g = Ui.gradient(stormChip, Color3.fromRGB(214, 196, 255), Color3.fromRGB(170, 146, 236))
	g.Name = "Gradient"
	stormLabel = Ui.label(stormChip, "", { Size = UDim2.new(1, -20, 0.72, 0), Position = UDim2.new(0, 10, 0.14, 0) })

	boostChip = Ui.frame(gui, {
		Name = "Boost",
		Position = UDim2.fromOffset(12, 62),
		Size = UDim2.fromOffset(200, 38),
		BackgroundColor3 = Ui.White,
		Visible = false,
	})
	Ui.corner(boostChip, UDim.new(1, 0))
	Ui.stroke(boostChip, 3)
	Ui.gradient(boostChip, Color3.fromRGB(255, 240, 180), Color3.fromRGB(255, 200, 120))
	boostLabel = Ui.label(boostChip, "", { Size = UDim2.new(1, -16, 0.72, 0), Position = UDim2.new(0, 8, 0.14, 0) })

	local speedChip = Ui.frame(gui, {
		Name = "Speed",
		Position = UDim2.fromOffset(222, 62),
		Size = UDim2.fromOffset(150, 38),
		BackgroundColor3 = Ui.White,
	})
	Ui.corner(speedChip, UDim.new(1, 0))
	Ui.stroke(speedChip, 3)
	Ui.gradient(speedChip, Color3.fromRGB(190, 246, 232), Color3.fromRGB(120, 210, 190))
	speedLabel = Ui.label(speedChip, "👟 16", { Size = UDim2.new(1, -16, 0.72, 0), Position = UDim2.new(0, 8, 0.14, 0) })

	eventChip = Ui.frame(gui, {
		Name = "Event",
		Position = UDim2.fromOffset(12, 108),
		Size = UDim2.fromOffset(300, 38),
		BackgroundColor3 = Ui.White,
		Visible = false,
	})
	Ui.corner(eventChip, UDim.new(1, 0))
	Ui.stroke(eventChip, 3)
	Ui.gradient(eventChip, Color3.fromRGB(255, 206, 160), Color3.fromRGB(186, 150, 226))
	eventLabel = Ui.label(eventChip, "", { Size = UDim2.new(1, -16, 0.72, 0), Position = UDim2.new(0, 8, 0.14, 0) })
end

local function buildBanner()
	banner = Ui.frame(gui, {
		Name = "ResetBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 118),
		Size = UDim2.fromOffset(480, 54),
		BackgroundColor3 = Ui.White,
		Visible = false,
	})
	Ui.corner(banner, UDim.new(0, 18))
	Ui.stroke(banner, 3)
	Ui.gradient(banner, Color3.fromRGB(255, 196, 222), Ui.Pink)
	bannerLabel = Ui.label(banner, "", { Size = UDim2.new(0.68, -10, 0.7, 0), Position = UDim2.new(0, 14, 0.15, 0) })
	bonusLabel = Ui.label(banner, "", {
		Size = UDim2.new(0.3, -14, 0.8, 0),
		Position = UDim2.new(0.7, 0, 0.1, 0),
		TextColor3 = Color3.fromRGB(255, 244, 196),
	})
end

local function buildQuests()
	questPanel = Ui.frame(gui, {
		Name = "Quests",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.48, 0),
		Size = UDim2.fromOffset(250, 236),
		BackgroundTransparency = 1,
	})
	local title = Ui.label(questPanel, "📜 " .. t("Quests"), {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	title.Name = "Title"
	for i = 1, Config.QuestCount do
		local card = Ui.frame(questPanel, {
			Name = "Quest" .. i,
			Position = UDim2.fromOffset(0, 36 + (i - 1) * 66),
			Size = UDim2.new(1, 0, 0, 60),
			BackgroundColor3 = Ui.White,
			BackgroundTransparency = 0.05,
		})
		Ui.corner(card, UDim.new(0, 14))
		Ui.stroke(card, 3)
		local text = Ui.label(card, "", {
			Name = "Text",
			Size = UDim2.new(1, -16, 0, 22),
			Position = UDim2.fromOffset(8, 5),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Ui.Ink,
		})
		local textStroke = text:FindFirstChildOfClass("UIStroke")
		if textStroke then
			textStroke:Destroy()
		end
		local bar = Ui.frame(card, {
			Name = "Bar",
			Size = UDim2.new(1, -16, 0, 20),
			Position = UDim2.fromOffset(8, 32),
			BackgroundColor3 = Color3.fromRGB(225, 215, 240),
		})
		Ui.corner(bar, UDim.new(1, 0))
		local fill = Ui.frame(bar, { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Ui.White })
		Ui.corner(fill, UDim.new(1, 0))
		Ui.gradient(fill, Color3.fromRGB(255, 150, 210), Ui.Pink)
		Ui.label(bar, "", { Name = "Count", Size = UDim2.fromScale(1, 1), ZIndex = 3 })
		table.insert(questCards, card)
	end
end

local function buildToasts()
	toastHolder = Ui.frame(gui, {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 180),
		Size = UDim2.fromOffset(520, 200),
		BackgroundTransparency = 1,
	})
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.Parent = toastHolder

	celebration = Ui.frame(gui, {
		Name = "Celebration",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(560, 150),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 40,
	})
	celebrationTitle = Ui.label(celebration, "", { Size = UDim2.new(1, 0, 0.62, 0), ZIndex = 41 })
	celebrationSub = Ui.label(celebration, "", {
		Size = UDim2.new(1, 0, 0.34, 0),
		Position = UDim2.fromScale(0, 0.64),
		ZIndex = 41,
		TextColor3 = Color3.fromRGB(255, 240, 190),
	})
end

---------------------------------------------------------------- messages
function Hud.toast(text: string, color: Color3?)
	local f = Ui.frame(toastHolder, {
		Size = UDim2.fromOffset(460, 44),
		BackgroundColor3 = Ui.White,
	})
	Ui.corner(f, UDim.new(1, 0))
	Ui.stroke(f, 3)
	local c = color or Ui.Blue
	Ui.gradient(f, Ui.lighten(c, 0.3), c)
	Ui.label(f, text, { Size = UDim2.new(1, -24, 0.72, 0), Position = UDim2.new(0, 12, 0.14, 0) })
	Ui.bounce(f, 0.25)
	task.delay(3, function()
		f:Destroy()
	end)
end

local celebrationToken = 0
function Hud.celebrate(title: string, subtitle: string?, confetti: boolean?)
	celebrationToken += 1
	local token = celebrationToken
	celebrationTitle.Text = title
	celebrationSub.Text = subtitle or ""
	celebration.Visible = true
	Ui.bounce(celebration, 0.6)
	Effects.play(Config.Sounds.Reward, 0.6, 1)
	if confetti ~= false then
		Ui.confetti(gui, 50)
	end
	task.delay(2.6, function()
		if celebrationToken == token then
			celebration.Visible = false
		end
	end)
end

-- Pièces qui volent du monde vers le compteur
function Hud.coinsGained(amount: number, worldPos: Vector3?)
	if amount <= 0 then
		return
	end
	Ui.bounce(coinsPill, 0.12)
	-- son de pièce (limité pour ne pas saturer quand on enchaîne)
	local now = os.clock()
	if now - lastCoinSound > 0.08 then
		lastCoinSound = now
		Effects.play(Config.Sounds.Coin, 0.35, 0.95 + math.random() * 0.1)
	end
	local camera = workspace.CurrentCamera
	if not worldPos or not camera then
		return
	end
	local sp, onScreen = camera:WorldToViewportPoint(worldPos)
	if not onScreen then
		return
	end
	local inset = gui.AbsolutePosition
	local target = coinIcon.AbsolutePosition + coinIcon.AbsoluteSize / 2 - inset
	local scale = gui:FindFirstChildOfClass("UIScale") :: UIScale?
	local s = if scale then scale.Scale else 1
	local count = math.clamp(math.floor(math.log10(amount + 1) * 2) + 1, 1, 5)
	for i = 1, count do
		local coin = Ui.frame(gui, {
			Size = UDim2.fromOffset(26, 26),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((sp.X - inset.X) / s + math.random(-20, 20), (sp.Y - inset.Y) / s + math.random(-20, 20)),
			BackgroundColor3 = Color3.fromRGB(255, 210, 120),
			ZIndex = 30,
		})
		Ui.corner(coin, UDim.new(1, 0))
		Ui.stroke(coin, 2)
		local duration = 0.45 + i * 0.06
		TweenService:Create(coin, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromOffset(target.X / s, target.Y / s),
			Size = UDim2.fromOffset(18, 18),
			Rotation = 360,
		}):Play()
		-- reflet de la pièce (elle brille en volant)
		local shine = Ui.frame(coin, {
			Position = UDim2.fromScale(0.2, 0.15),
			Size = UDim2.fromScale(0.3, 0.3),
			BackgroundColor3 = Ui.White,
			BackgroundTransparency = 0.2,
			ZIndex = 31,
		})
		Ui.corner(shine, UDim.new(1, 0))
		task.delay(duration, function()
			coin:Destroy()
		end)
	end
end

---------------------------------------------------------------- mises à jour
local function translateVars(vars: any): any
	if type(vars) ~= "table" then
		return vars
	end
	local out = {}
	for k, v in vars do
		out[k] = if type(v) == "string" and string.sub(v, 1, 5) == "Zone_" then t(v) else v
	end
	return out
end

local function updateQuests(state: { [string]: any })
	local quests = state.Quests or {}
	for i, card in questCards do
		local q = quests[i]
		card.Visible = q ~= nil
		if q then
			local def = Config.quest(q.Id)
			local text = card:FindFirstChild("Text") :: TextLabel
			text.Text = t(if def then def.TextKey else q.Id, { n = Formulas.formatNumber(q.Target) })
				.. "  💰" .. Formulas.formatNumber(q.Reward)
			local bar = card:FindFirstChild("Bar") :: Frame
			local fill = bar:FindFirstChild("Fill") :: Frame
			local ratio = math.clamp(q.Progress / math.max(1, q.Target), 0, 1)
			TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(ratio, 1) }):Play()
			local count = bar:FindFirstChild("Count") :: TextLabel
			count.Text = Formulas.formatNumber(q.Progress) .. " / " .. Formulas.formatNumber(q.Target)
		end
	end
	local title = questPanel:FindFirstChild("Title") :: TextLabel
	title.Text = "📜 " .. t("Quests")
end

local function onState(state: { [string]: any })
	targetCoins = state.Coins or targetCoins
	local level = state.Level or 1
	levelBadge.Text = t("Level", { n = level })
	TweenService:Create(levelFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(state.LevelProgress or 0, 0.04, 1), 1) }):Play()
	lastLevel = level
	if type(state.Speed) == "number" then
		speedLabel.Text = "👟 " .. t("SpeedStat", { n = state.Speed })
	end
	updateQuests(state)
end

local function currentZone(): Instance?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local pos = (root :: BasePart).Position
	local map = workspace:FindFirstChild("Map")
	local zones = map and map:FindFirstChild("Zones")
	if not zones then
		return nil
	end
	for _, zone in zones:GetChildren() do
		local ox, oz = zone:GetAttribute("OriginX"), zone:GetAttribute("OriginZ")
		local cx, cz = zone:GetAttribute("CountX"), zone:GetAttribute("CountZ")
		if type(ox) == "number" and type(oz) == "number" and type(cx) == "number" and type(cz) == "number" then
			local w, d = cx * Config.TileSize, cz * Config.TileSize
			if pos.X >= ox and pos.X <= ox + w and pos.Z >= oz and pos.Z <= oz + d then
				return zone
			end
		end
	end
	return nil
end
Hud.currentZone = currentZone

local function updateTimers()
	local now = workspace:GetServerTimeNow()
	-- Rainbow Storm
	local active = workspace:GetAttribute("StormActive") == true
	local g = stormChip:FindFirstChild("Gradient") :: UIGradient?
	if active then
		local endsAt = workspace:GetAttribute("StormEndsAt")
		stormLabel.Text = "🌈 " .. t("Storm", { n = Config.StormMultiplier }) .. " "
			.. Formulas.formatTime((if type(endsAt) == "number" then endsAt else now) - now)
		if g then
			g.Rotation = (os.clock() * 120) % 360
			g.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Ui.Pink),
				ColorSequenceKeypoint.new(0.33, Ui.Yellow),
				ColorSequenceKeypoint.new(0.66, Ui.Green),
				ColorSequenceKeypoint.new(1, Ui.Blue),
			})
		end
	else
		local nextAt = workspace:GetAttribute("NextStormAt")
		local remaining = (if type(nextAt) == "number" then nextAt else now) - now
		stormLabel.Text = "🌈 " .. t("StormIn", { time = Formulas.formatTime(remaining) })
		if g then
			g.Rotation = 90
			g.Color = ColorSequence.new(Color3.fromRGB(214, 196, 255), Color3.fromRGB(170, 146, 236))
		end
	end
	-- Événement en cours
	local shown = false
	for _, ev in Config.Events do
		if workspace:GetAttribute("Event_" .. ev.Id) == true then
			local ends = workspace:GetAttribute("EventEnds_" .. ev.Id)
			local left = (if type(ends) == "number" then ends else now) - now
			local timeText = if left > 86400 then tostring(math.floor(left / 86400)) .. "d" else Formulas.formatTime(left)
			eventLabel.Text = ev.Icon .. " " .. t("EventEnds", { event = t(ev.NameKey), time = timeText })
			shown = true
			break
		end
	end
	eventChip.Visible = shown
	-- Boost
	local s = State.current
	local boostUntil = s and s.BoostUntil or 0
	local left = boostUntil - os.time()
	boostChip.Visible = left > 0
	if left > 0 then
		boostLabel.Text = "⚡ " .. t("Boost", { time = Formulas.formatTime(left) })
	end
	-- Compte à rebours de la zone
	local zone = currentZone()
	if not zone then
		banner.Visible = false
		return
	end
	local zoneName = t("Zone_" .. zone.Name)
	if zone:GetAttribute("Washing") == true then
		banner.Visible = true
		bannerLabel.Text = t("Resetting", { zone = zoneName })
		bonusLabel.Text = ""
		return
	end
	local resetAt = zone:GetAttribute("ResetAt")
	if type(resetAt) ~= "number" then
		banner.Visible = false
		return
	end
	local remaining = resetAt - now
	if remaining <= Config.ZoneCountdown then
		banner.Visible = true
		bannerLabel.Text = t("ResetIn", { zone = zoneName, time = Formulas.formatTime(remaining) })
		bonusLabel.Text = t("Bonus", { n = Config.CountdownMultiplier })
		bonusLabel.Rotation = math.sin(os.clock() * 6) * 5
	else
		banner.Visible = false
	end
end

---------------------------------------------------------------- effets serveur
local function onEffect(kind: string, data: any)
	if kind == "QuestDone" then
		Hud.celebrate("✅ " .. t("QuestDone", { n = Formulas.formatNumber(data.Reward) }), nil, true)
	elseif kind == "LevelUp" then
		Hud.celebrate("⭐ " .. t("LevelUp", { n = data.Level }), nil, true)
	elseif kind == "ZoneUnlocked" then
		Hud.celebrate("🔓 " .. t("ZoneUnlocked", { zone = t("Zone_" .. data.Zone) }), nil, true)
	elseif kind == "Upgraded" then
		Effects.play(Config.Sounds.Reward, 0.4, 1.3)
		Hud.toast("⬆️ " .. t("Upgraded"), Ui.Green)
	elseif kind == "Offline" then
		Hud.celebrate("💤 " .. t("Offline", { n = Formulas.formatNumber(data.Coins) }), nil, true)
	elseif kind == "TutorialDone" then
		Hud.celebrate("🎉 " .. t("T_Done", { n = data.Reward }), nil, true)
	elseif kind == "DailyClaimed" then
		Hud.celebrate("🎁 " .. t("Day", { n = data.Day }), nil, true)
	end
end

function Hud.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "PopaintHud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")
	Hud.gui = gui

	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local function rescale()
		local cam = workspace.CurrentCamera
		if cam then
			local short = math.min(cam.ViewportSize.X, cam.ViewportSize.Y)
			scale.Scale = math.clamp(short / 760, 0.55, 1.3)
		end
	end
	rescale()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	buildCoins()
	buildChips()
	buildBanner()
	buildQuests()
	buildToasts()

	-- Barre de boutons en bas à gauche (compagnons, cadeau du jour)
	local leftBar = Ui.frame(gui, {
		Name = "LeftBar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(84, 190),
		BackgroundTransparency = 1,
	})
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = leftBar
	Hud.leftBar = leftBar

	targetCoins = tonumber(player:GetAttribute("Coins")) or 0
	displayedCoins = targetCoins
	coinsLabel.Text = Formulas.formatNumber(displayedCoins)
	player:GetAttributeChangedSignal("Coins"):Connect(function()
		targetCoins = tonumber(player:GetAttribute("Coins")) or targetCoins
	end)

	State.onChange(onState)
	Remotes.event("Effect").OnClientEvent:Connect(onEffect)
	Remotes.event("Notify").OnClientEvent:Connect(function(key: string, vars: any, kind: string?)
		if kind == "error" then
			Effects.play(Config.Sounds.Error, 0.3, 1.4)
		end
		Hud.toast(t(key, translateVars(vars)), if kind == "error" then Ui.Red else Ui.Blue)
	end)

	if player:GetAttribute("SaveOff") == true then
		Hud.toast(t("SaveOff"), Ui.Purple)
	end

	local acc = 0
	RunService.RenderStepped:Connect(function(dt: number)
		if displayedCoins ~= targetCoins then
			local diff = targetCoins - displayedCoins
			local step = diff * math.min(1, dt * 10)
			if math.abs(diff) < 1 or math.abs(step) < 0.5 then
				displayedCoins = targetCoins
			else
				displayedCoins += step
			end
			coinsLabel.Text = Formulas.formatNumber(displayedCoins)
		end
		if celebration.Visible then
			celebrationTitle.Rotation = math.sin(os.clock() * 8) * 3
		end
		acc += dt
		if acc >= 0.1 then
			acc = 0
			updateTimers()
		end
	end)
	local _ = lastLevel
end

return Hud
