-- Passenger path: a polyline sampled once, queried by arc length from the boarding point (head).
-- The queue itself is just colours in rules state; this only turns "i-th in line" into x, y.
local M = {}
M.__index = M

local atan2 = math.atan2 or math.atan

-- points: { {x, y}, ... } from the tail end to the head (boarding point last)
function M.new(points)
	local self = setmetatable({ pts = points, cum = { 0 } }, M)
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		self.cum[i] = self.cum[i - 1] + math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
	end
	self.length = self.cum[#points]
	return self
end

-- Point `d` units back from the head. Returns x, y, angle of travel (towards the head), on_path.
function M:at(d)
	local s = self.length - d
	if s <= 0 then
		local a, b = self.pts[1], self.pts[2]
		return a[1], a[2], atan2(b[2] - a[2], b[1] - a[1]), false
	end
	local lo, hi = 1, #self.cum
	while hi - lo > 1 do
		local mid = math.floor((lo + hi) / 2)
		if self.cum[mid] < s then lo = mid else hi = mid end
	end
	local a, b = self.pts[lo], self.pts[hi]
	local seg = self.cum[hi] - self.cum[lo]
	local t = seg > 0 and (s - self.cum[lo]) / seg or 0
	return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, atan2(b[2] - a[2], b[1] - a[1]), true
end

local function arc(out, cx, cy, rx, ry, a0, a1, steps)
	for i = 0, steps do
		local a = a0 + (a1 - a0) * i / steps
		out[#out + 1] = { cx + math.cos(a) * rx, cy + math.sin(a) * ry }
	end
end

-- Shapes in the unit square; the head always ends at the bottom centre, next to the bays.
M.SHAPES = {
	-- horseshoe: up the left, over the top, down the right, into the stop
	u = function()
		local p = { { 0.12, 0.1 } }
		arc(p, 0.5, 0.55, 0.38, 0.35, math.pi, 0, 24)
		p[#p + 1] = { 0.88, 0.3 }
		arc(p, 0.66, 0.3, 0.22, 0.22, 0, -math.pi * 0.5, 8)
		p[#p + 1] = { 0.5, 0.08 }
		return p
	end,
	-- full ring that unwinds into the stop
	ring = function()
		local p = {}
		arc(p, 0.5, 0.55, 0.4, 0.38, math.pi * 1.5 + 0.3, -math.pi * 0.5 + 0.3 - 2 * math.pi, 40)
		p[#p + 1] = { 0.5, 0.08 }
		return p
	end,
}

-- Shape scaled into a pixel rect
function M.in_rect(shape, r)
	local pts = {}
	for i, q in ipairs(M.SHAPES[shape]()) do
		pts[i] = { r.x + q[1] * r.w, r.y + q[2] * r.h }
	end
	return M.new(pts)
end

return M
