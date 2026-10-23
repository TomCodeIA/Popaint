--!strict
-- Popaint : boîte à outils de l'interface (style commun, boutons qui rebondissent, fenêtres, confettis).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Locale = require(Shared:WaitForChild("Locale")) :: any

local Ui = {}

local player = Players.LocalPlayer

---------------------------------------------------------------- DESIGN SYSTEM
-- Toutes les couleurs, polices, arrondis et reliefs viennent de src/Shared/Content/Design.luau
-- (le design system « Popaint »). Deux thèmes : Nuit et Jour, au choix du joueur.
local Design = Config.Design

Ui.Design = Design
local FONTS = (Enum.Font :: any) :: { [string]: Enum.Font }
Ui.Font = FONTS[Design.FontDisplay] or Enum.Font.LuckiestGuy -- titres, boutons : grosse police cartoon
Ui.FontText = FONTS[Design.FontText] or Enum.Font.Nunito -- texte courant, bien lisible
Ui.R = Design.Radius
Ui.Depth = Design.Depth
Ui.Dur = Design.Duration

-- Les six peintures (noms gardés pour tout le code existant)
Ui.Pink = Design.Paint.pink
Ui.Blue = Design.Paint.cyan
Ui.Yellow = Design.Paint.yellow
Ui.Green = Design.Paint.lime
Ui.Purple = Design.Paint.violet
Ui.Orange = Design.Paint.orange
Ui.Red = Design.Danger
Ui.White = Color3.new(1, 1, 1)
Ui.OnPaint = Design.OnPaint -- texte posé sur une peinture claire

-- Couleurs du thème en cours (mises à jour par Ui.setTheme)
local themeName = Design.DefaultTheme
local theme = Design.Themes[themeName]
Ui.Ink = theme.Ink
Ui.InkMuted = theme.InkMuted
Ui.Edge = theme.Edge
Ui.Panel = theme.Bg
Ui.PanelRaised = theme.BgRaised
Ui.Sunken = theme.BgSunken

-- Un élément porte un « rôle » : c'est ce qui permet de rhabiller tout l'écran d'un coup.
-- Rôles : "panel", "raised", "sunken", "ink", "inkMuted", "edge", "onPaint"
local ROLE = "DsRole"
local roleTargets: { GuiObject | UIStroke } = {}

local function colorOfRole(role: string): Color3
	if role == "panel" then
		return Ui.Panel
	elseif role == "raised" then
		return Ui.PanelRaised
	elseif role == "sunken" then
		return Ui.Sunken
	elseif role == "inkMuted" then
		return Ui.InkMuted
	elseif role == "edge" then
		return Ui.Edge
	elseif role == "onPaint" then
		return Ui.OnPaint
	end
	return Ui.Ink
end

local function paint(inst: Instance)
	local role = inst:GetAttribute(ROLE)
	if type(role) ~= "string" then
		return
	end
	local c = colorOfRole(role)
	if inst:IsA("UIStroke") then
		(inst :: UIStroke).Color = c
	elseif inst:IsA("TextLabel") or inst:IsA("TextButton") then
		(inst :: any).TextColor3 = c
	elseif inst:IsA("GuiObject") then
		(inst :: GuiObject).BackgroundColor3 = c
	end
end

-- Donne un rôle à un élément : il suivra le thème choisi par le joueur
function Ui.role(inst: Instance, role: string): Instance
	inst:SetAttribute(ROLE, role)
	table.insert(roleTargets, inst :: any)
	paint(inst)
	return inst
end

function Ui.themeName(): string
	return themeName
end

-- Change de thème (Nuit / Jour) et rhabille tout l'écran
function Ui.setTheme(name: string)
	local t = Design.Themes[name]
	if not t or name == themeName then
		return
	end
	themeName = name
	theme = t
	Ui.Ink, Ui.InkMuted, Ui.Edge = t.Ink, t.InkMuted, t.Edge
	Ui.Panel, Ui.PanelRaised, Ui.Sunken = t.Bg, t.BgRaised, t.BgSunken
	for i = #roleTargets, 1, -1 do
		local inst = roleTargets[i] :: any
		if inst.Parent then
			paint(inst)
		else
			table.remove(roleTargets, i)
		end
	end
end

local playSound: ((string, number?, number?) -> ())? = nil
function Ui.setSoundPlayer(fn: (string, number?, number?) -> ())
	playSound = fn
end

-- Traduction dans la langue du joueur
function Ui.t(key: string, vars: { [string]: any }?): string
	local lang = player:GetAttribute("Language")
	return Locale.get(if type(lang) == "string" then lang else "en", key, vars)
end

function Ui.corner(parent: Instance, radius: UDim?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, Ui.R.md)
	c.Parent = parent
	return c
end

-- Contour cartoon épais du design system. Sans couleur donnée, il suit le thème.
function Ui.stroke(parent: Instance, thickness: number?, color: Color3?): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or Design.StrokeThickness
	s.Color = color or Ui.Edge
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	if not color then
		Ui.role(s, "edge")
	end
	return s
