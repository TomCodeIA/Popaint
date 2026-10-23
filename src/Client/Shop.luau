--!strict
-- Popaint : boutique d'améliorations, ouverte à sa propre machine à bulles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Formulas = require(Shared:WaitForChild("Formulas")) :: any
local Ui = require(script.Parent:WaitForChild("Ui")) :: any
local State = require(script.Parent:WaitForChild("State")) :: any
local Hud = require(script.Parent:WaitForChild("Hud")) :: any

local Shop = {}

local player = Players.LocalPlayer
local t = Ui.t

local window: Frame
local rows: { [string]: Frame } = {}
local trailRows: { [string]: Frame } = {}

local function myMachine(): BasePart?
	local baseName = player:GetAttribute("BaseName")
	if type(baseName) ~= "string" then
		return nil
	end
	local bases = workspace:WaitForChild("Map"):WaitForChild("Hub"):WaitForChild("Bases")
	local base = bases:FindFirstChild(baseName)
	local body = base and base:FindFirstChild("MachineBody")
	if body and body:IsA("BasePart") then
		return body :: BasePart
	end
	return nil
end

local function eventActive(id: string?): boolean
	return id == nil or workspace:GetAttribute("Event_" .. id) == true
end

local function refreshTrails(state: { [string]: any })
	local ownedList = state.Cosmetics or {}
	for id, row in trailRows do
		local def = Config.cosmetic(id)
		if def then
			local owned = ownedList[id] == true
			local available = owned or eventActive(def.Event)
			row.Visible = available
			local buy = row:FindFirstChild("Buy") :: TextButton
			local tag = row:FindFirstChild("Tag") :: TextLabel
			if def.Event then
				local ev = Config.event(def.Event)
				tag.Text = (ev and ev.Icon or "") .. " " .. t("EventOnly", { event = t(ev and ev.NameKey or def.Event) })
			else
				tag.Text = ""
			end
			if state.EquippedTrail == id then
				buy.Text = "✔ " .. t("Equipped")
			elseif owned then
				buy.Text = t("Equip")
			else
				buy.Text = "💰 " .. Formulas.formatNumber(def.Cost)
			end
			local affordable = owned or (state.Coins or 0) >= def.Cost
			buy.TextTransparency = if affordable then 0 else 0.35
		end
	end
end

local function refresh(state: { [string]: any })
	refreshTrails(state)
	for id, row in rows do
		local info = state.Upgrades and state.Upgrades[id]
		if info then
			local lvl = row:FindFirstChild("Level") :: TextLabel
			lvl.Text = t("Level", { n = info.Level }) .. " / " .. tostring(info.Max)
			local buy = row:FindFirstChild("Buy") :: TextButton
			if info.Level >= info.Max then
				buy.Text = t("Max")
				buy.AutoButtonColor = false
			else
				buy.Text = "💰 " .. Formulas.formatNumber(info.Cost)
			end
			local affordable = info.Level < info.Max and (state.Coins or 0) >= info.Cost
			local stroke = buy:FindFirstChildOfClass("UIStroke")
			if stroke then
				(stroke :: UIStroke).Color = if affordable then Ui.Ink else Color3.fromRGB(160, 140, 180)
			end
			buy.TextTransparency = if affordable then 0 else 0.35
		end
	end
end

function Shop.open()
	Ui.open(window)
	State.action("OpenedShop")
	if State.current then
		refresh(State.current)
	end
end

