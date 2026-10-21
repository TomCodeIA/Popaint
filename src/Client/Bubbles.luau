--!strict
-- Popaint : affichage des bulles et éclatement au CONTACT du personnage.
-- Le client détecte le contact tout de suite (ressenti instantané), le serveur vérifie.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Effects = require(script.Parent:WaitForChild("Effects")) :: any
local State = require(script.Parent:WaitForChild("State")) :: any

local Bubbles = {}

local player = Players.LocalPlayer

type ClientBubble = {
	Id: number,
	Shell: Part,
	Core: Part,
	Base: Vector3,
	Size: number,
	Phase: number,
	Mine: boolean,
	Kind: string,
	Storm: boolean,
	Pending: number?,
}

local bubbles: { [string]: ClientBubble } = {}
local mineFolder = Instance.new("Folder")
mineFolder.Name = "MyBubbles"
local othersFolder = Instance.new("Folder")
othersFolder.Name = "OtherBubbles"

local popEvent: RemoteEvent = Remotes.event("PopBubble")
type PoppedFn = (tiles: number, coins: number, position: Vector3, color: Color3, isAuto: boolean, kind: string) -> ()
local onPopped: PoppedFn? = nil

local combo = 0
local lastPopTime = 0

local RAINBOW = Config.PaintPalette
local GOLD = Color3.fromRGB(255, 215, 60)

local function key(ownerId: number, id: number): string
	return tostring(ownerId) .. ":" .. tostring(id)
end

local function colorOf(index: number): Color3
	return Config.PaintPalette[index] or Config.PaintPalette[1]
end

local function newBall(size: number, color: Color3, material: Enum.Material, transparency: number): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = material
	part.Color = color
	part.Transparency = transparency
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part:SetAttribute("TargetSize", size)
	return part
end