end

-- Ombre dure (pas de flou) : c'est elle qui donne le relief « jouet ». Renvoie l'ombre.
function Ui.depth(gui: GuiObject, offset: number?, radius: number?): Frame
	local shadow = Instance.new("Frame")
	shadow.Name = "Depth"
	shadow.BorderSizePixel = 0
	shadow.BackgroundColor3 = Ui.Edge
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Position = UDim2.fromOffset(0, offset or Ui.Depth.md)
	shadow.ZIndex = math.max(1, gui.ZIndex - 1)
	shadow.Parent = gui.Parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Ui.R.md)
	c.Parent = shadow
	Ui.role(shadow, "edge")
	-- l'ombre colle à l'élément, même quand sa taille ou sa place changent
	local function follow()
		shadow.Size = gui.Size
		shadow.Position = gui.Position + UDim2.fromOffset(0, offset or Ui.Depth.md)
		shadow.AnchorPoint = gui.AnchorPoint
		shadow.Visible = gui.Visible
	end
	follow()
	gui:GetPropertyChangedSignal("Size"):Connect(follow)
	gui:GetPropertyChangedSignal("Position"):Connect(follow)
	gui:GetPropertyChangedSignal("Visible"):Connect(follow)
	gui.Destroying:Connect(function()
		shadow:Destroy()
	end)
	return shadow
end

-- Le design system interdit les dégradés décoratifs : les couleurs sont des aplats de peinture.
-- Cette fonction garde son nom (tout le code l'appelle) mais pose un aplat de la couleur principale,
-- avec juste un soupçon de relief en haut.
function Ui.gradient(parent: Instance, top: Color3, bottom: Color3): UIGradient
	local _ = top
	if parent:IsA("GuiObject") then
		(parent :: GuiObject).BackgroundColor3 = bottom
	end
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Ui.lighten(bottom, 0.12), bottom)
	g.Rotation = 90
	g.Parent = parent
	return g
end

-- Face latérale 3D d'une peinture (sa teinte « deep » du design system, sinon une version sombre)
function Ui.deepOf(c: Color3): Color3
	for _, p in Design.Paints do
		if p.Color == c then
			return p.Deep
		end
	end
	return c:Lerp(Ui.Edge, 0.55)
end

function Ui.lighten(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), amount)
end

function Ui.darken(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), amount)
end

function Ui.label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Ui.Font
	l.Text = text
	l.TextColor3 = Ui.White
	l.TextScaled = true
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Color = Ui.Edge
	s.Parent = l
	Ui.role(s, "edge")
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	l.Parent = parent
	return l
end

