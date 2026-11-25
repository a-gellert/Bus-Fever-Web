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

function M:pos(s)
	if s <= 0 then return self.pts[1][1], self.pts[1][2] end
	if s >= self.length then return self.pts[#self.pts][1], self.pts[#self.pts][2] end
	local lo, hi = 1, #self.cum
	while hi - lo > 1 do
		local mid = math.floor((lo + hi) / 2)
		if self.cum[mid] < s then lo = mid else hi = mid end
	end
	local a, b = self.pts[lo], self.pts[hi]
	local seg = self.cum[hi] - self.cum[lo]
	local t = seg > 0 and (s - self.cum[lo]) / seg or 0
	return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
end

-- Point `d` units back from the head. Returns x, y, angle of travel (towards the head), on_path.
-- Tangent angle uses a smooth lookahead window to avoid angular singularities on sharp turns.
function M:at(d)
	local s = self.length - d
	if s <= 0 then
		local x0, y0 = self:pos(0)
		local x1, y1 = self:pos(math.min(self.length, 2))
		return x0, y0, atan2(y1 - y0, x1 - x0), false
	end
	local x, y = self:pos(s)
	local delta = 20
	local s0 = math.max(0, s - delta)
	local s1 = math.min(self.length, s + delta)
	local x0, y0 = self:pos(s0)
	local x1, y1 = self:pos(s1)
	local a = atan2(y1 - y0, x1 - x0)
	return x, y, a, s <= self.length
end

local function arc(out, cx, cy, rx, ry, a0, a1, steps)
	for i = 0, steps do
		local a = a0 + (a1 - a0) * i / steps
		out[#out + 1] = { cx + math.cos(a) * rx, cy + math.sin(a) * ry }
	end
end

-- Shapes in the unit square; head always ends at the bottom centre, next to the bays.
-- Designed with generous clearance and smooth radii to guarantee zero passenger overlap.
M.SHAPES = {
	-- 1. Horseshoe / U: wide sweeping arch across the top
	u = function(w, h)
		local p = { { 0.16, 0.15 }, { 0.16, 0.58 } }
		arc(p, 0.50, 0.58, 0.34, 0.30, math.pi, 0, 32)
		p[#p + 1] = { 0.84, 0.35 }
		arc(p, 0.67, 0.35, 0.17, 0.22, 0, -math.pi * 0.5, 16)
		p[#p + 1] = { 0.50, 0.08 }
		return p
	end,
	-- 2. Grand stadium roundabout: circling all the way around the field into the stop
	loop = function(w, h)
		local p = { { 0.55, 0.24 }, { 0.76, 0.24 } }
		arc(p, 0.76, 0.56, 0.12, 0.30, -math.pi * 0.5, math.pi * 0.5, 24)
		p[#p + 1] = { 0.24, 0.86 }
		arc(p, 0.24, 0.56, 0.12, 0.30, math.pi * 0.5, math.pi * 1.5, 24)
		arc(p, 0.50, 0.24, 0.26, 0.16, math.pi, math.pi * 1.5, 16)
		p[#p + 1] = { 0.50, 0.08 }
		return p
	end,
	-- 3. Double butterfly wings (two symmetric curved lobes matching reference Image 2)
	butterfly = function(w, h)
		local p = { { 0.16, 0.45 } }
		arc(p, 0.30, 0.65, 0.14, 0.22, math.pi, 0, 24)
		p[#p + 1] = { 0.44, 0.65 }
		p[#p + 1] = { 0.56, 0.65 }
		arc(p, 0.70, 0.65, 0.14, 0.22, math.pi, 0, 24)
		p[#p + 1] = { 0.84, 0.42 }
		arc(p, 0.67, 0.42, 0.17, 0.22, 0, -math.pi * 0.5, 16)
		p[#p + 1] = { 0.50, 0.08 }
		return p
	end,
	-- 4. Figure-8 / Lemniscate contour (smooth 8 matching reference Image 3 without crossing)
	figure8 = function(w, h)
		local p = {}
		local is_wide = (w and h and (w / h) >= 1.4) or false
		if is_wide then
			-- Horizontal 8: left lobe, crossover bridge, right lobe, and sweeping return into stop
			p[#p + 1] = { 0.14, 0.45 }
			arc(p, 0.28, 0.64, 0.14, 0.24, math.pi, 0, 24)
			p[#p + 1] = { 0.48, 0.56 }
			arc(p, 0.72, 0.64, 0.14, 0.24, math.pi, -math.pi * 0.5, 24)
			p[#p + 1] = { 0.72, 0.32 }
			arc(p, 0.60, 0.32, 0.12, 0.20, 0, -math.pi * 0.5, 16)
			p[#p + 1] = { 0.50, 0.08 }
		else
			-- Vertical 8 in landscape: exact Reference Image 3!
			arc(p, 0.58, 0.30, 0.20, 0.18, 0, -math.pi, 24)
			p[#p + 1] = { 0.48, 0.48 }
			p[#p + 1] = { 0.58, 0.52 }
			p[#p + 1] = { 0.68, 0.56 }
			arc(p, 0.58, 0.72, 0.20, 0.18, -math.pi * 0.2, math.pi * 1.0, 24)
			p[#p + 1] = { 0.22, 0.38 }
			p[#p + 1] = { 0.32, 0.18 }
			p[#p + 1] = { 0.50, 0.08 }
		end
		return p
	end,
	-- 5. Serpentine winding S-curve across the meadow
	snake = function(w, h)
		local p = { { 0.16, 0.86 }, { 0.76, 0.86 } }
		arc(p, 0.76, 0.60, 0.12, 0.26, math.pi * 0.5, -math.pi * 0.5, 20)
		p[#p + 1] = { 0.62, 0.34 }
		arc(p, 0.62, 0.21, 0.12, 0.13, math.pi * 0.5, math.pi, 16)
		p[#p + 1] = { 0.50, 0.08 }
		return p
	end,
}

-- Open grass pocket inside each shape for the "N LEFT" counter
M.COUNTER_POS = {
	u         = { 0.50, 0.50 },
	loop      = { 0.50, 0.56 },
	butterfly = { 0.50, 0.95 },
	figure8   = { 0.50, 0.95 },
	snake     = { 0.22, 0.20 },
}

-- Shape scaled into a pixel rect
function M.in_rect(shape, r)
	local pts = {}
	local fn = M.SHAPES[shape] or M.SHAPES.u
	for i, q in ipairs(fn(r.w, r.h)) do
		pts[i] = { r.x + q[1] * r.w, r.y + q[2] * r.h }
	end
	return M.new(pts)
end

return M
