-- The solver's plan must also win in real time for a FAST player (taps the moment a bay is free).
-- Guards against rules that depend on animation timing (bay order, departure lag).
local T = require("tests.lib")
local levels = require("modules.meta.levels")
local rules = require("modules.sim.rules")
local solver = require("modules.sim.solver")
local sim = require("modules.sim.sim")

local N = tonumber(os.getenv and os.getenv("LEVELS") or nil) or 40
for n = 1, N do
	local level = levels.get(n)
	local ok, _, plan = solver.solve(rules.new(level), 30000)
	T.ok(ok, "level " .. n .. " solvable")
	local s = sim.new(level)
	local i = 1
	for _ = 1, 60 * 240 do
		local id = plan[i]
		if id and s.st.buses[id] and s.st.buses[id].state == "lot" and rules.free_bay(s.st, "open") then
			s:tap(id)
			if s.st.buses[id].state ~= "lot" then i = i + 1 end
		end
		s:update(1 / 60)
		if s.result then break end
	end
	T.eq(s.result, "won", "level " .. n .. " replayed in real time")
end
