-- Level generator with a solvability guarantee. Layout and colours are separate steps:
--   1. template -> slots (positions, angles, sizes)
--   2. reverse disassembly: repeatedly remove a vehicle whose exit is clear -> valid exit order[]
--      (no free vehicle: drop one; initial facings are retried so as few as possible are lost)
--   3. colours follow order[]; the passenger queue interleaves at most `window` consecutive
--      vehicles, and neighbours inside a window never share a colour, so sending vehicles in
--      order[] with `window` <= open bays always works without boosters.
-- Output is plain level data for rules.new (see rules.lua header).
local config = require("modules.config")
local geometry = require("modules.sim.geometry")
local templates = require("modules.sim.templates")
local rng = require("modules.sim.rng")

local M = {}

local PI = math.pi

local function exit_clear(box, others, lot, skip)
	return geometry.first_hit(box, others, geometry.exit_distance(box, lot.w, lot.h), skip) == nil
end

local function set_angle(s, angle)
	local sz = config.SIZES[s.size]
	s.angle = angle
	s.box = geometry.box(s.x, s.y, angle, sz.len, sz.wid)
end

-- Switching buses rotate with every other departure (same rule as rules.rotate_turners)
local function rotate_turners(slots)
	for _, s in ipairs(slots) do
		if s.turning then set_angle(s, s.angle + PI * 0.5) end
	end
end

