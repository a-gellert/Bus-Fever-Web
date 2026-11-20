-- Driving routes: start at the bus, end in the bay, leave the lot along the arrow, never jump.
local T = require("tests.lib")
local route = require("modules.view.route")

local lot = { x0 = 20, y0 = 60, x1 = 520, y1 = 560 }
local function check(name, from, bay, under)
	local r = route.build(from, lot, bay, under, 30, 24)
	local x, y = r:at(0)
	T.ok(math.abs(x - from.x) < 1 and math.abs(y - from.y) < 1, name .. ": starts at the bus")
	x, y = r:at(r.length)
	T.ok(math.abs(x - bay.x) < 1 and math.abs(y - bay.y) < 1, name .. ": ends in the bay")
	local _, _, a0 = r:at(1)
	T.ok(math.cos(a0) * from.ux + math.sin(a0) * from.uy > 0.95, name .. ": leaves along the arrow")
	local _, _, a1 = r:at(r.length - 1)
	T.ok(math.sin(a1) > 0.9, name .. ": enters the bay heading up")
	-- inside the lot the bus only uses its own exit lane (proved clear by the rules)
	for s = 0, r.length, 2 do
		local qx, qy = r:at(s)
		local inside = qx > lot.x0 and qx < lot.x1 and qy > lot.y0 and qy < lot.y1
		if inside then
			local off = math.abs((qx - from.x) * from.uy - (qy - from.y) * from.ux)
			T.ok(off < 1, name .. ": stays in its lane inside the lot (off " .. off .. ")")
		end
	end
	local px, py = r:at(0)
	for s = 5, r.length, 5 do
		local qx, qy = r:at(s)
		T.ok(math.sqrt((qx - px) ^ 2 + (qy - py) ^ 2) <= 5.01, name .. ": no jumps")
		px, py = qx, qy
	end
	return r.length
end

-- portrait: bays above the lot
local bay = { x = 300, y = 650 }
check("up", { x = 300, y = 300, ux = 0, uy = 1 }, bay, 60)
check("down", { x = 300, y = 300, ux = 0, uy = -1 }, bay, 60)
check("left", { x = 300, y = 300, ux = -1, uy = 0 }, bay, 60)
check("right", { x = 100, y = 500, ux = 1, uy = 0 }, bay, 60)
check("diagonal", { x = 200, y = 200, ux = 0.7071, uy = -0.7071 }, bay, 60)
-- landscape: bays to the right of the lot
check("side bays", { x = 300, y = 300, ux = -1, uy = 0 }, { x = 800, y = 350 }, 70)
