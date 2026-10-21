--!strict
-- Popaint : sauvegarde des joueurs avec verrou de session.
--
-- Pourquoi un verrou ? Si un joueur change de serveur très vite, l'ancien serveur peut encore
-- être en train d'écrire. Sans verrou, le nouveau serveur chargerait de vieilles données et
-- le joueur perdrait sa progression (ou pourrait dupliquer des objets).
--
-- Le module ne touche pas directement à Roblox : on lui donne un "store" qui a une méthode
-- UpdateAsync(key, fn). Ça permet de le tester hors de Roblox avec un faux DataStore.

local ProfileStore = {}
ProfileStore.__index = ProfileStore

export type Store = {
	UpdateAsync: (self: any, key: string, transform: (any) -> any) -> any,
}

export type Options = {
	store: Store?, -- nil = mode mémoire (Studio sans accès API)
	jobId: string,
	now: () -> number,
	wait: (number) -> (),
	template: { [string]: any },
	lockExpire: number,
	retries: number,
	retryDelay: number,
	log: ((string) -> ())?,
}

export type Profile = {
	Key: string,
	Data: { [string]: any },
	Active: boolean, -- false une fois libéré ou perdu
	Lost: boolean, -- true si un autre serveur a pris le verrou (on ne doit plus rien écrire)
	LastSave: number,
}

export type LoadResult = "ok" | "locked" | "error"

type Self = typeof(setmetatable({} :: {
	_opts: Options,
	_memory: { [string]: any },
}, ProfileStore))

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value :: any do
		out[deepCopy(k)] = deepCopy(v)
	end
	return out :: any
end
ProfileStore.deepCopy = deepCopy

-- Complète les données avec les clés manquantes du modèle (utile quand on ajoute des
-- fonctionnalités : les anciens joueurs reçoivent automatiquement les nouvelles valeurs).
local function reconcile(data: { [string]: any }, template: { [string]: any })
	for k, v in template do
		local current = data[k]
		if current == nil then
			data[k] = deepCopy(v)
		elseif type(v) == "table" and type(current) == "table" then
			-- On ne complète que les tables "structure" (clés texte), pas les listes du joueur.
			if next(v) ~= nil and type((next(v))) == "string" then
				reconcile(current, v)
			end
		elseif type(v) ~= type(current) then
			data[k] = deepCopy(v) -- valeur corrompue : on remet la valeur par défaut
		end
	end
end
ProfileStore.reconcile = reconcile

function ProfileStore.new(opts: Options): Self
	local self = setmetatable({
		_opts = opts,
		_memory = {},
	}, ProfileStore)
	return self
end

function ProfileStore.isMemoryMode(self: Self): boolean
	return self._opts.store == nil
end

function ProfileStore._log(self: Self, msg: string)
	local log = self._opts.log
	if log then
		log(msg)
	end
end

-- Charge et verrouille le profil. Retourne (résultat, profil?).
function ProfileStore.load(self: Self, key: string): (LoadResult, Profile?)
	local opts = self._opts
	if opts.store == nil then
		local data = self._memory[key]
		if data == nil then
			data = deepCopy(opts.template)
		end
		reconcile(data, opts.template)
		self._memory[key] = data
		return "ok", { Key = key, Data = data, Active = true, Lost = false, LastSave = opts.now() }
	end
	local store = opts.store :: Store

	local sawLock = false
	for attempt = 1, opts.retries do
		local loaded: { [string]: any }? = nil
		local blocked = false
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old: any): any
				local now = opts.now()
				if type(old) == "table" and type(old.Lock) == "table" then
					local lock = old.Lock
					local mine = lock.JobId == opts.jobId
					local fresh = type(lock.Time) == "number" and now - lock.Time < opts.lockExpire
					if not mine and fresh then
						blocked = true
						return nil -- annule l'écriture
					end
				end
				local data: { [string]: any }
				if type(old) == "table" and type(old.Data) == "table" then
					data = old.Data
				else
					data = deepCopy(opts.template)
				end
				reconcile(data, opts.template)
				loaded = data
				return { Data = data, Lock = { JobId = opts.jobId, Time = now } }
			end)
		end)
		if ok and loaded then
			return "ok", { Key = key, Data = loaded :: any, Active = true, Lost = false, LastSave = opts.now() }
		end
		if ok and blocked then
			sawLock = true
			self:_log(("[Popaint] %s verrouillé ailleurs, essai %d/%d"):format(key, attempt, opts.retries))
		elseif not ok then
			self:_log(("[Popaint] échec du chargement de %s (essai %d/%d) : %s"):format(key, attempt, opts.retries, tostring(err)))
		end
		if attempt < opts.retries then
			opts.wait(opts.retryDelay)
		end
	end
	return if sawLock then "locked" else "error", nil
end

-- Sauvegarde. release = true libère le verrou (départ du joueur / fermeture du serveur).
-- Retourne true si la sauvegarde est passée.
function ProfileStore.save(self: Self, profile: Profile, release: boolean): boolean
	if not profile.Active or profile.Lost then
		return false
	end
	local opts = self._opts
	if opts.store == nil then
		self._memory[profile.Key] = profile.Data
		profile.LastSave = opts.now()
		if release then
			profile.Active = false
		end
		return true
	end
	local store = opts.store :: Store

	local stolen = false
	local snapshot = deepCopy(profile.Data)
	local attempts = if release then 3 else 1
	for attempt = 1, attempts do
		local ok, err = pcall(function()
			store:UpdateAsync(profile.Key, function(old: any): any
				if type(old) == "table" and type(old.Lock) == "table" and old.Lock.JobId ~= opts.jobId then
					stolen = true
					return nil
				end
				local lock = if release then nil else { JobId = opts.jobId, Time = opts.now() }
				return { Data = snapshot, Lock = lock }
			end)
		end)
		if ok then
			if stolen then
				profile.Lost = true
				profile.Active = false
				self:_log(("[Popaint] %s : verrou pris par un autre serveur, sauvegarde ignorée"):format(profile.Key))
				return false
			end
			profile.LastSave = opts.now()
			if release then
				profile.Active = false
			end
			return true
		end
		self:_log(("[Popaint] échec de sauvegarde de %s (essai %d/%d) : %s"):format(profile.Key, attempt, attempts, tostring(err)))
		if attempt < attempts then
			opts.wait(2)
		end
	end
	if release then
		profile.Active = false
	end
	return false
end

return ProfileStore
