-- Discrete game rules: the single source of truth for what is legal.
-- Used by the real-time sim (sim.lua adds timers on top) and by the solver (instant moves).
-- No Defold API, no time. Every mutating function returns a list of events for the view.
--
-- Level data (from level_gen or hand-made):
--   { lot = {w=, h=}, bays = {open=, locked=, vip=bool},
--     buses   = { {x=, y=, angle=, size="s|m|l|xl|limo", color=, hidden=bool, turning=bool} },
--     garages = { {x=, y=, angle=, len=, wid=, queue = { {size=, color=, hidden=} } } },
--     barriers = { {x=, y=, angle=, len=, wid=} },
--     queue   = { color, color, ... } }   -- passengers, head first
--
-- Bus states: "lot" -> "to_bay" -> "bay" -> "full" -> "gone"
local config = require("modules.config")
local geometry = require("modules.sim.geometry")

local M = {}

local function add_bus(st, spec, x, y, angle, garage)
	local size = config.SIZES[spec.size]
	st.next_id = st.next_id + 1
	local bus = {
		id = st.next_id, size = spec.size, cap = size.cap, left = size.cap, color = spec.color,
		hidden = spec.hidden or false, turning = spec.turning or false, garage = garage, state = "lot",
		box = geometry.box(x, y, angle, size.len, size.wid),
	}
	st.buses[bus.id] = bus
	st.order[#st.order + 1] = bus.id
	return bus
end

-- Where a garage puts its next bus: right in front of the gate, facing the same way
function M.garage_spot(g, size)
	local s = config.SIZES[size]
	local d = g.len * 0.5 + s.len * 0.5
	return g.x + math.cos(g.angle) * d, g.y + math.sin(g.angle) * d
end

local function garage_pop(st, gi, events)
	local g = st.garages[gi]
	local spec = table.remove(g.queue, 1)
	if not spec then return end
	local x, y = M.garage_spot(g, spec.size)
	local bus = add_bus(st, spec, x, y, g.angle, gi)
	g.current = bus.id
	events[#events + 1] = { type = "spawn", bus = bus.id, garage = gi }
end

function M.new(level)
	local st = {
		lot = { w = level.lot.w, h = level.lot.h },
		buses = {}, order = {}, next_id = 0,
		garages = {}, barriers = {}, bays = {},
		queue = {}, head = 1,
	}
	for i = 1, #level.queue do st.queue[i] = level.queue[i] end

	local b = level.bays
	if b.vip then st.bays[#st.bays + 1] = { kind = "vip" } end
	for _ = 1, b.open do st.bays[#st.bays + 1] = { kind = "open" } end
	for _ = 1, b.locked or 0 do st.bays[#st.bays + 1] = { kind = "locked" } end

	for i, spec in ipairs(level.barriers or {}) do
		st.barriers[i] = { x = spec.x, y = spec.y, angle = spec.angle, len = spec.len, wid = spec.wid,
			box = geometry.box(spec.x, spec.y, spec.angle, spec.len, spec.wid) }
	end
	for _, spec in ipairs(level.buses) do add_bus(st, spec, spec.x, spec.y, spec.angle) end
	local ev = {}
	for gi, g in ipairs(level.garages or {}) do
		local q = {}
		for i, spec in ipairs(g.queue) do q[i] = spec end
		st.garages[gi] = { x = g.x, y = g.y, angle = g.angle, len = g.len, wid = g.wid, belt = g.belt, queue = q,
			box = geometry.box(g.x, g.y, g.angle, g.len, g.wid) }
		garage_pop(st, gi, ev)
	end
	M.reveal(st, ev)
	return st
end

-- Boxes that block driving: parked buses (except `skip`), garage bodies and barriers
function M.obstacles(st, skip)
	local list, owners = {}, {}
	for _, id in ipairs(st.order) do
		local bus = st.buses[id]
		if bus.state == "lot" and id ~= skip then
			list[#list + 1] = bus.box
			owners[#list] = id
		end
	end
	for gi, g in ipairs(st.garages) do
		list[#list + 1] = g.box
		owners[#list] = -gi
	end
	for wi, w in ipairs(st.barriers) do
		list[#list + 1] = w.box
		owners[#list] = -1000 - wi -- negative, distinct from garage ids; the view ignores it
	end
	return list, owners
end

-- true if the bus can leave the lot; otherwise false, blocker id (negative = garage/barrier), free distance
function M.exit_check(st, id)
	local bus = st.buses[id]
	local obs, owners = M.obstacles(st, id)
	local hit, dist = geometry.first_hit(bus.box, obs, geometry.exit_distance(bus.box, st.lot.w, st.lot.h))
	if not hit then return true end
	return false, owners[hit], dist
end

-- All buses that can leave right now. Builds the obstacle list once, so solver and casual
-- player avoid an O(n) rebuild for every candidate bus.
function M.free_buses(st)
	local obs = M.obstacles(st)
	local dist = geometry.exit_distance({ hl = 0, hw = 0 }, st.lot.w, st.lot.h)
	local out = {}
	for _, id in ipairs(st.order) do
		local bus = st.buses[id]
		if bus.state == "lot" then
			local d = dist + 2 * bus.box.hl
			if not geometry.first_hit(bus.box, obs, d, bus.box) then out[#out + 1] = id end
		end
	end
	return out
end

-- Hidden buses show their colour once their exit is clear
function M.reveal(st, events)
	local any = false
	for _, id in ipairs(st.order) do
		if st.buses[id].state == "lot" and st.buses[id].hidden then any = true break end
	end
	if not any then return end
	local obs = M.obstacles(st)
	local dist = geometry.exit_distance({ hl = 0, hw = 0 }, st.lot.w, st.lot.h)
	for _, id in ipairs(st.order) do
		local bus = st.buses[id]
		if bus.state == "lot" and bus.hidden then
			local d = dist + 2 * bus.box.hl
			if not geometry.first_hit(bus.box, obs, d, bus.box) then
				bus.hidden = false
				events[#events + 1] = { type = "reveal", bus = id, color = bus.color }
			end
		end
	end
end

-- Switching buses (the round arrow) turn 90 degrees whenever another bus is sent out.
-- They are part of the puzzle: the same tap can open one lane and close another.
function M.rotate_turners(st, events)
	local any = false
	for _, id in ipairs(st.order) do
		local bus = st.buses[id]
		if bus.state == "lot" and bus.turning then
			local size = config.SIZES[bus.size]
			bus.box = geometry.box(bus.box.x, bus.box.y, bus.box.angle + math.pi * 0.5, size.len, size.wid)
			events[#events + 1] = { type = "turn", bus = id, angle = bus.box.angle }
			any = true
		end
	end
	return any
end

function M.free_bay(st, kind)
	for i, bay in ipairs(st.bays) do
		if bay.kind == kind and not bay.bus then return i end
	end
end

function M.parked(st)
	local list = {}
	for _, id in ipairs(st.order) do
		if st.buses[id].state == "lot" then list[#list + 1] = id end
	end
	return list
end

-- Move a bus into a bay. The caller has checked legality (exit_check / free_bay or VIP booster).
function M.send(st, id, bay_index)
	local bus = st.buses[id]
	local events = {}
	bus.state = "to_bay"
	bus.bay = bay_index
	bus.hidden = false
	st.seq = (st.seq or 0) + 1
	bus.seq = st.seq -- boarding priority = tap order, never bay position or timing
	st.bays[bay_index].bus = id
	M.rotate_turners(st, events) -- before a garage spawns its next bus
	if bus.garage then
		st.garages[bus.garage].current = nil
		garage_pop(st, bus.garage, events)
	end
	M.reveal(st, events)
	return events
end

function M.arrive(st, id)
	st.buses[id].state = "bay"
end

-- Board the head passenger into the earliest-sent matching bus with free seats.
-- If that bus is still driving in, the head waits for it: this keeps the outcome identical
-- for a fast real-time player and for the instant solver.
-- Returns the bus id, or nil if the head has nowhere to go (yet).
function M.board_one(st)
	local color = st.queue[st.head]
	if not color then return nil end
	local best
	for _, bay in ipairs(st.bays) do
		local bus = bay.bus and st.buses[bay.bus]
		if bus and (bus.state == "bay" or bus.state == "to_bay") and bus.color == color and bus.left > 0 then
			if not best or bus.seq < best.seq then best = bus end
		end
	end
	if not best or best.state ~= "bay" then return nil end
	best.left = best.left - 1
	st.head = st.head + 1
	if best.left == 0 then best.state = "full" end
	return best.id
end

function M.depart(st, id)
	local bus = st.buses[id]
	st.bays[bus.bay].bus = nil
	bus.state = "gone"
end

-- Rescue: send every parked bus away and free the whole waiting row. Their passengers stay
-- in the queue, so the rescue gives room to act but does not guarantee a win.
function M.clear_bays(st)
	local cleared = {}
	for i, bay in ipairs(st.bays) do
		local bus = bay.bus and st.buses[bay.bus]
		if bus then
			bay.bus = nil
			bus.state = "gone"
			cleared[#cleared + 1] = { id = bus.id, bay = i }
		end
	end
	return cleared
end

function M.passengers_left(st)
	return #st.queue - st.head + 1
end

-- "won"  : everyone boarded
-- "stuck": nothing moving, the head has no bus and every open bay is taken (Out of Spots)
-- "play" : otherwise
function M.status(st)
	if st.head > #st.queue then return "won" end
	local color = st.queue[st.head]
	local open_free = false
	for _, bay in ipairs(st.bays) do
		local bus = bay.bus and st.buses[bay.bus]
		if not bus then
			if bay.kind == "open" then open_free = true end
		elseif bus.state ~= "bay" or bus.color == color then
			return "play" -- something is still moving or can take the head
		end
	end
	if open_free then return "play" end
	return "stuck"
end

return M