local function spawnBubble(ownerId: number, id: number, position: Vector3, size: number, colorIndex: number, kind: string?, storm: boolean?)
	local mine = ownerId == player.UserId
	local k = key(ownerId, id)
	if bubbles[k] then
		return
	end
	local kindName = kind or "low"
	local color = if kindName == "high" then GOLD else colorOf(colorIndex)
	if kindName == "high" then
		size *= 1.2
	end
	local shell = newBall(size, color, Enum.Material.ForceField, if mine then 0 else 0.6)
	local core = newBall(size * 0.55, Color3.new(1, 1, 1):Lerp(color, 0.5), Enum.Material.Neon, if mine then 0.55 else 0.85)
	shell.CFrame = CFrame.new(position)
	core.CFrame = CFrame.new(position)
	local parent = if mine then mineFolder else othersFolder
	shell.Parent = parent
	core.Parent = parent
	if mine then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = size * 2.2
		light.Brightness = if kindName == "high" then 2 else 1
		light.Parent = core
	end
	bubbles[k] = {
		Id = id,
		Shell = shell,
		Core = core,
		Base = position,
		Size = size,
		Phase = math.random() * math.pi * 2,
		Mine = mine,
		Kind = kindName,
		Storm = storm == true,
	}
	local info = TweenInfo.new(if kindName == "cascade" then 0.25 else 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(shell, info, { Size = Vector3.new(size, size, size) }):Play()
	local cs = size * 0.55
	TweenService:Create(core, info, { Size = Vector3.new(cs, cs, cs) }):Play()
end

local function destroyBubble(k: string, animated: boolean)
	local b = bubbles[k]
	if not b then
		return
	end
	bubbles[k] = nil
	b.Core:Destroy()
	if animated then
		local shell = b.Shell
		local s = shell.Size.X * 1.6
		local tween = TweenService:Create(shell, TweenInfo.new(0.15), { Size = Vector3.new(s, s, s), Transparency = 1 })
		tween:Play()
		tween.Completed:Once(function()
			shell:Destroy()
		end)
	else
		b.Shell:Destroy()
	end
end

local function hide(b: ClientBubble, hidden: boolean)
	b.Shell.Transparency = if hidden then 1 else 0
	b.Core.Transparency = if hidden then 1 else 0.55
	local light = b.Core:FindFirstChildOfClass("PointLight")
	if light then
		(light :: PointLight).Enabled = not hidden
	end
end

-- Demande au serveur d'éclater une de mes bulles (contact détecté ici)
local function requestPop(b: ClientBubble)
	if not b.Mine or b.Pending then
		return
	end
	b.Pending = os.clock()
	hide(b, true)
	popEvent:FireServer(b.Id)
end

local function contactRadius(): number
	local s = State.current
	if s and type(s.ContactRadius) == "number" then
		return s.ContactRadius
	end
	return Config.ContactRadius
end

function Bubbles.onPopped(callback: PoppedFn)
	onPopped = callback
end

local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include

function Bubbles.start()
	mineFolder.Parent = workspace
	othersFolder.Parent = workspace
	floorParams.FilterDescendantsInstances = { workspace:WaitForChild("Map") }

	Remotes.event("BubbleSpawned").OnClientEvent:Connect(spawnBubble)

	Remotes.event("BubbleRemoved").OnClientEvent:Connect(function(ownerId: number, id: number)
		destroyBubble(key(ownerId, id), true)
	end)

	Remotes.event("BubblePopped").OnClientEvent:Connect(function(ownerId: number, id: number, position: Vector3,
		colorIndex: number, tiles: number, coins: number, isAuto: boolean, kind: string?)
		local mine = ownerId == player.UserId
		local k = key(ownerId, id)
		local b = bubbles[k]
		local color = colorOf(colorIndex)
		if b and b.Storm then
			color = RAINBOW[math.random(1, #RAINBOW)]
		end
		destroyBubble(k, false)
		if mine then
			local now = os.clock()
			combo = if now - lastPopTime < 1.3 then math.min(combo + 1, 20) else 0
			lastPopTime = now
			-- son de pop, plus aigu à chaque bulle enchaînée
			Effects.play(Config.Sounds.Pop, 0.6, 0.95 + combo * 0.05 + math.random() * 0.05)
			if tiles > 0 then
				Effects.play(Config.Sounds.Splash, 0.18, 1.3 + math.random() * 0.3)
			end
			Effects.burst(position, color, if kind == "high" then 45 else 26, if kind == "high" then 1.4 else 1)
			if onPopped then
				onPopped(tiles, coins, position, color, isAuto, kind or "low")
			end
		else
			Effects.burst(position, color, 8)
		end
		local floorY = position.Y - 3
		local ray = workspace:Raycast(position, Vector3.new(0, -30, 0), floorParams)
		if ray then
			floorY = ray.Position.Y + 0.15
		end
		Effects.splashRing(Vector3.new(position.X, floorY, position.Z), color, if tiles > 0 then 7 else 3)
	end)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local rootPos: Vector3? = if root and root:IsA("BasePart") then (root :: BasePart).Position else nil
		local reach = contactRadius()
		for _, b in bubbles do
			if b.Pending then
				-- pas de réponse du serveur : la bulle réapparaît
				if t - b.Pending > 1 then
					b.Pending = nil
					hide(b, false)
				end
				continue
			end
			local bob = math.sin(t * 1.8 + b.Phase) * 0.4
			local cf = CFrame.new(b.Base + Vector3.new(0, bob, 0))
			b.Shell.CFrame = cf
			b.Core.CFrame = cf
			if b.Storm then
				local c = RAINBOW[(math.floor(t * 6 + b.Phase * 3) % #RAINBOW) + 1]
				b.Shell.Color = c
			end
			if b.Mine and rootPos and (rootPos - b.Base).Magnitude <= reach + b.Size / 2 then
				requestPop(b)
			end
		end
	end)
end

return Bubbles
