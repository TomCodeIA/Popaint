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
local CompanionModels = require(Shared:WaitForChild("CompanionModels")) :: any
local Quality = require(script.Parent:WaitForChild("Quality")) :: any

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

-- Modèle 3D d'un compagnon (voir src/Shared/CompanionModels.luau)
local function buildModel(id: string, tier: number): Model?
	local def = Config.Companions[id]
	if not def then
		return nil
	end
	return CompanionModels.build(def.Row or def, tier)
end

-- Compagnon en 3D dans l'interface (fenêtre ronde). spin = true : il tourne doucement
local spinning: { [Model]: { Base: CFrame, Phase: number } } = {}
local function icon(parent: Instance, id: string, tier: number, size: number, spin: boolean?): Frame
	local body = Ui.frame(parent, {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Color3.fromRGB(255, 250, 252),
		ZIndex = 13,
	})
	Ui.corner(body, UDim.new(1, 0))
	Ui.stroke(body, 3, if tier == 1 then Color3.fromRGB(255, 200, 70) elseif tier == 2 then Ui.Pink else Ui.Ink)
	if tier == 2 then
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Ui.lighten(RAINBOW[1], 0.5)),
			ColorSequenceKeypoint.new(0.5, Ui.lighten(RAINBOW[4], 0.5)),
			ColorSequenceKeypoint.new(1, Ui.lighten(RAINBOW[2], 0.5)),
		})
		g.Parent = body
	end
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(200, 196, 210)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-0.4, -1, 0.6)
	vp.ZIndex = 14
	vp.Parent = body
	local model = buildModel(id, tier)
	if model then
		for _, d in model:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				d:Destroy()
			end
		end
		local base = CFrame.Angles(0, math.rad(-20), 0)
		model:PivotTo(base)
		model.Parent = vp
		if spin then
			spinning[model] = { Base = base, Phase = math.random() * 6 }
			model.Destroying:Connect(function()
				spinning[model] = nil
			end)
		end
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 38
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0.9, -7.4), Vector3.new(0, 0.2, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
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
	local ic = icon(detail, c.Id, c.Tier, 110, true)
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
	local ic = icon(overlay, data.Id, 0, 220, true)
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
type Piece = { Part: BasePart, Rel: CFrame, Kind: string?, Side: number, Size: Vector3, Color: Color3 }
type Follower = { Model: Model, Pieces: { Piece }, Tier: number, Pos: Vector3, Phase: number, NextBlink: number, Last: Vector3 }
local followers: { [Player]: { Follower } } = {}
local followFolder = Instance.new("Folder")
followFolder.Name = "Companions"

-- Quelles pièces bougent, et comment (ailes qui battent, oreilles qui frétillent, queue qui remue, yeux qui clignent)
local KIND = {
	Wing = "Flap", Feather = "Flap", WingTip = "Flap",
	Ear = "Wiggle", EarIn = "Wiggle", Stalk = "Wiggle", Tip = "Wiggle",
	Tail = "Wag", TailFin = "Wag",
	Eye = "Blink", Shine = "Blink", Iris = "Blink", Shine2 = "Blink",
	Hand = "Wave",
	Flame = "Flicker", Halo = "Halo", Bulb = "Glow",
}

local function makeFollower(id: string, tier: number, at: Vector3): Follower?
	local model = buildModel(id, tier)
	if not model then
		return nil
	end
	local pieces = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local p = d :: BasePart
			local rel = p.CFrame
			table.insert(pieces, {
				Part = p, Rel = rel, Kind = KIND[p.Name] or (if p:GetAttribute("Main") then "Main" else nil),
				Side = if rel.Position.X < -0.05 then -1 elseif rel.Position.X > 0.05 then 1 else 0,
				Size = p.Size, Color = p.Color,
			})
		end
	end
	if not Quality.settings().Particles then
		for _, d in model:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				(d :: ParticleEmitter).Enabled = false
			end
		end
	end
	model:PivotTo(CFrame.new(at))
	model.Parent = followFolder
	return { Model = model, Pieces = pieces, Tier = tier, Pos = at, Phase = math.random() * 6, NextBlink = os.clock() + math.random() * 3, Last = at }
end

local function clearFollowers(p: Player)
	local list = followers[p]
	if list then
		for _, f in list do
			f.Model:Destroy()
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
			local f = makeFollower(id, tonumber(tierText) or 0, at)
			if f then
				table.insert(list, f)
			end
		end
	end
	followers[p] = list
end

-- Anime un compagnon : sautille en marchant, flotte à l'arrêt, cligne des yeux, bat des ailes…
-- au-delà de cette distance (selon la qualité), on ne déplace que le modèle entier
local function nearDistance(): number
	return Quality.settings().PetDetail
end
local function animate(f: Follower, look: CFrame, now: number, speed: number, near: boolean)
	local t = now + f.Phase
	local moving = math.clamp(speed / 14, 0, 1)
	local hop = math.abs(math.sin(t * 9)) * 0.7 * moving + math.sin(t * 2.2) * 0.18 * (1 - moving)
	local lean = CFrame.Angles(-0.25 * moving, 0, math.sin(t * 9) * 0.08 * moving)
	local cf = look * CFrame.new(0, hop, 0) * lean
	if not near then
		f.Model:PivotTo(cf)
		return
	end
	-- petit écrasement quand il retombe (« squash & stretch »)
	local squash = 1 - (1 - math.abs(math.sin(t * 9))) * 0.12 * moving
	local blink = now >= f.NextBlink
	if now >= f.NextBlink + 0.14 then
		f.NextBlink = now + 2 + math.random() * 3
	end
	local flap = math.sin(t * (if moving > 0.3 then 22 else 10)) * 0.45
	for _, pc in f.Pieces do
		local rel = pc.Rel
		local rx, ry, rz = rel.Position.X, rel.Position.Y, rel.Position.Z
		local relSq = CFrame.new(rx * (2 - squash), ry * squash, rz * (2 - squash)) * (rel - rel.Position)
		local kind = pc.Kind
		if kind == "Flap" then
			pc.Part.CFrame = cf * CFrame.new(pc.Side * 0.8, 0, 0.3) * CFrame.Angles(0, pc.Side * flap * 0.6, pc.Side * flap)
				* CFrame.new(-pc.Side * 0.8, 0, -0.3) * relSq
		elseif kind == "Wiggle" then
			pc.Part.CFrame = cf * CFrame.new(0, ry, 0) * CFrame.Angles(0, 0, math.sin(t * 6 + pc.Side) * 0.12)
				* CFrame.new(0, -ry, 0) * relSq
		elseif kind == "Wave" then
			-- les mains se balancent en marchant, font coucou à l'arrêt
			local swing = if moving > 0.3 then math.sin(t * 9 + pc.Side) * 0.5 else math.max(0, math.sin(t * 1.3)) * math.sin(t * 14) * 0.6
			pc.Part.CFrame = cf * CFrame.new(rx, ry + 0.2, rz) * CFrame.Angles(swing, 0, pc.Side * (0.2 + math.abs(swing) * 0.6))
				* CFrame.new(0, -0.2, 0) * (rel - rel.Position)
		elseif kind == "Wag" then
			pc.Part.CFrame = cf * CFrame.Angles(0, math.sin(t * 12) * 0.35, 0) * relSq
		elseif kind == "Halo" then
			pc.Part.CFrame = cf * CFrame.Angles(0, t * 1.5, 0) * relSq
		else
			pc.Part.CFrame = cf * relSq
			if kind == "Blink" then
				pc.Part.Size = if blink then Vector3.new(pc.Size.X, pc.Size.Y * 0.12, pc.Size.Z) else pc.Size
			elseif kind == "Flicker" then
				pc.Part.Size = pc.Size * (1 + math.sin(t * 17) * 0.12)
			elseif kind == "Main" and f.Tier == 2 then
				pc.Part.Color = pc.Color:Lerp(RAINBOW[(math.floor(now * 2) % #RAINBOW) + 1], 0.45)
			end
		end
	end
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
		BackgroundColor3 = Color3.fromRGB(70, 50, 100),
		BackgroundTransparency = 0.35,
		Visible = false,
		ZIndex = 60,
	})

	-- bouton dans la barre de gauche
	Ui.button(Hud.leftBar, "🐾", Ui.Pink, function()
		if Ui.isOpen(window) then
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
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		for p, list in followers do
			local character = p.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local rootCF = (root :: BasePart).CFrame
				local near = (rootCF.Position - eye).Magnitude < nearDistance()
				for i, f in list do
					local side = (i - (#list + 1) / 2) * 3.4
					local target = (rootCF * CFrame.new(side, 1.2, 4.8)).Position
					f.Pos = f.Pos:Lerp(target, math.min(1, dt * 7))
					local speed = (f.Pos - f.Last).Magnitude / math.max(dt, 1 / 240)
					f.Last = f.Pos
					local look = CFrame.lookAt(f.Pos, f.Pos + rootCF.LookVector)
					animate(f, look, now, speed, near)
				end
			end
		end
		-- compagnons qui tournent dans l'interface
		for model, info in spinning do
			local k = now + info.Phase
			model:PivotTo(info.Base * CFrame.Angles(0, math.sin(k * 0.8) * 0.6, 0) + Vector3.new(0, math.abs(math.sin(k * 3)) * 0.25, 0))
		end
	end)
end

return Pets
