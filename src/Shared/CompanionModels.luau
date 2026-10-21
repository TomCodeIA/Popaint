--!strict
-- Popaint : fabrique le modèle 3D d'un compagnon (utilisé par les joueurs pour les compagnons qui
-- suivent, l'inventaire et l'éclosion des œufs). Tout est construit en pièces : rien à importer.
--
-- L'apparence se règle dans Content/Companions.luau avec "Look" :
--   Body   : Round, Tall, Squish, Fish, Gem, Ghost, Pumpkin, Star, Cube, Bird
--   Extras : liste parmi CatEars, BunnyEars, BearEars, Horn, Horns, Antennae, Wings, BatWings,
--            FairyWings, Tail, Leaf, Crown, Bow, Halo, Flame, Spikes, Fins, Dots, Bolt, Bulb, Cherry, Scarf
--   Accent : deuxième couleur (oreilles, ventre, détails)
-- Sans Look, une apparence par défaut est choisie selon la rareté.
-- Pour voir le résultat sans Studio : tools/preview.sh companions

local CompanionModels = {}

local WHITE = Color3.fromRGB(255, 255, 255)
local INK = Color3.fromRGB(84, 64, 104)
local BLUSH = Color3.fromRGB(246, 156, 192)
local GOLD = Color3.fromRGB(255, 208, 90)

export type Look = { Body: string?, Extras: { string }?, Accent: Color3? }

local function tint(c: Color3, k: number): Color3
	return c:Lerp(WHITE, k)
end

