-- Sawtooth sanity with the casual-player model (solver.play_casual): first levels can't be lost,
-- breathers are easy, peaks are hard but not walls. Tuned seeds live in modules/meta/level_seeds.lua.
local T = require("tests.lib")
local levels = require("modules.meta.levels")
local rules = require("modules.sim.rules")
local solver = require("modules.sim.solver")
local rng = require("modules.sim.rng")

local RUNS = 12
local function fail_rate(n)
	local st = rules.new(levels.get(n))
	local fails = 0
	for r = 1, RUNS do
		if not solver.play_casual(st, rng.new(n * 1000 + r), 40, 8) then fails = fails + 1 end
	end
	return fails / RUNS
end

for n = 1, 3 do T.eq(fail_rate(n), 0, "level " .. n .. " cannot be lost") end

local sums = {}
for n = 6, 40 do
	local _, t = levels.difficulty(n)
	sums[t] = sums[t] or { 0, 0 }
	sums[t][1] = sums[t][1] + fail_rate(n)
	sums[t][2] = sums[t][2] + 1
end
local function avg(t) return sums[t][1] / sums[t][2] end
print(string.format("  casual fail: breather %.0f%%, rising %.0f/%.0f/%.0f%%, peak %.0f%%",
	avg(0.0) * 100, avg(0.2) * 100, avg(0.4) * 100, avg(0.6) * 100, avg(1.0) * 100))
T.ok(avg(0.0) <= 0.2, "breathers easy")
T.ok(avg(1.0) <= 0.75, "peaks are not walls")
T.ok(avg(1.0) > avg(0.0) + 0.2, "peaks clearly harder than breathers")
