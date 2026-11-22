-- Barriers, switching buses and the "clear spots" rescue: rules that must not silently break.
local T = require("tests.lib")
local rules = require("modules.sim.rules")
local levels = require("modules.meta.levels")

local PI = math.pi

-- A static barrier in the exit lane blocks the bus and is reported via free_buses
local blocked = {
	lot = { w = 8, h = 6 },
	bays = { open = 1 },
	barriers = { { x = 5, y = 1, angle = 0, len = 3, wid = 0.5 } },
	buses = { { x = 2, y = 1, angle = 0, size = "s", color = 1 } },
	queue = { 1, 1, 1, 1 },
}
local st = rules.new(blocked)
T.ok(not rules.exit_check(st, 1), "barrier blocks exit")
T.eq(#rules.free_buses(st), 0, "free_buses sees the barrier")

-- Switching bus turns 90 degrees whenever another bus is sent out
local turning = {
	lot = { w = 8, h = 8 },
	bays = { open = 2 },
	buses = {
		{ x = 1, y = 1, angle = 0, size = "s", color = 1 },
		{ x = 5, y = 5, angle = 0, size = "s", color = 2, turning = true },
	},
	queue = { 1, 1, 1, 1, 2, 2, 2, 2 },
}
local s2 = rules.new(turning)
local before = s2.buses[2].box.angle
rules.send(s2, 1, 1)
T.ok(math.abs(s2.buses[2].box.angle - (before + PI / 2)) < 1e-6, "turner rotates")

-- Clear spots frees every bay but leaves the passenger queue untouched
local s3 = rules.new(turning)
rules.send(s3, 1, 1)
rules.send(s3, 2, 2)
rules.arrive(s3, 1)
rules.arrive(s3, 2)
T.ok(s3.bays[1].bus and s3.bays[2].bus, "two buses parked")
local cleared = rules.clear_bays(s3)
T.eq(#cleared, 2, "both bays cleared")
T.ok(not s3.bays[1].bus and not s3.bays[2].bus, "bays are empty")
T.eq(s3.head, 1, "queue head unchanged")

-- free_buses must agree with the per-bus exit_check on a real, dense level
local lv = levels.get(39)
local s4 = rules.new(lv)
local function compare(tag)
	local set = {}
	for _, id in ipairs(rules.free_buses(s4)) do set[id] = true end
	for _, id in ipairs(rules.parked(s4)) do
		T.eq(set[id] or false, rules.exit_check(s4, id), tag .. " bus " .. id)
	end
end
compare("start")
local free = rules.free_buses(s4)
if #free > 0 then
	rules.send(s4, free[1], rules.free_bay(s4, "open") or 1)
	rules.arrive(s4, free[1])
	compare("after send")
end
