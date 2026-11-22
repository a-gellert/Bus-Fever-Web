-- Waiting row: one shared bus scale, and the longest bus of the level must fit a slot.
local T = require("tests.lib")
local layout = require("modules.view.layout")

local cases = {
	{ 540, 960, { w = 13, h = 17 }, 8, 6 },
	{ 360, 640, { w = 15, h = 20 }, 9, 6 },
	{ 1100, 620, { w = 13, h = 17 }, 9, 6 },
	{ 1600, 900, { w = 13, h = 17 }, 8, 5 },
}
for _, c in ipairs(cases) do
	local L = layout.compute(c[1], c[2], c[3], c[4], c[5])
	T.eq(L.max_bus_len, c[5], "max bus length kept")
	T.ok(L.bay_unit * c[5] <= L.bays.h + 1e-6, "long bus fits the waiting row")
	T.ok(L.bay_unit > 0, "positive bus scale")
	T.eq(#L.bay_pos, c[4], "one position per waiting spot")
	-- short and long buses use the same scalar; nothing per-size is stored
	T.eq(L.bus_scale, nil, "no per-bus scale table")
end
