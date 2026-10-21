--!strict
-- Popaint : formules du jeu (pures, sans effet de bord, testées automatiquement).

local Formulas = {}

export type Stats = {
	StudsPainted: number,
	BubblesPopped: number,
	CoinsEarned: number,
}

-- Prix = Prix de base x croissance^niveau
function Formulas.upgradeCost(baseCost: number, level: number, growth: number?): number
	return math.floor(baseCost * (growth or 1.15) ^ level + 0.5)
end

-- Points = studs peints + 2 x bulles éclatées + pièces gagnées / 10
function Formulas.points(stats: Stats): number
	return stats.StudsPainted + 2 * stats.BubblesPopped + stats.CoinsEarned / 10
end

-- Niveau = partie entière de la racine de (Points / diviseur), minimum 1
function Formulas.level(stats: Stats, divisor: number?): number
	local p = Formulas.points(stats)
	if p ~= p or p <= 0 then
		return 1
	end
	return math.max(1, math.floor(math.sqrt(p / (divisor or 50))))
end

-- Progression vers le niveau suivant (0 à 1)
function Formulas.levelProgress(stats: Stats, divisor: number?): number
	local d = divisor or 50
	local p = Formulas.points(stats)
	if p ~= p or p <= 0 then
		return 0
	end
	local lvl = Formulas.level(stats, d)
	local current = lvl * lvl * d
	local nextP = (lvl + 1) * (lvl + 1) * d
	if lvl == 1 then
		current = 0
	end
	return math.clamp((p - current) / (nextP - current), 0, 1)
end

-- Pièces gagnées pour un éclatement
function Formulas.popReward(tilesPainted: number, studValue: number, multiplier: number): number
	if tilesPainted <= 0 then
		return 0
	end
	return math.max(1, math.floor(tilesPainted * studValue * multiplier + 0.5))
end

-- Bonus d'un compagnon : { Coins = %, Radius = %, AutoPop = secondes }
function Formulas.companionBonus(rarityBonus: { [string]: number }, power: number, tierMultiplier: number): { [string]: number }
	local out = {}
	for k, v in rarityBonus do
		if k == "AutoPop" then
			out[k] = v -- l'intervalle ne change pas
		else
			out[k] = v * power * tierMultiplier
		end
	end
	return out
end

-- Additionne les bonus de plusieurs compagnons
function Formulas.sumBonuses(list: { { [string]: number } }): { Coins: number, Radius: number, AutoPops: { number } }
	local total = { Coins = 0, Radius = 0, AutoPops = {} }
	for _, b in list do
		total.Coins += b.Coins or 0
		total.Radius += b.Radius or 0
		if b.AutoPop then
			table.insert(total.AutoPops, b.AutoPop)
		end
	end
	return total
end

-- Choix pondéré : roll entre 0 et 1, chances en pourcentage
function Formulas.pickWeighted(chances: { { any } }, roll: number): any
	local total = 0
	for _, c in chances do
		total += c[2]
	end
	local target = roll * total
	local acc = 0
	for _, c in chances do
		acc += c[2]
		if target < acc then
			return c[1]
		end
	end
	return chances[#chances][1]
end

-- Rainbow Storm : actif pendant "duration" secondes toutes les "period" secondes (calé sur minuit UTC)
function Formulas.storm(t: number, period: number, duration: number): (boolean, number, number)
	local phase = t % period
	local cycleStart = t - phase
	local active = phase < duration
	local endsAt = cycleStart + duration
	local nextStart = cycleStart + period
	return active, endsAt, nextStart
end

-- Date UTC -> secondes depuis le 1er janvier 1970 (pour les dates des événements)
function Formulas.utcEpoch(year: number, month: number, day: number, hour: number?): number
	-- algorithme "days from civil" (calendrier grégorien)
	local y = if month <= 2 then year - 1 else year
	local era = (if y >= 0 then y else y - 399) // 400
	local yoe = y - era * 400
	local m = month
	local doy = (153 * (if m > 2 then m - 3 else m + 9) + 2) // 5 + day - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	local days = era * 146097 + doe - 719468
	return days * 86400 + (hour or 0) * 3600
end

-- Numéro du jour UTC (change à minuit UTC)
function Formulas.dayNumber(t: number): number
	return math.floor(t / 86400)
end

-- Cadeau quotidien : retourne (peut réclamer ?, jour du cycle 1..7 qui sera donné)
function Formulas.daily(lastClaimDay: number, streak: number, today: number, cycle: number): (boolean, number)
	if lastClaimDay == today then
		return false, ((streak - 1) % cycle) + 1
	end
	if lastClaimDay == today - 1 then
		return true, (streak % cycle) + 1
	end
	return true, 1 -- jour manqué (ou premier jour) : retour au jour 1
end

-- Objectif d'une quête selon le nombre de quêtes déjà terminées
function Formulas.questTarget(base: number, completed: number, growth: number, cap: number): number
	return math.max(1, math.floor(base * (1 + growth * math.min(completed, cap)) + 0.5))
end

-- Gains hors ligne
function Formulas.offlineCoins(seconds: number, afkInterval: number, avgTiles: number, studValue: number, multiplier: number, rate: number, maxSeconds: number): number
	if seconds <= 0 or afkInterval <= 0 then
		return 0
	end
	local s = math.min(seconds, maxSeconds)
	return math.floor(s / afkInterval * avgTiles * studValue * multiplier * rate)
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1234 -> "1.23K", 15000000 -> "15M"
function Formulas.formatNumber(n: number): string
	if n ~= n then
		return "0"
	end
	local negative = n < 0
	n = math.abs(n)
	if n < 1000 then
		local s = tostring(math.floor(n))
		return if negative then "-" .. s else s
	end
	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end
	local text: string
	if n >= 100 then
		text = string.format("%d", math.floor(n))
	elseif n >= 10 then
		text = string.format("%.1f", math.floor(n * 10) / 10)
	else
		text = string.format("%.2f", math.floor(n * 100) / 100)
	end
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return (if negative then "-" else "") .. text .. SUFFIXES[index]
end

-- 125 -> "2:05", 3725 -> "1:02:05"
function Formulas.formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

return Formulas
