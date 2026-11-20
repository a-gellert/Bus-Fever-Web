-- Player progress: current level, coins, booster stock. The only module that touches save data.
local config = require("modules.config")
local save = require("modules.platform.save")

local M = {}

local data

local function defaults()
	local d = { version = 1, level = 1, coins = 0, boosters = {} }
	for name, b in pairs(config.BOOSTERS) do d.boosters[name] = b.start end
	return d
end

function M.load()
	data = save.load() or defaults()
	local def = defaults()
	for k, v in pairs(def) do
		if data[k] == nil then data[k] = v end
	end
	for name, n in pairs(def.boosters) do
		if data.boosters[name] == nil then data.boosters[name] = n end
	end
	return data
end

function M.flush() save.save(data) end

function M.level() return data.level end

function M.complete_level()
	data.level = data.level + 1
	M.flush()
end

function M.booster_unlocked(name)
	return data.level >= config.BOOSTERS[name].unlock_level
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
