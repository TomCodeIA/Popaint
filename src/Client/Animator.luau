--!strict
-- Popaint : anime le décor chez le joueur (bonbon qui tourne, phare, île flottante, gelée qui tremble...).
-- Un objet de la map est animé s'il porte l'attribut "Anim" (ex. "Spin,Bob"), voir tools/build.luau.
--
-- Compatible avec le chargement progressif (StreamingEnabled) : les objets qui arrivent près du
-- joueur sont pris en charge dès qu'ils apparaissent, et oubliés quand ils disparaissent.

local RunService = game:GetService("RunService")

local Animator = {}

type Entry = {
	Inst: Instance,
	Kinds: { [string]: boolean },
	Base: CFrame?,
	Parts: { { Part: BasePart, Transparency: number, Size: Vector3 } },
	Phase: number,
	Count: number, -- nombre de pièces au dernier inventaire (pour détecter les arrivées)
}

local entries: { [Instance]: Entry } = {}
local MAX_DISTANCE = 450 -- au-delà, inutile d'animer

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
	local e: Entry = { Inst = inst, Kinds = set, Base = nil, Parts = {}, Phase = math.random() * 10, Count = -1 }
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
		for _, e in entries do
			if recount and e.Inst:IsA("Model") then
				inventory(e)
			end
			local base = e.Base
			if not base or #e.Parts == 0 then
				continue
			end
			if (base.Position - eye).Magnitude > MAX_DISTANCE then
				continue
			end
			local inst = e.Inst
			local t = now + e.Phase
			if e.Kinds.Spin or e.Kinds.Bob then
				local cf = base
				if e.Kinds.Bob then
					cf = cf + Vector3.new(0, math.sin(t * num(inst, "BobSpeed", 1)) * num(inst, "BobAmp", 1), 0)
				end
				if e.Kinds.Spin then
					cf = cf * CFrame.Angles(0, math.rad(now * num(inst, "SpinSpeed", 20)), 0)
				end
				if inst:IsA("Model") then
					(inst :: Model):PivotTo(cf)
				elseif inst:IsA("BasePart") then
					(inst :: BasePart).CFrame = cf
				end
			end
			if e.Kinds.Pulse then
				local k = (math.sin(t * num(inst, "PulseSpeed", 1.5)) + 1) / 2
				for _, p in e.Parts do
					p.Part.Transparency = math.clamp(p.Transparency + k * 0.35, 0, 0.95)
				end
			end
			if e.Kinds.Wobble then
				local s = math.sin(t * num(inst, "WobbleSpeed", 2))
				for _, p in e.Parts do
					p.Part.Size = Vector3.new(p.Size.X * (1 + s * 0.05), p.Size.Y * (1 - s * 0.06), p.Size.Z * (1 + s * 0.05))
				end
			end
		end
	end)
end

return Animator
