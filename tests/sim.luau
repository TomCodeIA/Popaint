-- Simulation d'un vrai serveur Popaint hors de Roblox :
-- on charge le fichier de jeu généré, on exécute les VRAIS scripts serveur, et on simule
-- le temps, les joueurs, les éclatements, les réinitialisations, la sauvegarde.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local lib = require("./lib")

local sim = {}

---------------------------------------------------------------- signaux
local Signal = {}
Signal.__index = Signal
function Signal.new(name)
	return setmetatable({ name = name, handlers = {} }, Signal)
end
function Signal:Connect(fn)
	local conn = { Connected = true }
	local entry = { fn = fn, conn = conn }
	table.insert(self.handlers, entry)
	function conn.Disconnect()
		conn.Connected = false
	end
	return conn
end
function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn.Disconnect()
		fn(...)
	end)
	return conn
end

---------------------------------------------------------------- état global de la simulation (réinitialisé à chaque run)
local S -- état courant

local function hid(inst)
	local id = inst:GetAttribute("__simid")
	if not id then
		S.nextHid += 1
		id = S.nextHid
		inst:SetAttribute("__simid", id)
	end
	return id
end

local function signalOf(inst, name)
	local key = hid(inst) .. "." .. name
	local s = S.signals[key]
	if not s then
		s = Signal.new(name)
		S.signals[key] = s
	end
	return s
end

---------------------------------------------------------------- ordonnanceur (task.*) avec temps simulé
local function report(err, co)
	local msg = tostring(err) .. "\n" .. debug.traceback(co)
	table.insert(S.errors, msg)
	print("  [ERREUR SCRIPT] " .. msg)
end

local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		report(err, co)
	end
end

