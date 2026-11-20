local T = require("tests.lib")
local rules = require("modules.sim.rules")
local sim = require("modules.sim.sim")
local boosters = require("modules.sim.boosters")

local PI = math.pi
-- two buses in one lane: #2 (front, faces up) blocks nothing, #1 behind it faces up too
local level = {
	lot = { w = 4, h = 10 },
	bays = { open = 1, locked = 1, vip = true },
	buses = {
		{ x = 1, y = 2, angle = PI / 2, size = "s", color = 1 },
		{ x = 1, y = 5, angle = PI / 2, size = "s", color = 2, hidden = true },
	},
	queue = { 2, 2, 2, 2, 1, 1, 1, 1 },
}

local st = rules.new(level)
T.ok(not rules.exit_check(st, 1), "rear bus blocked")
T.ok(rules.exit_check(st, 2), "front bus free")
T.eq(st.buses[2].hidden, false, "free hidden bus revealed at start")

-- real-time sim: send the front bus, board 4, depart, then the rear one
local s = sim.new(level)
s:tap(1)
local ev = s:drain()
T.eq(ev[1].type, "blocked", "tap blocked bus")
s:tap(2)
for _ = 1, 120 do s:update(1 / 60) end
T.eq(s.st.buses[2].state, "gone", "front bus left full")
s:tap(1)
for _ = 1, 120 do s:update(1 / 60) end
T.eq(rules.status(s.st), "won", "level won")

-- stuck: one open bay holds the wrong colour
local s2 = sim.new(level)
s2.st.queue = { 1, 1, 1, 1, 2, 2, 2, 2 }
s2:tap(2)
for _ = 1, 60 do s2:update(1 / 60) end
T.eq(s2.result, "stuck", "out of spots")
T.ok(s2:unlock_bay(), "unlock + bay")
s2:tap(1)
for _ = 1, 240 do s2:update(1 / 60) end
T.eq(rules.status(s2.st), "won", "rescued by the extra bay")

-- arrange keeps the multiset and puts seated colours first
local st3 = rules.new(level)
st3.queue = { 1, 1, 2, 1, 2, 2, 1, 2 }
rules.send(st3, 2, rules.free_bay(st3, "open"))
T.ok(boosters.arrange(st3), "arrange applied")
T.eq(table.concat(st3.queue, ""), "22221111", "arrange order")
