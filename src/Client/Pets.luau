--!strict
-- Popaint : compagnons bulles (inventaire, éclosion des œufs, compagnons qui suivent les joueurs).

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
local Hud = require(script.Parent:WaitForChild("Hud")) :: any
local Effects = require(script.Parent:WaitForChild("Effects")) :: any

local Pets = {}

local t = Ui.t

local window: Frame
local grid: ScrollingFrame
local detail: Frame
local countLabel: TextLabel
local selectedUid: number? = nil

local RAINBOW = Config.PaintPalette

local function rarityColor(rarity: string): Color3
	for _, r in Config.Rarities do
		if r.Id == rarity then
			return r.Color
		end
	end
	return Ui.White
end

-- Petite tête de compagnon en interface (rond coloré + yeux)
local function icon(parent: Instance, id: string, tier: number, size: number): Frame
	local def = Config.Companions[id]
	local body = Ui.frame(parent, {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = if def then def.Color else Ui.White,
		ZIndex = 13,
	})
	Ui.corner(body, UDim.new(1, 0))
	Ui.stroke(body, 3, if tier == 1 then Color3.fromRGB(255, 200, 40) elseif tier == 2 then Ui.Pink else Ui.Ink)
	for _, x in { 0.32, 0.68 } do
		local eye = Ui.frame(body, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.45),
			Size = UDim2.fromScale(0.16, 0.22),
			BackgroundColor3 = Ui.Ink,
			ZIndex = 14,
		})
		Ui.corner(eye, UDim.new(1, 0))
	end
	local shine = Ui.frame(body, {
		Position = UDim2.fromScale(0.18, 0.12),
		Size = UDim2.fromScale(0.22, 0.14),
		BackgroundColor3 = Ui.White,
		BackgroundTransparency = 0.3,
		ZIndex = 14,
	})
	Ui.corner(shine, UDim.new(1, 0))
	if tier == 2 then
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, RAINBOW[1]),
			ColorSequenceKeypoint.new(0.5, RAINBOW[3]),
			ColorSequenceKeypoint.new(1, RAINBOW[2]),
		})
		g.Parent = body
	end
	return body
end
Pets.icon = icon

local function bonusText(id: string, tier: number): string
	local def = Config.Companions[id]
	if not def then
		return ""
	end
	local b = Formulas.companionBonus(Config.RarityBonus[def.Rarity] or {}, def.Power, Config.TierMultipliers[tier] or 1)
	local parts = {}
	if b.Coins then
		table.insert(parts, t("BonusCoins", { n = math.floor(b.Coins * 100 + 0.5) }))
	end
	if b.Radius then
		table.insert(parts, t("BonusRadius", { n = math.floor(b.Radius * 100 + 0.5) }))
	end
	if b.AutoPop then
		table.insert(parts, t("BonusAutoPop", { n = b.AutoPop }))
	end
	return table.concat(parts, "\n")
end

local function findCompanion(state: any, uid: number): any
	for _, c in state.Companions or {} do
		if c.Uid == uid then
			return c
		end
	end
	return nil
end

local function countSame(state: any, c: any): number
	local n = 0
	for _, o in state.Companions or {} do
		if o.Id == c.Id and o.Tier == c.Tier then
			n += 1
		end
	end
	return n
end

