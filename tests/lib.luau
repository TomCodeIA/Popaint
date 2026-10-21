-- Petit framework de test + chargeur de modules Popaint hors de Roblox.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local lib = {}

local results = { passed = 0, failed = 0, failures = {} }
lib.results = results
local currentSuite = ""

function lib.suite(name: string)
	currentSuite = name
	print("\n== " .. name)
end

function lib.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		results.passed += 1
		print("  ok   " .. name)
	else
		results.failed += 1
		table.insert(results.failures, currentSuite .. " > " .. name .. " : " .. tostring(err))
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end

function lib.eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(("%s attendu=%s obtenu=%s"):format(msg or "", tostring(expected), tostring(actual)), 2)
	end
end

function lib.ok(cond: any, msg: string?)
	if not cond then
		error(msg or "condition fausse", 2)
	end
end

function lib.near(a: number, b: number, eps: number, msg: string?)
	if math.abs(a - b) > eps then
		error(("%s attendu≈%s obtenu=%s"):format(msg or "", tostring(b), tostring(a)), 2)
	end
end

-- Environnement de base : bibliothèques Luau + types de données Roblox
function lib.baseEnv(extra: { [string]: any }?): { [string]: any }
	local env = {
		math = math, string = string, table = table, coroutine = coroutine, utf8 = utf8, bit32 = bit32,
		buffer = buffer, debug = debug, os = os,
		pcall = pcall, xpcall = xpcall, error = error, assert = assert, type = type, typeof = typeof,
		tostring = tostring, tonumber = tonumber, pairs = pairs, ipairs = ipairs, next = next, select = select,
		setmetatable = setmetatable, getmetatable = getmetatable, rawget = rawget, rawset = rawset,
		rawequal = rawequal, rawlen = rawlen, unpack = table.unpack, print = print,
		warn = function(...)
			print("  [warn]", ...)
		end,
		Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, CFrame = roblox.CFrame, Color3 = roblox.Color3,
		UDim = roblox.UDim, UDim2 = roblox.UDim2, Enum = roblox.Enum, Instance = roblox.Instance,
		NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence, NumberRange = roblox.NumberRange, BrickColor = roblox.BrickColor,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	}
	if extra then
		for k, v in extra do
			env[k] = v
		end
	end
	return env
end

-- Charge un fichier source comme module avec un environnement donné
function lib.loadFile(path: string, env: { [string]: any }?): any
	local source = fs.readFile(path)
	local fn = luau.load(source, { debugName = path, environment = env or lib.baseEnv() })
	return fn()
end

-- Charge un module de src/ comme dans Roblox : "script.Parent:WaitForChild(...)" et "require"
-- fonctionnent sur les vrais fichiers (ex. Config qui lit le dossier Content).
local moduleCache: { [string]: any } = {}
local function fakeNode(path: string): any
	local node = { __path = path }
	node.Name = string.match(path, "([^/]+)$")
	function node.WaitForChild(_self: any, name: string): any
		local dir = path
		local file = dir .. "/" .. name .. ".luau"
		local ok = pcall(fs.readFile, file)
		if ok then
			return { __file = file, Name = name, Parent = node }
		end
		return fakeNode(dir .. "/" .. name)
	end
	node.FindFirstChild = node.WaitForChild
	return node
end

function lib.loadModule(file: string): any
	if moduleCache[file] ~= nil then
		return moduleCache[file]
	end
	local dir = string.match(file, "^(.*)/[^/]+$") or "."
	local env = lib.baseEnv()
	env.script = { __file = file, Name = string.match(file, "([^/]+)%.luau$"), Parent = fakeNode(dir) }
	env.require = function(m: any): any
		assert(type(m) == "table" and m.__file, "require d'un objet inconnu")
		return lib.loadModule(m.__file)
	end
	local result = lib.loadFile(file, env)
	moduleCache[file] = result
	return result
end

function lib.summary(): boolean
	print(("\n%d tests réussis, %d échoués"):format(results.passed, results.failed))
	for _, f in results.failures do
		print("  - " .. f)
	end
	return results.failed == 0
end

return lib