local function part(model: Model, name: string, cf: CFrame, size: Vector3, color: Color3, kind: string?, material: Enum.Material?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.CFrame = cf
	if kind == "ball" then
		p.Shape = Enum.PartType.Ball
	elseif kind == "blob" or kind == "wedge" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = if kind == "blob" then Enum.MeshType.Sphere else Enum.MeshType.Wedge
		mesh.Parent = p
	elseif kind == "cyl" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Parent = model
	return p
end

local DEFAULT_LOOKS: { [string]: Look } = {
	Common = { Body = "Round", Extras = { "BearEars" } },
	Rare = { Body = "Squish", Extras = { "CatEars", "Tail" } },
	Epic = { Body = "Tall", Extras = { "Horns", "Wings" } },
	Legendary = { Body = "Round", Extras = { "Horn", "FairyWings", "Crown" } },
	Mythic = { Body = "Round", Extras = { "Halo", "Wings", "Tail" } },
}

-- Taille et position du visage pour chaque forme de corps (repère du corps, regard vers -Z)
type BodyInfo = { Size: Vector3, Face: CFrame, Top: number, Feet: boolean }

local function buildBody(m: Model, body: string, color: Color3, accent: Color3): BodyInfo
	local o = CFrame.new()
	if body == "Tall" then
		local b = part(m, "Body", o, Vector3.new(2, 2.7, 2), color, "blob")
		b:SetAttribute("Main", true)
		part(m, "Belly", o * CFrame.new(0, -0.35, -0.55), Vector3.new(1.2, 1.5, 0.9), tint(accent, 0.3), "blob")
		return { Size = b.Size, Face = o * CFrame.new(0, 0.45, -0.95), Top = 1.3, Feet = true }
	elseif body == "Squish" then
		local b = part(m, "Body", o, Vector3.new(2.7, 1.9, 2.3), color, "blob")
		b:SetAttribute("Main", true)
		part(m, "Belly", o * CFrame.new(0, -0.3, -0.75), Vector3.new(1.6, 1, 0.8), tint(accent, 0.3), "blob")
		return { Size = b.Size, Face = o * CFrame.new(0, 0.2, -1.08), Top = 0.9, Feet = true }
	elseif body == "Fish" then
		local b = part(m, "Body", o, Vector3.new(1.8, 1.9, 2.6), color, "blob")
		b:SetAttribute("Main", true)
		part(m, "TailFin", o * CFrame.new(0, 0, 1.55) * CFrame.Angles(math.rad(90), 0, 0), Vector3.new(0.2, 1.4, 1.6), accent, "wedge")
		part(m, "TopFin", o * CFrame.new(0, 1, 0.2) * CFrame.Angles(0, math.rad(180), 0), Vector3.new(0.2, 0.7, 1.1), accent, "wedge")
		for _, x in { -1, 1 } do
			part(m, "SideFin", o * CFrame.new(x * 0.95, -0.3, 0.1) * CFrame.Angles(0, 0, x * 0.5), Vector3.new(0.15, 0.6, 0.9), accent, "blob")
		end
		return { Size = b.Size, Face = o * CFrame.new(0, 0.15, -1.15), Top = 0.95, Feet = false }
	elseif body == "Gem" then
		local b = part(m, "Body", o * CFrame.Angles(0, math.rad(45), math.rad(45)), Vector3.new(1.7, 1.7, 1.7), color, nil, Enum.Material.Glass)
		b:SetAttribute("Main", true)
		part(m, "Core", o, Vector3.new(1, 1, 1), tint(color, 0.5), "ball", Enum.Material.Neon)
		return { Size = Vector3.new(2.4, 2.4, 2.4), Face = o * CFrame.new(0, 0.1, -1.05), Top = 1.2, Feet = true }
	elseif body == "Ghost" then
		local b = part(m, "Body", o, Vector3.new(2.1, 2.5, 2.1), color, "blob")
		b:SetAttribute("Main", true)
		for k = 1, 7 do
			local a = k / 7 * math.pi * 2
			part(m, "Hem", o * CFrame.new(math.cos(a) * 0.75, -1.05 - (k % 2) * 0.15, math.sin(a) * 0.75), Vector3.new(0.75, 0.75, 0.75), color, "ball")
		end
		for _, x in { -1, 1 } do
			part(m, "Arm", o * CFrame.new(x * 1.1, -0.1, -0.2) * CFrame.Angles(0, 0, x * 0.7), Vector3.new(0.45, 0.9, 0.45), color, "blob")
		end
		return { Size = b.Size, Face = o * CFrame.new(0, 0.35, -1.0), Top = 1.2, Feet = false }
	elseif body == "Pumpkin" then
		for k = 1, 8 do
			local a = k / 8 * math.pi * 2
			local lobe = part(m, "Lobe", o * CFrame.new(math.cos(a) * 0.5, 0, math.sin(a) * 0.5), Vector3.new(1.2, 1.9, 1.2),
				if k % 2 == 0 then color else tint(color, 0.12), "blob")
			lobe:SetAttribute("Main", true)
		end
		local b = part(m, "Body", o, Vector3.new(1.8, 1.9, 1.8), color, "blob")
		b:SetAttribute("Main", true)
		part(m, "Stem", o * CFrame.new(0, 1.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.5, 0.3, 0.3), accent, "cyl")
		return { Size = Vector3.new(2.3, 1.9, 2.3), Face = o * CFrame.new(0, 0.1, -1.1), Top = 0.95, Feet = true }
	elseif body == "Star" then
		local b = part(m, "Body", o, Vector3.new(1.7, 1.7, 1.3), color, "blob")
		b:SetAttribute("Main", true)
		for k = 0, 4 do
			local ray = part(m, "Ray", o * CFrame.Angles(0, 0, k / 5 * math.pi * 2) * CFrame.new(0, 1.15, 0), Vector3.new(0.8, 1.1, 0.8), color, "blob")
			ray:SetAttribute("Main", true)
		end
		return { Size = Vector3.new(2.8, 2.8, 1.3), Face = o * CFrame.new(0, 0.1, -0.62), Top = 1.5, Feet = false }
	elseif body == "Cube" then
		local b = part(m, "Body", o, Vector3.new(2.1, 2.1, 2.1), color, nil, Enum.Material.Glass)
		b:SetAttribute("Main", true)
		b.TopSurface = Enum.SurfaceType.Studs
		b.Transparency = 0.15
		part(m, "Core", o, Vector3.new(1.2, 1.2, 1.2), tint(color, 0.45), "blob")
		return { Size = b.Size, Face = o * CFrame.new(0, 0.15, -1.08), Top = 1.05, Feet = true }
	elseif body == "Bird" then
		local b = part(m, "Body", o, Vector3.new(2.1, 2.1, 2.1), color, "ball")
		b:SetAttribute("Main", true)
		part(m, "Belly", o * CFrame.new(0, -0.3, -0.6), Vector3.new(1.4, 1.3, 0.9), tint(accent, 0.3), "blob")
		part(m, "Beak", o * CFrame.new(0, 0, -1.15), Vector3.new(0.45, 0.35, 0.5), Color3.fromRGB(255, 210, 160), "blob")
		for k = -1, 1 do
			part(m, "Crest", o * CFrame.new(k * 0.18, 1.1 + (1 - math.abs(k)) * 0.15, 0.1) * CFrame.Angles(0, 0, k * 0.4),
				Vector3.new(0.2, 0.6, 0.2), accent, "blob")
		end
		return { Size = b.Size, Face = o * CFrame.new(0, 0.35, -0.95), Top = 1.05, Feet = true }
	end
	-- Round (par défaut)
	local b = part(m, "Body", o, Vector3.new(2.2, 2.2, 2.2), color, "ball")
	b:SetAttribute("Main", true)
	part(m, "Belly", o * CFrame.new(0, -0.35, -0.65), Vector3.new(1.4, 1.2, 0.9), tint(accent, 0.3), "blob")
	return { Size = b.Size, Face = o * CFrame.new(0, 0.3, -1.0), Top = 1.1, Feet = true }
end

local function buildFace(m: Model, cf: CFrame)
	for _, x in { -1, 1 } do
		part(m, "Eye", cf * CFrame.new(x * 0.36, 0.05, 0), Vector3.new(0.3, 0.42, 0.2), INK, "blob")
		part(m, "Shine", cf * CFrame.new(x * 0.36 - 0.06, 0.16, -0.08), Vector3.new(0.12, 0.12, 0.12), WHITE, "ball")
		part(m, "Blush", cf * CFrame.new(x * 0.62, -0.18, 0.04), Vector3.new(0.3, 0.16, 0.1), BLUSH, "blob")
	end
	for k = -1, 1 do
		part(m, "Mouth", cf * CFrame.new(k * 0.09, -0.2 - (if k == 0 then 0.04 else 0), -0.02), Vector3.new(0.09, 0.09, 0.09), INK, "ball")
	end
end

local EXTRAS: { [string]: (Model, BodyInfo, Color3, Color3) -> () } = {}

EXTRAS.CatEars = function(m, b, c, a)
	-- le coin en pente du coin (wedge) est tourné vers l'extérieur : oreille pointue vue de face
	for _, x in { -1, 1 } do
		local cf = CFrame.new(x * 0.52, b.Top - 0.02, 0.05) * CFrame.Angles(0, math.rad(x * 90), 0) * CFrame.Angles(0, 0, 0)
		part(m, "Ear", cf, Vector3.new(0.3, 0.75, 0.6), c, "wedge")
		part(m, "EarIn", cf * CFrame.new(0.06 * x, -0.08, 0.06), Vector3.new(0.2, 0.48, 0.36), tint(a, 0.3), "wedge")
	end
end
EXTRAS.BunnyEars = function(m, b, c, a)
	for _, x in { -1, 1 } do
		part(m, "Ear", CFrame.new(x * 0.38, b.Top + 0.55, 0.1) * CFrame.Angles(0, 0, x * -0.2), Vector3.new(0.45, 1.4, 0.3), c, "blob")
		part(m, "EarIn", CFrame.new(x * 0.38, b.Top + 0.55, -0.02) * CFrame.Angles(0, 0, x * -0.2), Vector3.new(0.25, 1, 0.12), tint(a, 0.35), "blob")
	end
end
EXTRAS.BearEars = function(m, b, c, a)
	for _, x in { -1, 1 } do
		part(m, "Ear", CFrame.new(x * 0.62, b.Top - 0.1, 0.05), Vector3.new(0.6, 0.6, 0.6), c, "ball")
		part(m, "EarIn", CFrame.new(x * 0.62, b.Top - 0.1, -0.2), Vector3.new(0.32, 0.32, 0.1), tint(a, 0.3), "blob")
	end
end
EXTRAS.Horn = function(m, b, _c, a)
	for k = 0, 3 do
		part(m, "Horn", CFrame.new(0, b.Top + 0.1 + k * 0.22, -0.25 - k * 0.05), Vector3.new(0.42 - k * 0.09, 0.26, 0.42 - k * 0.09),
			if k % 2 == 0 then GOLD else tint(a, 0.4), "cyl")
	end
end
EXTRAS.Horns = function(m, b, _c, a)
	for _, x in { -1, 1 } do
		part(m, "Horn", CFrame.new(x * 0.45, b.Top + 0.1, 0) * CFrame.Angles(0, 0, x * -0.4), Vector3.new(0.3, 0.6, 0.3), tint(a, 0.5), "blob")
	end
end
EXTRAS.Antennae = function(m, b, _c, a)
	for _, x in { -1, 1 } do
		part(m, "Stalk", CFrame.new(x * 0.35, b.Top + 0.3, 0) * CFrame.Angles(0, 0, x * -0.3), Vector3.new(0.08, 0.7, 0.08), INK)
		part(m, "Tip", CFrame.new(x * 0.55, b.Top + 0.65, 0), Vector3.new(0.3, 0.3, 0.3), a, "ball", Enum.Material.Neon)
	end
end
EXTRAS.Wings = function(m, b, _c, a)
	for _, x in { -1, 1 } do
		for k = 0, 2 do
			part(m, "Feather", CFrame.new(x * (b.Size.X / 2 + 0.25 + k * 0.12), 0.2 + k * 0.2, 0.35) * CFrame.Angles(0, x * 0.3, x * (0.6 + k * 0.35)),
				Vector3.new(0.25, 1 - k * 0.15, 0.6), tint(a, 0.2 + k * 0.15), "blob")
		end
	end
end
EXTRAS.BatWings = function(m, b, _c, a)
	for _, x in { -1, 1 } do
		part(m, "Wing", CFrame.new(x * (b.Size.X / 2 + 0.5), 0.25, 0.3) * CFrame.Angles(0, x * 0.4, x * 0.3), Vector3.new(1.1, 0.9, 0.12), a)
		for k = 0, 1 do
			part(m, "WingTip", CFrame.new(x * (b.Size.X / 2 + 0.6 + k * 0.4), -0.25, 0.3), Vector3.new(0.35, 0.35, 0.12), a, "ball")
		end
	end
end
EXTRAS.FairyWings = function(m, b, _c, a)
	for _, x in { -1, 1 } do
		for k, y in { 0.45, -0.25 } do
			local w = part(m, "Wing", CFrame.new(x * (b.Size.X / 2 + 0.45), y, 0.45) * CFrame.Angles(0, x * 0.5, x * (0.5 - k * 0.6)),
				Vector3.new(1.2 - k * 0.3, 0.8 - k * 0.15, 0.08), tint(a, 0.5), "blob", Enum.Material.Glass)
			w.Transparency = 0.35
		end
	end
end
EXTRAS.Tail = function(m, b, c, a)
	part(m, "Tail", CFrame.new(0, -0.35, b.Size.Z / 2 + 0.15), Vector3.new(0.6, 0.6, 0.6), tint(a, 0.3), "ball")
	local _ = c
end
EXTRAS.Leaf = function(m, b, _c, _a)
	part(m, "Sprout", CFrame.new(0, b.Top + 0.2, 0), Vector3.new(0.1, 0.4, 0.1), Color3.fromRGB(160, 214, 180))
	for _, x in { -1, 1 } do
		part(m, "Leaf", CFrame.new(x * 0.25, b.Top + 0.42, 0) * CFrame.Angles(0, 0, x * -0.6), Vector3.new(0.45, 0.18, 0.3),
			Color3.fromRGB(184, 238, 204), "blob")
	end
end
EXTRAS.Crown = function(m, b, _c, _a)
	part(m, "CrownBand", CFrame.new(0, b.Top + 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.3, 0.9, 0.9), GOLD, "cyl")
	for k = 1, 5 do
		local ang = k / 5 * math.pi * 2
		part(m, "CrownPoint", CFrame.new(math.cos(ang) * 0.38, b.Top + 0.3, math.sin(ang) * 0.38), Vector3.new(0.18, 0.3, 0.18), GOLD, "blob")
	end
	part(m, "Jewel", CFrame.new(0, b.Top + 0.08, -0.45), Vector3.new(0.16, 0.16, 0.16), BLUSH, "ball", Enum.Material.Neon)
end
EXTRAS.Bow = function(m, b, _c, a)
	local cf = CFrame.new(0.45, b.Top - 0.05, -0.1)
	part(m, "BowKnot", cf, Vector3.new(0.22, 0.22, 0.22), a, "ball")
	for _, x in { -1, 1 } do
		part(m, "BowLoop", cf * CFrame.new(x * 0.25, 0, 0) * CFrame.Angles(0, 0, x * 0.3), Vector3.new(0.4, 0.3, 0.15), a, "blob")
	end
end
EXTRAS.Halo = function(m, b, _c, _a)
	for k = 1, 12 do
		local ang = k / 12 * math.pi * 2
		part(m, "Halo", CFrame.new(math.cos(ang) * 0.6, b.Top + 0.55, math.sin(ang) * 0.6), Vector3.new(0.2, 0.2, 0.2), GOLD, "ball", Enum.Material.Neon)
	end
end
EXTRAS.Flame = function(m, b, _c, _a)
	part(m, "Wick", CFrame.new(0, b.Top + 0.1, 0), Vector3.new(0.08, 0.3, 0.08), INK)
	part(m, "Flame", CFrame.new(0, b.Top + 0.45, 0), Vector3.new(0.35, 0.6, 0.35), Color3.fromRGB(255, 236, 170), "blob", Enum.Material.Neon)
end
EXTRAS.Spikes = function(m, b, _c, a)
	for k = 0, 3 do
		part(m, "Spike", CFrame.new(0, b.Top - 0.15 - k * 0.32, 0.4 + k * 0.22) * CFrame.Angles(math.rad(-30 - k * 15), 0, 0),
			Vector3.new(0.12, 0.4, 0.35), tint(a, 0.2), "wedge")
	end
end
EXTRAS.Fins = function(m, b, _c, a)
	for _, x in { -1, 1 } do
		part(m, "Fin", CFrame.new(x * (b.Size.X / 2 + 0.05), 0, 0.1) * CFrame.Angles(0, 0, x * 0.4), Vector3.new(0.15, 0.6, 0.8), a, "blob")
	end
end
EXTRAS.Dots = function(m, b, _c, a)
	for k = 1, 6 do
		local ang = k / 6 * math.pi * 2
		local r = b.Size.X / 2
		part(m, "Dot", CFrame.new(math.cos(ang) * r * 0.92, 0.25 * math.sin(k * 1.7), math.sin(ang) * r * 0.92 + 0.05),
			Vector3.new(0.3, 0.3, 0.3), tint(a, 0.4), "ball")
	end
end
EXTRAS.Bolt = function(m, b, _c, _a)
	local cf = CFrame.new(0, b.Top + 0.35, 0)
	part(m, "Bolt", cf * CFrame.Angles(0, 0, 0.5), Vector3.new(0.18, 0.5, 0.12), GOLD, nil, Enum.Material.Neon)
	part(m, "Bolt", cf * CFrame.new(0.12, -0.3, 0) * CFrame.Angles(0, 0, -0.5), Vector3.new(0.18, 0.45, 0.12), GOLD, nil, Enum.Material.Neon)
end
EXTRAS.Bulb = function(m, b, _c, a)
	part(m, "Socket", CFrame.new(0, b.Top + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.3, 0.45, 0.45), Color3.fromRGB(200, 200, 215), "cyl")
	part(m, "Bulb", CFrame.new(0, b.Top + 0.5, 0), Vector3.new(0.6, 0.6, 0.6), tint(a, 0.4), "ball", Enum.Material.Neon)
end
EXTRAS.Cherry = function(m, b, _c, _a)
	part(m, "Cherry", CFrame.new(0, b.Top + 0.2, 0), Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(255, 160, 160), "ball")
	part(m, "Stem", CFrame.new(0.08, b.Top + 0.55, 0) * CFrame.Angles(0, 0, -0.3), Vector3.new(0.06, 0.4, 0.06), Color3.fromRGB(160, 214, 180))
end
EXTRAS.Scarf = function(m, b, _c, a)
	part(m, "Scarf", CFrame.new(0, -b.Size.Y * 0.18, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.3, b.Size.X * 0.92, b.Size.Z * 0.92), a, "cyl")
	part(m, "ScarfEnd", CFrame.new(0.45, -b.Size.Y * 0.32, -b.Size.Z * 0.42), Vector3.new(0.3, 0.6, 0.12), a)
end

-- Listes connues (vérifiées par les tests : une faute de frappe dans Look est détectée)
CompanionModels.Bodies = { "Round", "Tall", "Squish", "Fish", "Gem", "Ghost", "Pumpkin", "Star", "Cube", "Bird" }
CompanionModels.Extras = EXTRAS

-- Construit le modèle. row = ligne de Content/Companions (ou Config.Companions), tier 0/1/2.
function CompanionModels.build(row: any, tier: number?): Model
	local tierN = tier or 0
	local m = Instance.new("Model")
	m.Name = row.Id or "Companion"
	local look: Look = row.Look or DEFAULT_LOOKS[row.Rarity] or DEFAULT_LOOKS.Common
	local color: Color3 = row.Color or WHITE
	local accent: Color3 = look.Accent or tint(color, 0.45)
	if tierN == 1 then
		color = color:Lerp(GOLD, 0.65)
		accent = GOLD
	end
	local info = buildBody(m, look.Body or "Round", color, accent)
	buildFace(m, info.Face)
	if info.Feet then
		for _, x in { -1, 1 } do
			part(m, "Foot", CFrame.new(x * 0.45, -info.Size.Y / 2 + 0.05, -0.25), Vector3.new(0.55, 0.32, 0.7), tint(accent, 0.1), "blob")
		end
	end
	local extras: { string } = look.Extras or {}
	for _, name in extras do
		local f = EXTRAS[name]
		if f then
			f(m, info, color, accent)
		end
	end
	-- doré : couronne en plus ; arc-en-ciel : halo et un peu plus grand
	if tierN == 1 and not table.find(extras, "Crown") then
		EXTRAS.Crown(m, info, color, accent)
	elseif tierN == 2 and not table.find(extras, "Halo") then
		EXTRAS.Halo(m, info, color, accent)
	end
	local body = m:FindFirstChild("Body") :: BasePart?
	if body then
		m.PrimaryPart = body
	end
	if tierN >= 1 or row.Rarity == "Mythic" or row.Rarity == "Legendary" then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "Sparkle"
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(if tierN == 1 then GOLD else WHITE)
		sparkle.Size = NumberSequence.new(0.35, 0)
		sparkle.Lifetime = NumberRange.new(0.6, 1)
		sparkle.Rate = if tierN == 2 then 10 else 5
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.LightEmission = 0.6
		if body then
			sparkle.Parent = body
		end
	end
	m:SetAttribute("Tier", tierN)
	if tierN == 2 then
		local s = 1.15
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				local p = d :: BasePart
				p.Size *= s
				p.CFrame = CFrame.new(p.CFrame.Position * s) * (p.CFrame - p.CFrame.Position)
			end
		end
	end
	return m
end

return CompanionModels
