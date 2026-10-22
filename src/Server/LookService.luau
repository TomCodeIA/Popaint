--!strict
-- Popaint : accessoires du personnage, visibles par tous les joueurs.
--   * un petit réservoir à bulles dans le dos, à la couleur de peinture du joueur ;
--   * un pinceau tenu dans la main droite.
-- Tout est construit en pièces et soudé au personnage : rien à importer.
-- Compatible R6 et R15 (on cherche les membres qui existent).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local DataService = require(script.Parent:WaitForChild("DataService")) :: any

local LookService = {}

local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(84, 60, 110)

local function piece(parent: Instance, name: string, size: Vector3, color: Color3, shape: string?, material: Enum.Material?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "cyl" then
		p.Shape = Enum.PartType.Cylinder
	elseif shape == "blob" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = parent
	return p
end

-- Soude une pièce à un membre du personnage, à une position relative
local function attach(part: BasePart, to: BasePart, offset: CFrame)
	part.CFrame = to.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = to
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
end

local function limb(character: Model, r15: string, r6: string): BasePart?
	local found = character:FindFirstChild(r15) or character:FindFirstChild(r6)
	return if found and found:IsA("BasePart") then found :: BasePart else nil
end

-- Construit (ou reconstruit) les accessoires sur le personnage
function LookService.apply(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("PopaintLook")
	if old then
		old:Destroy()
	end
	-- on accroche au torse si on le trouve, sinon au centre du personnage (marche toujours)
	local torso = limb(character, "UpperTorso", "Torso") or limb(character, "HumanoidRootPart", "HumanoidRootPart")
	local hand = limb(character, "RightHand", "Right Arm")
	if not torso then
		return
	end
	local profile = DataService.get(player)
	local index = if profile and type(profile.Data.PaintColor) == "number" then profile.Data.PaintColor else 1
	local color = Config.PaintPalette[index] or Config.PaintPalette[1]

	local look = Instance.new("Model")
	look.Name = "PopaintLook"
	look.Parent = character

	-- RÉSERVOIR À BULLES dans le dos
	local tank = piece(look, "Tank", Vector3.new(1.5, 1.7, 1.5), WHITE, "cyl", Enum.Material.Glass)
	tank.Transparency = 0.25
	attach(tank, torso, CFrame.new(0, 0.1, 0.85) * CFrame.Angles(0, 0, math.rad(90)))
	local soap = piece(look, "Soap", Vector3.new(1.1, 1.3, 1.3), color, "cyl")
	attach(soap, torso, CFrame.new(0, -0.1, 0.85) * CFrame.Angles(0, 0, math.rad(90)))
	for k = 1, 3 do
		local b = piece(look, "TankBubble", Vector3.new(0.3, 0.3, 0.3), WHITE, "ball")
		b.Transparency = 0.3
		attach(b, torso, CFrame.new((k - 2) * 0.35, 0.3 + k * 0.12, 0.85))
	end
	local cap = piece(look, "TankCap", Vector3.new(0.35, 1.7, 1.7), color, "cyl")
	attach(cap, torso, CFrame.new(0, 1, 0.85) * CFrame.Angles(0, 0, math.rad(90)))
	-- bretelles
	for _, x in { -1, 1 } do
		local strap = piece(look, "Strap", Vector3.new(0.22, 1.9, 0.22), color)
		attach(strap, torso, CFrame.new(x * 0.65, 0.1, 0.38))
	end
	-- petite buse qui dépasse
	local nozzle = piece(look, "Nozzle", Vector3.new(0.6, 0.25, 0.25), WHITE, "cyl")
	attach(nozzle, torso, CFrame.new(0.9, 0.7, 0.4) * CFrame.Angles(0, math.rad(90), 0))

	-- PINCEAU dans la main droite
	if hand then
		local handle = piece(look, "BrushHandle", Vector3.new(0.22, 1.5, 0.22), Color3.fromRGB(222, 184, 140), nil, Enum.Material.Wood)
		attach(handle, hand, CFrame.new(0, -0.5, 0) * CFrame.Angles(math.rad(12), 0, 0))
		local ferrule = piece(look, "BrushFerrule", Vector3.new(0.3, 0.3, 0.3), Color3.fromRGB(220, 216, 232), "cyl")
		attach(ferrule, hand, CFrame.new(0, -1.25, 0.03) * CFrame.Angles(0, 0, math.rad(90)))
		local tip = piece(look, "BrushTip", Vector3.new(0.42, 0.7, 0.42), color, "blob")
		attach(tip, hand, CFrame.new(0, -1.65, 0.05))
		local drop = piece(look, "BrushDrop", Vector3.new(0.22, 0.22, 0.22), color, "ball")
		attach(drop, hand, CFrame.new(0, -2.05, 0.05))
	end
	local _ = INK
end

function LookService.start()
	local function watch(player: Player)
		if player.Character then
			task.defer(LookService.apply, player)
		end
		player.CharacterAdded:Connect(function(character: Model)
			character:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.2)
			LookService.apply(player)
		end)
	end
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
end

return LookService
