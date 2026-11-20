-- Geometric lot templates (step 1 of level_gen). Each returns slots {x, y, angle, size};
-- direction (angle or angle + pi) is decided later by level_gen. Colours never live here.
local geometry = require("modules.sim.geometry")

local M = {}

local PI = math.pi
local atan2 = math.atan2 or math.atan -- LuaJIT vs Lua 5.3 (tests)
local GAP = 0.12 -- minimal clearance between parked vehicles

local function size_of(r, weights)
	local total = 0
	for _, w in pairs(weights) do total = total + w end
	local x = r:float() * total
	for _, k in ipairs({ "s", "m", "l" }) do
		x = x - (weights[k] or 0)
		if x < 0 then return k end
	end
	return "m"
end

-- Accepts the slot if it fits the lot and keeps clearance from accepted ones
local function try_place(slots, lot, sizes, x, y, angle, size)
	local s = sizes[size]
	local box = geometry.box(x, y, angle, s.len, s.wid)
	if not geometry.inside_rect(box, lot.w, lot.h) then return false end
	for _, o in ipairs(slots) do
		if geometry.overlap(box, o.box, GAP) then return false end
	end
	slots[#slots + 1] = { x = x, y = y, angle = angle, size = size, box = box }
	return true
end

-- Mosaic of lane-aligned vehicles in a frame rotated by `frame` (0 = grid, pi/4 = diagonal)
local function mosaic(r, lot, opt, frame, slots)
	slots = slots or {}
	local cx, cy = lot.w * 0.5, lot.h * 0.5
	local R = math.ceil(math.sqrt(lot.w * lot.w + lot.h * lot.h) * 0.5)
	local cf, sf = math.cos(frame), math.sin(frame)
	local cells = {}
	for v = -R, R do
		for u = -R, R do cells[#cells + 1] = { u, v } end
	end
	r:shuffle(cells)
	local pitch = 1 + GAP
	for _, c in ipairs(cells) do
		local size = size_of(r, opt.size_weights)
		local len = opt.sizes[size].len
		local along_v = r:float() < (opt.vertical or 0.5)
		for attempt = 1, 2 do
			local du, dv = 0, 0
			if along_v then dv = (len - 1) * 0.5 * pitch else du = (len - 1) * 0.5 * pitch end
			local u, v = c[1] * pitch + du, c[2] * pitch + dv
			local x, y = cx + u * cf - v * sf, cy + u * sf + v * cf
			local angle = frame + (along_v and PI * 0.5 or 0)
			if try_place(slots, lot, opt.sizes, x, y, angle, size) then break end
			along_v = not along_v
		end
	end
	return slots
end

function M.grid(r, lot, opt) return mosaic(r, lot, opt, 0) end

function M.diagonal(r, lot, opt) return mosaic(r, lot, opt, PI * 0.25) end

-- Fill free space around an existing layout with lane-aligned vehicles (corners of rings, fans)
function M.fill(r, lot, opt, slots) return mosaic(r, lot, opt, 0, slots) end

-- Concentric circles, vehicles tangent to the ring
function M.rings(r, lot, opt)
	local slots = {}
	local cx, cy = lot.w * 0.5, lot.h * 0.5
	local rmax = math.min(lot.w, lot.h) * 0.5 - 0.6
	local rad = opt.ring_start or 1.6
	while rad <= rmax do
		local theta = r:float() * 2 * PI
		local around = 0
		while around < 2 * PI * rad do
			local size = size_of(r, opt.size_weights)
			local len = opt.sizes[size].len
			local a = theta + (around + len * 0.5) / rad
			try_place(slots, lot, opt.sizes, cx + math.cos(a) * rad, cy + math.sin(a) * rad, a + PI * 0.5, size)
			around = around + len + GAP * 2
		end
		rad = rad + 1 + GAP * 3
	end
	return slots
end

-- Nested rectangular frames (the "square spiral" look)
function M.frames(r, lot, opt)
	local slots = {}
	local inset = 0.5
	while true do
		local x0, y0, x1, y1 = inset, inset, lot.w - inset, lot.h - inset
		if x1 - x0 < 3 or y1 - y0 < 3 then break end
		-- top and bottom lanes run horizontally, sides vertically
		for _, edge in ipairs({ { x0, y1, 1, 0 }, { x1, y0, -1, 0 }, { x0, y0, 0, 1 }, { x1, y1, 0, -1 } }) do
			local px, py, dx, dy = edge[1], edge[2], edge[3], edge[4]
			local span = (dx ~= 0) and (x1 - x0) or (y1 - y0)
			local t = 0
			while t < span do
				local size = size_of(r, opt.size_weights)
				local len = opt.sizes[size].len
				local m = t + len * 0.5
				try_place(slots, lot, opt.sizes, px + dx * m, py + dy * m, atan2(dy, dx), size)
				t = t + len + GAP
			end
		end
		inset = inset + 1 + GAP * 4
	end
	return slots
end

-- Rays from the bottom centre, vehicles pointing along the ray
function M.fan(r, lot, opt)
	local slots = {}
	local cx, cy = lot.w * 0.5, -1
	local rays = opt.rays or 13
	for i = 0, rays - 1 do
		local a = PI * (0.12 + 0.76 * i / (rays - 1))
		local d = 2.5
		while d < lot.w + lot.h do
			local size = size_of(r, opt.size_weights)
			local len = opt.sizes[size].len
			try_place(slots, lot, opt.sizes, cx + math.cos(a) * (d + len * 0.5), cy + math.sin(a) * (d + len * 0.5), a, size)
			d = d + len + GAP * 2
		end
	end
	return slots
end

M.NAMES = { "grid", "diagonal", "rings", "frames", "fan" }

return M
