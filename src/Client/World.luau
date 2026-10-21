--!strict
-- Popaint : réglages du monde côté joueur (portails verrouillés, ambiance Rainbow Storm, étiquettes des bases).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Formulas = require(Shared:WaitForChild("Formulas")) :: any
local Ui = require(script.Parent:WaitForChild("Ui")) :: any
local State = require(script.Parent:WaitForChild("State")) :: any
local Hud = require(script.Parent:WaitForChild("Hud")) :: any

local World = {}

local player = Players.LocalPlayer
local t = Ui.t

local function updateGates(state: any)
	local gates = workspace:WaitForChild("Map"):WaitForChild("Gates")
	for _, gate in gates:GetChildren() do
		if gate:IsA("BasePart") then
			local g = gate :: BasePart
			local unlocked = state.Zones and state.Zones[g.Name] == true
			-- La collision n'existe que chez ce joueur : les autres passent s'ils ont débloqué
			g.CanCollide = not unlocked
			g.Transparency = if unlocked then 1 else 0
			local zone = Config.zone(g.Name)
			local label = g:FindFirstChild("GateLabel", true)
			local ev = zone and zone.Event and Config.event(zone.Event)
			if label and label:IsA("TextLabel") and zone then
				local text: string
				if unlocked then
					text = ""
				elseif ev then
					text = ev.Icon .. " " .. t(zone.DisplayKey) .. "\n" .. t("EventClosed", { event = t(ev.NameKey) })
				else
					text = t(zone.DisplayKey) .. "\n🔒 💰 " .. Formulas.formatNumber(zone.Cost)
				end
				(label :: TextLabel).Text = text
			end
			local prompt = g:FindFirstChild("UnlockPrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				local p = prompt :: ProximityPrompt
				p.Enabled = not unlocked and not ev
				p.ActionText = t("Unlock")
				p.ObjectText = if zone then t(zone.DisplayKey) .. " (" .. Formulas.formatNumber(zone.Cost) .. ")" else ""
			end
		end
	end
end

-- Étiquettes des œufs : prix réel du joueur (les œufs d'événement suivent sa progression)
local RARITY_ORDER = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5 }
local function updateEggLabels(state: any)
	local eggs = workspace:WaitForChild("Map"):WaitForChild("Eggs")
	for _, egg in eggs:GetChildren() do
		local zone = Config.zone(egg.Name)
		local label = egg:FindFirstChild("EggLabel", true)
		if zone and label and label:IsA("TextLabel") then
			local ids = table.clone(Config.EggContents[zone.Id] or {})
			table.sort(ids, function(a, b)
				return RARITY_ORDER[Config.Companions[a].Rarity] < RARITY_ORDER[Config.Companions[b].Rarity]
			end)
			local lines = { t("EggTitle", { zone = t(zone.DisplayKey) }) }
			local cost = state.EggCosts and state.EggCosts[zone.Id] or zone.EggCost
			table.insert(lines, "💰 " .. Formulas.formatNumber(cost))
			for _, id in ids do
				local def = Config.Companions[id]
				for _, r in Config.Rarities do
					if r.Id == def.Rarity then
						table.insert(lines, def.Name .. "  " .. tostring(r.Chance) .. "%")
					end
				end
			end
			if zone.Event then
				local ev = Config.event(zone.Event)
				if ev then
					table.insert(lines, 1, ev.Icon .. " " .. t("EventOnly", { event = t(ev.NameKey) }))
				end
			end
			(label :: TextLabel).Text = table.concat(lines, "\n")
		end
	end
end

local function updateBaseLabels()
	local bases = workspace:WaitForChild("Map"):WaitForChild("Hub"):WaitForChild("Bases")
	local mine = player:GetAttribute("BaseName")
	for _, base in bases:GetChildren() do
		local label = base:FindFirstChild("OwnerLabel", true)
		if label and label:IsA("TextLabel") then
			local l = label :: TextLabel
			if base.Name == mine then
				l.TextColor3 = Ui.Yellow
			else
				l.TextColor3 = Ui.White
			end
		end
	end
end

function World.start()
	State.onChange(updateGates)
	State.onChange(updateEggLabels)
	updateBaseLabels()
	player:GetAttributeChangedSignal("BaseName"):Connect(updateBaseLabels)

	-- Ambiance du Rainbow Storm : couleurs qui tournent et saturation boostée
	local cc = Lighting:FindFirstChild("PopaintColor")
	local baseSat = if cc and cc:IsA("ColorCorrectionEffect") then (cc :: ColorCorrectionEffect).Saturation else 0.3
	local wasActive = false
	RunService.RenderStepped:Connect(function()
		local active = workspace:GetAttribute("StormActive") == true
		if cc and cc:IsA("ColorCorrectionEffect") then
			local c = cc :: ColorCorrectionEffect
			if active then
				local hue = (os.clock() * 0.15) % 1
				c.TintColor = Color3.fromHSV(hue, 0.12, 1)
				c.Saturation = baseSat + 0.25
			elseif wasActive then
				c.TintColor = Color3.fromRGB(255, 248, 255)
				c.Saturation = baseSat
			end
		end
		if active and not wasActive then
			Hud.celebrate("🌈 " .. t("Storm", { n = Config.StormMultiplier }), nil, true)
		end
		wasActive = active
	end)

	-- Traînées animées (couleurs qui défilent), pour tous les joueurs
	task.spawn(function()
		while true do
			task.wait(0.1)
			for _, p in Players:GetPlayers() do
				local character = p.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local trail = root and root:FindFirstChild("PopaintTrail")
				if trail and trail:IsA("Trail") and trail:GetAttribute("Animated") == true then
					local tr = trail :: Trail
					local keys = tr.Color.Keypoints
					local colors = {}
					for i, k in keys do
						colors[i] = k.Value
					end
					local shifted = {}
					for i, k in keys do
						table.insert(shifted, ColorSequenceKeypoint.new(k.Time, colors[(i % #colors) + 1]))
					end
					tr.Color = ColorSequence.new(shifted)
				end
			end
		end
	end)

	-- Événements : annonce à l'arrivée et au démarrage
	local announcedEvents: { [string]: boolean } = {}
	task.spawn(function()
		while true do
			for _, ev in Config.Events do
				local on = workspace:GetAttribute("Event_" .. ev.Id) == true
				if on and not announcedEvents[ev.Id] then
					announcedEvents[ev.Id] = true
					Hud.celebrate(ev.Icon .. " " .. t("EventStarted", { event = t(ev.NameKey) }), nil, true)
				elseif not on then
					announcedEvents[ev.Id] = nil
				end
			end
			task.wait(3)
		end
	end)

	-- Annonce 5 minutes avant le Storm
	local announced = 0
	task.spawn(function()
		while true do
			task.wait(1)
			local nextAt = workspace:GetAttribute("NextStormAt")
			if type(nextAt) == "number" and workspace:GetAttribute("StormActive") ~= true then
				local remaining = nextAt - workspace:GetServerTimeNow()
				if remaining <= Config.StormAnnounce and remaining > 0 and announced ~= nextAt then
					announced = nextAt
					Hud.toast("🌈 " .. t("StormSoon", { time = Formulas.formatTime(remaining) }), Ui.Purple)
				end
			end
		end
	end)
end

return World
