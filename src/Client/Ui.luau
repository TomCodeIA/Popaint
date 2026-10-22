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

Ui.Font = Enum.Font.FredokaOne
-- Couleurs pastel (douces pour les yeux). Le jaune « pièce » reste vif : c'est la couleur des récompenses.
Ui.Ink = Color3.fromRGB(84, 60, 110)
Ui.White = Color3.new(1, 1, 1)
Ui.Pink = Color3.fromRGB(255, 150, 196)
Ui.Blue = Color3.fromRGB(130, 196, 250)
Ui.Yellow = Color3.fromRGB(255, 208, 120)
Ui.Green = Color3.fromRGB(126, 214, 156)
Ui.Purple = Color3.fromRGB(184, 150, 250)
Ui.Red = Color3.fromRGB(250, 140, 150)
Ui.Panel = Color3.fromRGB(255, 249, 252)

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
	c.CornerRadius = radius or UDim.new(0, 16)
	c.Parent = parent
	return c
end

function Ui.stroke(parent: Instance, thickness: number?, color: Color3?): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or Ui.Ink
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Ui.gradient(parent: Instance, top: Color3, bottom: Color3): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = parent
	return g
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
	s.Color = Ui.Ink
	s.Parent = l
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
	TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Gros bouton coloré
function Ui.button(parent: Instance, text: string, color: Color3, onClick: () -> (), props: { [string]: any }?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = Ui.White -- la couleur vient du dégradé
	b.Font = Ui.Font
	b.Text = text
	b.TextColor3 = Ui.White
	b.TextScaled = true
	Ui.corner(b, UDim.new(0, 14))
	Ui.stroke(b, 3)
	Ui.gradient(b, Ui.lighten(color, 0.25), Ui.darken(color, 0.1))
	local ts = Instance.new("UIStroke")
	ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ts.Thickness = 2
	ts.Color = Ui.Ink
	ts.Parent = b
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
	-- le bouton s'écrase quand on appuie, puis rebondit quand on relâche
	local anyB = b :: any
	anyB.InputEnded:Connect(function()
		local sc = b:FindFirstChildOfClass("UIScale") :: UIScale?
		if sc and sc.Scale < 1 then
			TweenService:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)
	anyB.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local sc = b:FindFirstChildOfClass("UIScale") :: UIScale?
		if not sc then
			local n = Instance.new("UIScale")
			n.Parent = b
			sc = n
		end
		TweenService:Create(sc :: UIScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = 0.9 }):Play()
	end)
	b.Activated:Connect(function()
		Ui.bounce(b)
		if playSound then
			playSound(Config.Sounds.Click, 0.5, 1.1)
		end
		onClick()
	end)
	b.Parent = parent
	return b
end

-- Fenêtre avec titre et bouton fermer. Retourne (fenêtre, contenu)
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
	Ui.corner(w, UDim.new(0, 24))
	Ui.stroke(w, 5)
	local header = Ui.frame(w, {
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Ui.White,
		ZIndex = 11,
	})
	Ui.corner(header, UDim.new(0, 22))
	Ui.gradient(header, Ui.lighten(color, 0.3), color)
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
		Position = UDim2.new(1, -60, 0, 6),
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
	TweenService:Create(sc, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
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