-- Step 2. Returns slots in a valid exit order, plus the slots that never became free.
-- A dropped slot is not part of the real level, so it must not rotate the remaining buses.
-- Orientations are never flipped mid-way: a turner's angle at level start must not depend on
-- the disassembly history. (generate retries with different *initial* facings instead.)
local function disassemble(r, slots, lot, barriers)
	local remaining = {}
	for i, s in ipairs(slots) do remaining[i] = s end
	local order, dropped = {}, {}
	while #remaining > 0 do
		local boxes = {}
		for _, s in ipairs(remaining) do boxes[#boxes + 1] = s.box end
		for _, b in ipairs(barriers) do boxes[#boxes + 1] = b.box end
		local free = {}
		for i, s in ipairs(remaining) do
			if exit_clear(s.box, boxes, lot, s.box) then free[#free + 1] = i end
		end
		if #free == 0 then
			dropped[#dropped + 1] = table.remove(remaining, r:int(1, #remaining))
		else
			local i = free[r:int(1, #free)]
			order[#order + 1] = table.remove(remaining, i)
			rotate_turners(remaining) -- a real send: switching buses turn
		end
	end
	return order, dropped
end

-- Static barriers: they never move and block exit lanes. Placed in free gaps between buses,
-- preferably where they actually narrow at least one lane.
local function place_barriers(r, slots, lot, count)
	local barriers = {}
	local sweeps = {}
	for _, s in ipairs(slots) do
		sweeps[#sweeps + 1] = geometry.swept(s.box, geometry.exit_distance(s.box, lot.w, lot.h))
	end
	for _ = 1, count or 0 do
		local placed
		for _ = 1, 160 do
			local len = 2 + r:int(0, 2)
			local wid = 0.5
			local angle = r:float() < 0.5 and 0 or PI * 0.5
			local x = 0.5 + r:float() * (lot.w - 1)
			local y = 0.5 + r:float() * (lot.h - 1)
			local box = geometry.box(x, y, angle, len, wid)
			if geometry.inside_rect(box, lot.w, lot.h) then
				local clear = true
				for _, s in ipairs(slots) do
					if geometry.overlap(box, s.box, 0.08) then clear = false break end
				end
				for _, b in ipairs(barriers) do
					if geometry.overlap(box, b.box, 0.15) then clear = false break end
				end
				if clear then
					-- a barrier must lie in somebody's exit lane to be a real obstacle
					local blocks = false
					for _, sweep in ipairs(sweeps) do
						if geometry.overlap(box, sweep, -geometry.EPS) then blocks = true break end
					end
					if blocks then
						placed = { x = x, y = y, angle = angle, len = len, wid = wid, box = box }
						barriers[#barriers + 1] = placed
						break
					end
				end
			end
		end
		if not placed then break end
	end
	return barriers
end

-- Garage body: 1×1 box right behind a vehicle that must not cut anybody's exit path
local function try_garage(slot, order, lot, barriers, garages)
	local len = 1
	local s = config.SIZES[slot.size]
	local back = s.len * 0.5 + len * 0.5 -- same spot rules.garage_spot uses
	local gx, gy = slot.x - math.cos(slot.angle) * back, slot.y - math.sin(slot.angle) * back
	local body = geometry.box(gx, gy, slot.angle, len, s.wid)
	if not geometry.inside_rect(body, lot.w, lot.h) then return nil end
	for _, b in ipairs(barriers or {}) do
		if geometry.overlap(body, b.box, 0.05) then return nil end
	end
	for _, g in ipairs(garages or {}) do
		if geometry.overlap(body, g.box, 0.05) then return nil end
	end
	for _, o in ipairs(order) do
		if o ~= slot then
			if geometry.overlap(body, o.box, 0.05) then return nil end
			if geometry.overlap(body, geometry.swept(o.box, geometry.exit_distance(o.box, lot.w, lot.h)), -geometry.EPS) then
				return nil
			end
		end
	end
	return { x = gx, y = gy, angle = slot.angle, len = len, wid = s.wid, box = body }
end

-- Step 3. Pick a colour different from the previous `window - 1` vehicles.
local function pick_color(r, recent, n_colors)
	for _ = 1, 20 do
		local c = r:int(1, n_colors)
		local ok = true
		for _, p in ipairs(recent) do
			if p == c then ok = false break end
		end
		if ok then return c end
	end
	return r:int(1, n_colors)
end

local function build_queue(r, groups, window)
	local queue, active, next_group = {}, {}, 1
	local function refill()
		while #active < window and next_group <= #groups do
			local g = groups[next_group]
			active[#active + 1] = { color = g.color, left = g.cap }
			next_group = next_group + 1
		end
	end
	refill()
	while #active > 0 do
		-- earlier vehicles are favoured so the head of the queue stays readable
		local i = 1
		while i < #active and r:float() < 0.35 do i = i + 1 end
		local g = active[i]
		local chunk = math.min(g.left, r:int(2, 4))
		for _ = 1, chunk do queue[#queue + 1] = g.color end
		g.left = g.left - chunk
		if g.left == 0 then
			table.remove(active, i)
			refill()
		end
	end
	return queue
end

-- params: seed, template, count, colors, window, hidden (0..1), garages (n), garage_depth,
--         turners (0..1), barriers (n), size_weights {s=,m=,l=,xl=,limo=}, lot {w,h},
--         bays {open, locked, vip}
function M.generate(p)
	local r = rng.new(p.seed)
	local lot = p.lot or { w = 13, h = 17 }
	local opt = { sizes = config.SIZES, vertical = p.vertical,
		size_weights = p.size_weights or { s = 3, m = 4, l = 2, xl = 0, limo = 0 } }
	local slots = templates[p.template or "grid"](r, lot, opt)
	local count = p.count or #slots

	-- too sparse: fill the free corners, then drop extra fillers first so the shape stays whole
	local base = #slots
	if base < count then
		templates.fill(r, lot, opt, slots)
		while #slots > count and #slots > base do table.remove(slots, r:int(base + 1, #slots)) end
	end

	-- trim to the target count, then random facing
	r:shuffle(slots)
	while #slots > count do table.remove(slots) end
	local turner_count = 0
	for _, s in ipairs(slots) do
		if r:float() < 0.5 then set_angle(s, s.angle + PI) end
		local can_turn = (p.turners or 0) > 0 and turner_count < (p.max_turners or 2)
		s.turning = can_turn and r:float() < p.turners
		if s.turning then turner_count = turner_count + 1 end
		s.base_angle, s.flip = s.angle, false
	end

	local barriers = place_barriers(r, slots, lot, p.barriers or 0)
	-- Retry the whole disassembly with different initial facings for the slots that get
	-- permanently locked. A 180-degree flip has the same footprint, so barriers stay valid.
	local order, dropped
	for _ = 1, 6 do
		for _, s in ipairs(slots) do
			local a = s.base_angle + (s.flip and PI or 0)
			set_angle(s, a)
			s.start_angle = a
		end
		order, dropped = disassemble(r, slots, lot, barriers)
		if #dropped == 0 then break end
		local d = dropped[r:int(1, #dropped)]
		d.flip = not d.flip
	end
	local window = math.max(1, p.window or 2)
	local n_colors = math.max(window + 1, p.colors or 4)

	-- garages: a late vehicle in order[] becomes the gate of a stack
	local garage_of = {}
	local garages = {}
	for _ = 1, p.garages or 0 do
		local candidates = {}
		for k = math.floor(#order / 2) + 1, #order do
			if order[k] and not garage_of[k] and not order[k].turning then
				candidates[#candidates + 1] = k
			end
		end
		r:shuffle(candidates)
		for _, k in ipairs(candidates) do
			local g = try_garage(order[k], order, lot, barriers, garages)
			if g then
				g.depth = p.garage_depth or 3
				g.belt = p.belt_garages and true or false
				garage_of[k] = g
				garages[#garages + 1] = g
				break
			end
		end
	end

	-- colours along the exit order; a garage stack follows its gate vehicle
	local level = { seed = p.seed, lot = lot, buses = {}, garages = {}, barriers = {}, queue = nil,
		bays = p.bays or { open = config.BAYS_OPEN, locked = config.BAYS_LOCKED, vip = config.HAS_VIP_BAY } }
	for _, b in ipairs(barriers) do
		level.barriers[#level.barriers + 1] = { x = b.x, y = b.y, angle = b.angle, len = b.len, wid = b.wid }
	end
	local groups, recent = {}, {}
	local function next_color()
		local c = pick_color(r, recent, n_colors)
		table.insert(recent, c)
		if #recent > window - 1 then table.remove(recent, 1) end
		return c
	end
	for k, s in ipairs(order) do
		local g = garage_of[k]
		if g then
			local gq = {}
			for _ = 1, g.depth do
				local c = next_color()
				gq[#gq + 1] = { size = s.size, color = c }
				groups[#groups + 1] = { color = c, cap = config.SIZES[s.size].cap }
			end
			level.garages[#level.garages + 1] = { x = g.x, y = g.y, angle = g.angle, len = g.len, wid = g.wid,
				belt = g.belt, queue = gq }
		else
			local c = next_color()
			level.buses[#level.buses + 1] = { x = s.x, y = s.y, angle = s.start_angle, size = s.size, color = c,
				hidden = r:float() < (p.hidden or 0), turning = s.turning }
			groups[#groups + 1] = { color = c, cap = config.SIZES[s.size].cap }
		end
	end
	level.queue = build_queue(r, groups, window)
	level.window = window
	return level
end

return M
