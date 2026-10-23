--!strict
-- Popaint : effets visuels et sonores (côté joueur uniquement).

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

local Effects = {}

Effects.Sounds = Config.Sounds

local effectsFolder: Folder? = nil
local function folder(): Folder
	if effectsFolder and effectsFolder.Parent then
		return effectsFolder
	end
	local f = Instance.new("Folder")
	f.Name = "ClientEffects"
	f.Parent = workspace
	effectsFolder = f
	return f
end

local function sfxVolume(): number
	local v = Players.LocalPlayer:GetAttribute("SfxVolume")
	return if type(v) == "number" then v else 0.8
end

function Effects.play(soundId: string, volume: number?, pitch: number?)
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = (volume or 0.5) * sfxVolume()
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 4)
end

local function anchoredPart(): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- Gerbe de particules colorées
function Effects.burst(position: Vector3, color: Color3, amount: number, speed: number?)
	local holder = anchoredPart()
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 0.2
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.1),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new(0.35, 0.8)
	emitter.Speed = NumberRange.new(14 * (speed or 1), 28 * (speed or 1))
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = holder
	holder.Parent = folder()
	emitter:Emit(amount)
	Debris:AddItem(holder, 1.4)
end

-- Anneau de peinture qui s'étale sur le sol
function Effects.splashRing(position: Vector3, color: Color3, radius: number)
	local ring = anchoredPart()
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = color
	ring.Transparency = 0.15
	ring.Size = Vector3.new(0.2, 1, 1)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder()
	local tween = TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(ring, 0.5)
end

-- Texte qui s'envole (ex. "+12")
function Effects.floatingText(position: Vector3, text: string, color: Color3, scale: number?)
	local holder = anchoredPart()
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(position)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(5 * (scale or 1), 2.5 * (scale or 1))
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(45, 25, 70)
	label.Parent = gui
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.3
	uiScale.Parent = label
	holder.Parent = folder()
	TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local info = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(holder, info, { CFrame = CFrame.new(position + Vector3.new(0, 6, 0)) }):Play()
	TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(holder, 1.1)
end

return Effects
