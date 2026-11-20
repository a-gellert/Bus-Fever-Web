-- Boosters never break a level: after Jumble the position stays solvable; Arrange keeps the multiset.
local T = require("tests.lib")
local levels = require("modules.meta.levels")
local rules = require("modules.sim.rules")
local solver = require("modules.sim.solver")
local sim = require("modules.sim.sim")

for _, n in ipairs({ 13, 17, 22, 28, 34, 41 }) do
	local level = levels.get(n)
	local _, _, plan = solver.solve(rules.new(level), 30000)
	local s = sim.new(level)
	-- play a third of the plan, then shake things up
	for i = 1, math.floor(#plan / 3) do
		s:tap(plan[i])
		for _ = 1, 90 do s:update(1 / 60) end
	end
	local before = {}
	for _, c in ipairs(s.st.queue) do before[c] = (before[c] or 0) + 1 end
	s:use_jumble()
	T.ok(solver.solve(s.st, 30000) ~= false, "level " .. n .. " solvable after jumble")
	s:use_arrange()
	local after = {}
	for _, c in ipairs(s.st.queue) do after[c] = (after[c] or 0) + 1 end
	for c, k in pairs(before) do T.eq(after[c], k, "arrange keeps colour " .. c) end
end