local function refreshDetail(state: any)
	for _, child in detail:GetChildren() do
		if not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
	local c = if selectedUid then findCompanion(state, selectedUid) else nil
	if not c then
		Ui.label(detail, "🐾", { Size = UDim2.fromScale(0.6, 0.3), Position = UDim2.fromScale(0.2, 0.3), ZIndex = 12 })
		return
	end
	local def = Config.Companions[c.Id]
	local ic = icon(detail, c.Id, c.Tier, 110)
	ic.AnchorPoint = Vector2.new(0.5, 0)
	ic.Position = UDim2.new(0.5, 0, 0, 12)
	local name = def.Name .. (if c.Tier > 0 then " (" .. t("Tier_" .. c.Tier) .. ")" else "")
	Ui.label(detail, name, { Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 130), ZIndex = 12 })
	Ui.label(detail, t("R_" .. def.Rarity), {
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.fromOffset(8, 162),
		TextColor3 = rarityColor(def.Rarity),
		ZIndex = 12,
	})
	Ui.label(detail, bonusText(c.Id, c.Tier), {
		Size = UDim2.new(1, -16, 0, 50),
		Position = UDim2.fromOffset(8, 190),
		TextColor3 = Ui.Ink,
		ZIndex = 12,
	})
	local equipped = table.find(state.Equipped or {}, c.Uid) ~= nil
	Ui.button(detail, if equipped then t("Unequip") else t("Equip"), if equipped then Ui.Purple else Ui.Green, function()
		State.action(if equipped then "Unequip" else "Equip", c.Uid)
	end, { Size = UDim2.new(1, -20, 0, 48), Position = UDim2.fromOffset(10, 248), ZIndex = 12 })
	local canFuse = c.Tier < 2 and countSame(state, c) >= Config.FuseCount
	local fuse = Ui.button(detail, t("Fuse") .. " (" .. tostring(countSame(state, c)) .. "/" .. Config.FuseCount .. ")",
		if canFuse then Ui.Yellow else Color3.fromRGB(190, 180, 200), function()
			if canFuse then
				State.action("Fuse", c.Uid)
			end
		end, { Size = UDim2.new(1, -20, 0, 48), Position = UDim2.fromOffset(10, 302), ZIndex = 12 })
	fuse.Name = "Fuse"
	Ui.button(detail, t("Delete"), Ui.Red, function()
		State.action("DeletePet", c.Uid)
		selectedUid = nil
	end, { Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 356), ZIndex = 12 })
end

local function refresh(state: any)
	for _, child in grid:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local list: { any } = table.clone(state.Companions or {})
	local equipped = state.Equipped or {}
	-- équipés d'abord, puis par rareté
	local order = { Mythic = 1, Legendary = 2, Epic = 3, Rare = 4, Common = 5 }
	table.sort(list, function(a, b)
		local ea, eb = table.find(equipped, a.Uid) ~= nil, table.find(equipped, b.Uid) ~= nil
		if ea ~= eb then
			return ea
		end
		local da, db = Config.Companions[a.Id], Config.Companions[b.Id]
		local ra, rb = order[da and da.Rarity or "Common"], order[db and db.Rarity or "Common"]
		if ra ~= rb then
			return ra < rb
		end
		if a.Tier ~= b.Tier then
			return a.Tier > b.Tier
		end
		return a.Uid < b.Uid
	end)
	for _, c in list do
		local def = Config.Companions[c.Id]
		local card = Instance.new("TextButton")
		card.Text = ""
		card.AutoButtonColor = false
		card.BackgroundColor3 = Ui.White
		card.ZIndex = 12
		Ui.corner(card, UDim.new(0, 14))
		Ui.stroke(card, if selectedUid == c.Uid then 5 else 3, if selectedUid == c.Uid then Ui.Pink else Ui.Ink)
		Ui.gradient(card, Ui.lighten(rarityColor(def and def.Rarity or "Common"), 0.6), rarityColor(def and def.Rarity or "Common"))
		local ic = icon(card, c.Id, c.Tier, 56)
		ic.AnchorPoint = Vector2.new(0.5, 0)
		ic.Position = UDim2.new(0.5, 0, 0, 8)
		Ui.label(card, def and def.Name or c.Id, {
			Size = UDim2.new(1, -6, 0, 20),
			Position = UDim2.new(0, 3, 1, -24),
			ZIndex = 13,
		})
		if table.find(equipped, c.Uid) then
			Ui.label(card, "✔", {
				Size = UDim2.fromOffset(24, 24),
				Position = UDim2.fromOffset(4, 2),
				TextColor3 = Ui.Green,
				ZIndex = 14,
			})
		end
		card.Activated:Connect(function()
			selectedUid = c.Uid
			Ui.bounce(card)
			if State.current then
				refresh(State.current)
			end
		end)
		card.Parent = grid
	end
	countLabel.Text = tostring(#(state.Companions or {})) .. "/" .. Config.InventorySize .. "   "
		.. t("EquippedCount", { n = #equipped, max = state.MaxEquipped or Config.MaxEquipped })
	refreshDetail(state)
end

---------------------------------------------------------------- éclosion
local overlay: Frame
local function hatch(data: any)
	local def = Config.Companions[data.Id]
	if not def then
		return
	end
	local gui = Hud.gui :: ScreenGui
	overlay.Visible = true
	for _, child in overlay:GetChildren() do
		child:Destroy()
	end
	-- l'œuf tremble
	local egg = Ui.frame(overlay, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(170, 220),
		BackgroundColor3 = Ui.White,
		ZIndex = 61,
	})
	Ui.corner(egg, UDim.new(1, 0))
	Ui.stroke(egg, 5)
	local zone = Config.zone(data.Zone)
	Ui.gradient(egg, Color3.new(1, 1, 1), if zone then zone.Color else Ui.Yellow)
	for i = 1, 8 do
		egg.Rotation = if i % 2 == 0 then 12 else -12
		Effects.play(Config.Sounds.Click, 0.4, 0.8 + i * 0.08)
		task.wait(0.12 + i * 0.015)
	end
	egg:Destroy()
	Effects.play(Config.Sounds.Pop, 0.8, 0.8)
	Effects.play(Config.Sounds.Reward, 0.7, 1)
	Ui.confetti(gui, 70)
	-- le compagnon apparaît
	local rays = Ui.frame(overlay, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(360, 360),
		BackgroundColor3 = rarityColor(def.Rarity),
		BackgroundTransparency = 0.4,
		ZIndex = 61,
	})
	Ui.corner(rays, UDim.new(1, 0))
	local ic = icon(overlay, data.Id, 0, 190)
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.45)
	ic.ZIndex = 62
	for _, d in ic:GetDescendants() do
		if d:IsA("GuiObject") then
			(d :: GuiObject).ZIndex = 63
		end
	end
	Ui.bounce(ic, 0.8)
	Ui.label(overlay, t("Hatched", { name = def.Name }), {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.68),
		Size = UDim2.fromOffset(600, 60),
		ZIndex = 62,
	})
	Ui.label(overlay, t("R_" .. def.Rarity), {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.77),
		Size = UDim2.fromOffset(400, 40),
		TextColor3 = rarityColor(def.Rarity),
		ZIndex = 62,
	})
	local spin = TweenService:Create(rays, TweenInfo.new(2.5, Enum.EasingStyle.Linear), { Rotation = 360 })
	spin:Play()
	task.wait(2.6)
	overlay.Visible = false
