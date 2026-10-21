--!strict
-- Popaint : mini-map en haut à droite (zones, peinture en %, joueurs, verrous).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Ui = require(script.Parent:WaitForChild("Ui")) :: any
local State = require(script.Parent:WaitForChild("State")) :: any
local Hud = require(script.Parent:WaitForChild("Hud")) :: any

local MiniMap = {}

local player = Players.LocalPlayer

-- Limites du monde affiché (en studs) : calculées à partir des zones présentes dans la map,
-- donc une nouvelle zone apparaît toute seule sur la mini-map.
local MIN_X, MAX_X = -110, 110
local MIN_Z, MAX_Z = -110, 110
local SIZE = 190

local function computeBounds()
	local zones = workspace:WaitForChild("Map"):WaitForChild("Zones")
	for _, zone in zones:GetChildren() do
		local ox, oz = zone:GetAttribute("OriginX"), zone:GetAttribute("OriginZ")
		local cx, cz = zone:GetAttribute("CountX"), zone:GetAttribute("CountZ")
		if type(ox) == "number" and type(oz) == "number" and type(cx) == "number" and type(cz) == "number" then
			MIN_X = math.min(MIN_X, ox - 20)
			MIN_Z = math.min(MIN_Z, oz - 20)
			MAX_X = math.max(MAX_X, ox + cx * Config.TileSize + 20)
			MAX_Z = math.max(MAX_Z, oz + cz * Config.TileSize + 20)
		end
	end
end

local frame: Frame
local zoneFrames: { [string]: Frame } = {}
local dots: { [Player]: Frame } = {}

local function toMap(x: number, z: number): UDim2
	local u = (x - MIN_X) / (MAX_X - MIN_X)
	local v = (z - MIN_Z) / (MAX_Z - MIN_Z)
	return UDim2.fromScale(u, v)
end

function MiniMap.start()
	computeBounds()
	local gui = Hud.gui :: ScreenGui
	local ratio = (MAX_Z - MIN_Z) / (MAX_X - MIN_X)
	frame = Ui.frame(gui, {
		Name = "MiniMap",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(SIZE, SIZE * ratio),
		BackgroundColor3 = Color3.fromRGB(150, 220, 255),
		ClipsDescendants = true,
	})
	Ui.corner(frame, UDim.new(0, 18))
	Ui.stroke(frame, 4)

	-- hub
	local hubSize = 200 / (MAX_X - MIN_X)
	local hub = Ui.frame(frame, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = toMap(0, 0),
		Size = UDim2.fromScale(hubSize, 200 / (MAX_Z - MIN_Z)),
		BackgroundColor3 = Color3.fromRGB(214, 196, 255),
	})
	Ui.corner(hub, UDim.new(0, 6))

	local zones = workspace:WaitForChild("Map"):WaitForChild("Zones")
	for _, z in Config.Zones do
		local folder = zones:FindFirstChild(z.Id)
		if folder then
			local ox, oz = folder:GetAttribute("OriginX"), folder:GetAttribute("OriginZ")
			local cx = folder:GetAttribute("CountX")
			if type(ox) == "number" and type(oz) == "number" and type(cx) == "number" then
				local w = cx * Config.TileSize
				local zf = Ui.frame(frame, {
					Name = z.Id,
					Position = toMap(ox, oz),
					Size = UDim2.fromScale(w / (MAX_X - MIN_X), w / (MAX_Z - MIN_Z)),
					BackgroundColor3 = Color3.fromRGB(150, 150, 158),
				})
				Ui.corner(zf, UDim.new(0, 6))
				local fill = Ui.frame(zf, {
					Name = "Fill",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.fromScale(1, 0),
					BackgroundColor3 = z.Color,
				})
				Ui.corner(fill, UDim.new(0, 6))
				Ui.label(zf, "", { Name = "Lock", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ZIndex = 3 })
				zoneFrames[z.Id] = zf
			end
		end
	end

	State.onChange(function(state: any)
		for id, zf in zoneFrames do
			local lock = zf:FindFirstChild("Lock") :: TextLabel
			local open = state.Zones and state.Zones[id]
			local def = Config.zone(id)
			local ev = def and def.Event and Config.event(def.Event)
			lock.Text = if open then "" elseif ev then ev.Icon else "🔒"
			-- une zone d'événement fermée est à peine visible
			zf.BackgroundTransparency = if ev and not open then 0.6 else 0
		end
	end)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt: number)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		for id, zf in zoneFrames do
			local folder = zones:FindFirstChild(id)
			local painted = folder and folder:GetAttribute("Painted")
			local fill = zf:FindFirstChild("Fill") :: Frame
			fill.Size = UDim2.fromScale(1, if type(painted) == "number" then painted else 0)
		end
		-- points des joueurs
		for _, p in Players:GetPlayers() do
			local character = p.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local dot = dots[p]
			if root and root:IsA("BasePart") then
				if not dot then
					local d = Ui.frame(frame, {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.fromOffset(if p == player then 14 else 9, if p == player then 14 else 9),
						BackgroundColor3 = if p == player then Ui.White else Ui.Pink,
						ZIndex = 5,
					})
					Ui.corner(d, UDim.new(1, 0))
					Ui.stroke(d, 2)
					dots[p] = d
					dot = d
				end
				local pos = (root :: BasePart).Position;
				(dot :: Frame).Position = toMap(pos.X, pos.Z)
			elseif dot then
				dot:Destroy()
				dots[p] = nil
			end
		end
		for p, d in dots do
			if not p.Parent then
				d:Destroy()
				dots[p] = nil
			end
		end
	end)
end

return MiniMap
