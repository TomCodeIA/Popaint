-- Popaint (générateur de map) : outils communs pour construire des objets.
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum
local UDim2 = roblox.UDim2

local lib = {}

lib.roblox = roblox
lib.Instance = Instance
lib.Vector3 = Vector3
lib.CFrame = CFrame
lib.Color3 = Color3
lib.Enum = Enum
lib.UDim2 = UDim2

-- Dimensions du monde
lib.ZONE = 160 -- taille d'une zone (studs)
lib.TILE = 4 -- taille d'une case peignable
lib.BRIDGE = 26 -- longueur d'un pont
lib.HUB = 200 -- taille du hub
lib.HALF = 100
lib.WATER = -8 -- surface de l'eau
lib.WALL_H = 30

function lib.rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Palette PASTEL du jeu (douce pour les yeux). Les touches vives sont réservées aux récompenses.
lib.P = {
	pink = lib.rgb(255, 190, 215),
	rose = lib.rgb(246, 156, 192),
	peach = lib.rgb(255, 210, 178),
	butter = lib.rgb(255, 236, 170),
	mint = lib.rgb(184, 238, 204),
	sage = lib.rgb(160, 214, 180),
	sky = lib.rgb(182, 218, 255),
	aqua = lib.rgb(176, 234, 230),
	lavender = lib.rgb(206, 192, 255),
	lilac = lib.rgb(232, 196, 244),
	coral = lib.rgb(255, 178, 170),
	cream = lib.rgb(255, 248, 236),
	white = lib.rgb(255, 255, 255),
	plum = lib.rgb(150, 120, 172), -- contraste doux (yeux, ombres, troncs)
	cocoa = lib.rgb(176, 132, 110),
	ink = lib.rgb(84, 64, 104),
	gold = lib.rgb(255, 208, 90), -- touche vive : pièces, récompenses
}
lib.RAINBOW = { lib.P.pink, lib.P.butter, lib.P.mint, lib.P.sky, lib.P.lavender }
lib.CANDY = { lib.P.pink, lib.P.sky, lib.P.butter, lib.P.mint, lib.P.lavender, lib.P.peach, lib.P.aqua, lib.P.lilac }
-- Arc-en-ciel vif : seulement pour les moments forts (Rainbow Storm, récompenses)
lib.VIVID = {
	lib.rgb(255, 92, 168), lib.rgb(255, 214, 64), lib.rgb(120, 255, 140), lib.rgb(82, 215, 255), lib.rgb(186, 120, 255),
}

-- Couleur éclaircie (k = 0 : identique, 1 : blanc) et assombrie
function lib.tint(c, k)
	return c:Lerp(lib.rgb(255, 255, 255), k)
end
function lib.dark(c, k)
	return c:Lerp(lib.rgb(70, 50, 90), k)
end

-- Générateur pseudo-aléatoire déterministe : la map est identique à chaque construction
function lib.rng(seed)
	local state = seed % 2147483648
	return function(a, b)
		state = (state * 1103515245 + 12345) % 2147483648
		local r = state / 2147483648
		if a and b then
			return a + r * (b - a)
		end
		return r
	end
end

function lib.pick(rng, list)
	return list[math.floor(rng() * #list) + 1]
end

function lib.part(props)
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Class" and k ~= "Parent" then
			p[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

-- Pièce de décor : jamais de collision gênante, ne bloque pas les clics
function lib.deco(props)
	if props.CanCollide == nil then
		props.CanCollide = false
	end
	props.CanQuery = false
	props.CanTouch = false
	return lib.part(props)
end

function lib.ball(parent, name, pos, size, color, material, extra)
	local props = {
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		CFrame = CFrame.new(pos),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	return lib.deco(props)
end

-- Cylindre vertical
function lib.cyl(parent, name, pos, height, diameter, color, material, extra)
	local props = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	return lib.deco(props)
end

function lib.block(parent, name, cf, size, color, material, extra)
	local props = {
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.Plastic,
		TopSurface = Enum.SurfaceType.Studs,
		Parent = parent,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	return lib.deco(props)
end

-- Boule déformée (ellipsoïde) grâce à un SpecialMesh
function lib.blob(parent, name, cf, size, color, material, extra)
	local props = {
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	local p = lib.deco(props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

function lib.light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 12
	l.Brightness = brightness or 1
	l.Shadows = false
	l.Parent = parent
	return l
end

function lib.folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Modèle de décor. streaming : "Atomic" (arrive en entier), "Persistent" (toujours chargé)
-- lod = true : reste visible de loin en version simplifiée (montagnes, grands objets)
function lib.model(name, parent, streaming, lod)
	local m = Instance.new("Model")
	m.Name = name
	if streaming == "Persistent" then
		m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	elseif streaming == "Atomic" then
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
	if lod then
		m.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	end
	m.Parent = parent
	return m
end

-- Donne une pièce principale au modèle (nécessaire pour l'animer et le déplacer)
function lib.primary(m)
	if m.PrimaryPart then
		return m
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			m.PrimaryPart = d
			return m
		end
	end
	return m
end

-- Sous-modèle "Details" : les petites pièces qu'on ne montre que de près (src/Client/Detail.luau)
function lib.details(m)
	local d = m:FindFirstChild("Details")
	if d then
		return d
	end
	d = lib.Instance.new("Model")
	d.Name = "Details"
	d.Parent = m
	return d
end

-- Lueur douce (remplace le néon qui éblouit) : matériau lisse + petite lumière
function lib.glow(part, color, range)
	part.Material = Enum.Material.SmoothPlastic
	local l = lib.light(part, color or part.Color, range or 10, 0.6)
	return l
end

-- Animation jouée chez les joueurs (voir src/Client/Animator.luau) : "Spin", "Bob", "Pulse", "Wobble"
function lib.anim(inst, kinds, attrs)
	inst:SetAttribute("Anim", kinds)
	for k, v in attrs or {} do
		inst:SetAttribute(k, v)
	end
	if inst:IsA("Model") then
		lib.primary(inst)
		inst.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
end

function lib.billboard(parent, size, offsetY, text, color, maxDistance)
	local bb = Instance.new("BillboardGui")
	bb.Size = size
	bb.StudsOffset = Vector3.new(0, offsetY, 0)
	bb.MaxDistance = maxDistance or 150
	bb.LightInfluence = 0
	bb.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or lib.rgb(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = lib.rgb(45, 25, 70)
	label.Text = text
	label.Parent = bb
	return bb, label
end

function lib.surfaceText(part, face, text, color)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.LightInfluence = 0
	g.PixelsPerStud = 40
	g.Parent = part
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color or lib.rgb(255, 255, 255)
	t.TextStrokeTransparency = 0
	t.TextStrokeColor3 = lib.rgb(45, 25, 70)
	t.Parent = g
	return t
end

function lib.prompt(parent, name, action, object, distance)
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = distance or 12
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

function lib.formatCost(n)
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

---------------------------------------------------------------- zones interdites au décor
-- Rectangles { minX, minZ, maxX, maxZ } où aucun décor ne doit être posé (zones de jeu, ponts, hub)
function lib.newKeepOut()
	local k = { rects = {} }
	function k:add(minX, minZ, maxX, maxZ)
		table.insert(self.rects, { minX, minZ, maxX, maxZ })
	end
	function k:free(x, z, r)
		for _, rect in self.rects do
			local cx = math.clamp(x, rect[1], rect[3])
			local cz = math.clamp(z, rect[2], rect[4])
			if (x - cx) ^ 2 + (z - cz) ^ 2 < r * r then
				return false
			end
		end
		return true
	end
	return k
end

return lib