function Ui.frame(parent: Instance, props: { [string]: any }?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	if props then
		for k, v in props do
			(f :: any)[k] = v
		end
	end
	f.Parent = parent
	return f
end

-- Petit rebond quand on appuie
function Ui.bounce(gui: GuiObject, amount: number?)
	local scale = gui:FindFirstChildOfClass("UIScale") :: UIScale?
	if not scale then
		local s = Instance.new("UIScale")
		s.Parent = gui
		scale = s
	end
	local sc = scale :: UIScale
	sc.Scale = 1 + (amount or 0.12)
	TweenService:Create(sc, TweenInfo.new(Ui.Dur.Pop, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Gros bouton « jouet » : aplat de peinture, contour épais, face latérale 3D, il s'enfonce à l'appui.
function Ui.button(parent: Instance, text: string, color: Color3, onClick: () -> (), props: { [string]: any }?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = color
	b.Font = Ui.Font
	b.Text = text
	b.TextColor3 = Ui.White
	b.TextScaled = true
	Ui.corner(b, UDim.new(0, Ui.R.md))
	Ui.stroke(b)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = b
	if props then
		for k, v in props do
			(b :: any)[k] = v
		end
	end
	b.Parent = parent
	-- face latérale : une ombre dure de la couleur « deep » de la peinture
	local shadow = Ui.depth(b, Ui.Depth.md, Ui.R.md)
	shadow.BackgroundColor3 = Ui.deepOf(color)
	shadow:SetAttribute("DsRole", nil)
	local resting = b.Position
	local pressed = false
	local function press(down: boolean)
		if down == pressed then
			return
		end
		pressed = down
		local drop = if down then Design.PressDrop else 0
		local info = TweenInfo.new(Ui.Dur.Tap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(b, info, { Position = resting + UDim2.fromOffset(0, drop) }):Play()
		TweenService:Create(shadow, info, {
			Position = resting + UDim2.fromOffset(0, if down then Ui.Depth.sm + Design.PressDrop else Ui.Depth.md),
		}):Play()
	end
	local anyB = b :: any
	anyB.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			press(true)
		end
	end)
	anyB.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			press(false)
		end
	end)
	anyB.MouseLeave:Connect(function()
		press(false)
	end)
	b:GetPropertyChangedSignal("Position"):Connect(function()
		if not pressed then
			resting = b.Position
		end
	end)
	b.Activated:Connect(function()
		if playSound then
			playSound(Config.Sounds.Click, 0.5, 1.1)
		end
		onClick()
	end)
	return b
end

-- Fenêtre : panneau du thème (Nuit ou Jour), bandeau de couleur, relief 3D. Retourne (fenêtre, contenu)
function Ui.window(parent: Instance, title: string, color: Color3, size: UDim2): (Frame, Frame)
	local w = Ui.frame(parent, {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = size,
		BackgroundColor3 = Ui.Panel,
		Visible = false,
		ZIndex = 10,
	})
	Ui.role(w, "panel")
	Ui.corner(w, UDim.new(0, Ui.R.lg))
	Ui.stroke(w, Design.StrokeThickness + 2)
	Ui.depth(w, Ui.Depth.lg, Ui.R.lg)
	local header = Ui.frame(w, {
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = color,
		ZIndex = 11,
	})
	Ui.corner(header, UDim.new(0, Ui.R.lg))
	local headerFoot = Ui.frame(w, {
		Name = "HeaderFoot",
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Ui.deepOf(color),
		ZIndex = 11,
	})
	local _ = headerFoot
	Ui.label(header, title, {
		Name = "Title",
		Size = UDim2.new(1, -90, 0.8, 0),
		Position = UDim2.new(0, 20, 0.1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
	})
	local close = Ui.button(header, "X", Ui.Red, function()
		Ui.close(w)
	end, {
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.new(1, -60, 0, 4),
		ZIndex = 12,
	})
	close.Name = "Close"
	local content = Ui.frame(w, {
		Name = "Content",
		Position = UDim2.new(0, 16, 0, 76),
		Size = UDim2.new(1, -32, 1, -92),
		BackgroundTransparency = 1,
		ZIndex = 11,
	})
	return w, content
end

local openWindow: GuiObject? = nil

function Ui.open(w: GuiObject)
	if openWindow and openWindow ~= w then
		Ui.close(openWindow)
	end
	openWindow = w
	w:SetAttribute("CloseToken", (tonumber(w:GetAttribute("CloseToken")) or 0) + 1)
	w.Visible = true
	local scale = w:FindFirstChildOfClass("UIScale") :: UIScale?
	if not scale then
		local s = Instance.new("UIScale")
		s.Parent = w
		scale = s
	end
	local sc = scale :: UIScale
	sc.Scale = 0.6
	TweenService:Create(sc, TweenInfo.new(Ui.Dur.Pop, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- petite oscillation à l'ouverture
	w.Rotation = -3
	TweenService:Create(w, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
end

function Ui.close(w: GuiObject)
	if openWindow == w then
		openWindow = nil
	end
	if not w.Visible then
		return
	end
	-- la fenêtre rétrécit puis disparaît
	local token = (tonumber(w:GetAttribute("CloseToken")) or 0) + 1
	w:SetAttribute("CloseToken", token)
	local sc = w:FindFirstChildOfClass("UIScale") :: UIScale?
	if sc then
		TweenService:Create(sc, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.5 }):Play()
		task.delay(0.14, function()
			if w:GetAttribute("CloseToken") == token then
				w.Visible = false
			end
		end)
	else
		w.Visible = false
	end
end

function Ui.isOpen(w: GuiObject): boolean
	return openWindow == w and w.Visible
end

-- Le bouton « respire » doucement pour attirer l'œil (ex. une récompense à prendre)
function Ui.breathe(gui: GuiObject, amount: number?)
	local sc = gui:FindFirstChildOfClass("UIScale") :: UIScale?
	if not sc then
		local n = Instance.new("UIScale")
		n.Parent = gui
		sc = n
	end
	local tween = TweenService:Create(sc :: UIScale, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1 + (amount or 0.06) })
	tween:Play()
	return tween
end

-- Fait apparaître un élément en « pop » (petit puis grand puis normal)
function Ui.popIn(gui: GuiObject, delay: number?)
	local sc = gui:FindFirstChildOfClass("UIScale") :: UIScale?
	if not sc then
		local n = Instance.new("UIScale")
		n.Parent = gui
		sc = n
	end
	local s = sc :: UIScale
	s.Scale = 0
	task.delay(delay or 0, function()
		TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
end

-- Pluie de confettis à l'écran
function Ui.confetti(parent: Instance, amount: number?)
	local colors = Config.PaintPalette
	for _ = 1, amount or 40 do
		local c = Ui.frame(parent, {
			Size = UDim2.fromOffset(math.random(8, 16), math.random(10, 20)),
			Position = UDim2.new(math.random(), 0, -0.05, 0),
			BackgroundColor3 = colors[math.random(1, #colors)],
			Rotation = math.random(0, 360),
			ZIndex = 50,
		})
		Ui.corner(c, UDim.new(0, 3))
		local duration = 1.4 + math.random() * 1.2
		TweenService:Create(c, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(c.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, 1.1, 0),
			Rotation = c.Rotation + math.random(-360, 360),
		}):Play()
		task.delay(duration, function()
			c:Destroy()
		end)
	end
end

return Ui
