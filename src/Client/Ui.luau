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
Ui.Ink = Color3.fromRGB(45, 25, 70)
Ui.White = Color3.new(1, 1, 1)
Ui.Pink = Color3.fromRGB(255, 92, 168)
Ui.Blue = Color3.fromRGB(82, 200, 255)
Ui.Yellow = Color3.fromRGB(255, 214, 64)
Ui.Green = Color3.fromRGB(90, 230, 120)
Ui.Purple = Color3.fromRGB(170, 110, 255)
Ui.Red = Color3.fromRGB(255, 90, 90)
Ui.Panel = Color3.fromRGB(255, 246, 252)

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
	w.Visible = true
	local scale = w:FindFirstChildOfClass("UIScale") :: UIScale?
	if not scale then
		local s = Instance.new("UIScale")
		s.Parent = w
		scale = s
	end
	local sc = scale :: UIScale
	sc.Scale = 0.6
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function Ui.close(w: GuiObject)
	if openWindow == w then
		openWindow = nil
	end
	w.Visible = false
end

function Ui.isOpen(w: GuiObject): boolean
	return w.Visible
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
