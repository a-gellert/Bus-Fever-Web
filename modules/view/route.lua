-- Driving route from a parking spot to a bay (pure math, pixels):
--   forward along the arrow out of the lot -> along a road ring around the lot (shorter way round)
--   -> under the bay -> up into the bay. Corners are rounded locally (fillet), so the heading turns
--   smoothly while the exit lane, which the rules proved clear, stays straight.
local M = {}
M.__index = M

local atan2 = math.atan2 or math.atan
local EPS = 1e-3

-- distance from (px, py) along (ux, uy) to the boundary of rect r (point inside)
local function ray_exit(px, py, ux, uy, r)
	local t = math.huge
	if ux > EPS then t = math.min(t, (r.x1 - px) / ux) elseif ux < -EPS then t = math.min(t, (r.x0 - px) / ux) end
	if uy > EPS then t = math.min(t, (r.y1 - py) / uy) elseif uy < -EPS then t = math.min(t, (r.y0 - py) / uy) end
	return math.max(0, t)
end

-- position of a boundary point along the perimeter, counter-clockwise from the bottom-left corner
local function perim(r, x, y)
	local w, h = r.x1 - r.x0, r.y1 - r.y0
	if math.abs(y - r.y0) < 0.5 then return x - r.x0 end
	if math.abs(x - r.x1) < 0.5 then return w + (y - r.y0) end
	if math.abs(y - r.y1) < 0.5 then return w + h + (r.x1 - x) end
	return 2 * w + h + (r.y1 - y)
end

-- nearest point on the boundary of r
local function to_boundary(r, x, y)
	local cx, cy = math.min(math.max(x, r.x0), r.x1), math.min(math.max(y, r.y0), r.y1)
	if cx > r.x0 and cx < r.x1 and cy > r.y0 and cy < r.y1 then
		local d = { cx - r.x0, r.x1 - cx, cy - r.y0, r.y1 - cy }
		local m = math.min(d[1], d[2], d[3], d[4])
		if m == d[1] then cx = r.x0 elseif m == d[2] then cx = r.x1 elseif m == d[3] then cy = r.y0 else cy = r.y1 end
	end
	return cx, cy
end

-- ring corners between perimeter positions a and b, the shorter way round
local function ring_path(r, a, b)
	local w, h = r.x1 - r.x0, r.y1 - r.y0
	local P = 2 * (w + h)
	local corners = { { 0, r.x0, r.y0 }, { w, r.x1, r.y0 }, { w + h, r.x1, r.y1 }, { 2 * w + h, r.x0, r.y1 } }
	local ccw = (b - a) % P
	local out = {}
	if ccw <= P - ccw then
		for k = 0, 7 do -- walk corners after a, in order, up to b
			local c = corners[k % 4 + 1]
			local d = (c[1] - a) % P + (k >= 4 and P or 0)
			if d > EPS and d < ccw - EPS then out[#out + 1] = { d, c[2], c[3] } end
		end
		table.sort(out, function(p, q) return p[1] < q[1] end)
	else
		local cw = P - ccw
		for k = 0, 7 do
			local c = corners[k % 4 + 1]
			local d = (a - c[1]) % P + (k >= 4 and P or 0)
			if d > EPS and d < cw - EPS then out[#out + 1] = { d, c[2], c[3] } end
		end
		table.sort(out, function(p, q) return p[1] < q[1] end)
	end
	local pts, seen = {}, {}
	for _, p in ipairs(out) do
		local key = p[2] .. ":" .. p[3]
		if not seen[key] then seen[key] = true; pts[#pts + 1] = { p[2], p[3] } end
	end
	return pts
end

-- Round each corner locally: the curve starts at most `r` before the corner and ends `r` after it,
-- so a straight lane (the clear exit path) stays straight and nothing cuts back into the lot.
local function fillet(pts, r)
	local out = { pts[1] }
	for i = 2, #pts - 1 do
		local a, b, c = pts[i - 1], pts[i], pts[i + 1]
		local ab = math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
		local bc = math.sqrt((c[1] - b[1]) ^ 2 + (c[2] - b[2]) ^ 2)
		local r1, r2 = math.min(r, ab * 0.5), math.min(r, bc * 0.5)
		local p = { b[1] + (a[1] - b[1]) * r1 / ab, b[2] + (a[2] - b[2]) * r1 / ab }
		local q = { b[1] + (c[1] - b[1]) * r2 / bc, b[2] + (c[2] - b[2]) * r2 / bc }
		for k = 0, 8 do -- quadratic Bezier p -> b -> q
			local t = k / 8
			local u = 1 - t
			out[#out + 1] = { u * u * p[1] + 2 * u * t * b[1] + t * t * q[1], u * u * p[2] + 2 * u * t * b[2] + t * t * q[2] }
		end
	end
	out[#out + 1] = pts[#pts]
	return out
end

local function polyline(pts)
	local self = setmetatable({ pts = pts, cum = { 0 } }, M)
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		self.cum[i] = self.cum[i - 1] + math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
	end
	self.length = self.cum[#pts]
	return self
end

-- x, y, heading (radians) at distance s from the start
function M:at(s)
	s = math.max(0, math.min(s, self.length))
	local lo, hi = 1, #self.cum
	while hi - lo > 1 do
		local mid = math.floor((lo + hi) / 2)
		if self.cum[mid] < s then lo = mid else hi = mid end
	end
	local a, b = self.pts[lo], self.pts[hi]
	local seg = self.cum[hi] - self.cum[lo]
	local t = seg > 0 and (s - self.cum[lo]) / seg or 0
	return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, atan2(b[2] - a[2], b[1] - a[1])
end

-- straight line (departures)
function M.line(x0, y0, x1, y1)
	return polyline({ { x0, y0 }, { x1, y1 } })
end

-- from: {x, y, ux, uy} start pose (px); lot: {x0, y0, x1, y1} lot rect (px);
-- bay: {x, y} bay centre; under: distance below the bay centre where the bus lines up;
-- margin: ring offset outside the lot; radius: corner rounding (default = margin)
function M.build(from, lot, bay, under, margin, radius)
	local ring = { x0 = lot.x0 - margin, y0 = lot.y0 - margin, x1 = lot.x1 + margin, y1 = lot.y1 + margin }
	local t = ray_exit(from.x, from.y, from.ux, from.uy, ring)
	local p1 = { from.x + from.ux * t, from.y + from.uy * t }
	local e = { bay.x, bay.y - under }
	local qx, qy = to_boundary(ring, e[1], e[2])
	local pts = { { from.x, from.y }, p1 }
	for _, c in ipairs(ring_path(ring, perim(ring, p1[1], p1[2]), perim(ring, qx, qy))) do pts[#pts + 1] = c end
	pts[#pts + 1] = { qx, qy }
	if e[2] > qy + 1 or math.abs(e[1] - qx) > 1 then pts[#pts + 1] = e end -- line up under the bay
	pts[#pts + 1] = { bay.x, bay.y }
	-- drop zero-length steps (Chaikin would make kinks there)
	local clean = { pts[1] }
	for i = 2, #pts do
		local a, b = clean[#clean], pts[i]
		if math.abs(a[1] - b[1]) + math.abs(a[2] - b[2]) > 0.5 then clean[#clean + 1] = b end
	end
	return polyline(fillet(clean, radius or margin))
end

return M
