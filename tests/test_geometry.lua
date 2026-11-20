local T = require("tests.lib")
local g = require("modules.sim.geometry")

local PI = math.pi
local a = g.box(0, 0, 0, 2, 1)

-- touching side by side is not an overlap
T.ok(not g.overlap(a, g.box(0, 1, 0, 2, 1), -g.EPS), "touching")
T.ok(g.overlap(a, g.box(0, 0.9, 0, 2, 1), -g.EPS), "overlapping")
-- 45° box near a corner: SAT must separate it
T.ok(not g.overlap(a, g.box(2.2, 1.2, PI / 4, 1, 1)), "rotated separated")

-- exit sweep: blocker ahead, clear behind
local ahead = g.box(4, 0, PI / 2, 2, 1)
local hit, d = g.first_hit(a, { ahead }, 20)
T.eq(hit, 1, "blocked ahead")
T.ok(math.abs(d - 2.5) < 1e-6, "free distance " .. tostring(d))
local back = g.box(0, 0, PI, 2, 1)
T.eq(g.first_hit(back, { ahead }, 20), nil, "reverse is clear")

-- diagonal exit through a gap
local diag = g.box(0, 0, PI / 4, 2, 1)
T.eq(g.first_hit(diag, { g.box(3, 0, 0, 2, 1), g.box(0, 3, 0, 2, 1) }, 20), nil, "diagonal slips between")
T.ok(g.contains(diag, 0.6, 0.6), "contains")