local taskLib = {}
function taskLib.spawn(f, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
	resume(co, ...)
	return co
end
function taskLib.defer(f, ...)
	return taskLib.delay(0, f, ...)
end
function taskLib.delay(t, f, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
	table.insert(S.sleepers, { co = co, wake = S.clock + (t or 0), args = table.pack(...) })
	return co
end
function taskLib.wait(t)
	local co = coroutine.running()
	local start = S.clock
	table.insert(S.sleepers, { co = co, wake = S.clock + math.max(t or 0, 1 / 60), args = nil })
	coroutine.yield()
	return S.clock - start
end
function taskLib.cancel(co)
	for i = #S.sleepers, 1, -1 do
		if S.sleepers[i].co == co then
			table.remove(S.sleepers, i)
		end
	end
end

-- Avance le temps simulé, par pas de "step" secondes
function sim.advance(seconds, step)
	step = step or 0.1
	local target = S.clock + seconds
	while S.clock < target - 1e-9 do
		S.clock = math.min(target, S.clock + step)
		local due = {}
		for i = #S.sleepers, 1, -1 do
			if S.sleepers[i].wake <= S.clock + 1e-9 then
				table.insert(due, table.remove(S.sleepers, i))
			end
		end
		table.sort(due, function(a, b)
			return a.wake < b.wake
		end)
		for _, s in due do
			if coroutine.status(s.co) == "suspended" then
				if s.args then
					resume(s.co, table.unpack(s.args, 1, s.args.n))
				else
					resume(s.co)
				end
			end
		end
	end
end

-- Lance une fonction comme un thread Roblox
function sim.run(fn, ...)
	return taskLib.spawn(fn, ...)
end

function sim.fire(signal, ...)
	for _, h in signal.handlers do
		if h.conn.Connected then
			taskLib.spawn(h.fn, ...)
		end
	end
end

---------------------------------------------------------------- API Roblox simulée (méthodes absentes de Lune)
local implemented = false
local function implementOnce()
	if implemented then
		return
	end
	implemented = true
	roblox.implementMethod("Instance", "WaitForChild", function(self, name, timeout)
		local c = self:FindFirstChild(name)
		if c then
			return c
		end
		-- comme Roblox : on attend que l'enfant apparaisse
		local waited = 0
		while waited < (timeout or 60) do
			waited += taskLib.wait(0.1)
			c = self:FindFirstChild(name)
			if c then
				return c
			end
		end
		if timeout then
			return nil
		end
		error("WaitForChild infini : " .. self:GetFullName() .. "." .. name)
	end)
	roblox.implementMethod("Instance", "GetAttributeChangedSignal", function(self, name)
		return signalOf(self, "Attr_" .. name)
	end)
	roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(self, name)
		return signalOf(self, "Prop_" .. name)
	end)
	for _, m in { "FillBall", "FillBlock", "SetMaterialColor" } do
		roblox.implementMethod("Terrain", m, function(_, ...)
			S.terrainCalls[m] = (S.terrainCalls[m] or 0) + 1
		end)
	end
	roblox.implementMethod("RunService", "IsServer", function()
		return true
	end)
	roblox.implementMethod("RunService", "IsClient", function()
		return false
	end)
	roblox.implementMethod("RunService", "IsStudio", function()
		return S.studio == true
	end)
	roblox.implementMethod("Workspace", "GetServerTimeNow", function()
		return S.epoch + S.clock
	end)
	roblox.implementMethod("DataModel", "BindToClose", function(_, fn)
		table.insert(S.closeCallbacks, fn)
	end)
	roblox.implementMethod("DataStoreService", "GetDataStore", function(_, name)
		if S.noDataStore then
			error("Studio access to APIs is not allowed (simulé)")
		end
		S.storeName = name
		return S.store
	end)
	roblox.implementMethod("Players", "GetPlayers", function()
		local list = {}
		for _, p in S.players do
			table.insert(list, p)
		end
		return list
	end)
	roblox.implementMethod("Player", "Kick", function(self, msg)
		S.kicks[self.UserId] = msg or ""
		self.Parent = nil
	end)
	roblox.implementMethod("RemoteEvent", "FireAllClients", function(self, ...)
		table.insert(S.remoteLog, { name = self.Name, args = table.pack(...) })
	end)
	roblox.implementMethod("RemoteEvent", "FireClient", function(self, player, ...)
		table.insert(S.remoteLog, { name = self.Name, to = player.UserId, args = table.pack(...) })
	end)
	pcall(function()
		roblox.implementProperty("DataModel", "JobId", function()
			return "job-sim"
		end)
	end)
	for _, pair in {
		{ "Players", "PlayerAdded" }, { "Players", "PlayerRemoving" }, { "Player", "CharacterAdded" },
		{ "RemoteEvent", "OnServerEvent" }, { "RemoteEvent", "OnClientEvent" },
		{ "ProximityPrompt", "Triggered" },
	} do
		roblox.implementProperty(pair[1], pair[2], function(self)
			return signalOf(self, pair[2])
		end)
	end
end

---------------------------------------------------------------- Random (absent de Lune)
local RandomMT = {}
RandomMT.__index = RandomMT
function RandomMT:NextNumber(a, b)
	a = a or 0
	b = b or 1
	return a + math.random() * (b - a)
end
function RandomMT:NextInteger(a, b)
	return math.random(a, b)
end
local RandomLib = {
	new = function()
		return setmetatable({}, RandomMT)
	end,
}

---------------------------------------------------------------- chargement des scripts depuis le fichier de jeu
local function makeEnv(scriptInst)
	local fakeOs = setmetatable({
		time = function()
			return math.floor(S.epoch + S.clock)
		end,
		clock = function()
			return S.clock
		end,
	}, { __index = os })
	local env
	env = lib.baseEnv({
		game = S.gameProxy,
		workspace = S.game:GetService("Workspace"),
		script = scriptInst,
		task = taskLib,
		os = fakeOs,
		Random = RandomLib,
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				parts[i] = tostring((select(i, ...)))
			end
			local msg = table.concat(parts, " ")
			table.insert(S.warnings, msg)
			if S.verbose then
				print("  [warn] " .. msg)
			end
		end,
		print = function(...)
			if S.verbose then
				print("  [print]", ...)
			end
		end,
	})
	env.require = function(m)
		local key = m:GetFullName()
		if S.modules[key] ~= nil then
			return S.modules[key]
		end
		local fn = luau.load(m.Source, { debugName = key, environment = makeEnv(m) })
		local result = fn()
		S.modules[key] = result
		return result
	end
	return env
end

---------------------------------------------------------------- démarrage d'un serveur simulé
function sim.start(opts)
	opts = opts or {}
	implementOnce()
	math.randomseed(opts.seed or 1234)
	S = {
		clock = 0,
		-- Lune range les attributs entiers en float32 (Roblox : en double) : on garde des dates petites
		epoch = 1_000_000,
		sleepers = {},
		signals = {},
		nextHid = 0,
		errors = {},
		warnings = {},
		remoteLog = {},
		kicks = {},
		players = {},
		modules = {},
		closeCallbacks = {},
		terrainCalls = {},
		store = opts.store or sim.makeStore(),
		noDataStore = opts.noDataStore,
		studio = opts.studio,
		verbose = opts.verbose,
	}
	S.game = roblox.deserializePlace(fs.readFile(opts.place or "build/Popaint.rbxl"))
	-- "game" vu par les scripts : le vrai DataModel + JobId (propriété que Lune ne fournit pas)
	local real = S.game
	S.gameProxy = setmetatable({}, {
		__index = function(_, k)
			if k == "JobId" then
				return "job-sim"
			end
			local v = real[k]
			if type(v) == "function" then
				return function(_, ...)
					return v(real, ...)
				end
			end
			return v
		end,
	})
	S.Players = S.game:GetService("Players")
	S.ServerScriptService = S.game:GetService("ServerScriptService")
	S.ReplicatedStorage = S.game:GetService("ReplicatedStorage")
	local main = S.ServerScriptService.Server.Main
	sim.run(function()
		local fn = luau.load(main.Source, { debugName = "Main", environment = makeEnv(main) })
		fn()
	end)
	sim.advance(1)
	return S
end

function sim.state()
	return S
end

-- Faux DataStore (même comportement que le vrai : copie des valeurs)
local function deep(v)
	if type(v) ~= "table" then
		return v
	end
	local o = {}
	for k, x in v do
		o[k] = deep(x)
	end
	return o
end
sim.deep = deep
function sim.makeStore()
	local store = { data = {}, failNext = 0, writes = 0 }
	function store:UpdateAsync(key, fn)
		if self.failNext > 0 then
			self.failNext -= 1
			error("DataStore indisponible (simulé)")
		end
		local new = fn(deep(self.data[key]))
		if new ~= nil then
			self.data[key] = deep(new)
			self.writes += 1
		end
		return new
	end
	function store:GetAsync(key)
		return deep(self.data[key])
	end
	return store
end

-- Fait arriver un joueur avec un personnage
function sim.join(userId, name, position)
	local p = roblox.Instance.new("Player")
	p.Name = name
	p.UserId = userId
	p.DisplayName = name
	local character = roblox.Instance.new("Model")
	character.Name = name
	local root = roblox.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = roblox.CFrame.new(position or roblox.Vector3.new(0, 3, 18))
	root.Parent = character
	character.Parent = S.game:GetService("Workspace")
	p.Parent = S.Players
	p.Character = character
	S.players[userId] = p
	sim.fire(signalOf(S.Players, "PlayerAdded"), p)
	return p, root
end

function sim.leave(p)
	S.players[p.UserId] = nil
	sim.fire(signalOf(S.Players, "PlayerRemoving"), p)
	p.Parent = nil
end

function sim.respawn(p, position)
	local character = roblox.Instance.new("Model")
	local root = roblox.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = roblox.CFrame.new(position)
	root.Parent = character
	character.Parent = S.game:GetService("Workspace")
	p.Character = character
	sim.fire(signalOf(p, "CharacterAdded"), character)
	return root
end

-- Le client envoie "j'éclate la bulle id"
function sim.clientFire(p, remoteName, ...)
	local remote = S.ReplicatedStorage.Remotes:FindFirstChild(remoteName)
	assert(remote, "remote absent : " .. remoteName)
	sim.fire(signalOf(remote, "OnServerEvent"), p, ...)
end

function sim.closeServer()
	for _, cb in S.closeCallbacks do
		sim.run(cb)
	end
end

-- Événements envoyés aux clients depuis l'index "since"
function sim.events(name, since)
	local out = {}
	for i = (since or 0) + 1, #S.remoteLog do
		local e = S.remoteLog[i]
		if e.name == name then
			table.insert(out, e)
		end
	end
	return out
end

function sim.logSize()
	return #S.remoteLog
end

-- Bulles vivantes d'un joueur, d'après ce que le serveur a envoyé aux clients
function sim.liveBubbles(userId)
	local live = {}
	for _, e in S.remoteLog do
		local a = e.args
		if e.name == "BubbleSpawned" and a[1] == userId then
			live[a[2]] = { id = a[2], position = a[3], size = a[4], cascade = a[6] }
		elseif (e.name == "BubblePopped" or e.name == "BubbleRemoved") and a[1] == userId then
			live[a[2]] = nil
		end
	end
	return live
end

function sim.zone(id)
	return S.game:GetService("Workspace").Map.Zones:FindFirstChild(id or "CandyMeadow")
end

-- Module serveur déjà chargé (ex. "DataService")
function sim.module(name)
	return S.modules["ServerScriptService.Server." .. name]
end

-- Un joueur appuie sur une invite (ProximityPrompt)
function sim.prompt(p, promptInstance)
	sim.fire(signalOf(promptInstance, "Triggered"), p)
end

-- Dernier état envoyé à un joueur
function sim.lastState(userId)
	for i = #S.remoteLog, 1, -1 do
		local e = S.remoteLog[i]
		if e.name == "State" and e.to == userId then
			return e.args[1]
		end
	end
	return nil
end

-- Messages "Effect" / "Notify" envoyés à un joueur
function sim.clientEvents(name, userId, since)
	local out = {}
	for i = (since or 0) + 1, #S.remoteLog do
		local e = S.remoteLog[i]
		if e.name == name and e.to == userId then
			table.insert(out, e.args)
		end
	end
	return out
end

function sim.setTime(epoch)
	S.epoch = epoch - S.clock
end

function sim.now()
	return S.epoch + S.clock
end

return sim
