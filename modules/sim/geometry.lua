-- Oriented boxes (OBB) and the exit sweep. Pure Lua, no Defold API, no Box2D.
-- A box faces along its angle: (ux, uy) is the forward axis, hl/hw are half length/width.
local M = {}

local abs, cos, sin, max = math.abs, math.cos, math.sin, math.max

-- Touching neighbours (gap 0) must not count as overlap.
M.EPS = 1e-3

function M.box(x, y, angle, len, wid)
	return { x = x, y = y, angle = angle, hl = len * 0.5, hw = wid * 0.5, ux = cos(angle), uy = sin(angle) }
end

-- Half extent of a box projected on axis (ax, ay)
local function radius(o, ax, ay)
	return o.hl * abs(o.ux * ax + o.uy * ay) + o.hw * abs(o.ux * ay - o.uy * ax)
end

local function separated(a, b, ax, ay, gap)
	local d = abs((b.x - a.x) * ax + (b.y - a.y) * ay)
	return d >= radius(a, ax, ay) + radius(b, ax, ay) + gap
end

-- SAT on the 4 box axes. gap > 0 demands clearance, gap < 0 tolerates touching.
function M.overlap(a, b, gap)
	gap = gap or 0
	return not (separated(a, b, a.ux, a.uy, gap) or separated(a, b, -a.uy, a.ux, gap)
		or separated(a, b, b.ux, b.uy, gap) or separated(a, b, -b.uy, b.ux, gap))
end

-- The area a box covers while driving `dist` forward
function M.swept(o, dist)
	local h = dist * 0.5
	return { x = o.x + o.ux * h, y = o.y + o.uy * h, angle = o.angle, hl = o.hl + h, hw = o.hw, ux = o.ux, uy = o.uy }
end

-- Free distance from the front bumper of `o` to the nearest point of `b` along o's axis
local function gap_ahead(o, b)
	local front = o.x * o.ux + o.y * o.uy + o.hl
	local near = (b.x * o.ux + b.y * o.uy) - radius(b, o.ux, o.uy)
	return max(0, near - front)
end

-- Exit check. `obstacles` must not contain `o` itself. `skip` (optional) is a box to ignore,
-- which lets callers test every box against one shared obstacle list.
-- Returns nil when the way is clear, else (index of nearest blocker, free distance to it).
function M.first_hit(o, obstacles, dist, skip)
	local sw = M.swept(o, dist)
	local best, best_d
	for i = 1, #obstacles do
		local b = obstacles[i]
		if b ~= skip and M.overlap(sw, b, -M.EPS) then
			local d = gap_ahead(o, b)
			if not best_d or d < best_d then best, best_d = i, d end
		end
	end
	return best, best_d
end

-- Distance that surely takes a box out of a w×h lot
function M.exit_distance(o, w, h)
	return math.sqrt(w * w + h * h) + 2 * o.hl
end

function M.contains(o, px, py, pad)
	pad = pad or 0
	local dx, dy = px - o.x, py - o.y
	return abs(dx * o.ux + dy * o.uy) <= o.hl + pad and abs(dy * o.ux - dx * o.uy) <= o.hw + pad
end

function M.inside_rect(o, w, h)
	local rx, ry = radius(o, 1, 0), radius(o, 0, 1)
	return o.x - rx >= -M.EPS and o.x + rx <= w + M.EPS and o.y - ry >= -M.EPS and o.y + ry <= h + M.EPS
end

return M
