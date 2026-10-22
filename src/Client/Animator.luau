--!strict
-- Popaint : anime le décor chez le joueur (bonbon qui tourne, phare, île flottante, gelée qui tremble...).
-- Un objet de la map est animé s'il porte l'attribut "Anim" (ex. "Spin,Bob"), voir tools/map/lib.luau.
-- Animations : Spin (tourne, SpinAxis = "X"/"Y"/"Z"), Bob (flotte), Pulse (scintille), Wobble (gelée),
-- Sway (se balance depuis le pied), Drift (dérive d'un côté à l'autre), Swim (nage en rond),
-- Blink (ses lumières clignotent doucement).
-- Seulement près du joueur (AnimRange, 200 studs par défaut) : le reste ne bouge pas, pour les téléphones.
--
-- Compatible avec le chargement progressif (StreamingEnabled) : les objets qui arrivent près du
-- joueur sont pris en charge dès qu'ils apparaissent, et oubliés quand ils disparaissent.

local RunService = game:GetService("RunService")
local Quality = require(script.Parent:WaitForChild("Quality")) :: any

local Animator = {}

type Entry = {
	Inst: Instance,
	Kinds: { [string]: boolean },
	Base: CFrame?,
	Parts: { { Part: BasePart, Transparency: number, Size: Vector3 } },
	Phase: number,
	Foot: Vector3?, -- pied de l'objet (pivot du balancement)
	Lights: { { Light: PointLight, Brightness: number } },
	Range: number,
	Count: number, -- nombre de pièces au dernier inventaire (pour détecter les arrivées)
}

local entries: { [Instance]: Entry } = {}

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else default
end

local function partsOf(inst: Instance): { BasePart }
	local out = {}
	if inst:IsA("BasePart") then
		table.insert(out, inst :: BasePart)
	else
		for _, d in inst:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(out, d :: BasePart)
			end
		end
	end
	return out
end

-- Les pièces d'un modèle animé arrivent (ou repartent) avec le chargement progressif :
-- on reprend leur position d'origine dès qu'elles sont là.
local function inventory(e: Entry)
	local parts = partsOf(e.Inst)
	if #parts == e.Count then
		return
	end
	e.Count = #parts
	e.Parts = {}
	for _, p in parts do
		table.insert(e.Parts, { Part = p, Transparency = p.Transparency, Size = p.Size })
	end
	e.Lights = {}
	local minY = math.huge
	for _, p in parts do
		minY = math.min(minY, p.CFrame.Position.Y - p.Size.Y / 2)
		for _, l in p:GetChildren() do
			if l:IsA("PointLight") then
				table.insert(e.Lights, { Light = l :: PointLight, Brightness = (l :: PointLight).Brightness })
			end
		end
	end
	if #parts == 0 then
		e.Base = nil
	elseif e.Inst:IsA("Model") then
		local m = e.Inst :: Model
		e.Base = if m.PrimaryPart then (m.PrimaryPart :: BasePart).CFrame else m:GetPivot()
		if m.PrimaryPart then
			m.WorldPivot = (m.PrimaryPart :: BasePart).CFrame
		end
	else
		e.Base = (e.Inst :: BasePart).CFrame
	end
	if e.Base then
		local b = e.Base :: CFrame
		e.Foot = Vector3.new(b.Position.X, minY, b.Position.Z)
	end
end

local function track(inst: Instance)
	if entries[inst] then
		return
	end
	local kinds = inst:GetAttribute("Anim")
	if type(kinds) ~= "string" then
		return
	end
	local set = {}
	for k in string.gmatch(kinds, "[^,]+") do
		set[k] = true
	end
	local e: Entry = {
		Inst = inst, Kinds = set, Base = nil, Parts = {}, Phase = math.random() * 10, Count = -1, Foot = nil, Lights = {},
		Range = num(inst, "AnimRange", 200),
	}
	entries[inst] = e
	inventory(e)
end

