-- Discrete game rules: the single source of truth for what is legal.
-- Used by the real-time sim (sim.lua adds timers on top) and by the solver (instant moves).
-- No Defold API, no time. Every mutating function returns a list of events for the view.
--
-- Level data (from level_gen or hand-made):
--   { lot = {w=, h=}, bays = {open=, locked=, vip=bool},
--     buses   = { {x=, y=, angle=, size="s|m|l", color=, hidden=bool} },
--     garages = { {x=, y=, angle=, len=, wid=, queue = { {size=, color=, hidden=} } } },
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
		hidden = spec.hidden or false, garage = garage, state = "lot",
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
		garages = {}, bays = {},
		queue = {}, head = 1,
	}
	for i = 1, #level.queue do st.queue[i] = level.queue[i] end

	local b = level.bays
	if b.vip then st.bays[#st.bays + 1] = { kind = "vip" } end
	for _ = 1, b.open do st.bays[#st.bays + 1] = { kind = "open" } end
	for _ = 1, b.locked or 0 do st.bays[#st.bays + 1] = { kind = "locked" } end

	for _, spec in ipairs(level.buses) do add_bus(st, spec, spec.x, spec.y, spec.angle) end
	local ev = {}
	for gi, g in ipairs(level.garages or {}) do
		local q = {}
		for i, spec in ipairs(g.queue) do q[i] = spec end
		st.garages[gi] = { x = g.x, y = g.y, angle = g.angle, len = g.len, wid = g.wid, queue = q,
			box = geometry.box(g.x, g.y, g.angle, g.len, g.wid) }
		garage_pop(st, gi, ev)
	end
	M.reveal(st, ev)
	return st
end

-- Boxes that block driving: parked buses (except `skip`) and garage bodies
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
	return list, owners
end

-- true if the bus can leave the lot; otherwise false, blocker id (negative = garage), free distance
function M.exit_check(st, id)
	local bus = st.buses[id]
	local obs, owners = M.obstacles(st, id)
	local hit, dist = geometry.first_hit(bus.box, obs, geometry.exit_distance(bus.box, st.lot.w, st.lot.h))
	if not hit then return true end
	return false, owners[hit], dist
end

-- Hidden buses show their colour once their exit is clear
function M.reveal(st, events)
	for _, id in ipairs(st.order) do
		local bus = st.buses[id]
		if bus.state == "lot" and bus.hidden and M.exit_check(st, id) then
			bus.hidden = false
			events[#events + 1] = { type = "reveal", bus = id, color = bus.color }
		end
	end
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
	st.bays[bay_index].bus = id
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

-- Board the head passenger into the first matching bus in the bays (left to right).
-- Returns the bus id, or nil if the head has nowhere to go.
function M.board_one(st)
	local color = st.queue[st.head]
	if not color then return nil end
	for _, bay in ipairs(st.bays) do
		local bus = bay.bus and st.buses[bay.bus]
		if bus and bus.state == "bay" and bus.color == color and bus.left > 0 then
			bus.left = bus.left - 1
			st.head = st.head + 1
			if bus.left == 0 then bus.state = "full" end
			return bus.id
		end
	end
end

function M.depart(st, id)
	local bus = st.buses[id]
	st.bays[bus.bay].bus = nil
	bus.state = "gone"
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