function Shop.start()
	local gui = Hud.gui :: ScreenGui
	local content
	window, content = Ui.window(gui, "🫧 " .. t("ShopTitle"), Ui.Blue, UDim2.fromOffset(620, 560))
	window.Name = "Shop"

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ZIndex = 11
	scroll.Parent = content
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	for index, def in Config.Upgrades do
		local row = Ui.frame(scroll, {
			Name = def.Id,
			LayoutOrder = index,
			Size = UDim2.new(1, -14, 0, 84),
			BackgroundColor3 = Ui.White,
			ZIndex = 11,
		})
		Ui.corner(row, UDim.new(0, 16))
		Ui.stroke(row, 3)
		Ui.gradient(row, def.Color, Ui.lighten(def.Color, 0.18))
		local icon = Ui.frame(row, {
			Size = UDim2.fromOffset(64, 64),
			Position = UDim2.fromOffset(10, 10),
			BackgroundColor3 = def.Color,
			ZIndex = 12,
		})
		Ui.corner(icon, UDim.new(0, 14))
		Ui.stroke(icon, 3)
		Ui.label(icon, def.Icon, { Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ZIndex = 13 })
		Ui.label(row, t(def.NameKey), {
			Name = "Name",
			Size = UDim2.new(0.5, -90, 0, 30),
			Position = UDim2.fromOffset(86, 8),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
		})
		Ui.label(row, t(def.DescKey), {
			Name = "Desc",
			Size = UDim2.new(0.55, -90, 0, 20),
			Position = UDim2.fromOffset(86, 40),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Ui.Ink,
			ZIndex = 12,
		})
		Ui.label(row, "", {
			Name = "Level",
			Size = UDim2.new(0.3, 0, 0, 22),
			Position = UDim2.new(0.42, 0, 0, 10),
			TextColor3 = Color3.fromRGB(255, 240, 190),
			ZIndex = 12,
		})
		local buy = Ui.button(row, "", Ui.Green, function()
			State.action("BuyUpgrade", def.Id)
		end, {
			Name = "Buy",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(170, 58),
			ZIndex = 12,
		})
		buy.Name = "Buy"
		rows[def.Id] = row
	end

	-- Traînées
	local header = Ui.label(scroll, "✨ " .. t("Trails"), {
		Name = "TrailsHeader",
		Size = UDim2.new(1, -14, 0, 40),
		LayoutOrder = 100,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
	})
	header.Name = "TrailsHeader"
	local noTrail = Ui.button(scroll, t("NoTrail"), Color3.fromRGB(170, 160, 190), function()
		State.action("EquipCosmetic", "")
	end, { Name = "NoTrail", Size = UDim2.new(1, -14, 0, 44), LayoutOrder = 101, ZIndex = 12 })
	noTrail.Name = "NoTrail"
	for index, def in Config.Cosmetics do
		local row = Ui.frame(scroll, {
			Name = "Trail_" .. def.Id,
			LayoutOrder = 101 + index,
			Size = UDim2.new(1, -14, 0, 74),
			BackgroundColor3 = Ui.White,
			ZIndex = 11,
		})
		Ui.corner(row, UDim.new(0, 16))
		Ui.stroke(row, 3)
		-- aperçu de la traînée : bande dégradée
		local preview = Ui.frame(row, {
			Size = UDim2.fromOffset(120, 22),
			Position = UDim2.fromOffset(12, 40),
			BackgroundColor3 = Ui.White,
			ZIndex = 12,
		})
		Ui.corner(preview, UDim.new(1, 0))
		Ui.stroke(preview, 2)
		local keys = {}
		for k, c in def.Colors do
			table.insert(keys, ColorSequenceKeypoint.new(if #def.Colors == 1 then 0 else (k - 1) / (#def.Colors - 1), c))
		end
		if #keys == 1 then
			table.insert(keys, ColorSequenceKeypoint.new(1, def.Colors[1]))
		end
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(keys)
		g.Parent = preview
		Ui.label(row, def.Name, {
			Size = UDim2.new(0.5, 0, 0, 28),
			Position = UDim2.fromOffset(12, 6),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Ui.Ink,
			ZIndex = 12,
		})
		Ui.label(row, "", {
			Name = "Tag",
			Size = UDim2.new(0.3, 0, 0, 22),
			Position = UDim2.new(0.3, 0, 0, 42),
			TextColor3 = Ui.Yellow,
			ZIndex = 12,
		})
		local buy = Ui.button(row, "", Ui.Green, function()
			local st = State.current
			if st and st.Cosmetics and st.Cosmetics[def.Id] then
				State.action("EquipCosmetic", def.Id)
			else
				State.action("BuyCosmetic", def.Id)
			end
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(170, 54),
			ZIndex = 12,
		})
		buy.Name = "Buy"
		trailRows[def.Id] = row
	end

	State.onChange(function(state: { [string]: any })
		if window.Visible then
			refresh(state)
		end
	end)

	-- Invites des machines : seule la mienne s'affiche et ouvre la boutique
	local function wirePrompts()
		local bases = workspace:WaitForChild("Map"):WaitForChild("Hub"):WaitForChild("Bases")
		local mine = myMachine()
		for _, base in bases:GetChildren() do
			local prompt = base:FindFirstChild("ShopPrompt", true)
			if prompt and prompt:IsA("ProximityPrompt") then
				local p = prompt :: ProximityPrompt
				p.Enabled = mine ~= nil and p.Parent == mine
				p.ActionText = t("Buy")
				p.ObjectText = t("ShopTitle")
			end
		end
	end
	wirePrompts()
	player:GetAttributeChangedSignal("BaseName"):Connect(wirePrompts)
	player:GetAttributeChangedSignal("Language"):Connect(wirePrompts)

	local bases = workspace:WaitForChild("Map"):WaitForChild("Hub"):WaitForChild("Bases")
	for _, base in bases:GetChildren() do
		local prompt = base:FindFirstChild("ShopPrompt", true)
		if prompt and prompt:IsA("ProximityPrompt") then
			(prompt :: ProximityPrompt).Triggered:Connect(function()
				if myMachine() == (prompt :: ProximityPrompt).Parent then
					Shop.open()
				end
			end)
		end
	end

	-- La boutique se ferme si on s'éloigne de sa machine
	task.spawn(function()
		while true do
			task.wait(0.5)
			if window.Visible then
				local machine = myMachine()
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not machine or not root or not root:IsA("BasePart")
					or ((root :: BasePart).Position - machine.Position).Magnitude > Config.MachineReach then
					Ui.close(window)
				end
			end
		end
	end)
end

return Shop