function Animator.start()
	local map = workspace:WaitForChild("Map")
	for _, inst in map:GetDescendants() do
		track(inst)
	end
	map.DescendantAdded:Connect(function(inst: Instance)
		if inst:GetAttribute("Anim") then
			track(inst)
		end
	end)
	map.DescendantRemoving:Connect(function(inst: Instance)
		entries[inst] = nil
	end)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local now = os.clock()
		acc += dt
		local recount = acc > 0.5
		if recount then
			acc = 0
		end
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		local scale = Quality.settings().AnimScale
		for _, e in entries do
			if recount and e.Inst:IsA("Model") then
				inventory(e)
			end
			local base = e.Base
			if not base or #e.Parts == 0 then
				continue
			end
			if (base.Position - eye).Magnitude > e.Range * scale then
				continue
			end
			local inst = e.Inst
			local t = now + e.Phase
			local k = e.Kinds
			if k.Spin or k.Bob or k.Sway or k.Drift or k.Swim or k.Flow or k.Hop or k.Shake then
				local cf = base
				if k.Bob then
					cf = cf + Vector3.new(0, math.sin(t * num(inst, "BobSpeed", 1)) * num(inst, "BobAmp", 1), 0)
				end
				if k.Drift then
					local amp = num(inst, "DriftAmp", 6)
					cf = cf + Vector3.new(math.sin(t * num(inst, "DriftSpeed", 0.15)) * amp, 0, math.cos(t * num(inst, "DriftSpeed", 0.15) * 0.7) * amp * 0.4)
				end
				if k.Hop then
					-- petit saut : monte, retombe, se penche en avant pendant le saut
					local sp = num(inst, "HopSpeed", 1.6)
					local phase = (t * sp) % 1
					local jump = math.sin(math.min(phase, 0.5) * 2 * math.pi) -- 0 → 1 → 0 puis pause au sol
					local up = math.max(0, jump) * num(inst, "HopHeight", 2)
					cf = cf * CFrame.new(0, up, 0) * CFrame.Angles(math.max(0, jump) * -0.25, 0, 0)
				end
				if k.Flow then
					-- défilement le long d'une direction (eau qui coule, tapis)
					local dir = Vector3.new(num(inst, "FlowX", 0), num(inst, "FlowY", -1), num(inst, "FlowZ", 0))
					if dir.Magnitude > 0.001 then
						local dist = num(inst, "FlowDist", 2)
						cf = cf + dir.Unit * (((now * num(inst, "FlowSpeed", 1)) % 1) * dist)
					end
				end
				if k.Shake then
					-- tremble de temps en temps (œuf prêt à éclore)
					local period = num(inst, "ShakePeriod", 4)
					local phase = (t % period) / period
					if phase < 0.22 then
						local a = math.sin(phase / 0.22 * math.pi * 6) * math.rad(num(inst, "ShakeAmp", 7))
						cf = cf * CFrame.Angles(0, 0, a) * CFrame.new(0, math.abs(a) * 1.2, 0)
					end
				end
				if k.Swim then
					local r, sp = num(inst, "SwimRadius", 2.5), num(inst, "SwimSpeed", 0.4)
					local a = t * sp
					cf = CFrame.new(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)) * cf * CFrame.Angles(0, -a, 0)
				end
				if k.Spin then
					local ang = math.rad(now * num(inst, "SpinSpeed", 20))
					local axis = inst:GetAttribute("SpinAxis")
					cf = cf * (if axis == "X" then CFrame.Angles(ang, 0, 0) elseif axis == "Z" then CFrame.Angles(0, 0, ang) else CFrame.Angles(0, ang, 0))
				end
				if k.Sway and e.Foot then
					local amp = math.rad(num(inst, "SwayAmp", 4))
					local sp = num(inst, "SwaySpeed", 1)
					local foot = CFrame.new(e.Foot :: Vector3)
					cf = foot * CFrame.Angles(math.sin(t * sp) * amp, 0, math.cos(t * sp * 0.83) * amp * 0.7) * foot:Inverse() * cf
				end
				if inst:IsA("Model") then
					(inst :: Model):PivotTo(cf)
				elseif inst:IsA("BasePart") then
					(inst :: BasePart).CFrame = cf
				end
			end
			if k.Blink then
				local glow = 0.55 + 0.45 * math.sin(t * num(inst, "BlinkSpeed", 2))
				for _, l in e.Lights do
					l.Light.Brightness = l.Brightness * glow
				end
			end
			if k.Pulse then
				local glow = (math.sin(t * num(inst, "PulseSpeed", 1.5)) + 1) / 2
				for _, p in e.Parts do
					p.Part.Transparency = math.clamp(p.Transparency + glow * 0.35, 0, 0.95)
				end
			end
			if k.Wobble then
				local s = math.sin(t * num(inst, "WobbleSpeed", 2))
				for _, p in e.Parts do
					p.Part.Size = Vector3.new(p.Size.X * (1 + s * 0.05), p.Size.Y * (1 - s * 0.06), p.Size.Z * (1 + s * 0.05))
				end
			end
		end
	end)
end

return Animator
