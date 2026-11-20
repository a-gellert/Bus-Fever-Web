-- Player progress: highest level, booster stock, tutorial flag. The only module that touches save data.
local config = require("modules.config")
local save = require("modules.platform.save")

local M = {}

local VERSION = 1
local data

local function defaults()
	local d = { version = VERSION, level = 1, coins = 0, tutorial = false, boosters = {} }
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
