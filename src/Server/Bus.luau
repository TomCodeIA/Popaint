--!strict
-- Popaint : petit système d'événements interne au serveur.
-- Exemple : Bus.emit("Popped", player, info) ; Bus.on("Popped", function(player, info) ... end)
-- Permet aux quêtes, au didacticiel, etc. de réagir sans que les services se connaissent.

local Bus = {}

local listeners: { [string]: { (...any) -> () } } = {}

function Bus.on(name: string, fn: (...any) -> ())
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], fn)
end

function Bus.emit(name: string, ...: any)
	local list = listeners[name]
	if not list then
		return
	end
	for _, fn in list do
		local ok, err = pcall(fn :: any, ...)
		if not ok then
			warn(("[Popaint] erreur dans l'écouteur %s : %s"):format(name, tostring(err)))
		end
	end
end

return Bus