end

---------------------------------------------------------------- compagnons qui suivent (tous les joueurs)
type Follower = { Body: Part, Eyes: { Part }, Tier: number, Pos: Vector3 }
local followers: { [Player]: { Follower } } = {}
local followFolder = Instance.new("Folder")
followFolder.Name = "Companions"

local function makeFollower(id: string, tier: number, at: Vector3): Follower
	local def = Config.Companions[id]
	local body = Instance.new("Part")
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(2, 2, 2)
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Material = if tier == 1 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	body.Color = if tier == 1 then Color3.fromRGB(255, 210, 60) elseif def then def.Color else Ui.White
	body.CFrame = CFrame.new(at)
	body.Parent = followFolder
	local eyes = {}
	for _ = 1, 2 do
		local e = Instance.new("Part")
		e.Shape = Enum.PartType.Ball
		e.Size = Vector3.new(0.38, 0.5, 0.38)
		e.Anchored = true
		e.CanCollide = false
		e.CanQuery = false
		e.CanTouch = false
		e.Color = Color3.fromRGB(30, 20, 45)
		e.Parent = followFolder
		table.insert(eyes, e)
	end
	return { Body = body, Eyes = eyes, Tier = tier, Pos = at }
end

local function clearFollowers(p: Player)
	local list = followers[p]
	if list then
		for _, f in list do
			f.Body:Destroy()
			for _, e in f.Eyes do
				e:Destroy()
			end
		end
	end
	followers[p] = nil
end

