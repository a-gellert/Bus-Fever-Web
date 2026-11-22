-- Player progress: highest level, booster stock, tutorial flag. The only module that touches save data.
local config = require("modules.config")
local save = require("modules.platform.save")

local M = {}

local VERSION = 1
local data

local function defaults()
	local d = { version = VERSION, level = 1, coins = 0, tutorial = false, muted = false, seen = {}, boosters = {} }
	for name, b in pairs(config.BOOSTERS) do d.boosters[name] = b.start end
	return d
end

local function int(v, min)
	v = tonumber(v)
	if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
	return math.min(1e6, math.max(min, math.floor(v)))
end

-- Any old or damaged save becomes a valid one: unknown fields dropped, bad values defaulted.
function M.load()
	local raw = save.load()
	local d = defaults()
	if type(raw) == "table" then
		d.level = int(raw.level, 1) or d.level
		d.coins = int(raw.coins, 0) or d.coins
		d.tutorial = raw.tutorial == true
		d.muted = raw.muted == true
		if type(raw.seen) == "table" then
			for name in pairs(config.BOOSTERS) do d.seen[name] = raw.seen[name] == true end
		end
		if type(raw.boosters) == "table" then
			for name in pairs(d.boosters) do
				d.boosters[name] = int(raw.boosters[name], 0) or d.boosters[name]
			end
		end
	end
	data = d
	return data
end

function M.flush() save.save(data) end

function M.level() return data.level end

-- Reaching level n+1 (never goes backwards, e.g. when replaying with a dev start level)
function M.complete_level(n)
	data.level = math.max(data.level, (n or data.level) + 1)
	M.flush()
end

function M.muted() return data.muted end

function M.set_muted(v)
	data.muted = v and true or false
	M.flush()
end

function M.coins() return data.coins end

function M.add_coins(n)
	n = math.floor(tonumber(n) or 0)
	if n <= 0 then return end
	data.coins = math.min(1e6, data.coins + n)
	M.flush()
end

function M.spend_coins(n)
	n = math.floor(tonumber(n) or 0)
	if n <= 0 or data.coins < n then return false end
	data.coins = data.coins - n
	M.flush()
	return true
end

-- booster explainer shown once per booster
function M.seen(name) return data.seen[name] == true end

function M.set_seen(name)
	data.seen[name] = true
	M.flush()
end

function M.tutorial_done() return data.tutorial end

function M.set_tutorial_done()
	if not data.tutorial then
		data.tutorial = true
		M.flush()
	end
end

-- unlocked by the level being played (so a dev start level shows the right boosters)
function M.booster_unlocked(name, level)
	return (level or data.level) >= config.BOOSTERS[name].unlock_level
end

function M.booster_count(name) return data.boosters[name] or 0 end

function M.spend_booster(name)
	if M.booster_count(name) <= 0 then return false end
	data.boosters[name] = data.boosters[name] - 1
	M.flush()
	return true
end

function M.add_booster(name, n)
	data.boosters[name] = M.booster_count(name) + (n or 1)
	M.flush()
end

return M
