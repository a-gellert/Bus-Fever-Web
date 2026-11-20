-- Every campaign level must be solvable without boosters (the core promise of the web version).
local T = require("tests.lib")
local levels = require("modules.meta.levels")
local rules = require("modules.sim.rules")
local solver = require("modules.sim.solver")
local config = require("modules.config")

local N = tonumber(os.getenv and os.getenv("LEVELS") or nil) or 60
local unknown = 0
for n = 1, N do
	local level = levels.get(n)
	local seats = 0
	for _, b in ipairs(level.buses) do seats = seats + config.SIZES[b.size].cap end
	for _, g in ipairs(level.garages) do
		for _, spec in ipairs(g.queue) do seats = seats + config.SIZES[spec.size].cap end
	end
	T.eq(seats, #level.queue, "level " .. n .. " seats == passengers")
	local ok, nodes = solver.solve(rules.new(level), 30000)
	if ok == nil then unknown = unknown + 1 end
	T.ok(ok ~= false, "level " .. n .. " unsolvable (" .. #level.buses .. " buses, " .. nodes .. " nodes)")
end
T.ok(unknown <= N * 0.05, "solver budget ran out on " .. unknown .. " levels")