local function rebuildFollowers(p: Player)
	clearFollowers(p)
	local attr = p:GetAttribute("Pets")
	if type(attr) ~= "string" or attr == "" then
		return
	end
	local list = {}
	local character = p.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local at = if root and root:IsA("BasePart") then (root :: BasePart).Position else Vector3.new(0, 5, 0)
	for entry in string.gmatch(attr, "[^,]+") do
		local id, tierText = string.match(entry, "^([^:]+):(%d+)$")
		if id and Config.Companions[id] then
			table.insert(list, makeFollower(id, tonumber(tierText) or 0, at))
		end
	end
	followers[p] = list
end

local function watchPlayer(p: Player)
	rebuildFollowers(p)
	p:GetAttributeChangedSignal("Pets"):Connect(function()
		rebuildFollowers(p)
	end)
	p.CharacterAdded:Connect(function()
		task.wait(0.5)
		rebuildFollowers(p)
	end)
end

function Pets.open()
	Ui.open(window)
	if State.current then
		refresh(State.current)
	end
end

function Pets.start()
	local gui = Hud.gui :: ScreenGui
	local content
	window, content = Ui.window(gui, "🐾 " .. t("Pets"), Ui.Pink, UDim2.fromOffset(760, 560))
	window.Name = "Pets"
	countLabel = Ui.label(content, "", {
		Size = UDim2.new(0.66, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
	})
	grid = Instance.new("ScrollingFrame")
	grid.Position = UDim2.fromOffset(0, 36)
	grid.Size = UDim2.new(0.66, -10, 1, -36)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 8
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ZIndex = 11
	grid.Parent = content
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(104, 104)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.Parent = grid
	detail = Ui.frame(content, {
		Position = UDim2.new(0.66, 0, 0, 0),
		Size = UDim2.new(0.34, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(255, 230, 245),
		ZIndex = 11,
	})
	Ui.corner(detail, UDim.new(0, 18))
	Ui.stroke(detail, 3)

	overlay = Ui.frame(gui, {
		Name = "Hatch",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(20, 10, 35),
		BackgroundTransparency = 0.35,
		Visible = false,
		ZIndex = 60,
	})

	-- bouton dans la barre de gauche
	Ui.button(Hud.leftBar, "🐾", Ui.Pink, function()
		if window.Visible then
			Ui.close(window)
		else
			Pets.open()
		end
	end, { Name = "PetsButton", Size = UDim2.fromOffset(78, 78), LayoutOrder = 2 })

	State.onChange(function(state: any)
		if window.Visible then
			refresh(state)
		end
	end)
	Remotes.event("Effect").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Hatched" then
			task.spawn(hatch, data)
		elseif kind == "Fused" then
			local def = Config.Companions[data.Id]
			Hud.celebrate("✨ " .. (def and def.Name or data.Id) .. " " .. t("Tier_" .. tostring(data.Tier)), nil, true)
		end
	end)

	-- invites des œufs dans la langue du joueur
	local eggs = workspace:WaitForChild("Map"):WaitForChild("Eggs")
	for _, egg in eggs:GetChildren() do
		local prompt = egg:FindFirstChild("EggPrompt", true)
		if prompt and prompt:IsA("ProximityPrompt") then
			(prompt :: ProximityPrompt).ActionText = t("Open")
		end
	end

	-- compagnons qui suivent
	followFolder.Parent = workspace
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(clearFollowers)
	RunService.RenderStepped:Connect(function(dt: number)
		local now = os.clock()
		for p, list in followers do
			local character = p.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local rootCF = (root :: BasePart).CFrame
				for i, f in list do
					local side = (i - (#list + 1) / 2) * 3
					local target = (rootCF * CFrame.new(side, 1.5 + math.sin(now * 3 + i) * 0.5, 4.5)).Position
					f.Pos = f.Pos:Lerp(target, math.min(1, dt * 8))
					local look = CFrame.lookAt(f.Pos, f.Pos + rootCF.LookVector)
					f.Body.CFrame = look
					if f.Tier == 2 then
						f.Body.Color = RAINBOW[(math.floor(now * 5 + i) % #RAINBOW) + 1]
					end
					f.Eyes[1].CFrame = look * CFrame.new(-0.42, 0.2, -0.85)
					f.Eyes[2].CFrame = look * CFrame.new(0.42, 0.2, -0.85)
				end
			end
		end
	end)
end

return Pets
